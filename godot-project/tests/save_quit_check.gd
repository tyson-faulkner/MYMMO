# Save-on-quit check, against a live Nakama. One process per phase, run in order:
#
#   godot --path godot-project res://tests/save_quit_check.tscn -- --phase=write
#       host, change the character, close the window the way the OS does
#   ... -- --phase=verify
#       host again, confirm the change came back, then put the original save back
#   ... -- --phase=dead --flag-dir=<dir>
#       host, wait while Nakama is paused from outside, close the window, and
#       prove the quit still finishes inside the timeout
#
# This uses the machine's real Nakama account, so `write` backs up whatever
# character was saved before and `verify` restores it.
extends Node

const LEVEL_SCENE := preload("res://scenes/level/level.tscn")
const BACKUP_PATH := "user://save_quit_check_backup.json"
const TEST_LEVEL := 13
const TEST_XP := 777
const TEST_SPOT := Vector3(600, 1.5, 128)

var _level: Node
var _player: CharacterBody3D
var _args := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var kv := arg.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1]
	var phase := str(_args.get("phase", ""))

	_level = LEVEL_SCENE.instantiate()
	add_child(_level)
	await _frames(5)
	_level._on_host_pressed("SaveCheck", "blue", "valkyr")
	if not await _wait_for_player() or not await _wait_for_login():
		_finish(1)
		return
	# The spawn-time restore is login -> read -> apply; let it land.
	await _seconds(2.0)

	match phase:
		"write":
			await _phase_write()
		"verify":
			await _phase_verify()
		"dead":
			await _phase_dead()
		_:
			print("CHECK FAILED: unknown phase '%s'" % phase)
			_finish(1)


func _phase_write() -> void:
	if not FileAccess.file_exists(BACKUP_PATH):
		var existing: Dictionary = await Account.load_character()
		var file := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
		file.store_string(JSON.stringify({"had_save": not existing.is_empty(), "save": existing}))
		file.close()
		print("check: backed up the existing save (%s)" % ("present" if not existing.is_empty() else "none"))

	var stats := _player.get_node("Stats") as Stats
	stats._set_progression(TEST_LEVEL, TEST_XP)
	# A level change saves on its own. Moving afterwards means only the quit save
	# can have recorded where the character ends up.
	await _seconds(1.0)
	_player.global_position = TEST_SPOT
	_player.velocity = Vector3.ZERO
	await _frames(3)

	var at := _player.global_position
	print("check: closing the window as level %d, xp %d, at (%.1f, %.1f, %.1f)" % [stats.level, stats.experience, at.x, at.y, at.z])
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	await _seconds(8.0)
	print("CHECK FAILED: still running 8s after the close request")
	_finish(1)


func _phase_verify() -> void:
	var stats := _player.get_node("Stats") as Stats
	for i in range(100):
		if stats.level == TEST_LEVEL:
			break
		await _seconds(0.1)
	await _seconds(0.5)

	var at := _player.global_position
	var progression_ok := stats.level == TEST_LEVEL and stats.experience == TEST_XP
	var spot_ok := Vector2(at.x, at.z).distance_to(Vector2(TEST_SPOT.x, TEST_SPOT.z)) < 3.0
	print("check: logged back in as level %d, xp %d, at (%.1f, %.1f, %.1f)" % [stats.level, stats.experience, at.x, at.y, at.z])
	print("CHECK %s: level/xp %s, position %s" % [
		"PASSED" if progression_ok and spot_ok else "FAILED",
		"came back" if progression_ok else "WRONG",
		"came back" if spot_ok else "WRONG"
	])
	await _restore_backup()
	_finish(0 if progression_ok and spot_ok else 1)


func _phase_dead() -> void:
	var flag_dir := str(_args.get("flag-dir", ""))
	var ready_flag := FileAccess.open(flag_dir.path_join("ready.flag"), FileAccess.WRITE)
	ready_flag.store_string("ready")
	ready_flag.close()
	print("check: logged in; waiting for Nakama to be paused")
	for i in range(300):
		if FileAccess.file_exists(flag_dir.path_join("go.flag")):
			break
		await _seconds(0.1)
	print("check: closing the window with Nakama unresponsive")
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	await _seconds(10.0)
	print("CHECK FAILED: still running 10s after the close request")
	_finish(1)


func _restore_backup() -> void:
	if not FileAccess.file_exists(BACKUP_PATH):
		print("check: no backup to restore")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(BACKUP_PATH))
	var restored := false
	if parsed is Dictionary and bool(parsed.get("had_save", false)):
		restored = await Account.save_character(parsed["save"])
		print("check: original save put back (%s)" % restored)
	else:
		var id := NakamaStorageObjectId.new(Account.COLLECTION, Account.CHARACTER_KEY)
		var result = await Account.client.delete_storage_objects_async(Account.session, [id])
		restored = not result.is_exception()
		print("check: there was no save before; test save deleted (%s)" % restored)
	if restored:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))


func _wait_for_player() -> bool:
	for i in range(120):
		_player = _level.get_node_or_null("PlayersContainer/1") as CharacterBody3D
		if _player:
			return true
		await get_tree().process_frame
	print("CHECK FAILED: player never spawned")
	return false


func _wait_for_login() -> bool:
	for i in range(100):
		if Account.is_logged_in():
			return true
		await _seconds(0.1)
	print("CHECK FAILED: never logged in to Nakama (%s)" % Account.last_error)
	return false


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _finish(code: int) -> void:
	get_tree().quit(code)
