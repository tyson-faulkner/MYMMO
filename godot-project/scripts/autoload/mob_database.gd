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
		"xp": 18,
		"tags": [&"beast"],
		"color": Color(0.42, 0.38, 0.34),
		"scale": 0.85,
		"loot": {"bone": 0.35},
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
		"xp": 24,
		"tags": [&"bandit", &"human"],
		"color": Color(0.46, 0.35, 0.24),
		"scale": 1.0,
		"loot": {"chicken_leg": 0.3, "sword": 0.05},
		"currency": 2
	},
	&"bandit_cutthroat":
	{
		"name": "Bandit Cutthroat",
		"level": 4,
		"health": 78,
		"damage": 11,
		"speed": 3.6,
		"aggro": 10.0,
		"xp": 30,
		"tags": [&"bandit", &"human"],
		"color": Color(0.38, 0.28, 0.22),
		"scale": 1.02,
		"loot": {"sword": 0.1, "chalice": 0.05},
		"currency": 3
	},
	&"risen_levy":
	{
		"name": "Risen Levy",
		"level": 5,
		"health": 92,
		"damage": 12,
		"speed": 2.8,
		"aggro": 8.0,
		"xp": 36,
		"tags": [&"risen", &"undead"],
		"color": Color(0.55, 0.58, 0.5),
		"scale": 0.98,
		"loot": {"bone": 0.5},
		"currency": 3
	},
	# --- Thornhollow Vale, levels 6-12 (out toward the barrow) ---
	&"stag_outrider":
	{
		"name": "Stag Outrider",
		"level": 7,
		"health": 130,
		"damage": 16,
		"speed": 3.8,
		"aggro": 11.0,
		"xp": 52,
		"tags": [&"soldier", &"stag", &"human"],
		"color": Color(0.3, 0.45, 0.32),
		"scale": 1.05,
		"loot": {"axe": 0.08, "chalice": 0.06},
		"currency": 5
	},
	&"sunburst_serjeant":
	{
		"name": "Sunburst Serjeant",
		"level": 8,
		"health": 155,
		"damage": 18,
		"speed": 3.4,
		"aggro": 11.0,
		"xp": 60,
		"tags": [&"soldier", &"sunburst", &"human"],
		"color": Color(0.28, 0.36, 0.6),
		"scale": 1.08,
		"loot": {"sword_big": 0.08, "chalice": 0.06},
		"currency": 6
	},
	&"grave_binder":
	{
		"name": "Grave-Binder",
		"level": 10,
		"health": 170,
		"damage": 21,
		"speed": 3.0,
		"aggro": 12.0,
		"xp": 78,
		"tags": [&"risen", &"caster", &"human"],
		"color": Color(0.4, 0.3, 0.48),
		"scale": 1.0,
		"loot": {"chalice": 0.15, "bone": 0.4},
		"currency": 8
	},
	&"barrow_wight":
	{
		"name": "Barrow Wight",
		"level": 12,
		"health": 210,
		"damage": 25,
		"speed": 3.2,
		"aggro": 12.0,
		"xp": 95,
		"tags": [&"risen", &"undead", &"barrow"],
		"color": Color(0.5, 0.52, 0.62),
		"scale": 1.12,
		"loot": {"chalice": 0.12, "sword_big": 0.06},
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
		"level": 11,
		"health": 190,
		"damage": 22,
		"speed": 3.0,
		"aggro": 11.0,
		"xp": 88,
		"tags": [&"risen", &"barrow"],
		"color": Color(0.46, 0.48, 0.56),
		"scale": 1.1,
		"loot": {"bone": 0.45},
		"currency": 9
	},
	&"captain_reyne":
	{
		"name": "Captain Reyne",
		"level": 12,
		"health": 620,
		"damage": 30,
		"speed": 3.4,
		"aggro": 14.0,
		"xp": 320,
		"tags": [&"bandit", &"human", &"boss"],
		"color": Color(0.55, 0.24, 0.2),
		"scale": 1.3,
		"loot": {"sword_big": 0.5, "chalice": 0.3},
		"currency": 45,
		"boss": true
	},
	&"the_first_king":
	{
		"name": "The First King",
		"level": 14,
		"health": 980,
		"damage": 38,
		"speed": 3.2,
		"aggro": 16.0,
		"xp": 620,
		"tags": [&"risen", &"barrow", &"boss"],
		"color": Color(0.72, 0.6, 0.28),
		"scale": 1.45,
		"loot": {"chalice": 0.8, "sword_big": 0.4},
		"currency": 90,
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
