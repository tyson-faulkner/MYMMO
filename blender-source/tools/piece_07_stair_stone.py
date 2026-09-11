"""Piece 7 -- Stone stair, 2m wide, rising 1m over 1.5m of run.

Five steps of 0.2m rise and 0.3m going. That rise is what a player's step
height clears comfortably, and 1m of total rise is half a wall module, so
two flights reach a 2m landing and five reach the top of a 3m storey.

2m wide to match the wall modules, so stairs sit against a building front
without a gap and several can run side by side.

Each tread is modelled as a box reaching all the way back to the top of the
flight rather than as a thin slab. The overlaps make one solid mass with no
hollow underside to see through from below.
"""

import bmesh
import km_kit as K

NAME = "stair_stone_2m"
REPEAT = (3, (2.0, 0, 0))
ANGLES = (44, -126)
ELEVATION = 24

WIDTH = 2.0
STEPS = 5
RISE = 0.20
GOING = 0.30
RUN = STEPS * GOING


def build():
    K.new_scene()
    stone = K.material("limestone")
    hw = WIDTH / 2.0

    bm = bmesh.new()
    for i in range(STEPS):
        # Front face of this step, back to the rear of the whole flight.
        K.box(bm, (-hw, i * GOING, 0.0),
                  (hw, RUN, (i + 1) * RISE), 0)

        # A worn nosing lipping over the step below: catches the sun and
        # gives the flight a readable edge from across the street.
        if i > 0:
            K.box(bm, (-hw, i * GOING - 0.035, i * RISE - 0.045),
                      (hw, i * GOING + 0.02, i * RISE), 0)

    obj = K.finish(bm, NAME, [stone])
    return [obj]


if __name__ == "__main__":
    print(K.report(build()))
