# AbilityDatabase — seven abilities for each of the four classes.
#
# Per the design doc: seven unique abilities per class, plus three armour slots
# that each grant a choice between two options, which is where the eight builds
# per class come from. Those rune slots are M8 work; these seven are the spine
# they hang off.
#
# Levels are spread so a class gains something roughly every other level on the
# way to 20, with ranks (same ability, bigger numbers) filling the gaps later.
extends Node

const DEFINITIONS := {
	# --- Valkyr: tank. Valor BUILDS by fighting, so her openers cost nothing
	# and her finishers spend the lot.
	&"valkyr_strike":
	{
		"name": "Mourning Strike",
		"class": &"valkyr",
		"slot": 1,
		"effect": "damage",
		"power": 18,
		"cost": -12,
		"cooldown": 0.0,
		"range": 4.0,
		"level": 1,
		"text": "A measured spear thrust. Builds Valor rather than spending it."
	},
	&"valkyr_taunt":
	{
		"name": "Claim the Slain",
		"class": &"valkyr",
		"slot": 2,
		"effect": "taunt",
		"power": 6,
		"cost": 0,
		"cooldown": 8.0,
		"range": 18.0,
		"level": 2,
		"text": "You have claim over this one. It will answer to you and nobody else."
	},
	&"valkyr_cleave":
	{
		"name": "Sweeping Spear",
		"class": &"valkyr",
		"slot": 3,
		"effect": "aoe_damage",
		"power": 14,
		"cost": 20,
		"cooldown": 6.0,
		"range": 5.0,
		"aoe": 5.5,
		"level": 4,
		"text": "One long arc. Everything standing close enough gets a share."
	},
	&"valkyr_guard":
	{
		"name": "Wingguard",
		"class": &"valkyr",
		"slot": 4,
		"effect": "heal",
		"target": "self",
		"power": 55,
		"cost": 30,
		"cooldown": 20.0,
		"level": 6,
		"text": "Wings folded across the body. Spends Valor to buy back health."
	},
	&"valkyr_descend":
	{
		"name": "Descend",
		"class": &"valkyr",
		"slot": 5,
		"effect": "damage",
		"power": 34,
		"cost": 15,
		"cooldown": 12.0,
		"range": 22.0,
		"level": 8,
		"text": "Drop onto something from above, hard, from most of a field away."
	},
	&"valkyr_rally":
	{
		"name": "Rally the Fallen",
		"class": &"valkyr",
		"slot": 6,
		"effect": "aoe_heal",
		"target": "ground",
		"power": 30,
		"cost": 40,
		"cooldown": 45.0,
		"aoe": 12.0,
		"level": 12,
		"text": "Nobody else falls here today. Everyone nearby takes heart."
	},
	&"valkyr_judgment":
	{
		"name": "Judgment of the Slain",
		"class": &"valkyr",
		"slot": 7,
		"effect": "damage",
		"power": 30,
		"cost": 0,
		"spends_all": true,
		"cooldown": 18.0,
		"range": 4.5,
		"level": 16,
		"text": "Spends every point of Valor at once. The more of the fight you have taken, the harder it lands."
	},
	# --- Bard: healer and support. Verse drains and regenerates.
	&"bard_mend":
	{
		"name": "Mending Verse",
		"class": &"bard",
		"slot": 1,
		"effect": "heal",
		"target": "ally",
		"power": 32,
		"cost": 14,
		"cooldown": 0.0,
		"range": 24.0,
		"level": 1,
		"text": "Eight bars, and the bleeding slows. Nobody has ever explained why it works."
	},
	&"bard_chord":
	{
		"name": "Cutting Chord",
		"class": &"bard",
		"slot": 2,
		"effect": "damage",
		"power": 16,
		"cost": 8,
		"cooldown": 0.0,
		"range": 22.0,
		"level": 1,
		"text": "A note struck wrong on purpose."
	},
	&"bard_dirge":
	{
		"name": "Dirge",
		"class": &"bard",
		"slot": 3,
		"effect": "dot",
		"power": 9,
		"cost": 16,
		"cooldown": 4.0,
		"range": 24.0,
		"duration": 8.0,
		"level": 3,
		"text": "A funeral song, started early. It keeps going after you stop singing."
	},
	&"bard_march":
	{
		"name": "Marching Air",
		"class": &"bard",
		"slot": 4,
		"effect": "speed",
		"target": "ally",
		"speed": 1.35,
		"power": 0,
		"cost": 18,
		"cooldown": 18.0,
		"range": 24.0,
		"duration": 10.0,
		"level": 5,
		"text": "An old road song. Feet follow it whether their owner agrees or not."
	},
	&"bard_anthem":
	{
		"name": "Anthem of the Vale",
		"class": &"bard",
		"slot": 5,
		"effect": "aoe_heal",
		"target": "ground",
		"power": 26,
		"cost": 35,
		"cooldown": 15.0,
		"aoe": 14.0,
		"level": 8,
		"text": "Everyone who can hear it stands a little straighter."
	},
	&"bard_silence":
	{
		"name": "Broken Verse",
		"class": &"bard",
		"slot": 6,
		"effect": "interrupt",
		"power": 22,
		"cost": 20,
		"cooldown": 12.0,
		"range": 22.0,
		"level": 11,
		"text": "Deliberately wrong. Whatever was being said or sung stops mid-line."
	},
	&"bard_ballad":
	{
		"name": "Ballad of the Long Barrow",
		"class": &"bard",
		"slot": 7,
		"effect": "heal",
		"target": "ally",
		"power": 130,
		"cost": 55,
		"cooldown": 40.0,
		"range": 26.0,
		"level": 15,
		"text": "The full history of everyone buried up the valley. It takes a while, and it is worth it."
	},
	# --- Necromancer: ranged damage with a pet.
	&"necro_bolt":
	{
		"name": "Soulbolt",
		"class": &"necromancer",
		"slot": 1,
		"effect": "damage",
		"power": 20,
		"cost": 10,
		"cooldown": 0.0,
		"range": 26.0,
		"level": 1,
		"text": "The standard of the craft. Cheap, rude, effective."
	},
	&"necro_rot":
	{
		"name": "Creeping Rot",
		"class": &"necromancer",
		"slot": 2,
		"effect": "dot",
		"power": 11,
		"cost": 16,
		"cooldown": 3.0,
		"range": 26.0,
		"duration": 9.0,
		"level": 2,
		"text": "Starts small. Does not stop."
	},
	&"necro_drain":
	{
		"name": "Grave Draught",
		"class": &"necromancer",
		"slot": 3,
		"effect": "drain",
		"power": 22,
		"drain": 0.6,
		"cost": 18,
		"cooldown": 6.0,
		"range": 22.0,
		"level": 4,
		"text": "What it takes out of them goes somewhere. That somewhere is you."
	},
	&"necro_raise":
	{
		"name": "Raise Levy",
		"class": &"necromancer",
		"slot": 4,
		"effect": "summon",
		"target": "ground",
		"summon": &"risen_levy",
		"summon_seconds": 45.0,
		"cost": 30,
		"cooldown": 30.0,
		"level": 6,
		"text": "He was a farmer, then a soldier, then dead. Now he is busy again."
	},
	&"necro_burst":
	{
		"name": "Corpse Burst",
		"class": &"necromancer",
		"slot": 5,
		"effect": "aoe_damage",
		"power": 26,
		"cost": 28,
		"cooldown": 10.0,
		"range": 24.0,
		"aoe": 7.0,
		"level": 9,
		"text": "Every Grave-Binder learns this one and every one of them regrets the first time."
	},
	&"necro_chill":
	{
		"name": "Chill of the Barrow",
		"class": &"necromancer",
		"slot": 6,
		"effect": "speed",
		"power": 18,
		"speed": 0.45,
		"cost": 22,
		"cooldown": 14.0,
		"range": 24.0,
		"duration": 6.0,
		"level": 12,
		"text": "The cold that sits in old stone. It gets into whatever it touches."
	},
	&"necro_harvest":
	{
		"name": "Harvest",
		"class": &"necromancer",
		"slot": 7,
		"effect": "damage",
		"power": 95,
		"cost": 50,
		"cooldown": 25.0,
		"range": 26.0,
		"level": 16,
		"text": "Collects on everything the rot has been setting up."
	},
	# --- Tinker: ranged damage with turrets and bombs.
	&"tinker_shot":
	{
		"name": "Bolt Thrower",
		"class": &"tinker",
		"slot": 1,
		"effect": "damage",
		"power": 19,
		"cost": 9,
		"cooldown": 0.0,
		"range": 28.0,
		"level": 1,
		"text": "Crank, aim, release. No magic involved and that is the entire point."
	},
	&"tinker_oil":
	{
		"name": "Burning Oil",
		"class": &"tinker",
		"slot": 2,
		"effect": "dot",
		"power": 10,
		"cost": 15,
		"cooldown": 4.0,
		"range": 24.0,
		"duration": 8.0,
		"level": 2,
		"text": "Sticks first, burns second."
	},
	&"tinker_bomb":
	{
		"name": "Blackpowder Charge",
		"class": &"tinker",
		"slot": 3,
		"effect": "aoe_damage",
		"power": 30,
		"cost": 26,
		"cooldown": 9.0,
		"range": 22.0,
		"aoe": 6.5,
		"level": 4,
		"text": "Short fuse. Shorter than advertised, usually."
	},
	&"tinker_turret":
	{
		"name": "Field Turret",
		"class": &"tinker",
		"slot": 4,
		"effect": "summon",
		"target": "ground",
		"summon": &"tinker_turret_pet",
		"summon_seconds": 40.0,
		"cost": 28,
		"cooldown": 30.0,
		"level": 6,
		"text": "Bolt it to the ground, point it at the problem, walk away."
	},
	&"tinker_patch":
	{
		"name": "Field Repair",
		"class": &"tinker",
		"slot": 5,
		"effect": "heal",
		"target": "ally",
		"power": 40,
		"cost": 22,
		"cooldown": 12.0,
		"range": 18.0,
		"level": 8,
		"text": "The same kit for people and for machines. Nobody has complained yet."
	},
	&"tinker_net":
	{
		"name": "Snare Net",
		"class": &"tinker",
		"slot": 6,
		"effect": "speed",
		"power": 14,
		"speed": 0.4,
		"cost": 20,
		"cooldown": 16.0,
		"range": 20.0,
		"duration": 6.0,
		"level": 11,
		"text": "Weighted at the corners. Ends most chases immediately."
	},
	&"tinker_overload":
	{
		"name": "Overload",
		"class": &"tinker",
		"slot": 7,
		"effect": "aoe_damage",
		"power": 25,
		"cost": 0,
		"spends_all": true,
		"cooldown": 22.0,
		"range": 20.0,
		"aoe": 8.0,
		"level": 16,
		"text": "Dumps the whole Charge into one shot. The machine rarely survives it either."
	}
}

