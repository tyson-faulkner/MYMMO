# RuneDatabase — the three armour slots for each class, two runes apiece.
#
# Eight builds per class, from 24 entries and no new art: every rune changes an
# ability that already exists. See RuneData for the two rules these follow —
# the short version is that the two options in a slot differ by SITUATION, never
# by how big the number is.
#
# Read each pair as a question. Slot 1 for most classes is "do you want to hit
# one thing harder, or several things at once?" — and the honest answer depends
# on whether you are in a dungeon or a field.
extends Node

const DEFINITIONS := {
	# --- Valkyr ---
	&"valkyr_1a":
	{
		"name": "Widow's Edge",
		"class": &"valkyr",
		"slot": 1,
		"ability": &"valkyr_strike",
		"effect": "power",
		"value": 1.7,
		"text": "Mourning Strike lands far harder, on one target. For holding a boss."
	},
	&"valkyr_1b":
	{
		"name": "Sweeping Grief",
		"class": &"valkyr",
		"slot": 1,
		"ability": &"valkyr_strike",
		"effect": "make_aoe",
		"value": 4.0,
		"falloff": 0.55,
		"text": "Mourning Strike catches everything in reach for a share. For holding a pack."
	},
	&"valkyr_2a":
	{
		"name": "Iron Claim",
		"class": &"valkyr",
		"slot": 2,
		"ability": &"valkyr_taunt",
		"effect": "duration",
		"value": 2.5,
		"text": "Your claim holds far longer. One enemy stays yours through anything."
	},
	&"valkyr_2b":
	{
		"name": "Bannerfall",
		"class": &"valkyr",
		"slot": 2,
		"ability": &"valkyr_taunt",
		"effect": "make_aoe",
		"value": 9.0,
		"falloff": 0.8,
		"text": "You claim everything nearby at once, but not for as long. For picking up a wipe."
	},
	&"valkyr_3a":
	{
		"name": "Unbroken",
		"class": &"valkyr",
		"slot": 3,
		"ability": &"valkyr_guard",
		"effect": "power",
		"value": 1.8,
		"text": "Wingguard buys back far more of your own health."
	},
	&"valkyr_3b":
	{
		"name": "Feathered Rampart",
		"class": &"valkyr",
		"slot": 3,
		"ability": &"valkyr_guard",
		"effect": "splash_heal",
		"value": 11.0,
		"falloff": 0.6,
		"text": "Wingguard reaches everyone standing behind you, for less each."
	},
	# --- Bard ---
	&"bard_1a":
	{
		"name": "Perfect Pitch",
		"class": &"bard",
		"slot": 1,
		"ability": &"bard_mend",
		"effect": "power",
		"value": 1.65,
		"text": "Mending Verse heals one person for much more. For keeping a tank upright."
	},
	&"bard_1b":
	{
		"name": "Round Song",
		"class": &"bard",
		"slot": 1,
		"ability": &"bard_mend",
		"effect": "splash_heal",
		"value": 10.0,
		"falloff": 0.55,
		"text": "Mending Verse carries to whoever is standing near them. For a group taking chip damage."
	},
	&"bard_2a":
	{
		"name": "Long Dirge",
		"class": &"bard",
		"slot": 2,
		"ability": &"bard_dirge",
		"effect": "duration",
		"value": 2.2,
		"text": "The Dirge runs much longer on one target. For fights that last."
	},
	&"bard_2b":
	{
		"name": "Chorus of Sorrow",
		"class": &"bard",
		"slot": 2,
		"ability": &"bard_dirge",
		"effect": "make_aoe",
		"value": 7.0,
		"falloff": 0.6,
		"text": "The Dirge settles over everything near your target, for a shorter while."
	},
	&"bard_3a":
	{
		"name": "Sharp Note",
		"class": &"bard",
		"slot": 3,
		"ability": &"bard_chord",
		"effect": "power",
		"value": 2.1,
		"text": "Cutting Chord hits properly hard, but you'll wait for it."
	},
	&"bard_3b":
	{
		"name": "Quickstep",
		"class": &"bard",
		"slot": 3,
		"ability": &"bard_chord",
		"effect": "cost",
		"value": 0.4,
		"text": "Cutting Chord costs almost no Verse. Play it constantly while you heal."
	},
	# --- Necromancer ---
	&"necro_1a":
	{
		"name": "Marrowseeker",
		"class": &"necromancer",
		"slot": 1,
		"ability": &"necro_bolt",
		"effect": "power",
		"value": 1.75,
		"text": "Soulbolt bites much deeper into one target."
	},
	&"necro_1b":
	{
		"name": "Forked Bolt",
		"class": &"necromancer",
		"slot": 1,
		"ability": &"necro_bolt",
		"effect": "extra_targets",
		"value": 2.0,
		"falloff": 0.5,
		"text": "Soulbolt forks to two more enemies for half. The classic, and still the right answer in a pack."
	},
	&"necro_2a":
	{
		"name": "Honoured Dead",
		"class": &"necromancer",
		"slot": 2,
		"ability": &"necro_raise",
		"effect": "duration",
		"value": 2.0,
		"text": "One levy, standing far longer. Somebody worth raising properly."
	},
	&"necro_2b":
	{
		"name": "Grave Tide",
		"class": &"necromancer",
		"slot": 2,
		"ability": &"necro_raise",
		"effect": "extra_summon",
		"value": 2.0,
		"falloff": 0.6,
		"text": "Three of them at once, none of them impressive. Quantity has a quality."
	},
	&"necro_3a":
	{
		"name": "Deep Rot",
		"class": &"necromancer",
		"slot": 3,
		"ability": &"necro_rot",
		"effect": "duration",
		"value": 2.0,
		"text": "Creeping Rot works on one body for twice as long."
	},
	&"necro_3b":
	{
		"name": "Spreading Rot",
		"class": &"necromancer",
		"slot": 3,
		"ability": &"necro_rot",
		"effect": "make_aoe",
		"value": 6.5,
		"falloff": 0.7,
		"text": "Creeping Rot takes hold of everything around your target."
	},
	# --- Tinker ---
	&"tinker_1a":
	{
		"name": "Heavy Bolt",
		"class": &"tinker",
		"slot": 1,
		"ability": &"tinker_shot",
		"effect": "power",
		"value": 1.8,
		"text": "One bolt, considerably more of it."
	},
	&"tinker_1b":
	{
		"name": "Repeater",
		"class": &"tinker",
		"slot": 1,
		"ability": &"tinker_shot",
		"effect": "cost",
		"value": 0.35,
		"text": "Bolt Thrower costs almost no Charge. Keep cranking."
	},
	&"tinker_2a":
	{
		"name": "Siege Frame",
		"class": &"tinker",
		"slot": 2,
		"ability": &"tinker_turret",
		"effect": "duration",
		"value": 2.0,
		"text": "One turret, bolted down properly, lasting twice as long."
	},
	&"tinker_2b":
	{
		"name": "Twin Mount",
		"class": &"tinker",
		"slot": 2,
		"ability": &"tinker_turret",
		"effect": "extra_summon",
		"value": 1.0,
		"falloff": 0.65,
		"text": "Two lighter turrets covering two angles."
	},
	&"tinker_3a":
	{
		"name": "Shaped Charge",
		"class": &"tinker",
		"slot": 3,
		"ability": &"tinker_bomb",
		"effect": "focus",
		"value": 2.3,
		"text": "The charge drives into one target instead of spreading. For a boss."
	},
	&"tinker_3b":
	{
		"name": "Scattershot",
		"class": &"tinker",
		"slot": 3,
		"ability": &"tinker_bomb",
		"effect": "power",
		"value": 0.75,
		"aoe_bonus": 5.0,
		"text": "A much wider blast for less each. For a crowd."
	}
}

