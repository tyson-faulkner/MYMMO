# CharacterSheetUI — the door to gear, runes, mounts and specs. Press C.
#
# Four systems were finished and reachable only from tests: gear could not be
# equipped, mounts could not be summoned, runes could not be chosen. This
# panel is the one place a player does all of it. It is a view: every button
# calls the owning request on the character (server-side directly on the
# host, by RPC on a client) and the server decides; the panel redraws from
# whatever comes back.
#
# Every actionable button carries a "door" meta ({"kind", "id"}) so the smoke
# test can press the real buttons and assert the real requests fire.
class_name CharacterSheetUI
extends CanvasLayer

signal closed

const TAB_NAMES := ["Gear", "Runes", "Mounts", "Spec"]
const REFRESH_SECONDS := 0.5
const GEAR_LABELS := {
	&"head": "Head", &"chest": "Chest", &"legs": "Legs", &"hands": "Hands", &"feet": "Feet",
	&"weapon": "Weapon", &"offhand": "Off-hand", &"ring1": "Ring", &"ring2": "Ring",
	&"trinket": "Trinket", &"cloak": "Cloak"
}

var _player: Node3D = null
var _panel: PanelContainer = null
var _tabs: TabContainer = null
var _pages: Array = []
var _accumulated: float = 0.0


func _ready() -> void:
	layer = 20
	_panel = PanelContainer.new()
	_panel.name = "Sheet"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -390
	_panel.offset_right = 390
	_panel.offset_top = -270
	_panel.offset_bottom = 270
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var title_row := HBoxContainer.new()
	column.add_child(title_row)
	var title := Label.new()
	title.text = "Character"
	title.modulate = Color(1, 0.85, 0.45)
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close_button := Button.new()
	close_button.text = "Close  (C)"
	close_button.pressed.connect(close)
	title_row.add_child(close_button)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.tab_changed.connect(func(_index: int) -> void: refresh())
	column.add_child(_tabs)
	for tab_name in TAB_NAMES:
		var scroll := ScrollContainer.new()
		scroll.name = tab_name
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 6)
		scroll.add_child(page)
		_tabs.add_child(scroll)
		_pages.append(page)
	visible = false
	set_process(true)


func is_open() -> bool:
	return visible


func tab_names() -> Array:
	return TAB_NAMES.duplicate()


func show_tab(index: int) -> void:
	_tabs.current_tab = clampi(index, 0, TAB_NAMES.size() - 1)
	refresh()


func open_for(player: Node3D) -> void:
	_player = player
	visible = true
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func toggle_for(player: Node3D) -> void:
	if visible:
		close()
	else:
		open_for(player)


func _process(delta: float) -> void:
	if not visible:
		return
	_accumulated += delta
	if _accumulated >= REFRESH_SECONDS:
		_accumulated = 0.0
		refresh()


## Redraw the open tab from the character's current state.
func refresh() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	match _tabs.current_tab:
		0:
			_rebuild_gear()
		1:
			_rebuild_runes()
		2:
			_rebuild_mounts()
		3:
			_rebuild_spec()


## The real button for a given action, for tests that want to press it.
func find_door(kind: String, id: Variant) -> Button:
	for page in _pages:
		for node in page.find_children("*", "Button", true, false):
			var door: Variant = node.get_meta("door", null)
			if door is Dictionary and str(door.get("kind", "")) == kind and str(door.get("id", "")) == str(id):
				return node as Button
	return null


func _clear(page: VBoxContainer) -> void:
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()


func _note(page: Control, text: String, colour: Color = Color(0.8, 0.78, 0.7)) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = colour
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(label)


