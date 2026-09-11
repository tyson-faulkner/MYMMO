"""Piece 3 -- Stone wall with a doorway, plus the wooden door leaf.

Same 2m x 3m x 0.3m module and the same plinth as pieces 1 and 2, so all
three interchange in a wall run. The doorway is 1.0m x 2.2m -- generous
enough for a player with a shield on their back to read as walk-through.

The door surround runs from the ground to the lintel and interrupts the
plinth, which is what real masonry does and what stops the frame looking
stuck on.

The door leaf is exported as its OWN node with its origin on the hinge
edge, so Godot can swing it by rotating that node -- no re-rigging, no
second asset.
"""

import bmesh
import km_kit as K

NAME = "wall_stone_door_2x3"
W, H, T = 2.0, 3.0, K.WALL_THICKNESS
REPEAT = (3, (W, 0, 0))

OPEN_W, OPEN_H = 1.00, 2.20
JAMB = 0.15


def build():
    K.new_scene()
    stone, timber, iron = K.materials("limestone", "timber", "iron")

    hw, ht = W / 2.0, T / 2.0
    ox = OPEN_W / 2.0
    out = ht + 0.07
    back = -ht

    # ---------------------------------------------------------- the wall --
    bm = bmesh.new()

    # Slab with the doorway cut out. The opening runs to the floor, so the
    # "under" panel of a normal frame has zero height -- build the three
    # remaining panels directly.
    K.box(bm, (-hw, -ht, OPEN_H), (hw, ht, H), 0)              # over the door
    K.box(bm, (-hw, -ht, 0.0), (-ox, ht, OPEN_H), 0)           # left pier
    K.box(bm, (ox, -ht, 0.0), (hw, ht, OPEN_H), 0)             # right pier

    # Plinth, stopped either side of the door surround.
    for x0, x1 in ((-hw, -ox - JAMB), (ox + JAMB, hw)):
        K.box(bm, (x0, -ht - 0.06, 0.0), (x1, ht + 0.06, 0.35), 0)
        K.box(bm, (x0, -ht - 0.03, 0.35), (x1, ht + 0.03, 0.42), 0)

    # Jambs: dressed stone from the ground to the lintel.
    for sx in (-1, 1):
        x_in, x_out = sx * ox, sx * (ox + JAMB)
        K.box(bm, (min(x_in, x_out), back, 0.0),
                  (max(x_in, x_out), out, OPEN_H), 0)

    # Lintel and keystone, matching the window's treatment.
    span = OPEN_W + 2 * JAMB
    K.box(bm, (-span / 2, back, OPEN_H), (span / 2, out, OPEN_H + 0.26), 0)
    K.box(bm, (-0.17, back, OPEN_H + 0.20), (0.17, out + 0.03, OPEN_H + 0.48), 0)

    # Threshold: one worn step, kept shallow so it doesn't fight the street.
    K.box(bm, (-ox - 0.10, ht - 0.02, 0.0), (ox + 0.10, ht + 0.22, 0.10), 0)

    wall = K.finish(bm, NAME, [stone, timber, iron])

    # ---------------------------------------------------------- the door --
    door = _door_leaf([stone, timber, iron])
    # Origin on the hinge edge so rotating the node swings the door.
    door.location = (-ox + 0.02, 0.0, 0.0)

    return [wall, door]


def _door_leaf(mats):
    """Plank door with iron strap hinges and a pull handle.

    Modelled in local space with the hinge at the origin: x runs across the
    door, z up, y from the interior face to the exterior face.
    """
    dw, dh, dt = 0.96, 2.16, 0.07
    bm = bmesh.new()

    # Leaf. Vertical planks come from the timber texture, not geometry.
    K.box(bm, (0.0, 0.0, 0.0), (dw, dt, dh), 1)

    # Ledger braces across the back, so the door reads as built not cut.
    for z in (0.30, dh - 0.40):
        K.box(bm, (0.02, -0.04, z), (dw - 0.02, 0.0, z + 0.12), 1)

    # Iron strap hinges: full-width straps, thicker at the hinge edge.
    for z in (0.34, dh - 0.52):
        K.box(bm, (0.0, dt - 0.01, z), (dw * 0.78, dt + 0.025, z + 0.13), 2)
        K.box(bm, (0.0, dt - 0.01, z - 0.04), (0.16, dt + 0.03, z + 0.17), 2)

    # Pull handle on the leading edge: a backing plate and a grab bar.
    hx, hz = dw - 0.18, dh * 0.45
    K.box(bm, (hx - 0.09, dt - 0.01, hz - 0.11), (hx + 0.09, dt + 0.02, hz + 0.11), 2)
    K.box(bm, (hx - 0.05, dt + 0.02, hz - 0.07), (hx + 0.05, dt + 0.06, hz - 0.03), 2)
    K.box(bm, (hx - 0.05, dt + 0.02, hz + 0.03), (hx + 0.05, dt + 0.06, hz + 0.07), 2)
    K.box(bm, (hx - 0.05, dt + 0.04, hz - 0.07), (hx + 0.05, dt + 0.06, hz + 0.07), 2)

    # Finer UV tile than the walls: at the 2m default the timber texture's
    # 0.5m planks gave a 0.96m door barely two boards wide. 0.64m puts six
    # boards across the leaf, which is what a door should look like.
    return K.finish(bm, "door_leaf", mats, tile=0.64)


if __name__ == "__main__":
    print(K.report(build()))
