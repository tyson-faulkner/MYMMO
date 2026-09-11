"""Animations for the shared skeleton.

One skeleton means one animation set: whatever is built here plays on the
Valkyr, the Bard and every human enemy without being redone. That is the
whole reason the spec forbids per-class rigs.

The clip names match the states the game already drives in
scripts/player/player.gd -- Idle, Run, Sprint, Jump, Jump2, Fall, Attack1,
Emote2 -- so a new character drops in without touching the state machine.
Idle, Run and Attack1 are the three that carry the game; the rest exist so
nothing plays a missing clip.

Poses are written as WORLD-space rotations about each bone's own head,
listed parents-first. That is verbose, but it means a pose can be read and
adjusted without first working out which way a given bone's local axes
happen to point.
"""

import math
import bpy
from mathutils import Matrix, Vector

AXES = {"X": Vector((1, 0, 0)), "Y": Vector((0, 1, 0)), "Z": Vector((0, 0, 1))}
FPS = 24

# Arms hang at the sides. Everything else is measured from here, because a
# T-pose is a bind pose, not something a character is ever seen in.
REST_ARMS = [
    ("LeftUpperArm", "Y", 74), ("LeftUpperArm", "X", -6), ("LeftLowerArm", "X", -16),
    ("RightUpperArm", "Y", -74), ("RightUpperArm", "X", -6), ("RightLowerArm", "X", -16),
]


def _rotate(pose_bone, axis, degrees):
    """Rotate a pose bone about its own head, in world space."""
    pivot = pose_bone.matrix.translation.copy()
    rot = (Matrix.Translation(pivot)
           @ Matrix.Rotation(math.radians(degrees), 4, AXES[axis])
           @ Matrix.Translation(-pivot))
    pose_bone.matrix = rot @ pose_bone.matrix


def _translate(pose_bone, axis, amount):
    pose_bone.matrix = Matrix.Translation(AXES[axis] * amount) @ pose_bone.matrix


def clear_pose(arm_obj):
    for pb in arm_obj.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()


def apply_pose(arm_obj, entries):
    """Apply (bone, axis, degrees) rotations and ("T", bone, axis, metres).

    Entries are applied in order and compose, so a bone can appear more than
    once -- swing the upper arm down, then forward.
    """
    for entry in entries:
        if entry[0] == "T":
            _, bone, axis, amount = entry
            _translate(arm_obj.pose.bones[bone], axis, amount)
        else:
            bone, axis, degrees = entry
            _rotate(arm_obj.pose.bones[bone], axis, degrees)
        bpy.context.view_layer.update()


def _key(arm_obj, frame):
    for pb in arm_obj.pose.bones:
        pb.keyframe_insert("location", frame=frame)
        pb.keyframe_insert("rotation_quaternion", frame=frame)


def make_action(arm_obj, name, keys, loop=True):
    """Build one action from a list of (frame, pose entries) and stash it on
    its own NLA track, which is how the glTF exporter names a clip."""
    action = bpy.data.actions.new(name)
    arm_obj.animation_data_create()
    arm_obj.animation_data.action = action

    for frame, entries in keys:
        clear_pose(arm_obj)
        apply_pose(arm_obj, REST_ARMS + entries)
        _key(arm_obj, frame)

    clear_pose(arm_obj)
    arm_obj.animation_data.action = None
    track = arm_obj.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, action)
    strip.name = name
    track.mute = True
    return action


# ----------------------------------------------------------------- clips ---
def _stride(front, back, lift=0.0, lean=-8):
    """One half of a gait: `front` leg forward, `back` leg back."""
    return [
        ("Spine", "X", lean),
        ("%sUpperLeg" % front, "X", -32), ("%sLowerLeg" % front, "X", 26),
        ("%sFoot" % front, "X", -10),
        ("%sUpperLeg" % back, "X", 22), ("%sLowerLeg" % back, "X", 34),
        ("%sFoot" % back, "X", 14),
        # Arms swing opposite the legs.
        ("%sUpperArm" % back, "X", -34), ("%sLowerArm" % back, "X", -28),
        ("%sUpperArm" % front, "X", 26), ("%sLowerArm" % front, "X", -18),
        ("T", "Hips", "Z", lift),
    ]


def _passing(lean=-8):
    """The moment mid-stride where the legs cross."""
    return [
        ("Spine", "X", lean),
        ("LeftUpperLeg", "X", -6), ("LeftLowerLeg", "X", 16),
        ("RightUpperLeg", "X", -2), ("RightLowerLeg", "X", 30),
        ("T", "Hips", "Z", 0.045),
    ]


