# Tour screenshots: boots the real game, hosts, and travels the world through
# the actual portals, photographing each stop.
#
#   godot --path godot-project res://tests/tour_shot.tscn
#
# Not headless — it needs a real renderer. Writes PNGs to "Claude outputs/".
extends Node

const LEVEL_SCENE := preload("res://scenes/level/level.tscn")
const OUT_DIR := "res://../Claude outputs/"

var _level: Node3D
var _player: CharacterBody3D
var _camera: Camera3D


func _ready() -> void:
	_level = LEVEL_SCENE.instantiate()
	add_child(_level)
	await _frames(10)

	# The same call the main menu's Host button makes.
	_level._on_host_pressed("Tourist", "valkyr")
	for i in range(120):
		_player = _level.get_node_or_null("PlayersContainer/1") as CharacterBody3D
		if _player:
			break
		await get_tree().process_frame
	if _player == null:
		print("TOUR FAILED: player never spawned")
		get_tree().quit(1)
		return

	var stats := _player.get_node("Stats") as Stats
	stats.level = 20
	print("tour: hosted as Valkyr, level %d" % stats.level)

	_camera = Camera3D.new()
	_camera.fov = 62
	_camera.far = 4000.0
	_level.add_child(_camera)
	_camera.current = true
	await _frames(30)

	# 1. Thornhollow Vale town square.
	await _place(Vector3(0, 1.5, 12))
	await _shot("tour_1_thornhollow_town_square", Vector3(0, 24, 50), Vector3(0, 2, -4))

	# 2. Marcher Road portal, east of the vale -> Sablemarch.
	if not await _through_portal("Marcher Road", Vector3(120, 1.5, 20), Vector3(475, 1.5, 120)):
		return
	await _place(Vector3(600, 1.5, 128))
	await _shot("tour_2_sablemarch_field_camp", Vector3(600, 30, 176), Vector3(600, 2, 100))

	# 3. King's Road portal, east of Sablemarch -> Kingsmourn.
	if not await _through_portal("King's Road", Vector3(735, 1.5, 120), Vector3(1200, 1.5, 168)):
		return
	await _place(Vector3(1200, 1.5, 128))
	await _shot("tour_3_kingsmourn_market_ward", Vector3(1200, 24, 160), Vector3(1200, 3, 92))

	# 4. Kingsmourn palace ward.
	await _place(Vector3(1200, 1.5, -134))
	# Eye sits above and just inside the 12m ward wall (z -110), or it hides the floor.
	await _shot("tour_4_kingsmourn_palace_ward", Vector3(1200, 34, -100), Vector3(1200, 6, -168))

	print("TOUR COMPLETE")
	get_tree().quit(0)


## Put the player's body inside a portal's volume and let the portal move it.
func _through_portal(label: String, portal_pos: Vector3, expected: Vector3) -> bool:
	_player.global_position = portal_pos
	_player.velocity = Vector3.ZERO
	for i in range(90):
		await get_tree().physics_frame
		if _player.global_position.distance_to(expected) < 8.0:
			print("tour: %s portal -> arrived at %s" % [label, _fmt(_player.global_position)])
			await _frames(20)
			return true
	print("TOUR FAILED: %s portal did not move the player (at %s, expected %s)" % [label, _fmt(_player.global_position), _fmt(expected)])
	get_tree().quit(1)
	return false


func _place(pos: Vector3) -> void:
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	await _frames(20)


func _shot(name: String, eye: Vector3, look: Vector3) -> void:
	_camera.global_position = eye
	_camera.look_at(look, Vector3.UP)
	await _frames(12)
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(OUT_DIR) + name + ".png"
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("shot: %s -> %s (err %d)" % [name, path, err])


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _fmt(v: Vector3) -> String:
	return "(%.0f, %.1f, %.0f)" % [v.x, v.y, v.z]
