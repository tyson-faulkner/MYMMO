# CombatRecorder — every hit, heal, death and interrupt, written down once.
#
# docs/kingsmourn-qol-spec.md sections 1-3. The server already owns every
# number an addon would want, so the meter, the recap, the coach and the parse
# are all just reads of this list. Nobody can fudge their bars.
#
# The server records. Once a second it sends every peer the live totals (the
# meter); when a boss dies it sends everyone the recap: time to kill, the three
# columns, awards, each player's parse and three coaching sentences. Trash is
# recorded for the live meter but never scored.
#
# A fight starts when a boss takes damage and ends on its death or a wipe. A
# boss that walks home throws the fight away. Raw events are kept only for
# the fight in progress; nobody reads last Tuesday's log.
extends Node

signal fight_started(boss_id: StringName)
signal fight_ended(recap: Dictionary)
signal meter_updated(live: Dictionary)

const METER_SYNC_SECONDS := 1.0
## Quiet this long and the live meter's window starts over.
const OUT_OF_COMBAT_SECONDS := 8.0
## How wide a "were you doing anything" bucket is for uptime.
const UPTIME_BUCKET_SECONDS := 2.5
## A wipe is everyone this close to the boss being dead.
const WIPE_RANGE := 80.0

## Output per second a fresh character of each class should manage with no
## gear. The gear score scales it (see baseline_for). Tuned by playing.
const BASELINE := {
	&"valkyr": {"dps": 9.0, "hps": 0.0},
	&"bard": {"dps": 6.0, "hps": 11.0},
	&"necromancer": {"dps": 12.0, "hps": 0.0},
	&"tinker": {"dps": 11.5, "hps": 0.0}
}
const CLASS_COLOURS := {
	&"valkyr": Color(0.86, 0.66, 0.26),
	&"bard": Color(0.38, 0.62, 0.9),
	&"necromancer": Color(0.62, 0.38, 0.72),
	&"tinker": Color(0.86, 0.5, 0.26)
}
## WoW's parse colours, because everyone already knows them.
const PARSE_COLOURS := [
	[95, "orange", Color(1.0, 0.5, 0.0)],
	[75, "purple", Color(0.64, 0.21, 0.93)],
	[50, "blue", Color(0.0, 0.44, 1.0)],
	[25, "green", Color(0.12, 1.0, 0.0)],
	[0, "grey", Color(0.4, 0.4, 0.4)]
]

# --- Server side ---
var _fight: Dictionary = {}
var _events: Array = []
var _window_started_msec: int = 0
var _last_event_msec: int = 0
var _sync_accumulated: float = 0.0

# --- Every peer ---
var live: Dictionary = {}
var last_recap: Dictionary = {}
var history: Array = []


func _process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	if not _fight.is_empty():
		_watch_fight()
	_sync_accumulated += delta
	if _sync_accumulated >= METER_SYNC_SECONDS:
		_sync_accumulated = 0.0
		_publish_live()


func in_fight() -> bool:
	return not _fight.is_empty()


func current_boss_id() -> StringName:
	return StringName(str(_fight.get("boss_id", ""))) if not _fight.is_empty() else &""


# --- Recording (server) -------------------------------------------------------


## Called by Stats after armour and shields: what actually came off the bar.
func record_damage(target: Node, source_peer_id: int, amount: int, ability_id: StringName, avoidable: bool, killed: bool) -> void:
	if not _serving() or target == null or amount <= 0:
		return
	var target_mob := target as Mob
	var boss_hit := target_mob != null and target_mob.mob_data != null and target_mob.mob_data.is_boss and not target_mob.is_friendly
	if boss_hit and _fight.is_empty():
		_start_fight(target_mob)
	var event := _event("damage", source_peer_id, target, amount, ability_id)
	event["avoidable"] = avoidable
	_push(event)
	if killed:
		var death := _event("death", source_peer_id, target, 0, ability_id)
		_push(death)
		if boss_hit and not _fight.is_empty() and _fight.get("boss") == target_mob:
			_end_fight(false)


