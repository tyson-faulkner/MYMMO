# GroundEffect — something on the floor you should not be standing in.
#
# The Bound Ledger's ink pools, and anything else that leaves a puddle. Built
# on every peer (the boss RPCs the recipe, each machine draws its own disc),
# but only the server's copy hurts anyone: it slows and ticks damage on every
# player inside, the same way every other damage source works. A pool with no
# lifetime persists until something clears it — a brazier, or the boss dying.
class_name GroundEffect
extends Node3D

const GROUP := "GroundEffects"
const ROOT_NAME := "GroundEffects"

var radius: float = 3.0
## Movement multiplier while inside. 0.5 is the ink pool's "half speed".
var slow: float = 0.5
var damage_per_tick: int = 0
var tick_seconds: float = 1.0
## Below zero persists.
var remaining_seconds: float = -1.0
## The boss that made it, so "every pool fires" knows whose pools to fire.
var owner_name: String = ""

var _accumulated: float = 0.0


## Every peer runs this from the boss's RPC, so the result is the same on all
## of them: same name, same spot, same size.
static func spawn(
	tree: SceneTree, effect_name: String, at: Vector3, radius_in: float, slow_in: float,
	damage: int, tick: float, seconds: float, made_by: String, color: Color
) -> GroundEffect:
	var root := root_for(tree)
	if root == null:
		return null
	var existing := root.get_node_or_null(effect_name)
	if existing:
		return existing as GroundEffect
	var effect := GroundEffect.new()
	effect.name = effect_name
	effect.radius = radius_in
	effect.slow = slow_in
	effect.damage_per_tick = damage
	effect.tick_seconds = maxf(0.25, tick)
	effect.remaining_seconds = seconds
	effect.owner_name = made_by
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius_in
	mesh.bottom_radius = radius_in
	mesh.height = 0.08
	mesh.radial_segments = 24
	disc.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.35
	disc.material_override = material
	effect.add_child(disc)
	effect.add_to_group(GROUP)
	root.add_child(effect)
	effect.global_position = at + Vector3(0, 0.06, 0)
	return effect


## Pools live under one node in the current scene, made on demand, so the
## MultiplayerSpawner on the mob container never sees them.
static func root_for(tree: SceneTree) -> Node3D:
	var scene := tree.get_current_scene()
	if scene == null:
		return null
	var root := scene.get_node_or_null(ROOT_NAME) as Node3D
	if root == null:
		root = Node3D.new()
		root.name = ROOT_NAME
		scene.add_child(root)
	return root


static func all_in(tree: SceneTree) -> Array[GroundEffect]:
	var found: Array[GroundEffect] = []
	for node in tree.get_nodes_in_group(GROUP):
		var effect := node as GroundEffect
		if effect and not effect.is_queued_for_deletion():
			found.append(effect)
	return found


## Every peer: remove the pools within `clear_radius` of a point. Called from
## an interactable's RPC so all machines lose the same pools.
static func clear_near(tree: SceneTree, centre: Vector3, clear_radius: float) -> int:
	var cleared := 0
	for effect in all_in(tree):
		if effect.global_position.distance_to(centre) <= clear_radius:
			effect.queue_free()
			cleared += 1
	return cleared


func contains(point: Vector3) -> bool:
	var flat := Vector2(point.x - global_position.x, point.z - global_position.z)
	return flat.length() <= radius


func _process(delta: float) -> void:
	if remaining_seconds >= 0.0:
		remaining_seconds -= delta
		if remaining_seconds <= 0.0:
			queue_free()
			return
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var inside: Array[Node3D] = []
	for container in get_tree().get_nodes_in_group("Players"):
		for child in container.get_children():
			var character := child as Node3D
			if character and character.is_inside_tree() and contains(character.global_position):
				inside.append(character)
	for character in inside:
		if slow < 1.0 and character.has_method("apply_speed_modifier"):
			character.apply_speed_modifier(slow, 0.5)
	_accumulated += delta
	while _accumulated >= tick_seconds:
		_accumulated -= tick_seconds
		if damage_per_tick <= 0:
			continue
		for character in inside:
			var stats := character.get_node_or_null("Stats") as Stats
			if stats and not stats.is_dead:
				# Standing in it was a choice: this is the avoidable kind.
				stats.last_attacker = "the ink"
				stats.apply_damage(damage_per_tick, 0, &"pool", true)
