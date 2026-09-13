"""Valkyr spear -- see km_weapons.valkyr_spear."""
import km_kit as K
import km_weapons as W

NAME = "valkyr_spear"
OUT = "weapons"
GROUND = False
ANGLES = (30, -120)
ELEVATION = 12


def build():
    K.new_scene()
    return W.valkyr_spear()