func record_heal(target: Node, source_peer_id: int, amount: int, ability_id: StringName) -> void:
	if not _serving() or target == null or amount <= 0:
		return
	_push(_event("heal", source_peer_id, target, amount, ability_id))


## A player pressed something and the server let it happen.
func record_cast(peer_id: int, ability_id: StringName) -> void:
	if not _serving():
		return
	_push(_event("cast", peer_id, null, 0, ability_id))


func record_interrupt(peer_id: int, boss_name: String) -> void:
	if not _serving():
		return
	var event := _event("interrupt", peer_id, null, 1, &"")
	event["what"] = boss_name
	_push(event)


## A boss began a cast the party could have stopped. "Interrupts available".
func record_boss_cast(boss: Node, interruptible: bool) -> void:
	if not _serving() or not interruptible:
		return
	_push(_event("boss_cast", 0, boss, 0, &""))


func _serving() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func _event(kind: String, source_peer_id: int, target: Node, amount: int, ability_id: StringName) -> Dictionary:
	var target_peer := 0
	var target_boss := false
	if target:
		target_peer = _peer_of(target)
		var mob := target as Mob
		target_boss = mob != null and mob.mob_data != null and mob.mob_data.is_boss
	return {
		"t": Time.get_ticks_msec(),
		"kind": kind,
		"src": source_peer_id,
		"tgt": target_peer,
		"tgt_boss": target_boss,
		"ability": String(ability_id),
		"amount": amount
	}


func _push(event: Dictionary) -> void:
	var now := int(event["t"])
	if now - _last_event_msec > int(OUT_OF_COMBAT_SECONDS * 1000.0):
		# A new stretch of combat: the live meter starts over.
		if _fight.is_empty():
			_events.clear()
		_window_started_msec = now
	_last_event_msec = now
	_events.append(event)


func _peer_of(node: Node) -> int:
	if node == null:
		return 0
	if node is Mob:
		return 0
	# Player bodies are named after their peer id.
	var peer := int(str(node.name)) if str(node.name).is_valid_int() else 0
	return peer


# --- Fight boundaries (server) -----------------------------------------------


func _start_fight(boss: Mob) -> void:
	_events.clear()
	_window_started_msec = Time.get_ticks_msec()
	_fight = {
		"boss": boss,
		"boss_id": String(boss.mob_data.id),
		"boss_name": boss.mob_data.display_name,
		"tier": boss.grudge_tier,
		"started": Time.get_ticks_msec(),
		"max_health": boss.get_node("Stats").max_health if boss.get_node_or_null("Stats") else 1
	}
	fight_started.emit(StringName(_fight["boss_id"]))


func _watch_fight() -> void:
	var boss: Mob = _fight.get("boss")
	if boss == null or not is_instance_valid(boss) or not boss.is_inside_tree():
		_fight.clear()
		return
	if boss.state == Mob.State.RETURNING or boss.state == Mob.State.IDLE:
		# Walked home. Nobody gets scored for that.
		_fight.clear()
		_events.clear()
		return
	var anyone_alive := false
	var anyone_near := false
	for character in boss._players_within(WIPE_RANGE):
		anyone_near = true
		var stats := character.get_node_or_null("Stats") as Stats
		if stats == null or not stats.is_dead:
			anyone_alive = true
	if anyone_near and not anyone_alive:
		_end_fight(true)


func _end_fight(wiped: bool) -> void:
	var recap := build_recap(_fight, _events, wiped)
	_fight.clear()
	_events.clear()
	receive_recap(recap)
	receive_recap.rpc(recap)


# --- The live meter -----------------------------------------------------------


