# PersistenceManager — the bit that decides WHEN a character is written down.
#
# Attach to the player. The server owns the character's numbers; the owning
# client owns the account those numbers get saved to. So the server captures the
# state and hands it to the owner, and the owner writes it.
#
# Saving happens on a timer, on level-up, on quest hand-in, and on quit —
# level-ups and hand-ins because those are the moments a player would be most
# annoyed to lose.
class_name PersistenceManager
extends Node

const AUTOSAVE_SECONDS := 45.0

var _autosave_timer: float = 0.0
var _loaded := false


func _ready() -> void:
	var body := get_parent()
	var stats := body.get_node_or_null("Stats") as Stats
	if stats:
		stats.leveled_up.connect(func(_level: int) -> void: request_save())
	var quest_log := body.get_node_or_null("QuestLog") as QuestLog
	if quest_log:
		quest_log.quest_turned_in.connect(func(_quest_id: StringName) -> void: request_save())
	# The owning client is the one with the Nakama account, so it's the one that
	# asks for its saved character when it spawns.
	if body.is_multiplayer_authority():
		call_deferred("_restore_on_spawn")
	set_process(true)


func _process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_SECONDS:
		_autosave_timer = 0.0
		request_save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		request_save()


# --- Loading ---------------------------------------------------------------


func _restore_on_spawn() -> void:
	if _loaded:
		return
	_loaded = true
	if not await Account.login():
		return
	var saved := await Account.load_character()
	if saved.is_empty() or not CharacterState.looks_valid(saved):
		return
	# The client has its save; only the server may put it into play.
	if multiplayer.is_server():
		submit_saved_character(saved)
	else:
		submit_saved_character.rpc_id(1, saved)


@rpc("any_peer", "call_local", "reliable")
func submit_saved_character(saved: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var body := get_parent()
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	# Only the owner of this character may restore into it.
	if sender != body.get_multiplayer_authority():
		return
	if not CharacterState.looks_valid(saved):
		return
	CharacterState.apply(body, saved)


# --- Saving ----------------------------------------------------------------


## Server-side: read the live character and hand it to whoever owns it.
func request_save() -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var body := get_parent()
	var data := CharacterState.capture(body)
	if data.is_empty():
		return
	var owner_id := body.get_multiplayer_authority()
	if owner_id == multiplayer.get_unique_id():
		_write(data)
	else:
		receive_save.rpc_id(owner_id, data)


@rpc("authority", "reliable")
func receive_save(data: Dictionary) -> void:
	_write(data)


func _write(data: Dictionary) -> void:
	if not Account.is_logged_in():
		return
	await Account.save_character(data)
