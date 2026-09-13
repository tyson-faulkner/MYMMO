"""Enemy hedge_bandit -- see km_enemies.hedge_bandit. Shared body, shared skeleton, shared clips."""
import km_kit as K
import km_enemies as E

NAME = "enemy_hedge_bandit"
OUT = "enemies"
ANGLES = (90, -90)
ELEVATION = 6
APPLY_MODIFIERS = False
ANIMATE = True


def build():
    K.new_scene()
    return E.hedge_bandit()