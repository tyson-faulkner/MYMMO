# Mob — a living enemy: notices you, chases you, hits you, dies, and comes back.
#
# ALL of the thinking happens on the server. Clients receive the result through
# a MultiplayerSynchronizer and never decide anything themselves, which is the
# same rule the rest of the game follows: the client asks, the server decides.
class_name Mob
extends CharacterBody3D

enum State { IDLE, CHASING, ATTACKING, RETURNING, DEAD }

const GRAVITY := 24.0
## How close to home counts as "back where I started".
const HOME_TOLERANCE := 0.6

@export var mob_data: MobData = null

## Set by a spawner so the mob knows where to walk back to.
@export var home_position: Vector3 = Vector3.ZERO

## Dungeon and raid bosses scale with how many players are in the instance, so
## "a 5-man that works with 4" and "a raid that works with 5 or 10" are the same
## code written once.
@export var scale_with_player_count: bool = false

var state: State = State.IDLE
var target: Node3D = null

## A summoned pet fights FOR a player instead of against them. Necromancers
## raise levies and Tinkers bolt down turrets, so the same Mob has to be able to
## stand on either side of a fight.
var is_friendly: bool = false
var owner_peer_id: int = 0

## Pets don't stay forever. Below zero means "no expiry", which is every mob
## that was placed in the world rather than summoned.
var lifetime_seconds: float = -1.0

## Temporary speed change from a snare or a march buff.
var speed_multiplier: float = 1.0

var _stats: Stats = null
var _attack_timer: float = 0.0
var _respawn_timer: float = 0.0
var _last_damage_source: int = 0
var _speed_modifier_remaining: float = 0.0
var _forced_target_remaining: float = 0.0

@onready var _mesh: MeshInstance3D = $Body/Mesh
@onready var _name_label: Label3D = $NameLabel
@onready var _health_label: Label3D = $HealthLabel


func _ready() -> void:
	_stats = $Stats as Stats
	if home_position == Vector3.ZERO:
		home_position = global_position
	_apply_mob_data()
	_stats.health_changed.connect(_on_health_changed)
	_stats.died.connect(_on_died)
	_on_health_changed(_stats.health, _stats.max_health)
	add_to_group("Hostiles")


func _apply_mob_data() -> void:
	if not mob_data:
		return
	name_label_text(mob_data.display_name, mob_data.level)
	_stats.max_health = _scaled_health()
	_stats.level = mob_data.level
	_stats.health = _stats.max_health
	if _mesh and _mesh.get_surface_override_material(0) == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = mob_data.placeholder_color
		_mesh.set_surface_override_material(0, material)
	if mob_data.scale_multiplier != 1.0:
		$Body.scale = Vector3.ONE * mob_data.scale_multiplier


# Bosses get more health the more people are fighting them. This is the ONLY
# place player count changes difficulty, deliberately.
func _scaled_health() -> int:
	if not mob_data:
		return 60
	if not scale_with_player_count and not mob_data.is_boss:
		return mob_data.max_health
	var player_count: int = maxi(1, _count_players())
	# 100% for the first player, +65% for each additional one.
	var multiplier: float = 1.0 + 0.65 * float(player_count - 1)
	return int(round(float(mob_data.max_health) * multiplier))


func _scaled_damage() -> int:
	if not mob_data:
		return 5
	if not scale_with_player_count and not mob_data.is_boss:
		return mob_data.damage
	# Damage scales far more gently than health, or a full group melts the tank.
	var player_count: int = maxi(1, _count_players())
	return int(round(float(mob_data.damage) * (1.0 + 0.12 * float(player_count - 1))))


func name_label_text(display_name: String, level: int) -> void:
	if _name_label:
		_name_label.text = "%s  (%d)" % [display_name, level]


