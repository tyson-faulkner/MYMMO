"""Enemy sunburst_serjeant -- see km_enemies.sunburst_serjeant. Shared body, shared skeleton, shared clips."""
import km_kit as K
import km_enemies as E

NAME = "enemy_sunburst_serjeant"
OUT = "enemies"
ANGLES = (90, -90)
ELEVATION = 6
APPLY_MODIFIERS = False
ANIMATE = True


def build():
    K.new_scene()
    return E.sunburst_serjeant()