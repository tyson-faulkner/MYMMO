"""Ironveil class weapons -- the eight models that hang off the sockets.

All modelled in socket space: the origin is where the hand (or the back
socket) is, +Z is up, +Y is the character's forward, X across. Godot then
places each under its BoneAttachment3D with a +90 degree turn about X, which
is exactly the glTF Z-up-to-Y-up conversion undone -- so "up" here is up on
the rig, and the spear stands vertical at rest as the spec asks.

Oversized on purpose (the art rule): a correctly sized weapon looks too small.
"""

import math
import bmesh
from mathutils import Matrix, Vector
import km_kit as K
import km_textures as T

# Palette, per docs/ironveil-enemy-weapon-spec.md.
DARK_STEEL = (0.30, 0.31, 0.35)
SILVER = (0.78, 0.80, 0.84)
BONE = (0.86, 0.82, 0.72)
VIOLET = (0.36, 0.22, 0.50)
STORM = (0.18, 0.30, 0.58)
BRASS = (0.72, 0.55, 0.25)
ORANGE = (0.95, 0.52, 0.18)
LEATHER = (0.42, 0.28, 0.16)
DARK_WOOD = (0.26, 0.17, 0.10)


def register():
    T.register("wpn_dark_steel", lambda: T.plate(DARK_STEEL, seed=403, panel=7.0))
    T.register("wpn_silver", lambda: T.plate(SILVER, seed=421, panel=11.0))
    T.register("wpn_bone", lambda: T.plate(BONE, seed=313, panel=13.0))
    T.register("wpn_violet", lambda: T.cloth(VIOLET, seed=409, folds=14.0))
    T.register("wpn_storm", lambda: T.leather(STORM, seed=411))
    T.register("wpn_brass", lambda: T.plate(BRASS, seed=347, panel=12.0))
    T.register("wpn_orange", lambda: T.glow(ORANGE, seed=431))
    T.register("wpn_leather", lambda: T.leather(LEATHER, seed=337))
    T.register("wpn_dark_wood", lambda: T.cloth(DARK_WOOD, seed=437, folds=3.0))


def _oct(r, phase=22.5):
    return [(math.cos(a) * r, math.sin(a) * r) for a in
            [math.radians(phase + 45 * i) for i in range(8)]]


def rod(bm, r, z0, z1, mat, phase=22.5):
    """Octagonal shaft along Z."""
    return K.prism(bm, _oct(r, phase), "z", z0, z1, mat)


def rod_y(bm, r, y0, y1, mat):
    """Octagonal shaft along Y (barrels, gear axles)."""
    return K.prism(bm, _oct(r), "y", y0, y1, mat)


def blob(bm, centre, radius, mat, subdivisions=1):
    res = bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=radius,
                                     matrix=Matrix.Translation(Vector(centre)))
    for v in res["verts"]:
        for f in v.link_faces:
            f.material_index = mat


def _finish(bm, name, mats, tile=0.5):
    return K.finish(bm, name, mats, tile=tile)


# ---------------------------------------------------------------- Valkyr ---
def valkyr_spear():
    """2.8m leaf-headed spear: dark steel, gold binding at the grip."""
    register()
    mats = K.materials("wpn_dark_wood", "wpn_dark_steel", "gold", "iron")
    bm = bmesh.new()
    rod(bm, 0.035, -0.85, 1.45, 0)                       # shaft
    rod(bm, 0.048, -0.14, 0.14, 2)                       # gold grip binding
    rod(bm, 0.044, 1.30, 1.45, 2)                        # gold ferrule
    rod(bm, 0.042, -0.95, -0.85, 3)                      # iron butt
    leaf = [(0.0, 1.45), (0.09, 1.55), (0.11, 1.72), (0.07, 1.88), (0.0, 2.0),
            (-0.07, 1.88), (-0.11, 1.72), (-0.09, 1.55)]
    K.prism(bm, leaf, "y", -0.018, 0.018, 1)             # leaf head
    K.box(bm, (-0.012, -0.03, 1.48), (0.012, 0.03, 1.86), 1)   # central rib
    return [_finish(bm, "valkyr_spear", mats)]