func _physics_process(delta: float) -> void:
	# Clients are passengers: the synchroniser moves them.
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return

	if state == State.DEAD:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return

	_attack_timer = maxf(0.0, _attack_timer - delta)

	if _speed_modifier_remaining > 0.0:
		_speed_modifier_remaining -= delta
		if _speed_modifier_remaining <= 0.0:
			speed_multiplier = 1.0
	if _forced_target_remaining > 0.0:
		_forced_target_remaining -= delta
	if lifetime_seconds > 0.0:
		lifetime_seconds -= delta
		if lifetime_seconds <= 0.0:
			despawn.rpc()
			despawn()
			return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	match state:
		State.IDLE:
			_tick_idle()
		State.CHASING:
			_tick_chasing()
		State.ATTACKING:
			_tick_attacking()
		State.RETURNING:
			_tick_returning()

	move_and_slide()


func _tick_idle() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	var nearest := _find_hostile_toward_me(_aggro_radius())
	if nearest:
		target = nearest
		state = State.CHASING


func _tick_chasing() -> void:
	if _forced_target_remaining > 0.0 and _is_target_valid():
		# Taunted. It does not get to change its mind until this runs out.
		var taunt_distance := global_position.distance_to(target.global_position)
		if taunt_distance <= _attack_range():
			state = State.ATTACKING
		else:
			_move_toward(target.global_position)
		return
	if not _is_target_valid():
		_begin_return()
		return
	# Too far from home? Give up. Without a leash one player can drag an entire
	# hillside into town.
	if global_position.distance_to(home_position) > _leash_radius():
		_begin_return()
		return
	var distance := global_position.distance_to(target.global_position)
	if distance <= _attack_range():
		state = State.ATTACKING
		return
	_move_toward(target.global_position)


func _tick_attacking() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not _is_target_valid():
		_begin_return()
		return
	var distance := global_position.distance_to(target.global_position)
	if distance > _attack_range() * 1.25:
		state = State.CHASING
		return
	_face(target.global_position)
	if _attack_timer > 0.0:
		return
	_attack_timer = mob_data.attack_cooldown if mob_data else 1.8
	var target_stats := target.get_node_or_null("Stats") as Stats
	if target_stats and not target_stats.is_dead:
		target_stats.apply_damage(_scaled_damage(), 0)
		play_attack.rpc()


@rpc("authority", "call_local", "reliable")
func play_attack() -> void:
	# A visual hook. Real art will play a swing animation here; for now the
	# placeholder body gives a small lunge so hits are readable.
	var body := get_node_or_null("Body") as Node3D
	if not body:
		return
	var tween := create_tween()
	tween.tween_property(body, "position:z", -0.25, 0.08)
	tween.tween_property(body, "position:z", 0.0, 0.16)


func _tick_returning() -> void:
	if global_position.distance_to(home_position) <= HOME_TOLERANCE:
		state = State.IDLE
		target = null
		# Walking home heals it back up, so the next player gets a fair fight.
		_stats.revive()
		return
	_move_toward(home_position)


func _begin_return() -> void:
	target = null
	state = State.RETURNING


func _move_toward(destination: Vector3) -> void:
	var direction := destination - global_position
	direction.y = 0.0
	if direction.length() < 0.05:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	direction = direction.normalized()
	var speed: float = (mob_data.move_speed if mob_data else 3.2) * speed_multiplier
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_face(destination)


func _face(point: Vector3) -> void:
	var flat := Vector3(point.x, global_position.y, point.z)
	if flat.distance_to(global_position) < 0.05:
		return
	look_at(flat, Vector3.UP)


func _is_target_valid() -> bool:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return false
	var target_stats := target.get_node_or_null("Stats") as Stats
	if target_stats and target_stats.is_dead:
		return false
	return true


func _find_nearest_player(radius: float) -> Node3D:
	var best: Node3D = null
	var best_distance := radius
	for container in get_tree().get_nodes_in_group("Players"):
		for child in container.get_children():
			var character := child as Node3D
			if character == null or not character.is_inside_tree():
				continue
			var character_stats := character.get_node_or_null("Stats") as Stats
			if character_stats and character_stats.is_dead:
				continue
			var distance := global_position.distance_to(character.global_position)
			if distance < best_distance:
				best_distance = distance
				best = character
	return best


