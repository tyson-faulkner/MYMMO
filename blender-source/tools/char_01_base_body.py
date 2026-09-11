"""Character step 1 -- the base humanoid body.

Everything else in the game that is a person is this mesh with different
armour and textures on it: four classes, every human enemy, both bosses.
So it gets built once, carefully, to the proportions in the spec.

Heroic proportions, not realistic ones:
  * 1.80m tall and 7 heads, so the head is oversized at ~0.257m.
  * Shoulders 0.50m across -- noticeably wider than a real 1.8m person.
  * Hands and feet slightly large, which is what sells the WoW read.

T-pose, origin between the feet, facing +Y.

Limbs are swept tubes whose root rings sit INSIDE the torso rather than
being stitched into it. That is the standard low-poly approach: each limb
weights cleanly to its own bone, the intersection is buried under the
silhouette, and it avoids the pole-heavy topology a true stitched shoulder
needs. It is the one place this body is not a single continuous surface,
and it is a deliberate trade.
"""

import bmesh
import km_kit as K
import km_char as C
from km_char import HEAD

NAME = "char_base_body"
OUT = "characters"
ANGLES = (90, 0)          # straight on and from the side
ELEVATION = 8

SEG_BODY = 12             # segments around the torso and head
SEG_LIMB = 8              # around arms and legs

SKIN, CLOTH = 0, 1


def build():
    K.new_scene()
    mats = [K.material("skin", "KM_skin"), K.material("undersuit", "KM_undersuit")]

    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    _torso(bm, uv)
    _head(bm, uv)
    for side in C.SIDES:
        _arm(bm, uv, side)
        _leg(bm, uv, side)

    obj = C.finish_char(bm, NAME, mats)
    return [obj]


def _torso(bm, uv, skin_mat=SKIN, cloth_mat=CLOTH):
    """Hips to neck. The waist pinch and the flare into the shoulders are
    what stop a torso reading as a barrel."""
    sections = [
        ((0, 0, 0.80), 0.126, 0.092),   # crotch
        ((0, 0, 0.90), 0.156, 0.108),   # hips
        ((0, 0, 1.04), 0.142, 0.096),   # waist
        ((0, 0, 1.16), 0.166, 0.110),   # lower ribs
        ((0, 0, 1.28), 0.198, 0.132),   # chest
        # Depth matters as much as width here: with a shallow shoulder the
        # arm emerged from a thin edge and read as a plate stuck on the chest.
        ((0, 0, 1.38), 0.218, 0.146),   # upper chest
        ((0, 0, 1.45), 0.226, 0.148),   # shoulder line
        # Two rings through the trapezius instead of one. A single step from
        # shoulder to neck left a flat shelf either side of the head.
        ((0, 0, 1.500), 0.186, 0.128),
        ((0, 0, 1.540), 0.108, 0.092),
        ((0, 0, 1.575), 0.072, 0.070),  # neck
    ]
    C.tube(bm, uv, sections, C.X, C.Y, SEG_BODY, mat=cloth_mat,
           cap_start=True, cap_end=False)


def _head(bm, uv, skin_mat=SKIN, cloth_mat=CLOTH):
    sections = [
        ((0, 0, 1.555), 0.072, 0.070),
        ((0, 0.004, 1.62), 0.096, 0.102),
        ((0, 0.006, 1.68), 0.117, 0.124),
        ((0, 0.004, 1.74), 0.116, 0.122),
        ((0, 0, 1.785), 0.084, 0.088),
        ((0, 0, 1.80), 0.030, 0.032),
    ]
    C.tube(bm, uv, sections, C.X, C.Y, SEG_BODY, mat=skin_mat,
           cap_start=False, cap_end=True)


def _arm(bm, uv, side, skin_mat=SKIN, cloth_mat=CLOTH):
    """T-pose arm along X. Root ring sits inside the chest."""
    u = C.Y                      # ring plane is perpendicular to the arm
    v = C.Z
    axis = C.X * side
    # Shortened from an earlier pass: fingertip-to-fingertip was 2.02m on a
    # 1.80m figure, which read as gangly next to the heavy shoulders. The
    # span is now 1.82m -- about equal to height, which is the human ratio.
    sections = [
        ((side * 0.11, 0, 1.425), 0.100, 0.100),  # buried in the chest
        ((side * 0.20, 0, 1.435), 0.104, 0.104),  # deltoid, the widest point
        ((side * 0.31, 0, 1.430), 0.085, 0.086),  # upper arm
        ((side * 0.47, 0, 1.425), 0.069, 0.071),  # elbow
        ((side * 0.62, 0, 1.425), 0.059, 0.061),  # forearm
        ((side * 0.74, 0, 1.425), 0.047, 0.049),  # wrist
        # The hand continues the same tube rather than being a separate box.
        # As a loose island it was the one piece skinning could not resolve,
        # and it detached from the arm the first time the rig was posed.
        ((side * 0.80, 0, 1.425), 0.055, 0.042),  # palm
        ((side * 0.87, 0, 1.425), 0.050, 0.036),  # knuckles
        ((side * 0.91, 0, 1.425), 0.028, 0.020),  # fingertips
    ]
    # Sleeve to the elbow, bare from there. That puts the cloth/skin border
    # at the elbow instead of the shoulder, where it was drawing attention
    # to the seam between the arm tube and the torso. The last three spans
    # are the hand: a flattened mitten, which reads better than fingers at
    # this poly count and is covered by a gauntlet on every class anyway.
    C.tube(bm, uv, sections, u, v, SEG_LIMB,
           mat=[cloth_mat, cloth_mat, cloth_mat, skin_mat, skin_mat, skin_mat, skin_mat, skin_mat],
           cap_start=True, cap_end=True)


def _leg(bm, uv, side, skin_mat=SKIN, cloth_mat=CLOTH):
    x = side * 0.098
    sections = [
        # Thighs were far too wide here and the figure read as if it were
        # wearing jodhpurs. The upper thigh is now barely wider than the hip
        # it comes out of.
        # Kept close to the hip joint (z=0.92). Burying it higher meant the
        # part of the tube above the pivot swung out of the pelvis as a flap
        # whenever the leg rotated.
        ((x, 0, 0.935), 0.107, 0.103),  # buried in the pelvis
        ((x, 0, 0.84), 0.105, 0.102),   # upper thigh
        ((x, 0, 0.66), 0.096, 0.096),   # thigh
        ((x, 0, 0.48), 0.079, 0.083),   # knee
        ((x, 0, 0.30), 0.066, 0.070),   # calf
        ((x, 0, 0.12), 0.052, 0.054),   # ankle
    ]
    C.tube(bm, uv, sections, C.X, C.Y, SEG_LIMB, mat=cloth_mat,
           cap_start=True, cap_end=True)

    # Foot: a wedge running forward from the ankle.
    C.taper_box(bm, uv, (x, -0.045, 0.055), C.X, C.Z, C.Y,
                (0.062, 0.055), (0.055, 0.030), 0.26, mat=cloth_mat)


if __name__ == "__main__":
    print(K.report(build()))


