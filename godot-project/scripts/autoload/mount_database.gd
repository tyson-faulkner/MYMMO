# MountDatabase — every mount in the game, as data.
#
# A mount costs almost nothing mechanically (a model, a ride animation, a speed
# buff) and is one of the most motivating rewards in the genre, which is why
# there are ten of them rather than the three the design doc originally planned.
# Full art brief and build order: docs/ironveil-mount-spec.md.
#
# The economics behind the ten: seven share one quadruped rig — one skeleton,
# one run cycle, seven skins — and three are machines, which need no rig at all.
# So the real art bill is one rig, seven variants, three props.
#
# A mount reaches a player as an item in the bag. Using it learns the mount for
# good and consumes the item; after that it is summoned from the mount list, not
# from the bag. ItemDatabase asks this table for those items, exactly as it asks
# GearDatabase for gear.
extends Node

## Riding is 1.6x running, per the mount spec. Individual mounts vary a little
## so the later ones feel like an upgrade rather than a reskin.
const BASE_SPEED := 1.6

const DEFINITIONS := {
	&"mount_scrap_chopper":
	{
		"name": "Scrap Chopper",
		"description": "A tinker's machine, bought rather than earned. The first thing most riders own.",
		"speed": 1.5,
		"source": "Odda Vane, Thornfell — for Sovereigns",
		"required_level": 10,
		"value": 900,
		"color": Color(0.62, 0.38, 0.18),
		"machine": true
	},
	&"mount_veil_saber":
	{
		"name": "Veil Saber",
		"description": "Skull-faced, and lit from inside with the same green fire as the barrow.",
		"speed": 1.6,
		"source": "The First King — The Deepbarrow",
		"required_level": 10,
		"value": 0,
		"color": Color(0.45, 0.30, 0.58),
		"machine": false
	},
	&"mount_marcher_bear":
	{
		"name": "Marcher Bear",
		"description": "Carried supplies across the flood for a year. It is not afraid of the dead any more.",
		"speed": 1.6,
		"source": "Greymarch quest chain, final reward",
		"required_level": 14,
		"value": 0,
		"color": Color(0.42, 0.34, 0.26),
		"machine": false
	},
	&"mount_risen_brute":
	{
		"name": "Risen Brute",
		"description": "The water gave it back larger than it went in. Somebody put a saddle on it anyway.",
		"speed": 1.65,
		"source": "The Weight of Them — The Drowned Hold",
		"required_level": 14,
		"value": 0,
		"color": Color(0.34, 0.44, 0.42),
		"machine": false
	},
	&"mount_wraithcat":
	{
		"name": "Wraithcat",
		"description": "Barely there. The histories do not record where it came from, which is its own joke.",
		"speed": 1.7,
		"source": "The Bound Ledger — The Archive",
		"required_level": 18,
		"value": 0,
		"color": Color(0.56, 0.72, 0.80),
		"machine": false
	},
	&"mount_foundry_walker":
	{
		"name": "Foundry Walker",
		"description": "Six legs, one seat, and a price that makes armourers go quiet.",
		"speed": 1.7,
		"source": "Gudrun, Ironhold — very expensive",
		"required_level": 18,
		"value": 6000,
		"color": Color(0.44, 0.40, 0.36),
		"machine": true
	},
	&"mount_tombthrone":
	{
		"name": "Tombthrone",
		"description": "A seat carried by the dead, which is either a throne or a warning.",
		"speed": 1.7,
		"source": "Ironhold quest chain, final reward",
		"required_level": 19,
		"value": 0,
		"color": Color(0.58, 0.52, 0.34),
		"machine": false
	},
	&"mount_twin_furnace_hound":
	{
		"name": "Twin-Furnace Hound",
		"description": "Two furnaces, one temper.",
		"speed": 1.75,
		"source": "The Broken Throne — raid",
		"required_level": 20,
		"value": 0,
		"color": Color(0.72, 0.34, 0.18),
		"machine": false
	},
	&"mount_furnace_rhino":
	{
		"name": "Furnace Rhino",
		"description": "Armoured to the eyes and entirely uninterested in going around things.",
		"speed": 1.75,
		"source": "The Broken Throne — raid",
		"required_level": 20,
		"value": 0,
		"color": Color(0.50, 0.30, 0.24),
		"machine": false
	},
	&"mount_ironhide":
	{
		"name": "Ironhide",
		"description": "The biggest thing anyone rides, and the only one nobody can buy.",
		"speed": 1.8,
		"source": "The First King, Crowned — heroic raid only",
		"required_level": 20,
		"value": 0,
		"color": Color(0.66, 0.22, 0.18),
		"machine": false
	}
}

var _items: Dictionary = {}


func _ready() -> void:
	_generate()


func _generate() -> void:
	if not _items.is_empty():
		return
	for mount_id in DEFINITIONS:
		var entry: Dictionary = DEFINITIONS[mount_id]
		var item := Item.new()
		item.id = String(mount_id)
		item.name = str(entry["name"])
		item.description = str(entry["description"])
		item.item_type = Item.ItemType.MOUNT
		item.rarity = Item.ItemRarity.EPIC if not bool(entry.get("machine", false)) else Item.ItemRarity.RARE
		item.stackable = false
		item.max_stack = 1
		item.value = int(entry.get("value", 0))
		item.required_level = int(entry.get("required_level", 1))
		item.mount_id = mount_id
		_items[mount_id] = item


func get_item(item_id: StringName) -> Item:
	_generate()
	return _items.get(item_id, null)


func get_all_ids() -> Array:
	return DEFINITIONS.keys()


func has_mount(mount_id: StringName) -> bool:
	return DEFINITIONS.has(mount_id)


func display_name(mount_id: StringName) -> String:
	var entry: Dictionary = DEFINITIONS.get(mount_id, {})
	return str(entry.get("name", "Unknown Mount"))


## How much faster than running this mount is.
func speed_of(mount_id: StringName) -> float:
	var entry: Dictionary = DEFINITIONS.get(mount_id, {})
	return float(entry.get("speed", BASE_SPEED))


func required_level(mount_id: StringName) -> int:
	var entry: Dictionary = DEFINITIONS.get(mount_id, {})
	return int(entry.get("required_level", 1))


## Placeholder tint, the same trick mobs and NPCs use until real art lands.
func color_of(mount_id: StringName) -> Color:
	var entry: Dictionary = DEFINITIONS.get(mount_id, {})
	return entry.get("color", Color(0.6, 0.5, 0.4))


## The ones bought with Sovereigns rather than dropped. Vendors read this.
func purchasable() -> Array:
	var found: Array = []
	for mount_id in DEFINITIONS:
		if int(DEFINITIONS[mount_id].get("value", 0)) > 0:
			found.append(mount_id)
	return found
