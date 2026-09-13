# MobDatabase — every enemy in Ironveil, in one place.
#
# Adding an enemy is adding an entry to DEFINITIONS. No new code, no new scene:
# the spawner reads the id and builds it. That is what makes a whole zone's
# worth of enemies achievable.
#
# Loot ids here are placeholders from the template's item set. Real gear tables
# arrive with the gear system (see docs/BUILD_PLAN.md M8), and the slot
# ownership rule applies then: dungeons own armour and weapons, the open world
# owns rings, trinkets and cloaks.
extends Node

const DEFINITIONS := {
	# --- Thornfell, levels 1-5 (close to town) ---
	&"vale_wolf":
	{
		"name": "Vale Wolf",
		"level": 2,
		"health": 45,
		"damage": 6,
		"speed": 4.1,
		"aggro": 10.0,
		"xp": 14,
		"tags": [&"beast"],
		"color": Color(0.42, 0.38, 0.34),
		"scale": 0.85,
		"loot": {"bone": 0.35, "wolfsbane_ring": 0.04},
		"currency": 1
	},
	&"hedge_bandit":
	{
		"name": "Hedge Bandit",
		"level": 3,
		"health": 60,
		"damage": 8,
		"speed": 3.4,
		"aggro": 9.0,
		"xp": 20,
		"tags": [&"bandit", &"human"],
		"color": Color(0.46, 0.35, 0.24),
		"scale": 1.0,
		"loot": {"chicken_leg": 0.3, "gear_levy_cloak": 0.05},
		"currency": 2
	},
	&"bandit_cutthroat":
	{
		"name": "Bandit Cutthroat",
		"level": 3,
		"health": 78,
		"damage": 11,
		"speed": 3.6,
		"aggro": 10.0,
		"xp": 24,
		"tags": [&"bandit", &"human"],
		"color": Color(0.38, 0.28, 0.22),
		"scale": 1.02,
		"loot": {"gear_levy_ring": 0.06, "gear_levy_trinket": 0.04},
		"currency": 3
	},
	&"risen_levy":
	{
		"name": "Risen Levy",
		"level": 4,
		"health": 92,
		"damage": 12,
		"speed": 2.8,
		"aggro": 8.0,
		"xp": 30,
		"tags": [&"risen", &"undead"],
		"color": Color(0.55, 0.58, 0.5),
		"scale": 0.98,
		"loot": {"bone": 0.5, "gear_levy_cloak": 0.04},
		"currency": 3
	},
	# --- Thornfell, levels 6-12 (out toward the barrow) ---
	&"stag_outrider":
	{
		"name": "Stag Outrider",
		"level": 5,
		"health": 130,
		"damage": 16,
		"speed": 3.8,
		"aggro": 11.0,
		"xp": 38,
		"tags": [&"soldier", &"stag", &"human"],
		"color": Color(0.3, 0.45, 0.32),
		"scale": 1.05,
		"loot": {"gear_levy_ring": 0.05, "gear_levy_trinket": 0.05},
		"currency": 5
	},
	&"sunburst_serjeant":
	{
		"name": "Sunburst Serjeant",
		"level": 6,
		"health": 155,
		"damage": 18,
		"speed": 3.4,
		"aggro": 11.0,
		"xp": 46,
		"tags": [&"soldier", &"sunburst", &"human"],
		"color": Color(0.28, 0.36, 0.6),
		"scale": 1.08,
		"loot": {"gear_levy_trinket": 0.05, "gear_levy_cloak": 0.05},
		"currency": 6
	},
	&"grave_binder":
	{
		"name": "Grave-Binder",
		"level": 7,
		"health": 170,
		"damage": 21,
		"speed": 3.0,
		"aggro": 12.0,
		"xp": 58,
		"tags": [&"risen", &"caster", &"human"],
		"color": Color(0.4, 0.3, 0.48),
		"scale": 1.0,
		"loot": {"gear_levy_ring": 0.06, "gear_levy_trinket": 0.06},
		"currency": 8,
		"casts": [{"name": "Grave Bolt", "cast": 1.5, "every": 8.0, "power": 34, "range": 18.0}]
	},
	&"barrow_wight":
	{
		"name": "Barrow Wight",
		"level": 8,
		"health": 210,
		"damage": 25,
		"speed": 3.2,
		"aggro": 12.0,
		"xp": 70,
		"tags": [&"risen", &"undead", &"barrow"],
		"color": Color(0.5, 0.52, 0.62),
		"scale": 1.12,
		"loot": {"gear_levy_cloak": 0.06, "gear_levy_ring": 0.05},
		"currency": 10
	},
	# --- Summons. Spawned as pets, never placed in the world. ---
	&"tinker_turret_pet":
	{
		"name": "Field Turret",
		"level": 6,
		"health": 70,
		"damage": 14,
		"speed": 0.6,
		"aggro": 16.0,
		"xp": 0,
		"tags": [&"construct", &"summon"],
		"color": Color(0.72, 0.52, 0.22),
		"scale": 0.8,
		"loot": {},
		"currency": 0
	},
	&"tinker_medic_turret_pet":
	{
		"name": "Mending Turret",
		"level": 18,
		"health": 90,
		"damage": 0,
		"heal": 18,
		"attack_cooldown": 2.0,
		"speed": 0.6,
		"aggro": 16.0,
		"xp": 0,
		"tags": [&"construct", &"summon"],
		"color": Color(0.62, 0.72, 0.42),
		"scale": 0.8,
		"loot": {},
		"currency": 0
	},
	# --- The Deepbarrow (dungeon) ---
	&"barrow_guardian":
	{
		"name": "Barrow Guardian",
		"level": 8,
		"health": 190,
		"damage": 22,
		"speed": 3.0,
		"aggro": 11.0,
		"xp": 66,
		"tags": [&"risen", &"barrow"],
		"color": Color(0.46, 0.48, 0.56),
		"scale": 1.1,
		"loot": {"gear_levy_hands": 0.12, "gear_levy_feet": 0.12, "gear_levy_head": 0.08},
		"currency": 9,
		"dungeon": true
	},
	&"captain_reyne":
	{
		"name": "Captain Reyne",
		"level": 8,
		"health": 620,
		"damage": 30,
		"speed": 3.4,
		"aggro": 14.0,
		"xp": 210,
		"tags": [&"bandit", &"human", &"boss"],
		"color": Color(0.55, 0.24, 0.2),
		"scale": 1.3,
		"loot": {"gear_levy_chest": 0.5, "gear_levy_head": 0.5, "gear_levy_weapon_valkyr": 0.25, "gear_levy_weapon_bard": 0.25, "gear_levy_weapon_necromancer": 0.25, "gear_levy_weapon_tinker": 0.25},
		"currency": 45,
		"dungeon": true,
		"boss": true,
		# In grudge order: the first two are the fight; each tier adds one.
		"mechanics": [
			{"name": "Cutthroat Rush", "every": 14.0, "first": 8.0, "effect": "charge", "target": "furthest", "range": 30.0, "power": 40, "knockback": 8.0, "avoidable": true},
			{"name": "Bandit's Whistle", "at": [50], "effect": "spawn", "spawn": [{"id": "hedge_bandit", "count": 2}]},
			{"name": "Low Blow", "every": 10.0, "first": 5.0, "cast": 1.2, "effect": "damage", "power": 60, "target": "random", "range": 20.0, "avoidable": true},
			{"name": "Dirty Sand", "every": 18.0, "first": 12.0, "effect": "stun", "target": "tank", "duration": 2.0, "power": 10},
			{"name": "Second Wind", "every": 30.0, "first": 25.0, "cast": 2.0, "effect": "heal", "target": "self", "power": 90},
			{"name": "No Quarter", "at": [20], "every": 6.0, "effect": "stat", "damage_bonus": 0.10}
		]
	},
	&"the_first_king":
	{
		"name": "The First King",
		"level": 10,
		"health": 980,
		"damage": 38,
		"speed": 3.2,
		"aggro": 16.0,
		"xp": 420,
		"tags": [&"risen", &"barrow", &"boss"],
		"color": Color(0.72, 0.6, 0.28),
		"scale": 1.45,
		"loot": {"gear_levy_legs": 0.6, "gear_levy_chest": 0.4, "gear_levy_offhand_valkyr": 0.3, "gear_levy_offhand_bard": 0.3, "gear_levy_offhand_necromancer": 0.3, "gear_levy_offhand_tinker": 0.3, "mount_veil_saber": 0.15},
		"currency": 90,
		"dungeon": true,
		"boss": true,
		"mechanics": [
			{"name": "Grave Cold", "every": 12.0, "first": 6.0, "effect": "slow", "target": "random", "range": 24.0, "slow": 0.4, "duration": 5.0, "power": 30},
			{"name": "Rise", "at": [60, 30], "effect": "spawn", "spawn": [{"id": "risen_levy", "count": 2}]},
			{"name": "Barrow Wind", "every": 20.0, "first": 12.0, "cast": 1.5, "effect": "line", "target": "tank", "width": 3.0, "length": 30.0, "power": 70, "interruptible": false, "avoidable": true},
			{"name": "Old Grudge", "every": 16.0, "first": 10.0, "cast": 1.5, "effect": "damage", "power": 80, "target": "random", "range": 24.0, "avoidable": true},
			{"name": "Dust", "every": 14.0, "first": 9.0, "effect": "pool", "target": "random", "range": 24.0, "radius": 2.5, "slow": 0.6, "power": 12, "tick": 1.0, "persist": false, "seconds": 10.0, "avoidable": true},
			{"name": "The Crown Remembers", "at": [20], "every": 6.0, "effect": "stat", "damage_bonus": 0.10}
		]
	},
	# --- Greymarch, levels 9-14 ----------------------------------------------
	&"stag_picket":
	{
		"name": "Stag Picket",
		"level": 9,
		"health": 175,
		"damage": 20,
		"speed": 3.6,
		"aggro": 11.0,
		"xp": 78,
		"tags": [&"soldier", &"stag", &"human", &"picket"],
		"color": Color(0.28, 0.44, 0.3),
		"scale": 1.04,
		"loot": {"gear_marcher_ring": 0.05, "gear_marcher_cloak": 0.04},
		"currency": 7
	},
	&"sunburst_picket":
	{
		"name": "Sunburst Picket",
		"level": 10,
		"health": 195,
		"damage": 22,
		"speed": 3.4,
		"aggro": 11.0,
		"xp": 88,
		"tags": [&"soldier", &"sunburst", &"human", &"picket"],
		"color": Color(0.26, 0.35, 0.58),
		"scale": 1.06,
		"loot": {"gear_marcher_trinket": 0.05, "gear_marcher_cloak": 0.04},
		"currency": 8
	},
	&"drowned_levy":
	{
		"name": "Drowned Levy",
		"level": 11,
		"health": 215,
		"damage": 24,
		"speed": 2.6,
		"aggro": 9.0,
		"xp": 100,
		"tags": [&"risen", &"undead", &"drowned"],
		"color": Color(0.42, 0.52, 0.5),
		"scale": 1.0,
		"loot": {"bone": 0.5, "gear_marcher_ring": 0.04},
		"currency": 9
	},
	&"field_binder":
	{
		"name": "Field-Binder",
		"level": 12,
		"health": 240,
		"damage": 28,
		"speed": 3.0,
		"aggro": 13.0,
		"xp": 120,
		"tags": [&"risen", &"caster", &"human"],
		"color": Color(0.38, 0.28, 0.46),
		"scale": 1.0,
		"loot": {"gear_marcher_trinket": 0.06, "seal_of_two_houses": 0.03},
		"currency": 12,
		"casts": [{"name": "Grave Bolt", "cast": 1.5, "every": 8.0, "power": 46, "range": 18.0}]
	},
	&"march_wight":
	{
		"name": "March Wight",
		"level": 12,
		"health": 265,
		"damage": 30,
		"speed": 3.2,
		"aggro": 12.0,
		"xp": 130,
		"tags": [&"risen", &"undead", &"drowned"],
		"color": Color(0.46, 0.5, 0.58),
		"scale": 1.14,
		"loot": {"gear_marcher_cloak": 0.06, "gear_marcher_ring": 0.05},
		"currency": 14
	},
	&"flood_warden":
	{
		"name": "Flood Warden",
		"level": 13,
		"health": 320,
		"damage": 34,
		"speed": 2.8,
		"aggro": 12.0,
		"xp": 160,
		"tags": [&"risen", &"undead", &"drowned", &"redoubt"],
		"color": Color(0.34, 0.46, 0.5),
		"scale": 1.2,
		"loot": {"gear_marcher_trinket": 0.06, "ferrymans_coin": 0.04},
		"currency": 18
	},
	# --- The Drowned Hold ----------------------------------------------------
	# The two captains are one encounter: they fight you AND each other, which
	# is the whole point of them. Killing one first makes the other worse.
	&"captain_derrow":
	{
		"name": "Captain Derrow of the Stag",
		"level": 14,
		"health": 900,
		"damage": 40,
		"speed": 3.4,
		"aggro": 15.0,
		"xp": 520,
		"tags": [&"soldier", &"stag", &"drowned", &"boss", &"redoubt_captain"],
		"color": Color(0.24, 0.42, 0.28),
		"scale": 1.32,
		"loot": {"gear_marcher_chest": 0.5, "gear_marcher_hands": 0.5, "gear_marcher_weapon_valkyr": 0.25, "gear_marcher_weapon_bard": 0.25},
		"currency": 70,
		"dungeon": true,
		"boss": true,
		"feud": &"sunburst",
		"mechanics": [
			{"name": "Stag Charge", "every": 15.0, "first": 9.0, "effect": "charge", "target": "furthest", "range": 40.0, "power": 50, "knockback": 10.0, "avoidable": true},
			{"name": "Rally the Drowned", "at": [50], "effect": "spawn", "spawn": [{"id": "drowned_levy", "count": 2}]},
			{"name": "Antler Sweep", "every": 12.0, "first": 7.0, "cast": 1.0, "effect": "line", "target": "tank", "width": 3.0, "length": 30.0, "power": 65, "interruptible": false, "avoidable": true},
			{"name": "Mud Under Foot", "every": 18.0, "first": 11.0, "effect": "slow", "target": "tank", "slow": 0.2, "duration": 4.0, "power": 20},
			{"name": "The Stag Stands", "every": 28.0, "first": 22.0, "cast": 2.0, "effect": "heal", "target": "self", "power": 140},
			{"name": "Last Charge", "at": [20], "every": 6.0, "effect": "stat", "damage_bonus": 0.10}
		]
	},
	&"captain_vance":
	{
		"name": "Captain Vance of the Sunburst",
		"level": 14,
		"health": 900,
		"damage": 40,
		"speed": 3.4,
		"aggro": 15.0,
		"xp": 520,
		"tags": [&"soldier", &"sunburst", &"drowned", &"boss", &"redoubt_captain"],
		"color": Color(0.22, 0.32, 0.6),
		"scale": 1.32,
		"loot": {"gear_marcher_legs": 0.5, "gear_marcher_feet": 0.5, "gear_marcher_weapon_necromancer": 0.25, "gear_marcher_weapon_tinker": 0.25},
		"currency": 70,
		"dungeon": true,
		"boss": true,
		"feud": &"stag",
		"mechanics": [
			{"name": "Sun Volley", "every": 10.0, "first": 6.0, "cast": 1.5, "effect": "damage", "power": 90, "target": "random", "range": 30.0, "avoidable": true},
			{"name": "Rally the Drowned", "at": [50], "effect": "spawn", "spawn": [{"id": "drowned_levy", "count": 2}]},
			{"name": "Shield Wall", "every": 25.0, "first": 18.0, "cast": 2.0, "effect": "heal", "target": "self", "power": 120},
			{"name": "Sunburst", "every": 16.0, "first": 12.0, "cast": 1.2, "effect": "stun", "target": "random", "range": 30.0, "duration": 2.0, "power": 30},
			{"name": "Salt Water", "every": 14.0, "first": 8.0, "effect": "pool", "target": "random", "range": 30.0, "radius": 3.0, "slow": 0.5, "power": 14, "tick": 1.0, "persist": false, "seconds": 12.0, "avoidable": true},
			{"name": "Hold the Line", "at": [20], "every": 6.0, "effect": "stat", "damage_bonus": 0.10}
		]
	},
	&"the_weight_of_them":
	{
		"name": "The Weight of Them",
		"level": 14,
		"health": 1400,
		"damage": 46,
		"speed": 2.4,
		"aggro": 18.0,
		"xp": 900,
		"tags": [&"risen", &"drowned", &"redoubt", &"boss"],
		"color": Color(0.3, 0.38, 0.4),
		"scale": 1.6,
		"loot": {"gear_marcher_head": 0.6, "gear_marcher_chest": 0.4, "gear_marcher_offhand_valkyr": 0.3, "gear_marcher_offhand_bard": 0.3, "gear_marcher_offhand_necromancer": 0.3, "gear_marcher_offhand_tinker": 0.3, "mount_risen_brute": 0.15},
		"currency": 130,
		"dungeon": true,
		"boss": true,
		"mechanics": [
			{"name": "Undertow", "every": 8.0, "first": 5.0, "effect": "pool", "target": "random", "range": 40.0, "radius": 3.0, "slow": 0.5, "power": 15, "tick": 1.0, "persist": false, "seconds": 14.0, "avoidable": true},
			{"name": "Drag Down", "every": 20.0, "first": 12.0, "effect": "slow", "target": "tank", "slow": 0.1, "duration": 4.0, "power": 40},
			{"name": "The Flood Rises", "at": [50, 25], "effect": "spawn", "spawn": [{"id": "drowned_levy", "count": 3}]},
			{"name": "Crush", "every": 14.0, "first": 9.0, "cast": 1.5, "effect": "damage", "target": "tank", "power": 110, "avoidable": true},
			{"name": "Weight of Water", "every": 22.0, "first": 16.0, "cast": 1.5, "effect": "line", "target": "tank", "width": 4.0, "length": 30.0, "power": 75, "interruptible": false, "avoidable": true},
			{"name": "Every One of Them", "at": [20], "every": 6.0, "effect": "stat", "damage_bonus": 0.10}
		]
	},
	# --- Ironhold (14-20) ------------------------------------------------------
	&"street_agitator":
	{
		"name": "Street Agitator",
		"level": 14,
		"health": 300,
		"damage": 34,
		"speed": 3.4,
		"aggro": 11.0,
		"xp": 150,
		"tags": [&"human", &"agitator"],
		"color": Color(0.55, 0.42, 0.3),
		"scale": 1.0,
		"loot": {"gear_sovereign_ring": 0.03, "gear_sovereign_trinket": 0.02},
		"currency": 16
	},
	&"stag_retainer":
	{
		"name": "Stag Retainer",
		"level": 15,
		"health": 330,
		"damage": 36,
		"speed": 3.4,
		"aggro": 12.0,
		"xp": 165,
		"tags": [&"human", &"soldier", &"stag", &"retainer"],
		"color": Color(0.24, 0.42, 0.28),
		"scale": 1.05,
		"loot": {"gear_sovereign_cloak": 0.04, "gear_sovereign_ring": 0.03},
		"currency": 18
	},
	&"sunburst_retainer":
	{
		"name": "Sunburst Retainer",
		"level": 15,
		"health": 330,
		"damage": 36,
		"speed": 3.4,
		"aggro": 12.0,
		"xp": 165,
		"tags": [&"human", &"soldier", &"sunburst", &"retainer"],
		"color": Color(0.22, 0.32, 0.6),
		"scale": 1.05,
		"loot": {"gear_sovereign_cloak": 0.04, "gear_sovereign_trinket": 0.03},
		"currency": 18
	},
	&"crypt_risen":
	{
		"name": "Crypt Risen",
		"level": 16,
		"health": 360,
		"damage": 38,
		"speed": 3.0,
		"aggro": 12.0,
		"xp": 180,
		"tags": [&"risen", &"undead", &"crypt"],
		"color": Color(0.5, 0.52, 0.56),
		"scale": 1.12,
		"loot": {"gear_sovereign_ring": 0.04, "gear_sovereign_cloak": 0.04},
		"currency": 20
	},
	&"crown_binder":
	{
		"name": "Crown-Binder",
		"level": 17,
		"health": 340,
		"damage": 44,
		"speed": 3.1,
		"aggro": 14.0,
		"xp": 200,
		"tags": [&"human", &"binder", &"crypt"],
		"color": Color(0.4, 0.22, 0.45),
		"scale": 1.0,
		"loot": {"gear_sovereign_trinket": 0.05, "gear_sovereign_ring": 0.04},
		"currency": 24,
		"casts": [{"name": "Crown Bolt", "cast": 1.5, "every": 8.0, "power": 70, "range": 18.0}]
	},
	&"first_king_herald":
	{
		"name": "Herald of the First King",
		"level": 18,
		"health": 620,
		"damage": 50,
		"speed": 3.2,
		"aggro": 15.0,
		"xp": 320,
		"tags": [&"risen", &"undead", &"herald", &"elite"],
		"color": Color(0.62, 0.55, 0.3),
		"scale": 1.28,
		"loot": {"gear_sovereign_cloak": 0.08, "gear_sovereign_trinket": 0.06},
		"currency": 36
	},
	&"stag_guard":
	{
		"name": "Stag Palace Guard",
		"level": 19,
		"health": 420,
		"damage": 46,
		"speed": 3.4,
		"aggro": 13.0,
		"xp": 230,
		"tags": [&"human", &"soldier", &"stag", &"claimant_guard"],
		"color": Color(0.2, 0.4, 0.26),
		"scale": 1.08,
		"loot": {"gear_sovereign_ring": 0.04, "gear_sovereign_cloak": 0.04},
		"currency": 26
	},
	&"sunburst_guard":
	{
		"name": "Sunburst Palace Guard",
		"level": 19,
		"health": 420,
		"damage": 46,
		"speed": 3.4,
		"aggro": 13.0,
		"xp": 230,
		"tags": [&"human", &"soldier", &"sunburst", &"claimant_guard"],
		"color": Color(0.2, 0.3, 0.58),
		"scale": 1.08,
		"loot": {"gear_sovereign_trinket": 0.04, "gear_sovereign_cloak": 0.04},
		"currency": 26
	},
	# --- The Archive (dungeon 3, level 18) --------------------------------------
	&"record_burner":
	{
		"name": "Sunburst Record-Burner",
		"level": 18,
		"health": 400,
		"damage": 44,
		"speed": 3.3,
		"aggro": 13.0,
		"xp": 210,
		"tags": [&"human", &"sunburst", &"records"],
		"color": Color(0.3, 0.35, 0.6),
		"scale": 1.04,
		"loot": {},
		"currency": 22,
		"dungeon": true,
		"feud": &"stag"
	},
	&"record_forger":
	{
		"name": "Stag Record-Forger",
		"level": 18,
		"health": 400,
		"damage": 44,
		"speed": 3.3,
		"aggro": 13.0,
		"xp": 210,
		"tags": [&"human", &"stag", &"records"],
		"color": Color(0.3, 0.45, 0.32),
		"scale": 1.04,
		"loot": {},
		"currency": 22,
		"dungeon": true,
		"feud": &"sunburst"
	},
	&"master_kell":
	{
		"name": "Master Kell of the Records",
		"level": 18,
		"health": 1700,
		"damage": 54,
		"speed": 3.2,
		"aggro": 16.0,
		"xp": 1100,
		"tags": [&"human", &"binder", &"records", &"boss"],
		"color": Color(0.5, 0.3, 0.5),
		"scale": 1.3,
		"loot": {"gear_sovereign_hands": 0.5, "gear_sovereign_feet": 0.5, "gear_sovereign_weapon_valkyr": 0.25, "gear_sovereign_weapon_bard": 0.25, "gear_sovereign_weapon_necromancer": 0.25, "gear_sovereign_weapon_tinker": 0.25},
		"currency": 120,
		"dungeon": true,
		"boss": true,
		# docs/ironveil-endgame-spec.md, boss 1. Burn the Page is the
		# Tinker's interrupt; the Bind is what the Bard will cleanse.
		"mechanics": [
			{"name": "Burn the Page", "every": 12.0, "first": 6.0, "cast": 2.0, "effect": "damage", "power": 150, "target": "random", "range": 30.0, "avoidable": true},
			{"name": "Call the Shelves", "at": [70, 35], "effect": "spawn", "spawn": [{"id": "record_burner", "count": 2}, {"id": "record_forger", "count": 2}]},
			# Grudge tiers 1-5, one each. The Bind is the first thing grudge adds.
			{"name": "Bind", "every": 20.0, "first": 9.0, "effect": "slow", "target": "tank", "slow": 0.05, "duration": 4.0},
			{"name": "Ink Splash", "every": 14.0, "first": 8.0, "effect": "pool", "target": "random", "range": 30.0, "radius": 2.5, "slow": 0.5, "power": 15, "tick": 1.0, "persist": false, "seconds": 12.0, "avoidable": true},
			{"name": "Forbidden Word", "every": 22.0, "first": 14.0, "cast": 1.5, "effect": "stun", "target": "random", "range": 30.0, "duration": 2.5, "power": 40},
			{"name": "Second Reading", "every": 40.0, "first": 30.0, "cast": 2.5, "effect": "heal", "target": "self", "power": 200},
			{"name": "Close the Book", "at": [20], "every": 6.0, "effect": "stat", "damage_bonus": 0.10}
		]
	},
	&"the_bound_ledger":
	{
		"name": "The Bound Ledger",
		"level": 18,
		"health": 2200,
		"damage": 58,
		"speed": 2.4,
		"aggro": 18.0,
		"xp": 1400,
		"tags": [&"construct", &"records", &"boss"],
		"color": Color(0.7, 0.62, 0.45),
		"scale": 1.7,
		"loot": {"gear_sovereign_head": 0.5, "gear_sovereign_chest": 0.4, "gear_sovereign_legs": 0.4, "gear_sovereign_offhand_valkyr": 0.3, "gear_sovereign_offhand_bard": 0.3, "gear_sovereign_offhand_necromancer": 0.3, "gear_sovereign_offhand_tinker": 0.3, "mount_wraithcat": 0.12},
		"currency": 180,
		"dungeon": true,
		"boss": true,
		# Boss 2. Pools persist; the braziers in the vault are what clear them.
		"mechanics": [
			{"name": "Ink Pool", "every": 8.0, "first": 5.0, "effect": "pool", "target": "random", "range": 40.0, "radius": 3.0, "slow": 0.5, "power": 20, "tick": 1.0, "persist": true, "avoidable": true},
			{"name": "Turn the Page", "every": 30.0, "first": 30.0, "cast": 1.5, "effect": "pools_fire", "power": 60, "range": 60.0, "target": "self", "interruptible": false},
			{"name": "Paper Cut", "every": 9.0, "first": 4.0, "effect": "damage", "target": "tank", "power": 90},
			{"name": "Marginalia", "at": [60, 30], "effect": "spawn", "spawn": [{"id": "record_burner", "count": 1}, {"id": "record_forger", "count": 1}]},
			{"name": "Blot", "every": 20.0, "first": 12.0, "cast": 1.0, "effect": "slow", "target": "random", "range": 40.0, "slow": 0.3, "duration": 4.0},
			{"name": "Ledger Line", "every": 16.0, "first": 10.0, "cast": 1.2, "effect": "line", "target": "tank", "width": 3.0, "length": 40.0, "power": 90, "interruptible": false, "avoidable": true},
			{"name": "Final Entry", "at": [10], "every": 5.0, "effect": "stat", "damage_bonus": 0.15}
		]
	},
	# --- The Broken Throne (raid, level 20) -------------------------------------
	&"lord_ashcombe":
	{
		"name": "Lord Ashcombe of the Stag",
		"level": 20,
		"health": 3200,
		"damage": 62,
		"speed": 3.4,
		"aggro": 20.0,
		"xp": 1500,
		"tags": [&"human", &"stag", &"claimant", &"boss", &"raid"],
		"color": Color(0.16, 0.42, 0.24),
		"scale": 1.4,
		"loot": {"gear_sovereign_chest": 0.6, "gear_sovereign_hands": 0.5, "gear_sovereign_weapon_valkyr": 0.35, "gear_sovereign_weapon_bard": 0.35, "mount_twin_furnace_hound": 0.1},
		"currency": 250,
		"dungeon": true,
		"boss": true,
		"feud": &"sunburst",
		"mechanics": [
			{"name": "Charge", "every": 15.0, "first": 10.0, "effect": "charge", "target": "furthest", "range": 60.0, "power": 70, "knockback": 14.0, "avoidable": true},
			{"name": "Call the Guards", "at": [30], "effect": "spawn", "spawn": [{"id": "stag_guard", "count": 3}]},
			{"name": "Antler Sweep", "every": 12.0, "first": 7.0, "cast": 1.0, "effect": "line", "target": "tank", "width": 3.0, "length": 40.0, "power": 70, "interruptible": false, "avoidable": true},
			{"name": "Stag's Pride", "at": [60], "effect": "heal", "target": "self", "power": 300},
			{"name": "Trample", "every": 24.0, "first": 18.0, "effect": "pool", "target": "tank", "range": 40.0, "radius": 4.0, "slow": 0.5, "power": 25, "tick": 1.0, "persist": false, "seconds": 8.0, "avoidable": true}
		]
	},
	&"lady_severin":
	{
		"name": "Lady Severin of the Sunburst",
		"level": 20,
		"health": 3200,
		"damage": 62,
		"speed": 3.4,
		"aggro": 20.0,
		"xp": 1500,
		"tags": [&"human", &"sunburst", &"claimant", &"boss", &"raid"],
		"color": Color(0.18, 0.28, 0.62),
		"scale": 1.4,
		"loot": {"gear_sovereign_legs": 0.6, "gear_sovereign_feet": 0.5, "gear_sovereign_weapon_necromancer": 0.35, "gear_sovereign_weapon_tinker": 0.35, "mount_furnace_rhino": 0.1},
		"currency": 250,
		"dungeon": true,
		"boss": true,
		"feud": &"stag",
		"mechanics": [
			{"name": "Sun Lance", "every": 10.0, "first": 8.0, "cast": 1.2, "effect": "line", "target": "tank", "width": 3.0, "length": 40.0, "power": 80, "interruptible": false, "avoidable": true},
			{"name": "Call the Guards", "at": [30], "effect": "spawn", "spawn": [{"id": "sunburst_guard", "count": 3}]},
			{"name": "Sun Flare", "every": 14.0, "first": 9.0, "cast": 1.5, "effect": "damage", "power": 120, "target": "random", "range": 40.0, "avoidable": true},
			{"name": "Radiance", "at": [60], "effect": "spawn", "spawn": [{"id": "sunburst_guard", "count": 1}]},
			{"name": "Blinding", "every": 26.0, "first": 20.0, "cast": 1.2, "effect": "stun", "target": "random", "range": 40.0, "duration": 2.0, "power": 30}
		]
	},
	&"first_king_crowned":
	{
		"name": "The First King, Crowned",
		"level": 20,
		"health": 5000,
		"damage": 72,
		"speed": 2.8,
		"aggro": 24.0,
		"xp": 3000,
		"tags": [&"risen", &"undead", &"king", &"boss", &"raid"],
		"color": Color(0.72, 0.62, 0.3),
		"scale": 1.9,
		"loot": {"gear_sovereign_head": 0.7, "gear_sovereign_chest": 0.5, "gear_sovereign_offhand_valkyr": 0.4, "gear_sovereign_offhand_bard": 0.4, "gear_sovereign_offhand_necromancer": 0.4, "gear_sovereign_offhand_tinker": 0.4, "mount_ironhide": 0.08},
		"currency": 500,
		"dungeon": true,
		"boss": true,
		"mechanics": [
			{"name": "The Crown", "every": 25.0, "first": 15.0, "effect": "named", "target": "random", "range": 60.0, "duration": 8.0, "heal_share": 0.5, "dais": "throne_dais"},
			{"name": "Heralds", "at": [75, 50, 25], "effect": "spawn", "spawn": [{"id": "first_king_herald", "count": 2}], "alive_bonus": 0.10},
			{"name": "Ironhold", "at": [15], "every": 5.0, "effect": "stat", "damage_bonus": 0.10},
			{"name": "Grave Wind", "every": 18.0, "first": 12.0, "cast": 1.5, "effect": "line", "target": "tank", "width": 3.0, "length": 50.0, "power": 100, "interruptible": false, "avoidable": true},
			{"name": "The Weight of the Crown", "every": 22.0, "first": 16.0, "effect": "slow", "target": "random", "range": 60.0, "slow": 0.2, "duration": 5.0, "power": 60}
		]
	}
}

