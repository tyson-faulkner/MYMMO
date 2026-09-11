"""Character step 5c -- the Bard, "Storm Skald", healer.

Reference: docs/reference/01-characters/01-bard-storm-skald.png.

From the spec: the lightest of the four. Long coat, no heavy plate, and an
instrument on the back socket so the role reads even from behind.

Palette note: the spec text says "storm blues and silver, weathered
leather", while the approved reference sheet is a deep crimson coat with
blue panels, gold trim and a heavy fur mantle. The reference is the
approved visual direction, so this follows it -- crimson and gold with the
storm-blue carried on the coat panels, the drum head and the rune light.

Silhouette: no pauldrons at all, a fur mantle instead, a flared knee-length
coat, and the drum on his back. Light on top, wide at the hem -- the
opposite shape to the Valkyr.
"""

import bpy
import bmesh

import km_kit as K
import km_char as C
import km_armour as A
import km_rig as R
import km_textures as T
import char_01_base_body as body

NAME = "char_bard"
OUT = "characters"
ANGLES = (90, -90)
ELEVATION = 6
APPLY_MODIFIERS = False
ANIMATE = True            # the shared clip set, from km_anim.py

COAT = (0.455, 0.105, 0.132)        # deep crimson
PANEL = (0.135, 0.190, 0.400)       # storm blue
GOLD = (0.820, 0.650, 0.250)
FUR = (0.310, 0.262, 0.228)
LEATHER = (0.300, 0.195, 0.122)
RUNE = (0.300, 0.560, 0.960)
HAIR = (0.860, 0.845, 0.815)        # white beard and hair, off the reference

M_COAT, M_PANEL, M_GOLD, M_FUR, M_LEATHER, M_RUNE, M_SKIN, M_HAIR = range(8)


def _materials():
    T.register("bard_coat", lambda: T.cloth(COAT, seed=361, folds=8.0))
    T.register("bard_panel", lambda: T.cloth(PANEL, seed=367, folds=12.0))
    T.register("bard_gold", lambda: T.plate(GOLD, seed=373, panel=12.0))
    T.register("bard_fur", lambda: T.fur(FUR, seed=379))
    T.register("bard_leather", lambda: T.leather(LEATHER, seed=383))
    T.register("bard_rune", lambda: T.glow(RUNE, seed=389))
    T.register("bard_hair", lambda: T.fur(HAIR, seed=397, clumps=30.0))
    return [
        K.material("bard_coat", "KM_bard_coat"),
        K.material("bard_panel", "KM_bard_panel"),
        K.material("bard_gold", "KM_bard_gold"),
        K.material("bard_fur", "KM_bard_fur"),
        K.material("bard_leather", "KM_bard_leather"),
        K.material("bard_rune", "KM_bard_rune"),
        K.material("skin", "KM_skin"),
        K.material("bard_hair", "KM_bard_hair"),
    ]


def build():
    K.new_scene()
    mats = _materials()

    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    body._torso(bm, uv, skin_mat=M_SKIN, cloth_mat=M_PANEL)
    body._head(bm, uv, skin_mat=M_SKIN, cloth_mat=M_PANEL)
    for side in C.SIDES:
        body._arm(bm, uv, side, skin_mat=M_SKIN, cloth_mat=M_PANEL)
        body._leg(bm, uv, side, skin_mat=M_LEATHER, cloth_mat=M_LEATHER)

    _coat(bm, uv)
    A.mantle(bm, uv, M_FUR)
    _drum(bm, uv)
    A.beard(bm, uv, M_HAIR, length=1.44, fullness=1.05)
    for side in C.SIDES:
        _sleeve(bm, uv, side)
        _boot(bm, uv, side)

    mesh = C.finish_char(bm, NAME, mats)
    mesh.name = "Body"
    arm_obj = R.build_armature("Armature")
    R.skin(mesh, arm_obj)
    bpy.context.view_layer.update()
    return [arm_obj, mesh]


