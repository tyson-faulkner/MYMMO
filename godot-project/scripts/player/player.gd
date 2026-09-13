class_name Character
extends CharacterBody3D

enum SkinColor { BLUE, YELLOW, GREEN, RED }

const NORMAL_SPEED = 6.0
const SPRINT_SPEED = 10.0
const JUMP_VELOCITY = 7.5
const FALL_GRAVITY_MULTIPLIER = 1.6
const BASE_NICKNAME_HEIGHT := 2.0
const SERVER_ANIMATION_REQUESTS_PER_SECOND := 10.0
const SERVER_ANIMATION_REQUEST_BURST := 6.0
const PICKUP_ANIMATION_DELAY_MSEC := 1000
const PICKUP_ANIMATION_WINDOW_MSEC := 2500
const PICKUP_REQUEST_COOLDOWN_MSEC := 1000
const MELEE_DAMAGE := 25
const MELEE_COOLDOWN_MSEC := 700
const ALLOWED_ANIMATION_STATES := {
	&"Idle": true,
	&"Run": true,
	&"Sprint": true,
	&"Jump": true,
	&"Jump2": true,
	&"Fall": true,
	&"Attack1": true,
	&"Emote2": true
}
# What shows on the body for the gear you wear. Weapons are the one
# class-restricted slot, and every tier of a class's weapon is the same model,
# so the tables key on class rather than item id: a Valkyr holding any spear
# shows the Spear. The weapon hand is the right (the attack clip leads with
# it); the off-hand goes on the left or, for the lute and the toolkit, the back.
const CLASS_WEAPON_NODES := {&"valkyr": "Spear", &"bard": "Blade", &"necromancer": "Staff", &"tinker": "BoltThrower"}
const CLASS_OFFHAND_NODES := {&"valkyr": "KiteShield", &"bard": "Lute", &"necromancer": "SkullFocus", &"tinker": "Toolkit"}
const WEAPON_SOCKET_PATH := "Body/RightHandAttach/"
const OFFHAND_SOCKET_PATHS := {
	"KiteShield": "Body/LeftHandAttach/",
	"SkullFocus": "Body/LeftHandAttach/",
	"Lute": "Body/BackAttach/",
	"Toolkit": "Body/BackAttach/"
}
# Head stays empty: the template's hats are gone and helmets are stat gear.
const HAT_NODES_BY_ITEM: Dictionary = {}
const HEAD_EQUIPMENT_PATH := "Body/HeadAttach/"
const BACKPACK_NODES_BY_ITEM := {"backpack": "Backpack"}
const BACK_EQUIPMENT_PATH := "Body/BackAttach/"
const CLASS_RESOURCE_PATHS := {
	&"valkyr": "res://resources/classes/valkyr.tres",
	&"bard": "res://resources/classes/bard.tres",
	&"necromancer": "res://resources/classes/necromancer.tres",
	&"tinker": "res://resources/classes/tinker.tres"
}

@export var skin_color: SkinColor = SkinColor.BLUE

## Which of the four classes this character is. Set when the player spawns, from
## what they picked on the menu. There are no races in Kingsmourn: class and
## gear are the whole of your identity.
@export var class_id: StringName = &"valkyr"

@export_category("Nickname")
@export_range(0.0, 1.0, 0.01) var nickname_clearance: float = 0.2

@export_category("Objects")
@export var _body: Body = null
@export var _spring_arm_offset: SpringArmCharacter = null

var player_inventory: PlayerInventory
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var can_double_jump = true
var has_double_jumped = false
var is_attacking := false
var is_collecting := false

var _current_speed: float
var _spawn_point = Vector3(0, 5, 0)

## Fall below this and you are put back at _spawn_point. Portals move both of
## these, because "too low" means something different inside a barrow that sits
## five hundred metres underground.
var fall_limit_y: float = -15.0

## Snares and march buffs. The server decides it; the owning client is the one
## that actually moves, so the value has to travel to them.
var speed_multiplier: float = 1.0
var _speed_modifier_remaining: float = 0.0

## Riding. Kept apart from speed_multiplier because that one is a timed buff
## that ticks itself away, and a mount has to stay until the rider gets off.
var mount_speed_multiplier: float = 1.0

## Being dead. A ghost moves faster than the living, which is the entire reason
## a corpse run is tolerable — WoW's mistake was making the walk back cost the
## same as the walk out. You cannot be mounted and dead at once, so this never
## stacks with the mount in practice.
var ghost_speed_multiplier: float = 1.0
var _animation_sequence := 0
var _last_applied_animation_sequence := 0
var _last_requested_animation: StringName = &""
var _appearance_sync_requesters: Dictionary = {}
var _server_animation_request_tokens := SERVER_ANIMATION_REQUEST_BURST
var _last_server_animation_token_update_msec := 0
var _server_pickup_animation_started_msec := -1
var _last_server_pickup_request_msec := -PICKUP_REQUEST_COOLDOWN_MSEC
var _last_melee_hit_msec := -MELEE_COOLDOWN_MSEC
var _pickup_area_camera_yaw_offset := 0.0
var _equipped_hat_visual_id := ""