def valkyr_shield():
    """Tall kite shield, dark face, gold rim and boss. Faces +Y (outward)."""
    register()
    mats = K.materials("wpn_dark_steel", "gold", "iron")
    bm = bmesh.new()
    kite = [(-0.34, 0.48), (0.34, 0.48), (0.38, 0.30), (0.22, -0.34), (0.0, -0.66),
            (-0.22, -0.34), (-0.38, 0.30)]
    inner = [(x * 0.84, y * 0.86 + 0.02) for x, y in kite]
    K.prism(bm, kite, "y", 0.03, 0.075, 1)               # gold plate (rim shows)
    K.prism(bm, inner, "y", 0.075, 0.095, 0)             # dark face inset
    K.prism(bm, _oct(0.085), "y", 0.095, 0.15, 1)        # boss
    K.box(bm, (-0.20, -0.02, -0.05), (0.20, 0.03, 0.05), 2)   # grip bar (behind)
    K.box(bm, (-0.04, -0.06, -0.12), (0.04, 0.03, 0.12), 2)   # strap
    return [_finish(bm, "valkyr_shield", mats)]


# ------------------------------------------------------------------ Bard ---
def bard_blade():
    """Short straight blade, silver and worn, leather grip, gold pommel."""
    register()
    mats = K.materials("wpn_silver", "wpn_dark_steel", "wpn_leather", "gold")
    bm = bmesh.new()
    blade = [(-0.035, 0.08), (0.035, 0.08), (0.035, 0.60), (0.0, 0.82), (-0.035, 0.60)]
    K.prism(bm, blade, "y", -0.007, 0.007, 0)
    K.box(bm, (-0.007, -0.016, 0.10), (0.007, 0.016, 0.62), 1)   # fuller ridge
    K.box(bm, (-0.11, -0.025, 0.055), (0.11, 0.025, 0.085), 1)    # guard
    rod(bm, 0.024, -0.14, 0.055, 2)                                 # grip
    K.box(bm, (-0.04, -0.04, -0.20), (0.04, 0.04, -0.14), 3)      # pommel
    return [_finish(bm, "bard_blade", mats)]


def bard_lute():
    """Storm-blue lacquered lute for the back socket, face outward (+Y)."""
    register()
    mats = K.materials("wpn_storm", "timber", "wpn_silver", "gold")
    bm = bmesh.new()
    cy = 0.10                                            # stand-off from the back
    body = [(-0.24, -0.30), (-0.26, -0.12), (-0.18, 0.06), (-0.10, 0.14), (0.10, 0.14),
            (0.18, 0.06), (0.26, -0.12), (0.24, -0.30), (0.12, -0.42), (-0.12, -0.42)]
    K.prism(bm, body, "y", cy, cy + 0.13, 0)              # bowl
    K.box(bm, (-0.035, cy + 0.10, 0.10), (0.035, cy + 0.145, 0.70), 1)   # neck
    K.box(bm, (-0.06, cy + 0.09, 0.70), (0.06, cy + 0.15, 0.86), 1)      # head
    K.box(bm, (-0.10, cy + 0.13, -0.24), (0.10, cy + 0.16, -0.21), 3)    # bridge
    for i in range(4):
        x = -0.045 + i * 0.03
        K.box(bm, (x - 0.004, cy + 0.146, -0.22), (x + 0.004, cy + 0.154, 0.72), 2)  # strings
    for i in range(2):
        for sx in (-1, 1):
            K.box(bm, (sx * 0.06 - 0.015, cy + 0.09, 0.74 + i * 0.05), (sx * 0.085, cy + 0.15, 0.76 + i * 0.05), 3)  # pegs
    return [_finish(bm, "bard_lute", mats)]


# ----------------------------------------------------------- Necromancer ---
def necromancer_staff():
    """Tall dark staff, violet cord, a skull bound at the head."""
    register()
    mats = K.materials("wpn_dark_wood", "wpn_violet", "wpn_bone", "wpn_orange")
    bm = bmesh.new()
    rod(bm, 0.032, -0.75, 1.32, 0)
    for z in (-0.10, 0.02, 0.14, 0.95, 1.07, 1.19):
        rod(bm, 0.041, z, z + 0.06, 1)                   # cord wraps
    # Four bone prongs cradling the skull.
    for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        K.box(bm, (sx * 0.05 - 0.02, sy * 0.05 - 0.02, 1.32), (sx * 0.05 + 0.02, sy * 0.05 + 0.02, 1.62), 2)
    blob(bm, (0.0, 0.0, 1.50), 0.15, 2)                  # skull
    K.box(bm, (-0.08, 0.10, 1.50), (-0.03, 0.16, 1.56), 3)   # eyes (front = +Y)
    K.box(bm, (0.03, 0.10, 1.50), (0.08, 0.16, 1.56), 3)
    return [_finish(bm, "necromancer_staff", mats)]


