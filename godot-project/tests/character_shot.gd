# Character and ground screenshots from the real game.
#
#   godot --path godot-project res://tests/character_shot.tscn
#
# Hosts, wears each class model in turn and photographs it from the front (the
# check that it faces the way it walks), then a running pose, the first-person
# camera, and the painted ground in the vale and Greymarch. Prints the facts a
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
	# A throwaway account, so the gear and mounts staged here never reach a
	# real character's save.
	Account.device_id_override = "throwaway-character-shot"
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

	# Enemies, as the spawners placed them.
	_camera.fov = 45
	var wanted := ["vale_wolf", "hedge_bandit", "risen_levy", "sunburst_serjeant", "barrow_guardian", "the_first_king"]
	for mob_id in wanted:
		var mob: Node3D = null
		for node in get_tree().get_nodes_in_group("Hostiles"):
			if node.get("mob_data") != null and str(node.mob_data.id) == mob_id:
				mob = node
				break
		if mob == null:
			print("enemy: no %s spawned" % mob_id)
			continue
		# In front of it: look_at() points a mob's -Z at its target.
		var front: Vector3 = -mob.global_basis.z.normalized()
		var eye_height: float = 1.0 * (mob.get_node("Body") as Node3D).scale.y
		var centre: Vector3 = mob.global_position + Vector3(0, eye_height, 0)
		await _shot("enemy_%s" % mob_id, centre + front * 3.2 + Vector3(0.9, 0.6, 0), centre)
		var model := mob.get_node_or_null("Body/Model")
		var player: AnimationPlayer = model.get_node_or_null("AnimationPlayer") if model else null
		print("enemy: %s model=%s clip=%s" % [mob_id, model != null, player.current_animation if player else "-"])

	# A cast bar, above the enemy and in the target frame, and a stun on the
	# player, which the fake player in the smoke test cannot show.
	var binder: Mob = null
	for node in get_tree().get_nodes_in_group("Hostiles"):
		var mob := node as Mob
		if mob and mob.mob_data and mob.mob_data.id == &"hedge_bandit" and not mob.is_friendly:
			binder = mob
			break
	if binder:
		binder.mob_data = binder.mob_data.duplicate()
		binder.mob_data.casts = [{"name": "Grave Bolt", "cast": 6.0, "every": 20.0, "power": 1, "range": 30.0}]
		await _place(binder.global_position + Vector3(0, 0.5, 3.5))
		_player._spring_arm_offset.get_node("SpringArm3D/Camera3D").current = true
		var targeting: Targeting = _player.get_node("Targeting")
		targeting.set_target(binder)
		binder.target = _player
		binder.state = Mob.State.ATTACKING
		var started := binder.start_cast(0, true)
		await get_tree().create_timer(2.0).timeout
		await _save("enemy_cast_bar")
		print("cast: started=%s casting=%s progress=%.2f label=%s" % [started, binder.is_casting, binder.cast_progress(), binder.get_node("CastLabel").visible])
		_player.apply_stun(1.0)
		print("stun: player stunned=%s" % _player.is_stunned())
		_camera.current = true
		# The grudge mark in the name, up close, to prove the font draws it.
		binder.interrupt_cast(0, true)
		binder.set_grudge_tier(4)
		var label_spot := binder.global_position + Vector3(0, 2.3, 0)
		await _shot("grudge_label", label_spot + Vector3(0, 0.3, 3.2), label_spot)
		print("grudge: label=%s" % binder.get_node("NameLabel").text)
		binder.set_grudge_tier(0)

	# The Ledger's vault: an ink pool under the player, a brazier beside it.
	var ledger: Mob = null
	for node in get_tree().get_nodes_in_group("Hostiles"):
		var mob := node as Mob
		if mob and mob.mob_data and mob.mob_data.id == &"the_bound_ledger":
			ledger = mob
			break
	var brazier := Interactable.find(get_tree(), &"brazier_nw")
	if ledger and brazier:
		# Teleporting below the vale's fall limit would bounce us straight back.
		_player.fall_limit_y = -3000.0
		await _place(Vector3(brazier.global_position.x + 3.0, -1499.0, brazier.global_position.z + 2.5))
		await _frames(20)
		ledger.target = _player
		ledger.state = Mob.State.ATTACKING
		ledger._attack_timer = 999.0
		var engine: BossMechanics = ledger.get_node("BossMechanics")
		var made := engine.fire_by_name("Ink Pool")
		engine.fire_by_name("Turn the Page")
		await _frames(12)
		var centre := _player.global_position
		await _shot("boss_ink_pool", centre + Vector3(7.0, 5.0, 9.0), centre + Vector3(0, 0.5, 0))
		print("pool: made=%s pools=%d ledger_casting=%s" % [made, GroundEffect.all_in(get_tree()).size(), ledger.is_casting])
		# The meter while the fight is on, then the recap when it ends.
		var ledger_stats := ledger.get_node("Stats") as Stats
		var bar: AbilityBar = _player.get_node("AbilityBar")
		_player.get_node("Targeting").set_target(ledger)
		for i in range(4):
			bar.request_cast("tinker_shot", ledger.get_path())
			await get_tree().create_timer(0.3).timeout
		CombatRecorder._publish_live()
		await _frames(4)
		await _save("meter_live")
		print("meter: live=%s" % str(CombatRecorder.live))
		ledger_stats.apply_damage(999999, 1)
		await _frames(6)
		await _save("recap_panel")
		print("recap: boss=%s seconds=%.1f awards=%d parse=%s" % [CombatRecorder.last_recap.get("boss_name", "?"), float(CombatRecorder.last_recap.get("seconds", 0.0)), CombatRecorder.last_recap.get("awards", {}).size(), str(CombatRecorder.last_recap.get("parses", {}).get(1, {}).get("score", "?"))])
		ledger.state = Mob.State.IDLE
		ledger.target = null
		ledger._attack_timer = 0.0

	# The twelve-slot bar at level 20 with a spec and a rune move, and the
	# spec chooser open.
	var player_stats: Stats = _player.get_node("Stats")
	player_stats._set_progression(20, 0)
	_player.apply_class(&"bard")
	player_stats.choose_spec(&"hymn", true)
	var runes: RuneLoadout = _player.get_node("RuneLoadout")
	runes.choose(2, &"bard_2b")
	var huds := _level.find_children("*", "GameHUD", true, false)
	if not huds.is_empty():
		(huds[0] as GameHUD)._refresh_slot_labels()
	# The character sheet, one shot per tab, with something on every tab.
	_player.request_add_item("gear_marcher_chest", 1)
	_player.request_add_item("mount_veil_saber", 1)
	_player.get_node("MountController").learn(&"mount_wraithcat")
	var sheet: CharacterSheetUI = _level.character_sheet
	sheet.open_for(_player)
	for tab in range(4):
		sheet.show_tab(tab)
		await _frames(6)
		await _save("sheet_%s" % sheet.tab_names()[tab].to_lower())
	sheet.show_tab(3)
	await _frames(4)
	await _save("spec_chooser_bar")
	sheet.close()
	var bar_ui: AbilityBar = _player.get_node("AbilityBar")
	var names := []
	for slot in range(1, 13):
		var on_bar := bar_ui.ability_in_slot(slot)
		names.append(on_bar.display_name if on_bar else "-")
	print("bar: %s" % ", ".join(names))

	# The quality-of-life pass: back in the square with a quest tracked, the
	# minimap and its arrow, a gravestone, a chest, then the big map.
	if not huds.is_empty():
		var hud: GameHUD = huds[0]
		hud._recap.visible = false
		hud._coach.visible = false
	_player.fall_limit_y = -15.0
	await _place(Vector3(-4, 1.5, 6))
	var log: QuestLog = _player.get_node("QuestLog")
	for quest_id in QuestDatabase.get_all_ids():
		if log.can_accept(quest_id):
			log.accept_quest(quest_id)
			break
	Chronicle.place_gravestone(_player, _player.global_position + Vector3(2.5, 0, 1.5), "a screenshot")
	_player._spring_arm_offset.get_node("SpringArm3D/Camera3D").current = true
	await get_tree().create_timer(1.2).timeout
	await _save("qol_square")
	var chests := _level.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n is Chest)
	print("qol: areas=%d tracked=%s chests=%d stones=%d" % [huds[0]._areas.size() if not huds.is_empty() else -1, str(huds[0]._tracked_quest) if not huds.is_empty() else "?", chests.size(), get_tree().get_nodes_in_group(Gravestone.GROUP_STONES).size()])
	if not huds.is_empty():
		huds[0]._toggle_big_map()
		await _frames(8)
		await _save("qol_big_map")
		huds[0]._toggle_big_map()
	_camera.current = true

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
