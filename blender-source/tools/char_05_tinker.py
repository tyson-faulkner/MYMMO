"""Character step 5b -- the Tinker, "Forge Engineer", ranged damage.

Reference: docs/reference/01-characters/04-tinker-forge-engineer.png.

From the spec: bulky at the BACK, not the shoulders -- a pack of tools and
parts is the distinguishing feature. That is the whole trick for telling him
from the Valkyr at distance: she is wide across the top, he is deep from
front to back.

Palette off the reference: a red coat, brown leather apron and boots, brass
fittings, oiled iron plate, and cold blue crystal in the canisters.

One oversized mechanical gauntlet on the right arm, which is the second
read and the reason his two arms are deliberately not symmetrical.
"""

import bpy
import bmesh

import km_kit as K
import km_char as C
import km_armour as A
import km_rig as R
import km_textures as T
import char_01_base_body as body

NAME = "char_tinker"
OUT = "characters"
ANGLES = (90, -90)
ELEVATION = 6
APPLY_MODIFIERS = False

COAT = (0.560, 0.128, 0.105)        # the red coat
LEATHER = (0.330, 0.210, 0.128)     # apron and boots
BRASS = (0.760, 0.560, 0.210)
IRON = (0.300, 0.305, 0.318)        # oiled iron, lighter than the Valkyr's
CRYSTAL = (0.280, 0.720, 0.930)
HAIR = (0.855, 0.840, 0.812)        # white beard, off the reference

M_COAT, M_LEATHER, M_BRASS, M_IRON, M_CRYSTAL, M_SKIN, M_HAIR = range(7)


def _materials():
    T.register("tinker_coat", lambda: T.cloth(COAT, seed=331, folds=8.0))
    T.register("tinker_leather", lambda: T.leather(LEATHER, seed=337))
    T.register("tinker_brass", lambda: T.plate(BRASS, seed=347, panel=12.0))
    T.register("tinker_iron", lambda: T.plate(IRON, seed=349, panel=8.0))
    T.register("tinker_crystal", lambda: T.glow(CRYSTAL, seed=353))
    T.register("tinker_hair", lambda: T.fur(HAIR, seed=359, clumps=28.0))
    return [
        K.material("tinker_coat", "KM_tinker_coat"),
        K.material("tinker_leather", "KM_tinker_leather"),
        K.material("tinker_brass", "KM_tinker_brass"),
        K.material("tinker_iron", "KM_tinker_iron"),
        K.material("tinker_crystal", "KM_tinker_crystal"),
        K.material("skin", "KM_skin"),
        K.material("tinker_hair", "KM_tinker_hair"),
    ]


def build():
    K.new_scene()
    mats = _materials()

    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    body._torso(bm, uv, skin_mat=M_SKIN, cloth_mat=M_COAT)
    body._head(bm, uv, skin_mat=M_SKIN, cloth_mat=M_COAT)
    for side in C.SIDES:
        body._arm(bm, uv, side, skin_mat=M_SKIN, cloth_mat=M_COAT)
        body._leg(bm, uv, side, skin_mat=M_LEATHER, cloth_mat=M_LEATHER)

    _coat(bm, uv)
    A.beard(bm, uv, M_HAIR, length=1.47, fullness=1.1)
    _goggles(bm, uv)
    A.pack(bm, uv, M_IRON, M_BRASS)
    # Crystal glowing in the canisters, and one in the pack's face.
    for side in (-1, 1):
        C.tube(bm, uv, [((side * 0.115, -0.30, 1.16), 0.030, 0.030),
                        ((side * 0.115, -0.30, 1.34), 0.030, 0.030)],
               C.X, C.Y, 8, mat=M_CRYSTAL, cap_start=True, cap_end=True)

    for side in C.SIDES:
        _boot(bm, uv, side)
    _gauntlet(bm, uv, 1)        # right arm only, on purpose
    _light_bracer(bm, uv, -1)

    mesh = C.finish_char(bm, NAME, mats)
    mesh.name = "Body"
    arm_obj = R.build_armature("Armature")
    R.skin(mesh, arm_obj)
    bpy.context.view_layer.update()
    return [arm_obj, mesh]