func _publish_live() -> void:
	var totals := {}
	if Time.get_ticks_msec() - _last_event_msec > int(OUT_OF_COMBAT_SECONDS * 1000.0) and _fight.is_empty():
		if not live.is_empty():
			receive_live({})
			receive_live.rpc({})
		return
	for event in _events:
		var kind: String = event["kind"]
		if kind == "damage":
			if int(event["src"]) > 0:
				_bump(totals, int(event["src"]), "damage", int(event["amount"]))
			if int(event["tgt"]) > 0:
				_bump(totals, int(event["tgt"]), "taken", int(event["amount"]))
		elif kind == "heal" and int(event["src"]) > 0:
			_bump(totals, int(event["src"]), "healing", int(event["amount"]))
	for peer_id in totals:
		var character := _find_player(peer_id)
		totals[peer_id]["name"] = _name_of(character, peer_id)
		totals[peer_id]["class"] = String(_class_of(character))
	receive_live(totals)
	receive_live.rpc(totals)


func _bump(totals: Dictionary, peer_id: int, column: String, amount: int) -> void:
	if not totals.has(peer_id):
		totals[peer_id] = {"damage": 0, "healing": 0, "taken": 0}
	totals[peer_id][column] = int(totals[peer_id][column]) + amount


@rpc("authority", "call_local", "unreliable_ordered")
func receive_live(totals: Dictionary) -> void:
	live = totals
	meter_updated.emit(live)


@rpc("authority", "call_local", "reliable")
func receive_recap(recap: Dictionary) -> void:
	last_recap = recap
	history.append(recap)
	fight_ended.emit(recap)


# --- The recap ---------------------------------------------------------------


## Pure: a fight and its events in, the whole recap out. Tests call this with
## hand-built events too.
func build_recap(fight: Dictionary, events: Array, wiped: bool) -> Dictionary:
	var started := int(fight.get("started", 0))
	var ended := started
	for event in events:
		ended = maxi(ended, int(event["t"]))
	var seconds := maxf(1.0, float(ended - started) / 1000.0)
	var boss_id := str(fight.get("boss_id", ""))
	var max_health := int(fight.get("max_health", 1))

	# Per-player tallies.
	var players := {}
	var first_blood := 0
	var killing_blow := 0
	var boss_casts := 0
	for event in events:
		var kind: String = event["kind"]
		var src := int(event["src"])
		var tgt := int(event["tgt"])
		if src > 0:
			_tally(players, src)
		if tgt > 0:
			_tally(players, tgt)
		match kind:
			"damage":
				if src > 0:
					players[src]["damage"] += int(event["amount"])
					_ability_tally(players[src], str(event["ability"]), int(event["amount"]))
					if bool(event.get("tgt_boss", false)) and first_blood == 0:
						first_blood = src
				if tgt > 0:
					players[tgt]["taken"] += int(event["amount"])
					if src == 0:
						players[tgt]["boss_taken"] += int(event["amount"])
					if bool(event.get("avoidable", false)):
						players[tgt]["avoidable_hits"] += 1
						players[tgt]["avoidable_amount"] += int(event["amount"])
			"heal":
				if src > 0:
					players[src]["healing"] += int(event["amount"])
					_ability_tally(players[src], str(event["ability"]), int(event["amount"]))
			"death":
				if tgt > 0:
					players[tgt]["deaths"] += 1
				elif bool(event.get("tgt_boss", false)) and src > 0:
					killing_blow = src
			"interrupt":
				if src > 0:
					players[src]["interrupts"] += 1
			"cast":
				if src > 0:
					players[src]["casts"].append({"t": int(event["t"]), "ability": str(event["ability"])})
			"boss_cast":
				boss_casts += 1

	var names := {}
	var classes := {}
	var levels := {}
	var gear := {}
	var health := {}
	for peer_id in players:
		var character := _find_player(peer_id)
		names[peer_id] = _name_of(character, peer_id)
		classes[peer_id] = String(_class_of(character))
		levels[peer_id] = _level_of(character)
		gear[peer_id] = gear_score_of(character)
		health[peer_id] = _max_health_of(character)

	var recap := {
		"boss_id": boss_id,
		"boss_name": str(fight.get("boss_name", "")),
		"tier": int(fight.get("tier", 0)),
		"seconds": seconds,
		"wiped": wiped,
		"names": names,
		"classes": classes,
		"columns": {"damage": {}, "healing": {}, "taken": {}},
		"awards": {},
		"parses": {},
		"coach": {},
		"abilities": {},
		"new_records": [],
		"best_seconds": 0.0
	}
	for peer_id in players:
		recap["columns"]["damage"][peer_id] = players[peer_id]["damage"]
		recap["columns"]["healing"][peer_id] = players[peer_id]["healing"]
		recap["columns"]["taken"][peer_id] = players[peer_id]["taken"]
		recap["abilities"][peer_id] = _ranked_abilities(players[peer_id])

	recap["awards"] = _awards(players, names, first_blood, killing_blow)

	var total_boss_damage := 0
	for peer_id in players:
		total_boss_damage += int(players[peer_id]["boss_taken"])
	for peer_id in players:
		var class_id := StringName(str(classes[peer_id]))
		var parse := parse_for(players[peer_id], class_id, int(levels[peer_id]), int(gear[peer_id]), seconds, started, int(health[peer_id]), boss_casts, total_boss_damage)
		recap["parses"][peer_id] = parse
		recap["coach"][peer_id] = coach_for(players[peer_id], class_id, int(levels[peer_id]), seconds, started, parse)

	if not wiped and boss_id != "":
		_settle_records(recap, players.keys())
	return recap