const EFFECT_NAMES := {
	"damage": AbilityData.Effect.DAMAGE,
	"aoe_damage": AbilityData.Effect.AOE_DAMAGE,
	"heal": AbilityData.Effect.HEAL,
	"aoe_heal": AbilityData.Effect.AOE_HEAL,
	"dot": AbilityData.Effect.DOT,
	"drain": AbilityData.Effect.DRAIN,
	"taunt": AbilityData.Effect.TAUNT,
	"summon": AbilityData.Effect.SUMMON,
	"speed": AbilityData.Effect.SPEED,
	"interrupt": AbilityData.Effect.INTERRUPT,
	"damage_reduction": AbilityData.Effect.DAMAGE_REDUCTION,
	"stun": AbilityData.Effect.STUN,
	"stack": AbilityData.Effect.STACK,
	"hot": AbilityData.Effect.HOT,
	"buff": AbilityData.Effect.BUFF
}

const TARGET_NAMES := {
	"enemy": AbilityData.TargetRule.ENEMY,
	"self": AbilityData.TargetRule.SELF,
	"ally": AbilityData.TargetRule.ALLY,
	"ground": AbilityData.TargetRule.GROUND
}

var _cache: Dictionary = {}
var _by_class: Dictionary = {}


func _ready() -> void:
	for ability_id in DEFINITIONS:
		var ability := _build(ability_id, DEFINITIONS[ability_id])
		_cache[ability_id] = ability
		if not _by_class.has(ability.class_id):
			_by_class[ability.class_id] = []
		_by_class[ability.class_id].append(ability)
	for class_id in _by_class:
		_by_class[class_id].sort_custom(func(a: AbilityData, b: AbilityData) -> bool: return a.slot < b.slot)


