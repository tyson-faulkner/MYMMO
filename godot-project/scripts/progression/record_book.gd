# RecordBook — your best on every boss, and (on the host) the group's.
#
# docs/kingsmourn-qol-spec.md section 3, "comparisons": your own best matters
# most, then the record. Personal bests are saved with the character. The
# group record is kept by whoever hosts, because the host is what the group
# has in common; if a different friend hosts, they keep their own book.
class_name RecordBook
extends Node

signal book_changed

## boss id -> {"seconds": float, "parse": int, "when": "YYYY-MM-DD"}
var bests: Dictionary = {}
## boss id -> {"seconds": float, "holder": "names", "since": "YYYY-MM-DD"}
var records: Dictionary = {}


func best_seconds(boss_id: StringName) -> float:
	return float(bests.get(String(boss_id), {}).get("seconds", 0.0))


func best_parse(boss_id: StringName) -> int:
	return int(bests.get(String(boss_id), {}).get("parse", 0))


func record_seconds(boss_id: StringName) -> float:
	return float(records.get(String(boss_id), {}).get("seconds", 0.0))


## Server. Returns the lines worth announcing, if any.
func note_best(boss_id: StringName, boss_name: String, seconds: float, parse: int) -> Array:
	var key := String(boss_id)
	var lines := []
	var entry: Dictionary = bests.get(key, {}).duplicate()
	var old_seconds := float(entry.get("seconds", 0.0))
	var old_parse := int(entry.get("parse", 0))
	if old_seconds <= 0.0 or seconds < old_seconds:
		entry["seconds"] = seconds
		if old_seconds > 0.0:
			lines.append("personal best on %s, %s" % [boss_name, CombatRecorder.format_seconds(seconds)])
	if parse > old_parse:
		entry["parse"] = parse
		if old_parse > 0:
			lines.append("best parse on %s, %d" % [boss_name, parse])
	entry["when"] = Time.get_date_string_from_system()
	bests[key] = entry
	book_changed.emit()
	_push()
	return lines


## Server, host's book. Returns the announcement if the record fell.
func note_record(boss_id: StringName, boss_name: String, seconds: float, holder: String) -> String:
	var key := String(boss_id)
	var old_seconds := float(records.get(key, {}).get("seconds", 0.0))
	if old_seconds > 0.0 and seconds >= old_seconds:
		return ""
	records[key] = {"seconds": seconds, "holder": holder, "since": Time.get_date_string_from_system()}
	book_changed.emit()
	_push()
	if old_seconds <= 0.0:
		return ""
	return "Server record on %s: %s by %s" % [boss_name, CombatRecorder.format_seconds(seconds), holder]


func _push() -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var owner_id := get_parent().get_multiplayer_authority()
	if owner_id != 1:
		sync_book.rpc_id(owner_id, bests, records)


@rpc("authority", "reliable")
func sync_book(saved_bests: Dictionary, saved_records: Dictionary) -> void:
	bests = saved_bests.duplicate(true)
	records = saved_records.duplicate(true)
	book_changed.emit()


func to_dict() -> Dictionary:
	return {"bests": bests.duplicate(true), "records": records.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	bests = {}
	records = {}
	for key in data.get("bests", {}):
		var entry: Dictionary = data["bests"][key]
		bests[str(key)] = {"seconds": maxf(0.0, float(entry.get("seconds", 0.0))), "parse": clampi(int(entry.get("parse", 0)), 0, 100), "when": str(entry.get("when", ""))}
	for key in data.get("records", {}):
		var entry: Dictionary = data["records"][key]
		records[str(key)] = {"seconds": maxf(0.0, float(entry.get("seconds", 0.0))), "holder": str(entry.get("holder", "")), "since": str(entry.get("since", ""))}
	book_changed.emit()
	_push()
