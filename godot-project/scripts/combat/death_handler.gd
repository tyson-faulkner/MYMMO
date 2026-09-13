# DeathHandler — what happens when you lose.
#
# Ironveil uses WoW's answer, because it is proven and cheap to build: when
# you die you become a ghost, and you choose between two bad options.
#
#   Release   — resurrect at the graveyard immediately, and carry about five
#               minutes of Grave-Chill: weakened, but walking.
#   Corpse run — walk your ghost back to where you died and resurrect there
#               clean, with no timer and no penalty except the walk.
#
# That is the whole death penalty. It costs time, never progress: nothing is
# lost, nothing is destroyed, and nobody is locked out of playing.
class_name DeathHandler
extends Node

signal died_at(position: Vector3)
signal resurrected
signal sickness_changed(seconds_remaining: float)

## How close your ghost has to get to your corpse to reclaim it.
const CORPSE_RECLAIM_RANGE := 5.0
const SICKNESS_SECONDS := 300.0

## A ghost runs at this multiple of living speed. The corpse run is the free
## option, so it has to be quick enough that people actually take it; spirit
## healers are spread through every zone for the same reason.
const GHOST_SPEED := 1.5

## Grave-Chill: everything you do lands for 75% while it lasts. Enough to
## notice, not enough to stop you playing.
const SICKNESS_PENALTY := 0.75

var is_ghost: bool = false
var corpse_position: Vector3 = Vector3.ZERO
var sickness_remaining: float = 0.0

var _stats: Stats = null
var _checked_this_frame: float = 0.0


func _ready() -> void:
	_stats = get_parent().get_node_or_null("Stats") as Stats
	if _stats:
		_stats.died.connect(_on_died)
	set_process(true)


func _process(delta: float) -> void:
	if sickness_remaining > 0.0:
		sickness_remaining = maxf(0.0, sickness_remaining - delta)
		if sickness_remaining == 0.0:
			sickness_changed.emit(0.0)
		elif absf(fmod(sickness_remaining, 1.0) - 0.0) < delta:
			sickness_changed.emit(sickness_remaining)

	if not is_ghost:
		return
	# Only the owner walks their own ghost, so only the owner checks whether it
	# has arrived. It then asks the server, which checks the distance again.
	var body := get_parent() as Node3D
	if body == null or not body.is_multiplayer_authority():
		return
	_checked_this_frame += delta
	if _checked_this_frame < 0.25:
		return
	_checked_this_frame = 0.0
	if body.global_position.distance_to(corpse_position) <= CORPSE_RECLAIM_RANGE:
		request_reclaim_corpse()


func _on_died(_killer_peer_id: int) -> void:
	var body := get_parent() as Node3D
	if body == null:
		return
	if multiplayer.is_server():
		var where := body.global_position
		enter_ghost(where)
		enter_ghost.rpc(where)
		# A stone where it happened, and a line in the book.
		var cause := _stats.last_attacker if _stats else ""
		var stone := Chronicle.place_gravestone(body, where, cause)
		if stone:
			Chronicle.record_death(stone.who, cause)


@rpc("authority", "call_local", "reliable")
func enter_ghost(where: Vector3) -> void:
	is_ghost = true
	corpse_position = where
	_set_ghost_visuals(true)
	_set_ghost_speed(GHOST_SPEED)
	died_at.emit(where)


@rpc("authority", "call_local", "reliable")
func leave_ghost() -> void:
	is_ghost = false
	_set_ghost_visuals(false)
	_set_ghost_speed(1.0)
	resurrected.emit()


func _set_ghost_speed(multiplier: float) -> void:
	var body := get_parent()
	if body and body.has_method("set_ghost_speed"):
		body.set_ghost_speed(multiplier)


# A ghost is see-through and cannot be hit. Mobs already ignore anything whose
# Stats say it is dead, so nothing else needs teaching.
func _set_ghost_visuals(ghost: bool) -> void:
	var body := get_parent() as Node3D
	if body == null:
		return
	var model := body.get_node_or_null("Body") as Node3D
	if model:
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := mesh as MeshInstance3D
			mesh_instance.transparency = 0.65 if ghost else 0.0


# --- Release: resurrect at the graveyard, weakened -------------------------


@rpc("any_peer", "call_local", "reliable")
func request_release() -> void:
	if not multiplayer.is_server():
		return
	var body := get_parent() as Node3D
	if body == null or not is_ghost:
		return
	if multiplayer.get_remote_sender_id() not in [0, body.get_multiplayer_authority()]:
		return
	# The lesser Ferryman's Coin: one free ride back to the body instead.
	if _consume(body, "ferrymans_coin_lesser"):
		_resurrect(corpse_position, false)
		return
	var graveyard := _nearest_graveyard(corpse_position)
	_resurrect(graveyard, true)


## Server. Takes one of a consumable out of the bag if it is there.
func _consume(body: Node3D, item_id: String) -> bool:
	if body == null or not body.has_method("get_inventory"):
		return false
	var inventory = body.get_inventory()
	if inventory == null or inventory.remove_item(item_id, 1) <= 0:
		return false
	if body.has_method("_sync_inventory_to_owner"):
		body._sync_inventory_to_owner()
	return true


# --- Corpse run: resurrect where you fell, clean ---------------------------


@rpc("any_peer", "call_local", "reliable")
func request_reclaim_corpse() -> void:
	if not multiplayer.is_server():
		var body_local := get_parent() as Node3D
		if body_local and body_local.is_multiplayer_authority():
			request_reclaim_corpse.rpc_id(1)
		return
	var body := get_parent() as Node3D
	if body == null or not is_ghost:
		return
	# Re-checked here against the real position, so a client can't reclaim from
	# across the zone.
	if body.global_position.distance_to(corpse_position) > CORPSE_RECLAIM_RANGE + 2.0:
		return
	_resurrect(corpse_position, false)


func _resurrect(where: Vector3, with_sickness: bool) -> void:
	var body := get_parent() as Node3D
	if _stats:
		_stats.revive()
	if body.has_method("teleport_to"):
		body.teleport_to(where)
	else:
		# Anything without the method still has to end up somewhere sensible —
		# silently leaving a released player lying on their own corpse is worse
		# than a fallback that doesn't replicate.
		body.global_position = where
	leave_ghost()
	leave_ghost.rpc()
	if with_sickness:
		# The Marcher's Draught: this one does not take.
		if _consume(body, "marchers_draught"):
			return
		var seconds := SICKNESS_SECONDS
		# The Ferryman's Coin: he knows the way back.
		if body.has_method("get_inventory"):
			var inventory = body.get_inventory()
			if inventory and inventory.has_effect(&"short_grave_chill"):
				seconds *= 0.5
		apply_sickness(seconds)
		apply_sickness.rpc(seconds)


@rpc("authority", "call_local", "reliable")
func apply_sickness(seconds: float) -> void:
	sickness_remaining = seconds
	sickness_changed.emit(seconds)


## Multiplier applied to damage and healing while Grave-Chill lasts.
func output_multiplier() -> float:
	return SICKNESS_PENALTY if sickness_remaining > 0.0 else 1.0


func _nearest_graveyard(from: Vector3) -> Vector3:
	var best := Vector3(0, 2, 20)
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("Graveyards"):
		var marker := node as Node3D
		if marker == null:
			continue
		var distance := from.distance_to(marker.global_position)
		if distance < best_distance:
			best_distance = distance
			best = marker.global_position
	return best