def _coat(bm, uv):
    # Coat body over the torso, then a knee-length skirt split at the front.
    A.shell(bm, uv, [((0, 0, 1.46), 0.238, 0.164),
                     ((0, 0, 1.22), 0.214, 0.150),
                     ((0, 0, 1.02), 0.190, 0.138)],
            C.X, C.Y, 12, M_COAT)
    A.skirt(bm, uv, 1.03, 0.56, 0.192, 0.238, M_COAT, n=12)

    # Leather apron hanging down the front -- the Tinker reads as a smith.
    A.shell(bm, uv, [((0, 0.140, 1.34), 0.118, 0.030),
                     ((0, 0.156, 1.02), 0.140, 0.030),
                     ((0, 0.168, 0.72), 0.132, 0.028),
                     ((0, 0.170, 0.60), 0.090, 0.024)],
            C.X, C.Y, 6, M_LEATHER, cap_start=True, cap_end=True)

    # Brass belt and buckle.
    A.shell(bm, uv, [((0, 0, 1.00), 0.196, 0.142),
                     ((0, 0, 1.062), 0.200, 0.146)],
            C.X, C.Y, 12, M_BRASS)


def _goggles(bm, uv):
    """Goggles pushed up on the forehead, off the reference sheet."""
    A.shell(bm, uv, [((0, 0, 1.735), 0.122, 0.128),
                     ((0, 0, 1.775), 0.120, 0.126)],
            C.X, C.Y, 12, M_LEATHER)
    for side in (-1, 1):
        C.tube(bm, uv, [((side * 0.052, 0.100, 1.755), 0.040, 0.040),
                        ((side * 0.052, 0.128, 1.755), 0.040, 0.040)],
               C.X, C.Z, 8, mat=M_BRASS, cap_start=True, cap_end=True)


def _gauntlet(bm, uv, side):
    """The big mechanical arm -- oversized on purpose, like the reference."""
    u, v = C.Y, C.Z
    A.shell(bm, uv, [((side * 0.30, 0, 1.430), 0.110, 0.110),
                     ((side * 0.46, 0, 1.428), 0.118, 0.118),
                     ((side * 0.60, 0, 1.426), 0.126, 0.126)],
            u, v, 8, M_IRON)
    # Brass barrel bands and the fist.
    for x in (0.50, 0.66):
        C.tube(bm, uv, [((side * x, 0, 1.426), 0.132, 0.132),
                        ((side * (x + 0.035), 0, 1.426), 0.132, 0.132)],
               u, v, 8, mat=M_BRASS, cap_start=False, cap_end=False)
    C.tube(bm, uv, [((side * 0.72, 0, 1.425), 0.120, 0.118),
                    ((side * 0.86, 0, 1.425), 0.132, 0.128),
                    ((side * 0.95, 0, 1.425), 0.096, 0.092)],
           u, v, 8, mat=M_IRON, cap_start=True, cap_end=True)
    # Crystal core set into the forearm.
    C.tube(bm, uv, [((side * 0.56, 0.075, 1.426), 0.048, 0.048),
                    ((side * 0.56, 0.105, 1.426), 0.040, 0.040)],
           C.X, C.Z, 8, mat=M_CRYSTAL, cap_start=True, cap_end=True)


def _light_bracer(bm, uv, side):
    """The other arm stays light, so the two never read as a matched pair."""
    A.shell(bm, uv, [((side * 0.48, 0, 1.425), 0.076, 0.078),
                     ((side * 0.66, 0, 1.425), 0.066, 0.068),
                     ((side * 0.78, 0, 1.425), 0.058, 0.056)],
            C.Y, C.Z, 8, M_LEATHER)


def _boot(bm, uv, side):
    x = side * 0.098
    A.shell(bm, uv, [((x, 0, 0.46), 0.092, 0.096),
                     ((x, 0, 0.28), 0.082, 0.086),
                     ((x, 0, 0.10), 0.072, 0.074)],
            C.X, C.Y, 8, M_LEATHER)
    # Iron toe cap.
    C.tube(bm, uv, [((x, 0.02, 0.055), 0.066, 0.058),
                    ((x, 0.16, 0.045), 0.058, 0.040)],
           C.X, C.Z, 8, mat=M_IRON, cap_start=True, cap_end=True)


if __name__ == "__main__":
    print(K.report(build()))
