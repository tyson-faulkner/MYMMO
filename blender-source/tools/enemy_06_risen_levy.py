"""Enemy risen_levy -- see km_enemies.risen_levy. Shared body, shared skeleton, shared clips."""
import km_kit as K
import km_enemies as E

NAME = "enemy_risen_levy"
OUT = "enemies"
ANGLES = (90, -90)
ELEVATION = 6
APPLY_MODIFIERS = False
ANIMATE = True


def build():
    K.new_scene()
    return E.risen_levy()