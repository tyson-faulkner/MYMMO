# Graveyard — where you come back when you give up on the walk.
#
# Drop one per region. DeathHandler picks whichever is nearest to where you
# fell, which is why the barrow needs its own: releasing inside a dungeon should
# not put you on the surface, five hundred metres above the fight.
class_name Graveyard
extends Node3D

@export var display_name: String = "Vale Graveyard"


func _ready() -> void:
	add_to_group("Graveyards")
