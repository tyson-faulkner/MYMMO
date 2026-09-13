"""Enemy variants on the shared body -- step 7 of the character spec.

docs/kingsmourn-enemy-weapon-spec.md: every human enemy is the base body
with a different texture and ONE silhouette tell. No new meshes, rigs or
clips -- each variant here is the same skinned body the classes use, so the
shared animation set plays on all of them.

Each builder returns [armature, mesh], ready for km_build with ANIMATE=True.
"""

import bpy
import bmesh

import km_kit as K
import km_char as C
import km_armour as A
import km_rig as R
import km_textures as T
import char_01_base_body as body

# Palettes from the spec.
WOOL = (0.58, 0.52, 0.42)
LEATHER = (0.40, 0.30, 0.20)
LEATHER_DARK = (0.28, 0.20, 0.14)
STEEL = (0.55, 0.56, 0.58)
STAG_GREEN = (0.16, 0.36, 0.22)
SUNBURST_BLUE = (0.14, 0.22, 0.55)
MAIL = (0.46, 0.47, 0.50)
VIOLET_ROBE = (0.30, 0.20, 0.40)
BONE = (0.86, 0.84, 0.78)
COLD_EYE = (0.70, 0.85, 1.00)
COLD_EYE_BRIGHT = (0.86, 0.94, 1.00)
WRAP_GREY = (0.44, 0.44, 0.42)
WRAP_BLACK = (0.10, 0.10, 0.11)
VERDIGRIS = (0.34, 0.52, 0.42)
TARNISH = (0.50, 0.52, 0.55)
OXBLOOD = (0.42, 0.10, 0.10)
GILT_GREEN = (0.44, 0.52, 0.28)
WHITE = (0.92, 0.92, 0.90)


def _mats(specs):
    """[(name, builder)] -> materials, registering each texture on the way."""
    mats = []
    for name, builder in specs:
        if builder is not None:
            T.register(name, builder)
        mats.append(K.material(name, "KM_%s" % name))
    return mats


def _body(bm, uv, skin, cloth, head=None):
    body._torso(bm, uv, skin_mat=skin, cloth_mat=cloth)
    body._head(bm, uv, skin_mat=skin if head is None else head, cloth_mat=cloth)
    for side in C.SIDES:
        body._arm(bm, uv, side, skin_mat=skin, cloth_mat=cloth)
        body._leg(bm, uv, side, skin_mat=skin, cloth_mat=cloth)


def _finish(bm, name, mats):
    mesh = C.finish_char(bm, name, mats)
    mesh.name = "Body"
    arm_obj = R.build_armature("Armature")
    R.skin(mesh, arm_obj)
    bpy.context.view_layer.update()
    return [arm_obj, mesh]


# ---------------------------------------------------------------- pieces ---
def _cloak(bm, uv, mat, length=1.12):
    """A panel hanging from the shoulder blades down the back."""
    A.shell(bm, uv, [((0, -0.150, 1.47), 0.210, 0.030),
                     ((0, -0.185, 1.15), 0.235, 0.030),
                     ((0, -0.215, 0.70), 0.250, 0.030),
                     ((0, -0.235, 1.47 - length), 0.235, 0.028)],
            C.X, C.Y, 8, mat, cap_start=True, cap_end=True)


def _tabard(bm, uv, mat, device_mat):
    """Front panel with a house device on the chest."""
    A.shell(bm, uv, [((0, 0.150, 1.40), 0.160, 0.024),
                     ((0, 0.155, 1.05), 0.165, 0.024),
                     ((0, 0.160, 0.72), 0.150, 0.022)],
            C.X, C.Y, 6, mat, cap_start=True, cap_end=True)
    A.shell(bm, uv, [((0, 0.176, 1.32), 0.070, 0.012),
                     ((0, 0.179, 1.16), 0.070, 0.012)],
            C.X, C.Y, 6, device_mat, cap_start=True, cap_end=True)


