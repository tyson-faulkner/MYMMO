"""Piece 1 -- Stone wall section, 2m wide x 3m tall x 0.3m thick.

The base module of every building, so it has to repeat cleanly: butt two of
these together and the join must be invisible. That rules out quoins (corner
stones) -- they'd land mid-wall in a long run and belong on a corner piece.

What it does get is a projecting plinth along the base with a chamfered cap.
That detail runs horizontally, so it survives being repeated, and it gives
the sun something to catch at ground level the way the reference art does.
"""

import bmesh
import km_kit as K

NAME = "wall_stone_2x3"
W, H, T = 2.0, 3.0, K.WALL_THICKNESS
REPEAT = (3, (W, 0, 0))     # preview three in a row to check the seams


def build():
    K.new_scene()
    mats = K.materials("limestone")
    bm = bmesh.new()

    hw, ht = W / 2.0, T / 2.0

    # Main slab.
    K.box(bm, (-hw, -ht, 0.0), (hw, ht, H))

    # Plinth: a wider, shorter block along the bottom 0.35m.
    K.box(bm, (-hw, -ht - 0.06, 0.0), (hw, ht + 0.06, 0.35))
    # Chamfer cap on the plinth so water sheds -- and so it catches the sun.
    K.box(bm, (-hw, -ht - 0.03, 0.35), (hw, ht + 0.03, 0.42))

    obj = K.finish(bm, NAME, mats)
    return [obj]


if __name__ == "__main__":
    objs = build()
    print(K.report(objs))
