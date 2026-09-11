"""Character step 4 -- the Valkyr, tank.

Reference: docs/reference/01-characters/02-valkyr-dark-seraph.png.

Built first of the four because she is the most distinctive silhouette, so
she is the best test of whether armour-over-shared-body actually works.

From the spec: the widest of the four, heavy pauldrons, and WINGS as the
read-at-distance feature. Deliberately darker than the town's cream-and-blue
-- she is the one character who should look out of place in a sunlit market
square. Blackened plate, gold trim, deep violet cloth, pale wings.

Everything is added into the base body's mesh and skinned by the same
distance weighting, so the pauldrons follow the shoulders and the faulds
follow the hips without any extra rigging.
"""

import bpy
import bmesh

import km_kit as K
import km_char as C
import km_armour as A
import km_rig as R
import km_textures as T
import char_01_base_body as body

NAME = "char_valkyr"
OUT = "characters"
ANGLES = (90, -90)
ELEVATION = 6
APPLY_MODIFIERS = False

# Blackened plate, gold trim, deep violet cloth, pale wings.
PLATE = (0.105, 0.100, 0.115)
PLATE_LIT = (0.180, 0.172, 0.200)
GOLD = (0.831, 0.667, 0.259)
VIOLET = (0.205, 0.160, 0.310)
WING = (0.930, 0.925, 0.905)

M_PLATE, M_GOLD, M_CLOTH, M_WING, M_SKIN = 0, 1, 2, 3, 4


def _materials():
    T.register("valkyr_plate", lambda: T.plate(PLATE, seed=211, panel=6.0))
    T.register("valkyr_gold", lambda: T.plate(GOLD, seed=223, panel=11.0))
    T.register("valkyr_cloth", lambda: T.cloth(VIOLET, seed=227, folds=7.0))
    T.register("valkyr_wing", lambda: T.feather(WING, seed=229))
    return [
        K.material("valkyr_plate", "KM_valkyr_plate"),
        K.material("valkyr_gold", "KM_valkyr_gold"),
        K.material("valkyr_cloth", "KM_valkyr_cloth"),
        K.material("valkyr_wing", "KM_valkyr_wing"),
        K.material("skin", "KM_skin"),
    ]


def build():
    K.new_scene()
    mats = _materials()

    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    _under_body(bm, uv)
    _torso_armour(bm, uv)
    _helm(bm, uv)
    for side in C.SIDES:
        _arm_armour(bm, uv, side)
        _leg_armour(bm, uv, side)
        # Rooted on the shoulder BLADES, so behind the chest (-Y). An
        # earlier pass rooted them at +Y and the wings grew out of her front.
        A.wing(bm, uv, side, (side * 0.09, -0.11, 1.33), 0.98, M_WING)
    _faulds(bm, uv)
    A.halo(bm, uv, (0.0, 0.10, 1.76), 0.175, 0.016, M_GOLD)

    mesh = C.finish_char(bm, NAME, mats)
    mesh.name = "Body"

    arm_obj = R.build_armature("Armature")
    R.skin(mesh, arm_obj)
    bpy.context.view_layer.update()
    return [arm_obj, mesh]


def _under_body(bm, uv):
    """The parts of the base body that still show: head and a dark bodysuit.

    Reuses the body module's own section tables so the armour can never
    drift out of register with the mesh underneath it.
    """
    # The head stays skin (it sits inside the helm); everything else is the
    # dark bodysuit the plate is strapped over.
    body._torso(bm, uv, skin_mat=M_SKIN, cloth_mat=M_PLATE)
    body._head(bm, uv, skin_mat=M_SKIN, cloth_mat=M_PLATE)
    for side in C.SIDES:
        body._arm(bm, uv, side, skin_mat=M_PLATE, cloth_mat=M_PLATE)
        body._leg(bm, uv, side, skin_mat=M_PLATE, cloth_mat=M_PLATE)


def _torso_armour(bm, uv):
    # Breastplate: a shell standing just outside the chest, waist to collar.
    sections = [
        ((0, 0, 1.02), 0.152, 0.106),
        ((0, 0, 1.16), 0.178, 0.122),
        ((0, 0, 1.29), 0.212, 0.143),
        ((0, 0, 1.40), 0.231, 0.158),
        ((0, 0, 1.47), 0.238, 0.152),
    ]
    A.shell(bm, uv, sections, C.X, C.Y, 12, M_PLATE)

    # Gold sternum band and belt -- the trim that keeps her from reading
    # as a black blob at distance.
    A.shell(bm, uv, [((0, 0, 1.30), 0.216, 0.147),
                     ((0, 0, 1.345), 0.222, 0.150)], C.X, C.Y, 12, M_GOLD)
    A.shell(bm, uv, [((0, 0, 1.00), 0.158, 0.112),
                     ((0, 0, 1.055), 0.163, 0.116)], C.X, C.Y, 12, M_GOLD)

    A.collar(bm, uv, 1.475, 0.115, 0.085, M_PLATE)