## Which model each enemy wears, from assets/enemies/. Ten human variants and
## the wolf cover the vale (docs/ironveil-enemy-weapon-spec.md); zones two
## and three reuse them by house and by kind, per the spec's "reuse
## ruthlessly". Constructs (the turret, the Ledger) stay placeholders: they are
## props, not people. Add a line here when a new variant is modelled.
const MODELS := {
	&"vale_wolf": "vale_wolf",
	&"hedge_bandit": "enemy_hedge_bandit",
	&"bandit_cutthroat": "enemy_bandit_cutthroat",
	&"risen_levy": "enemy_risen_levy",
	&"stag_outrider": "enemy_stag_outrider",
	&"sunburst_serjeant": "enemy_sunburst_serjeant",
	&"grave_binder": "enemy_grave_binder",
	&"barrow_wight": "enemy_barrow_wight",
	&"barrow_guardian": "enemy_barrow_guardian",
	&"captain_reyne": "enemy_captain_reyne",
	&"the_first_king": "enemy_the_first_king",
	# Greymarch
	&"stag_picket": "enemy_stag_outrider",
	&"sunburst_picket": "enemy_sunburst_serjeant",
	&"drowned_levy": "enemy_risen_levy",
	&"field_binder": "enemy_grave_binder",
	&"march_wight": "enemy_barrow_wight",
	&"flood_warden": "enemy_barrow_guardian",
	&"captain_derrow": "enemy_stag_outrider",
	&"captain_vance": "enemy_sunburst_serjeant",
	&"the_weight_of_them": "enemy_barrow_wight",
	# Ironhold
	&"street_agitator": "enemy_hedge_bandit",
	&"stag_retainer": "enemy_stag_outrider",
	&"sunburst_retainer": "enemy_sunburst_serjeant",
	&"crypt_risen": "enemy_risen_levy",
	&"crown_binder": "enemy_grave_binder",
	&"first_king_herald": "enemy_barrow_guardian",
	&"stag_guard": "enemy_stag_outrider",
	&"sunburst_guard": "enemy_sunburst_serjeant",
	&"record_burner": "enemy_sunburst_serjeant",
	&"record_forger": "enemy_stag_outrider",
	&"master_kell": "enemy_grave_binder",
	&"lord_ashcombe": "enemy_stag_outrider",
	&"lady_severin": "enemy_sunburst_serjeant",
	&"first_king_crowned": "enemy_the_first_king"
}

