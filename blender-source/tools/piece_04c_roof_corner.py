"""Piece 4c -- Slate hip roof corner.

Where two pitches meet at a building corner, the roof surface is the lower
of the two planes: z = min(x, y). That splits into two triangles meeting
along a hip line running diagonally from the eave corner up to the ridge.

The piece covers a 2m x 2m corner and matches the slope panel exactly --
same 45-degree pitch, same 0.35m eave oversail, same 0.30m thickness -- so
a slope panel butted against either open edge continues without a step.

Built with explicit winding rather than boxes: the faces are triangles and
sloped quads, and getting the normals right by hand is cheaper than trying
to recalculate them on a mesh with overlapping solids.
"""

import bmesh
import km_kit as K

NAME = "roof_slate_corner"
ANGLES = (45, -135)
ELEVATION = 24

SPAN = 2.0
OVER = 0.35          # eave oversail, matching the slope panel
THICK = 0.30         # vertical thickness, matching the slope panel


def build():
    K.new_scene()
    slate, timber = K.materials("slate", "timber")

    lo = -OVER               # outer eave corner, where z = -OVER
    hi = SPAN                # inner corner, at ridge height
    zlo = -OVER
    zhi = SPAN
    t = THICK

    bm = bmesh.new()
    v = {}

    def vert(x, y, z):
        key = (round(x, 5), round(y, 5), round(z, 5))
        if key not in v:
            v[key] = bm.verts.new(key)
        return v[key]

    def face(pts, mat=0):
        f = bm.faces.new([vert(*p) for p in pts])
        f.material_index = mat
        return f

    # Corners of the top surface. z = min(x, y).
    o_top = (lo, lo, zlo)          # outer eave corner
    x_top = (hi, lo, zlo)          # along the -Y eave
    y_top = (lo, hi, zlo)          # along the -X eave
    r_top = (hi, hi, zhi)          # inner corner, at the ridge

    o_bot = (lo, lo, zlo - t)
    x_bot = (hi, lo, zlo - t)
    y_bot = (lo, hi, zlo - t)
    r_bot = (hi, hi, zhi - t)

    # Top surface: two triangles either side of the hip line.
    face([o_top, x_top, r_top])          # the y < x half, plane z = y
    face([o_top, r_top, y_top])          # the x < y half, plane z = x

    # Underside, wound the other way.
    face([o_bot, r_bot, x_bot])
    face([o_bot, y_bot, r_bot])

    # The two open edges a slope panel butts against.
    face([x_top, x_bot, r_bot, r_top])   # +X face
    face([y_top, r_top, r_bot, y_bot])   # +Y face

    # The two eave edges.
    face([o_top, y_top, y_bot, o_bot])   # -X eave
    face([o_top, o_bot, x_bot, x_top])   # -Y eave

    obj = K.finish(bm, NAME, [slate, timber])
    K.sit_on_floor(obj)
    return [obj]


if __name__ == "__main__":
    print(K.report(build()))
