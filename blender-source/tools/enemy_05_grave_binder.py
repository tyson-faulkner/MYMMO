"""Enemy grave_binder -- see km_enemies.grave_binder. Shared body, shared skeleton, shared clips."""
import km_kit as K
import km_enemies as E

NAME = "enemy_grave_binder"
OUT = "enemies"
ANGLES = (90, -90)
ELEVATION = 6
APPLY_MODIFIERS = False
ANIMATE = True


def build():
    K.new_scene()
    return E.grave_binder()