# Press C in the town square and photograph what comes up.
#
#   godot --path godot-project res://tests/sheet_shot.tscn
#
# Hosts for real, waits for the character to stand in the square, then sends
# the actual "character_sheet" action through the input system — not a call
# into the panel — so what is photographed is what a player gets from the key.
extends Node

const LEVEL_SCENE := preload("res://scenes/level/level.tscn")
const OUT_DIR := "res://../Claude outputs/"

var _level: Node3D
var _player: CharacterBody3D


func _ready() -> void:
	_level = LEVEL_SCENE.instantiate()
	add_child(_level)
	await _frames(10)
	_level._on_host_pressed("Sheet Check", "tinker")
	for i in range(120):
		_player = _level.get_node_or_null("PlayersContainer/1") as CharacterBody3D
		if _player:
			break
		await get_tree().process_frame
	if _player == null:
		print("SHEET SHOT FAILED: player never spawned")
		get_tree().quit(1)
		return
	# The saved character (if Nakama is up) lands a second or two after
	# spawning and replaces the bag and the mount list, so wait for it
	# before handing anything over.
	await get_tree().create_timer(3.0).timeout
	# The save also puts the character back where it logged out. This shot is
	# of the town square, so go there, and let anything that followed leash.
	_player.teleport_to(Vector3(-4, 1.5, 6))
	await get_tree().create_timer(2.0).timeout
	_player.request_add_item("gear_marcher_chest", 1)
	_player.get_node("MountController").learn(&"mount_veil_saber")
	await get_tree().create_timer(1.0).timeout
	await _save("square_before_c")
	# Who is near, and whether anything is hunting the player.
	for node in get_tree().get_nodes_in_group("Hostiles"):
		var mob := node as Mob
		if mob and mob.global_position.distance_to(_player.global_position) < 30.0:
			print("near: %s at %.0fm state=%d target=%s home=%s" % [mob.mob_data.id, mob.global_position.distance_to(_player.global_position), mob.state, str(mob.target.name) if mob.target else "-", str(mob.home_position.round())])
	print("bag: %s  mounts: %s" % [str(_player.get_inventory().get_slot(0).item_id), str(_player.get_node("MountController").learned.keys())])

	_press("character_sheet")
	await _frames(12)
	await _save("square_sheet_gear")
	print("sheet: visible=%s after C" % _level.is_character_sheet_visible())
	var sheet: CharacterSheetUI = _level.character_sheet
	for tab in [1, 2]:
		sheet.show_tab(tab)
		await _frames(6)
		await _save("square_sheet_%s" % sheet.tab_names()[tab].to_lower())

	_press("character_sheet")
	await _frames(6)
	print("sheet: visible=%s after second C" % _level.is_character_sheet_visible())
	print("SHEET SHOT COMPLETE")
	get_tree().quit(0)


## Send a real action press and release, as the keyboard would.
func _press(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func _save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(OUT_DIR) + shot_name + ".png"
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("shot: %s (err %d)" % [shot_name, err])


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