## Whoever this mob considers an enemy. A placed mob looks for players and for
## anyone's pets; a pet looks for placed mobs.
func _find_hostile_toward_me(radius: float) -> Node3D:
	if is_friendly:
		return _find_nearest_enemy_mob(radius)
	var nearest_player := _find_nearest_player(radius)
	var nearest_pet := _find_nearest_pet(radius)
	if nearest_player == null:
		return nearest_pet
	if nearest_pet == null:
		return nearest_player
	var to_player := global_position.distance_to(nearest_player.global_position)
	var to_pet := global_position.distance_to(nearest_pet.global_position)
	return nearest_player if to_player <= to_pet else nearest_pet


func _find_nearest_enemy_mob(radius: float) -> Node3D:
	var best: Node3D = null
	var best_distance := radius
	for node in get_tree().get_nodes_in_group("Hostiles"):
		var other := node as Mob
		if other == null or other == self or other.is_friendly or other.state == State.DEAD:
			continue
		var distance := global_position.distance_to(other.global_position)
		if distance < best_distance:
			best_distance = distance
			best = other
	return best


func _find_nearest_pet(radius: float) -> Node3D:
	var best: Node3D = null
	var best_distance := radius
	for node in get_tree().get_nodes_in_group("Hostiles"):
		var pet := node as Mob
		if pet == null or pet == self or not pet.is_friendly or pet.state == State.DEAD:
			continue
		var distance := global_position.distance_to(pet.global_position)
		if distance < best_distance:
			best_distance = distance
			best = pet
	return best


## Turn this mob into somebody's summon: it changes sides and gets a clock.
func become_pet(new_owner_peer_id: int, seconds: float) -> void:
	is_friendly = true
	owner_peer_id = new_owner_peer_id
	lifetime_seconds = seconds
	# A pet has no home to leash back to, and should not respawn when killed.
	home_position = global_position
	if mob_data:
		var pet_data: MobData = mob_data.duplicate()
		pet_data.leash_radius = 9999.0
		pet_data.respawn_seconds = 99999.0
		mob_data = pet_data
	if _name_label:
		_name_label.modulate = Color(0.6, 0.9, 1.0)


## A Valkyr claiming something: it attacks her and nothing else until this runs
## out.
func force_target(new_target: Node3D, seconds: float) -> void:
	if not multiplayer.is_server() or new_target == null:
		return
	target = new_target
	_forced_target_remaining = maxf(seconds, 4.0)
	if state == State.IDLE or state == State.RETURNING:
		state = State.CHASING


func apply_speed_modifier(multiplier: float, seconds: float) -> void:
	if not multiplayer.is_server():
		return
	speed_multiplier = maxf(0.1, multiplier)
	_speed_modifier_remaining = seconds


@rpc("authority", "call_local", "reliable")
func despawn() -> void:
	queue_free()


func _count_players() -> int:
	var total := 0
	for container in get_tree().get_nodes_in_group("Players"):
		total += container.get_child_count()
	return total


func _aggro_radius() -> float:
	return mob_data.aggro_radius if mob_data else 9.0


func _leash_radius() -> float:
	return mob_data.leash_radius if mob_data else 22.0


func _attack_range() -> float:
	return mob_data.attack_range if mob_data else 2.2


func _on_health_changed(current: int, maximum: int) -> void:
	if not _health_label:
		return
	if current > 0:
		_health_label.text = "%d / %d" % [current, maximum]
		_health_label.visible = true
	else:
		_health_label.visible = false
	# Being hit at all wakes it up, even from behind and out of aggro range.
	if (
		multiplayer.has_multiplayer_peer()
		and multiplayer.is_server()
		and current < maximum
		and current > 0
		and state == State.IDLE
	):
		var attacker := _find_hostile_toward_me(_leash_radius())
		if attacker:
			target = attacker
			state = State.CHASING