def _boots(bm, uv, side, mat):
    x = side * 0.098
    A.shell(bm, uv, [((x, 0, 0.53), 0.090, 0.094),
                     ((x, 0, 0.30), 0.078, 0.082),
                     ((x, 0, 0.09), 0.066, 0.068)],
            C.X, C.Y, 8, mat)


def _pauldron(bm, uv, side, mat, rim_mat=None):
    if rim_mat is not None:
        A.pauldron(bm, uv, side, (side * 0.20, 0.0, 1.44), 0.141, 0.225, rim_mat)
    A.pauldron(bm, uv, side, (side * 0.20, 0.0, 1.44), 0.135, 0.20, mat)


def _kettle_helm(bm, uv, mat):
    C.tube(bm, uv, [((0, 0, 1.70), 0.122, 0.128),
                    ((0, 0, 1.78), 0.108, 0.112),
                    ((0, 0, 1.84), 0.060, 0.062),
                    ((0, 0, 1.86), 0.020, 0.020)],
           C.X, C.Y, 12, mat=mat, cap_start=False, cap_end=True)
    C.tube(bm, uv, [((0, 0, 1.695), 0.205, 0.205),
                    ((0, 0, 1.715), 0.205, 0.205)],
           C.X, C.Y, 12, mat=mat, cap_start=True, cap_end=True)


def _closed_helm(bm, uv, mat):
    C.tube(bm, uv, [((0, 0, 1.575), 0.082, 0.080),
                    ((0, 0.004, 1.63), 0.103, 0.110),
                    ((0, 0.006, 1.70), 0.124, 0.131),
                    ((0, 0.004, 1.755), 0.116, 0.122),
                    ((0, 0, 1.795), 0.074, 0.078),
                    ((0, 0, 1.815), 0.026, 0.028)],
           C.X, C.Y, 12, mat=mat, cap_start=False, cap_end=True)


def _visor(bm, uv, mat):
    C.tube(bm, uv, [((-0.075, 0.125, 1.672), 0.012, 0.010),
                    ((0.0, 0.150, 1.672), 0.014, 0.012),
                    ((0.075, 0.125, 1.672), 0.012, 0.010)],
           C.Y, C.Z, 6, mat=mat, cap_start=True, cap_end=True)


def _eyes(bm, uv, mat):
    for side in (-1, 1):
        C.tube(bm, uv, [((side * 0.040, 0.118, 1.672), 0.018, 0.013),
                        ((side * 0.040, 0.134, 1.672), 0.013, 0.009)],
               C.X, C.Z, 6, mat=mat, cap_start=True, cap_end=True)


def _fetishes(bm, uv, mat):
    for x, y in ((0.12, 0.10), (0.16, 0.02), (-0.14, 0.08)):
        C.tube(bm, uv, [((x, y, 1.00), 0.018, 0.018),
                        ((x * 1.05, y * 1.05, 0.88), 0.014, 0.014),
                        ((x * 1.10, y * 1.10, 0.82), 0.022, 0.022)],
               C.X, C.Y, 6, mat=mat, cap_start=True, cap_end=True)


def _purse(bm, uv, mat):
    C.tube(bm, uv, [((-0.170, 0.06, 1.00), 0.045, 0.030),
                    ((-0.176, 0.06, 0.90), 0.050, 0.035),
                    ((-0.170, 0.06, 0.86), 0.030, 0.020)],
           C.X, C.Y, 8, mat=mat, cap_start=True, cap_end=True)


def _plume(bm, uv, mat):
    C.tube(bm, uv, [((0, 0.02, 1.85), 0.020, 0.020),
                    ((0, -0.08, 1.93), 0.035, 0.030),
                    ((0, -0.22, 1.86), 0.040, 0.030),
                    ((0, -0.33, 1.72), 0.020, 0.018)],
           C.X, C.Z, 6, mat=mat, cap_start=True, cap_end=True)


