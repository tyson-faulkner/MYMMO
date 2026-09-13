# NpcDatabase — everyone in the world who talks.
#
# The point of this existing at all: quests name their giver by id, and before
# this database there was nothing that could confirm the giver was a real person
# standing somewhere. A typo, or a quest written for an NPC nobody ever placed,
# would ship silently. The smoke test now walks every quest and fails if its
# giver or turn-in is not in here.
#
# Scenes place an NPC with a position and an id. Everything else — name, title,
# greeting, colour — comes from this table, exactly as enemies work.
extends Node

const DEFINITIONS := {
	# --- Thornhollow Vale ----------------------------------------------------
	&"npc_halvard":
	{
		"name": "Serjeant Halvard",
		"title": "Gate Serjeant",
		"zones": [&"thornhollow"],
		"color": Color(0.42, 0.45, 0.55),
		"greeting":
		"The valley's gone to pieces since the king died. Make yourself useful and I'll pretend I'm glad you came."
	},
	&"npc_maren":
	{
		"name": "Maren Holt",
		"title": "Quartermaster",
		"zones": [&"thornhollow"],
		"color": Color(0.62, 0.5, 0.36),
		"greeting": "I count what we have left twice a day, and it's never more than it was."
	},
	&"npc_ilsa":
	{
		"name": "Ilsa",
		"title": "Skald",
		# She follows you to the front, because somebody has to write it down
		# correctly and she does not trust anyone else to.
		"zones": [&"thornhollow", &"sablemarch", &"kingsmourn"],
		"color": Color(0.35, 0.55, 0.78),
		"greeting":
		"Histories decide claims, and claims decide thrones. So yes, what I write down matters rather a lot."
	},
	&"npc_bryn":
	{
		"name": "Bryn Aldercott",
		"title": "Innkeeper",
		"zones": [&"thornhollow"],
		"color": Color(0.7, 0.58, 0.42),
		"greeting": "Bed's four coppers, and the roof only leaks over the far corner. I'd take it."
	},
	&"npc_odda":
	{
		"name": "Odda Vane",
		"title": "Armourer",
		"zones": [&"thornhollow"],
		"color": Color(0.48, 0.4, 0.36),
		"greeting": "I shod horses before the war. Now I make spear points. Nobody asked me which I preferred.",
		"stock": ["gear_levy_head", "gear_levy_chest", "gear_levy_legs", "gear_levy_hands", "gear_levy_feet", "gear_levy_weapon_valkyr", "gear_levy_weapon_bard", "gear_levy_weapon_necromancer", "gear_levy_weapon_tinker", "mount_scrap_chopper"]
	},
	&"npc_selle":
	{
		"name": "Selle",
		"title": "Provisioner",
		"zones": [&"thornhollow"],
		"color": Color(0.66, 0.62, 0.48),
		"greeting": "Bread, rope, lamp oil. If you want anything finer you want a different valley.",
		"stock": ["chicken_leg", "bone"]
	},
	&"npc_aurey":
	{
		"name": "Captain Aurey",
		"title": "Guard Captain",
		"zones": [&"thornhollow"],
		"color": Color(0.5, 0.44, 0.5),
		"greeting": "Two houses want this road and neither one of them will say so out loud. Keep your head down."
	},
	# --- Sablemarch ----------------------------------------------------------
	&"npc_wrenn":
	{
		"name": "Sister Wrenn",
		"title": "Field Surgeon",
		"zones": [&"sablemarch"],
		"color": Color(0.78, 0.76, 0.7),
		"greeting":
		"I treat whoever is bleeding. Both houses allow it, because both houses expect to need me.",
		"stock": ["gear_marcher_head", "gear_marcher_hands", "gear_marcher_feet"]
	},
	&"npc_aske":
	{
		"name": "Lieutenant Aske",
		"title": "Of the White Stag",
		"zones": [&"sablemarch"],
		"color": Color(0.3, 0.46, 0.32),
		"greeting": "I have held this line for eleven months. I could not tell you what for."
	},
	&"npc_colm":
	{
		"name": "Serjeant-Major Colm",
		"title": "Of the Sunburst",
		"zones": [&"sablemarch"],
		"color": Color(0.28, 0.36, 0.6),
		"greeting": "Four hundred and eleven. Ask me what, and I will tell you, and you will wish you hadn't."
	},
	&"npc_ferryman":
	{
		"name": "The Ferryman",
		"title": "",
		"zones": [&"sablemarch"],
		"color": Color(0.4, 0.42, 0.44),
		"greeting": "Water's up again. It always is now. Nothing stays buried in a flooded field."
	},
	# --- Everywhere --------------------------------------------------------
	# One entity, placed at every graveyard, exactly as WoW does it. Talking to
	# her is the shortcut: instant resurrection for five minutes of Grave-Chill.
	# Walking to your own corpse instead costs nothing but the walk.
	&"npc_spirit_healer":
	{
		"name": "The Ferryman's Daughter",
		"title": "Spirit Healer",
		"zones": [&"thornhollow", &"sablemarch", &"kingsmourn"],
		"color": Color(0.66, 0.78, 0.86),
		"greeting":
		"I can send you back from here, and you will feel it for a while. Or you can walk to yourself. Most walk."
	},
	# --- Kingsmourn ------------------------------------------------------------
	&"npc_orrin":
	{
		"name": "Castellan Orrin",
		"title": "Keeper of the City",
		"zones": [&"kingsmourn"],
		"color": Color(0.5, 0.48, 0.42),
		"greeting": "I hold the city for a king who's dead and heirs who aren't. Make yourself useful."
	},
	&"npc_tarrant":
	{
		"name": "Envoy Tarrant",
		"title": "Of the White Stag",
		"zones": [&"kingsmourn"],
		"color": Color(0.24, 0.42, 0.28),
		"greeting": "Whatever the Sunburst told you, the reverse is true."
	},
	&"npc_vell":
	{
		"name": "Envoy Vell",
		"title": "Of the Sunburst",
		"zones": [&"kingsmourn"],
		"color": Color(0.22, 0.32, 0.6),
		"greeting": "Whatever the Stag told you, the reverse is true."
	},
	&"npc_pell":
	{
		"name": "Archivist Pell",
		"title": "Of the Hall of Records",
		"zones": [&"kingsmourn"],
		"color": Color(0.7, 0.62, 0.45),
		"greeting": "Everything that's ever been decided in this realm is on a shelf in there. That's why they're burning it."
	},
	&"npc_gudrun":
	{
		"name": "Gudrun",
		"title": "Foundrywright",
		"zones": [&"kingsmourn"],
		"color": Color(0.55, 0.35, 0.2),
		"greeting": "Sovereign steel, if you've the coin. The walker's not for sale to anyone who has to ask the price.",
		"stock": ["gear_sovereign_ring", "gear_sovereign_trinket", "gear_sovereign_cloak", "mount_foundry_walker"]
	}
}

