"""Tinker bolt thrower -- see km_weapons.tinker_bolt_thrower."""
import km_kit as K
import km_weapons as W

NAME = "tinker_bolt_thrower"
OUT = "weapons"
GROUND = False
ANGLES = (40, -120)
ELEVATION = 24


def build():
    K.new_scene()
    return W.tinker_bolt_thrower()
