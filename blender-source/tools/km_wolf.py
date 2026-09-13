"""The Vale Wolf -- the game's one quadruped.

The only enemy that is not the shared body: its own swept mesh, its own
14-bone rig, and its own three clips (Idle, Run, Attack1 -- the names the
mob code drives). Lean and grey-brown, ribs showing; it came down with the
cold and stayed because it found bodies.

Faces +Y like the humans, origin under the chest, so the mob scene needs
no special case for it.
"""

import bpy
import bmesh
from mathutils import Vector

import km_kit as K
import km_char as C
import km_rig as R
import km_textures as T
import km_anim

FUR = (0.40, 0.36, 0.31)
FUR_DARK = (0.24, 0.21, 0.18)
EYE = (0.85, 0.90, 0.45)

# (name, head, tail, parent): Z-up, +Y forward.
BONES = [
    ("Hips", (0, -0.55, 0.62), (0, -0.20, 0.64), None),
    ("Spine", (0, -0.20, 0.64), (0, 0.25, 0.68), "Hips"),
    ("Chest", (0, 0.25, 0.68), (0, 0.48, 0.74), "Spine"),
    ("Neck", (0, 0.48, 0.74), (0, 0.68, 0.86), "Chest"),
    ("Head", (0, 0.68, 0.86), (0, 1.05, 0.82), "Neck"),
    ("Tail", (0, -0.60, 0.62), (0, -0.95, 0.45), "Hips"),
]
for _side, _name in ((1, "Left"), (-1, "Right")):
    BONES += [
        ("Front%sUpper" % _name, (_side * 0.12, 0.32, 0.66), (_side * 0.12, 0.30, 0.36), "Chest"),
        ("Front%sLower" % _name, (_side * 0.12, 0.30, 0.36), (_side * 0.12, 0.34, 0.03), "Front%sUpper" % _name),
        ("Back%sUpper" % _name, (_side * 0.13, -0.45, 0.62), (_side * 0.13, -0.40, 0.34), "Hips"),
        ("Back%sLower" % _name, (_side * 0.13, -0.40, 0.34), (_side * 0.13, -0.44, 0.03), "Back%sUpper" % _name),
    ]


def build_armature(name="Armature"):
    arm_data = bpy.data.armatures.new(name)
    arm_obj = bpy.data.objects.new(name, arm_data)
    bpy.context.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")
    made = {}
    for bname, head, tail, parent in BONES:
        eb = arm_data.edit_bones.new(bname)
        eb.head = Vector(head)
        eb.tail = Vector(tail)
        eb.use_deform = True
        made[bname] = eb
    for bname, _, _, parent in BONES:
        if parent:
            made[bname].parent = made[parent]
            made[bname].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm_obj


def _mesh(bm, uv, fur, dark, eye):
    # Body along Y: rump, belly, ribcage, shoulders.
    C.tube(bm, uv, [((0, -0.72, 0.60), 0.120, 0.130),
                    ((0, -0.55, 0.62), 0.165, 0.185),
                    ((0, -0.20, 0.60), 0.170, 0.200),
                    ((0, 0.15, 0.64), 0.185, 0.220),
                    ((0, 0.40, 0.70), 0.150, 0.160),
                    ((0, 0.52, 0.76), 0.110, 0.110)],
           C.X, C.Z, 10, mat=fur, cap_start=True, cap_end=True)
    # A darker saddle down the spine.
    C.tube(bm, uv, [((0, -0.60, 0.72), 0.100, 0.060),
                    ((0, -0.15, 0.74), 0.120, 0.070),
                    ((0, 0.30, 0.80), 0.100, 0.055)],
           C.X, C.Z, 6, mat=dark, cap_start=True, cap_end=True)
    # Neck and head: rising, then the muzzle tapering forward.
    C.tube(bm, uv, [((0, 0.50, 0.76), 0.100, 0.100),
                    ((0, 0.66, 0.85), 0.110, 0.110),
                    ((0, 0.80, 0.88), 0.115, 0.105),
                    ((0, 0.95, 0.84), 0.080, 0.070),
                    ((0, 1.08, 0.80), 0.050, 0.045),
                    ((0, 1.14, 0.79), 0.030, 0.028)],
           C.X, C.Z, 10, mat=fur, cap_start=True, cap_end=True)
    for side in (-1, 1):
        C.tube(bm, uv, [((side * 0.060, 0.72, 0.92), 0.030, 0.020),
                        ((side * 0.075, 0.70, 1.03), 0.012, 0.010)],
               C.X, C.Y, 5, mat=dark, cap_start=True, cap_end=True)        # ears
        C.tube(bm, uv, [((side * 0.045, 0.94, 0.87), 0.016, 0.012),
                        ((side * 0.045, 0.955, 0.87), 0.012, 0.009)],
               C.X, C.Z, 6, mat=eye, cap_start=True, cap_end=True)         # eyes
    # Legs: tubes down Z with a flattened paw.
    for side in (-1, 1):
        for x, y in ((side * 0.12, 0.32), (side * 0.13, -0.45)):
            C.tube(bm, uv, [((x, y, 0.68), 0.075, 0.085),
                            ((x, y - 0.02, 0.42), 0.055, 0.060),
                            ((x, y, 0.22), 0.045, 0.050),
                            ((x, y + 0.02, 0.06), 0.050, 0.060),
                            ((x, y + 0.04, 0.01), 0.045, 0.070)],
                   C.X, C.Y, 8, mat=fur, cap_start=True, cap_end=True)
    # Tail.
    C.tube(bm, uv, [((0, -0.66, 0.62), 0.040, 0.040),
                    ((0, -0.82, 0.55), 0.035, 0.035),
                    ((0, -0.96, 0.42), 0.020, 0.020)],
           C.X, C.Z, 6, mat=dark, cap_start=True, cap_end=True)


