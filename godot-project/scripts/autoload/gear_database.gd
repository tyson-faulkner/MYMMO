# GearDatabase — every piece of equipment in the game.
#
# Most items are generated from a small table rather than hand-written, because
# eleven slots across three tiers is a lot of near-identical entries and the
# interesting decisions are all in the table: which slot leans on which stat,
# how much each tier is worth, and — the rule that actually matters — which
# slots the open world owns.
#
# THE RULE (from the design doc): rings, trinkets and cloaks come from questing
# and the world, and are NEVER in a dungeon or raid loot table. Armour and
# weapons come from dungeons and raids. World gear therefore cannot be
# outscaled, because there is nothing to outscale it with, and questing stays
# worth doing alongside dungeon runs. A test enforces this.
#
# Three stats: Armour (flat off every hit), Power (flat onto every hit and
# heal), Stamina (5 health each).
extends Node

const HEALTH_PER_STAMINA := 5

## What each tier is worth per item, before slot weighting.
const TIER_BUDGET := {
	Item.GearTier.STARTER: 6,
	Item.GearTier.MID: 14,
	Item.GearTier.CAP: 24
}

const TIER_LEVEL := {
	Item.GearTier.STARTER: 1,
	Item.GearTier.MID: 8,
	Item.GearTier.CAP: 14
}

const TIER_NAME := {
	Item.GearTier.STARTER: "Levy",
	Item.GearTier.MID: "Marcher",
	Item.GearTier.CAP: "Sovereign"
}

## Per-class stat weights (armour / power / stamina) that turn an item's
## three numbers into one score for YOUR class. Valkyr leans armour,
## Necromancer leans power. This is what the green up-arrow reads.
const CLASS_WEIGHTS := {
	&"valkyr": [1.0, 0.5, 0.7],
	&"bard": [0.4, 1.0, 0.6],
	&"necromancer": [0.3, 1.0, 0.5],
	&"tinker": [0.4, 1.0, 0.5]
}

## The next tier up, for the rare chest's "gear for your weakest slot".
const NEXT_TIER := {
	Item.GearTier.NONE: Item.GearTier.STARTER,
	Item.GearTier.STARTER: Item.GearTier.MID,
	Item.GearTier.MID: Item.GearTier.CAP
}

## How each slot splits its budget between Armour / Power / Stamina, and where
## it comes from. Chest and legs are where your health lives; the weapon is
## where your damage lives; rings and trinkets lean into power so a world drop
## can genuinely be the best thing you own.
const SLOTS := {
	Item.GearSlot.HEAD:    {"weights": [0.45, 0.20, 0.35], "source": Item.GearSource.DUNGEON, "name": "Helm"},
	Item.GearSlot.CHEST:   {"weights": [0.50, 0.10, 0.40], "source": Item.GearSource.DUNGEON, "name": "Hauberk"},
	Item.GearSlot.LEGS:    {"weights": [0.45, 0.15, 0.40], "source": Item.GearSource.DUNGEON, "name": "Greaves"},
	Item.GearSlot.HANDS:   {"weights": [0.30, 0.45, 0.25], "source": Item.GearSource.DUNGEON, "name": "Gauntlets"},
	Item.GearSlot.FEET:    {"weights": [0.35, 0.25, 0.40], "source": Item.GearSource.DUNGEON, "name": "Boots"},
	Item.GearSlot.OFFHAND: {"weights": [0.50, 0.25, 0.25], "source": Item.GearSource.DUNGEON, "name": "Ward"},
	Item.GearSlot.RING:    {"weights": [0.00, 0.70, 0.30], "source": Item.GearSource.WORLD,   "name": "Ring"},
	Item.GearSlot.TRINKET: {"weights": [0.10, 0.60, 0.30], "source": Item.GearSource.WORLD,   "name": "Charm"},
	Item.GearSlot.CLOAK:   {"weights": [0.30, 0.20, 0.50], "source": Item.GearSource.WORLD,   "name": "Cloak"}
}

## Weapons are the one class-restricted slot, for silhouette. One per class per
## tier. All power.
const WEAPONS := {
	&"valkyr":      {"name": "Spear",        "offhand": "Kite Shield"},
	&"bard":        {"name": "Blade",        "offhand": "Lute"},
	&"necromancer": {"name": "Staff",        "offhand": "Skull Focus"},
	&"tinker":      {"name": "Bolt Thrower", "offhand": "Toolkit"}
}

