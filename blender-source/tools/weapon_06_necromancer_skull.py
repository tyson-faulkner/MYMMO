"""Necromancer skull focus -- see km_weapons.necromancer_skull."""
import km_kit as K
import km_weapons as W

NAME = "necromancer_skull"
OUT = "weapons"
GROUND = False
ANGLES = (-60, -130)
ELEVATION = 16


def build():
    K.new_scene()
    return W.necromancer_skull()
