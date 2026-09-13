# AbilityDatabase — every ability in the game, as data.
#
# Per docs/kingsmourn-class-spec.md: each class shares five abilities across
# its two specs, each spec adds two or three of its own plus a capstone at 20
# (`spec` field), and twelve rune moves (`rune_move`, slot 0) reach the bar
# only through a GRANT rune. Bar slots 1-8 are the class and spec abilities,
# 9 the capstone, 10-12 the three rune moves.
#
# Levels are spread so a class gains something roughly every other level on the
# way to 20; spec abilities carry their own levels, and anything you are
# already past unlocks the moment you pick the spec.
extends Node

## The bar: 1-8 class and spec, 9 capstone, 10-12 rune moves.
const CLASS_SLOTS := 8
const CAPSTONE_SLOT := 9
const FIRST_RUNE_SLOT := 10
const BAR_SLOTS := 12

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
		"spec": &"bulwark",
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
		"effect": "damage_reduction",
		"target": "self",
		"reduction": 0.3,
		"duration": 6.0,
		"power": 0,
		"cost": 20,
		"cooldown": 15.0,
		"level": 6,
		"text": "Wings folded across the body. A third less of everything gets through, for six seconds. The every-pull button."
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
		"slot": 0,
		"rune_move": true,
		"effect": "aoe_heal",
		"target": "ground",
		"power": 30,
		"cost": 40,
		"cooldown": 45.0,
		"aoe": 12.0,
		"level": 11,
		"text": "Nobody else falls here today. Everyone nearby takes heart. A rune move, for a healer-less night."
	},
	&"valkyr_wall":
	{
		"name": "Unbroken Wing",
		"class": &"valkyr",
		"spec": &"bulwark",
		"slot": 6,
		"effect": "damage_reduction",
		"target": "self",
		"reduction": 0.6,
		"duration": 10.0,
		"power": 0,
		"cost": 0,
		"cooldown": 120.0,
		"level": 12,
		"text": "The big one. Sixty percent less for ten seconds, once every two minutes. For the moment it goes wrong."
	},
	&"valkyr_last_stand":
	{
		"name": "Last Stand of the Vale",
		"class": &"valkyr",
		"spec": &"bulwark",
		"slot": 9,
		"effect": "unkillable",
		"target": "self",
		"duration": 8.0,
		"power": 0,
		"cost": 0,
		"cooldown": 180.0,
		"level": 20,
		"text": "For eight seconds you cannot fall below one point of health. Cheap, big, unkillable: the third tier."
	},
	&"valkyr_pierce":
	{
		"name": "Piercing Fall",
		"class": &"valkyr",
		"spec": &"lance",
		"slot": 2,
		"effect": "stun",
		"power": 40,
		"duration": 1.5,
		"cost": 15,
		"cooldown": 12.0,
		"range": 22.0,
		"level": 10,
		"text": "Descend, spear first. Heavy damage on landing and a moment where they cannot answer."
	},
	&"valkyr_thrust":
	{
		"name": "Widow's Thrust",
		"class": &"valkyr",
		"spec": &"lance",
		"slot": 6,
		"effect": "damage",
		"execute": true,
		"power": 36,
		"cost": 20,
		"cooldown": 8.0,
		"range": 4.5,
		"level": 18,
		"text": "The closer they are to done, the harder it lands. Up to double on something nearly dead."
	},
	&"valkyr_choice":
	{
		"name": "Valkyrie's Choice",
		"class": &"valkyr",
		"spec": &"lance",
		"slot": 9,
		"effect": "buff",
		"target": "self",
		"power": 40,
		"duration": 10.0,
		"cost": 0,
		"cooldown": 90.0,
		"level": 20,
		"text": "Choose one, and for ten seconds every hit you land is the one that counts."
	},
	&"valkyr_spearcast":
	{
		"name": "Spearcast",
		"class": &"valkyr",
		"slot": 0,
		"rune_move": true,
		"effect": "damage",
		"power": 70,
		"cost": 25,
		"cooldown": 30.0,
		"range": 24.0,
		"level": 5,
		"text": "Throw the spear. It comes back, eventually. A rune move."
	},
	&"valkyr_wingbeat":
	{
		"name": "Wingbeat",
		"class": &"valkyr",
		"slot": 0,
		"rune_move": true,
		"effect": "dash",
		"target": "self",
		"power": 0,
		"cost": 0,
		"cooldown": 20.0,
		"level": 17,
		"text": "One beat of the wings carries you eight metres and out of whatever was holding you. A rune move."
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
		"target": "ground",
		"speed": 1.35,
		"power": 0,
		"cost": 18,
		"cooldown": 18.0,
		"aoe": 20.0,
		"duration": 10.0,
		"level": 5,
		"text": "An old road song. Every foot in earshot follows it whether its owner agrees or not."
	},
	&"bard_soothe":
	{
		"name": "Soothing Verse",
		"class": &"bard",
		"spec": &"hymn",
		"slot": 5,
		"effect": "hot",
		"target": "ally",
		"power": 6,
		"tick": 1.0,
		"duration": 12.0,
		"cost": 8,
		"cooldown": 0.0,
		"range": 24.0,
		"level": 4,
		"text": "A quiet tune that keeps going. Keep it rolling on whoever is being hit."
	},
	&"bard_anthem":
	{
		"name": "Anthem of the Vale",
		"class": &"bard",
		"spec": &"hymn",
		"slot": 7,
		"effect": "hot",
		"target": "ground",
		"power": 5,
		"tick": 1.0,
		"duration": 12.0,
		"cost": 30,
		"cooldown": 15.0,
		"aoe": 14.0,
		"level": 8,
		"text": "Everyone who can hear it stands a little straighter, and keeps standing, for twelve seconds."
	},
	&"bard_hymn":
	{
		"name": "Battle Hymn",
		"class": &"bard",
		"spec": &"hymn",
		"slot": 8,
		"effect": "buff",
		"target": "ground",
		"power": 12,
		"aoe": 20.0,
		"duration": 20.0,
		"cost": 25,
		"cooldown": 60.0,
		"level": 12,
		"text": "The old marching song, the loud verse. Everyone hits harder for twenty seconds."
	},
	&"bard_chorus":
	{
		"name": "Chorus",
		"class": &"bard",
		"spec": &"hymn",
		"slot": 9,
		"effect": "haste_hots",
		"target": "self",
		"duration": 8.0,
		"power": 0,
		"cost": 30,
		"cooldown": 90.0,
		"level": 20,
		"text": "Every song you have running sings twice as fast for eight seconds. The panic button that rewards having set up."
	},
	&"bard_mock":
	{
		"name": "Mocking Verse",
		"class": &"bard",
		"spec": &"dirge",
		"slot": 5,
		"effect": "dot",
		"power": 8,
		"weaken": 0.1,
		"cost": 14,
		"cooldown": 6.0,
		"range": 24.0,
		"duration": 10.0,
		"level": 10,
		"text": "A song about them, and not a kind one. It hurts, and they hit softer while it lasts."
	},
	&"bard_bleed":
	{
		"name": "Bleeding Chord",
		"class": &"bard",
		"spec": &"dirge",
		"slot": 0,
		"effect": "stack",
		"power": 4,
		"tick": 1.0,
		"duration": 8.0,
		"max_stacks": 5,
		"cost": 0,
		"cooldown": 0.0,
		"range": 24.0,
		"level": 10,
		"text": "The cut a Cutting Chord leaves. Stacks."
	},
	&"bard_crescendo":
	{
		"name": "Crescendo",
		"class": &"bard",
		"spec": &"dirge",
		"slot": 7,
		"effect": "damage",
		"consumes": &"bard_bleed",
		"consume_bonus": 25,
		"power": 30,
		"cost": 20,
		"cooldown": 10.0,
		"range": 22.0,
		"level": 18,
		"text": "Every bleed you have on them, all at once, and then silence."
	},
	&"bard_last_note":
	{
		"name": "The Last Note",
		"class": &"bard",
		"spec": &"dirge",
		"slot": 9,
		"effect": "charges",
		"charges": 3,
		"charges_ability": &"bard_chord",
		"target": "self",
		"duration": 30.0,
		"power": 0,
		"cost": 0,
		"cooldown": 60.0,
		"level": 20,
		"text": "Your next three Cutting Chords cost nothing and land for double."
	},
	&"bard_discord":
	{
		"name": "Discord",
		"class": &"bard",
		"slot": 0,
		"rune_move": true,
		"effect": "damage",
		"power": 60,
		"cost": 20,
		"cooldown": 30.0,
		"range": 24.0,
		"level": 5,
		"text": "Every string at once, all of them wrong. A rune move."
	},
	&"bard_skip":
	{
		"name": "Skip Step",
		"class": &"bard",
		"slot": 0,
		"rune_move": true,
		"effect": "dash",
		"target": "self",
		"power": 0,
		"cost": 0,
		"cooldown": 20.0,
		"level": 17,
		"text": "A dance step, eight metres long, out of whatever was holding you. A rune move."
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
		"slot": 0,
		"rune_move": true,
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
		"spec": &"grave",
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
	&"necro_mass":
	{
		"name": "Mass Grave",
		"class": &"necromancer",
		"spec": &"grave",
		"slot": 9,
		"effect": "summon",
		"target": "ground",
		"summon": &"risen_levy",
		"summon_count": 3,
		"summon_seconds": 15.0,
		"cost": 40,
		"cooldown": 120.0,
		"level": 20,
		"text": "Three at once, for fifteen seconds. The whole field gets up."
	},
	&"necro_ward":
	{
		"name": "Bone Ward",
		"class": &"necromancer",
		"spec": &"pact",
		"slot": 4,
		"effect": "damage_reduction",
		"target": "self",
		"reduction": 0.4,
		"duration": 10.0,
		"power": 0,
		"cost": 20,
		"cooldown": 30.0,
		"level": 10,
		"text": "Armour of bone, grown from your own. Forty percent less gets through for ten seconds."
	},
	&"necro_claim":
	{
		"name": "Grave Claim",
		"class": &"necromancer",
		"spec": &"pact",
		"slot": 5,
		"effect": "taunt",
		"power": 10,
		"root": 2.0,
		"cost": 10,
		"cooldown": 10.0,
		"range": 18.0,
		"level": 18,
		"text": "It is yours, and for two seconds it is not going anywhere."
	},
	&"necro_refuse":
	{
		"name": "Refuse the Grave",
		"class": &"necromancer",
		"spec": &"pact",
		"slot": 9,
		"effect": "cheat_death",
		"target": "self",
		"reduction": 0.3,
		"duration": 12.0,
		"power": 30,
		"cost": 0,
		"cooldown": 180.0,
		"level": 20,
		"text": "For twelve seconds the blow that should kill you instead leaves you at a third, and drains everything within eight metres."
	},
	&"necro_graveshot":
	{
		"name": "Graveshot",
		"class": &"necromancer",
		"slot": 0,
		"rune_move": true,
		"effect": "damage",
		"power": 75,
		"cost": 25,
		"cooldown": 30.0,
		"range": 26.0,
		"level": 5,
		"text": "One bolt with everything behind it. A rune move."
	},
	&"necro_brace":
	{
		"name": "Bracing Draught",
		"class": &"necromancer",
		"slot": 0,
		"rune_move": true,
		"effect": "heal",
		"target": "self",
		"power": 60,
		"cost": 15,
		"cooldown": 30.0,
		"level": 11,
		"text": "Something from the flask. It works; do not ask. A rune move."
	},
	&"necro_bonestep":
	{
		"name": "Bone Step",
		"class": &"necromancer",
		"slot": 0,
		"rune_move": true,
		"effect": "dash",
		"target": "self",
		"power": 0,
		"cost": 0,
		"cooldown": 20.0,
		"level": 17,
		"text": "Eight metres, sideways through somewhere cold, and out of whatever held you. A rune move."
	},
	&"necro_burst":
	{
		"name": "Corpse Burst",
		"class": &"necromancer",
		"spec": &"grave",
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
	&"tinker_triage":
	{
		"name": "Triage",
		"class": &"tinker",
		"spec": &"medic",
		"slot": 4,
		"effect": "heal",
		"target": "ally",
		"power": 24,
		"low_health_bonus": 1.6,
		"cost": 8,
		"cooldown": 3.0,
		"range": 24.0,
		"level": 10,
		"text": "Quick, cheap, and a good deal stronger on someone under forty percent."
	},
	&"tinker_mend_turret":
	{
		"name": "Mending Turret",
		"class": &"tinker",
		"spec": &"medic",
		"slot": 5,
		"effect": "summon",
		"target": "ground",
		"summon": &"tinker_medic_turret_pet",
		"summon_seconds": 30.0,
		"cost": 25,
		"cooldown": 30.0,
		"level": 18,
		"text": "Bolt it down and it patches whoever nearby is worst off, every two seconds."
	},
	&"tinker_tonic":
	{
		"name": "Tonic of the Marches",
		"class": &"tinker",
		"spec": &"medic",
		"slot": 9,
		"effect": "hot",
		"target": "ground",
		"aoe": 20.0,
		"power": 8,
		"tick": 1.0,
		"duration": 12.0,
		"cleanses": true,
		"cost": 40,
		"cooldown": 90.0,
		"level": 20,
		"text": "A round for everyone. Mends for twelve seconds and shakes off whatever was slowing or holding them."
	},
	&"tinker_bombard":
	{
		"name": "Bombardment",
		"class": &"tinker",
		"spec": &"artillery",
		"slot": 9,
		"effect": "aoe_damage",
		"power": 28,
		"aoe": 5.0,
		"line_count": 3,
		"cost": 35,
		"cooldown": 60.0,
		"range": 22.0,
		"level": 20,
		"text": "Three Blackpowder Charges, walking away from you in a line."
	},
	&"tinker_mortar":
	{
		"name": "Mortar",
		"class": &"tinker",
		"slot": 0,
		"rune_move": true,
		"effect": "aoe_damage",
		"power": 55,
		"aoe": 6.0,
		"cost": 25,
		"cooldown": 30.0,
		"range": 24.0,
		"level": 5,
		"text": "Up, over, and down on all of them. A rune move."
	},
	&"tinker_field_tonic":
	{
		"name": "Field Tonic",
		"class": &"tinker",
		"slot": 0,
		"rune_move": true,
		"effect": "heal",
		"target": "self",
		"power": 55,
		"cost": 15,
		"cooldown": 30.0,
		"level": 11,
		"text": "The bottle in the kit that is not for machines. A rune move."
	},
	&"tinker_grapnel":
	{
		"name": "Grapnel",
		"class": &"tinker",
		"slot": 0,
		"rune_move": true,
		"effect": "dash",
		"target": "self",
		"power": 0,
		"cost": 0,
		"cooldown": 20.0,
		"level": 17,
		"text": "Fire the hook, hold on. Eight metres, and nothing holds you on the way. A rune move."
	},
	&"tinker_turret":
	{
		"name": "Field Turret",
		"class": &"tinker",
		"spec": &"artillery",
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
		"slot": 8,
		"effect": "heal",
		"target": "self",
		"power": 40,
		"cost": 22,
		"cooldown": 12.0,
		"range": 18.0,
		"level": 8,
		"text": "The same kit for people and for machines. A Medic can use it on anyone in reach; anyone else patches themselves."
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
	"buff": AbilityData.Effect.BUFF,
	"dash": AbilityData.Effect.DASH,
	"unkillable": AbilityData.Effect.UNKILLABLE,
	"cheat_death": AbilityData.Effect.CHEAT_DEATH,
	"charges": AbilityData.Effect.CHARGES,
	"haste_hots": AbilityData.Effect.HASTE_HOTS
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


## Every ability a class has — shared, both specs' and the rune moves.
func abilities_for_class(class_id: StringName) -> Array:
	if _by_class.is_empty():
		_ready()
	return _by_class.get(class_id, [])


## The abilities this build can actually press: shared ones, the chosen
## spec's, and whatever the worn runes grant, all at or below `level`.
func abilities_on_bar(class_id: StringName, spec_id: StringName, level: int, granted: Array = []) -> Array:
	var found := []
	for slot in range(1, BAR_SLOTS + 1):
		var ability := ability_in_slot(class_id, slot, level, spec_id, granted)
		if ability:
			found.append(ability)
	return found


## The ability in a given bar slot, if the player is high enough level for it
## and the build (spec, runes) puts it there. Slots 10-12 hold what the three
## rune slots grant.
func ability_in_slot(class_id: StringName, slot: int, level: int, spec_id: StringName = &"", granted: Array = []) -> AbilityData:
	if slot >= FIRST_RUNE_SLOT:
		var rune_index := slot - FIRST_RUNE_SLOT
		if rune_index >= granted.size():
			return null
		var move := get_ability(StringName(str(granted[rune_index])))
		if move == null or move.class_id != class_id or not move.rune_move:
			return null
		return move if level >= move.level_required else null
	for ability in abilities_for_class(class_id):
		if ability.slot != slot or ability.rune_move:
			continue
		if ability.spec != &"" and ability.spec != spec_id:
			continue
		return ability if level >= ability.level_required else null
	return null


## The bar slot an ability sits in for this build, or 0 if it is not on it.
func slot_of(ability: AbilityData, class_id: StringName, spec_id: StringName, level: int, granted: Array = []) -> int:
	if ability == null:
		return 0
	for slot in range(1, BAR_SLOTS + 1):
		if ability_in_slot(class_id, slot, level, spec_id, granted) == ability:
			return slot
	return 0


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
	ability.tick_seconds = float(entry.get("tick", 1.0))
	ability.spec = StringName(str(entry.get("spec", "")))
	ability.rune_move = bool(entry.get("rune_move", false))
	ability.execute = bool(entry.get("execute", false))
	ability.consumes = StringName(str(entry.get("consumes", "")))
	ability.consume_bonus = int(entry.get("consume_bonus", 0))
	ability.weaken = float(entry.get("weaken", 0.0))
	ability.low_health_bonus = float(entry.get("low_health_bonus", 1.0))
	ability.cleanses = bool(entry.get("cleanses", false))
	ability.line_count = maxi(1, int(entry.get("line_count", 1)))
	ability.summon_count = maxi(1, int(entry.get("summon_count", 1)))
	ability.root_seconds = float(entry.get("root", 0.0))
	ability.charges = maxi(1, int(entry.get("charges", 3)))
	ability.charges_ability = StringName(str(entry.get("charges_ability", "")))
	ability.level_required = int(entry.get("level", 1))
	ability.description = str(entry.get("text", ""))
	return ability