@onready var nickname: Label3D = $PlayerNick/Nickname

@onready var _pickup_area: Area3D = $Body/InfrontArea3D
@onready var _first_person_hud: CanvasLayer = $FirstPersonHUD


func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	$SpringArmOffset/SpringArm3D/Camera3D.current = is_multiplayer_authority()


func _ready():
	if multiplayer.is_server():
		player_inventory = PlayerInventory.new()
		_add_starting_items()
		call_deferred("_sync_equipment_appearance")
		if not is_multiplayer_authority():
			call_deferred("_sync_inventory_to_owner")

	apply_class(class_id)

	set_player_skin(skin_color)
	# Through the body, not its AnimationPlayer: the player is replaced whenever
	# the class model is, and this connection has to survive that.
	_body.animation_finished.connect(_on_animation_finished)
	_body.play_animation_state(&"Idle")
	nickname.visible = true
	_set_nickname_height(BASE_NICKNAME_HEIGHT)
	call_deferred("_update_nickname_height")
	if not multiplayer.is_server():
		call_deferred("_request_equipment_appearance")
	if is_multiplayer_authority() and _spring_arm_offset:
		_pickup_area_camera_yaw_offset = wrapf(
			_pickup_area.global_rotation.y - _spring_arm_offset.global_rotation.y, -PI, PI
		)
		_spring_arm_offset.perspective_changed.connect(_on_camera_perspective_changed)
		_on_camera_perspective_changed(_spring_arm_offset.is_first_person)


func _on_camera_perspective_changed(first_person: bool) -> void:
	if not is_multiplayer_authority():
		return
	_body.visible = true
	_body.set_head_hidden(first_person)
	nickname.visible = not first_person
	_first_person_hud.visible = first_person
	if first_person:
		_align_pickup_area_with_camera()
	else:
		_pickup_area.rotation = Vector3.ZERO
		call_deferred("_refresh_nickname_height_after_perspective_change")


func _refresh_nickname_height_after_perspective_change() -> void:
	if not is_multiplayer_authority() or _is_local_first_person():
		return
	var height := _calculate_nickname_height(_equipped_hat_visual_id)
	_set_nickname_height(height)
	nickname.visible = true
	if multiplayer.is_server():
		_broadcast_nickname_height(height)


func _align_pickup_area_with_camera() -> void:
	var pickup_rotation := _pickup_area.global_rotation
	pickup_rotation.y = wrapf(_spring_arm_offset.global_rotation.y + _pickup_area_camera_yaw_offset, -PI, PI)
	_pickup_area.global_rotation = pickup_rotation


func _physics_process(delta):
	if not multiplayer.has_multiplayer_peer() or not is_multiplayer_authority():
		return

	var current_scene = get_tree().get_current_scene()
	var should_freeze = false
	if current_scene:
		if current_scene.has_method("is_gameplay_input_blocked") and current_scene.is_gameplay_input_blocked():
			should_freeze = true
		elif current_scene.has_method("is_chat_visible") and current_scene.is_chat_visible():
			should_freeze = true
		elif current_scene.has_method("is_inventory_visible") and current_scene.is_inventory_visible():
			should_freeze = true

	if is_attacking or is_collecting:
		velocity.x = 0
		velocity.z = 0
		_apply_gravity(delta)
		move_and_slide()
		return

	if should_freeze:
		_freeze()
		_apply_gravity(delta)
		move_and_slide()
		_request_animation(_body.get_movement_animation(velocity))
		return

	if Input.is_action_just_pressed("pickup") and is_on_floor() and _has_collectible_item_in_front():
		is_collecting = true
		_request_animation(&"Emote2", true)
		return

	if Input.is_action_just_pressed("attack") and is_on_floor():
		_start_attack()
		return

	if is_on_floor():
		can_double_jump = true
		has_double_jumped = false

		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			can_double_jump = true
			_request_animation(&"Jump", true)
	else:
		_apply_gravity(delta)

		if can_double_jump and not has_double_jumped and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			has_double_jumped = true
			can_double_jump = false
			_request_animation(&"Jump2", true)

	_move()
	var collided = move_and_slide()
	if collided:
		_push_collided_items()

	_request_animation(_body.get_movement_animation(velocity))


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var gravity_multiplier = FALL_GRAVITY_MULTIPLIER if velocity.y < 0 else 1.0
	velocity.y -= gravity * gravity_multiplier * delta