func _on_died(killer_peer_id: int) -> void:
	state = State.DEAD
	target = null
	velocity = Vector3.ZERO
	_last_damage_source = killer_peer_id
	set_visual_dead.rpc(true)
	set_visual_dead(true)
	if not multiplayer.is_server():
		return
	if is_friendly:
		# Summons don't respawn. They were only ever borrowed.
		despawn.rpc()
		despawn()
		return
	_award_kill(killer_peer_id)
	_respawn_timer = mob_data.respawn_seconds if mob_data else 25.0


# Everything a kill is worth: XP, quest credit, currency, loot.
func _award_kill(killer_peer_id: int) -> void:
	if killer_peer_id <= 0 or not mob_data:
		return
	var killer := _find_player_by_peer(killer_peer_id)
	if killer == null:
		return
	var killer_stats := killer.get_node_or_null("Stats") as Stats
	if killer_stats:
		killer_stats.grant_xp(_experience_for(killer_stats.level))
	var quest_log := killer.get_node_or_null("QuestLog")
	if quest_log and quest_log.has_method("credit_kill"):
		quest_log.credit_kill(mob_data.id, mob_data.tags)
	# Sovereigns — the currency earned from BOTH questing and dungeons, which is
	# what keeps either path worth walking.
	if quest_log and quest_log.has_method("add_currency") and mob_data.currency_reward > 0:
		quest_log.add_currency(mob_data.currency_reward)
	_drop_loot()


# Roll the loot table and leave whatever dropped on the ground. Adding the item
# to the level's ItemContainer is enough: the MultiplayerSpawner watching that
# node replicates it to everyone, including anyone who joins later.
func _drop_loot() -> void:
	if not multiplayer.is_server() or mob_data == null or mob_data.loot_table.is_empty():
		return
	var container := _find_item_container()
	if container == null:
		return
	var dropped := 0
	for item_id in mob_data.loot_table:
		if randf() > float(mob_data.loot_table[item_id]):
			continue
		var item: Item = ItemDatabase.get_item(str(item_id))
		if item == null or item.scene_path.is_empty() or not ResourceLoader.exists(item.scene_path):
			continue
		var packed := load(item.scene_path) as PackedScene
		if packed == null:
			continue
		var instance := packed.instantiate() as Node3D
		if instance == null:
			continue
		container.add_child(instance, true)
		# Scatter slightly so a multi-drop isn't one pile inside itself.
		var angle := TAU * float(dropped) / 4.0
		instance.global_position = global_position + Vector3(cos(angle) * 0.6, 0.8, sin(angle) * 0.6)
		dropped += 1


func _find_item_container() -> Node3D:
	var scene := get_tree().get_current_scene()
	if scene == null:
		return null
	var direct := scene.get_node_or_null("Environment/ItemContainer") as Node3D
	if direct:
		return direct
	return scene.find_child("ItemContainer", true, false) as Node3D


# Grey mobs give almost nothing, so nobody farms level 2 rats at level 18.
func _experience_for(killer_level: int) -> int:
	if not mob_data:
		return 0
	var difference: int = mob_data.level - killer_level
	var multiplier: float = clampf(1.0 + 0.08 * float(difference), 0.1, 1.6)
	return maxi(1, int(round(float(mob_data.experience_reward) * multiplier)))


func _find_player_by_peer(peer_id: int) -> Node3D:
	for container in get_tree().get_nodes_in_group("Players"):
		var node := container.get_node_or_null(str(peer_id))
		if node:
			return node as Node3D
	return null


@rpc("authority", "call_local", "reliable")
func set_visual_dead(dead: bool) -> void:
	var body := get_node_or_null("Body") as Node3D
	if body:
		body.visible = not dead
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision:
		collision.set_deferred("disabled", dead)
	if _name_label:
		_name_label.visible = not dead
	if _health_label:
		_health_label.visible = not dead


func _respawn() -> void:
	global_position = home_position
	velocity = Vector3.ZERO
	state = State.IDLE
	target = null
	_stats.max_health = _scaled_health()
	_stats.revive()
	set_visual_dead.rpc(false)
	set_visual_dead(false)
