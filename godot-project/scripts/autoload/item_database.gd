extends Node

# Everything that isn't gear or a mount. Gear lives in GearDatabase and mounts
# in MountDatabase; get_item() answers for all three so one lookup serves loot,
# pickup, inventory and tooltips alike.
#
# The template's demo hats and weapons (fedora, sombrero, sword, axe...) are
# gone: real class gear replaced them. The backpack stays until Ironveil has
# its own bag item, because it is what grants the four extra slots.

const BACKPACK_ICON: Texture2D = preload("res://assets/items/backpacks/icons/backpack.png")
const CHICKEN_LEG_ICON: Texture2D = preload("res://assets/items/misc/icons/chicken_leg.png")
const BONE_ICON: Texture2D = preload("res://assets/items/misc/icons/bone.png")
const CHALICE_ICON: Texture2D = preload("res://assets/items/misc/icons/chalice.png")

var items: Dictionary = {}


func _ready():
	_create_items()


func get_item(item_id: String) -> Item:
	var found: Item = items.get(item_id)
	if found:
		return found
	var gear := GearDatabase.get_item(StringName(item_id))
	if gear:
		return gear
	return MountDatabase.get_item(StringName(item_id))


func get_all_items() -> Dictionary:
	return items


func _create_items():
	_create_item(
		"backpack",
		"Backpack",
		"A sturdy backpack worn on the back.",
		Item.ItemType.BACKPACK,
		"res://scenes/items/backpacks/backpack.tscn",
		BACKPACK_ICON,
		true,
		60
	)
	_create_item(
		"chicken_leg",
		"Chicken Leg",
		"A cooked chicken leg.",
		Item.ItemType.MISC,
		"res://scenes/items/misc/chicken_leg.tscn",
		CHICKEN_LEG_ICON,
		false,
		5
	)
	_create_item(
		"bone",
		"Bone",
		"A weathered bone.",
		Item.ItemType.MISC,
		"res://scenes/items/misc/bone.tscn",
		BONE_ICON,
		false,
		2
	)
	_create_item(
		"chalice",
		"Chalice",
		"A decorative golden chalice.",
		Item.ItemType.MISC,
		"res://scenes/items/misc/chalice.tscn",
		CHALICE_ICON,
		false,
		35
	)
	# Chest consumables: run-changing, never a stat potion.
	_create_item(
		"marchers_draught",
		"Marcher's Draught",
		"Your next Grave-Chill does not take. Drunk for you, by the game, when it matters.",
		Item.ItemType.CONSUMABLE,
		"",
		CHICKEN_LEG_ICON,
		false,
		30
	)
	_create_item(
		"ferrymans_coin_lesser",
		"Ferryman's Coin, lesser",
		"One free ride: release, and wake at your body instead of the graveyard.",
		Item.ItemType.CONSUMABLE,
		"",
		CHALICE_ICON,
		false,
		30
	)
	_create_item(
		"widows_salt",
		"Widow's Salt",
		"Your next gravestone buff is doubled.",
		Item.ItemType.CONSUMABLE,
		"",
		BONE_ICON,
		false,
		30
	)


func _create_item(
	item_id: String,
	item_name: String,
	item_description: String,
	item_type: Item.ItemType,
	scene_path: String,
	item_icon: Texture2D,
	equipable: bool,
	item_value: int
) -> void:
	var item := Item.new()
	item.id = item_id
	item.name = item_name
	item.description = item_description
	item.item_type = item_type
	item.rarity = Item.ItemRarity.COMMON
	item.stackable = not equipable
	item.max_stack = 99 if item.stackable else 1
	item.value = item_value
	item.icon = item_icon
	item.scene_path = scene_path
	if equipable:
		item.context_options.append(Item.ContextOptions.EQUIP)
	item.context_options.append(Item.ContextOptions.DROP)
	items[item.id] = item
