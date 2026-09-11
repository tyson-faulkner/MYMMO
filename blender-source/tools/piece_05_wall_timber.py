"""Piece 5 -- Timber-frame upper-storey wall, 2m x 3m.

White plaster infill with warm brown beams: the signature of the reference
street. Goes on top of a stone ground floor.

It jetties -- the storey oversails the wall below by 0.25m on the exterior
side, carried on timber corbels. That overhang is most of why the reference
buildings read as they do, and because it only projects along Y it doesn't
disturb how pieces butt together along X.

The corner posts are half-width (0.10) at each edge, so two pieces side by
side form one full 0.20 post and a long run gets evenly spaced posts every
2m. A lone piece looks a touch thin at its edges; a wall run looks right,
and wall runs are what this is for.
"""

import bmesh
import km_kit as K

NAME = "wall_timber_2x3"
W, H, T = 2.0, 3.0, K.WALL_THICKNESS
REPEAT = (3, (W, 0, 0))

JETTY = 0.25         # how far the storey oversails the floor below
BEAM = 0.075         # how far beams stand proud of the plaster
POST = 0.10          # half a post -- two pieces meeting make a whole one


def build():
    K.new_scene()
    plaster, timber = K.materials("plaster", "timber")

    hw = W / 2.0
    # The plaster core sits forward of centre by the jetty amount.
    y0 = -T / 2.0
    y1 = T / 2.0 + JETTY
    face = y1               # exterior surface of the plaster
    out = face + BEAM       # outer face of the beams
    # Beams bite just into the plaster rather than spanning the full depth.
    # Running them right through left the diagonals poking out as spikes on
    # the interior face.
    inset = face - 0.06

    bm = bmesh.new()

    # Plaster panel.
    K.box(bm, (-hw, y0, 0.0), (hw, y1, H), 0)

    # --- the frame ------------------------------------------------------
    sill_top = 0.22
    rail0, rail1 = 1.44, 1.62
    plate0 = 2.76

    # Horizontals: sill, mid rail, top plate. Each runs the full width so a
    # run of pieces reads as one continuous frame.
    K.box(bm, (-hw, inset, 0.0), (hw, out, sill_top), 1)
    K.box(bm, (-hw, inset, rail0), (hw, out, rail1), 1)
    K.box(bm, (-hw, inset, plate0), (hw, out, H), 1)

    # Half corner posts. These DO run the full depth -- they wrap the wall's
    # edge, so a corner of the building reads as a post from both sides.
    for sx in (-1, 1):
        x_out = sx * hw
        x_in = sx * (hw - POST)
        K.box(bm, (min(x_in, x_out), y0, 0.0),
                  (max(x_in, x_out), out, H), 1)

    # Lower register: a chevron of braces rising to the centre.
    # Upper register: two plain studs splitting it into three bays.
    # Deliberately sparse -- an earlier pass with braces and a stud in both
    # registers read as more timber than plaster, which the reference is not.
    inner = hw - POST
    brace = 0.10
    for sx in (-1, 1):
        K.strut(bm, (sx * inner, sill_top), (sx * 0.06, rail0),
                brace, inset, out, 1)
        K.box(bm, (sx * 0.60 - 0.05, inset, rail1),
                  (sx * 0.60 + 0.05, out, plate0), 1)

    # --- corbels carrying the jetty --------------------------------------
    # Brackets under the overhang, so the storey doesn't float.
    for sx in (-1, 1):
        cx = sx * (hw - 0.28)
        K.strut(bm, (cx, -0.30), (cx, 0.02), 0.16, T / 2.0 - 0.02, y1, 1)
        K.box(bm, (cx - 0.09, T / 2.0 - 0.02, -0.30),
                  (cx + 0.09, y1, -0.12), 1)

    obj = K.finish(bm, NAME, [plaster, timber])
    # Origin stays on the storey's floor line, NOT on the lowest geometry.
    # The corbels are meant to hang below it and overlap the wall beneath,
    # so this piece drops straight onto a 3m ground floor at y=3.
    return [obj]


if __name__ == "__main__":
    print(K.report(build()))
