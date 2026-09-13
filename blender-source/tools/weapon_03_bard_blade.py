"""Bard blade -- see km_weapons.bard_blade."""
import km_kit as K
import km_weapons as W

NAME = "bard_blade"
OUT = "weapons"
GROUND = False
ANGLES = (30, -120)
ELEVATION = 12


def build():
    K.new_scene()
    return W.bard_blade()
