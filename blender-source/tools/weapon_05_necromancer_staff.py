"""Necromancer staff -- see km_weapons.necromancer_staff."""
import km_kit as K
import km_weapons as W

NAME = "necromancer_staff"
OUT = "weapons"
GROUND = False
ANGLES = (-60, -130)
ELEVATION = 12


def build():
    K.new_scene()
    return W.necromancer_staff()
