# Character and ground screenshots from the real game.
#
#   godot --path godot-project res://tests/character_shot.tscn
#
# Hosts, wears each class model in turn and photographs it from the front (the
# check that it faces the way it walks), then a running pose, the first-person
# camera, and the painted ground in the vale and Sablemarch. Prints the facts a
# picture can't show: whether Idle is still playing after its length has run
# out, and where the first-person camera actually sits. Needs a real renderer,
# so it runs windowed. Writes PNGs to "Claude outputs/".
extends Node

const LEVEL_SCENE := preload("res://scenes/level/level.tscn")
const OUT_DIR := "res://../Claude outputs/"
const CLASSES: Array[StringName] = [&"valkyr", &"bard", &"necromancer", &"tinker"]
const SPOT := Vector3(-6, 1.5, 10)

var _level: Node3D
var _player: CharacterBody3D
var _camera: Camera3D


func _ready() -> void:
	_level = LEVEL_SCENE.instantiate()
	add_child(_level)
	await _frames(10)
	_level._on_host_pressed("Model Check", "valkyr")
	for i in range(120):
		_player = _level.get_node_or_null("PlayersContainer/1") as CharacterBody3D
		if _player:
			break
		await get_tree().process_frame
	if _player == null:
		print("SHOTS FAILED: player never spawned")
		get_tree().quit(1)
		return

	_camera = Camera3D.new()
	_camera.fov = 45
	_camera.far = 4000.0
	_level.add_child(_camera)
	_camera.current = true
	await _frames(30)

	var body: Body = _player._body
	for class_id in CLASSES:
		_player.apply_class(class_id)
		# Hand the class its own starter weapon and off-hand, the way a fresh
		# character of that class would spawn with them.
		var inventory: PlayerInventory = _player.player_inventory
		inventory.get_gear_slot(&"weapon").item_id = String(GearDatabase.generated_id(Item.GearTier.STARTER, Item.GearSlot.WEAPON, class_id))
		inventory.get_gear_slot(&"weapon").quantity = 1
		inventory.get_gear_slot(&"offhand").item_id = String(GearDatabase.generated_id(Item.GearTier.STARTER, Item.GearSlot.OFFHAND, class_id))
		inventory.get_gear_slot(&"offhand").quantity = 1
		_player._sync_equipment_appearance()
		await _place(SPOT)
		body.rotation.y = 0.0
		await _frames(4)
		var forward := body.global_basis.z.normalized()
		var right := body.global_basis.x.normalized()
		var centre := _player.global_position + Vector3(0, 1.0, 0)
		# Front-and-slightly-to-the-side, so the face and the silhouette both read.
		await _shot("char_%s_front" % class_id, centre + forward * 3.4 + right * 1.2 + Vector3(0, 0.35, 0), centre)
		# And from behind, for what hangs on the back socket.
		await _shot("char_%s_back" % class_id, centre - forward * 3.4 - right * 1.2 + Vector3(0, 0.35, 0), centre)
		var shown: Array[String] = []
		for socket in ["RightHandAttach", "LeftHandAttach", "BackAttach"]:
			for child in body.get_node(socket).get_children():
				if child is Node3D and (child as Node3D).visible and not (child is RemoteTransform3D):
					shown.append(child.name)
		print("model: %s wears %s, showing %s" % [class_id, body.model_class, ", ".join(shown)])
		# Where the sockets really are, in Body space. If a weapon hangs wrong,
		# this is the number to read, not the rest pose.
		var skeleton := body.get_skeleton()
		var to_body := body.global_transform.affine_inverse()
		for socket in ["RightHandAttach", "LeftHandAttach", "BackAttach"]:
			var attach := body.get_node(socket) as BoneAttachment3D
			var socket_in_body: Transform3D = to_body * attach.global_transform
			var bone_in_body: Transform3D = to_body * skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(socket))
			print("  socket %-16s node origin=%s x=%s y=%s z=%s" % [socket, _v(socket_in_body.origin), _v(socket_in_body.basis.x), _v(socket_in_body.basis.y), _v(socket_in_body.basis.z)])
			print("         %-16s bone origin=%s x=%s y=%s z=%s" % ["", _v(bone_in_body.origin), _v(bone_in_body.basis.x), _v(bone_in_body.basis.y), _v(bone_in_body.basis.z)])
			for child in attach.get_children():
				if child is Node3D and (child as Node3D).visible and not (child is RemoteTransform3D):
					var w: Transform3D = to_body * (child as Node3D).global_transform
					print("         %-16s up->%s fwd(-z)->%s at %s" % [child.name, _v(w.basis.y), _v(-w.basis.z), _v(w.origin)])

	# Idle is 3.0s long. If it still plays after 4s, it loops.
	body.play_animation_state(&"Idle", true)
	await get_tree().create_timer(4.0).timeout
	print("idle: playing=%s current=%s after 4.0s" % [body.animation_player.is_playing(), body.animation_player.current_animation])

	# Running, seen from the side, out in the open: in the square an NPC stood
	# between the camera and the character.
	await _place(Vector3(34, 1.5, 44))
	body.rotation.y = 0.0
	body.play_animation_state(&"Run", true)
	await get_tree().create_timer(0.35).timeout
	var run_centre := _player.global_position + Vector3(0, 1.0, 0)
	await _shot("char_run_side", run_centre + body.global_basis.x.normalized() * 3.6 + Vector3(0, 0.3, 0), run_centre)
	body.play_animation_state(&"Idle", true)

	# First person, through the player's own camera.
	var arm: SpringArmCharacter = _player._spring_arm_offset
	arm.is_first_person = true
	arm._apply_perspective()
	arm.perspective_changed.emit(true)
	await _frames(10)
	var eye: Vector3 = arm._spring_arm.global_position
	var head := body.get_skeleton().find_bone("Head")
	var head_scale := body.get_skeleton().get_bone_pose_scale(head)
	print("first person: camera %.2fm above the feet, %.2fm ahead of centre, head scale %s" % [
		eye.y - _player.global_position.y,
		(eye - _player.global_position).dot(body.global_basis.z.normalized()),
		head_scale])
	var player_camera := arm._spring_arm.get_node("Camera3D") as Camera3D
	player_camera.current = true
	await _frames(6)
	await _save("char_first_person")
	arm.is_first_person = false
	arm._apply_perspective()
	arm.perspective_changed.emit(false)
	_camera.current = true

	# The painted ground, low enough to see texture rather than colour.
	_camera.fov = 62
	await _place(Vector3(34, 1.5, 44))
	await _shot("ground_vale_grass", Vector3(34, 4.5, 60), Vector3(40, 0, 20))
	await _shot("ground_vale_wide", Vector3(0, 30, 80), Vector3(0, 0, -30))
	await _shot("ground_sablemarch_mud", Vector3(560, 5, 150), Vector3(580, 0, 100))

	print("SHOTS COMPLETE")
	get_tree().quit(0)


func _place(pos: Vector3) -> void:
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	await _frames(15)


func _shot(shot_name: String, eye: Vector3, look: Vector3) -> void:
	_camera.global_position = eye
	_camera.look_at(look, Vector3.UP)
	await _frames(8)
	await _save(shot_name)


func _save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(OUT_DIR) + shot_name + ".png"
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("shot: %s (err %d)" % [shot_name, err])


func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