var _cache: Dictionary = {}


func _ready() -> void:
	for npc_id in DEFINITIONS:
		_cache[npc_id] = _build(npc_id, DEFINITIONS[npc_id])


func get_npc(npc_id: StringName) -> NpcData:
	if _cache.is_empty():
		_ready()
	return _cache.get(npc_id, null)


func has_npc(npc_id: StringName) -> bool:
	return DEFINITIONS.has(npc_id)


func get_all_ids() -> Array:
	return DEFINITIONS.keys()


## Everyone who stands in a given zone.
func npcs_in_zone(zone: StringName) -> Array:
	var found: Array = []
	for npc_id in DEFINITIONS:
		var npc := get_npc(npc_id)
		if npc and npc.zones.has(zone):
			found.append(npc)
	return found


func _build(npc_id: StringName, entry: Dictionary) -> NpcData:
	var npc := NpcData.new()
	npc.id = npc_id
	npc.display_name = str(entry.get("name", "Villager"))
	npc.title = str(entry.get("title", ""))
	npc.greeting = str(entry.get("greeting", "Well met."))
	npc.body_color = entry.get("color", Color(0.72, 0.66, 0.55))
	var zones: Array[StringName] = []
	for zone in entry.get("zones", []):
		zones.append(StringName(zone))
	npc.zones = zones
	var stock: Array[StringName] = []
	for item_id in entry.get("stock", []):
		stock.append(StringName(item_id))
	npc.stock = stock
	return npc


## Everyone who sells something.
func vendors() -> Array:
	var found: Array = []
	for npc_id in DEFINITIONS:
		var npc := get_npc(npc_id)
		if npc and not npc.stock.is_empty():
			found.append(npc)
	return found
