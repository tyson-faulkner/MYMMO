# SeasonDatabase — what changes every six to eight weeks, and what never does.
#
# docs/ironveil-qol-spec.md section 9. The level cap and the gear tiers are
# forever; nobody's gear becomes junk. A season swaps each boss's mechanic list
# and skin, and hands out cosmetics, mounts and titles. Never power.
#
# It is the grudge engine wearing a different hat: grudge turns mechanics on
# WITHIN a list, a season swaps the WHOLE list. BossMechanics asks here for a
# boss's list, Mob asks here for its skin, and this file is otherwise content.
extends Node

## Fixed at the start of each season, in order. `starts` is the first day,
## `weeks` how long it runs; the next season begins the day this one ends. If
## the list runs out, the last season simply continues.
const SEASONS := [
	{
		"id": &"unburied",
		"name": "The Unburied King",
		"starts": "2026-09-13",
		"weeks": 8,
		# Season one is the base game: nothing overridden.
		"mechanics": {},
		"models": {},
		"rewards": {"title": "Mournbound", "cosmetic": "banner_gold", "mount": &"mount_ironhide"}
	},
	{
		"id": &"drowned_court",
		"name": "The Drowned Court",
		"starts": "2026-11-08",
		"weeks": 7,
		# The Greymarch flood reaches the capital: the Archive and the Broken Throne fight
		# with the Hold's tricks, and their masters wear the drowned.
		"mechanics": {
			&"master_kell": [
				{"name": "Undertow", "every": 8.0, "first": 5.0, "effect": "pool", "target": "random", "range": 40.0, "radius": 3.0, "slow": 0.5, "power": 18, "tick": 1.0, "persist": false, "seconds": 12.0, "avoidable": true},
				{"name": "Drowned Page", "every": 12.0, "first": 6.0, "cast": 2.0, "effect": "damage", "power": 140, "target": "random", "range": 30.0, "avoidable": true},
				{"name": "Call the Flood", "at": [70, 35], "effect": "spawn", "spawn": [{"id": "drowned_levy", "count": 3}]},
				{"name": "Bind", "every": 20.0, "first": 9.0, "effect": "slow", "target": "tank", "slow": 0.05, "duration": 4.0},
				{"name": "Drag Down", "every": 22.0, "first": 14.0, "cast": 1.5, "effect": "stun", "target": "random", "range": 30.0, "duration": 2.5, "power": 40},
				{"name": "Second Reading", "every": 40.0, "first": 30.0, "cast": 2.5, "effect": "heal", "target": "self", "power": 200},
				{"name": "Close the Book", "at": [20], "every": 6.0, "effect": "stat", "damage_bonus": 0.10}
			],
			&"the_bound_ledger": [
				{"name": "Flood Line", "every": 14.0, "first": 8.0, "cast": 1.2, "effect": "line", "target": "tank", "width": 4.0, "length": 40.0, "power": 90, "interruptible": false, "avoidable": true},
				{"name": "Ink Pool", "every": 8.0, "first": 5.0, "effect": "pool", "target": "random", "range": 40.0, "radius": 3.0, "slow": 0.5, "power": 20, "tick": 1.0, "persist": true, "avoidable": true},
				{"name": "Turn the Page", "every": 30.0, "first": 30.0, "cast": 1.5, "effect": "pools_fire", "power": 60, "range": 60.0, "target": "self", "interruptible": false},
				{"name": "The Flood Rises", "at": [50, 25], "effect": "spawn", "spawn": [{"id": "drowned_levy", "count": 3}]},
				{"name": "Blot", "every": 20.0, "first": 12.0, "cast": 1.0, "effect": "slow", "target": "random", "range": 40.0, "slow": 0.3, "duration": 4.0},
				{"name": "Paper Cut", "every": 9.0, "first": 4.0, "effect": "damage", "target": "tank", "power": 90},
				{"name": "Final Entry", "at": [10], "every": 5.0, "effect": "stat", "damage_bonus": 0.15}
			],
			&"first_king_crowned": [
				{"name": "The Crown", "every": 25.0, "first": 15.0, "effect": "named", "target": "random", "range": 60.0, "duration": 8.0, "heal_share": 0.5, "dais": "throne_dais"},
				{"name": "Drowned Heralds", "at": [75, 50, 25], "effect": "spawn", "spawn": [{"id": "flood_warden", "count": 2}], "alive_bonus": 0.10},
				{"name": "Undertow", "every": 10.0, "first": 6.0, "effect": "pool", "target": "random", "range": 60.0, "radius": 3.5, "slow": 0.5, "power": 24, "tick": 1.0, "persist": false, "seconds": 15.0, "avoidable": true},
				{"name": "Grave Wind", "every": 18.0, "first": 12.0, "cast": 1.5, "effect": "line", "target": "tank", "width": 3.0, "length": 50.0, "power": 100, "interruptible": false, "avoidable": true},
				{"name": "The King's Mourning", "at": [15], "every": 5.0, "effect": "stat", "damage_bonus": 0.10}
			]
		},
		"models": {
			&"master_kell": "enemy_barrow_wight",
			&"the_bound_ledger": "",
			&"first_king_crowned": "enemy_barrow_guardian"
		},
		"rewards": {"title": "Of the Drowned Court", "cosmetic": "weapon_glow_flood", "mount": &"mount_risen_brute"}
	}
]

## Tests pin a season by index; -1 means "whatever the calendar says".
var forced_index: int = -1


func current_index() -> int:
	if forced_index >= 0 and forced_index < SEASONS.size():
		return forced_index
	var now := Time.get_unix_time_from_system()
	var index := 0
	for i in range(SEASONS.size()):
		if now >= _start_unix(SEASONS[i]):
			index = i
	return index


func current() -> Dictionary:
	return SEASONS[current_index()]


func current_id() -> StringName:
	return StringName(str(current().get("id", "")))


func season_name() -> String:
	return str(current().get("name", ""))


## Days until the season turns over; 0 if this is the last one on the list.
func days_left() -> int:
	var index := current_index()
	if index + 1 >= SEASONS.size():
		return 0
	var ends := _start_unix(SEASONS[index + 1])
	return maxi(0, int(ceil((ends - Time.get_unix_time_from_system()) / 86400.0)))


## The mechanic list a boss fights with this season, in grudge order.
func mechanics_for(boss_id: StringName, base: Array) -> Array:
	var overrides: Dictionary = current().get("mechanics", {})
	if overrides.has(boss_id):
		return overrides[boss_id]
	return base


## The model a boss wears this season, or its usual one.
func model_for(boss_id: StringName, base_path: String) -> String:
	var overrides: Dictionary = current().get("models", {})
	if overrides.has(boss_id):
		var model := str(overrides[boss_id])
		return "res://assets/enemies/%s.glb" % model if not model.is_empty() else ""
	return base_path


func rewards() -> Dictionary:
	return current().get("rewards", {})


## The one line the chronicle gets when a season turns over.
func turnover_line() -> String:
	return "A new season begins: %s. Its title is \"%s\"." % [season_name(), str(rewards().get("title", ""))]


func _start_unix(season: Dictionary) -> float:
	var parts := str(season.get("starts", "2026-01-01")).split("-")
	if parts.size() != 3:
		return 0.0
	return Time.get_unix_time_from_datetime_dict({
		"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]),
		"hour": 0, "minute": 0, "second": 0
	})
