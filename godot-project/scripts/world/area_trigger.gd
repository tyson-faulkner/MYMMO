# AreaTrigger — an invisible region that completes a "reach this place"
# objective when a player walks into it.
#
# The server is the one that credits it, so walking here has to actually happen
# in the world everyone shares.
class_name AreaTrigger
extends Area3D

## Matches the objective's "target" in QuestDatabase.
@export var area_id: StringName = &"barrow_approach"

## Optional message shown to the player who arrives.
@export var arrival_text: String = ""

var _already_credited: Dictionary = {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var quest_log := body.get_node_or_null("QuestLog") as QuestLog
	if quest_log == null:
		return
	var peer_id := str(body.name).to_int()
	if _already_credited.has(peer_id):
		return
	_already_credited[peer_id] = true
	quest_log.credit_reach(area_id)
