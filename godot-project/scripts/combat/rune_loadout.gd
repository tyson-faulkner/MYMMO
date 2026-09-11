# RuneLoadout — which of the two runes you picked, in each of your three slots.
#
# The design doc's build variety lives here: three slots, two choices each,
# eight builds per class. Choices are validated on the server — the rune has to
# belong to your class, sit in the slot you're putting it in, and you have to be
# high enough level for that slot to exist.
#
# Swapping is free and instant. There is no respec cost, because a respec cost
# only ever punishes the people who experiment, which is the entire point of
# having eight builds.
class_name RuneLoadout
extends Node

signal loadout_changed

const SLOT_COUNT := 3

## slot -> rune_id
var chosen: Dictionary = {}


func _get_stats() -> Stats:
	return get_parent().get_node_or_null("Stats") as Stats


func _class_id() -> StringName:
	var stats := _get_stats()
	if stats and stats.class_data and stats.class_data.id != &"":
		return stats.class_data.id
	var body := get_parent()
	if body and body.get("class_id") != null:
		return body.class_id
	return &"valkyr"


func slot_unlocked(slot: int) -> bool:
	var stats := _get_stats()
	var level := stats.level if stats else 1
	return level >= RuneDatabase.level_for_slot(slot)


func rune_in_slot(slot: int) -> RuneData:
	if not chosen.has(slot):
		return null
	if not slot_unlocked(slot):
		return null
	return RuneDatabase.get_rune(StringName(str(chosen[slot])))


## The active rune that changes a given ability, if any. Abilities are only
## touched by a rune sitting in an unlocked slot.
func rune_for_ability(ability_id: StringName) -> RuneData:
	for slot in range(1, SLOT_COUNT + 1):
		var rune := rune_in_slot(slot)
		if rune and rune.ability_id == ability_id:
			return rune
	return null


# --- Choosing --------------------------------------------------------------


@rpc("any_peer", "call_local", "reliable")
func request_choose(slot: int, rune_id_text: String) -> void:
	if not multiplayer.is_server():
		return
	var body := get_parent()
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	if sender != body.get_multiplayer_authority():
		return
	choose(slot, StringName(rune_id_text))


func choose(slot: int, rune_id: StringName) -> bool:
	if slot < 1 or slot > SLOT_COUNT:
		return false
	if rune_id == &"":
		chosen.erase(slot)
		_push()
		return true
	var rune := RuneDatabase.get_rune(rune_id)
	if rune == null:
		return false
	# A rune has to be yours, in the right slot, and unlocked.
	if rune.class_id != _class_id() or rune.slot != slot or not slot_unlocked(slot):
		return false
	chosen[slot] = String(rune_id)
	_push()
	return true


func _push() -> void:
	loadout_changed.emit()
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var owner_id := get_parent().get_multiplayer_authority()
	if owner_id != 1:
		sync_loadout.rpc_id(owner_id, chosen)


@rpc("authority", "reliable")
func sync_loadout(loadout: Dictionary) -> void:
	chosen = loadout.duplicate()
	loadout_changed.emit()


func to_dict() -> Dictionary:
	var out := {}
	for slot in chosen:
		out[str(slot)] = str(chosen[slot])
	return out


func from_dict(data: Dictionary) -> void:
	chosen.clear()
	for slot in data:
		chosen[int(slot)] = str(data[slot])
	loadout_changed.emit()
