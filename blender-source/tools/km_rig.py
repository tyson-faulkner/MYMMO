"""Kingsmourn character rig -- the shared skeleton.

There are no playable races, so there is exactly ONE skeleton. Every class,
every human enemy and both bosses use it, which is why it is defined here as
data rather than built per-character.

Bone names follow Godot's SkeletonProfileHumanoid so retargeting recognises
them, plus the four attachment bones the game's equipment code already
expects as socket names: HeadAttach, LeftHandAttach, RightHandAttach and
BackAttach.

Bones are (head, tail) in the same metres-and-Z-up space the body is built
in, so the numbers here line up with char_01_base_body.py by inspection.
"""

import bpy
from mathutils import Vector

# name: (head, tail, parent)
# Kept flat and explicit -- a rig you can read is a rig you can fix.
BONES = [
    ("Hips",           (0.000, 0.000, 0.95), (0.000, 0.000, 1.06), None),
    ("Spine",          (0.000, 0.000, 1.06), (0.000, 0.000, 1.19), "Hips"),
    ("Chest",          (0.000, 0.000, 1.19), (0.000, 0.000, 1.38), "Spine"),
    ("UpperChest",     (0.000, 0.000, 1.38), (0.000, 0.000, 1.50), "Chest"),
    ("Neck",           (0.000, 0.000, 1.50), (0.000, 0.000, 1.58), "UpperChest"),
    ("Head",           (0.000, 0.000, 1.58), (0.000, 0.000, 1.80), "Neck"),
]

# Arms are horizontal in the T-pose; legs run straight down.
_ARM = [
    ("Shoulder",  (0.045, 0.0, 1.44), (0.130, 0.0, 1.43), "UpperChest"),
    ("UpperArm",  (0.130, 0.0, 1.43), (0.470, 0.0, 1.425), "Shoulder"),
    ("LowerArm",  (0.470, 0.0, 1.425), (0.740, 0.0, 1.425), "UpperArm"),
    ("Hand",      (0.740, 0.0, 1.425), (0.880, 0.0, 1.425), "LowerArm"),
]
_LEG = [
    ("UpperLeg",  (0.098, 0.0, 0.92), (0.098, 0.0, 0.48), "Hips"),
    ("LowerLeg",  (0.098, 0.0, 0.48), (0.098, 0.0, 0.12), "UpperLeg"),
    ("Foot",      (0.098, 0.0, 0.12), (0.098, 0.14, 0.03), "LowerLeg"),
    ("Toes",      (0.098, 0.14, 0.03), (0.098, 0.22, 0.03), "Foot"),
]

SIDES = (("Left", 1.0), ("Right", -1.0))

# Sockets the equipment code binds to, as real bones so a BoneAttachment3D
# can name them directly: (bone, parent, offset from the parent's head).
ATTACHMENTS = [
    ("HeadAttach",      "Head",      (0.0, 0.0, 0.20), (0.0, 0.0, 0.30)),
    ("LeftHandAttach",  "LeftHand",  (0.0, 0.0, 0.0), (0.0, 0.10, 0.0)),
    ("RightHandAttach", "RightHand", (0.0, 0.0, 0.0), (0.0, 0.10, 0.0)),
    ("BackAttach",      "UpperChest", (0.0, -0.14, 0.08), (0.0, -0.24, 0.08)),
]


def bone_table():
    """Every bone as (name, head, tail, parent), sides expanded."""
    table = list(BONES)
    for side, sx in SIDES:
        for name, head, tail, parent in _ARM + _LEG:
            full = side + name
            par = parent if parent in ("UpperChest", "Hips") else side + parent
            table.append((
                full,
                (head[0] * sx, head[1], head[2]),
                (tail[0] * sx, tail[1], tail[2]),
                par,
            ))
    for name, parent, head_off, tail_off in ATTACHMENTS:
        base = dict((b[0], b) for b in table)[parent]
        origin = Vector(base[2] if parent == "Head" else base[1])
        if parent.endswith("Hand"):
            origin = Vector(base[1]) + (Vector(base[2]) - Vector(base[1])) * 0.5
        table.append((
            name,
            tuple(origin + Vector(head_off)),
            tuple(origin + Vector(tail_off)),
            parent,
        ))
    return table


def build_armature(name="Armature"):
    """Create the shared skeleton as a real Blender armature object."""
    arm_data = bpy.data.armatures.new(name)
    arm_obj = bpy.data.objects.new(name, arm_data)
    bpy.context.collection.objects.link(arm_obj)

    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")
    table = bone_table()
    made = {}
    for bname, head, tail, parent in table:
        eb = arm_data.edit_bones.new(bname)
        eb.head = Vector(head)
        eb.tail = Vector(tail)
        eb.use_deform = not bname.endswith("Attach")
        made[bname] = eb
    for bname, _, _, parent in table:
        if parent:
            made[bname].parent = made[parent]
            # Limbs stay unconnected: connecting them would snap each bone's
            # head onto its parent's tail and quietly move the joints.
            made[bname].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm_obj


def _point_segment_distance(p, a, b):
    ab = b - a
    length_sq = ab.length_squared
    if length_sq < 1e-12:
        return (p - a).length
    t = max(0.0, min(1.0, (p - a).dot(ab) / length_sq))
    return (p - (a + ab * t)).length


def skin(mesh_obj, arm_obj, power=4.0, max_influences=4):
    """Bind the mesh, weighting each vertex by distance to the bone segments.

    Deliberately NOT Blender's automatic (heat) weights. Heat weighting
    solves over a connected surface, and this body is not one continuous
    surface -- limbs are separate tubes buried in the torso. Islands it
    could not reach came out weighted to whatever bone happened to win, and
    a hand flew off to the hip the moment the rig was posed.

    Inverse-distance with a high power is crude but it is local, it is
    deterministic, and every vertex gets a sane answer whether or not its
    island touches anything else.
    """
    bones = [b for b in arm_obj.data.bones if b.use_deform]
    segments = [(b.name, b.head_local.copy(), b.tail_local.copy()) for b in bones]

    groups = {}
    for name, _, _ in segments:
        groups[name] = mesh_obj.vertex_groups.get(name) or mesh_obj.vertex_groups.new(name=name)

    for vert in mesh_obj.data.vertices:
        co = vert.co
        ranked = sorted(
            ((_point_segment_distance(co, head, tail), name)
             for name, head, tail in segments),
            key=lambda pair: pair[0],
        )[:max_influences]

        weights = [(name, 1.0 / max(dist, 1e-4) ** power) for dist, name in ranked]
        total = sum(w for _, w in weights)
        for name, w in weights:
            groups[name].add([vert.index], w / total, "REPLACE")

    mesh_obj.parent = arm_obj
    mesh_obj.matrix_parent_inverse = arm_obj.matrix_world.inverted()
    modifier = mesh_obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = arm_obj
    return mesh_obj