def build():
    K.new_scene()
    T.register("wolf_fur", lambda: T.fur(FUR, seed=541, clumps=26.0))
    T.register("wolf_dark", lambda: T.fur(FUR_DARK, seed=543, clumps=22.0))
    T.register("wolf_eye", lambda: T.glow(EYE, seed=545))
    mats = [K.material("wolf_fur", "KM_wolf_fur"),
            K.material("wolf_dark", "KM_wolf_dark"),
            K.material("wolf_eye", "KM_wolf_eye")]
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    _mesh(bm, uv, 0, 1, 2)
    mesh = C.finish_char(bm, "vale_wolf", mats)
    mesh.name = "Body"
    arm_obj = build_armature("Armature")
    R.skin(mesh, arm_obj, power=3.0)
    bpy.context.view_layer.update()
    _clips(arm_obj)
    return [arm_obj, mesh]


def _stride(front_fwd, back_fwd, lift):
    """One half of a gallop: the front pair swings one way, the back pair the other."""
    f, b = 34.0 * front_fwd, 30.0 * back_fwd
    return [
        ("FrontLeftUpper", "X", f), ("FrontRightUpper", "X", f * 0.85),
        ("FrontLeftLower", "X", -f * 0.6), ("FrontRightLower", "X", -f * 0.5),
        ("BackLeftUpper", "X", b), ("BackRightUpper", "X", b * 0.85),
        ("BackLeftLower", "X", -b * 0.5), ("BackRightLower", "X", -b * 0.4),
        ("Spine", "X", -front_fwd * 5.0), ("Head", "X", front_fwd * 4.0),
        ("T", "Hips", "Z", lift),
    ]


def _clips(arm_obj):
    A = km_anim.make_action
    A(arm_obj, "Idle", [
        (1, []),
        (24, [("Chest", "X", -2), ("Head", "X", 3), ("Tail", "Z", 12)]),
        (48, [("Head", "Y", 4), ("Head", "X", -2), ("Tail", "Z", -12)]),
        (72, []),
    ], rest=[])
    A(arm_obj, "Run", [
        (1, _stride(1.0, -1.0, 0.02)),
        (5, [("T", "Hips", "Z", 0.07), ("Spine", "X", 4)]),
        (9, _stride(-1.0, 1.0, 0.02)),
        (13, [("T", "Hips", "Z", 0.05), ("Spine", "X", -4)]),
        (17, _stride(1.0, -1.0, 0.02)),
    ], rest=[])
    A(arm_obj, "Attack1", [
        (1, []),
        (4, [("Chest", "X", 6), ("Head", "X", -16), ("T", "Hips", "Y", -0.06)]),
        (9, [("Chest", "X", -12), ("Head", "X", 18), ("T", "Hips", "Y", 0.18),
             ("FrontLeftUpper", "X", 30), ("FrontRightUpper", "X", 30)]),
        (15, [("Head", "X", 6), ("T", "Hips", "Y", 0.06)]),
        (22, []),
    ], loop=False, rest=[])
    bpy.context.scene.frame_end = 72
