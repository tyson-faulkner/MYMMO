# Interactable — a thing in the world you press F on, or stand on.
#
# The NPC's "walk up, press F" generalised: the Ledger's braziers (a 3s channel
# that burns away the ink pools nearby, then 25s to relight) and the throne
# dais (nothing to press; the Crown mechanic just asks who is standing on it).
# The client asks, the server checks range and cooldown, runs the channel, and
# only then does anything happen — the same shape as every other request.
class_name Interactable
extends Node3D

const GROUP := "Interactables"

@export var interact_id: StringName = &"brazier"
@export var display_name: String = "Brazier"
## What pressing F is called, on the label.
@export var prompt: String = "Light the brazier"
## "clear_pools" burns away GroundEffects within action_radius after the
## channel; "stand" does nothing on its own and just answers is_player_on().
@export var action: String = "clear_pools"
@export var action_radius: float = 6.0
@export var channel_seconds: float = 3.0
@export var cooldown_seconds: float = 25.0
@export var use_range: float = 4.0

var _ready_at_msec: int = 0
var _channel_player: Node3D = null
var _channel_remaining: float = 0.0
## Every peer's copy, so the label can draw the channel.
var _channel_started_msec: int = 0
var _channel_seconds_shown: float = 0.0
var _label: Label3D = null


func _ready() -> void:
	add_to_group(GROUP)
	if action == "stand":
		return
	_label = Label3D.new()
	_label.position = Vector3(0, 2.4, 0)
	_label.pixel_size = 0.0035
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 48
	_label.outline_size = 16
	_label.modulate = Color(1.0, 0.85, 0.6)
	_label.text = display_name
	add_child(_label)


static func find(tree: SceneTree, id: StringName) -> Interactable:
	for node in tree.get_nodes_in_group(GROUP):
		var interactable := node as Interactable
		if interactable and interactable.interact_id == id:
			return interactable
	return null


func is_ready() -> bool:
	return Time.get_ticks_msec() >= _ready_at_msec and _channel_player == null


func seconds_until_ready() -> float:
	return maxf(0.0, float(_ready_at_msec - Time.get_ticks_msec()) / 1000.0)


func is_player_in_range(player: Node3D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	return global_position.distance_to(player.global_position) <= use_range


## For the dais: standing inside action_radius counts.
func is_player_on(player: Node3D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var flat := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z)
	return flat.length() <= action_radius


func _process(_delta: float) -> void:
	if _label == null:
		return
	if _channel_started_msec > 0 and _channel_seconds_shown > 0.0:
		var progress := clampf(float(Time.get_ticks_msec() - _channel_started_msec) / (_channel_seconds_shown * 1000.0), 0.0, 1.0)
		var filled := int(round(progress * 10.0))
		_label.text = "%s\n%s%s" % [display_name, "▮".repeat(filled), "▯".repeat(10 - filled)]
		return
	if not is_ready():
		_label.text = "%s\n(relights in %ds)" % [display_name, int(ceil(seconds_until_ready()))]
		return
	var local_player := _get_local_player()
	if local_player and is_player_in_range(local_player) and _is_nearest_to(local_player):
		_label.text = "%s\n[F] %s" % [display_name, prompt]
	else:
		_label.text = display_name


func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server() or _channel_player == null:
		return
	if not is_player_in_range(_channel_player):
		_finish_channel(false)
		return
	var stats := _channel_player.get_node_or_null("Stats") as Stats
	if stats and stats.is_dead:
		_finish_channel(false)
		return
	_channel_remaining -= delta
	if _channel_remaining <= 0.0:
		var player := _channel_player
		_finish_channel(true)
		perform(player)


func _unhandled_input(event: InputEvent) -> void:
	if action == "stand" or not event.is_action_pressed("interact"):
		return
	var local_player := _get_local_player()
	if local_player == null or not is_player_in_range(local_player) or not _is_nearest_to(local_player):
		return
	if multiplayer.is_server():
		request_use()
	else:
		request_use.rpc_id(1)
	get_viewport().set_input_as_handled()


@rpc("any_peer", "call_local", "reliable")
func request_use() -> void:
	if not multiplayer.is_server():
		return
	var player := _resolve_requesting_player()
	if player == null or not is_player_in_range(player) or not is_ready():
		return
	if channel_seconds <= 0.0:
		perform(player)
		return
	_channel_player = player
	_channel_remaining = channel_seconds
	show_channel(channel_seconds)
	show_channel.rpc(channel_seconds)


## Server. Does the thing, cooldown included. Tests and bosses call it
## straight, skipping the channel.
func perform(player: Node3D) -> void:
	if not multiplayer.is_server():
		return
	match action:
		"clear_pools":
			clear_pools_here()
			clear_pools_here.rpc()
	_ready_at_msec = Time.get_ticks_msec() + int(cooldown_seconds * 1000.0)
	set_cooldown.rpc(cooldown_seconds)


@rpc("authority", "call_local", "reliable")
func clear_pools_here() -> void:
	GroundEffect.clear_near(get_tree(), global_position, action_radius)


@rpc("authority", "reliable")
func set_cooldown(seconds: float) -> void:
	_ready_at_msec = Time.get_ticks_msec() + int(seconds * 1000.0)


@rpc("authority", "call_local", "reliable")
func show_channel(seconds: float) -> void:
	_channel_started_msec = Time.get_ticks_msec()
	_channel_seconds_shown = seconds


@rpc("authority", "call_local", "reliable")
func hide_channel() -> void:
	_channel_started_msec = 0
	_channel_seconds_shown = 0.0


func _finish_channel(_completed: bool) -> void:
	_channel_player = null
	_channel_remaining = 0.0
	hide_channel()
	hide_channel.rpc()


func _resolve_requesting_player() -> Node3D:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	for container in get_tree().get_nodes_in_group("Players"):
		var node := container.get_node_or_null(str(sender))
		if node:
			return node as Node3D
	return null


func _get_local_player() -> Node3D:
	if not multiplayer.has_multiplayer_peer():
		return null
	var local_id := multiplayer.get_unique_id()
	for container in get_tree().get_nodes_in_group("Players"):
		var node := container.get_node_or_null(str(local_id))
		if node:
			return node as Node3D
	return null


func _is_nearest_to(player: Node3D) -> bool:
	var my_distance := global_position.distance_to(player.global_position)
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as Interactable
		if other == null or other == self or other.action == "stand":
			continue
		if other.global_position.distance_to(player.global_position) < my_distance:
			return false
	return true