func _tally(players: Dictionary, peer_id: int) -> void:
	if not players.has(peer_id):
		players[peer_id] = {
			"damage": 0, "healing": 0, "taken": 0, "boss_taken": 0,
			"interrupts": 0, "avoidable_hits": 0, "avoidable_amount": 0, "deaths": 0,
			"casts": [], "by_ability": {}
		}


func _ability_tally(player: Dictionary, ability: String, amount: int) -> void:
	if ability.is_empty():
		ability = "melee"
	var table: Dictionary = player["by_ability"]
	if not table.has(ability):
		table[ability] = {"total": 0, "hits": 0, "biggest": 0}
	table[ability]["total"] = int(table[ability]["total"]) + amount
	table[ability]["hits"] = int(table[ability]["hits"]) + 1
	table[ability]["biggest"] = maxi(int(table[ability]["biggest"]), amount)


func _ranked_abilities(player: Dictionary) -> Array:
	var rows := []
	var table: Dictionary = player["by_ability"]
	var cast_counts := {}
	for cast in player["casts"]:
		cast_counts[cast["ability"]] = int(cast_counts.get(cast["ability"], 0)) + 1
	for ability in table:
		var data := AbilityDatabase.get_ability(StringName(ability))
		rows.append({
			"id": ability,
			"name": data.display_name if data else ability.capitalize(),
			"total": int(table[ability]["total"]),
			"casts": int(cast_counts.get(ability, table[ability]["hits"])),
			"average": int(round(float(table[ability]["total"]) / float(maxi(1, int(table[ability]["hits"]))))),
			"biggest": int(table[ability]["biggest"])
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["total"]) > int(b["total"]))
	return rows


## One line each, chosen so every role can win something.
func _awards(players: Dictionary, names: Dictionary, first_blood: int, killing_blow: int) -> Dictionary:
	var awards := {}
	var most := func(column: String, title: String) -> void:
		var best_peer := 0
		var best := 0
		for peer_id in players:
			if int(players[peer_id][column]) > best:
				best = int(players[peer_id][column])
				best_peer = peer_id
		if best_peer > 0:
			awards[title] = {"peer": best_peer, "name": names[best_peer], "value": best}
	most.call("damage", "Most Damage")
	most.call("healing", "Most Healing")
	most.call("taken", "Most Damage Taken")
	most.call("interrupts", "Most Interrupts")
	var fewest_peer := 0
	var fewest := -1
	var never_died := []
	for peer_id in players:
		var hits := int(players[peer_id]["avoidable_hits"])
		if fewest < 0 or hits < fewest:
			fewest = hits
			fewest_peer = peer_id
		if int(players[peer_id]["deaths"]) == 0:
			never_died.append(names[peer_id])
	if fewest_peer > 0:
		awards["Fewest Avoidable Hits"] = {"peer": fewest_peer, "name": names[fewest_peer], "value": fewest}
	if not never_died.is_empty():
		awards["Never Died"] = {"peer": 0, "name": ", ".join(never_died), "value": never_died.size()}
	if first_blood > 0:
		awards["First Blood"] = {"peer": first_blood, "name": names[first_blood], "value": 1}
	if killing_blow > 0:
		awards["Killing Blow"] = {"peer": killing_blow, "name": names[killing_blow], "value": 1}
	return awards


