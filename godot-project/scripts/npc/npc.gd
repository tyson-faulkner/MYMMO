# NPC — someone you can walk up to and talk to.
#
# NPCs hand out quests and take them back. Which quests is not stored here: it
# comes from QuestDatabase, matched on this NPC's id. So writing a new quest and
# hooking it to a character is one data entry, not a scene edit.
#
# Accepting and handing in are server decisions. The client presses a button;
# the server checks the player is genuinely standing here, genuinely eligible,
# and only then changes anything.
class_name NPC
extends StaticBody3D

## How far away the player can be and still be "talking to" this NPC. Checked
## again on the server so a client can't hand in a quest from another zone.
const INTERACT_RANGE := 4.5

@export var npc_id: StringName = &"npc_unnamed"
@export var display_name: String = "Villager"

## Shown under the name: "Gate Serjeant", "Skald", "Innkeeper".
@export var title: String = ""

@export_multiline var greeting: String = "Well met."

## Tint for the placeholder body. Real character art swaps into Body/Mesh later.
@export var body_color: Color = Color(0.72, 0.66, 0.55)

var _players_in_range: Dictionary = {}

@onready var _name_label: Label3D = $NameLabel
@onready var _quest_marker: Label3D = $QuestMarker
@onready var _interact_area: Area3D = $InteractArea


func _ready() -> void:
	_apply_definition()
	_name_label.text = _base_name_text()
	var mesh := get_node_or_null("Body/Mesh") as MeshInstance3D
	if mesh and mesh.get_surface_override_material(0) == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = body_color
		mesh.set_surface_override_material(0, material)
	_interact_area.body_entered.connect(_on_body_entered)
	_interact_area.body_exited.connect(_on_body_exited)
	_quest_marker.visible = false
	add_to_group("NPCs")
	set_process(true)


func _process(_delta: float) -> void:
	# The marker above the head is a local, cosmetic thing: it reflects what the
	# player looking at the screen can do right now.
	var local_player := _get_local_player()
	if local_player == null:
		_quest_marker.visible = false
		return
	_name_label.text = _base_name_text()
	if is_player_in_range(local_player) and _is_nearest_npc_to(local_player):
		_name_label.text += "\n[F] Talk"
	var quest_log := local_player.get_node_or_null("QuestLog") as QuestLog
	if quest_log == null:
		_quest_marker.visible = false
		return
	var marker := ""
	for quest_id in QuestDatabase.quests_offered_by(npc_id):
		if quest_log.is_active(quest_id) and quest_log.is_complete(quest_id):
			marker = "?"
			break
		if quest_log.can_accept(quest_id):
			marker = "!"
	_quest_marker.text = marker
	_quest_marker.visible = marker != ""


# The database is the source of truth, exactly as it is for enemies. A scene
# places an NPC with a position and an id; name, title, greeting and colour all
# come from NpcDatabase. That way a quest giver cannot quietly disagree with
# itself depending on which zone you met them in.
func _apply_definition() -> void:
	var data := NpcDatabase.get_npc(npc_id)
	if data == null:
		push_warning("NPC '%s' is not in NpcDatabase - falling back to scene values." % npc_id)
		return
	display_name = data.display_name
	title = data.title
	greeting = data.greeting
	body_color = data.body_color


func _base_name_text() -> String:
	return display_name if title.is_empty() else "%s\n<%s>" % [display_name, title]


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("Players") and body.get("nickname") == null:
		# Anything with a nickname is a player character in this template.
		return
	_players_in_range[body] = true


func _on_body_exited(body: Node3D) -> void:
	_players_in_range.erase(body)


