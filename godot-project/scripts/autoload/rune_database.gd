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
		"name": "Spearcast",
		"class": &"valkyr",
		"slot": 1,
		"ability": &"valkyr_spearcast",
		"effect": "grant",
		"value": 1.0,
		"text": "A new move: throw the spear for heavy damage at range, once every thirty seconds."
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
		"name": "Rally the Fallen",
		"class": &"valkyr",
		"slot": 2,
		"ability": &"valkyr_rally",
		"effect": "grant",
		"value": 1.0,
		"text": "A new move: a party heal on a long cooldown. Either spec can carry it for a healer-less night."
	},
	&"valkyr_3a":
	{
		"name": "Wingbeat",
		"class": &"valkyr",
		"slot": 3,
		"ability": &"valkyr_wingbeat",
		"effect": "grant",
		"value": 1.0,
		"text": "A new move: a short dash that breaks snares. For a mechanic-heavy boss."
	},
	&"valkyr_3b":
	{
		"name": "Feathered Rampart",
		"class": &"valkyr",
		"slot": 3,
		"ability": &"valkyr_guard",
		"effect": "make_aoe",
		"value": 11.0,
		"falloff": 0.6,
		"text": "Wingguard shelters everyone standing near you, for less each. For a stand-and-hold fight."
	},
	# --- Bard ---
	&"bard_1a":
	{
		"name": "Discord",
		"class": &"bard",
		"slot": 1,
		"ability": &"bard_discord",
		"effect": "grant",
		"value": 1.0,
		"text": "A new move: one loud, wrong chord for heavy damage, every thirty seconds."
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
		"name": "Ballad of the Long Barrow",
		"class": &"bard",
		"slot": 2,
		"ability": &"bard_ballad",
		"effect": "grant",
		"value": 1.0,
		"text": "A new move: the big burst heal, so either spec can carry one emergency heal."
	},
	&"bard_3a":
	{
		"name": "Skip Step",
		"class": &"bard",
		"slot": 3,
		"ability": &"bard_skip",
		"effect": "grant",
		"value": 1.0,
		"text": "A new move: a short dash that breaks snares."
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
		"name": "Graveshot",
		"class": &"necromancer",
		"slot": 1,
		"ability": &"necro_graveshot",
		"effect": "grant",
		"value": 1.0,
		"text": "A new move: a long-cooldown nuke. For a boss."
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
		"name": "Bracing Draught",
		"class": &"necromancer",
		"slot": 2,
		"ability": &"necro_brace",
		"effect": "grant",
		"value": 1.0,
		"text": "A new move: a self-heal on a cooldown. For standing where you should not."
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
		"name": "Bone Step",
		"class": &"necromancer",
		"slot": 3,
		"ability": &"necro_bonestep",
		"effect": "grant",
		"value": 1.0,
		"text": "A new move: a short dash that breaks snares."
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
		"name": "Mortar",
		"class": &"tinker",
		"slot": 1,
		"ability": &"tinker_mortar",
		"effect": "grant",
		"value": 1.0,
		"text": "A new move: a long-cooldown blast on a crowd."
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
		"name": "Field Tonic",
		"class": &"tinker",
		"slot": 2,
		"ability": &"tinker_field_tonic",
		"effect": "grant",
		"value": 1.0,
		"text": "A new move: a self-heal on a cooldown."
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
		"name": "Grapnel",
		"class": &"tinker",
		"slot": 3,
		"ability": &"tinker_grapnel",
		"effect": "grant",
		"value": 1.0,
		"text": "A new move: a short dash that breaks snares."
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
	"splash_heal": RuneData.Effect.SPLASH_HEAL,
	"grant": RuneData.Effect.GRANT
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
