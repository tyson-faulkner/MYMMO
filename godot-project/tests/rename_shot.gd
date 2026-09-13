# Photograph the two most visible renames: the title on the main menu and
# the sign over the first dungeon's portal.
#
#   godot --path godot-project res://tests/rename_shot.tscn
extends Node

const LEVEL_SCENE := preload("res://scenes/level/level.tscn")
const OUT_DIR := "res://../Claude outputs/"

var _level: Node3D


func _ready() -> void:
	Account.device_id_override = "throwaway-rename-shot"
	_level = LEVEL_SCENE.instantiate()
	add_child(_level)
	await _frames(20)
	await _save("rename_main_menu")
	_level._on_host_pressed("Rename Check", "valkyr")
	var player: Node3D = null
	for i in range(120):
		player = _level.get_node_or_null("PlayersContainer/1") as Node3D
		if player:
			break
		await get_tree().process_frame
	if player == null:
		print("RENAME SHOT FAILED: player never spawned")
		get_tree().quit(1)
		return
	await get_tree().create_timer(3.0).timeout
	# The barrow portal sign, from a free camera in front of it.
	var portal: Node3D = null
	for node in _level.find_children("*", "Area3D", true, false):
		if node is DungeonPortal and str(node.get("label_text")).contains("Deepbarrow"):
			portal = node
			break
	if portal:
		var camera := Camera3D.new()
		_level.add_child(camera)
		camera.current = true
		camera.global_position = portal.global_position + Vector3(0, 3.0, 12.0)
		camera.look_at(portal.global_position + Vector3(0, 2.5, 0), Vector3.UP)
		await _frames(10)
		await _save("rename_barrow_portal")
		print("portal sign: %s" % str(portal.get("label_text")))
	else:
		print("portal: no Deepbarrow portal found")
	print("RENAME SHOT COMPLETE")
	get_tree().quit(0)


func _save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(OUT_DIR) + shot_name + ".png"
	print("shot: %s (err %d)" % [shot_name, get_viewport().get_texture().get_image().save_png(path)])


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
