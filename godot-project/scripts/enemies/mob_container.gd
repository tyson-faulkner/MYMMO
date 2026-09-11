# MobContainer — the one place enemies are created, so that Godot's
# MultiplayerSpawner can replicate them to every client, including people who
# join after the fight already started.
#
# The server calls spawn_mob(). The spawner sends the little dictionary to
# every client, each client runs _spawn_from_data with it, and everyone ends up
# with the same enemy at the same spot under the same node name.
class_name MobContainer
extends Node3D

const MOB_SCENE := preload("res://scenes/enemies/mob.tscn")

var _next_index: int = 0


func spawn_mob(mob_id: StringName, spawn_position: Vector3, is_boss_instance: bool = false) -> Node:
	if not multiplayer.is_server():
		return null
	_next_index += 1
	return _spawn_from_data(
		{
			"id": String(mob_id),
			"x": spawn_position.x,
			"y": spawn_position.y,
			"z": spawn_position.z,
			"n": _next_index,
			"boss": is_boss_instance
		}
	)


# Runs on every peer. Must be deterministic: same input, same node.
func _spawn_from_data(data: Variant) -> Node:
	if not (data is Dictionary):
		return null
	var info: Dictionary = data
	var mob := MOB_SCENE.instantiate() as Mob
	if mob == null:
		return null
	mob.name = "Mob_%d" % int(info.get("n", 0))
	var spawn_position := Vector3(
		float(info.get("x", 0.0)), float(info.get("y", 0.0)), float(info.get("z", 0.0))
	)
	mob.position = spawn_position
	mob.home_position = spawn_position
	mob.scale_with_player_count = bool(info.get("boss", false))
	mob.mob_data = MobDatabase.get_mob(StringName(str(info.get("id", ""))))
	return mob
