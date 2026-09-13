# BossMechanics — what a boss DOES, from data.
#
# docs/kingsmourn-endgame-spec.md describes every boss as a list of timed or
# health-triggered abilities: "every 12s, a 2s cast at a random non-tank",
# "at 70% and 35%, four adds", "every 8s a pool under someone". This node reads
# exactly that from MobData.mechanics and runs it on the server. One script,
# every boss; a new boss is entries, not code.
#
# A mechanic entry:
#   name         shown over the boss's head and in the recorder
#   every/first  timer trigger, seconds            (or)
#   at           health trigger: [70, 35] percentages, each fires once
#                with `every` as well: fires at the threshold, then repeats
#   cast         seconds of wind-up, 0 = instant. Casts use Mob's cast bar.
#   interruptible  false for the unstoppable ones
#   target       "tank" (current target), "random", "furthest", "self"
#   range        how far a random/furthest target may be
#   effect       what lands:
#       damage      power to the target
#       heal        power to the boss
#       slow        target moves at `slow` for `duration` (Kell's Bind)
#       stun        target stunned for `duration`
#       pool        a GroundEffect at the target's feet: radius, slow, power,
#                   tick, persist (true) or seconds
#       pools_fire  every pool this boss made bolts its nearest player: power
#       line        power to everyone in a `width` line from the boss through
#                   the target, `length` long (Severin's Sun Lance)
#       charge      the boss lands beside the target, hits for power, and
#                   throws them `knockback` metres (Ashcombe)
#       named       names a player for `duration`; while named and off the
#                   `dais` interactable, hits on the boss heal it `heal_share`
#       spawn       `spawn`: [{id, count}] via the mob container; optional
#                   `alive_bonus` per living add to the boss's damage
#       stat        `damage_bonus` added to the boss's damage, permanently
#   avoidable    the parse reads this flag; the engine ignores it
class_name BossMechanics
extends Node

signal mechanic_fired(mechanic_name: String)

var mob: Mob = null

var _next_fire_msec: Dictionary = {}
var _fired_thresholds: Dictionary = {}
var _spawned: Dictionary = {}
var _damage_bonus: float = 0.0
var _pool_count: int = 0
var _in_combat: bool = false

## The Crown: who is named and until when. Read by the HUD-facing label too.
var named_player: Node3D = null
var _named_until_msec: int = 0
var _named_entry: Dictionary = {}


func setup(owner_mob: Mob) -> void:
	mob = owner_mob
	name = "BossMechanics"


func _physics_process(_delta: float) -> void:
	if mob == null or not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	if mob.mob_data == null or mob.mob_data.mechanics.is_empty():
		return
	var fighting := mob.state == Mob.State.CHASING or mob.state == Mob.State.ATTACKING
	if not fighting:
		if _in_combat:
			reset()
		return
	if not _in_combat:
		_in_combat = true
		_next_fire_msec.clear()
	var now := Time.get_ticks_msec()
	if named_player and now >= _named_until_msec:
		named_player = null
	var stats := mob.get_node_or_null("Stats") as Stats
	var health_pct := 100.0
	if stats and stats.max_health > 0:
		health_pct = 100.0 * float(stats.health) / float(stats.max_health)
	for index in range(mob.mob_data.mechanics.size()):
		var entry: Dictionary = mob.mob_data.mechanics[index]
		if entry.has("at"):
			var thresholds: Array = entry["at"]
			if not _fired_thresholds.has(index):
				_fired_thresholds[index] = {}
			for threshold in thresholds:
				var key := float(threshold)
				if health_pct <= key and not _fired_thresholds[index].has(key):
					_fired_thresholds[index][key] = true
					fire(entry, index)
					if entry.has("every"):
						_next_fire_msec[index] = now + int(float(entry["every"]) * 1000.0)
			# A repeating health trigger (the enrage) ticks after its first fire.
			if entry.has("every") and _next_fire_msec.has(index) and now >= int(_next_fire_msec[index]):
				fire(entry, index)
				_next_fire_msec[index] = now + int(float(entry["every"]) * 1000.0)
			continue
		var every := float(entry.get("every", 0.0))
		if every <= 0.0:
			continue
		if not _next_fire_msec.has(index):
			_next_fire_msec[index] = now + int(float(entry.get("first", every * 0.5)) * 1000.0)
			continue
		if now >= int(_next_fire_msec[index]):
			if fire(entry, index):
				_next_fire_msec[index] = now + int(every * 1000.0)
			else:
				# Nothing to aim at yet. Try again shortly rather than in a minute.
				_next_fire_msec[index] = now + 1000


