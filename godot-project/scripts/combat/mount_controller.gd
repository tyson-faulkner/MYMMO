# MountController — learning, summoning and being thrown off a mount.
#
# Server-authoritative like everything else that matters: the client asks, the
# server decides, the answer is broadcast. A client that simply sets its own
# speed multiplier would be a client that can outrun the game.
#
# The rules, from docs/ironveil-mount-spec.md:
#   - A mount arrives as an item. Using it learns the mount and eats the item.
#   - Summoning puts you on it and multiplies your speed.
#   - Taking damage or attacking throws you off.
#   - No mounts underground: dungeons, the crypt, the raid.
#
# Learned mounts are stored per character today. The spec wants them shared
# across an account; when the Nakama account work lands, `learned` moves from
# CharacterState to the account record and nothing else here changes.
class_name MountController
extends Node

signal mounted_changed(mount_id: StringName)
signal mount_learned(mount_id: StringName)

## Every interior in the world is far underground — the barrow at -500, the
## redoubt at -1000, the crypt, hall and throne below that. So "am I in a
## dungeon" is a question about height, and costs nothing to ask.
const OPEN_WORLD_FLOOR := -100.0

var learned: Dictionary = {}
var current: StringName = &""

var _character: Node3D
var _last_seen_health: int = -1


func _ready() -> void:
	_character = get_parent() as Node3D
	# Getting hit throws you off. Stats has no "took damage" signal, so watch
	# the health it broadcasts and treat any drop as a hit — which also covers
	# damage over time, falling, and anything added later.
	var stats := get_parent().get_node_or_null("Stats") as Stats
	if stats:
		_last_seen_health = stats.health
		stats.health_changed.connect(_on_health_changed)
		stats.died.connect(_on_died)


func _on_health_changed(current: int, _maximum: int) -> void:
	var dropped := _last_seen_health >= 0 and current < _last_seen_health
	_last_seen_health = current
	if dropped and multiplayer.is_server():
		dismount()


func _on_died(_killer_peer_id: int) -> void:
	if multiplayer.is_server():
		dismount()


## Is this mount already known? Learning twice is a no-op, not an error — the
## second copy of a drop should still be lootable, just worthless.
func knows(mount_id: StringName) -> bool:
	return learned.has(mount_id)


func is_mounted() -> bool:
	return current != &""


## Server-side. Returns false when the mount is not real, so callers can leave
## the item in the bag rather than deleting something they failed to use.
func learn(mount_id: StringName) -> bool:
	if not multiplayer.is_server():
		return false
	if not MountDatabase.has_mount(mount_id):
		return false
	if learned.has(mount_id):
		return false
	learned[mount_id] = true
	sync_learned(mount_id)
	sync_learned.rpc(mount_id)
	return true


@rpc("authority", "call_local", "reliable")
func sync_learned(mount_id: StringName) -> void:
	learned[mount_id] = true
	mount_learned.emit(mount_id)


## Why a summon would fail, in words a player can act on. Empty means it works.
func refusal_reason(mount_id: StringName) -> String:
	if not MountDatabase.has_mount(mount_id):
		return "No such mount."
	if not learned.has(mount_id):
		return "You haven't learned that mount."
	if _character == null:
		return "You can't ride right now."
	if _character.global_position.y < OPEN_WORLD_FLOOR:
		return "You can't ride down here."
	var stats := _character.get_node_or_null("Stats") as Stats
	if stats == null or stats.health <= 0:
		return "You can't ride while dead."
	if stats.level < MountDatabase.required_level(mount_id):
		return "You need level %d to ride that." % MountDatabase.required_level(mount_id)
	return ""


## Server-side. Summon a mount, or swap to a different one.
func mount_up(mount_id: StringName) -> bool:
	if not multiplayer.is_server():
		return false
	if not refusal_reason(mount_id).is_empty():
		return false
	_set_mount(mount_id)
	sync_mount.rpc(mount_id)
	return true


## Server-side. Anything that should throw a rider calls this: damage, casting,
## swinging, stepping through a dungeon portal.
func dismount() -> void:
	if not multiplayer.is_server() or current == &"":
		return
	_set_mount(&"")
	sync_mount.rpc(&"")


@rpc("authority", "call_local", "reliable")
func sync_mount(mount_id: StringName) -> void:
	_set_mount(mount_id)


func _set_mount(mount_id: StringName) -> void:
	current = mount_id
	if _character and _character.has_method("set_mount_speed"):
		_character.set_mount_speed(1.0 if mount_id == &"" else MountDatabase.speed_of(mount_id))
	mounted_changed.emit(mount_id)


# --- Client entry point ----------------------------------------------------


## Called by the mount list UI on the owning client.
func request_mount(mount_id: StringName) -> void:
	if multiplayer.is_server():
		_server_request(mount_id)
	else:
		_server_request.rpc_id(1, mount_id)


@rpc("any_peer", "reliable")
func _server_request(mount_id: StringName) -> void:
	if not multiplayer.is_server():
		return
	# Only the player who owns this body may ride it.
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != int(str(_character.name)):
		return
	if is_mounted():
		dismount()
		return
	mount_up(mount_id)


# --- Persistence -----------------------------------------------------------


func to_dict() -> Dictionary:
	var ids: Array[String] = []
	for mount_id in learned:
		ids.append(String(mount_id))
	ids.sort()
	return {"learned": ids}


func from_dict(data: Dictionary) -> void:
	learned.clear()
	for mount_id in data.get("learned", []):
		# A save is untrusted input: a mount that no longer exists is dropped
		# rather than loaded as a phantom the player can summon.
		var id := StringName(str(mount_id))
		if MountDatabase.has_mount(id):
			learned[id] = true
	current = &""