func _start_attack() -> void:
	if is_attacking or is_collecting or not is_on_floor():
		return
	is_attacking = true
	velocity.x = 0
	velocity.z = 0
	_request_animation(&"Attack1", true)
	if multiplayer.is_server():
		request_melee_hit()
	else:
		request_melee_hit.rpc_id(1)


# The client asks; the SERVER decides who actually got hit and for how much.
# Never trust the client to report its own damage.
@rpc("any_peer", "call_local", "reliable")
func request_melee_hit() -> void:
	if not multiplayer.is_server() or not _is_owner_request():
		return
	# Ghosts don't get to swing.
	var own_stats := get_node_or_null("Stats") as Stats
	if own_stats and own_stats.is_dead:
		return
	var now := Time.get_ticks_msec()
	if now - _last_melee_hit_msec < MELEE_COOLDOWN_MSEC:
		return
	_last_melee_hit_msec = now
	if not _pickup_area:
		return
	var own_power := 0
	var attacker_stats := get_node_or_null("Stats") as Stats
	if attacker_stats:
		own_power = attacker_stats.total_power()
	for body in _pickup_area.get_overlapping_bodies():
		var target_stats := body.get_node_or_null("Stats") as Stats
		if target_stats and not target_stats.is_dead:
			target_stats.apply_damage(MELEE_DAMAGE + own_power, get_multiplayer_authority())


func _on_animation_finished(animation_name: StringName) -> void:
	match animation_name:
		&"Attack1":
			is_attacking = false
		&"Emote2":
			is_collecting = false


func _request_animation(state: StringName, restart: bool = false) -> void:
	if not ALLOWED_ANIMATION_STATES.has(state):
		return
	if not restart and _last_requested_animation == state:
		return
	_last_requested_animation = state
	_body.play_animation_state(state, restart)
	if multiplayer.is_server():
		request_animation_state(state)
	else:
		request_animation_state.rpc_id(1, state)


@rpc("any_peer", "call_local", "reliable")
func request_animation_state(state: StringName) -> void:
	if not multiplayer.is_server() or not _is_owner_request():
		return
	if not ALLOWED_ANIMATION_STATES.has(state):
		return
	if not _server_consume_animation_request_token():
		return
	if state == &"Emote2":
		if not _is_grounded_on_server() or not _has_collectible_item_in_front():
			return
		_server_pickup_animation_started_msec = Time.get_ticks_msec()
	else:
		_server_pickup_animation_started_msec = -1
	_server_publish_animation(state)


func _server_consume_animation_request_token() -> bool:
	var now := Time.get_ticks_msec()
	if _last_server_animation_token_update_msec == 0:
		_last_server_animation_token_update_msec = now
	else:
		var elapsed_seconds := (now - _last_server_animation_token_update_msec) / 1000.0
		_server_animation_request_tokens = minf(
			SERVER_ANIMATION_REQUEST_BURST,
			_server_animation_request_tokens + elapsed_seconds * SERVER_ANIMATION_REQUESTS_PER_SECOND
		)
		_last_server_animation_token_update_msec = now

	if _server_animation_request_tokens < 1.0:
		return false
	_server_animation_request_tokens -= 1.0
	return true


func _server_publish_animation(state: StringName) -> void:
	if not multiplayer.is_server():
		return
	_animation_sequence += 1
	sync_animation_state.rpc(state, _animation_sequence)
	sync_animation_state(state, _animation_sequence)


@rpc("any_peer", "call_local", "reliable")
func sync_animation_state(state: StringName, sequence: int) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != 1 and not (sender_id == 0 and multiplayer.is_server()):
		return
	if sequence <= _last_applied_animation_sequence:
		return
	_last_applied_animation_sequence = sequence

	if not ALLOWED_ANIMATION_STATES.has(state):
		return

	# The owner already played the input-driven state immediately.
	if is_multiplayer_authority():
		return
	_body.play_animation_state(state, true)


func _push_collided_items() -> void:
	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		if c.get_collider() is RigidBody3D:
			apply_force_to_server_object.rpc_id(1, c.get_collider().name, -c.get_normal())