## The fight is over (the boss walked home, or died): forget everything except
## the adds, which the container still owns.
func reset() -> void:
	_in_combat = false
	_next_fire_msec.clear()
	_fired_thresholds.clear()
	_damage_bonus = 0.0
	named_player = null


## Server. Runs one mechanic now. Returns false when it had nothing to aim at.
func fire(entry: Dictionary, index: int = -1) -> bool:
	if mob == null:
		return false
	var cast_seconds := float(entry.get("cast", 0.0))
	if cast_seconds > 0.0:
		var started := mob.start_cast_entry(entry, true)
		if started:
			mechanic_fired.emit(str(entry.get("name", "")))
		return started
	var target := _pick_target(entry)
	if target == null and _needs_target(entry):
		return false
	land(entry, target, index)
	mechanic_fired.emit(str(entry.get("name", "")))
	return true


## Server. Runs a mechanic by name — what tests and scripted fights use.
func fire_by_name(mechanic_name: String) -> bool:
	if mob == null or mob.mob_data == null:
		return false
	for index in range(mob.mob_data.mechanics.size()):
		var entry: Dictionary = mob.mob_data.mechanics[index]
		if str(entry.get("name", "")) == mechanic_name:
			return fire(entry, index)
	return false


func _needs_target(entry: Dictionary) -> bool:
	return str(entry.get("effect", "damage")) in ["damage", "slow", "stun", "pool", "line", "charge", "named"]


func _pick_target(entry: Dictionary) -> Node3D:
	var rule := str(entry.get("target", "tank"))
	var reach := float(entry.get("range", 40.0))
	match rule:
		"self":
			return mob
		"tank":
			return mob._pick_cast_target("current", reach)
		_:
			return mob._pick_cast_target(rule, reach)


## Server. What happens when the mechanic lands — instantly, or at the end of
## its cast (Mob._land_cast hands anything it doesn't know here).
func land(entry: Dictionary, target: Node3D, index: int = -1) -> void:
	var mechanic_name := str(entry.get("name", ""))
	var power := int(entry.get("power", 0))
	var duration := float(entry.get("duration", 4.0))
	match str(entry.get("effect", "damage")):
		"damage":
			_hit(target, power)
		"heal":
			var stats := mob.get_node_or_null("Stats") as Stats
			if stats:
				stats.heal(power)
		"slow":
			if target and target.has_method("apply_speed_modifier"):
				target.apply_speed_modifier(float(entry.get("slow", 0.1)), duration)
			_hit(target, power)
		"stun":
			if target and target.has_method("apply_stun"):
				target.apply_stun(duration)
			_hit(target, power)
		"pool":
			if target == null:
				return
			_pool_count += 1
			var seconds := -1.0 if bool(entry.get("persist", true)) else float(entry.get("seconds", 10.0))
			mob.spawn_ground_effect.rpc(
				"Pool_%s_%d" % [mob.name, _pool_count], target.global_position,
				float(entry.get("radius", 3.0)), float(entry.get("slow", 0.5)), power,
				float(entry.get("tick", 1.0)), seconds
			)
			mob.spawn_ground_effect(
				"Pool_%s_%d" % [mob.name, _pool_count], target.global_position,
				float(entry.get("radius", 3.0)), float(entry.get("slow", 0.5)), power,
				float(entry.get("tick", 1.0)), seconds
			)
		"pools_fire":
			for pool in GroundEffect.all_in(get_tree()):
				if pool.owner_name != mob.name:
					continue
				var nearest := _nearest_player_to(pool.global_position, float(entry.get("range", 60.0)))
				_hit(nearest, power)
		"line":
			if target == null:
				return
			var origin := mob.global_position
			var direction := target.global_position - origin
			direction.y = 0.0
			if direction.length() < 0.1:
				direction = -mob.global_transform.basis.z
			direction = direction.normalized()
			var half_width := float(entry.get("width", 3.0)) * 0.5
			var length := float(entry.get("length", 40.0))
			for character in mob._players_within(length + 2.0):
				var offset := character.global_position - origin
				offset.y = 0.0
				var along := offset.dot(direction)
				if along < 0.0 or along > length:
					continue
				var across := (offset - direction * along).length()
				if across <= half_width:
					_hit(character, power)
		"charge":
			if target == null:
				return
			var toward := target.global_position - mob.global_position
			toward.y = 0.0
			if toward.length() < 0.1:
				toward = -mob.global_transform.basis.z
			toward = toward.normalized()
			mob.global_position = target.global_position - toward * 1.6
			mob.velocity = Vector3.ZERO
			mob.target = target
			_hit(target, power)
			if target.has_method("apply_knockback"):
				target.apply_knockback(toward * float(entry.get("knockback", 12.0)) + Vector3(0, 4.0, 0))
		"named":
			if target == null:
				return
			named_player = target
			_named_until_msec = Time.get_ticks_msec() + int(duration * 1000.0)
			_named_entry = entry
			var who := str(target.name)
			var nickname := target.get_node_or_null("PlayerNick/Nickname") as Label3D
			if nickname:
				who = nickname.text
			mob.announce("%s: %s" % [mechanic_name.to_upper(), who], duration)
			mob.announce.rpc("%s: %s" % [mechanic_name.to_upper(), who], duration)
		"spawn":
			_spawn_adds(entry, index)
		"stat":
			_damage_bonus += float(entry.get("damage_bonus", 0.1))
			mob.announce(mechanic_name, 2.0)
			mob.announce.rpc(mechanic_name, 2.0)


