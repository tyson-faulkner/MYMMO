class_name PlayerInventory
extends RefCounted

const BASE_INVENTORY_SIZE := 16
const BACKPACK_BONUS_SLOTS := 4
const MAX_INVENTORY_SIZE := BASE_INVENTORY_SIZE + BACKPACK_BONUS_SLOTS
var slots: Array[InventorySlot] = []
var equipped_weapon: InventorySlot = InventorySlot.new()
var equipped_hat: InventorySlot = InventorySlot.new()
var equipped_backpack: InventorySlot = InventorySlot.new()

## The eleven gear slots, keyed by name so two rings can coexist. The
## template's weapon/hat/backpack above stay as cosmetic attachments; real
## stats come from these.
const GEAR_KEYS: Array[StringName] = [
	&"head", &"chest", &"legs", &"hands", &"feet",
	&"weapon", &"offhand", &"ring1", &"ring2", &"trinket", &"cloak"
]
var gear: Dictionary = {}


func _init():
	_initialize_slots()


func _initialize_slots():
	slots.clear()
	for i in range(MAX_INVENTORY_SIZE):
		slots.append(InventorySlot.new())
	gear.clear()
	for key in GEAR_KEYS:
		gear[key] = InventorySlot.new()


# --- Gear -------------------------------------------------------------------


## Which gear key an item goes in. Rings take the first empty ring, or ring1.
static func gear_key_for(item: Item) -> StringName:
	match item.gear_slot:
		Item.GearSlot.HEAD: return &"head"
		Item.GearSlot.CHEST: return &"chest"
		Item.GearSlot.LEGS: return &"legs"
		Item.GearSlot.HANDS: return &"hands"
		Item.GearSlot.FEET: return &"feet"
		Item.GearSlot.WEAPON: return &"weapon"
		Item.GearSlot.OFFHAND: return &"offhand"
		Item.GearSlot.RING: return &"ring1"
		Item.GearSlot.TRINKET: return &"trinket"
		Item.GearSlot.CLOAK: return &"cloak"
		_: return &""


func get_gear_slot(key: StringName) -> InventorySlot:
	return gear.get(key, null)


## Move a piece of gear from the bag onto the body, swapping out whatever was
## there. `class_id` and `level` are checked so the server can refuse a Bard
## picking up a spear or a level 3 wearing cap gear.
func equip_gear_from_slot(index: int, class_id: StringName, level: int) -> bool:
	if not is_slot_active(index):
		return false
	var bag_slot: InventorySlot = get_slot(index)
	if bag_slot == null or bag_slot.is_empty():
		return false
	var item: Item = ItemDatabase.get_item(bag_slot.item_id)
	if item == null or not item.is_gear():
		return false
	if item.class_restriction != &"" and item.class_restriction != class_id:
		return false
	if level < item.required_level:
		return false

	var key := gear_key_for(item)
	if key == &"":
		return false
	# Rings: prefer an empty ring slot before swapping one out.
	if key == &"ring1" and not gear[&"ring1"].is_empty() and gear[&"ring2"].is_empty():
		key = &"ring2"

	var target: InventorySlot = gear[key]
	var incoming_id := bag_slot.item_id
	bag_slot.item_id = target.item_id
	bag_slot.quantity = target.quantity
	if bag_slot.item_id.is_empty():
		bag_slot.clear()
	target.item_id = incoming_id
	target.quantity = 1
	return true


func unequip_gear(key: StringName, destination_index: int = -1) -> bool:
	var source: InventorySlot = gear.get(key, null)
	if source == null or source.is_empty():
		return false
	if destination_index < 0:
		destination_index = get_first_empty_slot()
	if not is_slot_active(destination_index):
		return false
	var destination: InventorySlot = get_slot(destination_index)
	if destination == null or not destination.is_empty():
		return false
	destination.item_id = source.item_id
	destination.quantity = 1
	source.clear()
	return true


## The three numbers everything you're wearing adds up to.
## Returns {"armor": int, "power": int, "stamina": int, "effects": Array}.
func gear_totals() -> Dictionary:
	var totals := {"armor": 0, "power": 0, "stamina": 0, "effects": []}
	for key in GEAR_KEYS:
		var slot: InventorySlot = gear[key]
		if slot.is_empty():
			continue
		var item: Item = ItemDatabase.get_item(slot.item_id)
		if item == null or not item.is_gear():
			continue
		totals["armor"] += item.armor
		totals["power"] += item.power
		totals["stamina"] += item.stamina
		if item.unique_effect != &"":
			totals["effects"].append(item.unique_effect)
	return totals


func has_effect(effect: StringName) -> bool:
	return gear_totals()["effects"].has(effect)


