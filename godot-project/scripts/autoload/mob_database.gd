# MobDatabase — every enemy in Kingsmourn, in one place.
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
	# --- Thornhollow Vale, levels 1-5 (close to town) ---
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
	# --- Thornhollow Vale, levels 6-12 (out toward the barrow) ---
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
		"currency": 8
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
	# --- The Barrow of the First King (dungeon) ---
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
		"boss": true
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
		"boss": true
	},
	# --- Sablemarch, levels 9-14 ---------------------------------------------
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
		"currency": 12
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
	# --- The Drowned Redoubt -------------------------------------------------
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
		"boss": true
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
		"boss": true
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
		"boss": true
	},
	# --- Kingsmourn (14-20) ----------------------------------------------------
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
		"currency": 24
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
	# --- The Hall of Records (dungeon 3, level 18) ------------------------------
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
		"dungeon": true
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
		"dungeon": true
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
		"boss": true
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
		"boss": true
	},
	# --- The Throne of Kingsmourn (raid, level 20) ------------------------------
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
		"boss": true
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
		"boss": true
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
		"boss": true
	}
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
	data.loot_table = entry.get("loot", {})
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