func _door(kind: String, id: Variant, text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.set_meta("door", {"kind": kind, "id": id})
	button.pressed.connect(handler)
	return button


func _on_server() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func _class_id() -> StringName:
	var stats := _player.get_node_or_null("Stats") as Stats
	if stats and stats.class_data:
		return stats.class_data.id
	if _player.get("class_id") != null:
		return _player.class_id
	return &"valkyr"


# --- Gear: the eleven-slot paper doll and the bag ------------------------------


func _rebuild_gear() -> void:
	var page: VBoxContainer = _pages[0]
	_clear(page)
	if not _player.has_method("get_inventory") or _player.get_inventory() == null:
		_note(page, "This character has no bag.")
		return
	var inventory = _player.get_inventory()
	var class_id := _class_id()
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	page.add_child(columns)
	var worn := VBoxContainer.new()
	worn.custom_minimum_size = Vector2(330, 0)
	columns.add_child(worn)
	_note(worn, "Worn — click to take off", Color(1, 0.85, 0.45))
	var totals: Dictionary = inventory.gear_totals()
	_note(worn, "Armour %d · Power %d · Stamina %d" % [int(totals["armor"]), int(totals["power"]), int(totals["stamina"])])
	for key in PlayerInventory.GEAR_KEYS:
		var slot = inventory.get_gear_slot(key)
		var item: Item = ItemDatabase.get_item(slot.item_id) if slot and not slot.is_empty() else null
		var text := "%s:  %s" % [GEAR_LABELS.get(key, String(key)), item.name if item else "—"]
		if item:
			text += "   A%d P%d S%d" % [item.armor, item.power, item.stamina]
		var button := _door("unequip", key, text, unequip_worn.bind(key))
		button.disabled = item == null
		worn.add_child(button)

	var bag := VBoxContainer.new()
	bag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(bag)
	_note(bag, "Bag — click gear to wear it", Color(1, 0.85, 0.45))
	var shown := 0
	for index in range(inventory.get_active_slot_count()):
		var slot = inventory.get_slot(index)
		if slot == null or slot.is_empty():
			continue
		var item: Item = ItemDatabase.get_item(slot.item_id)
		if item == null:
			continue
		shown += 1
		if item.is_gear():
			var delta: Dictionary = inventory.compare_to_worn(item, class_id)
			var parts := []
			for stat in ["armor", "power", "stamina"]:
				var change := int(delta[stat])
				if change != 0:
					parts.append("%s%d %s" % ["+" if change > 0 else "−", absi(change), "armour" if stat == "armor" else stat])
			var wrong_class := item.class_restriction != &"" and item.class_restriction != class_id
			var verdict := "not for your class" if wrong_class else ("upgrade" if bool(delta["upgrade"]) else ("sidegrade" if parts.is_empty() else "not an upgrade"))
			var text := "%s%s   (%s)\n   %s%s" % [item.name, "  ▲" if bool(delta["upgrade"]) else "", Item.slot_name(item.gear_slot), ", ".join(parts) + (", " if not parts.is_empty() else ""), verdict]
			var button := _door("equip", index, text, equip_from_bag.bind(index))
			if bool(delta["upgrade"]):
				button.modulate = Color(0.7, 1.0, 0.75)
			button.disabled = wrong_class
			bag.add_child(button)
		elif item.item_type == Item.ItemType.MOUNT:
			bag.add_child(_door("learn_mount", index, "Learn mount: %s" % item.name, learn_mount_from_bag.bind(index)))
		else:
			_note(bag, "%s ×%d" % [item.name, slot.quantity])
	if shown == 0:
		_note(bag, "Empty.")


## The door to Player.request_equip_gear.
func equip_from_bag(index: int) -> void:
	if _player == null or not _player.has_method("request_equip_gear"):
		return
	if _on_server():
		_player.request_equip_gear(index)
	else:
		_player.request_equip_gear.rpc_id(1, index)
	_accumulated = REFRESH_SECONDS


## The door to Player.request_unequip_gear.
func unequip_worn(key: StringName) -> void:
	if _player == null or not _player.has_method("request_unequip_gear"):
		return
	if _on_server():
		_player.request_unequip_gear(String(key), -1)
	else:
		_player.request_unequip_gear.rpc_id(1, String(key), -1)
	_accumulated = REFRESH_SECONDS


## The door to Player.request_learn_mount.
func learn_mount_from_bag(index: int) -> void:
	if _player == null or not _player.has_method("request_learn_mount"):
		return
	if _on_server():
		_player.request_learn_mount(index)
	else:
		_player.request_learn_mount.rpc_id(1, index)
	_accumulated = REFRESH_SECONDS


# --- Runes: three slots, two choices each ----------------------------------------


func _rebuild_runes() -> void:
	var page: VBoxContainer = _pages[1]
	_clear(page)
	var runes := _player.get_node_or_null("RuneLoadout") as RuneLoadout
	if runes == null:
		_note(page, "No rune slots.")
		return
	var class_id := _class_id()
	var refusal := runes.swap_refusal()
	_note(page, "Three slots, two runes each. Swap for free out of combat, at an inn or a graveyard. A rune that grants a move puts it on bar slots 10–12.")
	if not refusal.is_empty():
		_note(page, "Locked right now: %s" % refusal, Color(1, 0.6, 0.55))
	for slot in range(1, RuneLoadout.SLOT_COUNT + 1):
		var unlocked := runes.slot_unlocked(slot)
		var current := runes.rune_in_slot(slot)
		var header := Label.new()
		header.text = "Slot %d — %s" % [slot, ("wearing %s" % current.display_name) if current else ("empty" if unlocked else "unlocks at level %d" % RuneDatabase.level_for_slot(slot))]
		header.modulate = Color(1, 0.85, 0.45)
		page.add_child(header)
		for rune in RuneDatabase.options_for(class_id, slot):
			var text := "%s%s\n   %s" % [rune.display_name, "   (worn)" if current and current.id == rune.id else "", rune.description]
			var button := _door("rune", rune.id, text, choose_rune.bind(slot, rune.id))
			button.disabled = not unlocked or not refusal.is_empty() or (current != null and current.id == rune.id)
			page.add_child(button)
		if current:
			var clear_button := _door("rune_clear", slot, "Take the rune out of slot %d" % slot, choose_rune.bind(slot, &""))
			clear_button.disabled = not refusal.is_empty()
			page.add_child(clear_button)


## The door to RuneLoadout.request_choose.
func choose_rune(slot: int, rune_id: StringName) -> void:
	var runes := _player.get_node_or_null("RuneLoadout") as RuneLoadout if _player else null
	if runes == null:
		return
	if _on_server():
		runes.request_choose(slot, String(rune_id))
	else:
		runes.request_choose.rpc_id(1, slot, String(rune_id))
	_accumulated = REFRESH_SECONDS


# --- Mounts: what you have learned, and why you cannot ride it right now -----------


func _rebuild_mounts() -> void:
	var page: VBoxContainer = _pages[2]
	_clear(page)
	var mounts := _player.get_node_or_null("MountController") as MountController
	if mounts == null:
		_note(page, "No mounts.")
		return
	var ids := mounts.learned.keys()
	ids.sort()
	if ids.is_empty():
		_note(page, "No mounts learned yet. They drop from bosses, sell at vendors, and one comes from a quest. Using the item learns it for good.")
		return
	for mount_id in ids:
		var riding: bool = mounts.current == mount_id
		var reason := mounts.refusal_reason(mount_id)
		var text := "%s   ×%.1f speed · level %d%s" % [MountDatabase.display_name(mount_id), MountDatabase.speed_of(mount_id), MountDatabase.required_level(mount_id), "   — riding. Click to dismiss." if riding else ""]
		var button := _door("mount", mount_id, text, summon_mount.bind(mount_id))
		button.disabled = not riding and not reason.is_empty()
		page.add_child(button)
		if not reason.is_empty() and not riding:
			_note(page, "   %s" % reason, Color(1, 0.6, 0.55))


## The door to MountController.request_mount (which dismisses when riding).
func summon_mount(mount_id: StringName) -> void:
	var mounts := _player.get_node_or_null("MountController") as MountController if _player else null
	if mounts == null:
		return
	mounts.request_mount(mount_id)
	_accumulated = REFRESH_SECONDS


# --- Spec ----------------------------------------------------------------------------


func _rebuild_spec() -> void:
	var page: VBoxContainer = _pages[3]
	_clear(page)
	var stats := _player.get_node_or_null("Stats") as Stats
	if stats == null or stats.class_data == null:
		_note(page, "No class yet.")
		return
	if stats.level < SpecDatabase.CHOOSE_LEVEL:
		_note(page, "Specs open at level %d. You are level %d." % [SpecDatabase.CHOOSE_LEVEL, stats.level])
	_note(page, "Two specs per class. Free to change at an inn or a graveyard. Your spec's abilities sit on the bar; the other spec's do not.")
	for spec_id in SpecDatabase.specs_for(stats.class_data.id):
		var spec := SpecDatabase.get_spec(spec_id)
		var worn: bool = stats.spec_id == spec_id
		var button := _door("spec", spec_id, "%s  —  %s%s\n   %s\n   %s" % [spec.get("name", ""), spec.get("role", ""), "   (yours)" if worn else "", spec.get("text", ""), spec.get("passive", "")], choose_spec.bind(spec_id))
		button.disabled = worn or stats.level < SpecDatabase.CHOOSE_LEVEL
		page.add_child(button)


## The door to Stats.request_choose_spec.
func choose_spec(spec_id: StringName) -> void:
	var stats := _player.get_node_or_null("Stats") as Stats if _player else null
	if stats == null:
		return
	if _on_server():
		stats.request_choose_spec(String(spec_id))
	else:
		stats.request_choose_spec.rpc_id(1, String(spec_id))
	_accumulated = REFRESH_SECONDS
