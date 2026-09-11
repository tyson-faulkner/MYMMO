"""Piece 6 -- Cobblestone street tile, 2m x 2m, tileable.

Deliberately a flat slab. All the roundness is painted into the texture,
which domes each sett and darkens the grout; geometry for that would cost
hundreds of triangles across a whole street and buy nothing at eye level.

Ground pieces break the usual convention: the WALKING SURFACE sits at z=0
and the slab hangs below it, so a street tile and a wall placed at the same
height meet correctly. Give a ground tile a base at z=0 instead and every
wall in the scene ends up sunk by the slab's thickness.

The texture tiles at exactly 2m, so the piece is one tile square and a
street laid out of copies has no visible seams or repeat in the stonework.
"""

import bmesh
import km_kit as K

NAME = "street_cobble_2x2"
REPEAT = (3, (2.0, 0, 0), 30)
ANGLES = (40, -120)
ELEVATION = 34
GROUND = False       # the preview's ground plane is coplanar with this piece

SIZE = 2.0
THICK = 0.14


def build():
    K.new_scene()
    cobble = K.material("cobblestone")
    h = SIZE / 2.0

    bm = bmesh.new()
    K.box(bm, (-h, -h, -THICK), (h, h, 0.0), 0)
    obj = K.finish(bm, NAME, [cobble])
    return [obj]


if __name__ == "__main__":
    print(K.report(build()))
