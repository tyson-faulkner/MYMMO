# Mob — a living enemy: notices you, chases you, hits you, dies, and comes back.
#
# ALL of the thinking happens on the server. Clients receive the result through
# a MultiplayerSynchronizer and never decide anything themselves, which is the
# same rule the rest of the game follows: the client asks, the server decides.
class_name Mob
extends CharacterBody3D

enum State { IDLE, CHASING, ATTACKING, RETURNING, DEAD }

## Fired on the server when somebody stops a cast. The combat recorder and the
## parse count these; "Most Interrupts" is a real award.
signal cast_interrupted(cast_name: String, by_peer_id: int)
## Fired on the server when a cast lands.
signal cast_landed(cast_name: String, target: Node3D)

const GRAVITY := 24.0
## After an interrupt, a caster is silenced for this long before trying again.
const INTERRUPT_LOCKOUT := 3.0
## How far away a cast target may be if the cast entry doesn't say.
const DEFAULT_CAST_RANGE := 20.0
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

## The rigged model this mob wears, if its MobData names one. It replaces the
## tinted placeholder capsule; the capsule stays for enemies with no art yet.
const MODEL_NODE := "Model"
const LOOPING_CLIPS: Array[StringName] = [&"Idle", &"Run"]
## Faster than this across the ground and the model runs rather than stands.
const RUN_SPEED_THRESHOLD := 0.5

var _model_player: AnimationPlayer = null
var _clip: StringName = &""
var _last_ground_position: Vector3 = Vector3.ZERO

## Casting. `is_casting`, `cast_name`, `cast_interruptible` and the two clocks
## are set on EVERY peer by begin_cast/end_cast, so a client can draw the bar
## from its own clock without the server streaming progress at it. The rest is
## server-only.
var is_casting: bool = false
var cast_name: String = ""
var cast_interruptible: bool = true
var _cast_started_msec: int = 0
var _cast_seconds: float = 1.0
var _cast_entry: Dictionary = {}
var _cast_target: Node3D = null
var _cast_remaining: float = 0.0
var _cast_ready_at: Dictionary = {}
var _cast_lockout: float = 0.0
var _stun_remaining: float = 0.0
var _cast_label: Label3D = null
## A line over the head that isn't a cast: "THE CROWN: Tyson", "Heralds".
var _announce_text: String = ""
var _announce_until_msec: int = 0

## Server only, bosses only: the thing that runs their mechanics.
var _mechanics: BossMechanics = null

## The grudge tier this pull is fought at. Every peer has it: it is in the name.
var grudge_tier: int = 0

## Fired on the server when a boss dies, with the tier it fell at. The
## chronicle listens for "the first time each tier falls".
signal boss_fell(boss_id: StringName, tier: int)

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
	_stats.damaged.connect(_on_damaged)
	_on_health_changed(_stats.health, _stats.max_health)
	add_to_group("Hostiles")
	if mob_data and not mob_data.mechanics.is_empty() and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_mechanics = BossMechanics.new()
		_mechanics.setup(self)
		add_child(_mechanics)
	_cast_label = Label3D.new()
	_cast_label.name = "CastLabel"
	_cast_label.position = Vector3(0, 2.0, 0)
	_cast_label.pixel_size = 0.003
	_cast_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cast_label.no_depth_test = true
	_cast_label.font_size = 44
	_cast_label.outline_size = 14
	_cast_label.modulate = Color(1.0, 0.75, 0.35)
	_cast_label.visible = false
	add_child(_cast_label)


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
	_wear_model()


## Put the real model on, if there is one, and hide the placeholder under it.
## Models are exported facing -Z, which is where look_at() points a mob, so
## no turn is needed — unlike the player, whose template faced the other way.
func _wear_model() -> void:
	if mob_data == null:
		return
	# A season can put a boss in a different skin.
	var model_path := SeasonDatabase.model_for(mob_data.id, mob_data.model_path)
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		return
	var scene := load(model_path) as PackedScene
	if scene == null:
		return
	var model := scene.instantiate() as Node3D
	if model == null:
		return
	model.name = MODEL_NODE
	var body := $Body as Node3D
	body.add_child(model)
	for placeholder in ["Mesh", "Head", "Shoulders"]:
		var node := body.get_node_or_null(placeholder) as Node3D
		if node:
			node.visible = false
	_model_player = model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if _model_player:
		for clip in LOOPING_CLIPS:
			if _model_player.has_animation(clip):
				_model_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		_play_clip(&"Idle")
	_last_ground_position = global_position


