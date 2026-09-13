# A stand-in character for reachability checks: it has a real bag and the
# same request methods the real Character exposes, but each request only
# records that it was called. Pressing a button on the character sheet and
# then reading `calls` proves the UI actually reaches the system.
extends CharacterBody3D

var class_id: StringName = &"valkyr"
var inventory := PlayerInventory.new()
var calls: Array = []


func get_inventory() -> PlayerInventory:
	return inventory


func request_equip_gear(from_slot: int) -> void:
	calls.append(["equip", from_slot])


func request_unequip_gear(key_text: String, destination_slot: int = -1) -> void:
	calls.append(["unequip", key_text, destination_slot])


func request_learn_mount(from_slot: int) -> void:
	calls.append(["learn_mount", from_slot])


func called(kind: String) -> Array:
	for call in calls:
		if str(call[0]) == kind:
			return call
	return []
