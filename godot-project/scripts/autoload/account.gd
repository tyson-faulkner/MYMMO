# Account — this machine's Nakama login, and the one place characters are saved.
#
# Nakama is what makes Kingsmourn an MMO rather than a session: without it,
# everything vanishes the moment the host closes the game.
#
# THE GAME MUST WORK WITHOUT IT. If Docker isn't running, or the backend is
# down, the whole thing degrades to exactly what it was before — you can still
# host, join, fight and quest, you just don't keep it. Nothing here is allowed
# to block or crash the game.
#
# Trust model, stated plainly: each player's client saves its OWN character
# under its OWN Nakama account. The server decides every value during play, but
# the client is what writes it down. For five to ten friends that trade is
# fine — cheating here is a social problem, not a technical one. Moving to
# server-authoritative saves means adding a Nakama server module and routing
# writes through it, and everything else in this file stays the same.
extends Node

signal login_changed(logged_in: bool)

const SERVER_HOST := "127.0.0.1"
const SERVER_PORT := 7350
const SERVER_KEY := "defaultkey"
const SERVER_SCHEME := "http"

const COLLECTION := "kingsmourn"
const CHARACTER_KEY := "character"

var session = null
var client = null
var last_error: String = ""

var _attempted := false


func is_logged_in() -> bool:
	return session != null and not session.is_expired()


## Try to log in. Safe to call more than once; safe to call when Nakama is not
## running. Returns true if we ended up logged in.
func login() -> bool:
	if is_logged_in():
		return true
	_attempted = true
	if not _has_addon():
		last_error = "Nakama addon not present"
		return false

	client = Nakama.create_client(SERVER_KEY, SERVER_HOST, SERVER_PORT, SERVER_SCHEME)
	# Device authentication: no passwords for anyone to forget, and a returning
	# player lands on the same account automatically.
	var device_id: String = Nakama.get_device_id()
	var result = await client.authenticate_device_async(device_id)

	if result.is_exception():
		session = null
		last_error = str(result.get_exception().message)
		push_warning("Kingsmourn: playing without saving — %s" % last_error)
		login_changed.emit(false)
		return false

	session = result
	last_error = ""
	login_changed.emit(true)
	return true


## Read this account's saved character. Returns an empty dictionary when there
## is nothing saved, or when Nakama isn't there.
func load_character() -> Dictionary:
	if not is_logged_in():
		return {}
	var read_id = NakamaStorageObjectId.new(COLLECTION, CHARACTER_KEY, session.user_id)
	var result = await client.read_storage_objects_async(session, [read_id])
	if result.is_exception():
		last_error = str(result.get_exception().message)
		return {}
	if result.objects.is_empty():
		return {}
	var parsed = JSON.parse_string(result.objects[0].value)
	if parsed is Dictionary:
		return parsed
	return {}


## Write this account's character. Fire and forget: a failed save must never
## interrupt play.
func save_character(data: Dictionary) -> bool:
	if not is_logged_in() or data.is_empty():
		return false
	var write := NakamaWriteStorageObject.new(
		COLLECTION,
		CHARACTER_KEY,
		1,  # read permission: owner only
		1,  # write permission: owner only
		JSON.stringify(data),
		""
	)
	var result = await client.write_storage_objects_async(session, [write])
	if result.is_exception():
		last_error = str(result.get_exception().message)
		push_warning("Kingsmourn: save failed — %s" % last_error)
		return false
	return true


func status_line() -> String:
	if is_logged_in():
		return "Saving to Nakama as %s" % session.user_id.substr(0, 8)
	if not _attempted:
		return "Not connected"
	return "Playing without saving (%s)" % last_error


# The addon is an autoload; in headless test runs it may not be registered.
func _has_addon() -> bool:
	return Engine.has_singleton("Nakama") or get_node_or_null("/root/Nakama") != null
