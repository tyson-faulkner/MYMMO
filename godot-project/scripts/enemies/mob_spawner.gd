# MobSpawner — a marker you drop in a zone: "put four Hedge Bandits around
# here". Placement is content, not code.
#
# Only the server actually spawns; the MobContainer replicates the result.
class_name MobSpawner
extends Node3D

## Which enemy, by id, from MobDatabase.
@export var mob_id: StringName = &"hedge_bandit"

@export_range(1, 12) var count: int = 3

## Enemies are scattered inside this radius so a camp doesn't look like a queue.
@export var scatter_radius: float = 5.0

## Bosses scale with the number of players in the instance.
@export var is_boss_encounter: bool = false

## Where the spawned enemies get parented. Defaults to the nearest MobContainer.
@export var container_path: NodePath


func _ready() -> void:
	# Wait a frame so the whole zone is in the tree before spawning into it.
	call_deferred("_spawn_all")


func _spawn_all() -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var container := _resolve_container()
	if container == null:
		push_warning("MobSpawner '%s' found no MobContainer to spawn into." % name)
		return
	for index in range(count):
		container.spawn_mob(mob_id, _scatter_point(index), is_boss_encounter)


# Spread the group around the marker in a ring, nudged by index so repeated
# spawns of the same camp don't overlap.
func _scatter_point(index: int) -> Vector3:
	if count <= 1 or scatter_radius <= 0.0:
		return global_position
	var angle := TAU * (float(index) / float(count)) + float(index) * 0.7
	var distance := scatter_radius * (0.45 + 0.55 * fposmod(float(index) * 0.37, 1.0))
	return global_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)


func _resolve_container() -> MobContainer:
	if not container_path.is_empty():
		var explicit := get_node_or_null(container_path) as MobContainer
		if explicit:
			return explicit
	var node: Node = self
	while node:
		var found := _find_container_in(node)
		if found:
			return found
		node = node.get_parent()
	return null


func _find_container_in(root: Node) -> MobContainer:
	for child in root.get_children():
		var container := child as MobContainer
		if container:
			return container
	return null
