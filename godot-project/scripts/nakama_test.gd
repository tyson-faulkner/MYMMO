extends Node2D

const SERVER_HOST := "127.0.0.1"
const SERVER_PORT := 7350
const SERVER_KEY := "defaultkey"


func _ready() -> void:
	_connect_to_nakama()


func _connect_to_nakama() -> void:
	var client: NakamaClient = Nakama.create_client(SERVER_KEY, SERVER_HOST, SERVER_PORT, "http")
	var device_id: String = Nakama.get_device_id()

	var session: NakamaSession = await client.authenticate_device_async(device_id)

	if session.is_exception():
		var exception: NakamaException = session.get_exception()
		print("Nakama connection FAILED: %s (status_code=%s)" % [exception.message, exception.status_code])
		return

	print("Nakama connection SUCCESS")
	print("  user_id: %s" % session.user_id)
	print("  username: %s" % session.username)
	print("  created: %s" % session.created)
	print("  expire_time: %s" % session.expire_time)
	print("  token: %s" % session.token)