func is_player_in_range(player: Node3D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	return global_position.distance_to(player.global_position) <= INTERACT_RANGE


## Called by the local player pressing the interact key.
func begin_conversation(player: Node3D) -> void:
	if not is_player_in_range(player):
		return
	var quest_log := player.get_node_or_null("QuestLog") as QuestLog
	if quest_log == null:
		return
	var dialogue := _find_dialogue_ui()
	if dialogue:
		dialogue.open_for(self, player, quest_log)
	# Talking is itself a quest objective sometimes, and the server has to be
	# the one to say it happened.
	if multiplayer.is_server():
		request_talk()
	else:
		request_talk.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func request_talk() -> void:
	if not multiplayer.is_server():
		return
	var player := _resolve_requesting_player()
	if player == null or not is_player_in_range(player):
		return
	var quest_log := player.get_node_or_null("QuestLog") as QuestLog
	if quest_log:
		quest_log.credit_talk(npc_id)


@rpc("any_peer", "call_local", "reliable")
func request_accept_quest(quest_id_text: String) -> void:
	if not multiplayer.is_server():
		return
	var player := _resolve_requesting_player()
	if player == null or not is_player_in_range(player):
		return
	var quest_id := StringName(quest_id_text)
	# The quest must actually be one this NPC offers. Otherwise a modified
	# client could accept the final quest in the chain from the stable boy.
	if not QuestDatabase.quests_offered_by(npc_id).has(quest_id):
		return
	var quest_log := player.get_node_or_null("QuestLog") as QuestLog
	if quest_log:
		quest_log.accept_quest(quest_id)


@rpc("any_peer", "call_local", "reliable")
func request_turn_in_quest(quest_id_text: String) -> void:
	if not multiplayer.is_server():
		return
	var player := _resolve_requesting_player()
	if player == null or not is_player_in_range(player):
		return
	var quest_id := StringName(quest_id_text)
	var quest := QuestDatabase.get_quest(quest_id)
	if quest == null or quest.turn_in_id != npc_id:
		return
	var quest_log := player.get_node_or_null("QuestLog") as QuestLog
	if quest_log:
		quest_log.turn_in(quest_id)


## Buying. The server checks the NPC actually sells it, the player is actually
## standing here, and they actually have the Sovereigns — then and only then
## does anything change hands.
@rpc("any_peer", "call_local", "reliable")
func request_buy(item_id_text: String) -> void:
	if not multiplayer.is_server():
		return
	var player := _resolve_requesting_player()
	if player == null or not is_player_in_range(player):
		return
	var data := NpcDatabase.get_npc(npc_id)
	var item_id := StringName(item_id_text)
	if data == null or not data.stock.has(item_id):
		return
	var item: Item = ItemDatabase.get_item(item_id_text)
	if item == null:
		return
	var quest_log := player.get_node_or_null("QuestLog") as QuestLog
	if quest_log == null or quest_log.currency < item.value:
		return
	if not player.has_method("request_add_item"):
		return
	quest_log.add_currency(-item.value)
	player.request_add_item(item_id_text, 1)


func _resolve_requesting_player() -> Node3D:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	for container in get_tree().get_nodes_in_group("Players"):
		var node := container.get_node_or_null(str(sender))
		if node:
			return node as Node3D
	return null


func _get_local_player() -> Node3D:
	if not multiplayer.has_multiplayer_peer():
		return null
	var local_id := multiplayer.get_unique_id()
	for container in get_tree().get_nodes_in_group("Players"):
		var node := container.get_node_or_null(str(local_id))
		if node:
			return node as Node3D
	return null


func _find_dialogue_ui() -> Node:
	var scene := get_tree().get_current_scene()
	if scene == null:
		return null
	return scene.find_child("NpcDialogueUI", true, false)


# --- Talking to this NPC ----------------------------------------------------


# Pressing the interact key talks to the NEAREST npc you're standing next to,
# so two characters standing together don't both answer at once.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	var local_player := _get_local_player()
	if local_player == null or not is_player_in_range(local_player):
		return
	if not _is_nearest_npc_to(local_player):
		return
	var dialogue := _find_dialogue_ui()
	if dialogue and dialogue.has_method("is_open") and dialogue.is_open():
		return
	begin_conversation(local_player)
	get_viewport().set_input_as_handled()


func _is_nearest_npc_to(player: Node3D) -> bool:
	var my_distance := global_position.distance_to(player.global_position)
	for node in get_tree().get_nodes_in_group("NPCs"):
		var other := node as NPC
		if other == null or other == self:
			continue
		if other.global_position.distance_to(player.global_position) < my_distance:
			return false
	return true
