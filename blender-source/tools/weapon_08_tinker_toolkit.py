"""Tinker toolkit (back socket) -- see km_weapons.tinker_toolkit."""
import km_kit as K
import km_weapons as W

NAME = "tinker_toolkit"
OUT = "weapons"
GROUND = False
ANGLES = (-60, -140)
ELEVATION = 24


def build():
    K.new_scene()
    return W.tinker_toolkit()
