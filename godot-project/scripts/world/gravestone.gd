# Gravestone — a small stone where a player fell, with their name and what
# killed them.
#
# docs/ironveil-qol-spec.md section 6. Anyone can pay respects (a 3s
# channel) for a ten-minute +5% to damage and healing, once per stone per
# player. Three or more stones together are a cairn, and the cairn's buff is
# +8%. Widow's Salt doubles the next one. Stones last a day of play.
class_name Gravestone
extends Interactable

const ROOT_NAME := "Gravestones"
const GROUP_STONES := "Gravestones"
const LIFETIME_SECONDS := 86400.0
const BUFF_SECONDS := 600.0
const RESPECT_SHARE := 0.05
const CAIRN_SHARE := 0.08
const CAIRN_COUNT := 3
const CAIRN_RADIUS := 6.0

var who: String = ""
var cause: String = ""
var when_text: String = ""
var paid_locally: bool = false

var _paid: Dictionary = {}
var _placed_msec: int = 0


static func spawn(tree: SceneTree, stone_name: String, where: Vector3, fallen: String, killed_by: String, when: String) -> Gravestone:
	var scene := tree.get_current_scene()
	if scene == null:
		return null
	var root := scene.get_node_or_null(ROOT_NAME) as Node3D
	if root == null:
		root = Node3D.new()
		root.name = ROOT_NAME
		scene.add_child(root)
	var existing := root.get_node_or_null(stone_name) as Gravestone
	if existing:
		return existing
	var stone := Gravestone.new()
	stone.name = stone_name
	stone.interact_id = StringName(stone_name)
	stone.who = fallen
	stone.cause = killed_by
	stone.when_text = when
	stone.display_name = "Here fell %s" % fallen
	stone.prompt = "Pay respects"
	stone.action = "respects"
	stone.channel_seconds = 3.0
	stone.cooldown_seconds = 0.0
	stone.use_range = 4.0
	root.add_child(stone)
	stone.global_position = where
	return stone


func _ready() -> void:
	super()
	add_to_group(GROUP_STONES)
	_placed_msec = Time.get_ticks_msec()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.8, 0.18)
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.56, 0.58)
	mesh.material_override = material
	mesh.position = Vector3(0, 0.4, 0)
	add_child(mesh)
	if _label:
		_label.position = Vector3(0, 1.4, 0)
		_label.modulate = Color(0.85, 0.88, 0.95)


## Live stones within reach of each other make a cairn.
func is_cairn() -> bool:
	var near := 0
	for node in get_tree().get_nodes_in_group(GROUP_STONES):
		var other := node as Gravestone
		if other and other.is_inside_tree() and other.global_position.distance_to(global_position) <= CAIRN_RADIUS:
			near += 1
	return near >= CAIRN_COUNT


## What the buff is worth: 5%, 8% at a cairn, doubled by Widow's Salt.
static func buff_share(cairn: bool, salted: bool) -> float:
	var share := CAIRN_SHARE if cairn else RESPECT_SHARE
	return share * 2.0 if salted else share


func has_paid(peer_id: int) -> bool:
	return _paid.has(peer_id)


## Server. Once per stone per player.
func perform(player: Node3D) -> void:
	if not multiplayer.is_server() or player == null:
		return
	var peer_id := int(str(player.name)) if str(player.name).is_valid_int() else 0
	if _paid.has(peer_id):
		return
	_paid[peer_id] = true
	var salted := false
	if player.has_method("get_inventory"):
		var inventory = player.get_inventory()
		if inventory and inventory.remove_item("widows_salt", 1) > 0:
			salted = true
			if player.has_method("_sync_inventory_to_owner"):
				player._sync_inventory_to_owner()
	StatusEffect.apply(player, StatusEffect.Kind.OUTPUT_MULT, &"respects", buff_share(is_cairn(), salted), BUFF_SECONDS)
	if peer_id == 1:
		mark_paid()
	elif peer_id > 0:
		mark_paid.rpc_id(peer_id)


@rpc("authority", "reliable")
func mark_paid() -> void:
	paid_locally = true


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - _placed_msec > int(LIFETIME_SECONDS * 1000.0):
		queue_free()
		return
	if _label == null:
		return
	var body := "%s\n%s" % [display_name, cause if not cause.is_empty() else "the vale"]
	if _channel_started_msec > 0 and _channel_seconds_shown > 0.0:
		var progress := clampf(float(Time.get_ticks_msec() - _channel_started_msec) / (_channel_seconds_shown * 1000.0), 0.0, 1.0)
		var filled := int(round(progress * 10.0))
		_label.text = "%s\n%s%s" % [body, "▮".repeat(filled), "▯".repeat(10 - filled)]
		return
	if paid_locally:
		_label.text = "%s\n(respects paid)" % body
		return
	var local_player := _get_local_player()
	if local_player and is_player_in_range(local_player) and _is_nearest_to(local_player):
		_label.text = "%s\n[F] %s%s" % [body, prompt, " at the cairn" if is_cairn() else ""]
	else:
		_label.text = body