## The green up-arrow: does this item beat what is worn in its slot, for
## this class? Rings compare against the worse of the two. Returns
## {"upgrade": bool, "armor": delta, "power": delta, "stamina": delta,
## "against": Item or null, "score": delta}.
func compare_to_worn(item: Item, class_id: StringName) -> Dictionary:
	var result := {"upgrade": false, "armor": 0, "power": 0, "stamina": 0, "against": null, "score": 0.0}
	if item == null or not item.is_gear():
		return result
	if item.class_restriction != &"" and item.class_restriction != class_id:
		return result
	var key := gear_key_for(item)
	if key == &"":
		return result
	var worn: Item = null
	if key == &"ring1":
		var first: Item = ItemDatabase.get_item(gear[&"ring1"].item_id) if not gear[&"ring1"].is_empty() else null
		var second: Item = ItemDatabase.get_item(gear[&"ring2"].item_id) if not gear[&"ring2"].is_empty() else null
		if first == null or second == null:
			worn = null
		else:
			worn = first if GearDatabase.score_for_class(first, class_id) <= GearDatabase.score_for_class(second, class_id) else second
	elif not gear[key].is_empty():
		worn = ItemDatabase.get_item(gear[key].item_id)
	result["against"] = worn
	result["armor"] = item.armor - (worn.armor if worn else 0)
	result["power"] = item.power - (worn.power if worn else 0)
	result["stamina"] = item.stamina - (worn.stamina if worn else 0)
	result["score"] = GearDatabase.score_for_class(item, class_id) - (GearDatabase.score_for_class(worn, class_id) if worn else 0.0)
	result["upgrade"] = float(result["score"]) > 0.01
	return result


## The worn slot with the least behind it, by tier budget. Empty slots count
## as nothing, so a bare ring finger is always the weakest.
func weakest_gear_key(_class_id: StringName) -> StringName:
	var weakest_key: StringName = &""
	var weakest_budget := 1_000_000
	for key in GEAR_KEYS:
		var slot: InventorySlot = gear[key]
		var budget := 0
		if not slot.is_empty():
			var item: Item = ItemDatabase.get_item(slot.item_id)
			if item and item.is_gear():
				budget = int(GearDatabase.TIER_BUDGET.get(item.gear_tier, 0))
		if budget < weakest_budget:
			weakest_budget = budget
			weakest_key = key
	return weakest_key


func get_active_slot_count() -> int:
	return MAX_INVENTORY_SIZE if not equipped_backpack.is_empty() else BASE_INVENTORY_SIZE


func is_slot_active(index: int) -> bool:
	return index >= 0 and index < get_active_slot_count()


func get_slot(index: int) -> InventorySlot:
	if index >= 0 and index < slots.size():
		return slots[index]
	return null


func get_equipped_slot(item_type: Item.ItemType) -> InventorySlot:
	match item_type:
		Item.ItemType.WEAPON:
			return equipped_weapon
		Item.ItemType.HAT:
			return equipped_hat
		Item.ItemType.BACKPACK:
			return equipped_backpack
		_:
			return null


func equip_from_slot(index: int, item_type: Item.ItemType) -> bool:
	if not is_slot_active(index):
		return false

	var backpack_slot: InventorySlot = get_slot(index)
	var equipped_slot: InventorySlot = get_equipped_slot(item_type)
	if not backpack_slot or backpack_slot.is_empty() or not equipped_slot:
		return false

	var item: Item = ItemDatabase.get_item(backpack_slot.item_id)
	if not item or item.item_type != item_type:
		return false

	var new_item_id: String = backpack_slot.item_id
	var new_quantity: int = backpack_slot.quantity
	backpack_slot.item_id = equipped_slot.item_id
	backpack_slot.quantity = equipped_slot.quantity
	equipped_slot.item_id = new_item_id
	equipped_slot.quantity = new_quantity
	if backpack_slot.is_empty():
		backpack_slot.clear()
	return true


func unequip_to_slot(item_type: Item.ItemType, destination_index: int = -1) -> bool:
	var equipped_slot: InventorySlot = get_equipped_slot(item_type)
	if not equipped_slot or equipped_slot.is_empty():
		return false
	if item_type == Item.ItemType.BACKPACK:
		return _unequip_backpack_to_slot(equipped_slot, destination_index)

	if destination_index < 0:
		destination_index = get_first_empty_slot()
	if not is_slot_active(destination_index):
		return false
	var destination: InventorySlot = get_slot(destination_index)
	if not destination or not destination.is_empty():
		return false

	destination.item_id = equipped_slot.item_id
	destination.quantity = equipped_slot.quantity
	equipped_slot.clear()
	return true


func _unequip_backpack_to_slot(equipped_slot: InventorySlot, destination_index: int) -> bool:
	if destination_index < 0:
		destination_index = _get_first_empty_base_slot()
	if destination_index < 0 or destination_index >= BASE_INVENTORY_SIZE:
		return false

	var destination := get_slot(destination_index)
	if not destination or not destination.is_empty():
		return false

	var occupied_bonus_slots: Array[int] = []
	for i in range(BASE_INVENTORY_SIZE, MAX_INVENTORY_SIZE):
		if not slots[i].is_empty():
			occupied_bonus_slots.append(i)

	var available_base_slots: Array[int] = []
	for i in range(BASE_INVENTORY_SIZE):
		if i != destination_index and slots[i].is_empty():
			available_base_slots.append(i)
	if occupied_bonus_slots.size() > available_base_slots.size():
		return false

	for i in range(occupied_bonus_slots.size()):
		var source := slots[occupied_bonus_slots[i]]
		var target := slots[available_base_slots[i]]
		target.item_id = source.item_id
		target.quantity = source.quantity
		source.clear()

	destination.item_id = equipped_slot.item_id
	destination.quantity = equipped_slot.quantity
	equipped_slot.clear()
	return true


