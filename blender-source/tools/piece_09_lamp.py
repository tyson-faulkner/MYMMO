"""Piece 9 -- Street lamp: black iron post, one arm, a warm lantern.

3.0m to the top of the lantern (measured: 0.42 x 0.83 x 3.04m), on a 0.4m
plinth footprint, so the lantern sits just under a ground-floor eave line. The post is two
stacked boxes, thicker below, which is all the taper a low-poly silhouette
needs. The glass is the kit's one "glow": an amber texture far brighter than
anything near it, because the kit has no emissive materials.
"""

import bmesh
import km_kit as K

NAME = "lamp_iron"
ANGLES = (32, -130)
ELEVATION = 18

PLINTH = 0.40
POST_H = 3.0


def build():
    K.new_scene()
    iron, glow = K.material("iron"), K.material("lamp_glow")

    bm = bmesh.new()
    hp = PLINTH / 2.0
    # Plinth: two steps.
    K.box(bm, (-hp, -hp, 0.0), (hp, hp, 0.10), 0)
    K.box(bm, (-0.14, -0.14, 0.10), (0.14, 0.14, 0.32), 0)
    # Post, thicker below the collar.
    K.box(bm, (-0.075, -0.075, 0.32), (0.075, 0.075, 1.6), 0)
    K.box(bm, (-0.09, -0.09, 1.55), (0.09, 0.09, 1.65), 0)         # collar
    K.box(bm, (-0.055, -0.055, 1.65), (0.055, 0.055, POST_H), 0)
    # Arm out along +Y, with a curl of bracket under it.
    K.box(bm, (-0.045, -0.045, POST_H - 0.09), (0.045, 0.52, POST_H), 0)
    K.box(bm, (-0.03, 0.10, POST_H - 0.40), (0.03, 0.16, POST_H - 0.09), 0)
    K.box(bm, (-0.03, 0.10, POST_H - 0.40), (0.03, 0.40, POST_H - 0.34), 0)
    # Lantern: hangs from the arm's end. Cage of four corner bars, cap, base.
    cx, cy = 0.0, 0.42
    z0, z1 = POST_H - 0.62, POST_H - 0.12
    for sx in (-1, 1):
        for sy in (-1, 1):
            K.box(bm, (cx + sx * 0.16 - 0.02, cy + sy * 0.16 - 0.02, z0),
                      (cx + sx * 0.16 + 0.02, cy + sy * 0.16 + 0.02, z1), 0)
    K.box(bm, (cx - 0.19, cy - 0.19, z0 - 0.05), (cx + 0.19, cy + 0.19, z0), 0)
    K.box(bm, (cx - 0.21, cy - 0.21, z1), (cx + 0.21, cy + 0.21, z1 + 0.05), 0)
    K.box(bm, (cx - 0.11, cy - 0.11, z1 + 0.05), (cx + 0.11, cy + 0.11, z1 + 0.16), 0)   # cap
    # Glass, slightly inside the bars.
    K.box(bm, (cx - 0.15, cy - 0.15, z0), (cx + 0.15, cy + 0.15, z1), 1)

    obj = K.finish(bm, NAME, [iron, glow], tile=1.0)
    return [obj]


if __name__ == "__main__":
    print(K.report(build()))