## The handful of hand-made items with a named effect. These are the flavour
## layer the design doc asked for on top of the stat sticks — a world ring that
## does something no raid item does.
const UNIQUES := {
	&"wolfsbane_ring":
	{
		"name": "Wolfsbane Ring",
		"slot": Item.GearSlot.RING,
		"tier": Item.GearTier.STARTER,
		"source": Item.GearSource.WORLD,
		"stats": [0, 3, 2],
		"effect": &"beast_slayer",
		"text": "Beasts take a fifth again as much from you."
	},
	&"halvards_cloak":
	{
		"name": "Halvard's Old Cloak",
		"slot": Item.GearSlot.CLOAK,
		"tier": Item.GearTier.STARTER,
		"source": Item.GearSource.WORLD,
		"stats": [2, 0, 5],
		"effect": &"",
		"text": "It has been to the barrow and back once already."
	},
	&"ferrymans_coin":
	{
		"name": "Ferryman's Coin",
		"slot": Item.GearSlot.TRINKET,
		"tier": Item.GearTier.MID,
		"source": Item.GearSource.WORLD,
		"stats": [0, 7, 5],
		"effect": &"short_grave_chill",
		"text": "Grave-Chill lasts half as long. He knows the way back."
	},
	&"seal_of_two_houses":
	{
		"name": "Seal of Two Houses",
		"slot": Item.GearSlot.RING,
		"tier": Item.GearTier.MID,
		"source": Item.GearSource.WORLD,
		"stats": [0, 9, 4],
		"effect": &"soldier_slayer",
		"text": "Soldiers of either house take a fifth again as much from you."
	},
	&"kings_signet":
	{
		"name": "The First King's Signet",
		"slot": Item.GearSlot.RING,
		"tier": Item.GearTier.CAP,
		"source": Item.GearSource.WORLD,
		"stats": [0, 16, 8],
		"effect": &"undead_slayer",
		"text": "The dead take a fifth again as much from you. They recognise it."
	}
}

var _items: Dictionary = {}


func _ready() -> void:
	_generate()


func get_item(item_id: StringName) -> Item:
	if _items.is_empty():
		_generate()
	return _items.get(item_id, null)


func has_item(item_id: StringName) -> bool:
	if _items.is_empty():
		_generate()
	return _items.has(item_id)


func get_all_ids() -> Array:
	if _items.is_empty():
		_generate()
	return _items.keys()


## Every item for a slot at a tier — the loot tables and vendors pull from this.
func items_for(slot: Item.GearSlot, tier: Item.GearTier) -> Array:
	var found: Array = []
	for item_id in get_all_ids():
		var item: Item = _items[item_id]
		if item.gear_slot == slot and item.gear_tier == tier:
			found.append(item)
	return found


## One number for an item, weighted for a class. Nothing worn scores zero.
static func score_for_class(item: Item, class_id: StringName) -> float:
	if item == null or not item.is_gear():
		return 0.0
	var weights: Array = CLASS_WEIGHTS.get(class_id, CLASS_WEIGHTS[&"valkyr"])
	return float(item.armor) * float(weights[0]) + float(item.power) * float(weights[1]) + float(item.stamina) * float(weights[2])


## The rare chest's pick: the next tier up for the slot this character is
## weakest in, class-specific where the slot is. "" when everything worn is
## already Sovereign.
static func upgrade_for(inventory, class_id: StringName) -> StringName:
	if inventory == null:
		return &""
	var weakest_key: StringName = inventory.weakest_gear_key(class_id)
	if weakest_key == &"":
		return &""
	var worn: InventorySlot = inventory.get_gear_slot(weakest_key)
	var worn_tier: Item.GearTier = Item.GearTier.NONE
	if worn and not worn.is_empty():
		var worn_item: Item = ItemDatabase.get_item(worn.item_id)
		if worn_item:
			worn_tier = worn_item.gear_tier
	if not NEXT_TIER.has(worn_tier):
		return &""
	var slot := _slot_for_key(weakest_key)
	var class_bound := slot == Item.GearSlot.WEAPON or slot == Item.GearSlot.OFFHAND
	return generated_id(NEXT_TIER[worn_tier], slot, class_id if class_bound else &"")


