# SpecDatabase — two specs per class, so any five friends can form a party.
#
# docs/ironveil-class-spec.md. A spec is a passive that sets the role, two
# or three spec abilities, and a capstone at 20. The abilities themselves are
# entries in AbilityDatabase carrying a `spec` field; this file is the passive
# and the words. You pick a spec at level 10, at an inn or a graveyard, free.
#
# Passive fields, all optional, read by Stats and AbilityBar:
#   armor_mult, health_mult, threat_mult      Stats
#   damage_mult, healing_mult                 every hit / heal you cause
#   cooldown_mult   {ability: factor}         that ability's cooldown
#   tick_mult       {ability: factor}         that DoT's tick interval
#   summon_mult                               how long your summons last
#   drain_mult                                Grave Draught's returned share
#   pet_attack_mult                           your turrets' swing interval
#   chain           {ability: ability}        casting one also casts the other
#   ally_targets    [abilities]               these now target an ally at range
extends Node

const DEFINITIONS := {
	&"bulwark": {
		"name": "Bulwark", "class": &"valkyr", "role": "Tank",
		"text": "Wings as a wall. Absorbs, taunts, holds the line.",
		"passive": "+25% armour. Threat doubled.",
		"armor_mult": 1.25, "threat_mult": 2.0
	},
	&"lance": {
		"name": "Lance", "class": &"valkyr", "role": "Melee Damage",
		"text": "Descend from height and hit one thing very hard.",
		"passive": "+15% damage. Descend's cooldown halved.",
		"damage_mult": 1.15, "cooldown_mult": {&"valkyr_descend": 0.5}
	},
	&"hymn": {
		"name": "Hymn", "class": &"bard", "role": "Healer",
		"text": "Verses that mend. Keep the songs up, refresh, Chorus when it goes bad.",
		"passive": "Healing +20%. Marching Air also lays Soothing Verse on everyone it reaches.",
		"healing_mult": 1.2, "chain": {&"bard_march": &"bard_soothe"}
	},
	&"dirge": {
		"name": "Dirge", "class": &"bard", "role": "Ranged Damage",
		"text": "Songs that cut. The mockery-and-curses bard.",
		"passive": "Damage +20%. Cutting Chord leaves a stacking bleed.",
		"damage_mult": 1.2, "chain": {&"bard_chord": &"bard_bleed"}
	},
	&"grave": {
		"name": "Grave", "class": &"necromancer", "role": "Ranged Damage",
		"text": "Rot, bolts, raised levies.",
		"passive": "Creeping Rot ticks 30% faster. Levies last half again as long.",
		"tick_mult": {&"necro_rot": 0.7}, "summon_mult": 1.5
	},
	&"pact": {
		"name": "Pact", "class": &"necromancer", "role": "Tank",
		"text": "Trades health for armour of bone; drains to stay standing.",
		"passive": "+20% health. Grave Draught heals for double. Threat doubled.",
		"health_mult": 1.2, "drain_mult": 2.0, "threat_mult": 2.0
	},
	&"artillery": {
		"name": "Artillery", "class": &"tinker", "role": "Ranged Damage",
		"text": "Turrets, bombs, oil.",
		"passive": "+15% damage. Turrets fire 30% faster.",
		"damage_mult": 1.15, "pet_attack_mult": 0.7
	},
	&"medic": {
		"name": "Medic", "class": &"tinker", "role": "Healer",
		"text": "Field repair on people. A turret that heals. Tonics.",
		"passive": "Healing +20%. Field Repair works on allies at range.",
		"healing_mult": 1.2, "ally_targets": [&"tinker_patch"]
	}
}

## Nobody has a spec before this.
const CHOOSE_LEVEL := 10


func get_spec(spec_id: StringName) -> Dictionary:
	return DEFINITIONS.get(spec_id, {})


func get_all_ids() -> Array:
	return DEFINITIONS.keys()


func specs_for(class_id: StringName) -> Array:
	var found := []
	for spec_id in DEFINITIONS:
		if DEFINITIONS[spec_id]["class"] == class_id:
			found.append(spec_id)
	return found


func is_spec_of(spec_id: StringName, class_id: StringName) -> bool:
	return DEFINITIONS.has(spec_id) and DEFINITIONS[spec_id]["class"] == class_id


## The passive's numbers, or an empty dictionary for "no spec yet".
func passive_for(spec_id: StringName) -> Dictionary:
	return DEFINITIONS.get(spec_id, {})


func multiplier(spec_id: StringName, key: String) -> float:
	return float(passive_for(spec_id).get(key, 1.0))


func per_ability(spec_id: StringName, key: String, ability_id: StringName) -> float:
	var table: Dictionary = passive_for(spec_id).get(key, {})
	return float(table.get(ability_id, 1.0))


func chained(spec_id: StringName, ability_id: StringName) -> StringName:
	var table: Dictionary = passive_for(spec_id).get("chain", {})
	return StringName(str(table.get(ability_id, "")))


func targets_allies(spec_id: StringName, ability_id: StringName) -> bool:
	return passive_for(spec_id).get("ally_targets", []).has(ability_id)
