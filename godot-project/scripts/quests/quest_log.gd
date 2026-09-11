# QuestLog — one player's quest state. Attach as a child node named "QuestLog".
#
# The server owns every number in here. A client can ask to accept or hand in a
# quest, but it can never tell the server "I killed eight bandits" — kill credit
# only ever comes from the server watching something actually die.
class_name QuestLog
extends Node

signal log_changed
signal quest_accepted(quest_id: StringName)
signal quest_completed(quest_id: StringName)
signal quest_turned_in(quest_id: StringName)
signal currency_changed(amount: int)

## quest_id -> Array[int] of progress, one entry per objective.
var active: Dictionary = {}

## quest_id -> true, for quests already handed in.
var turned_in: Dictionary = {}

## Sovereigns. Earned from questing AND dungeons, on purpose.
var currency: int = 0


func _get_stats() -> Stats:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("Stats") as Stats


func _owner_peer_id() -> int:
	var parent := get_parent()
	if parent == null:
		return 0
	return str(parent.name).to_int()


# --- Queries ----------------------------------------------------------------


func is_active(quest_id: StringName) -> bool:
	return active.has(quest_id)


func is_turned_in(quest_id: StringName) -> bool:
	return turned_in.has(quest_id)


func is_complete(quest_id: StringName) -> bool:
	if not active.has(quest_id):
		return false
	var quest := QuestDatabase.get_quest(quest_id)
	if quest == null:
		return false
	var progress: Array = active[quest_id]
	for index in range(quest.objective_count()):
		if index >= progress.size():
			return false
		if int(progress[index]) < quest.objective_required(index):
			return false
	return true


func can_accept(quest_id: StringName) -> bool:
	if active.has(quest_id) or turned_in.has(quest_id):
		return false
	var quest := QuestDatabase.get_quest(quest_id)
	if quest == null:
		return false
	if quest.prerequisite != &"" and not turned_in.has(quest.prerequisite):
		return false
	var stats := _get_stats()
	if stats and stats.level < quest.required_level:
		return false
	return true


func progress_for(quest_id: StringName) -> Array:
	return active.get(quest_id, [])


# --- Server-side mutations --------------------------------------------------


func accept_quest(quest_id: StringName) -> bool:
	if not multiplayer.is_server() or not can_accept(quest_id):
		return false
	var quest := QuestDatabase.get_quest(quest_id)
	var progress: Array = []
	for _index in range(quest.objective_count()):
		progress.append(0)
	active[quest_id] = progress
	quest_accepted.emit(quest_id)
	_push_to_owner()
	return true


## Called by a Mob on the server when it dies. Never by a client.
func credit_kill(mob_id: StringName, tags: Array) -> void:
	if not multiplayer.is_server():
		return
	var changed := false
	for quest_id in active.keys():
		var quest := QuestDatabase.get_quest(quest_id)
		if quest == null:
			continue
		for index in range(quest.objectives.size()):
			var objective: Dictionary = quest.objectives[index]
			var kind := str(objective.get("type", ""))
			var target := StringName(str(objective.get("target", "")))
			var matched := false
			if kind == "kill" and target == mob_id:
				matched = true
			elif kind == "kill_tag" and tags.has(target):
				matched = true
			if matched and _advance(quest_id, index, 1, quest.objective_required(index)):
				changed = true
	if changed:
		_after_progress()


func credit_collect(item_id: StringName, amount: int = 1) -> void:
	if not multiplayer.is_server() or amount <= 0:
		return
	var changed := false
	for quest_id in active.keys():
		var quest := QuestDatabase.get_quest(quest_id)
		if quest == null:
			continue
		for index in range(quest.objectives.size()):
			var objective: Dictionary = quest.objectives[index]
			if str(objective.get("type", "")) != "collect":
				continue
			if StringName(str(objective.get("target", ""))) != item_id:
				continue
			if _advance(quest_id, index, amount, quest.objective_required(index)):
				changed = true
	if changed:
		_after_progress()


func credit_talk(npc_id: StringName) -> void:
	_credit_simple("talk", npc_id)


func credit_reach(area_id: StringName) -> void:
	_credit_simple("reach", area_id)


func _credit_simple(kind: String, target_id: StringName) -> void:
	if not multiplayer.is_server():
		return
	var changed := false
	for quest_id in active.keys():
		var quest := QuestDatabase.get_quest(quest_id)
		if quest == null:
			continue
		for index in range(quest.objectives.size()):
			var objective: Dictionary = quest.objectives[index]
			if str(objective.get("type", "")) != kind:
				continue
			if StringName(str(objective.get("target", ""))) != target_id:
				continue
			if _advance(quest_id, index, 1, quest.objective_required(index)):
				changed = true
	if changed:
		_after_progress()


func _advance(quest_id: StringName, index: int, amount: int, required: int) -> bool:
	var progress: Array = active[quest_id]
	while progress.size() <= index:
		progress.append(0)
	var current := int(progress[index])
	if current >= required:
		return false
	progress[index] = mini(required, current + amount)
	active[quest_id] = progress
	return true


func _after_progress() -> void:
	for quest_id in active.keys():
		if is_complete(quest_id):
			quest_completed.emit(quest_id)
	_push_to_owner()


func turn_in(quest_id: StringName) -> bool:
	if not multiplayer.is_server() or not is_complete(quest_id):
		return false
	var quest := QuestDatabase.get_quest(quest_id)
	if quest == null:
		return false
	active.erase(quest_id)
	turned_in[quest_id] = true
	var stats := _get_stats()
	if stats and quest.experience_reward > 0:
		stats.grant_xp(quest.experience_reward)
	if quest.currency_reward > 0:
		add_currency(quest.currency_reward)
	var parent := get_parent()
	if parent and parent.has_method("request_add_item"):
		for item_id in quest.item_rewards:
			parent.request_add_item(str(item_id), int(quest.item_rewards[item_id]))
	quest_turned_in.emit(quest_id)
	_push_to_owner()
	return true


func add_currency(amount: int) -> void:
	if not multiplayer.is_server() or amount == 0:
		return
	currency = maxi(0, currency + amount)
	currency_changed.emit(currency)
	_push_to_owner()


# --- Syncing to the owning client ------------------------------------------


func _push_to_owner() -> void:
	log_changed.emit()
	if not multiplayer.is_server():
		return
	var payload := to_dict()
	var owner_id := _owner_peer_id()
	if owner_id == 1:
		return
	if owner_id > 0:
		sync_log.rpc_id(owner_id, payload)


@rpc("authority", "reliable")
func sync_log(payload: Dictionary) -> void:
	from_dict(payload)
	log_changed.emit()


func to_dict() -> Dictionary:
	var serialized_active := {}
	for quest_id in active:
		serialized_active[String(quest_id)] = active[quest_id]
	var serialized_done := []
	for quest_id in turned_in:
		serialized_done.append(String(quest_id))
	return {"active": serialized_active, "done": serialized_done, "currency": currency}


func from_dict(payload: Dictionary) -> void:
	active.clear()
	turned_in.clear()
	for quest_id in payload.get("active", {}):
		active[StringName(quest_id)] = payload["active"][quest_id]
	for quest_id in payload.get("done", []):
		turned_in[StringName(quest_id)] = true
	currency = int(payload.get("currency", 0))
	currency_changed.emit(currency)