def _crown(bm, uv, mat):
    import math
    C.tube(bm, uv, [((0, 0, 1.775), 0.112, 0.116),
                    ((0, 0, 1.860), 0.118, 0.122)],
           C.X, C.Y, 10, mat=mat, cap_start=False, cap_end=False)
    for i in range(5):
        a = 2.0 * math.pi * i / 5.0
        cx, cy = math.cos(a) * 0.112, math.sin(a) * 0.116
        C.tube(bm, uv, [((cx, cy, 1.86), 0.022, 0.022),
                        ((cx * 1.04, cy * 1.04, 1.99), 0.005, 0.005)],
               C.X, C.Y, 5, mat=mat, cap_start=True, cap_end=True)


def _arm_band(bm, uv, side, mat):
    A.shell(bm, uv, [((side * 0.29, 0, 1.432), 0.093, 0.094),
                     ((side * 0.36, 0, 1.430), 0.091, 0.092)],
            C.Y, C.Z, 8, mat)


def _belt(bm, uv, mat):
    A.shell(bm, uv, [((0, 0, 1.01), 0.150, 0.104),
                     ((0, 0, 1.07), 0.152, 0.106)],
            C.X, C.Y, 12, mat)


def _breastplate(bm, uv, mat):
    A.shell(bm, uv, [((0, 0, 1.02), 0.152, 0.106),
                     ((0, 0, 1.16), 0.178, 0.122),
                     ((0, 0, 1.29), 0.212, 0.143),
                     ((0, 0, 1.40), 0.231, 0.158),
                     ((0, 0, 1.47), 0.238, 0.152)],
            C.X, C.Y, 12, mat)


# -------------------------------------------------------------- variants ---
def hedge_bandit():
    """Hood up, no armour: the lightest outline in the game."""
    mats = _mats([("en_wool", lambda: T.cloth(WOOL, seed=501, folds=7.0)),
                  ("skin", None),
                  ("en_leather", lambda: T.leather(LEATHER, seed=503)),
                  ("en_stag_scrap", lambda: T.cloth(STAG_GREEN, seed=505, folds=10.0))])
    WOOL_M, SKIN_M, LEATHER_M, SCRAP_M = range(4)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    _body(bm, uv, SKIN_M, WOOL_M)
    A.hood(bm, uv, WOOL_M, peak=1.88)
    _belt(bm, uv, LEATHER_M)
    _arm_band(bm, uv, 1, SCRAP_M)          # the last scrap of uniform
    return _finish(bm, "enemy_hedge_bandit", mats)


def bandit_cutthroat():
    """One looted pauldron, worn on the wrong shoulder."""
    mats = _mats([("en_leather_dark", lambda: T.leather(LEATHER_DARK, seed=507)),
                  ("skin", None),
                  ("en_steel", lambda: T.plate(STEEL, seed=509, panel=9.0)),
                  ("en_leather", None)])
    DARK_M, SKIN_M, STEEL_M, LEATHER_M = range(4)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    _body(bm, uv, SKIN_M, DARK_M)
    _belt(bm, uv, LEATHER_M)
    _pauldron(bm, uv, 1, STEEL_M)          # one only, and on the left
    for side in C.SIDES:
        _boots(bm, uv, side, LEATHER_M)
    return _finish(bm, "enemy_bandit_cutthroat", mats)


def stag_outrider():
    """Green cloak and tall riding boots: cavalry on foot."""
    mats = _mats([("en_leather", None),
                  ("skin", None),
                  ("en_stag_green", lambda: T.cloth(STAG_GREEN, seed=511, folds=8.0)),
                  ("en_white", lambda: T.plate(WHITE, seed=513, panel=14.0)),
                  ("en_leather_dark", None)])
    LEATHER_M, SKIN_M, GREEN_M, WHITE_M, DARK_M = range(5)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    _body(bm, uv, SKIN_M, LEATHER_M)
    _tabard(bm, uv, GREEN_M, WHITE_M)
    _cloak(bm, uv, GREEN_M)
    _belt(bm, uv, DARK_M)
    for side in C.SIDES:
        _boots(bm, uv, side, DARK_M)
    return _finish(bm, "enemy_stag_outrider", mats)


