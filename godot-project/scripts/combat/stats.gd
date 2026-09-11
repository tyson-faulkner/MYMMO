# Stats — health, class resource, level and XP for anything that can fight or
# be fought. Attach it as a child node named "Stats".
#
# Only the server is allowed to change any of these numbers. When it does, it
# tells every client the new value. This is called "server authoritative" and
# it's what stops a cheating client from simply declaring itself invincible or
# max level.
class_name Stats
extends Node

## current, maximum
signal health_changed(current: int, maximum: int)
## current, maximum, what the bar is called ("Mana", "Verse", "Valor"...)
signal resource_changed(current: int, maximum: int, label: String)
## Carries who landed the killing blow so quests and XP can be credited.
## 0 means "nobody / the world".
signal died(killer_peer_id: int)
signal revived
## current xp, xp needed for the next level
signal xp_changed(current: int, needed: int)
signal leveled_up(new_level: int)

const MAX_LEVEL := 20

@export var max_health: int = 100
@export var max_mana: int = 100
@export var level: int = 1

## Optional. When set, the class decides health, resource name and resource
## behaviour, overriding max_health / max_mana above.
@export var class_data: ClassData = null

var health: int
var mana: int
var is_dead: bool = false
var experience: int = 0

var _resource_label: String = "Mana"
var _resource_builds_in_combat: bool = false
var _resource_regen_per_second: float = 0.0
var _regen_carry: float = 0.0


func _ready() -> void:
	if class_data:
		apply_class(class_data)
	else:
		health = max_health
		mana = max_mana
	health_changed.emit(health, max_health)
	resource_changed.emit(mana, max_mana, _resource_label)
	xp_changed.emit(experience, xp_for_next_level(level))


# Recompute everything from a class definition. Safe to call on spawn once the
# player has picked a class.
func apply_class(new_class: ClassData) -> void:
	class_data = new_class
	if not class_data:
		return
	max_health = class_data.base_health + class_data.health_per_level * (level - 1)
	max_mana = class_data.max_resource
	_resource_label = class_data.resource_label
	_resource_builds_in_combat = class_data.resource_builds_in_combat
	_resource_regen_per_second = class_data.resource_regen_per_second
	health = max_health
	# A resource that builds during a fight starts empty; one that drains
	# starts full.
	mana = 0 if _resource_builds_in_combat else max_mana
	health_changed.emit(health, max_health)
	resource_changed.emit(mana, max_mana, _resource_label)


func get_resource_label() -> String:
	return _resource_label


func _process(delta: float) -> void:
	# Only the server ticks regeneration, then broadcasts the result.
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	if is_dead or _resource_builds_in_combat or _resource_regen_per_second <= 0.0:
		return
	if mana >= max_mana:
		return
	_regen_carry += _resource_regen_per_second * delta
	if _regen_carry >= 1.0:
		var whole := int(_regen_carry)
		_regen_carry -= float(whole)
		restore_resource(whole)


# --- Health -----------------------------------------------------------------


# Server only. `source_peer_id` is who dealt it, so the killing blow can be
# credited to a player's quests and XP.
func apply_damage(amount: int, source_peer_id: int = 0) -> void:
	if not multiplayer.is_server() or is_dead or amount <= 0:
		return
	var mitigated: int = amount
	if class_data and class_data.base_armor > 0:
		# Flat armour with a floor, so a big hit still hurts.
		mitigated = maxi(1, amount - class_data.base_armor)
	var new_health: int = maxi(0, health - mitigated)
	_set_health(new_health, source_peer_id)
	_set_health.rpc(new_health, source_peer_id)
	# Taking a hit builds a tank's resource.
	if _resource_builds_in_combat:
		restore_resource(int(ceil(mitigated * 0.35)))


func heal(amount: int) -> void:
	if not multiplayer.is_server() or is_dead or amount <= 0:
		return
	var new_health: int = mini(max_health, health + amount)
	_set_health(new_health, 0)
	_set_health.rpc(new_health, 0)


# Server only. Restore to full and clear death.
func revive() -> void:
	if not multiplayer.is_server():
		return
	_set_health(max_health, 0)
	_set_health.rpc(max_health, 0)


# Runs on every machine. The server calls it directly on itself and sends it to
# the clients, so everybody's health bars agree.
@rpc("authority", "reliable")
func _set_health(value: int, killer_peer_id: int) -> void:
	var was_dead := is_dead
	health = clampi(value, 0, max_health)
	health_changed.emit(health, max_health)
	if health == 0:
		if not was_dead:
			is_dead = true
			died.emit(killer_peer_id)
	else:
		is_dead = false
		if was_dead:
			revived.emit()


# --- Class resource ---------------------------------------------------------


## Returns true if the cost was paid. The server calls this before letting an
## ability go off; a client asking nicely is never enough.
func spend_resource(amount: int) -> bool:
	if amount <= 0:
		return true
	if mana < amount:
		return false
	_set_resource(mana - amount)
	_set_resource.rpc(mana - amount)
	return true


func restore_resource(amount: int) -> void:
	if not multiplayer.is_server() or amount <= 0:
		return
	var value: int = mini(max_mana, mana + amount)
	if value == mana:
		return
	_set_resource(value)
	_set_resource.rpc(value)


func has_resource(amount: int) -> bool:
	return mana >= amount


@rpc("authority", "reliable")
func _set_resource(value: int) -> void:
	mana = clampi(value, 0, max_mana)
	resource_changed.emit(mana, max_mana, _resource_label)


# --- Levelling --------------------------------------------------------------


## How much XP the jump from `current_level` to the next one costs.
## Tuned so 1 to 20 is roughly eight to ten hours of play.
static func xp_for_next_level(current_level: int) -> int:
	if current_level >= MAX_LEVEL:
		return 0
	return 80 * current_level + 12 * current_level * current_level


func grant_xp(amount: int) -> void:
	if not multiplayer.is_server() or amount <= 0 or level >= MAX_LEVEL:
		return
	var new_experience := experience + amount
	var new_level := level
	var needed := xp_for_next_level(new_level)
	while new_level < MAX_LEVEL and needed > 0 and new_experience >= needed:
		new_experience -= needed
		new_level += 1
		needed = xp_for_next_level(new_level)
	_set_progression(new_level, new_experience)
	_set_progression.rpc(new_level, new_experience)


@rpc("authority", "reliable")
func _set_progression(new_level: int, new_experience: int) -> void:
	var gained_levels := new_level > level
	level = clampi(new_level, 1, MAX_LEVEL)
	experience = maxi(0, new_experience)
	if gained_levels:
		if class_data:
			max_health = class_data.base_health + class_data.health_per_level * (level - 1)
			health = max_health
			health_changed.emit(health, max_health)
		leveled_up.emit(level)
	xp_changed.emit(experience, xp_for_next_level(level))