def build_all(arm_obj):
    """Every clip the game's state machine can ask for."""
    made = []

    # Idle: a slow breath and a little weight shift. Deliberately small --
    # an idle that moves much reads as a character who cannot stand still.
    made.append(make_action(arm_obj, "Idle", [
        (1, []),
        (24, [("Spine", "X", -2), ("Chest", "X", -2), ("Head", "X", 2),
              ("LeftUpperArm", "X", 3), ("RightUpperArm", "X", 3)]),
        (48, [("Spine", "X", 1), ("Head", "Y", -2)]),
        (72, []),
    ]))

    made.append(make_action(arm_obj, "Run", [
        (1, _stride("Left", "Right", 0.0)),
        (7, _passing()),
        (13, _stride("Right", "Left", 0.0)),
        (19, _passing()),
        (25, _stride("Left", "Right", 0.0)),
    ]))

    # Sprint is the same gait leaning harder with a longer stride, not a
    # separate animation -- one skeleton, one set of poses.
    made.append(make_action(arm_obj, "Sprint", [
        (1, _stride("Left", "Right", 0.0, lean=-20)),
        (5, _passing(lean=-20)),
        (10, _stride("Right", "Left", 0.0, lean=-20)),
        (14, _passing(lean=-20)),
        (19, _stride("Left", "Right", 0.0, lean=-20)),
    ]))

    jump = [
        (1, [("LeftUpperLeg", "X", 26), ("LeftLowerLeg", "X", -44),
             ("RightUpperLeg", "X", 26), ("RightLowerLeg", "X", -44),
             ("Spine", "X", -16), ("T", "Hips", "Z", -0.14)]),
        (6, [("LeftUpperArm", "X", -52), ("RightUpperArm", "X", -52),
             ("Spine", "X", 6), ("T", "Hips", "Z", 0.04)]),
        (14, [("LeftUpperLeg", "X", -14), ("LeftLowerLeg", "X", 30),
              ("RightUpperLeg", "X", 8), ("RightLowerLeg", "X", 22),
              ("LeftUpperArm", "X", -40), ("RightUpperArm", "X", -40)]),
    ]
    made.append(make_action(arm_obj, "Jump", jump, loop=False))
    made.append(make_action(arm_obj, "Jump2", [
        (1, [("Spine", "X", -10), ("T", "Hips", "Z", -0.10)]),
        (7, [("LeftUpperArm", "X", -64), ("RightUpperArm", "X", -64),
             ("LeftUpperLeg", "X", -20), ("RightUpperLeg", "X", -20)]),
        (15, [("LeftUpperLeg", "X", -10), ("RightUpperLeg", "X", 10)]),
    ], loop=False))

    made.append(make_action(arm_obj, "Fall", [
        (1, [("LeftUpperArm", "X", -46), ("RightUpperArm", "X", -46),
             ("LeftUpperLeg", "X", -18), ("LeftLowerLeg", "X", 26),
             ("RightUpperLeg", "X", 10), ("RightLowerLeg", "X", 18),
             ("Spine", "X", 8)]),
        (20, [("LeftUpperArm", "X", -54), ("RightUpperArm", "X", -38),
              ("LeftUpperLeg", "X", -10), ("LeftLowerLeg", "X", 32),
              ("RightUpperLeg", "X", 16), ("RightLowerLeg", "X", 12),
              ("Spine", "X", 10)]),
        (40, [("LeftUpperArm", "X", -46), ("RightUpperArm", "X", -46),
              ("LeftUpperLeg", "X", -18), ("LeftLowerLeg", "X", 26),
              ("RightUpperLeg", "X", 10), ("RightLowerLeg", "X", 18),
              ("Spine", "X", 8)]),
    ]))

    # Attack1: wind up across the body, swing through, recover. Right arm
    # leads, because every class holds its weapon in the right hand.
    made.append(make_action(arm_obj, "Attack1", [
        (1, []),
        (4, [("Spine", "Z", 22), ("Chest", "Z", 14),
             ("RightUpperArm", "X", -74), ("RightUpperArm", "Z", 26),
             ("RightLowerArm", "X", -58), ("Head", "Z", 10)]),
        (10, [("Spine", "Z", -26), ("Chest", "Z", -16),
              ("RightUpperArm", "X", -30), ("RightUpperArm", "Z", -34),
              ("RightLowerArm", "X", -10),
              ("LeftUpperArm", "X", 18), ("Head", "Z", -12),
              ("LeftUpperLeg", "X", -12)]),
        (16, [("Spine", "Z", -8), ("RightUpperArm", "X", -12),
              ("RightLowerArm", "X", -20)]),
        (26, []),
    ], loop=False))

    made.append(make_action(arm_obj, "Emote2", [
        (1, []),
        (10, [("RightUpperArm", "X", -30), ("RightUpperArm", "Y", -62),
              ("RightLowerArm", "X", -20), ("Head", "Y", -8)]),
        (20, [("RightUpperArm", "X", -30), ("RightUpperArm", "Y", -86),
              ("RightLowerArm", "X", -20), ("Head", "Y", -8)]),
        (30, [("RightUpperArm", "X", -30), ("RightUpperArm", "Y", -62),
              ("RightLowerArm", "X", -20), ("Head", "Y", -8)]),
        (44, []),
    ], loop=False))

    bpy.context.scene.frame_end = 72
    return made
