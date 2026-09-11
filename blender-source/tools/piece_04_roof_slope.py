"""Piece 4a -- Blue slate roof slope, 2m of ridge per section.

One pitch panel. It covers 2m along the ridge (X), 2m of horizontal run (Y)
and rises 2m, which is a 45-degree pitch -- steep, the way the reference
street art is, and it keeps every number on the 1m grid.

Sitting it at the top of a 3m wall run puts the eave at 3m and the ridge at
5m. Mirror it about Y for the far pitch; cap the join with the ridge piece.

The eave oversails the wall by 0.35m and carries a timber fascia, because a
roof that stops flush with the wall reads as a lid rather than a roof.
"""

import bmesh
import km_kit as K

NAME = "roof_slate_slope_2m"
REPEAT = (3, (2.0, 0, 0))
ANGLES = (52, -120)
ELEVATION = 22

WIDTH = 2.0          # along the ridge
RUN = 2.0            # horizontal, eave to ridge
RISE = 2.0           # 45 degrees
OVERHANG = 0.35      # how far the eave oversails the wall below
THICK = 0.30         # measured vertically


def build():
    K.new_scene()
    slate, timber = K.materials("slate", "timber")

    hw = WIDTH / 2.0
    # Profile in the (y, z) plane, extruded along X. Walking anticlockwise:
    # eave tip -> ridge top -> ridge underside -> eave underside.
    eave_y = -OVERHANG
    eave_z = -OVERHANG                      # 45 degrees, so the drop matches
    profile = [
        (eave_y, eave_z),
        (RUN, RISE),
        (RUN, RISE - THICK),
        (eave_y, eave_z - THICK),
    ]

    bm = bmesh.new()
    K.prism(bm, profile, "x", -hw, hw, mat=0)

    # Fascia board closing the eave, set just under the slate lip.
    K.box(bm, (-hw, eave_y - 0.06, eave_z - THICK - 0.02),
              (hw, eave_y + 0.02, eave_z + 0.02), 1)

    obj = K.finish(bm, NAME, [slate, timber])
    # Sit the eave underside on z=0, matching every other piece in the kit.
    # Measured, not computed: the fascia board hangs below the slate.
    K.sit_on_floor(obj)
    return [obj]


if __name__ == "__main__":
    print(K.report(build()))