# --- The parse -----------------------------------------------------------------


## Four components, 100 points, scored against what the fight allowed.
func parse_for(
	player: Dictionary, class_id: StringName, level: int, gear_score: int, seconds: float,
	started: int, own_max_health: int, boss_casts: int, total_boss_damage: int
) -> Dictionary:
	var uptime := uptime_share(player, seconds, started)
	var rotation := rotation_share(player, class_id, level, seconds, started)
	# Mechanics: avoidable damage, scaled by how much of YOUR bar it took;
	# interrupts landed vs available; a tank is judged on holding the boss.
	var avoid_share := clampf(float(player["avoidable_amount"]) / float(maxi(1, own_max_health)) * 1.5, 0.0, 1.0)
	var mechanics := 1.0 - avoid_share
	if class_id == &"valkyr":
		if total_boss_damage > 0:
			var held := clampf(float(player["boss_taken"]) / float(total_boss_damage), 0.0, 1.0)
			mechanics *= 0.5 + 0.5 * held
	elif boss_casts > 0:
		var landed := clampf(float(player["interrupts"]) / float(boss_casts), 0.0, 1.0)
		mechanics *= 0.6 + 0.4 * landed
	var healer := class_id == &"bard"
	var actual := (float(player["healing"]) if healer else float(player["damage"])) / seconds
	var baseline := baseline_for(class_id, gear_score, healer)
	var output := clampf(actual / maxf(0.01, baseline), 0.0, 1.0)
	var score := int(round(uptime * 30.0 + rotation * 25.0 + mechanics * 25.0 + output * 20.0))
	score = clampi(score, 0, 100)
	return {
		"score": score,
		"colour": colour_name(score),
		"uptime": int(round(uptime * 30.0)),
		"rotation": int(round(rotation * 25.0)),
		"mechanics": int(round(mechanics * 25.0)),
		"output": int(round(output * 20.0)),
		"per_second": snappedf(actual, 0.1),
		"baseline": snappedf(baseline, 0.1),
		"healer": healer
	}


## The item-level parse done natively: the baseline scales with the sum of
## the worn gear's budgets, so Levy and Sovereign are each scored against
## what THEIR gear should do.
func baseline_for(class_id: StringName, gear_score: int, healer: bool) -> float:
	var base: Dictionary = BASELINE.get(class_id, BASELINE[&"valkyr"])
	var raw := float(base["hps"] if healer else base["dps"])
	return raw * (1.0 + float(gear_score) / 120.0)


func uptime_share(player: Dictionary, seconds: float, started: int) -> float:
	var buckets := maxi(1, int(ceil(seconds / UPTIME_BUCKET_SECONDS)))
	var active := {}
	for cast in player["casts"]:
		var index := int(float(int(cast["t"]) - started) / 1000.0 / UPTIME_BUCKET_SECONDS)
		active[clampi(index, 0, buckets - 1)] = true
	return clampf(float(active.size()) / float(buckets), 0.0, 1.0)


## Key abilities used when available, and DoT/buff uptime, averaged.
func rotation_share(player: Dictionary, class_id: StringName, level: int, seconds: float, started: int) -> float:
	var usage := cooldown_usage(player, class_id, level, seconds)
	var uptimes := effect_uptimes(player, class_id, level, seconds, started)
	var parts: Array[float] = []
	if not usage.is_empty():
		var total := 0.0
		for row in usage:
			total += float(row["ratio"])
		parts.append(total / float(usage.size()))
	if not uptimes.is_empty():
		var total := 0.0
		for row in uptimes:
			total += float(row["uptime"])
		parts.append(total / float(uptimes.size()))
	if parts.is_empty():
		return 0.0
	var sum := 0.0
	for part in parts:
		sum += part
	return clampf(sum / float(parts.size()), 0.0, 1.0)


