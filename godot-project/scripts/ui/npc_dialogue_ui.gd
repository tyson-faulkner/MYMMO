# NpcDialogueUI — the panel that opens when you talk to someone.
#
# It is a view and nothing more. Every button it builds sends a request to the
# server and waits; it never changes a quest itself.
class_name NpcDialogueUI
extends CanvasLayer

signal closed

var _npc: NPC = null
var _player: Node3D = null
var _quest_log: QuestLog = null

@onready var _name_label: Label = $Panel/Margin/Layout/NameLabel
@onready var _body_label: RichTextLabel = $Panel/Margin/Layout/BodyText
@onready var _options: VBoxContainer = $Panel/Margin/Layout/Options
@onready var _close_button: Button = $Panel/Margin/Layout/CloseButton


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(close)


func is_open() -> bool:
	return visible


func open_for(npc: NPC, player: Node3D, quest_log: QuestLog) -> void:
	_npc = npc
	_player = player
	_quest_log = quest_log
	if _quest_log and not _quest_log.log_changed.is_connected(_rebuild):
		_quest_log.log_changed.connect(_rebuild)
	visible = true
	_rebuild()
	_update_mouse_mode()


func close() -> void:
	if _quest_log and _quest_log.log_changed.is_connected(_rebuild):
		_quest_log.log_changed.disconnect(_rebuild)
	visible = false
	_npc = null
	_player = null
	_quest_log = null
	_update_mouse_mode()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


func _rebuild() -> void:
	if _npc == null or _quest_log == null:
		return
	_name_label.text = _npc.display_name if _npc.title.is_empty() else "%s  —  %s" % [_npc.display_name, _npc.title]
	for child in _options.get_children():
		child.queue_free()

	var body_text := _npc.greeting
	var offered: Array = QuestDatabase.quests_offered_by(_npc.npc_id)

	for quest_id in offered:
		var quest: QuestData = QuestDatabase.get_quest(quest_id)
		if quest == null:
			continue
		if _quest_log.is_turned_in(quest_id):
			continue
		if _quest_log.is_active(quest_id):
			if _quest_log.is_complete(quest_id):
				body_text = quest.completion_text
				_add_option("Hand in: %s" % quest.title, _on_turn_in.bind(String(quest_id)), true)
			else:
				_add_progress_line(quest)
			continue
		if _quest_log.can_accept(quest_id):
			body_text = quest.offer_text
			_add_option("Accept: %s" % quest.title, _on_accept.bind(String(quest_id)), false)

	# Vendors: one line per thing they sell, priced in Sovereigns, greyed out
	# when you can't afford it.
	var data := NpcDatabase.get_npc(_npc.npc_id)
	if data and not data.stock.is_empty():
		for item_id in data.stock:
			var item: Item = ItemDatabase.get_item(String(item_id))
			if item == null:
				continue
			var affordable := _quest_log.currency >= item.value
			var label := "Buy %s — %d Sovereigns" % [item.name, item.value]
			if item.is_gear():
				label += "   (A%d P%d S%d)" % [item.armor, item.power, item.stamina]
			var button := Button.new()
			button.text = label
			button.custom_minimum_size = Vector2(0, 34)
			button.disabled = not affordable
			button.pressed.connect(_on_buy.bind(String(item_id)))
			_options.add_child(button)

	_body_label.text = body_text
	if _options.get_child_count() == 0:
		var nothing := Label.new()
		nothing.text = "Nothing for you right now."
		nothing.modulate = Color(0.75, 0.72, 0.66)
		_options.add_child(nothing)


func _add_progress_line(quest: QuestData) -> void:
	var progress: Array = _quest_log.progress_for(quest.id)
	var lines: Array[String] = []
	for index in range(quest.objective_count()):
		var have := int(progress[index]) if index < progress.size() else 0
		lines.append("   %s  %d / %d" % [quest.objective_text(index), have, quest.objective_required(index)])
	var label := Label.new()
	label.text = "%s (in progress)\n%s" % [quest.title, "\n".join(lines)]
	label.modulate = Color(0.82, 0.78, 0.68)
	_options.add_child(label)


func _add_option(text: String, handler: Callable, is_completion: bool) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 38)
	if is_completion:
		button.modulate = Color(1.0, 0.88, 0.45)
	button.pressed.connect(handler)
	_options.add_child(button)


func _on_accept(quest_id_text: String) -> void:
	if _npc == null:
		return
	if multiplayer.is_server():
		_npc.request_accept_quest(quest_id_text)
	else:
		_npc.request_accept_quest.rpc_id(1, quest_id_text)


func _on_turn_in(quest_id_text: String) -> void:
	if _npc == null:
		return
	if multiplayer.is_server():
		_npc.request_turn_in_quest(quest_id_text)
	else:
		_npc.request_turn_in_quest.rpc_id(1, quest_id_text)


func _on_buy(item_id_text: String) -> void:
	if _npc == null:
		return
	if multiplayer.is_server():
		_npc.request_buy(item_id_text)
	else:
		_npc.request_buy.rpc_id(1, item_id_text)


func _update_mouse_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED
