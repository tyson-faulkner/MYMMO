"""Enemy 11 -- the Vale Wolf, its own quadruped mesh, rig and clips (km_wolf.py)."""
import km_wolf as W

NAME = "vale_wolf"
OUT = "enemies"
ANGLES = (60, -110)
ELEVATION = 14
APPLY_MODIFIERS = False
ANIMATE = False           # km_wolf builds its own Idle/Run/Attack1


def build():
    return W.build()