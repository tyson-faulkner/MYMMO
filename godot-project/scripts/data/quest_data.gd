# QuestData — one quest, as data.
#
# An objective is a small dictionary so new objective kinds can be added
# without changing every quest:
#   {"type": "kill",    "target": "vale_wolf", "count": 6, "text": "..."}
#   {"type": "kill_tag","target": "bandit",    "count": 8, "text": "..."}
#   {"type": "collect", "target": "bone",      "count": 4, "text": "..."}
#   {"type": "talk",    "target": "npc_id",    "count": 1, "text": "..."}
#   {"type": "reach",   "target": "area_id",   "count": 1, "text": "..."}
class_name QuestData
extends Resource

@export var id: StringName = &""
@export var title: String = ""

## Who hands it out, and who you hand it back to (often the same NPC).
@export var giver_id: StringName = &""
@export var turn_in_id: StringName = &""

@export_multiline var offer_text: String = ""
@export_multiline var progress_text: String = ""
@export_multiline var completion_text: String = ""

@export var objectives: Array = []

@export var required_level: int = 1

## Quests unlock in a chain, so a zone reads as a story instead of a job board.
@export var prerequisite: StringName = &""

@export var experience_reward: int = 0

## Sovereigns — the shared currency earned from BOTH questing and dungeons.
## This is the keystone that keeps both paths worth walking.
@export var currency_reward: int = 0

@export var item_rewards: Dictionary = {}


func objective_count() -> int:
	return objectives.size()


func objective_text(index: int) -> String:
	if index < 0 or index >= objectives.size():
		return ""
	var objective: Dictionary = objectives[index]
	return str(objective.get("text", ""))


func objective_required(index: int) -> int:
	if index < 0 or index >= objectives.size():
		return 0
	var objective: Dictionary = objectives[index]
	return int(objective.get("count", 1))
