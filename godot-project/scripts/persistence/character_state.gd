# CharacterState — everything about a character that has to survive logging out,
# turned into a plain Dictionary and back.
#
# Deliberately pure: no Nakama, no networking, no nodes it doesn't read. That
# makes the part most likely to silently corrupt somebody's character the part
# that is easiest to test, and the smoke test round-trips it on every run.
#
# VERSION exists because saves outlive code. When a field changes shape, bump it
# and migrate in `_migrate` rather than letting old saves load as garbage.
class_name CharacterState
extends RefCounted

const VERSION := 1


## Read a live character into a plain dictionary.
static func capture(character: Node) -> Dictionary:
	if character == null:
		return {}
	var data := {"version": VERSION}

	var stats := character.get_node_or_null("Stats") as Stats

	# Stats holds the actual ClassData, so Stats is what the save believes —
	# same rule the ability bar follows. Reading it off the body instead meant
	# the two could disagree and the save would record the wrong class.
	if stats and stats.class_data and stats.class_data.id != &"":
		data["class"] = String(stats.class_data.id)
	elif character.get("class_id") != null:
		data["class"] = String(character.class_id)
	else:
		data["class"] = "valkyr"

	if stats:
		data["level"] = stats.level
		data["experience"] = stats.experience
		data["health"] = stats.health

	var position: Vector3 = character.global_position if character is Node3D else Vector3.ZERO
	data["position"] = {"x": position.x, "y": position.y, "z": position.z}

	var quest_log := character.get_node_or_null("QuestLog") as QuestLog
	if quest_log:
		data["quests"] = quest_log.to_dict()

	var runes := character.get_node_or_null("RuneLoadout") as RuneLoadout
	if runes:
		data["runes"] = runes.to_dict()

	var mounts := character.get_node_or_null("MountController") as MountController
	if mounts:
		data["mounts"] = mounts.to_dict()

	var grudge := character.get_node_or_null("GrudgeLedger") as GrudgeLedger
	if grudge:
		data["grudge"] = grudge.to_dict()

	var records := character.get_node_or_null("RecordBook") as RecordBook
	if records:
		data["records"] = records.to_dict()

	var inventory = character.get_inventory() if character.has_method("get_inventory") else null
	if inventory:
		data["inventory"] = inventory.to_dict()

	return data


## Write a saved dictionary back onto a live character. Everything is clamped
## and defaulted, because a save file is untrusted input like any other — it may
## be old, hand-edited, or truncated.
static func apply(character: Node, data: Dictionary) -> bool:
	if character == null or data.is_empty():
		return false
	var migrated := _migrate(data)

	var saved_class := StringName(str(migrated.get("class", "valkyr")))
	var stats := character.get_node_or_null("Stats") as Stats
	if character.has_method("apply_class"):
		character.apply_class(saved_class)
	elif stats:
		# No body method (a bare rig, or a test double): go straight to Stats,
		# which is where the class actually lives anyway.
		var class_path := "res://resources/classes/%s.tres" % saved_class
		if ResourceLoader.exists(class_path):
			var loaded := load(class_path) as ClassData
			if loaded:
				stats.apply_class(loaded)

	if stats:
		# apply_class already reset health and level, so progression goes on top.
		var level := clampi(int(migrated.get("level", 1)), 1, Stats.MAX_LEVEL)
		var experience := maxi(0, int(migrated.get("experience", 0)))
		stats._set_progression(level, experience)
		if stats.multiplayer.has_multiplayer_peer() and stats.multiplayer.is_server():
			stats._set_progression.rpc(level, experience)
		var health := int(migrated.get("health", stats.max_health))
		if health > 0:
			stats.health = clampi(health, 1, stats.max_health)
			stats.health_changed.emit(stats.health, stats.max_health)

	if character is Node3D and migrated.has("position"):
		var saved: Dictionary = migrated["position"]
		var where := Vector3(
			float(saved.get("x", 0.0)), float(saved.get("y", 2.0)), float(saved.get("z", 0.0))
		)
		if character.has_method("teleport_to"):
			character.teleport_to(where)
		else:
			character.global_position = where

	var quest_log := character.get_node_or_null("QuestLog") as QuestLog
	if quest_log and migrated.has("quests"):
		quest_log.from_dict(migrated["quests"])
		# The owning client needs the restored log too, not just the server.
		if quest_log.multiplayer.has_multiplayer_peer() and quest_log.multiplayer.is_server():
			quest_log._push_to_owner()

	var runes := character.get_node_or_null("RuneLoadout") as RuneLoadout
	if runes and migrated.has("runes"):
		runes.from_dict(migrated["runes"])

	var mounts := character.get_node_or_null("MountController") as MountController
	if mounts and migrated.has("mounts"):
		mounts.from_dict(migrated["mounts"])

	var grudge := character.get_node_or_null("GrudgeLedger") as GrudgeLedger
	if grudge and migrated.has("grudge"):
		grudge.from_dict(migrated["grudge"])

	var records := character.get_node_or_null("RecordBook") as RecordBook
	if records and migrated.has("records"):
		records.from_dict(migrated["records"])

	if migrated.has("inventory") and character.has_method("get_inventory"):
		var inventory = character.get_inventory()
		if inventory:
			inventory.from_dict(migrated["inventory"])
			if character.has_method("_sync_inventory_to_owner"):
				character._sync_inventory_to_owner()
			# Worn gear came back; its numbers have to come back with it, and
			# so does what it looks like in the hand.
			if character.has_method("_refresh_gear_bonuses"):
				character._refresh_gear_bonuses()
			if character.has_method("_sync_equipment_appearance"):
				character._sync_equipment_appearance()

	return true


## Bring an older save up to the current shape. Nothing to do yet — version 1 is
## the first — but the hook exists so the first migration isn't also the first
## time anyone thinks about migrations.
static func _migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 0))
	var migrated := data.duplicate(true)
	if version < 1:
		# Pre-versioned saves: assume the fields that existed, default the rest.
		migrated["version"] = 1
	return migrated


## Cheap sanity check before trusting a blob off the wire or out of storage.
static func looks_valid(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	if not data.has("class"):
		return false
	if int(data.get("level", 0)) < 1 or int(data.get("level", 0)) > Stats.MAX_LEVEL:
		return false
	return true
