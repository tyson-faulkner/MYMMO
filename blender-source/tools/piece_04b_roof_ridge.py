"""Piece 4b -- Slate ridge cap, 2m per section.

Two opposing roof slopes leave an open seam along the top. This caps it.
Not in the original spec list, but a roof made only of slopes has a hole in
it, so the kit needs this to be usable at all.

Cross-section is a shallow bent tile that oversails both pitches, so it
hides the join with room to spare.
"""

import bmesh
import km_kit as K

NAME = "roof_slate_ridge_2m"
REPEAT = (3, (2.0, 0, 0))
ANGLES = (44, -132)
ELEVATION = 20

LENGTH = 2.0
DROP = 0.32          # how far the cap reaches down each pitch


def build():
    K.new_scene()
    slate = K.material("slate")
    hl = LENGTH / 2.0

    # Profile in (y, z): across the outer face left to right, then back
    # along the underside. A 45-degree pitch each side matches the slopes.
    profile = [
        (-DROP, -DROP + 0.10),
        (0.0, 0.14),
        (DROP, -DROP + 0.10),
        (DROP, -DROP),
        (0.0, 0.04),
        (-DROP, -DROP),
    ]

    bm = bmesh.new()
    K.prism(bm, profile, "x", -hl, hl, mat=0)
    obj = K.finish(bm, NAME, [slate])
    K.sit_on_floor(obj)                  # base on z=0 like every other piece
    return [obj]


if __name__ == "__main__":
    print(K.report(build()))
