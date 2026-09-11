"""Character step 2b -- deformation test.

The spec says approve the deformation before animating, and automatic
weights are exactly the sort of thing that looks fine in a T-pose and falls
apart the moment a joint bends. So this poses the rig hard -- arms down and
elbows bent, hips and knees bent -- and renders it.

What to look for: the elbow and knee should crease rather than collapse or
balloon, and the shoulder should not tear away from the chest.

This is a test render only. It exports nothing.
"""

import math
import bpy
from mathutils import Matrix, Vector

import km_kit as K
import char_02_rigged_body as rigged

NAME = "char_pose_test"
ANGLES = (62, -118)
ELEVATION = 10
EXPORT = False

# (bone, world axis, degrees). Parents are listed before their children so
# each rotation composes onto an already-updated parent.
POSE = [
    ("LeftUpperArm",  "Y",  62), ("RightUpperArm", "Y", -62),
    ("LeftLowerArm",  "X", -72), ("RightLowerArm", "X", -72),
    ("LeftUpperLeg",  "X", -28), ("RightUpperLeg", "X",  14),
    ("LeftLowerLeg",  "X",  52), ("RightLowerLeg", "X",  20),
    ("Spine",         "Z",  10),
    ("Head",          "Z", -16),
]

AXES = {"X": Vector((1, 0, 0)), "Y": Vector((0, 1, 0)), "Z": Vector((0, 0, 1))}


def build():
    objs = rigged.build()
    arm_obj = objs[0]

    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="POSE")
    for bone_name, axis, degrees in POSE:
        pb = arm_obj.pose.bones[bone_name]
        # Rotate about the bone's own HEAD. Matrix.Rotation pivots on the
        # world origin, and because these bones are unconnected they each
        # own a location channel -- so composing it directly translated the
        # arms halfway across the scene instead of bending them.
        pivot = pb.matrix.translation.copy()
        rot = (Matrix.Translation(pivot)
               @ Matrix.Rotation(math.radians(degrees), 4, AXES[axis])
               @ Matrix.Translation(-pivot))
        pb.matrix = rot @ pb.matrix
        bpy.context.view_layer.update()
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()

    return objs


if __name__ == "__main__":
    print(K.report(build()))