func _process(_delta: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if not is_multiplayer_authority():
		return
	var first_person := _spring_arm_offset != null and _spring_arm_offset.is_first_person
	if first_person:
		_align_pickup_area_with_camera()
	var camera_input_blocked := false
	var current_scene := get_tree().get_current_scene()
	if current_scene and current_scene.has_method("is_camera_input_blocked"):
		camera_input_blocked = current_scene.is_camera_input_blocked()
	_first_person_hud.visible = (
		first_person and not camera_input_blocked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	)
	_tick_speed_modifier(_delta)
	_check_out_of_bounds()


func _freeze():
	velocity.x = 0
	velocity.z = 0
	_current_speed = 0
	_request_animation(&"Idle")


func _move() -> void:
	var input_direction: Vector2 = Vector2.ZERO
	if is_multiplayer_authority():
		input_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	var direction: Vector3 = transform.basis * Vector3(input_direction.x, 0, input_direction.y).normalized()

	_is_running()
	direction = direction.rotated(Vector3.UP, _spring_arm_offset.rotation.y)

	if direction:
		velocity.x = direction.x * _current_speed
		velocity.z = direction.z * _current_speed
		_body.apply_rotation(velocity)
		return

	velocity.x = move_toward(velocity.x, 0, _current_speed)
	velocity.z = move_toward(velocity.z, 0, _current_speed)


func _is_running() -> bool:
	if Input.is_action_pressed("shift"):
		_current_speed = SPRINT_SPEED * speed_multiplier * mount_speed_multiplier * ghost_speed_multiplier
		return true
	_current_speed = NORMAL_SPEED * speed_multiplier * mount_speed_multiplier * ghost_speed_multiplier
	return false


## Set by MountController when you get on or off. Separate from the timed
## speed modifier so a snare and a mount can coexist without one clearing
## the other.
func set_mount_speed(multiplier: float) -> void:
	mount_speed_multiplier = maxf(0.1, multiplier)


## Set by DeathHandler when you become a ghost and when you come back.
func set_ghost_speed(multiplier: float) -> void:
	ghost_speed_multiplier = maxf(0.1, multiplier)


# Called on the server by AbilityBar; relayed to whoever owns this body.
func apply_speed_modifier(multiplier: float, seconds: float) -> void:
	if not multiplayer.is_server():
		return
	sync_speed_modifier(multiplier, seconds)
	sync_speed_modifier.rpc(multiplier, seconds)


@rpc("authority", "reliable")
func sync_speed_modifier(multiplier: float, seconds: float) -> void:
	speed_multiplier = maxf(0.1, multiplier)
	_speed_modifier_remaining = seconds


func _tick_speed_modifier(delta: float) -> void:
	if _speed_modifier_remaining <= 0.0:
		return
	_speed_modifier_remaining -= delta
	if _speed_modifier_remaining <= 0.0:
		speed_multiplier = 1.0


func _check_out_of_bounds():
	if global_transform.origin.y < fall_limit_y:
		_reset_position_after_fall()


func _reset_position_after_fall():
	global_transform.origin = _spawn_point
	velocity = Vector3.ZERO


## The menu and the network still send a skin colour. Class models carry their
## own painted textures, so it no longer changes how the character looks; it is
## remembered so nothing that sends it breaks.
func set_player_skin(skin_name: SkinColor) -> void:
	skin_color = skin_name


@rpc("any_peer", "call_local", "reliable")
func sync_inventory_to_owner(inventory_data: Dictionary):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != 1 and not (sender_id == 0 and multiplayer.is_server()):
		return

	if not is_multiplayer_authority():
		return

	if not player_inventory:
		player_inventory = PlayerInventory.new()
	player_inventory.from_dict(inventory_data)

	var level_scene = get_tree().get_current_scene()
	if (
		level_scene
		and get_multiplayer_authority() == multiplayer.get_unique_id()
		and level_scene.has_method("update_local_inventory_display")
	):
		level_scene.update_local_inventory_display()


@rpc("any_peer", "call_local", "reliable")
func request_move_item(from_slot: int, to_slot: int, quantity: int = -1):
	if not multiplayer.is_server():
		return

	var requesting_client = multiplayer.get_remote_sender_id()
	if not _is_owner_request():
		push_warning(
			(
				"Client "
				+ str(requesting_client)
				+ " tried to modify inventory for player "
				+ str(get_multiplayer_authority())
			)
		)
		return

	if not player_inventory:
		return

	if not player_inventory.is_slot_active(from_slot) or not player_inventory.is_slot_active(to_slot):
		push_warning("Invalid slot indices: from=" + str(from_slot) + " to=" + str(to_slot))
		return

	if quantity != -1 and quantity <= 0:
		push_warning("Invalid move quantity: " + str(quantity))
		return

	var success = false
	if quantity == -1:
		success = player_inventory.move_item(from_slot, to_slot)
		if not success:
			success = player_inventory.swap_items(from_slot, to_slot)
	else:
		success = player_inventory.move_item(from_slot, to_slot, quantity)

	if success:
		_sync_inventory_to_owner()


@rpc("any_peer", "call_local", "reliable")
func request_add_item(item_id: String, quantity: int = 1):
	if not multiplayer.is_server():
		return

	var requesting_client = multiplayer.get_remote_sender_id()
	var is_local_server_call = requesting_client == 0 and multiplayer.get_unique_id() == 1
	if requesting_client != 1 and not is_local_server_call:
		push_warning(
			"Client " + str(requesting_client) + " tried to add items to player " + str(get_multiplayer_authority())
		)
		return

	if not player_inventory:
		return

	if quantity <= 0:
		push_warning("Invalid quantity: " + str(quantity))
		return

	var item = ItemDatabase.get_item(item_id)
	if not item:
		push_warning("Item not found: " + item_id)
		return

	var remaining = player_inventory.add_item(item, quantity)
	var added = quantity - remaining

	if added > 0:
		_sync_inventory_to_owner()


func request_add_single_item(item_id: String) -> bool:
	if not multiplayer.is_server():
		return false

	if player_inventory == null:
		return false

	var item = ItemDatabase.get_item(item_id)
	if not item:
		push_warning("Item not found: " + item_id)
		return false

	var remaining = player_inventory.add_item(item, 1)

	if remaining == 0:
		_sync_inventory_to_owner()
		return true
	return false


@rpc("any_peer", "call_local", "reliable")
func request_remove_item(item_id: String, quantity: int = 1):
	if not multiplayer.is_server():
		return

	var requesting_client = multiplayer.get_remote_sender_id()
	if not _is_owner_request():
		push_warning(
			(
				"Client "
				+ str(requesting_client)
				+ " tried to remove items from player "
				+ str(get_multiplayer_authority())
			)
		)
		return

	if not player_inventory:
		return

	if quantity <= 0:
		push_warning("Invalid quantity: " + str(quantity))
		return

	var removed = player_inventory.remove_item(item_id, quantity)

	if removed > 0:
		_sync_inventory_to_owner()


@rpc("authority", "call_local", "reliable")
func add_world_item(scene_path: String, player_position: Vector3) -> void:
	var item_container = get_node_or_null("/root/Level/Environment/ItemContainer")
	if not item_container:
		push_warning("ItemContainer not found at /root/Level/Environment/ItemContainer")
		return
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_warning("Cannot add world item: invalid scene path '" + scene_path + "'")
		return
	var packed_scene = load(scene_path) as PackedScene
	if not packed_scene:
		push_warning("Cannot add world item: scene path is not a PackedScene '" + scene_path + "'")
		return
	var instance_item := packed_scene.instantiate() as Node3D
	if not instance_item:
		push_warning("Cannot add world item: scene root is not a Node3D '" + scene_path + "'")
		return
	item_container.add_child(instance_item, true)
	instance_item.global_position = player_position


func get_inventory() -> PlayerInventory:
	return player_inventory


func _sync_inventory_to_owner() -> void:
	if not multiplayer.is_server() or not player_inventory:
		return
	var owner_id = get_multiplayer_authority()
	if owner_id == 1:
		sync_inventory_to_owner(player_inventory.to_dict())
	else:
		sync_inventory_to_owner.rpc_id(owner_id, player_inventory.to_dict())


@rpc("any_peer", "call_local", "reliable")
func request_equip_item(from_slot: int, item_type: Item.ItemType) -> void:
	if not multiplayer.is_server() or not _is_owner_request():
		return
	if not player_inventory or not player_inventory.is_slot_active(from_slot):
		return
	if item_type != Item.ItemType.WEAPON and item_type != Item.ItemType.HAT and item_type != Item.ItemType.BACKPACK:
		return
	if player_inventory.equip_from_slot(from_slot, item_type):
		_sync_inventory_to_owner()
		_sync_equipment_appearance()


@rpc("any_peer", "call_local", "reliable")
func request_unequip_item(item_type: Item.ItemType, destination_slot: int = -1) -> void:
	if not multiplayer.is_server() or not _is_owner_request():
		return
	if not player_inventory:
		return
	if item_type != Item.ItemType.WEAPON and item_type != Item.ItemType.HAT and item_type != Item.ItemType.BACKPACK:
		return
	if destination_slot < -1 or destination_slot >= PlayerInventory.MAX_INVENTORY_SIZE:
		return
	if destination_slot >= 0 and not player_inventory.is_slot_active(destination_slot):
		return
	if player_inventory.unequip_to_slot(item_type, destination_slot):
		_sync_inventory_to_owner()
		_sync_equipment_appearance()


# --- Gear -------------------------------------------------------------------


@rpc("any_peer", "call_local", "reliable")
func request_equip_gear(from_slot: int) -> void:
	if not multiplayer.is_server() or not _is_owner_request():
		return
	if not player_inventory or not player_inventory.is_slot_active(from_slot):
		return
	var stats := get_node_or_null("Stats") as Stats
	var level := stats.level if stats else 1
	# Class and level are checked inside, on the server, so a Bard cannot end
	# up holding a spear and a level 3 cannot wear cap gear.
	if player_inventory.equip_gear_from_slot(from_slot, class_id, level):
		_sync_inventory_to_owner()
		_refresh_gear_bonuses()
		_sync_equipment_appearance()


@rpc("any_peer", "call_local", "reliable")
func request_learn_mount(from_slot: int) -> void:
	if not multiplayer.is_server() or not _is_owner_request():
		return
	if not player_inventory or not player_inventory.is_slot_active(from_slot):
		return
	var slot := player_inventory.get_slot(from_slot)
	if slot == null or slot.is_empty():
		return
	var item: Item = ItemDatabase.get_item(slot.item_id)
	if item == null or item.item_type != Item.ItemType.MOUNT:
		return
	var mounts := get_node_or_null("MountController") as MountController
	if mounts == null:
		return
	# Learning eats the item; failing to learn leaves it in the bag, so a
	# duplicate drop is still worth picking up and selling.
	if mounts.learn(item.mount_id):
		player_inventory.remove_item(slot.item_id, 1)
		_sync_inventory_to_owner()


@rpc("any_peer", "call_local", "reliable")
func request_unequip_gear(key_text: String, destination_slot: int = -1) -> void:
	if not multiplayer.is_server() or not _is_owner_request():
		return
	if not player_inventory:
		return
	if player_inventory.unequip_gear(StringName(key_text), destination_slot):
		_sync_inventory_to_owner()
		_refresh_gear_bonuses()
		_sync_equipment_appearance()


## Total up everything worn and hand it to Stats. Server only.
func _refresh_gear_bonuses() -> void:
	if not multiplayer.is_server() or not player_inventory:
		return
	var stats := get_node_or_null("Stats") as Stats
	if stats == null:
		return
	var totals: Dictionary = player_inventory.gear_totals()
	stats.set_gear_bonuses(int(totals["armor"]), int(totals["power"]), int(totals["stamina"]))


func _is_owner_request() -> bool:
	var sender := multiplayer.get_remote_sender_id()
	return sender == get_multiplayer_authority() or (sender == 0 and multiplayer.is_server())


func _sync_equipment_appearance() -> void:
	if not multiplayer.is_server() or not player_inventory:
		return
	var weapon_id := _worn_gear_id(&"weapon")
	var offhand_id := _worn_gear_id(&"offhand")
	var backpack_id := player_inventory.equipped_backpack.item_id
	var nickname_height := _calculate_nickname_height("")
	_broadcast_nickname_height(nickname_height)
	sync_equipment_appearance.rpc(weapon_id, offhand_id, backpack_id)
	sync_equipment_appearance(weapon_id, offhand_id, backpack_id)


func _worn_gear_id(key: StringName) -> String:
	var slot: InventorySlot = player_inventory.get_gear_slot(key) if player_inventory else null
	return slot.item_id if slot else ""


func _request_equipment_appearance() -> void:
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		return
	request_equipment_appearance.rpc_id(1)


@rpc("any_peer", "reliable")
func request_equipment_appearance() -> void:
	if not multiplayer.is_server() or not player_inventory:
		return
	var requester_id := multiplayer.get_remote_sender_id()
	if requester_id <= 0:
		return
	if _appearance_sync_requesters.has(requester_id):
		return
	_appearance_sync_requesters[requester_id] = true
	_sync_equipment_appearance_to_peer(requester_id)


func _sync_equipment_appearance_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server() or not player_inventory or peer_id <= 0:
		return
	sync_equipment_appearance.rpc_id(peer_id, _worn_gear_id(&"weapon"), _worn_gear_id(&"offhand"), player_inventory.equipped_backpack.item_id)


@rpc("any_peer", "reliable")
func sync_equipment_appearance(weapon_id: String, offhand_id: String, backpack_id: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 1 and not (sender == 0 and multiplayer.is_server()):
		return
	_set_equipment_visibility(weapon_id, offhand_id, backpack_id)


func _set_equipment_visibility(weapon_id: String, offhand_id: String, backpack_id: String) -> void:
	_equipped_hat_visual_id = ""
	var weapon_node := _gear_visual_node(weapon_id, CLASS_WEAPON_NODES)
	for class_id in CLASS_WEAPON_NODES:
		var node_name: String = CLASS_WEAPON_NODES[class_id]
		var node := get_node_or_null(WEAPON_SOCKET_PATH + node_name) as Node3D
		if node:
			node.visible = node_name == weapon_node
	var offhand_node := _gear_visual_node(offhand_id, CLASS_OFFHAND_NODES)
	for class_id in CLASS_OFFHAND_NODES:
		var node_name: String = CLASS_OFFHAND_NODES[class_id]
		var node := get_node_or_null(str(OFFHAND_SOCKET_PATHS[node_name]) + node_name) as Node3D
		if node:
			node.visible = node_name == offhand_node
	_set_equipment_nodes_visibility(BACK_EQUIPMENT_PATH, BACKPACK_NODES_BY_ITEM, backpack_id)


## The node that shows a worn gear item, or "" for nothing. Any tier of a
## class's weapon maps to that class's one model.
func _gear_visual_node(item_id: String, nodes_by_class: Dictionary) -> String:
	if item_id.is_empty():
		return ""
	var item := ItemDatabase.get_item(item_id)
	if item == null or item.item_type != Item.ItemType.GEAR:
		return ""
	return str(nodes_by_class.get(item.class_restriction, ""))


func _broadcast_nickname_height(height: float) -> void:
	if not multiplayer.is_server():
		return
	var level_scene := get_tree().get_current_scene()
	if level_scene and level_scene.has_method("register_player_nickname_height"):
		level_scene.register_player_nickname_height(get_multiplayer_authority(), height)


func _set_equipment_nodes_visibility(parent_path: String, nodes_by_item: Dictionary, equipped_item_id: String) -> void:
	for item_id in nodes_by_item:
		var equipment := get_node_or_null(parent_path + str(nodes_by_item[item_id])) as Node3D
		if equipment:
			equipment.visible = item_id == equipped_item_id


func _update_nickname_height(hat_id: String = "") -> void:
	if not nickname:
		return
	nickname.visible = not _is_local_first_person()
	_set_nickname_height(_calculate_nickname_height(hat_id))


func _calculate_nickname_height(hat_id: String) -> float:
	var target_height := BASE_NICKNAME_HEIGHT
	# Tall silhouettes — the Valkyr's halo and wings — would swallow the name.
	if _body and is_inside_tree():
		var model := _body.get_node_or_null(Body.MODEL_NODE) as Node3D
		if model:
			var model_top := _get_visual_top(model)
			if model_top > -INF and model_top < INF:
				target_height = maxf(target_height, model_top + nickname_clearance)
	var equipped_hat := _get_hat_node(hat_id)
	if equipped_hat:
		var hat_top := _get_visual_top(equipped_hat)
		if hat_top > -INF and hat_top < INF:
			target_height = max(BASE_NICKNAME_HEIGHT, hat_top + nickname_clearance)
	return target_height


func _set_nickname_height(height: float) -> void:
	var nickname_position := nickname.position
	nickname_position.y = height
	nickname.position = nickname_position


func apply_synced_nickname_height(height: float) -> void:
	if not nickname:
		return
	nickname.visible = not _is_local_first_person()
	if height > -INF and height < INF:
		_set_nickname_height(maxf(BASE_NICKNAME_HEIGHT, height))
	else:
		_set_nickname_height(BASE_NICKNAME_HEIGHT)


func _is_local_first_person() -> bool:
	return is_multiplayer_authority() and _spring_arm_offset != null and _spring_arm_offset.is_first_person


func get_current_nickname_height() -> float:
	return nickname.position.y if nickname else BASE_NICKNAME_HEIGHT


func _get_hat_node(hat_id: String) -> Node3D:
	if HAT_NODES_BY_ITEM.has(hat_id):
		var requested_hat_path := HEAD_EQUIPMENT_PATH + str(HAT_NODES_BY_ITEM[hat_id])
		var requested_hat := get_node_or_null(requested_hat_path) as Node3D
		if requested_hat:
			return requested_hat
	return null


func _get_visual_top(root: Node3D) -> float:
	var visual_top := -INF
	if root is MeshInstance3D:
		visual_top = _get_mesh_top(root as MeshInstance3D)

	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance:
			visual_top = max(visual_top, _get_mesh_top(mesh_instance))
	return visual_top


func _get_mesh_top(mesh_instance: MeshInstance3D) -> float:
	var visual_top := -INF
	var mesh_bounds := mesh_instance.get_aabb()
	for endpoint_index in range(8):
		var endpoint_global := mesh_instance.to_global(mesh_bounds.get_endpoint(endpoint_index))
		visual_top = max(visual_top, to_local(endpoint_global).y)
	return visual_top


# Everyone starts in the Levy set: the plain kit a new recruit is issued.
# It goes straight onto the body, so a brand-new character has real numbers
# from the first swing.
func _add_starting_items():
	if not player_inventory:
		return

	var backpack := ItemDatabase.get_item("backpack")
	if backpack:
		player_inventory.add_item(backpack, 1)

	var starter := Item.GearTier.STARTER
	var starting_gear: Array[StringName] = [
		GearDatabase.generated_id(starter, Item.GearSlot.CHEST),
		GearDatabase.generated_id(starter, Item.GearSlot.LEGS),
		GearDatabase.generated_id(starter, Item.GearSlot.FEET),
		GearDatabase.generated_id(starter, Item.GearSlot.WEAPON, class_id)
	]
	for item_id in starting_gear:
		var item := ItemDatabase.get_item(String(item_id))
		if item == null:
			continue
		var key := PlayerInventory.gear_key_for(item)
		var slot: InventorySlot = player_inventory.get_gear_slot(key)
		if slot and slot.is_empty():
			slot.item_id = item.id
			slot.quantity = 1
	call_deferred("_refresh_gear_bonuses")


func pickup() -> void:
	if multiplayer.is_server():
		request_pickup()
	else:
		request_pickup.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func request_pickup() -> void:
	if not multiplayer.is_server() or not _is_owner_request():
		return
	var now := Time.get_ticks_msec()
	if now - _last_server_pickup_request_msec < PICKUP_REQUEST_COOLDOWN_MSEC:
		return
	_last_server_pickup_request_msec = now

	var animation_elapsed := now - _server_pickup_animation_started_msec
	if (
		_server_pickup_animation_started_msec < 0
		or animation_elapsed < PICKUP_ANIMATION_DELAY_MSEC
		or animation_elapsed > PICKUP_ANIMATION_WINDOW_MSEC
	):
		return
	if not _is_grounded_on_server():
		return
	if not _has_collectible_item_in_front():
		return
	_server_pickup_animation_started_msec = -1
	_server_pickup()


func _server_pickup() -> void:
	var quest_log := get_node_or_null("QuestLog") as QuestLog
	for item in _get_collectible_items_in_front():
		var picked_up_id := item.item_id
		var result := request_add_single_item(picked_up_id)
		if result and item.is_inside_tree():
			item.queue_free()
			# "Collect N of something" objectives are credited HERE, on the
			# server, when the item genuinely enters the bag.
			if quest_log:
				quest_log.credit_collect(StringName(picked_up_id), 1)


func _has_collectible_item_in_front() -> bool:
	return not _get_collectible_items_in_front().is_empty()


func _get_collectible_items_in_front() -> Array[ItemRigidBody3D]:
	var collectible_items: Array[ItemRigidBody3D] = []
	var pickup_area := get_node_or_null("Body/InfrontArea3D") as Area3D
	if not pickup_area:
		return collectible_items

	for body in pickup_area.get_overlapping_bodies():
		var item := body as ItemRigidBody3D
		if item and not item.item_id.is_empty() and ItemDatabase.get_item(item.item_id):
			collectible_items.append(item)
	return collectible_items


@rpc("any_peer", "call_local", "reliable")
func apply_force_to_server_object(object_name: String, normal: Vector3) -> void:
	var object_node = get_node_or_null("/root/Level/Environment/ItemContainer")
	if object_node:
		for n in object_node.get_children():
			if n.name == object_name and n is RigidBody3D:
				n.apply_force(normal * 100)


func _is_grounded_on_server() -> bool:
	if not multiplayer.is_server() or not is_inside_tree():
		return false
	var query := PhysicsRayQueryParameters3D.new()
	query.from = global_position + Vector3.UP * 0.15
	query.to = global_position + Vector3.DOWN * 0.3
	query.collision_mask = 2
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# --- Class ------------------------------------------------------------------


## Load the chosen class definition and hand it to Stats, which recomputes
## health, the resource bar and what that bar is called.
func apply_class(new_class_id: StringName) -> void:
	class_id = new_class_id
	if _body:
		_body.set_class_model(class_id)
		# A new silhouette moves the name, and every peer has to hear about it.
		if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			call_deferred("_sync_equipment_appearance")
	var path: String = str(CLASS_RESOURCE_PATHS.get(class_id, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var data := load(path) as ClassData
	if data == null:
		return
	var stats := get_node_or_null("Stats") as Stats
	if stats:
		stats.apply_class(data)


func get_class_data() -> ClassData:
	var path: String = str(CLASS_RESOURCE_PATHS.get(class_id, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as ClassData


## Called by portals: move the character and tell it where "home" and "too far
## down" are now.
func set_recovery_point(point: Vector3, new_fall_limit: float) -> void:
	_spawn_point = point
	fall_limit_y = new_fall_limit


## Move this character somewhere, and make that somewhere the place it recovers
## to. Used by portals and by resurrection.
func teleport_to(where: Vector3) -> void:
	if multiplayer.is_server() and not is_multiplayer_authority():
		sync_teleport.rpc_id(get_multiplayer_authority(), where)
		return
	sync_teleport(where)


@rpc("authority", "call_local", "reliable")
func sync_teleport(where: Vector3) -> void:
	global_position = where
	velocity = Vector3.ZERO
	_spawn_point = where