def _helm(bm, uv):
    """Closed helm with a raised crest -- the head never reads as bare."""
    sections = [
        ((0, 0, 1.575), 0.082, 0.080),
        ((0, 0.004, 1.63), 0.103, 0.110),
        ((0, 0.006, 1.70), 0.124, 0.131),
        ((0, 0.004, 1.755), 0.116, 0.122),
        ((0, 0, 1.795), 0.074, 0.078),
        ((0, 0, 1.815), 0.026, 0.028),
    ]
    C.tube(bm, uv, sections, C.X, C.Y, 12, mat=M_PLATE,
           cap_start=False, cap_end=True)

    # Crest running front to back over the crown.
    A.shell(bm, uv, [((0, 0.10, 1.70), 0.016, 0.030),
                     ((0, 0.02, 1.83), 0.016, 0.052),
                     ((0, -0.09, 1.80), 0.016, 0.040)],
            C.X, C.Z, 6, M_GOLD, cap_start=True, cap_end=True)


def _arm_armour(bm, uv, side):
    # Gold shell slightly larger and longer than the black one laid over it,
    # so only its edge shows and it reads as a rim. Built the other way
    # round first, where it stuck out as a separate gold wedge.
    A.pauldron(bm, uv, side, (side * 0.20, 0.0, 1.44), 0.141, 0.225, M_GOLD)
    A.pauldron(bm, uv, side, (side * 0.20, 0.0, 1.44), 0.135, 0.20, M_PLATE)

    # Vambrace on the forearm.
    u, v = C.Y, C.Z
    A.shell(bm, uv, [((side * 0.50, 0, 1.425), 0.074, 0.076),
                     ((side * 0.62, 0, 1.425), 0.066, 0.068),
                     ((side * 0.74, 0, 1.425), 0.054, 0.056)],
            u, v, 8, M_PLATE)
    # Gauntlet over the hand.
    A.shell(bm, uv, [((side * 0.76, 0, 1.425), 0.058, 0.048),
                     ((side * 0.86, 0, 1.425), 0.054, 0.042)],
            u, v, 8, M_PLATE)


def _leg_armour(bm, uv, side):
    x = side * 0.098
    # Cuisse over the thigh, greave over the shin, sabaton over the foot.
    A.shell(bm, uv, [((x, 0, 0.88), 0.112, 0.110),
                     ((x, 0, 0.70), 0.104, 0.104),
                     ((x, 0, 0.55), 0.090, 0.094)],
            C.X, C.Y, 8, M_PLATE)
    A.shell(bm, uv, [((x, 0, 0.46), 0.088, 0.092),
                     ((x, 0, 0.30), 0.075, 0.079),
                     ((x, 0, 0.14), 0.062, 0.064)],
            C.X, C.Y, 8, M_PLATE)
    # Knee cop, in gold so the leg has a highlight.
    A.shell(bm, uv, [((x, 0, 0.505), 0.090, 0.094),
                     ((x, 0, 0.455), 0.092, 0.096)],
            C.X, C.Y, 8, M_GOLD)


def _faulds(bm, uv):
    """Armoured skirt over a long violet tabard.

    The tabard is what carries her colour below the waist; without it the
    lower half is a black silhouette with nothing in it.
    """
    A.skirt(bm, uv, 1.02, 0.78, 0.166, 0.215, M_PLATE, n=12)
    # Front and back tabard panels. Widened and lengthened from a first pass
    # where they read as a small bib rather than a hanging banner.
    for facing in (1, -1):
        A.shell(bm, uv, [((0, facing * 0.090, 1.02), 0.112, 0.026),
                         ((0, facing * 0.125, 0.74), 0.124, 0.024),
                         ((0, facing * 0.138, 0.44), 0.108, 0.020),
                         ((0, facing * 0.140, 0.30), 0.052, 0.018)],
                C.X, C.Y, 6, M_CLOTH, cap_start=True, cap_end=True)


if __name__ == "__main__":
    print(K.report(build()))