def necromancer_skull():
    """Hand-held skull focus on a short bound handle."""
    register()
    mats = K.materials("wpn_dark_wood", "wpn_violet", "wpn_bone", "wpn_orange")
    bm = bmesh.new()
    rod(bm, 0.02, -0.16, 0.14, 0)
    rod(bm, 0.028, -0.06, 0.06, 1)
    blob(bm, (0.0, 0.0, 0.27), 0.13, 2)
    K.box(bm, (-0.07, 0.09, 0.27), (-0.025, 0.14, 0.32), 3)
    K.box(bm, (0.025, 0.09, 0.27), (0.07, 0.14, 0.32), 3)
    return [_finish(bm, "necromancer_skull", mats)]


# ---------------------------------------------------------------- Tinker ---
def tinker_bolt_thrower():
    """Cranked mechanical crossbow, brass and iron, held forward at the hip.
    Runs along +Y; the grip is at the origin."""
    register()
    mats = K.materials("iron", "wpn_brass", "timber", "wpn_orange")
    bm = bmesh.new()
    K.box(bm, (-0.05, -0.32, -0.08), (0.05, 0.10, 0.04), 2)        # stock
    K.box(bm, (-0.075, 0.05, -0.03), (0.075, 0.60, 0.11), 0)        # body
    K.box(bm, (-0.03, 0.10, 0.11), (0.03, 0.62, 0.15), 1)           # rail
    K.box(bm, (-0.085, 0.36, 0.11), (0.085, 0.56, 0.26), 1)         # magazine
    # Bow arms: swept back from the front of the body.
    for sx in (-1, 1):
        arm = [(sx * 0.07, 0.56), (sx * 0.42, 0.34), (sx * 0.42, 0.29), (sx * 0.07, 0.50)]
        K.prism(bm, arm, "z", 0.02, 0.06, 0)
        K.box(bm, (min(sx * 0.40, sx * 0.44), 0.28, 0.0), (max(sx * 0.40, sx * 0.44), 0.36, 0.08), 3)  # orange tips
    K.box(bm, (-0.43, 0.30, 0.035), (0.43, 0.315, 0.045), 0)         # string
    # Gears on the right flank, and the crank.
    for cy, r in ((0.16, 0.09), (0.30, 0.07)):
        gear = [(cy + math.cos(a) * r, 0.04 + math.sin(a) * r) for a in
                [math.radians(22.5 + 45 * i) for i in range(8)]]
        K.prism(bm, gear, "x", 0.075, 0.105, 1)
    K.box(bm, (0.075, 0.13, 0.01), (0.14, 0.19, 0.07), 0)            # crank hub
    K.box(bm, (0.13, 0.13, 0.04), (0.16, 0.30, 0.07), 0)             # crank arm
    K.box(bm, (0.14, 0.27, 0.04), (0.24, 0.31, 0.08), 3)             # crank handle
    K.box(bm, (-0.05, -0.02, 0.11), (0.05, 0.06, 0.18), 3)           # sight
    return [_finish(bm, "tinker_bolt_thrower", mats)]


def tinker_toolkit():
    """Leather tool satchel for the back socket, brass clasps, tools showing."""
    register()
    mats = K.materials("wpn_leather", "wpn_brass", "iron", "timber")
    bm = bmesh.new()
    cy = 0.06
    K.box(bm, (-0.25, cy, -0.24), (0.25, cy + 0.20, 0.14), 0)           # satchel
    K.box(bm, (-0.26, cy, 0.06), (0.26, cy + 0.22, 0.16), 0)           # flap
    for x in (-0.14, 0.14):
        K.box(bm, (x - 0.03, cy + 0.20, -0.02), (x + 0.03, cy + 0.235, 0.10), 1)   # clasps
    K.box(bm, (-0.27, cy + 0.02, -0.06), (0.27, cy + 0.19, -0.02), 1)  # brass band
    # Tools poking out of the top.
    K.box(bm, (-0.16, cy + 0.06, 0.12), (-0.11, cy + 0.11, 0.42), 3)   # hammer haft
    K.box(bm, (-0.20, cy + 0.04, 0.40), (-0.07, cy + 0.13, 0.48), 2)   # hammer head
    K.box(bm, (0.02, cy + 0.07, 0.12), (0.06, cy + 0.11, 0.38), 2)     # spanner
    K.box(bm, (-0.01, cy + 0.06, 0.36), (0.09, cy + 0.12, 0.42), 2)
    K.box(bm, (0.13, cy + 0.08, 0.12), (0.17, cy + 0.12, 0.33), 3)     # chisel
    return [_finish(bm, "tinker_toolkit", mats)]