var _cache: Dictionary = {}


func _ready() -> void:
	for mob_id in DEFINITIONS:
		_cache[mob_id] = _build(mob_id, DEFINITIONS[mob_id])


func get_mob(mob_id: StringName) -> MobData:
	if _cache.is_empty():
		_ready()
	return _cache.get(mob_id, null)


func get_all_ids() -> Array:
	return DEFINITIONS.keys()


func _build(mob_id: StringName, entry: Dictionary) -> MobData:
	var data := MobData.new()
	data.id = mob_id
	data.display_name = str(entry.get("name", "Enemy"))
	data.level = int(entry.get("level", 1))
	data.max_health = int(entry.get("health", 60))
	data.damage = int(entry.get("damage", 8))
	data.move_speed = float(entry.get("speed", 3.2))
	data.aggro_radius = float(entry.get("aggro", 9.0))
	data.experience_reward = int(entry.get("xp", 20))
	data.currency_reward = int(entry.get("currency", 0))
	data.placeholder_color = entry.get("color", Color(0.5, 0.45, 0.4))
	data.scale_multiplier = float(entry.get("scale", 1.0))
	var model := str(MODELS.get(mob_id, ""))
	if not model.is_empty():
		data.model_path = "res://assets/enemies/%s.glb" % model
	data.loot_table = entry.get("loot", {})
	data.casts = entry.get("casts", [])
	data.heal_power = int(entry.get("heal", 0))
	data.attack_cooldown = float(entry.get("attack_cooldown", data.attack_cooldown))
	data.mechanics = entry.get("mechanics", [])
	data.feud = StringName(str(entry.get("feud", "")))
	data.is_boss = bool(entry.get("boss", false))
	data.is_dungeon = bool(entry.get("dungeon", false)) or data.is_boss
	if data.is_boss:
		# Bosses hold their ground: they don't wander off and they hit slower
		# but much harder, which leaves room for mechanics between swings.
		data.leash_radius = 40.0
		data.attack_cooldown = 2.4
		data.respawn_seconds = 120.0
	var tags: Array[StringName] = []
	for tag in entry.get("tags", []):
		tags.append(StringName(tag))
	data.tags = tags
	return data
