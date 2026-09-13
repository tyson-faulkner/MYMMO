# Chest — never contains something you'd shrug at.
#
# docs/ironveil-qol-spec.md section 8. Three kinds:
#   COMMON  a few per zone, 30 minutes: Sovereigns and one run-changing
#           consumable. Never a stat potion.
#   RARE    one per zone, two hours, announced in chat; it moves between a
#           few spots so people actually look. Gear for the slot your
#           character is weakest in, or a title.
#   SEASON  one, at the end of the raid, once per season: the season's title.
# Once per character per respawn, so nobody farms them. The chest itself
# stays for everyone else.
class_name Chest
extends Interactable

enum Tier { COMMON, RARE, SEASON }

const CONSUMABLES := ["marchers_draught", "ferrymans_coin_lesser", "widows_salt"]
const TITLES := ["the Unshrugging", "of the Long Road", "Who Looked", "Marcher"]
const RARE_GEAR_CHANCE := 0.7

@export var tier: Tier = Tier.COMMON
@export var respawn_minutes: float = 30.0
## World spots a RARE chest moves between when it respawns.
@export var rare_spots: Array[Vector3] = []
## For the announcement: "something glints in the Greymarch flood".
@export var glint_text: String = "something glints in the vale"

## peer -> msec when they opened it
var _opened: Dictionary = {}
var _respawn_at_msec: int = 0
var opened_locally: bool = false


func _ready() -> void:
	match tier:
		Tier.COMMON:
			display_name = "Chest"
		Tier.RARE:
			display_name = "Glinting Chest"
			respawn_minutes = maxf(respawn_minutes, 120.0)
		Tier.SEASON:
			display_name = "Season Chest"
	prompt = "Open"
	action = "open"
	channel_seconds = 1.0
	cooldown_seconds = 0.0
	use_range = 4.0
	super()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 0.6, 0.6)
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.86, 0.68, 0.24) if tier != Tier.COMMON else Color(0.52, 0.36, 0.2)
	mesh.material_override = material
	mesh.position = Vector3(0, 0.3, 0)
	add_child(mesh)
	if _label:
		_label.position = Vector3(0, 1.3, 0)
	_respawn_at_msec = Time.get_ticks_msec() + int(respawn_minutes * 60000.0)


func _physics_process(delta: float) -> void:
	super(delta)
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	if tier == Tier.RARE and Time.get_ticks_msec() >= _respawn_at_msec:
		relocate_now()


## Server. A rare chest respawns somewhere else and says so.
func relocate_now() -> void:
	_respawn_at_msec = Time.get_ticks_msec() + int(respawn_minutes * 60000.0)
	_opened.clear()
	if rare_spots.is_empty():
		return
	var spot: Vector3 = rare_spots.pick_random()
	relocate(spot)
	relocate.rpc(spot)
	announce(glint_text)
	announce.rpc(glint_text)


@rpc("authority", "reliable")
func relocate(spot: Vector3) -> void:
	global_position = spot
	opened_locally = false


@rpc("authority", "reliable")
func announce(text: String) -> void:
	var scene := get_tree().get_current_scene()
	if scene == null:
		return
	for hud in scene.find_children("*", "GameHUD", true, false):
		if hud.has_method("_show_toast"):
			hud._show_toast(text.capitalize() if text.length() < 3 else text[0].to_upper() + text.substr(1))


func can_open(peer_id: int) -> bool:
	if not _opened.has(peer_id):
		return true
	return Time.get_ticks_msec() - int(_opened[peer_id]) >= int(respawn_minutes * 60000.0)


## Server. Hands over the contents, once per character per respawn.
func perform(player: Node3D) -> void:
	if not multiplayer.is_server() or player == null:
		return
	var peer_id := int(str(player.name)) if str(player.name).is_valid_int() else 0
	if not can_open(peer_id):
		return
	var quest_log := player.get_node_or_null("QuestLog") as QuestLog
	var book := player.get_node_or_null("RecordBook") as RecordBook
	match tier:
		Tier.COMMON:
			if quest_log:
				quest_log.add_currency(randi_range(15, 40))
			_give_item(player, CONSUMABLES.pick_random())
		Tier.RARE:
			var gear_id := &""
			if player.has_method("get_inventory"):
				var stats := player.get_node_or_null("Stats") as Stats
				var class_id: StringName = stats.class_data.id if stats and stats.class_data else &"valkyr"
				gear_id = GearDatabase.upgrade_for(player.get_inventory(), class_id)
			if gear_id != &"" and randf() < RARE_GEAR_CHANCE:
				_give_item(player, String(gear_id))
			elif book:
				book.add_title(TITLES.pick_random())
			elif quest_log:
				quest_log.add_currency(120)
		Tier.SEASON:
			var season := String(SeasonDatabase.current_id())
			if book == null or book.season_chest == season:
				return
			book.season_chest = season
			book.add_title(str(SeasonDatabase.rewards().get("title", "of the Season")))
	_opened[peer_id] = Time.get_ticks_msec()
	if peer_id == 1:
		mark_opened()
	elif peer_id > 0:
		mark_opened.rpc_id(peer_id)


func _give_item(player: Node3D, item_id: String) -> void:
	if item_id.is_empty() or not player.has_method("request_add_item"):
		return
	player.request_add_item(item_id, 1)


@rpc("authority", "reliable")
func mark_opened() -> void:
	opened_locally = true


func _process(_delta: float) -> void:
	if _label == null:
		return
	if _channel_started_msec > 0 and _channel_seconds_shown > 0.0:
		var progress := clampf(float(Time.get_ticks_msec() - _channel_started_msec) / (_channel_seconds_shown * 1000.0), 0.0, 1.0)
		var filled := int(round(progress * 10.0))
		_label.text = "%s\n%s%s" % [display_name, "▮".repeat(filled), "▯".repeat(10 - filled)]
		return
	if opened_locally:
		_label.text = "%s\n(opened)" % display_name
		return
	var local_player := _get_local_player()
	if local_player and is_player_in_range(local_player) and _is_nearest_to(local_player):
		_label.text = "%s\n[F] %s" % [display_name, prompt]
	else:
		_label.text = display_name
