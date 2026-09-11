# Targeting — who you are currently pointing at.
#
# Tab-target, as the design doc chose: Tab cycles to the nearest enemy, clicking
# picks a specific one, and both feed the same target underneath. It was chosen
# over action combat deliberately — action combat needs lag compensation, which
# is one of the genuinely hard problems in multiplayer.
#
# This runs only for the player who owns this character. The server re-checks
# the target on every cast, so a client lying about what it has targeted gets it
# thrown out.
class_name Targeting
extends Node

signal target_changed(target: Node3D)

const MAX_TARGET_RANGE := 40.0

var current_target: Node3D = null

var _cycle_index: int = 0


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	if current_target == null:
		return
	# Drop a target that died, despawned or walked off.
	if not is_instance_valid(current_target) or not current_target.is_inside_tree():
		set_target(null)
		return
	var stats := current_target.get_node_or_null("Stats") as Stats
	if stats and stats.is_dead:
		set_target(null)
		return
	var owner_body := get_parent() as Node3D
	if owner_body and owner_body.global_position.distance_to(current_target.global_position) > MAX_TARGET_RANGE:
		set_target(null)


func _unhandled_input(event: InputEvent) -> void:
	var owner_body := get_parent() as Node3D
	if owner_body == null or not owner_body.is_multiplayer_authority():
		return
	if event.is_action_pressed("target_next"):
		cycle_nearest()
		get_viewport().set_input_as_handled()


func set_target(target: Node3D) -> void:
	if current_target == target:
		return
	current_target = target
	target_changed.emit(target)


## Tab: step through hostiles by distance, nearest first, then wrap.
func cycle_nearest() -> void:
	var candidates := hostiles_in_range()
	if candidates.is_empty():
		set_target(null)
		return
	if current_target == null or not candidates.has(current_target):
		_cycle_index = 0
	else:
		_cycle_index = (candidates.find(current_target) + 1) % candidates.size()
	set_target(candidates[_cycle_index])


func hostiles_in_range() -> Array[Node3D]:
	var found: Array[Node3D] = []
	var owner_body := get_parent() as Node3D
	if owner_body == null:
		return found
	for node in get_tree().get_nodes_in_group("Hostiles"):
		var mob := node as Mob
		if mob == null or not mob.is_inside_tree() or mob.is_friendly:
			continue
		var stats := mob.get_node_or_null("Stats") as Stats
		if stats and stats.is_dead:
			continue
		if owner_body.global_position.distance_to(mob.global_position) <= MAX_TARGET_RANGE:
			found.append(mob)
	found.sort_custom(
		func(a: Node3D, b: Node3D) -> bool:
			return (
				owner_body.global_position.distance_to(a.global_position)
				< owner_body.global_position.distance_to(b.global_position)
			)
	)
	return found
