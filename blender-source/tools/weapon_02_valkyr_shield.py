"""Valkyr kite shield -- see km_weapons.valkyr_shield."""
import km_kit as K
import km_weapons as W

NAME = "valkyr_shield"
OUT = "weapons"
GROUND = False
ANGLES = (-70, -150)
ELEVATION = 14


def build():
    K.new_scene()
    return W.valkyr_shield()