func _play_clip(clip: StringName) -> void:
	if _model_player == null or not _model_player.has_animation(clip):
		return
	if _clip == clip and _model_player.is_playing():
		return
	_clip = clip
	_model_player.play(clip)


## Every peer picks Idle or Run from the movement it can see. Clients never
## run the AI, but they do see the synchronised position change, which is all
## a run cycle needs to know.
func _process(delta: float) -> void:
	_refresh_cast_label()
	if _model_player == null or delta <= 0.0:
		return
	var moved := global_position - _last_ground_position
	moved.y = 0.0
	_last_ground_position = global_position
	if _clip == &"Attack1" and _model_player.is_playing() and _model_player.current_animation == "Attack1":
		return
	_play_clip(&"Run" if moved.length() / delta > RUN_SPEED_THRESHOLD else &"Idle")


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
	var scaled := float(mob_data.damage) * (1.0 + 0.12 * float(player_count - 1))
	# Enrage stacks and living heralds make a boss hit harder still.
	if _mechanics:
		scaled *= _mechanics.damage_multiplier()
	return int(round(scaled))


func name_label_text(display_name: String, level: int) -> void:
	if _name_label:
		var tier := "  ⟨%s⟩" % GrudgeLedger.roman(grudge_tier) if grudge_tier > 0 else ""
		_name_label.text = "%s%s  (%d)" % [display_name, tier, level]


## Every peer: the pull's grudge tier, so the name reads "Master Kell ⟨IV⟩".
@rpc("authority", "call_local", "reliable")
func set_grudge_tier(tier: int) -> void:
	grudge_tier = maxi(0, tier)
	if mob_data:
		name_label_text(mob_data.display_name, mob_data.level)


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
	_cast_lockout = maxf(0.0, _cast_lockout - delta)

	if _stun_remaining > 0.0:
		# Stunned: nothing happens except gravity. The cast, if any, is
		# already gone — apply_stun() stopped it.
		_stun_remaining -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return

	if is_casting:
		_tick_cast(delta)
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return

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
		return
	# A feud: the Records packs and the claimants fight each other, but only
	# once a player is close enough to see it, so a pack is whole when you
	# arrive and thins itself out while you watch.
	if mob_data and mob_data.feud != &"" and _find_nearest_player(_aggro_radius() * 2.5):
		var rival := _find_feud_rival(_aggro_radius())
		if rival:
			target = rival
			state = State.CHASING


func _find_feud_rival(radius: float) -> Node3D:
	var best: Node3D = null
	var best_distance := radius
	for node in get_tree().get_nodes_in_group("Hostiles"):
		var other := node as Mob
		if other == null or other == self or other.is_friendly or other.state == State.DEAD:
			continue
		if other.mob_data == null or not other.mob_data.tags.has(mob_data.feud):
			continue
		var distance := global_position.distance_to(other.global_position)
		if distance < best_distance:
			best_distance = distance
			best = other
	return best


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
	if _try_begin_cast():
		return
	if _attack_timer > 0.0:
		return
	_attack_timer = mob_data.attack_cooldown if mob_data else 1.8
	var target_stats := target.get_node_or_null("Stats") as Stats
	if target_stats and not target_stats.is_dead:
		target_stats.apply_damage(_scaled_damage(), 0)
		play_attack.rpc()


@rpc("authority", "call_local", "reliable")
func play_attack() -> void:
	# A modelled enemy swings; the placeholder capsule lunges so hits still read.
	if _model_player and _model_player.has_animation(&"Attack1"):
		_clip = &"Attack1"
		_model_player.play(&"Attack1")
		return
	var body := get_node_or_null("Body") as Node3D
	if not body:
		return
	var tween := create_tween()
	tween.tween_property(body, "position:z", -0.25, 0.08)
	tween.tween_property(body, "position:z", 0.0, 0.16)