def sunburst_serjeant():
    """Gold-trimmed pauldrons and a kettle helm: visibly heavier than the Outrider."""
    mats = _mats([("en_mail", lambda: T.plate(MAIL, seed=515, panel=22.0)),
                  ("skin", None),
                  ("en_sunburst_blue", lambda: T.cloth(SUNBURST_BLUE, seed=517, folds=8.0)),
                  ("gold", None),
                  ("en_steel", None)])
    MAIL_M, SKIN_M, BLUE_M, GOLD_M, STEEL_M = range(5)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    _body(bm, uv, SKIN_M, MAIL_M)
    _tabard(bm, uv, BLUE_M, GOLD_M)
    for side in C.SIDES:
        _pauldron(bm, uv, side, STEEL_M, rim_mat=GOLD_M)
        _boots(bm, uv, side, STEEL_M)
    _kettle_helm(bm, uv, STEEL_M)
    _belt(bm, uv, GOLD_M)
    return _finish(bm, "enemy_sunburst_serjeant", mats)


def grave_binder():
    """Hooded violet robe, bone fetishes at the belt, one gold house-seal purse."""
    mats = _mats([("en_violet_robe", lambda: T.cloth(VIOLET_ROBE, seed=519, folds=11.0)),
                  ("skin", None),
                  ("en_bone", lambda: T.plate(BONE, seed=521, panel=13.0)),
                  ("gold", None)])
    ROBE_M, SKIN_M, BONE_M, GOLD_M = range(4)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    _body(bm, uv, SKIN_M, ROBE_M, head=SKIN_M)
    A.skirt(bm, uv, 1.02, 0.30, 0.166, 0.205, ROBE_M)
    A.hood(bm, uv, ROBE_M)
    _belt(bm, uv, BONE_M)
    _fetishes(bm, uv, BONE_M)
    _purse(bm, uv, GOLD_M)
    return _finish(bm, "enemy_grave_binder", mats)


def risen_levy():
    """The Hedge Bandit's exact outline in bone, in the same undyed wool."""
    mats = _mats([("en_wool", None),
                  ("en_bone", None),
                  ("en_cold_eye", lambda: T.glow(COLD_EYE, seed=523))])
    WOOL_M, BONE_M, EYE_M = range(3)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    _body(bm, uv, BONE_M, WOOL_M)
    A.hood(bm, uv, WOOL_M, peak=1.88)
    _eyes(bm, uv, EYE_M)
    A.ragged_hem(bm, uv, WOOL_M, 0.95, [0.22, 0.14, 0.19, 0.26, 0.16, 0.23, 0.13], 0.150, y_scale=0.7, blade_width=0.055)
    return _finish(bm, "enemy_risen_levy", mats)


def barrow_guardian():
    """Full helm, verdigris bronze, grey grave-wrappings, cold light in the visor."""
    mats = _mats([("en_wrap_grey", lambda: T.cloth(WRAP_GREY, seed=525, folds=13.0)),
                  ("en_bone", None),
                  ("en_verdigris", lambda: T.plate(VERDIGRIS, seed=527, panel=7.0)),
                  ("en_cold_eye", None)])
    WRAP_M, BONE_M, BRONZE_M, EYE_M = range(4)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    _body(bm, uv, BONE_M, WRAP_M)
    _breastplate(bm, uv, BRONZE_M)
    for side in C.SIDES:
        _pauldron(bm, uv, side, BRONZE_M)
        _boots(bm, uv, side, BRONZE_M)
    _closed_helm(bm, uv, BRONZE_M)
    _visor(bm, uv, EYE_M)
    return _finish(bm, "enemy_barrow_guardian", mats)


