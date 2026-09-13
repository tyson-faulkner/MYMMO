class_name Item
extends Resource

enum ItemType { WEAPON, CONSUMABLE, TOOL, MISC, HAT, BACKPACK, GEAR, MOUNT }

## The eleven equipment slots. Two rings, so RING is the kind and the inventory
## keeps two of them.
enum GearSlot { NONE, HEAD, CHEST, LEGS, HANDS, FEET, WEAPON, OFFHAND, RING, TRINKET, CLOAK }

## Who owns the slot — the design doc's core gear rule. World slots are NEVER
## placed in dungeon or raid loot, so questing gear can't be outscaled: there is
## nothing to outscale it with.
enum GearSource { WORLD, DUNGEON, VENDOR }

## Three tiers across levels 1-20: starter, mid, cap.
enum GearTier { NONE, STARTER, MID, CAP }

enum ItemRarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

enum ContextOptions {
	DROP,
	EQUIP,
	UNEQUIP,
}

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var icon: Texture2D

@export var stackable: bool = true
@export var max_stack: int = 99

@export var item_type: ItemType = ItemType.MISC
@export var rarity: ItemRarity = ItemRarity.COMMON
@export var value: int = 0
@export var context_options: Array[Item.ContextOptions] = []

@export var scene_path: String = ""

# --- Gear ---------------------------------------------------------------------
# Three stats only. Armour takes a flat amount off every hit. Power adds a flat
# amount to every ability and swing. Stamina is 5 health a point. Simple to
# read on a tooltip, simple to compare two items, and enough to make a drop
# matter.

@export var gear_slot: GearSlot = GearSlot.NONE
@export var gear_tier: GearTier = GearTier.NONE
@export var gear_source: GearSource = GearSource.WORLD
@export var armor: int = 0
@export var power: int = 0
@export var stamina: int = 0
@export var required_level: int = 1

## Weapons are the one class-restricted thing, purely for silhouette: a Valkyr
## holding a staff breaks the art rule. Armour fits everyone — one body.
## Empty means anyone.
@export var class_restriction: StringName = &""

## A named special effect, for the handful of uniques. Looked up by the systems
## that care; an item with none is just its numbers.
@export var unique_effect: StringName = &""

## Set on mount items. Using one learns the mount for good and consumes the
## item; after that it is summoned from the mount list, not from the bag.
@export var mount_id: StringName = &""


func is_gear() -> bool:
	return gear_slot != GearSlot.NONE


static func slot_name(slot: GearSlot) -> String:
	match slot:
		GearSlot.HEAD: return "Head"
		GearSlot.CHEST: return "Chest"
		GearSlot.LEGS: return "Legs"
		GearSlot.HANDS: return "Hands"
		GearSlot.FEET: return "Feet"
		GearSlot.WEAPON: return "Weapon"
		GearSlot.OFFHAND: return "Off-hand"
		GearSlot.RING: return "Ring"
		GearSlot.TRINKET: return "Trinket"
		GearSlot.CLOAK: return "Cloak"
		_: return ""


## Which slots the open world owns, and which dungeons do. Enforced by a test.
static func slot_is_world_owned(slot: GearSlot) -> bool:
	return slot == GearSlot.RING or slot == GearSlot.TRINKET or slot == GearSlot.CLOAK
