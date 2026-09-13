class_name MainMenuUI
extends Control

signal host_pressed(nickname: String, class_id: String)
signal join_pressed(nickname: String, address: String, class_id: String)
signal quit_pressed

## The four classes, in party order: tank, healer, damage, damage. There are no
## races in Ironveil — this choice is your whole identity. There is no
## appearance picker either: that is cut from v1, and each class model carries
## its own painted textures.
const CLASS_OPTIONS: Array[String] = ["valkyr", "bard", "necromancer", "tinker"]
const SAFE_AREA_MARGIN := 24.0

@onready var nick_input: LineEdit = $MainContainer/MainMenu/Option1/NickInput
@onready var address_input: LineEdit = $MainContainer/MainMenu/Option3/AddressInput
@onready var main_container: VBoxContainer = $MainContainer
@onready var class_input: OptionButton = $MainContainer/MainMenu/OptionClass/ClassInput
@onready var class_blurb: Label = $MainContainer/MainMenu/ClassBlurb


func _ready() -> void:
	class_input.clear()
	for class_id in CLASS_OPTIONS:
		var data := _class_data(class_id)
		if data:
			class_input.add_item("%s  —  %s" % [data.display_name, data.role])
		else:
			class_input.add_item(class_id.capitalize())
	class_input.select(0)
	class_input.item_selected.connect(_on_class_selected)
	_on_class_selected(0)

	resized.connect(_update_responsive_layout)
	call_deferred("_update_responsive_layout")


func _on_host_pressed() -> void:
	host_pressed.emit(nick_input.text.strip_edges(), get_class_id())


func _on_join_pressed() -> void:
	join_pressed.emit(nick_input.text.strip_edges(), address_input.text.strip_edges(), get_class_id())


func _on_quit_pressed():
	quit_pressed.emit()


func show_menu():
	show()
	call_deferred("_update_responsive_layout")


func hide_menu():
	hide()


func is_menu_visible() -> bool:
	return visible


func _update_responsive_layout() -> void:
	if not main_container:
		return
	var available_size := Vector2(
		maxf(1.0, size.x - SAFE_AREA_MARGIN * 2.0), maxf(1.0, size.y - SAFE_AREA_MARGIN * 2.0)
	)
	var content_size := main_container.get_combined_minimum_size()
	if content_size.x <= 0.0 or content_size.y <= 0.0:
		return
	var scale_factor := minf(1.0, minf(available_size.x / content_size.x, available_size.y / content_size.y))
	main_container.pivot_offset = main_container.size * 0.5
	main_container.scale = Vector2.ONE * scale_factor


func get_class_id() -> String:
	var index := class_input.selected
	if index < 0 or index >= CLASS_OPTIONS.size():
		return CLASS_OPTIONS[0]
	return CLASS_OPTIONS[index]


func _on_class_selected(index: int) -> void:
	var data := _class_data(CLASS_OPTIONS[index] if index < CLASS_OPTIONS.size() else CLASS_OPTIONS[0])
	if data == null:
		class_blurb.text = ""
		return
	class_blurb.text = "%s\n\nResource: %s" % [data.description, data.resource_label]


func _class_data(class_id: String) -> ClassData:
	var path := "res://resources/classes/%s.tres" % class_id
	if not ResourceLoader.exists(path):
		return null
	return load(path) as ClassData