func _spawn_adds(entry: Dictionary, index: int) -> void:
	var container := mob.get_parent() as MobContainer
	if container == null:
		return
	if not _spawned.has(index):
		_spawned[index] = []
	var placed := 0
	for group in entry.get("spawn", []):
		var mob_id := StringName(str(group.get("id", "")))
		for i in range(int(group.get("count", 1))):
			var angle := TAU * float(placed) / 6.0
			var spot := mob.global_position + Vector3(cos(angle) * 4.0, 0.0, sin(angle) * 4.0)
			var add := container.spawn_mob(mob_id, spot, false) as Mob
			placed += 1
			if add == null:
				continue
			_spawned[index].append(add)
			# It walked in for a fight, not to stand around.
			var victim := _nearest_player_to(spot, 60.0)
			if victim and add.has_method("force_target"):
				add.call_deferred("force_target", victim, 4.0)
	mob.announce(str(entry.get("name", "")), 2.5)
	mob.announce.rpc(str(entry.get("name", "")), 2.5)


## What the boss's hits get multiplied by: enrage stacks, plus living adds
## that carry an alive_bonus.
func damage_multiplier() -> float:
	var multiplier := 1.0 + _damage_bonus
	if mob and mob.mob_data:
		for index in _spawned:
			var entry: Dictionary = mob.mob_data.mechanics[index] if index < mob.mob_data.mechanics.size() else {}
			var bonus := float(entry.get("alive_bonus", 0.0))
			if bonus <= 0.0:
				continue
			for add in _spawned[index]:
				if is_instance_valid(add) and add.is_inside_tree() and add.state != Mob.State.DEAD:
					multiplier += bonus
	return multiplier


## Server, from the boss's Stats: the Crown's punishment for an unmoved raid.
func on_damaged(amount: int, _source_peer_id: int) -> void:
	if named_player == null or Time.get_ticks_msec() >= _named_until_msec:
		return
	var dais := Interactable.find(get_tree(), StringName(str(_named_entry.get("dais", "throne_dais"))))
	if dais and dais.is_player_on(named_player):
		return
	var stats := mob.get_node_or_null("Stats") as Stats
	if stats:
		stats.heal(maxi(1, int(round(float(amount) * float(_named_entry.get("heal_share", 0.5))))))


func is_naming(player: Node3D) -> bool:
	return named_player == player and Time.get_ticks_msec() < _named_until_msec


func _hit(target: Node3D, power: int) -> void:
	if target == null or power <= 0:
		return
	var stats := target.get_node_or_null("Stats") as Stats
	if stats and not stats.is_dead:
		stats.apply_damage(int(round(float(power) * damage_multiplier())), 0)


func _nearest_player_to(point: Vector3, reach: float) -> Node3D:
	var best: Node3D = null
	var best_distance := reach
	for container in get_tree().get_nodes_in_group("Players"):
		for child in container.get_children():
			var character := child as Node3D
			if character == null or not character.is_inside_tree():
				continue
			var stats := character.get_node_or_null("Stats") as Stats
			if stats and stats.is_dead:
				continue
			var distance := point.distance_to(character.global_position)
			if distance < best_distance:
				best_distance = distance
				best = character
	return best
