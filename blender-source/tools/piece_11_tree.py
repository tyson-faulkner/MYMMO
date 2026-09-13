"""Piece 11 -- Round tree: an octagonal trunk and a blob canopy.

WoW-Classic foliage is a mass, not leaves: three low-poly spheres, the big
one on top and two smaller ones pushed off-centre so the silhouette is not
a lollipop. Canopy bottom sits at 2.6m so a character walks under it.

Also builds the planter box (piece 11b) from the same parts: a stone trough
with three small foliage blobs in it.
"""

import math
import bmesh
from mathutils import Matrix, Vector
import km_kit as K

NAME = "tree_round"
ANGLES = (30, -120)
ELEVATION = 16

TRUNK_H = 3.4
TRUNK_R = 0.30


def _octagon(r):
    return [(math.cos(a) * r, math.sin(a) * r) for a in
            [math.radians(22.5 + 45 * i) for i in range(8)]]


def _blob(bm, centre, radius, mat):
    """Low-poly sphere with the given material on every face."""
    res = bmesh.ops.create_icosphere(
        bm, subdivisions=1, radius=radius,
        matrix=Matrix.Translation(Vector(centre)))
    for v in res["verts"]:
        for f in v.link_faces:
            f.material_index = mat
    return res


def build():
    K.new_scene()
    timber, foliage = K.materials("timber", "foliage")

    bm = bmesh.new()
    # Trunk: two octagonal prisms, the lower one fatter, plus a root flare.
    K.prism(bm, _octagon(TRUNK_R * 1.35), "z", 0.0, 0.30, 0)
    K.prism(bm, _octagon(TRUNK_R), "z", 0.30, TRUNK_H * 0.55, 0)
    K.prism(bm, _octagon(TRUNK_R * 0.78), "z", TRUNK_H * 0.55, TRUNK_H + 0.4, 0)
    # Canopy: the side blobs overlap the trunk's top, so no branches are needed.
    _blob(bm, (0.0, 0.0, TRUNK_H + 0.9), 1.70, 1)
    _blob(bm, (0.95, 0.45, TRUNK_H + 0.35), 1.10, 1)
    _blob(bm, (-0.85, -0.55, TRUNK_H + 1.55), 1.00, 1)

    obj = K.finish(bm, NAME, [timber, foliage], smooth=False, tile=1.5)
    return [obj]


if __name__ == "__main__":
    print(K.report(build()))