func get_ability(ability_id: StringName) -> AbilityData:
	if _cache.is_empty():
		_ready()
	return _cache.get(ability_id, null)


func get_all_ids() -> Array:
	return DEFINITIONS.keys()


## Every ability a class has, in bar order.
func abilities_for_class(class_id: StringName) -> Array:
	if _by_class.is_empty():
		_ready()
	return _by_class.get(class_id, [])


## The ability in a given bar slot, if the player is high enough level for it.
func ability_in_slot(class_id: StringName, slot: int, level: int) -> AbilityData:
	for ability in abilities_for_class(class_id):
		if ability.slot == slot:
			return ability if level >= ability.level_required else null
	return null


func _build(ability_id: StringName, entry: Dictionary) -> AbilityData:
	var ability := AbilityData.new()
	ability.id = ability_id
	ability.display_name = str(entry.get("name", ""))
	ability.class_id = StringName(str(entry.get("class", &"")))
	ability.slot = int(entry.get("slot", 1))
	ability.effect = EFFECT_NAMES.get(str(entry.get("effect", "damage")), AbilityData.Effect.DAMAGE)
	ability.target_rule = TARGET_NAMES.get(str(entry.get("target", "enemy")), AbilityData.TargetRule.ENEMY)
	ability.power = int(entry.get("power", 10))
	ability.cost = int(entry.get("cost", 10))
	ability.spends_all_resource = bool(entry.get("spends_all", false))
	ability.cooldown = float(entry.get("cooldown", 0.0))
	ability.cast_range = float(entry.get("range", 6.0))
	ability.aoe_radius = float(entry.get("aoe", 0.0))
	ability.duration_seconds = float(entry.get("duration", 0.0))
	ability.drain_ratio = float(entry.get("drain", 0.5))
	ability.summon_mob_id = StringName(str(entry.get("summon", &"")))
	ability.summon_seconds = float(entry.get("summon_seconds", 30.0))
	ability.speed_multiplier = float(entry.get("speed", 1.0))
	ability.reduction = clampf(float(entry.get("reduction", 0.3)), 0.0, 1.0)
	ability.max_stacks = maxi(1, int(entry.get("max_stacks", 5)))
	ability.level_required = int(entry.get("level", 1))
	ability.description = str(entry.get("text", ""))
	return ability