# --- Casting ------------------------------------------------------------------
#
# A cast is a wind-up everyone can see, then a hit. The wind-up is the point:
# it gives the party a few seconds to do something about it — an interrupt, a
# stun, or just moving. Ordinary casters carry one cast; bosses carry several,
# and the mechanics engine adds its own on top of these.


## Server. Looks for a cast that is ready and has a target, and starts it.
func _try_begin_cast() -> bool:
	if mob_data == null or mob_data.casts.is_empty() or _cast_lockout > 0.0:
		return false
	var now := Time.get_ticks_msec()
	for index in range(mob_data.casts.size()):
		var entry: Dictionary = mob_data.casts[index]
		if not _cast_ready_at.has(index):
			var first := float(entry.get("first", float(entry.get("every", 10.0)) * 0.5))
			_cast_ready_at[index] = now + int(first * 1000.0)
		if now < int(_cast_ready_at[index]):
			continue
		if start_cast(index):
			return true
	return false


## Server. Begins cast `index` from mob_data.casts if it has a target in range.
## Public so tests can force one. Returns whether it started.
func start_cast(index: int, ignore_cooldowns: bool = false) -> bool:
	if not multiplayer.is_server() or mob_data == null or index < 0 or index >= mob_data.casts.size():
		return false
	var entry: Dictionary = mob_data.casts[index]
	if not start_cast_entry(entry, ignore_cooldowns):
		return false
	_cast_ready_at[index] = Time.get_ticks_msec() + int(float(entry.get("every", 10.0)) * 1000.0)
	return true


## Server. Begins a cast from any entry — a casts row or a boss mechanic.
func start_cast_entry(entry: Dictionary, ignore_cooldowns: bool = false) -> bool:
	if not multiplayer.is_server():
		return false
	if is_casting or state == State.DEAD or _stun_remaining > 0.0:
		return false
	if not ignore_cooldowns and _cast_lockout > 0.0:
		return false
	var rule := str(entry.get("target", "current"))
	if rule == "tank":
		rule = "current"
	var chosen: Node3D = self if rule == "self" else _pick_cast_target(rule, float(entry.get("range", DEFAULT_CAST_RANGE)))
	if chosen == null:
		return false
	_cast_entry = entry
	_cast_target = chosen
	_cast_remaining = maxf(0.1, float(entry.get("cast", 1.5)))
	velocity.x = 0.0
	velocity.z = 0.0
	if chosen != self:
		_face(chosen.global_position)
	begin_cast(str(entry.get("name", "Cast")), _cast_remaining, bool(entry.get("interruptible", true)))
	begin_cast.rpc(cast_name, _cast_remaining, cast_interruptible)
	return true


func _pick_cast_target(rule: String, cast_range: float) -> Node3D:
	match rule:
		"random":
			var candidates := _players_within(cast_range)
			return candidates.pick_random() if not candidates.is_empty() else null
		"furthest":
			var furthest: Node3D = null
			var best := -1.0
			for candidate in _players_within(cast_range):
				var distance := global_position.distance_to(candidate.global_position)
				if distance > best:
					best = distance
					furthest = candidate
			return furthest
		_:
			if _is_target_valid() and global_position.distance_to(target.global_position) <= cast_range:
				return target
			return null


func _players_within(radius: float) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for container in get_tree().get_nodes_in_group("Players"):
		for child in container.get_children():
			var character := child as Node3D
			if character == null or not character.is_inside_tree():
				continue
			var character_stats := character.get_node_or_null("Stats") as Stats
			if character_stats and character_stats.is_dead:
				continue
			if global_position.distance_to(character.global_position) <= radius:
				found.append(character)
	return found


func _tick_cast(delta: float) -> void:
	if _cast_target and is_instance_valid(_cast_target):
		_face(_cast_target.global_position)
	_cast_remaining -= delta
	if _cast_remaining > 0.0:
		return
	_land_cast()


