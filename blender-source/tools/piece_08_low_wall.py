"""Piece 8 -- Low stone wall / ledge, 2m long and 0.9m tall.

The kit's fence: edges terraces, encloses yards, lines the square, and at
0.9m it reads as something a player leans on rather than climbs.

2m long so it lines up with the wall modules and the street tiles. The
coping oversails the body by 5cm on each side, which is what stops a low
wall looking like a kerb stood on end -- and it throws a shadow line down
the face that reads from a long way off.
"""

import bmesh
import km_kit as K

NAME = "wall_low_2m"
REPEAT = (3, (2.0, 0, 0))
ANGLES = (38, -124)
ELEVATION = 22

LENGTH = 2.0
BODY_H = 0.74
COPE_H = 0.16
BODY_T = 0.36
COPE_OVER = 0.05


def build():
    K.new_scene()
    stone = K.material("limestone")

    hl = LENGTH / 2.0
    hb = BODY_T / 2.0
    hc = hb + COPE_OVER

    bm = bmesh.new()

    # Body.
    K.box(bm, (-hl, -hb, 0.0), (hl, hb, BODY_H), 0)

    # Coping: a chamfered cap. Two courses, the lower one slightly narrower,
    # so the overhang reads as moulding rather than a slab dropped on top.
    K.box(bm, (-hl, -hb - 0.025, BODY_H), (hl, hb + 0.025, BODY_H + 0.04), 0)
    K.box(bm, (-hl, -hc, BODY_H + 0.04), (hl, hc, BODY_H + COPE_H), 0)

    obj = K.finish(bm, NAME, [stone])
    return [obj]


if __name__ == "__main__":
    print(K.report(build()))
