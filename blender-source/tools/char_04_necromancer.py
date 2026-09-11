"""Character step 5a -- the Necromancer, "Veil Walker", ranged damage.

Reference: docs/reference/01-characters/03-necromancer-veil-walker.png.

From the spec: tall and narrow, hood up, long ragged hem -- and the hem is
what makes it read at distance. Palette is pale grave-green and dull violet
with bone accents; the reference leans that green towards a cold teal, with
a near-black robe and bone-white bladed trim, so that is what this uses.

The shared body underneath is unchanged. Narrowness comes from the robe:
it hangs almost straight from the shoulders instead of flaring at the hips
like the Valkyr's faulds, which is what makes the same body read as a
different build.
"""

import bpy
import bmesh

import km_kit as K
import km_char as C
import km_armour as A
import km_rig as R
import km_textures as T
import char_01_base_body as body

NAME = "char_necromancer"
OUT = "characters"
ANGLES = (90, -90)
ELEVATION = 6
APPLY_MODIFIERS = False

ROBE = (0.088, 0.092, 0.098)        # near-black, faintly cold
ROBE_LIT = (0.150, 0.168, 0.170)
BONE = (0.855, 0.842, 0.790)        # bone-white bladed trim
TEAL = (0.180, 0.760, 0.690)        # the grave-light
VEIL = (0.115, 0.230, 0.220)        # dull green underlayer

M_ROBE, M_BONE, M_TEAL, M_VEIL, M_SKIN = 0, 1, 2, 3, 4


def _materials():
    T.register("necro_robe", lambda: T.cloth(ROBE, seed=311, folds=11.0))
    T.register("necro_bone", lambda: T.plate(BONE, seed=313, panel=13.0))
    T.register("necro_teal", lambda: T.glow(TEAL, seed=317))
    T.register("necro_veil", lambda: T.cloth(VEIL, seed=319, folds=8.0))
    return [
        K.material("necro_robe", "KM_necro_robe"),
        K.material("necro_bone", "KM_necro_bone"),
        K.material("necro_teal", "KM_necro_teal"),
        K.material("necro_veil", "KM_necro_veil"),
        K.material("skin", "KM_skin"),
    ]


def build():
    K.new_scene()
    mats = _materials()

    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    body._torso(bm, uv, skin_mat=M_ROBE, cloth_mat=M_ROBE)
    # The head is robe-dark too. There is no face under this hood -- a skin
    # tone in there read as a bare head wearing a bag.
    body._head(bm, uv, skin_mat=M_ROBE, cloth_mat=M_ROBE)
    for side in C.SIDES:
        body._arm(bm, uv, side, skin_mat=M_ROBE, cloth_mat=M_ROBE)
        body._leg(bm, uv, side, skin_mat=M_ROBE, cloth_mat=M_ROBE)

    _robe(bm, uv)
    A.hood(bm, uv, M_ROBE)
    # The only light on the whole figure: two eyes, set just proud of the
    # hood's front face. Inside it they were completely hidden -- the hood
    # is a closed revolution, so nothing behind it is ever visible.
    for side in (-1, 1):
        C.tube(bm, uv, [((side * 0.040, 0.148, 1.672), 0.018, 0.013),
                        ((side * 0.040, 0.163, 1.672), 0.013, 0.009)],
               C.X, C.Z, 6, mat=M_TEAL, cap_start=True, cap_end=True)

    for side in C.SIDES:
        _shoulder(bm, uv, side)
        _sleeve(bm, uv, side)

    _ribcage(bm, uv)

    mesh = C.finish_char(bm, NAME, mats)
    mesh.name = "Body"
    arm_obj = R.build_armature("Armature")
    R.skin(mesh, arm_obj)
    bpy.context.view_layer.update()
    return [arm_obj, mesh]