const EFFECT_NAMES := {
	"power": RuneData.Effect.POWER,
	"cooldown": RuneData.Effect.COOLDOWN,
	"cost": RuneData.Effect.COST,
	"duration": RuneData.Effect.DURATION,
	"extra_targets": RuneData.Effect.EXTRA_TARGETS,
	"make_aoe": RuneData.Effect.MAKE_AOE,
	"focus": RuneData.Effect.FOCUS,
	"extra_summon": RuneData.Effect.EXTRA_SUMMON,
	"splash_heal": RuneData.Effect.SPLASH_HEAL
}

var _cache: Dictionary = {}


func _ready() -> void:
	for rune_id in DEFINITIONS:
		_cache[rune_id] = _build(rune_id, DEFINITIONS[rune_id])


func get_rune(rune_id: StringName) -> RuneData:
	if _cache.is_empty():
		_ready()
	return _cache.get(rune_id, null)


func get_all_ids() -> Array:
	return DEFINITIONS.keys()


## The two runes offered in one slot, for one class.
func options_for(class_id: StringName, slot: int) -> Array:
	var found: Array = []
	for rune_id in DEFINITIONS:
		var rune := get_rune(rune_id)
		if rune.class_id == class_id and rune.slot == slot:
			found.append(rune)
	return found


## Slots unlock with the armour they sit on, which in practice means levelling.
static func level_for_slot(slot: int) -> int:
	match slot:
		1:
			return 5
		2:
			return 11
		_:
			return 17


func _build(rune_id: StringName, entry: Dictionary) -> RuneData:
	var rune := RuneData.new()
	rune.id = rune_id
	rune.display_name = str(entry.get("name", ""))
	rune.class_id = StringName(str(entry.get("class", &"")))
	rune.slot = int(entry.get("slot", 1))
	rune.ability_id = StringName(str(entry.get("ability", &"")))
	rune.effect = EFFECT_NAMES.get(str(entry.get("effect", "power")), RuneData.Effect.POWER)
	rune.value = float(entry.get("value", 1.0))
	rune.falloff = float(entry.get("falloff", 0.5))
	rune.aoe_bonus = float(entry.get("aoe_bonus", 0.0))
	rune.description = str(entry.get("text", ""))
	return rune
