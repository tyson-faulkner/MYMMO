# Stats — health and mana for anything that can fight or be fought.
#
# Attach this as a child node named "Stats" to a player or an enemy.
#
# Only the server is allowed to change health. When it does, it tells every
# client the new value. This is called "server authoritative" and it's what
# stops a cheating client from simply declaring itself invincible.
class_name Stats
extends Node

signal health_changed(current: int, maximum: int)
signal died

@export var max_health: int = 100
@export var max_mana: int = 100
@export var level: int = 1

var health: int
var mana: int
var is_dead: bool = false


func _ready() -> void:
	health = max_health
	mana = max_mana
	health_changed.emit(health, max_health)


# Server only. Subtract health and broadcast the result to everyone.
func apply_damage(amount: int) -> void:
	if not multiplayer.is_server() or is_dead or amount <= 0:
		return
	var new_health: int = maxi(0, health - amount)
	_set_health(new_health)
	_set_health.rpc(new_health)


# Server only. Restore to full.
func revive() -> void:
	if not multiplayer.is_server():
		return
	_set_health(max_health)
	_set_health.rpc(max_health)


# Runs on every machine. The server calls it directly on itself and sends it
# to the clients, so everybody's health bars agree.
@rpc("authority", "reliable")
func _set_health(value: int) -> void:
	health = clampi(value, 0, max_health)
	health_changed.emit(health, max_health)
	if health == 0:
		if not is_dead:
			is_dead = true
			died.emit()
	else:
		is_dead = false