func _land_cast() -> void:
	var entry := _cast_entry
	var victim := _cast_target
	var landed_name := cast_name
	end_cast(false)
	end_cast.rpc(false)
	var power := int(entry.get("power", _scaled_damage()))
	if mob_data and mob_data.is_boss:
		power = int(round(float(power) * (1.0 + 0.12 * float(maxi(1, _count_players()) - 1))))
	match str(entry.get("effect", "damage")):
		"heal":
			_stats.heal(power)
		"damage":
			if victim and is_instance_valid(victim):
				var victim_stats := victim.get_node_or_null("Stats") as Stats
				if victim_stats and not victim_stats.is_dead:
					victim_stats.apply_damage(power, 0)
		_:
			# A boss mechanic with a wind-up: the engine knows what lands.
			if _mechanics:
				_mechanics.land(entry, victim if victim and is_instance_valid(victim) else null)
	cast_landed.emit(landed_name, victim)


## Server. Stops the cast in progress. Returns true if there was one to stop.
## An uninterruptible cast ignores this unless `force` (a stun) says otherwise.
func interrupt_cast(by_peer_id: int = 0, force: bool = false) -> bool:
	if not multiplayer.is_server() or not is_casting:
		return false
	if not cast_interruptible and not force:
		return false
	var stopped := cast_name
	_cast_lockout = INTERRUPT_LOCKOUT
	end_cast(true)
	end_cast.rpc(true)
	cast_interrupted.emit(stopped, by_peer_id)
	return true


## Server. Stops everything for a while; also breaks any cast, interruptible or not.
func apply_stun(seconds: float) -> void:
	if not multiplayer.is_server() or seconds <= 0.0:
		return
	_stun_remaining = maxf(_stun_remaining, seconds)
	interrupt_cast(0, true)
	velocity.x = 0.0
	velocity.z = 0.0


func is_stunned() -> bool:
	return _stun_remaining > 0.0


## 0..1, how far along the visible cast is. Any peer can ask.
func cast_progress() -> float:
	if not is_casting or _cast_seconds <= 0.0:
		return 0.0
	return clampf(float(Time.get_ticks_msec() - _cast_started_msec) / (_cast_seconds * 1000.0), 0.0, 1.0)


@rpc("authority", "call_local", "reliable")
func begin_cast(shown_name: String, seconds: float, interruptible: bool) -> void:
	is_casting = true
	cast_name = shown_name
	cast_interruptible = interruptible
	_cast_seconds = seconds
	_cast_started_msec = Time.get_ticks_msec()


@rpc("authority", "call_local", "reliable")
func end_cast(interrupted: bool) -> void:
	is_casting = false
	_cast_entry = {}
	_cast_target = null
	if _cast_label:
		if interrupted:
			_cast_label.text = "Interrupted"
			_cast_label.modulate = Color(0.8, 0.85, 1.0)
			var tween := create_tween()
			tween.tween_interval(0.7)
			tween.tween_callback(func() -> void:
				if not is_casting:
					_cast_label.visible = false)
		else:
			_cast_label.visible = false


## Every peer: a line over the head for a few seconds. Bosses use it to say
## who the Crown named and what just walked in.
@rpc("authority", "call_local", "reliable")
func announce(text: String, seconds: float) -> void:
	_announce_text = text
	_announce_until_msec = Time.get_ticks_msec() + int(seconds * 1000.0)


## Every peer, from the boss: draw a pool. The server's copy is the one that
## hurts; the others are the picture.
@rpc("authority", "call_local", "reliable")
func spawn_ground_effect(
	effect_name: String, at: Vector3, radius: float, slow: float, damage: int, tick: float, seconds: float
) -> void:
	GroundEffect.spawn(get_tree(), effect_name, at, radius, slow, damage, tick, seconds, name, Color(0.08, 0.06, 0.16, 0.75))