## "Overload was ready 7 times; you used it 3." for every cooldown you had.
func cooldown_usage(player: Dictionary, class_id: StringName, level: int, seconds: float) -> Array:
	var rows := []
	var cast_counts := {}
	for cast in player["casts"]:
		cast_counts[cast["ability"]] = int(cast_counts.get(cast["ability"], 0)) + 1
	for ability in AbilityDatabase.abilities_for_class(class_id):
		if ability.cooldown < 6.0 or level < ability.level_required:
			continue
		var ready := int(floor(seconds / ability.cooldown)) + 1
		var used := int(cast_counts.get(String(ability.id), 0))
		rows.append({"id": String(ability.id), "name": ability.display_name, "ready": ready, "used": used, "ratio": clampf(float(used) / float(ready), 0.0, 1.0)})
	return rows


## Share of the fight each damage-over-time, heal-over-time or buff was up,
## and how many times it fell off.
func effect_uptimes(player: Dictionary, class_id: StringName, level: int, seconds: float, started: int) -> Array:
	var rows := []
	var ended := started + int(seconds * 1000.0)
	for ability in AbilityDatabase.abilities_for_class(class_id):
		if level < ability.level_required:
			continue
		var timed: bool = ability.effect in [AbilityData.Effect.DOT, AbilityData.Effect.HOT, AbilityData.Effect.STACK, AbilityData.Effect.BUFF]
		if not timed or ability.duration_seconds <= 0.0:
			continue
		var covered := 0
		var cursor := started
		var fell_off := 0
		var applied := false
		for cast in player["casts"]:
			if str(cast["ability"]) != String(ability.id):
				continue
			var at := int(cast["t"])
			if applied and at > cursor:
				fell_off += 1
			var until := mini(ended, at + int(ability.duration_seconds * 1000.0))
			covered += maxi(0, until - maxi(at, cursor))
			cursor = maxi(cursor, until)
			applied = true
		if applied and cursor < ended:
			fell_off += 1
		rows.append({"id": String(ability.id), "name": ability.display_name, "uptime": clampf(float(covered) / float(maxi(1, ended - started)), 0.0, 1.0), "fell_off": fell_off, "used": applied})
	return rows


## Three sentences the game writes for you about what to change.
func coach_for(player: Dictionary, class_id: StringName, level: int, seconds: float, started: int, parse: Dictionary) -> Array:
	var lines := []
	var idle := 1.0 - uptime_share(player, seconds, started)
	if idle >= 0.1:
		lines.append("You spent %d%% of that fight with nothing on cooldown." % int(round(idle * 100.0)))
	else:
		lines.append("You barely stopped casting: %d%% idle. Keep that." % int(round(idle * 100.0)))
	var uptimes := effect_uptimes(player, class_id, level, seconds, started)
	if uptimes.is_empty():
		lines.append("Nothing you have ticks over time yet, so uptime is all about pressing keys.")
	else:
		var worst: Dictionary = uptimes[0]
		for row in uptimes:
			if float(row["uptime"]) < float(worst["uptime"]):
				worst = row
		if not bool(worst["used"]):
			lines.append("You never used %s." % worst["name"])
		elif int(worst["fell_off"]) > 0:
			lines.append("%s fell off %d time%s." % [worst["name"], int(worst["fell_off"]), "" if int(worst["fell_off"]) == 1 else "s"])
		else:
			lines.append("%s stayed up the whole fight." % worst["name"])
	var usage := cooldown_usage(player, class_id, level, seconds)
	var laziest := {}
	for row in usage:
		var missed := int(row["ready"]) - int(row["used"])
		if laziest.is_empty() or missed > int(laziest["ready"]) - int(laziest["used"]):
			laziest = row
	if laziest.is_empty():
		lines.append("No long cooldowns at your level yet.")
	elif int(laziest["ready"]) - int(laziest["used"]) > 0:
		lines.append("%s was ready %d time%s; you used it %d." % [laziest["name"], int(laziest["ready"]), "" if int(laziest["ready"]) == 1 else "s", int(laziest["used"])])
	else:
		lines.append("Every cooldown you had, you used.")
	return lines


