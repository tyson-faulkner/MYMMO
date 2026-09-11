"""Character step 2 -- the base body, rigged and skinned.

Same mesh as step 1, bound to the shared skeleton from km_rig.py with
automatic weights. This is the asset every class and every human enemy is
built from, so the deformation has to be right before anything is dressed.

Exports as char_base_rigged.glb with the skeleton and the four attachment
bones, ready for a BoneAttachment3D in Godot to bind by name.
"""

import bpy
import km_kit as K
import km_rig as R
import char_01_base_body as body

NAME = "char_base_rigged"
OUT = "characters"
ANGLES = (90, 0)
ELEVATION = 8
APPLY_MODIFIERS = False   # applying the armature modifier would strip the skin


def build():
    objs = body.build()          # clears the scene and builds the mesh
    mesh = objs[0]
    mesh.name = "Body"

    arm_obj = R.build_armature("Armature")
    R.skin(mesh, arm_obj)

    bpy.context.view_layer.update()
    return [arm_obj, mesh]


if __name__ == "__main__":
    print(K.report(build()))