static func _slot_for_key(key: StringName) -> Item.GearSlot:
	match key:
		&"head": return Item.GearSlot.HEAD
		&"chest": return Item.GearSlot.CHEST
		&"legs": return Item.GearSlot.LEGS
		&"hands": return Item.GearSlot.HANDS
		&"feet": return Item.GearSlot.FEET
		&"weapon": return Item.GearSlot.WEAPON
		&"offhand": return Item.GearSlot.OFFHAND
		&"ring1", &"ring2": return Item.GearSlot.RING
		&"trinket": return Item.GearSlot.TRINKET
		&"cloak": return Item.GearSlot.CLOAK
	return Item.GearSlot.NONE


## Generated id, so loot tables and quests can name items predictably:
##   gear_starter_chest, gear_mid_ring, gear_cap_weapon_valkyr
static func generated_id(tier: Item.GearTier, slot: Item.GearSlot, class_id: StringName = &"") -> StringName:
	var tier_key := str(TIER_NAME.get(tier, "x")).to_lower()
	var slot_key := Item.slot_name(slot).to_lower().replace("-", "")
	if class_id != &"":
		return StringName("gear_%s_%s_%s" % [tier_key, slot_key, class_id])
	return StringName("gear_%s_%s" % [tier_key, slot_key])


func _generate() -> void:
	_items.clear()
	for tier in [Item.GearTier.STARTER, Item.GearTier.MID, Item.GearTier.CAP]:
		var budget: int = TIER_BUDGET[tier]
		for slot in SLOTS:
			var spec: Dictionary = SLOTS[slot]
			if slot == Item.GearSlot.OFFHAND:
				continue  # class-specific, below
			var weights: Array = spec["weights"]
			_add(
				generated_id(tier, slot),
				"%s %s" % [TIER_NAME[tier], spec["name"]],
				slot, tier, spec["source"],
				_split(budget, weights),
				&"", &"", ""
			)
		# Weapons and off-hands, one per class.
		for class_id in WEAPONS:
			var w: Dictionary = WEAPONS[class_id]
			_add(
				generated_id(tier, Item.GearSlot.WEAPON, class_id),
				"%s %s" % [TIER_NAME[tier], w["name"]],
				Item.GearSlot.WEAPON, tier, Item.GearSource.DUNGEON,
				[0, budget, 0],
				class_id, &"", ""
			)
			_add(
				generated_id(tier, Item.GearSlot.OFFHAND, class_id),
				"%s %s" % [TIER_NAME[tier], w["offhand"]],
				Item.GearSlot.OFFHAND, tier, Item.GearSource.DUNGEON,
				_split(budget, SLOTS[Item.GearSlot.OFFHAND]["weights"]),
				class_id, &"", ""
			)
	for unique_id in UNIQUES:
		var u: Dictionary = UNIQUES[unique_id]
		var stats: Array = u["stats"]
		_add(unique_id, u["name"], u["slot"], u["tier"], u["source"], stats, &"", u["effect"], u["text"])


func _split(budget: int, weights: Array) -> Array:
	return [
		int(round(float(budget) * float(weights[0]))),
		int(round(float(budget) * float(weights[1]))),
		int(round(float(budget) * float(weights[2])))
	]


func _add(
	item_id: StringName, display_name: String, slot: Item.GearSlot, tier: Item.GearTier,
	source: Item.GearSource, stats: Array, class_id: StringName, effect: StringName, text: String
) -> void:
	var item := Item.new()
	item.id = String(item_id)
	item.name = display_name
	item.item_type = Item.ItemType.GEAR
	item.gear_slot = slot
	item.gear_tier = tier
	item.gear_source = source
	item.armor = int(stats[0])
	item.power = int(stats[1])
	item.stamina = int(stats[2])
	item.required_level = int(TIER_LEVEL[tier])
	item.class_restriction = class_id
	item.unique_effect = effect
	item.stackable = false
	item.max_stack = 1
	item.rarity = Item.ItemRarity.RARE if effect != &"" else (
		Item.ItemRarity.UNCOMMON if tier != Item.GearTier.STARTER else Item.ItemRarity.COMMON
	)
	item.value = 4 * int(TIER_BUDGET[tier])
	item.context_options = [Item.ContextOptions.EQUIP, Item.ContextOptions.DROP]
	item.description = text if not text.is_empty() else "%s   Armour %d  Power %d  Stamina %d" % [
		Item.slot_name(slot), item.armor, item.power, item.stamina
	]
	_items[item_id] = item
