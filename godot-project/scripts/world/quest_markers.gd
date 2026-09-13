# QuestMarkers — where a quest objective IS, worked out from data.
#
# docs/ironveil-qol-spec.md section 5: markers are derived, never hand
# placed. A quest names a target; MobDatabase says what that is; the zone's
# spawners say where. Move a camp and the marker moves. Reach objectives use
# the AreaTrigger's box, kill objectives the bounding circle of the matching
# spawners, talk objectives the NPC, collect objectives whoever drops it.
class_name QuestMarkers
extends RefCounted


## {"found": bool, "centre": Vector3, "radius": float, "text": String, "kind": String}
static func objective_area(tree: SceneTree, quest: QuestData, index: int) -> Dictionary:
	var missing := {"found": false, "centre": Vector3.ZERO, "radius": 0.0, "text": quest.objective_text(index) if quest else "", "kind": ""}
	if quest == null or index < 0 or index >= quest.objectives.size():
		return missing
	var objective: Dictionary = quest.objectives[index]
	var kind := str(objective.get("type", ""))
	var target := StringName(str(objective.get("target", "")))
	var scene := tree.get_current_scene()
	if scene == null:
		return missing
	var points: Array[Vector3] = []
	var spreads: Array[float] = []
	match kind:
		"kill", "kill_tag", "collect":
			for node in scene.find_children("*", "Node3D", true, false):
				var spawner := node as MobSpawner
				if spawner == null:
					continue
				var data := MobDatabase.get_mob(spawner.mob_id)
				if data == null:
					continue
				var matches := false
				if kind == "kill":
					matches = spawner.mob_id == target
				elif kind == "kill_tag":
					matches = data.tags.has(target)
				else:
					matches = data.loot_table.has(String(target))
				if matches:
					points.append(spawner.global_position)
					spreads.append(spawner.scatter_radius)
		"talk":
			for node in tree.get_nodes_in_group("NPCs"):
				if node is Node3D and node.get("npc_id") == target:
					points.append((node as Node3D).global_position)
					spreads.append(6.0)
		"reach":
			for node in scene.find_children("*", "Area3D", true, false):
				var trigger := node as AreaTrigger
				if trigger == null or trigger.area_id != target:
					continue
				points.append(trigger.global_position)
				var extent := 10.0
				for child in trigger.get_children():
					var shape := child as CollisionShape3D
					if shape and shape.shape is BoxShape3D:
						var size: Vector3 = (shape.shape as BoxShape3D).size
						extent = maxf(size.x, size.z) * 0.5
				spreads.append(extent)
	if points.is_empty():
		return missing
	var centre := Vector3.ZERO
	for point in points:
		centre += point
	centre /= float(points.size())
	var radius := 0.0
	for i in range(points.size()):
		radius = maxf(radius, centre.distance_to(points[i]) + spreads[i])
	return {"found": true, "centre": centre, "radius": radius + 3.0, "text": quest.objective_text(index), "kind": kind}


## Every unfinished objective of every active quest, numbered to match the
## log, with where it is.
static func active_areas(tree: SceneTree, quest_log: QuestLog) -> Array:
	var areas := []
	if quest_log == null:
		return areas
	var number := 0
	for quest_id in quest_log.active.keys():
		var quest := QuestDatabase.get_quest(quest_id)
		if quest == null:
			continue
		var progress: Array = quest_log.progress_for(quest_id)
		for index in range(quest.objective_count()):
			number += 1
			var have := int(progress[index]) if index < progress.size() else 0
			if have >= quest.objective_required(index):
				continue
			var area := objective_area(tree, quest, index)
			if not bool(area["found"]):
				continue
			area["number"] = number
			area["quest_id"] = quest_id
			area["index"] = index
			area["title"] = quest.title
			areas.append(area)
	return areas


## Does this enemy count for this objective? Drives the marker over its head
## once you arrive, so you are not killing the wrong wolves.
static func mob_matches(mob: Mob, quest: QuestData, index: int) -> bool:
	if mob == null or mob.mob_data == null or quest == null or index < 0 or index >= quest.objectives.size():
		return false
	var objective: Dictionary = quest.objectives[index]
	var kind := str(objective.get("type", ""))
	var target := StringName(str(objective.get("target", "")))
	match kind:
		"kill":
			return mob.mob_data.id == target
		"kill_tag":
			return mob.mob_data.tags.has(target)
		"collect":
			return mob.mob_data.loot_table.has(String(target))
	return false


## The "what now" line for when nothing is tracked: the next quest you could
## pick up, and who has it.
static func what_now(quest_log: QuestLog, level: int) -> String:
	if quest_log == null:
		return ""
	for quest_id in QuestDatabase.get_all_ids():
		var quest := QuestDatabase.get_quest(quest_id)
		if quest == null or not quest_log.can_accept(quest_id):
			continue
		var giver := NpcDatabase.get_npc(quest.giver_id)
		var who := giver.display_name if giver else String(quest.giver_id)
		return "What now: \"%s\" — see %s." % [quest.title, who]
	for quest_id in QuestDatabase.get_all_ids():
		var quest := QuestDatabase.get_quest(quest_id)
		if quest == null or quest_log.is_turned_in(quest_id) or quest_log.is_active(quest_id):
			continue
		if quest.required_level > level:
			return "What now: \"%s\" opens at level %d." % [quest.title, quest.required_level]
	return "What now: the vale is quiet. Try a dungeon."
