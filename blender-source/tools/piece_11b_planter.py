"""Piece 11b -- Planter box: a 1m stone trough with a clump of foliage.

The tree's little sibling, for squares and doorsteps. Exactly 1m x 1m on
the grid, 0.5m of stone, foliage to about 1.1m.
"""

import bmesh
from mathutils import Matrix, Vector
import km_kit as K

NAME = "planter_box"
ANGLES = (34, -128)
ELEVATION = 24

SIZE = 1.0
H = 0.50


def build():
    K.new_scene()
    stone, soil, foliage = K.materials("limestone", "mud", "foliage")

    h = SIZE / 2.0
    t = 0.10
    bm = bmesh.new()
    # Trough: floor and four walls, with a thicker capping course.
    K.box(bm, (-h, -h, 0.0), (h, h, 0.12), 0)
    for x0, x1, y0, y1 in ((-h, -h + t, -h, h), (h - t, h, -h, h), (-h, h, -h, -h + t), (-h, h, h - t, h)):
        K.box(bm, (x0, y0, 0.12), (x1, y1, H - 0.08), 0)
    for x0, x1, y0, y1 in ((-h - 0.02, -h + t + 0.02, -h - 0.02, h + 0.02), (h - t - 0.02, h + 0.02, -h - 0.02, h + 0.02),
                           (-h - 0.02, h + 0.02, -h - 0.02, -h + t + 0.02), (-h - 0.02, h + 0.02, h - t - 0.02, h + 0.02)):
        K.box(bm, (x0, y0, H - 0.08), (x1, y1, H), 0)
    # Soil.
    K.box(bm, (-h + t, -h + t, 0.12), (h - t, h - t, H - 0.10), 1)
    # Foliage: three blobs.
    for centre, r in (((0.0, 0.0, H + 0.28), 0.36), ((0.24, -0.18, H + 0.16), 0.26), ((-0.22, 0.20, H + 0.20), 0.24)):
        res = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r, matrix=Matrix.Translation(Vector(centre)))
        for v in res["verts"]:
            for f in v.link_faces:
                f.material_index = 2

    obj = K.finish(bm, NAME, [stone, soil, foliage], tile=1.0)
    return [obj]


if __name__ == "__main__":
    print(K.report(build()))