def barrow_wight():
    """A dead lord: long tattered cloak, near-black wrappings, tarnished silver."""
    mats = _mats([("en_wrap_black", lambda: T.cloth(WRAP_BLACK, seed=529, folds=13.0)),
                  ("en_bone", None),
                  ("en_tarnish", lambda: T.plate(TARNISH, seed=531, panel=10.0)),
                  ("en_cold_eye_bright", lambda: T.glow(COLD_EYE_BRIGHT, seed=533))])
    WRAP_M, BONE_M, SILVER_M, EYE_M = range(4)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    _body(bm, uv, BONE_M, WRAP_M)
    _cloak(bm, uv, WRAP_M, length=1.30)
    A.ragged_hem(bm, uv, WRAP_M, 0.30, [0.20, 0.12, 0.18, 0.24, 0.14], 0.235, y_scale=0.35, blade_width=0.070)
    _belt(bm, uv, SILVER_M)
    A.collar(bm, uv, 1.475, 0.115, 0.085, SILVER_M)
    _eyes(bm, uv, EYE_M)
    return _finish(bm, "enemy_barrow_wight", mats)


def captain_reyne():
    """A stolen officer's coat, a plumed helm, one good piece of plate."""
    mats = _mats([("en_oxblood", lambda: T.cloth(OXBLOOD, seed=535, folds=8.0)),
                  ("skin", None),
                  ("en_steel", None),
                  ("en_leather_dark", None),
                  ("en_plume", lambda: T.feather((0.60, 0.12, 0.12), seed=537))])
    COAT_M, SKIN_M, STEEL_M, DARK_M, PLUME_M = range(5)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    _body(bm, uv, SKIN_M, COAT_M)
    A.skirt(bm, uv, 1.02, 0.52, 0.166, 0.230, COAT_M)
    _pauldron(bm, uv, -1, STEEL_M)          # the one good piece
    _belt(bm, uv, DARK_M)
    for side in C.SIDES:
        _boots(bm, uv, side, DARK_M)
    _closed_helm(bm, uv, STEEL_M)
    _plume(bm, uv, PLUME_M)
    return _finish(bm, "enemy_captain_reyne", mats)


def the_first_king():
    """Gilded armour gone dull and green, deep shadow, and THE CROWN."""
    mats = _mats([("en_wrap_black", None),
                  ("en_bone", None),
                  ("en_gilt_green", lambda: T.plate(GILT_GREEN, seed=539, panel=6.0)),
                  ("gold", None),
                  ("en_cold_eye_bright", None)])
    WRAP_M, BONE_M, GILT_M, GOLD_M, EYE_M = range(5)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    _body(bm, uv, BONE_M, WRAP_M)
    _breastplate(bm, uv, GILT_M)
    for side in C.SIDES:
        _pauldron(bm, uv, side, GILT_M)
        _boots(bm, uv, side, GILT_M)
    _cloak(bm, uv, WRAP_M, length=1.35)
    A.skirt(bm, uv, 1.02, 0.70, 0.166, 0.215, GILT_M)
    _eyes(bm, uv, EYE_M)
    _crown(bm, uv, GOLD_M)
    return _finish(bm, "enemy_the_first_king", mats)


BUILDERS = {
    "enemy_hedge_bandit": hedge_bandit,
    "enemy_bandit_cutthroat": bandit_cutthroat,
    "enemy_stag_outrider": stag_outrider,
    "enemy_sunburst_serjeant": sunburst_serjeant,
    "enemy_grave_binder": grave_binder,
    "enemy_risen_levy": risen_levy,
    "enemy_barrow_guardian": barrow_guardian,
    "enemy_barrow_wight": barrow_wight,
    "enemy_captain_reyne": captain_reyne,
    "enemy_the_first_king": the_first_king,
}
