# GrudgeLedger — how many times you have beaten each boss, which is how hard
# it fights you next time.
#
# docs/ironveil-qol-spec.md section 7. Every boss's mechanics are an ordered
# list; grudge tier N turns on the first 2+N. Each kill raises the tier by one
# for everyone present, up to 5 for dungeon bosses and 3 for raid bosses. The
# group fights at the LOWEST member's tier, so a new friend is never dragged
# into a fight nobody explained to them.
#
# Server-owned, like every other number that matters, and pushed to the owner
# so their character sheet can show it. Saved with the character.
class_name GrudgeLedger
extends Node

signal grudge_changed(boss_id: StringName, tier: int)

const DUNGEON_CAP := 5
const RAID_CAP := 3
## How many mechanics a boss fights with before any grudge.
const BASE_MECHANICS := 2

## boss id (String) -> tier
var tiers: Dictionary = {}


func tier_for(boss_id: StringName) -> int:
	return int(tiers.get(String(boss_id), 0))


static func cap_for(data: MobData) -> int:
	if data == null:
		return DUNGEON_CAP
	return RAID_CAP if data.tags.has(&"raid") else DUNGEON_CAP


## How many of a boss's mechanics a given tier turns on.
static func mechanics_enabled(tier: int) -> int:
	return BASE_MECHANICS + maxi(0, tier)


## Server. One more kill of this boss.
func raise(boss_id: StringName, cap: int) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var key := String(boss_id)
	var next := mini(cap, int(tiers.get(key, 0)) + 1)
	if next == int(tiers.get(key, 0)):
		return
	tiers[key] = next
	grudge_changed.emit(boss_id, next)
	_push()


func _push() -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var owner_id := get_parent().get_multiplayer_authority()
	if owner_id != 1:
		sync_tiers.rpc_id(owner_id, tiers)


@rpc("authority", "reliable")
func sync_tiers(data: Dictionary) -> void:
	tiers = data.duplicate()
	for key in tiers:
		grudge_changed.emit(StringName(key), int(tiers[key]))


func to_dict() -> Dictionary:
	var out := {}
	for key in tiers:
		out[str(key)] = int(tiers[key])
	return out


func from_dict(data: Dictionary) -> void:
	tiers.clear()
	for key in data:
		var tier := clampi(int(data[key]), 0, DUNGEON_CAP)
		if tier > 0:
			tiers[str(key)] = tier
	_push()


## ⟨IV⟩ on a name label.
static func roman(value: int) -> String:
	match clampi(value, 0, 5):
		1: return "I"
		2: return "II"
		3: return "III"
		4: return "IV"
		5: return "V"
	return ""
