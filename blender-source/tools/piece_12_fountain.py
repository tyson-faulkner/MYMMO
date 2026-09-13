"""Piece 12 -- Fountain: the square's centrepiece.

An octagonal limestone basin 6m across (three grid units, a vertex on each
axis), a raised pedestal, a column, an upper bowl, and a gold finial. Water
is a flat painted surface in the basin and the bowl. 3.2m tall.

Thornhollow's square placed a 7.5m placeholder here; Kingsmourn a 9m one.
ZoneBuilder scales this piece 1.0 and 1.4 rather than exporting two.
"""

import math
import bmesh
import km_kit as K

NAME = "fountain"
ANGLES = (28, -118)
ELEVATION = 24

R_OUTER = 3.0
R_INNER = 2.55
BASIN_H = 0.85


def _oct(r, phase=0.0):
    return [(math.cos(a) * r, math.sin(a) * r) for a in
            [math.radians(phase + 45 * i) for i in range(8)]]


def _ring(bm, r_out, r_in, z0, z1, mat, phase=0.0):
    """An octagonal wall between two radii: eight trapezoid prisms."""
    outer, inner = _oct(r_out, phase), _oct(r_in, phase)
    for i in range(8):
        j = (i + 1) % 8
        K.prism(bm, [outer[i], outer[j], inner[j], inner[i]], "z", z0, z1, mat)


def build():
    K.new_scene()
    stone, water, gold = K.materials("limestone", "water", "gold")

    bm = bmesh.new()
    # Basin floor and wall, with a coping course that oversails the wall.
    K.prism(bm, _oct(R_OUTER), "z", 0.0, 0.30, 0)
    _ring(bm, R_OUTER, R_INNER, 0.30, BASIN_H - 0.14, 0)
    _ring(bm, R_OUTER + 0.10, R_INNER - 0.06, BASIN_H - 0.14, BASIN_H, 0)
    # Water in the basin.
    K.prism(bm, _oct(R_INNER), "z", 0.30, 0.68, 1)
    # Pedestal and column, turned 22.5 degrees so its flats face the axes.
    K.prism(bm, _oct(0.95, 22.5), "z", 0.30, 1.10, 0)
    K.prism(bm, _oct(0.75, 22.5), "z", 1.10, 1.22, 0)
    K.prism(bm, _oct(0.36, 22.5), "z", 1.22, 2.35, 0)
    K.prism(bm, _oct(0.50, 22.5), "z", 2.20, 2.35, 0)
    # Upper bowl with its own water and a gold finial.
    K.prism(bm, _oct(1.30, 22.5), "z", 2.35, 2.50, 0)
    _ring(bm, 1.30, 1.08, 2.50, 2.72, 0, 22.5)
    K.prism(bm, _oct(1.08, 22.5), "z", 2.50, 2.62, 1)
    K.box(bm, (-0.16, -0.16, 2.62), (0.16, 0.16, 2.95), 2)
    K.box(bm, (-0.10, -0.10, 2.95), (0.10, 0.10, 3.20), 2)

    obj = K.finish(bm, NAME, [stone, water, gold], tile=1.5)
    return [obj]


if __name__ == "__main__":
    print(K.report(build()))
