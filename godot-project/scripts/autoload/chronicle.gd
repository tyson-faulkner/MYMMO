# Chronicle — your group's history, which is the only kind anyone reads.
#
# docs/ironveil-qol-spec.md section 6. The server keeps a short log of
# notable things: the first fall of each boss (and of each grudge tier),
# personal bests and records, deaths, the season turning over. Ilsa tells you
# the last few when you talk to her, and there is a weekly line. This is also
# where gravestones are raised, since they are history too.
#
# Lives in the host's save (CharacterState writes it for peer 1), synced to
# every peer so Ilsa can answer on a client.
extends Node

signal changed

const MAX_ENTRIES := 60

## Newest first: {"when": "YYYY-MM-DD", "text": String, "kind": String}
var entries: Array = []
## boss id -> {tier(int): true} for "the first time each tier falls"
var first_falls: Dictionary = {}
## name -> deaths this session
var deaths: Dictionary = {}
var last_season: String = ""

var _stone_count: int = 0


func _process(_delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	# A season turned over since the chronicle was last written.
	var season := String(SeasonDatabase.current_id())
	if season != last_season:
		if last_season != "":
			record(SeasonDatabase.turnover_line(), "season")
		last_season = season


# --- Writing it down (server) --------------------------------------------------


func record(text: String, kind: String = "note") -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server() or text.is_empty():
		return
	entries.push_front({"when": Time.get_date_string_from_system(), "text": text, "kind": kind})
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
	changed.emit()
	sync_entries.rpc(entries)


func record_boss_fall(boss_id: StringName, boss_name: String, tier: int, by: Array) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var key := String(boss_id)
	if not first_falls.has(key):
		first_falls[key] = {}
	var names := ", ".join(by) if not by.is_empty() else "nobody who stayed to be counted"
	if first_falls[key].is_empty():
		record("%s fell for the first time, to %s." % [boss_name, names], "boss")
	elif not first_falls[key].has(tier) and tier > 0:
		record("%s fell at grudge ⟨%s⟩ for the first time, to %s." % [boss_name, GrudgeLedger.roman(tier), names], "grudge")
	first_falls[key][tier] = true


func record_lines(lines: Array, kind: String = "record") -> void:
	for line in lines:
		record(str(line), kind)


func record_death(who: String, cause: String) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	deaths[who] = int(deaths.get(who, 0)) + 1
	if int(deaths[who]) == 5:
		record("%s died to %s. That makes five tonight." % [who, cause if not cause.is_empty() else "something"], "death")


# --- Reading it back (any peer) ------------------------------------------------


func recent(count: int = 5) -> Array:
	var lines := []
	for entry in entries.slice(0, count):
		lines.append(str(entry["text"]))
	return lines


## "This week: the First King fell to five; Mike holds the Kell record;
## Tyson died to wolves. Twice."
func weekly_line() -> String:
	var parts := []
	for entry in entries:
		if str(entry["kind"]) == "boss":
			parts.append(str(entry["text"]).trim_suffix("."))
			break
	for entry in entries:
		if str(entry["kind"]) == "record":
			parts.append(str(entry["text"]).trim_suffix("."))
			break
	var worst := ""
	var worst_count := 0
	for who in deaths:
		if int(deaths[who]) > worst_count:
			worst_count = int(deaths[who])
			worst = str(who)
	if worst_count > 0:
		parts.append("%s died %s" % [worst, "once" if worst_count == 1 else ("twice" if worst_count == 2 else "%d times" % worst_count)])
	if parts.is_empty():
		return "This week: nothing worth writing down yet. Go and change that."
	return "This week: " + "; ".join(parts) + "."


@rpc("authority", "reliable")
func sync_entries(list: Array) -> void:
	entries = list.duplicate(true)
	changed.emit()


func to_dict() -> Dictionary:
	return {"entries": entries.duplicate(true), "first_falls": first_falls.duplicate(true), "last_season": last_season}


func from_dict(data: Dictionary) -> void:
	entries = []
	for entry in data.get("entries", []):
		if entry is Dictionary:
			entries.append({"when": str(entry.get("when", "")), "text": str(entry.get("text", "")), "kind": str(entry.get("kind", "note"))})
	first_falls = {}
	for key in data.get("first_falls", {}):
		first_falls[str(key)] = {}
		for tier in data["first_falls"][key]:
			first_falls[str(key)][int(tier)] = true
	last_season = str(data.get("last_season", ""))
	changed.emit()
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_entries.rpc(entries)


# --- Gravestones -----------------------------------------------------------------


## Server: someone fell here. Every peer raises the stone.
func place_gravestone(body: Node3D, where: Vector3, cause: String) -> Gravestone:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server() or body == null:
		return null
	_stone_count += 1
	var who := str(body.name)
	var nickname := body.get_node_or_null("PlayerNick/Nickname") as Label3D
	if nickname and not nickname.text.is_empty():
		who = nickname.text
	var stone_name := "Stone_%d" % _stone_count
	var when_text := Time.get_datetime_string_from_system(false, true)
	spawn_gravestone.rpc(stone_name, where, who, cause, when_text)
	return spawn_gravestone(stone_name, where, who, cause, when_text)


@rpc("authority", "reliable")
func spawn_gravestone(stone_name: String, where: Vector3, who: String, cause: String, when_text: String) -> Gravestone:
	return Gravestone.spawn(get_tree(), stone_name, where, who, cause, when_text)