func _get_first_empty_base_slot() -> int:
	for i in range(BASE_INVENTORY_SIZE):
		if slots[i].is_empty():
			return i
	return -1


func add_item(item: Item, quantity: int = 1) -> int:
	var remaining = quantity
	var active_slot_count := get_active_slot_count()

	if item.stackable:
		for i in range(active_slot_count):
			var slot := slots[i]
			if slot.item_id == item.id:
				remaining = slot.add_item(item, remaining)
				if remaining <= 0:
					break

	if remaining > 0:
		for i in range(active_slot_count):
			var slot := slots[i]
			if slot.is_empty():
				remaining = slot.add_item(item, remaining)
				if remaining <= 0:
					break

	return remaining


func remove_item(item_id: String, quantity: int = 1) -> int:
	var removed = 0
	for i in range(get_active_slot_count()):
		var slot := slots[i]
		if slot.item_id == item_id:
			var slot_removed = slot.remove_item(quantity - removed)
			removed += slot_removed
			if removed >= quantity:
				break
	return removed


func move_item(from_index: int, to_index: int, quantity: int = -1) -> bool:
	if (
		from_index == to_index
		or not is_slot_active(from_index)
		or not is_slot_active(to_index)
		or quantity == 0
		or quantity < -1
	):
		return false

	var from_slot = get_slot(from_index)
	var to_slot = get_slot(to_index)

	if not from_slot or not to_slot or from_slot.is_empty():
		return false

	var move_amount = from_slot.quantity if quantity == -1 else quantity
	move_amount = min(move_amount, from_slot.quantity)

	var item = ItemDatabase.get_item(from_slot.item_id)
	if not item:
		return false

	var remaining = to_slot.add_item(item, move_amount)
	var moved_amount = move_amount - remaining
	if moved_amount > 0:
		from_slot.remove_item(moved_amount)

	return moved_amount > 0


func swap_items(from_index: int, to_index: int) -> bool:
	if not is_slot_active(from_index) or not is_slot_active(to_index):
		return false

	var from_slot = get_slot(from_index)
	var to_slot = get_slot(to_index)

	if not from_slot or not to_slot:
		return false

	if from_slot.item_id == to_slot.item_id and not from_slot.is_empty() and not to_slot.is_empty():
		var item = ItemDatabase.get_item(from_slot.item_id)
		if item and item.stackable:
			var total_quantity = from_slot.quantity + to_slot.quantity
			if total_quantity <= item.max_stack:
				to_slot.quantity = total_quantity
				from_slot.clear()
				return true
			var space_available = item.max_stack - to_slot.quantity
			var amount_to_move = min(space_available, from_slot.quantity)
			to_slot.quantity += amount_to_move
			from_slot.quantity -= amount_to_move
			if from_slot.quantity <= 0:
				from_slot.clear()
			return true

	var temp_item_id = from_slot.item_id
	var temp_quantity = from_slot.quantity

	from_slot.item_id = to_slot.item_id
	from_slot.quantity = to_slot.quantity

	to_slot.item_id = temp_item_id
	to_slot.quantity = temp_quantity

	return true


func get_first_empty_slot() -> int:
	for i in range(get_active_slot_count()):
		if slots[i].is_empty():
			return i
	return -1


func to_dict() -> Dictionary:
	var data = []
	for slot in slots:
		data.append(slot.to_dict())
	var gear_data := {}
	for key in GEAR_KEYS:
		gear_data[String(key)] = gear[key].to_dict()
	return {
		"slots": data,
		"equipped_weapon": equipped_weapon.to_dict(),
		"equipped_hat": equipped_hat.to_dict(),
		"equipped_backpack": equipped_backpack.to_dict(),
		"gear": gear_data
	}


func from_dict(data: Dictionary) -> void:
	var slots_data = data.get("slots", [])
	for i in range(min(slots_data.size(), slots.size())):
		slots[i].from_dict(slots_data[i])
	for i in range(slots_data.size(), slots.size()):
		slots[i].clear()
	equipped_weapon.from_dict(data.get("equipped_weapon", {}))
	equipped_hat.from_dict(data.get("equipped_hat", {}))
	equipped_backpack.from_dict(data.get("equipped_backpack", {}))
	var gear_data: Dictionary = data.get("gear", {})
	for key in GEAR_KEYS:
		gear[key].from_dict(gear_data.get(String(key), {}))