func _refresh_cast_label() -> void:
	if _cast_label == null:
		return
	if not is_casting:
		if _announce_text != "" and Time.get_ticks_msec() < _announce_until_msec:
			_cast_label.visible = true
			_cast_label.modulate = Color(1.0, 0.9, 0.5)
			_cast_label.text = _announce_text
		elif _announce_text != "":
			_announce_text = ""
			_cast_label.visible = false
		return
	var filled := int(round(cast_progress() * 10.0))
	_cast_label.visible = true
	_cast_label.modulate = Color(1.0, 0.75, 0.35) if cast_interruptible else Color(1.0, 0.45, 0.4)
	_cast_label.text = "%s\n%s%s" % [cast_name, "▮".repeat(filled), "▯".repeat(10 - filled)]


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


## Server. Somebody hit this mob: a feuding mob drops its rival for the player
## who interfered, and a boss's engine gets to react (the Crown).
func _on_damaged(amount: int, source_peer_id: int) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server() or state == State.DEAD:
		return
	if _mechanics:
		_mechanics.on_damaged(amount, source_peer_id)
	if source_peer_id > 0 and (target == null or target is Mob):
		var attacker := _find_player_by_peer(source_peer_id)
		if attacker:
			target = attacker
			if state != State.ATTACKING:
				state = State.CHASING


func _on_died(killer_peer_id: int) -> void:
	state = State.DEAD
	target = null
	velocity = Vector3.ZERO
	_last_damage_source = killer_peer_id
	_stun_remaining = 0.0
	if _mechanics:
		_mechanics.reset()
	if is_casting and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		end_cast(true)
		end_cast.rpc(true)
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


# Everything a kill is worth: XP, quest credit, currency, loot — shared with
# the killer's party.
#
# Quest credit and currency are NOT split. Only XP is, and gently. Splitting
# quest credit would mean four friends hunting the same eight bandits needed
# thirty-two kills between them, which is precisely the maths that makes people
# refuse to group in a co-op game.
func _award_kill(killer_peer_id: int) -> void:
	if killer_peer_id <= 0 or not mob_data:
		return
	var players_root := _find_players_root()
	var share_group: Array = [killer_peer_id]
	if players_root:
		share_group = PartyManager.share_group_for(killer_peer_id, global_position, players_root)

	for peer_id in share_group:
		var member := _find_player_by_peer(int(peer_id))
		if member == null:
			continue
		var member_stats := member.get_node_or_null("Stats") as Stats
		if member_stats:
			var full := _experience_for(member_stats.level)
			member_stats.grant_xp(PartyManager.experience_share(full, share_group.size()))
		var quest_log := member.get_node_or_null("QuestLog")
		if quest_log and quest_log.has_method("credit_kill"):
			quest_log.credit_kill(mob_data.id, mob_data.tags)
		if quest_log and quest_log.has_method("add_currency") and mob_data.currency_reward > 0:
			quest_log.add_currency(mob_data.currency_reward)

	# A boss down raises the grudge of everyone who was there for it — not
	# just the party: "present" is what the spec says, and presence is a place.
	if mob_data.is_boss:
		var cap := GrudgeLedger.cap_for(mob_data)
		for character in _players_within(BossMechanics.PRESENCE_RANGE):
			var ledger := character.get_node_or_null("GrudgeLedger") as GrudgeLedger
			if ledger:
				ledger.raise(mob_data.id, cap)
		boss_fell.emit(mob_data.id, grudge_tier)

	# Loot drops once, on the ground, for whoever reaches it.
	_drop_loot()


## Grudge pays: a modest bump per tier, and the mount is guaranteed at the top
## tier so nobody runs the raid nine times for nothing.
func _loot_chance(base: float, item_id: String) -> float:
	if mob_data == null or not mob_data.is_boss or grudge_tier <= 0:
		return base
	if item_id.begins_with("mount_") and grudge_tier >= GrudgeLedger.cap_for(mob_data):
		return 1.0
	return minf(1.0, base * (1.0 + 0.15 * float(grudge_tier)))


func _find_players_root() -> Node:
	for container in get_tree().get_nodes_in_group("Players"):
		return container
	return null


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
		if randf() > _loot_chance(float(mob_data.loot_table[item_id]), str(item_id)):
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