def _robe(bm, uv):
    """A long straight robe, then a torn hem under it.

    Barely any flare: the narrow column is half of what separates this
    silhouette from the Valkyr's, and the ragged points do the rest.
    """
    A.shell(bm, uv, [((0, 0, 1.46), 0.238, 0.160),
                     ((0, 0, 1.20), 0.212, 0.148),
                     ((0, 0, 0.95), 0.196, 0.140),
                     ((0, 0, 0.60), 0.194, 0.142),
                     ((0, 0, 0.30), 0.198, 0.146)],
             C.X, C.Y, 12, M_ROBE)

    # Dull green underlayer showing below the black.
    A.shell(bm, uv, [((0, 0, 0.55), 0.182, 0.132),
                     ((0, 0, 0.22), 0.186, 0.136)],
            C.X, C.Y, 12, M_VEIL)

    # Two tiers of torn points, staggered so the outline is busy.
    A.ragged_hem(bm, uv, M_ROBE, 0.62,
                 [0.34, 0.24, 0.31, 0.20, 0.36, 0.26, 0.30, 0.22, 0.33],
                 0.196, y_scale=0.74)
    A.ragged_hem(bm, uv, M_VEIL, 0.40,
                 [0.22, 0.14, 0.19, 0.26, 0.16, 0.23, 0.13],
                 0.176, y_scale=0.74, blade_width=0.060)

    # Bone-bladed trim down the front seam.
    A.shell(bm, uv, [((0, 0.148, 1.30), 0.040, 0.022),
                     ((0, 0.155, 1.00), 0.046, 0.024),
                     ((0, 0.152, 0.74), 0.030, 0.020),
                     ((0, 0.150, 0.62), 0.008, 0.010)],
            C.X, C.Y, 6, M_BONE, cap_start=True, cap_end=True)


def _shoulder(bm, uv, side):
    """Bladed bone pauldrons -- angular, not domed like the Valkyr's."""
    A.shell(bm, uv, [((side * 0.16, 0, 1.475), 0.085, 0.075),
                     ((side * 0.26, 0, 1.470), 0.108, 0.092),
                     ((side * 0.33, -0.02, 1.415), 0.070, 0.055),
                     ((side * 0.36, -0.03, 1.355), 0.018, 0.016)],
            C.Y, C.Z, 6, M_BONE, cap_start=True, cap_end=True)


def _sleeve(bm, uv, side):
    """Wide sleeve to the elbow, then torn strips hanging from it."""
    A.shell(bm, uv, [((side * 0.22, 0, 1.435), 0.112, 0.110),
                     ((side * 0.40, 0, 1.430), 0.098, 0.098),
                     ((side * 0.52, 0, 1.425), 0.084, 0.086)],
            C.Y, C.Z, 8, M_ROBE)
    for i, drop in enumerate((0.20, 0.30, 0.24)):
        x = side * (0.36 + i * 0.07)
        C.tube(bm, uv, [((x, 0.0, 1.36), 0.050, 0.016),
                        ((x, -0.01, 1.36 - drop * 0.6), 0.042, 0.014),
                        ((x, -0.02, 1.36 - drop), 0.008, 0.008)],
               C.Y, C.X, 5, mat=M_VEIL, cap_start=True, cap_end=True,
               v_scale=0.5)


def _ribcage(bm, uv):
    """Bone ribs across the chest, straight off the reference sheet.

    Built as short bars ACROSS the front rather than rings around the body:
    ring-shaped ribs sat inside the robe shell and were invisible, and
    widening them to clear it would have banded the whole torso.
    """
    for i, z in enumerate((1.39, 1.32, 1.25)):
        half = 0.118 - i * 0.012
        C.tube(bm, uv, [((-half, 0.150, z), 0.016, 0.013),
                        ((0.0, 0.163, z + 0.010), 0.019, 0.015),
                        ((half, 0.150, z), 0.016, 0.013)],
               C.Y, C.Z, 6, mat=M_BONE, cap_start=True, cap_end=True,
               v_scale=0.6)
    # Sternum down the middle.
    C.tube(bm, uv, [((0, 0.158, 1.43), 0.020, 0.016),
                    ((0, 0.166, 1.30), 0.024, 0.018),
                    ((0, 0.158, 1.20), 0.014, 0.011)],
           C.X, C.Z, 6, mat=M_BONE, cap_start=True, cap_end=True, v_scale=0.6)


if __name__ == "__main__":
    print(K.report(build()))