func colour_name(score: int) -> String:
	if score >= 100:
		return "gold"
	for row in PARSE_COLOURS:
		if score >= int(row[0]):
			return str(row[1])
	return "grey"


func colour_for(score: int) -> Color:
	if score >= 100:
		return Color(1.0, 0.84, 0.0)
	for row in PARSE_COLOURS:
		if score >= int(row[0]):
			return row[2]
	return Color(0.4, 0.4, 0.4)


# --- Records -----------------------------------------------------------------


## Personal bests go to each present player's RecordBook; the group's record
## lives in the host's, since the host is who the group has in common.
func _settle_records(recap: Dictionary, peers: Array) -> void:
	var boss_id := StringName(str(recap["boss_id"]))
	var seconds := float(recap["seconds"])
	var host := _find_player(1)
	var host_book := host.get_node_or_null("RecordBook") as RecordBook if host else null
	if host_book:
		recap["best_seconds"] = host_book.record_seconds(boss_id)
	for peer_id in peers:
		var character := _find_player(peer_id)
		var book := character.get_node_or_null("RecordBook") as RecordBook if character else null
		if book == null:
			continue
		var parse: Dictionary = recap["parses"].get(peer_id, {})
		for line in book.note_best(boss_id, str(recap["boss_name"]), seconds, int(parse.get("score", 0))):
			recap["new_records"].append("%s: %s" % [recap["names"][peer_id], line])
	if host_book:
		var fastest_name := ""
		for peer_id in peers:
			if fastest_name.is_empty():
				fastest_name = str(recap["names"][peer_id])
			else:
				fastest_name += ", " + str(recap["names"][peer_id])
		var line := host_book.note_record(boss_id, str(recap["boss_name"]), seconds, fastest_name)
		if not line.is_empty():
			recap["new_records"].append(line)
		if float(recap["best_seconds"]) <= 0.0:
			recap["best_seconds"] = seconds


# --- Lookups -------------------------------------------------------------------


func _find_player(peer_id: int) -> Node:
	for container in get_tree().get_nodes_in_group("Players"):
		var node := container.get_node_or_null(str(peer_id))
		if node:
			return node
	return null


func _name_of(character: Node, peer_id: int) -> String:
	if character:
		var nickname := character.get_node_or_null("PlayerNick/Nickname") as Label3D
		if nickname and not nickname.text.is_empty():
			return nickname.text
	return "Player %d" % peer_id


func _class_of(character: Node) -> StringName:
	if character == null:
		return &"valkyr"
	var stats := character.get_node_or_null("Stats") as Stats
	if stats and stats.class_data:
		return stats.class_data.id
	if character.get("class_id") != null:
		return character.class_id
	return &"valkyr"


func _level_of(character: Node) -> int:
	if character == null:
		return 1
	var stats := character.get_node_or_null("Stats") as Stats
	return stats.level if stats else 1


func _max_health_of(character: Node) -> int:
	if character == null:
		return 100
	var stats := character.get_node_or_null("Stats") as Stats
	return maxi(1, stats.max_health) if stats else 100


## The sum of the worn gear's budgets: one number for a whole character.
func gear_score_of(character: Node) -> int:
	if character == null or not character.has_method("get_inventory"):
		return 0
	var inventory = character.get_inventory()
	if inventory == null:
		return 0
	var total := 0
	for key in inventory.gear:
		var slot = inventory.gear[key]
		if slot == null or slot.is_empty():
			continue
		var item: Item = ItemDatabase.get_item(slot.item_id)
		if item and item.is_gear():
			total += int(GearDatabase.TIER_BUDGET.get(item.gear_tier, 0))
	return total


static func format_seconds(seconds: float) -> String:
	var whole := int(round(seconds))
	return "%d:%02d" % [whole / 60, whole % 60]
