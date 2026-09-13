"""Enemy bandit_cutthroat -- see km_enemies.bandit_cutthroat. Shared body, shared skeleton, shared clips."""
import km_kit as K
import km_enemies as E

NAME = "enemy_bandit_cutthroat"
OUT = "enemies"
ANGLES = (90, -90)
ELEVATION = 6
APPLY_MODIFIERS = False
ANIMATE = True


def build():
    K.new_scene()
    return E.bandit_cutthroat()