def _coat(bm, uv):
    A.shell(bm, uv, [((0, 0, 1.44), 0.234, 0.160),
                     ((0, 0, 1.20), 0.208, 0.146),
                     ((0, 0, 1.02), 0.186, 0.136)],
            C.X, C.Y, 12, M_COAT)
    # Wide flared skirt -- the hem is the Bard's silhouette, not his shoulders.
    A.skirt(bm, uv, 1.03, 0.52, 0.190, 0.268, M_COAT, n=12)

    # Blue front panel and gold edging down the opening.
    A.shell(bm, uv, [((0, 0.144, 1.40), 0.070, 0.026),
                     ((0, 0.156, 1.05), 0.078, 0.026),
                     ((0, 0.190, 0.70), 0.084, 0.024),
                     ((0, 0.205, 0.54), 0.078, 0.022)],
            C.X, C.Y, 6, M_PANEL, cap_start=True, cap_end=True)
    A.shell(bm, uv, [((0, 0, 1.00), 0.190, 0.140),
                     ((0, 0, 1.058), 0.194, 0.144)],
            C.X, C.Y, 12, M_LEATHER)
    A.shell(bm, uv, [((0, 0.128, 1.012), 0.044, 0.036),
                     ((0, 0.150, 1.046), 0.044, 0.036)],
            C.X, C.Y, 8, M_GOLD)


def _sleeve(bm, uv, side):
    """Flared cuffs, gold banded -- decorative, never armoured."""
    A.shell(bm, uv, [((side * 0.24, 0, 1.435), 0.112, 0.112),
                     ((side * 0.44, 0, 1.430), 0.096, 0.096),
                     ((side * 0.58, 0, 1.426), 0.104, 0.104)],
            C.Y, C.Z, 8, M_COAT)
    C.tube(bm, uv, [((side * 0.58, 0, 1.426), 0.108, 0.108),
                    ((side * 0.64, 0, 1.426), 0.100, 0.100)],
           C.Y, C.Z, 8, mat=M_GOLD, cap_start=False, cap_end=False)
    A.shell(bm, uv, [((side * 0.66, 0, 1.425), 0.072, 0.074),
                     ((side * 0.78, 0, 1.425), 0.062, 0.062)],
            C.Y, C.Z, 8, M_LEATHER)


def _drum(bm, uv):
    """The instrument on his back -- the spec's "reads even from behind"."""
    C.tube(bm, uv, [((0, -0.215, 1.24), 0.150, 0.150),
                    ((0, -0.295, 1.24), 0.150, 0.150)],
           C.X, C.Z, 14, mat=M_LEATHER, cap_start=True, cap_end=True)
    # Drum head and a rune glowing on it.
    C.tube(bm, uv, [((0, -0.300, 1.24), 0.142, 0.142),
                    ((0, -0.312, 1.24), 0.138, 0.138)],
           C.X, C.Z, 14, mat=M_GOLD, cap_start=False, cap_end=True)
    C.tube(bm, uv, [((0, -0.314, 1.24), 0.062, 0.062),
                    ((0, -0.322, 1.24), 0.052, 0.052)],
           C.X, C.Z, 10, mat=M_RUNE, cap_start=False, cap_end=True)
    # Gold hoops around the shell.
    for y in (-0.235, -0.275):
        C.tube(bm, uv, [((0, y, 1.24), 0.156, 0.156),
                        ((0, y - 0.016, 1.24), 0.156, 0.156)],
               C.X, C.Z, 14, mat=M_GOLD, cap_start=False, cap_end=False)


def _boot(bm, uv, side):
    x = side * 0.098
    A.shell(bm, uv, [((x, 0, 0.50), 0.098, 0.102),
                     ((x, 0, 0.30), 0.084, 0.088),
                     ((x, 0, 0.10), 0.074, 0.076)],
            C.X, C.Y, 8, M_LEATHER)
    # Fur cuff at the top of the boot.
    C.tube(bm, uv, [((x, 0, 0.48), 0.106, 0.110),
                    ((x, 0, 0.54), 0.108, 0.112)],
           C.X, C.Y, 8, mat=M_FUR, cap_start=False, cap_end=False)


if __name__ == "__main__":
    print(K.report(build()))

