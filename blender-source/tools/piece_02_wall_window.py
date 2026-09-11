"""Piece 2 -- Stone wall section with a window, 2m x 3m x 0.3m.

Same 2x3 footprint and same plinth as piece 1, so the two interchange freely
in a wall run. The opening is 0.9m wide x 1.2m tall with its sill at 1.1m --
chest height on a player, which is what makes a building read as inhabited.

The opening gets a full surround: a projecting sill below, dressed stone
jambs either side and a flat arch of voussoirs above. Glass sits recessed in
the reveal so the wall still reads solid from outside.
"""

import bmesh
import km_kit as K

NAME = "wall_stone_window_2x3"
W, H, T = 2.0, 3.0, K.WALL_THICKNESS
REPEAT = (3, (W, 0, 0))

OPEN_W, OPEN_H = 0.90, 1.20
SILL_Z = 1.10


def build():
    K.new_scene()
    stone, timber, glass = K.material("limestone"), K.material("timber"), _glass()
    bm = bmesh.new()

    hw, ht = W / 2.0, T / 2.0
    ox = OPEN_W / 2.0
    oz0, oz1 = SILL_Z, SILL_Z + OPEN_H

    # Wall slab with the opening cut out.
    K.frame(bm, (-hw, -ht, 0.0), (hw, ht, H), (-ox, oz0), (ox, oz1), "y", 0)

    # Plinth, matching piece 1 exactly so a run of walls lines up.
    K.box(bm, (-hw, -ht - 0.06, 0.0), (hw, ht + 0.06, 0.35), 0)
    K.box(bm, (-hw, -ht - 0.03, 0.35), (hw, ht + 0.03, 0.42), 0)

    # --- window surround (projects along +Y, the exterior face) ----------
    out = ht + 0.07                # outer limit of the dressed stonework
    back = -ht                     # flush inside -- no ridges on the interior

    # Sill: overhangs the opening each side and juts out to throw a shadow.
    K.box(bm, (-ox - 0.17, back, oz0 - 0.15), (ox + 0.17, ht + 0.13, oz0), 0)

    # Jambs: dressed stone either side, standing proud of the wall face.
    for sx in (-1, 1):
        x_in, x_out = sx * ox, sx * (ox + 0.15)
        K.box(bm, (min(x_in, x_out), back, oz0),
                  (max(x_in, x_out), out, oz1), 0)

    # Lintel: one chunky block plus a keystone. Five separate voussoirs were
    # tried first and read as noise at this size -- two big shapes carry far
    # better, which is the WoW-Classic lesson.
    span = OPEN_W + 0.30
    K.box(bm, (-span / 2, back, oz1), (span / 2, out, oz1 + 0.26), 0)
    K.box(bm, (-0.15, back, oz1 + 0.20), (0.15, out + 0.03, oz1 + 0.46), 0)

    # --- window itself --------------------------------------------------
    # Glass set well back in the reveal so the opening reads as a deep hole.
    gy = ht - 0.13
    K.box(bm, (-ox, gy, oz0), (ox, gy + 0.02, oz1), 2)
    bar = 0.06
    K.box(bm, (-bar / 2, gy - 0.01, oz0), (bar / 2, gy + 0.07, oz1), 1)
    mid = (oz0 + oz1) / 2.0
    K.box(bm, (-ox, gy - 0.01, mid - bar / 2), (ox, gy + 0.07, mid + bar / 2), 1)

    obj = K.finish(bm, NAME, [stone, timber, glass])
    return [obj]


def _glass():
    """Leaded glass: dark, slightly blue, and a bit shiny so it reads as glass
    against all the matte stone."""
    import bpy
    mat = bpy.data.materials.get("KM_glass")
    if mat:
        return mat
    mat = bpy.data.materials.new("KM_glass")
    mat.use_nodes = True
    b = mat.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (0.13, 0.19, 0.24, 1.0)
    b.inputs["Roughness"].default_value = 0.18
    b.inputs["Metallic"].default_value = 0.0
    return mat


if __name__ == "__main__":
    print(K.report(build()))
