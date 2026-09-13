"""Piece 10 -- Market stall: timber counter and frame, striped red-and-gold
awning, a few goods on the counter.

3m x 2m footprint on the grid. The awning pitches down towards the front
(-Y, the customer's side) so the stripes read from the street, and its hem
is scalloped with small boxes because a straight edge looked like a shelf.
"""

import bmesh
import km_kit as K
import km_textures as T

NAME = "market_stall"
ANGLES = (34, -126)
ELEVATION = 22

W, D = 3.0, 2.0          # x, y
COUNTER_H = 0.92
POST = 0.12
RED = (0.66, 0.24, 0.20)
GOLD = (0.83, 0.67, 0.26)


def build():
    K.new_scene()
    T.register("awning", lambda: T.stripes(RED, GOLD, count=10, seed=291))
    timber, awning, stone, sack = K.materials("timber", "awning", "limestone", "mud")

    hw, hd = W / 2.0, D / 2.0
    bm = bmesh.new()

    # Counter: a solid front box, with a plank top that oversails it.
    K.box(bm, (-hw + 0.1, -hd + 0.15, 0.0), (hw - 0.1, -hd + 0.95, COUNTER_H - 0.06), 0)
    K.box(bm, (-hw, -hd, COUNTER_H - 0.06), (hw, -hd + 1.05, COUNTER_H), 0)
    # Back shelf, lower and shallower.
    K.box(bm, (-hw + 0.1, hd - 0.55, 0.0), (hw - 0.1, hd - 0.05, 0.55), 0)
    K.box(bm, (-hw + 0.05, hd - 0.60, 0.55), (hw - 0.05, hd, 0.60), 0)

    # Four posts; the back pair taller so the awning pitches forward.
    front_h, back_h = 2.25, 2.70
    for sx in (-1, 1):
        x0 = sx * (hw - POST) - (0.0 if sx < 0 else POST)
        K.box(bm, (x0, -hd, 0.0), (x0 + POST, -hd + POST, front_h), 0)
        K.box(bm, (x0, hd - POST, 0.0), (x0 + POST, hd, back_h), 0)
    # Cross rails carrying the awning.
    K.box(bm, (-hw, -hd, front_h - 0.10), (hw, -hd + POST, front_h), 0)
    K.box(bm, (-hw, hd - POST, back_h - 0.10), (hw, hd, back_h), 0)

    # Awning: a thin sloped sheet from the back rail down to just past the
    # front rail, in the awning material. Profile in (y, z), extruded along x.
    y_front, y_back = -hd - 0.30, hd + 0.05
    z_front, z_back = front_h + 0.02, back_h + 0.02
    sheet = [(y_front, z_front), (y_back, z_back), (y_back, z_back + 0.05), (y_front, z_front + 0.05)]
    K.prism(bm, sheet, "x", -hw - 0.15, hw + 0.15, 1)
    # Scalloped hem along the front edge.
    n = 9
    step = (W + 0.30) / n
    for i in range(n):
        x0 = -hw - 0.15 + i * step
        K.box(bm, (x0 + 0.02, y_front - 0.03, z_front - 0.16), (x0 + step - 0.02, y_front + 0.06, z_front + 0.02), 1)

    # Goods: a crate, a stone jar, two sacks. Enough to say "shop".
    K.box(bm, (-1.15, -hd + 0.30, COUNTER_H), (-0.55, -hd + 0.85, COUNTER_H + 0.42), 0)
    K.box(bm, (0.15, -hd + 0.35, COUNTER_H), (0.45, -hd + 0.65, COUNTER_H + 0.38), 2)
    K.box(bm, (0.65, -hd + 0.25, COUNTER_H), (1.20, -hd + 0.75, COUNTER_H + 0.30), 3)
    K.box(bm, (0.75, hd - 0.50, 0.60), (1.25, hd - 0.10, 0.95), 3)

    obj = K.finish(bm, NAME, [timber, awning, stone, sack], tile=1.0)
    return [obj]


if __name__ == "__main__":
    print(K.report(build()))
