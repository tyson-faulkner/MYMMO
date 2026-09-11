# DungeonPortal — walk in here, come out somewhere else.
#
# The Barrow of the First King is a separate region of the same world rather
# than a per-group instance. For a server of five to ten friends that is the
# right trade: it costs almost nothing, and everyone who walks in is in the same
# barrow, which is what a small group wants anyway. Real per-group instancing
# belongs with the persistence work, not before it.
#
# Each player moves their OWN character, because in this template every client
# owns its own body. The portal only says where.
class_name DungeonPortal
extends Area3D

const COOLDOWN_SECONDS := 2.0

@export var destination: Vector3 = Vector3.ZERO

## Shown floating over the portal.
@export var label_text: String = "The Barrow of the First King"

## Minimum level to enter. Sends low players away rather than into a wipe.
@export var required_level: int = 1

## Falling below this on the far side means you fell out of the world there.
## The barrow is far underground, so its limit is not the surface's.
@export var destination_fall_limit: float = -15.0

var _cooldown_until_msec: int = 0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	var label := get_node_or_null("Label") as Label3D
	if label:
		label.text = label_text


func _on_body_entered(body: Node3D) -> void:
	# Only the player who owns this body may move it.
	if not body.is_multiplayer_authority():
		return
	if Time.get_ticks_msec() < _cooldown_until_msec:
		return
	var stats := body.get_node_or_null("Stats") as Stats
	if stats and stats.level < required_level:
		return
	_cooldown_until_msec = Time.get_ticks_msec() + int(COOLDOWN_SECONDS * 1000.0)
	body.global_position = destination
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO
	if body.has_method("set_recovery_point"):
		body.set_recovery_point(destination, destination_fall_limit)
