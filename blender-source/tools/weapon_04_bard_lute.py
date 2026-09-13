"""Bard lute (back socket) -- see km_weapons.bard_lute."""
import km_kit as K
import km_weapons as W

NAME = "bard_lute"
OUT = "weapons"
GROUND = False
ANGLES = (-70, -150)
ELEVATION = 14


def build():
    K.new_scene()
    return W.bard_lute()
