# AbilityBar — keys 1 to 7, and everything that happens when you press them.
#
# The split that matters: the client decides WHEN to ask, the server decides
# WHETHER it happens and WHAT it does. Cooldowns are tracked on both sides, but
# the server's copy is the one that counts — a client with its cooldowns edited
# out just gets refused.
class_name AbilityBar
extends Node

signal cast_succeeded(ability_id: StringName)
signal cast_failed(ability_id: StringName, reason: String)
signal cooldowns_changed

const SLOT_COUNT := 7

## Server-side cooldowns, the authoritative ones: slot -> msec when ready.
var _server_ready_at: Dictionary = {}
## The local copy, so the UI can grey a button out immediately.
var _local_ready_at: Dictionary = {}

var _dot_hosts: Dictionary = {}


func _get_body() -> Node3D:
	return get_parent() as Node3D


func _get_stats() -> Stats:
	var body := _get_body()
	return body.get_node_or_null("Stats") as Stats if body else null


func _get_targeting() -> Targeting:
	var body := _get_body()
	return body.get_node_or_null("Targeting") as Targeting if body else null


# Stats is the single source of truth for what class this character is: it is
# what holds the ClassData, so it is what the bar asks. Reading it off the body
# as well meant the two could disagree, and the bar would silently refuse every
# ability of the class you thought you were.
func _class_id() -> StringName:
	var stats := _get_stats()
	if stats and stats.class_data and stats.class_data.id != &"":
		return stats.class_data.id
	var body := _get_body()
	if body and body.get("class_id") != null:
		return body.class_id
	return &"valkyr"


func _unhandled_input(event: InputEvent) -> void:
	var body := _get_body()
	if body == null or not body.is_multiplayer_authority():
		return
	for slot in range(1, SLOT_COUNT + 1):
		if event.is_action_pressed("ability_%d" % slot):
			press_slot(slot)
			get_viewport().set_input_as_handled()
			return


func ability_in_slot(slot: int) -> AbilityData:
	var stats := _get_stats()
	var level := stats.level if stats else 1
	return AbilityDatabase.ability_in_slot(_class_id(), slot, level)


func seconds_remaining(slot: int) -> float:
	var ready_at: int = int(_local_ready_at.get(slot, 0))
	return maxf(0.0, float(ready_at - Time.get_ticks_msec()) / 1000.0)


# --- The client's side -----------------------------------------------------


func press_slot(slot: int) -> void:
	var ability := ability_in_slot(slot)
	if ability == null:
		cast_failed.emit(&"", "nothing in that slot yet")
		return
	if seconds_remaining(slot) > 0.0:
		cast_failed.emit(ability.id, "still cooling down")
		return
	var stats := _get_stats()
	if stats and not ability.spends_all_resource and ability.cost > 0 and not stats.has_resource(ability.cost):
		cast_failed.emit(ability.id, "not enough %s" % stats.get_resource_label())
		return

	var target := _resolve_target(ability)
	if ability.target_rule == AbilityData.TargetRule.ENEMY and target == null:
		cast_failed.emit(ability.id, "no target")
		return

	# Grey the button immediately so the bar feels responsive; the server's
	# answer will correct it either way.
	if ability.cooldown > 0.0:
		_local_ready_at[slot] = Time.get_ticks_msec() + int(ability.cooldown * 1000.0)
		cooldowns_changed.emit()

	var target_path := NodePath("")
	if target:
		target_path = target.get_path()
	if multiplayer.is_server():
		request_cast(String(ability.id), target_path)
	else:
		request_cast.rpc_id(1, String(ability.id), target_path)


func _resolve_target(ability: AbilityData) -> Node3D:
	match ability.target_rule:
		AbilityData.TargetRule.SELF, AbilityData.TargetRule.GROUND:
			return _get_body()
		AbilityData.TargetRule.ALLY:
			var targeting_ally := _get_targeting()
			if targeting_ally and targeting_ally.current_target is Node3D:
				var candidate := targeting_ally.current_target
				# Healing something hostile is almost always a misclick.
				if candidate is Mob and not (candidate as Mob).is_friendly:
					return _get_body()
				return candidate
			return _get_body()
		_:
			var targeting := _get_targeting()
			return targeting.current_target if targeting else null


# --- The server's side -----------------------------------------------------


@rpc("any_peer", "call_local", "reliable")
func request_cast(ability_id_text: String, target_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var body := _get_body()
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	if body == null or sender != body.get_multiplayer_authority():
		return

	var ability := AbilityDatabase.get_ability(StringName(ability_id_text))
	if ability == null:
		return
	var stats := _get_stats()
	if stats == null or stats.is_dead:
		return
	# The ability has to belong to this character's class and level.
	if ability.class_id != _class_id() or stats.level < ability.level_required:
		return
	var slot := ability.slot
	if Time.get_ticks_msec() < int(_server_ready_at.get(slot, 0)):
		return

	var target: Node3D = null
	if not target_path.is_empty():
		target = get_node_or_null(target_path) as Node3D
	if ability.target_rule == AbilityData.TargetRule.SELF or ability.target_rule == AbilityData.TargetRule.GROUND:
		target = body
	if ability.target_rule == AbilityData.TargetRule.ENEMY:
		if target == null:
			return
		var target_stats := target.get_node_or_null("Stats") as Stats
		if target_stats == null or target_stats.is_dead:
			return
		# Range is checked HERE, against real positions, not wherever the
		# client claims to be standing.
		if body.global_position.distance_to(target.global_position) > ability.cast_range + 1.0:
			return

	# Pay for it.
	var spent := 0
	if ability.spends_all_resource:
		spent = stats.mana
		if spent <= 0:
			return
		stats.spend_resource(spent)
	elif ability.cost > 0:
		if not stats.spend_resource(ability.cost):
			return
	elif ability.cost < 0:
		stats.restore_resource(-ability.cost)

	if ability.cooldown > 0.0:
		_server_ready_at[slot] = Time.get_ticks_msec() + int(ability.cooldown * 1000.0)

	_execute(ability, body, target, spent)
	confirm_cast.rpc_id(body.get_multiplayer_authority(), String(ability.id), slot)


@rpc("authority", "reliable")
func confirm_cast(ability_id_text: String, slot: int) -> void:
	var ability := AbilityDatabase.get_ability(StringName(ability_id_text))
	if ability and ability.cooldown > 0.0:
		_local_ready_at[slot] = Time.get_ticks_msec() + int(ability.cooldown * 1000.0)
	cooldowns_changed.emit()
	cast_succeeded.emit(StringName(ability_id_text))


# The one place an ability turns into something happening. Every effect is a
# verb here, which is why a new ability is a data entry and not new code.
func _execute(ability: AbilityData, caster: Node3D, target: Node3D, spent_resource: int) -> void:
	var caster_peer := caster.get_multiplayer_authority()
	var power := ability.power
	if ability.spends_all_resource:
		# Scales with what you had banked: the more of the fight you carried,
		# the harder the finisher lands.
		power = int(round(float(ability.power) * (0.5 + float(spent_resource) / 50.0)))

	match ability.effect:
		AbilityData.Effect.DAMAGE:
			_damage(target, power, caster_peer)
		AbilityData.Effect.AOE_DAMAGE:
			var centre: Node3D = target if target else caster
			for victim in _hostiles_near(centre.global_position, ability.aoe_radius):
				_damage(victim, power, caster_peer)
		AbilityData.Effect.HEAL:
			_heal(target if target else caster, power)
		AbilityData.Effect.AOE_HEAL:
			for friend in _friendlies_near(caster.global_position, ability.aoe_radius):
				_heal(friend, power)
		AbilityData.Effect.DOT:
			DamageOverTime.apply(target, power, ability.duration_seconds, ability.tick_seconds, caster_peer)
		AbilityData.Effect.DRAIN:
			_damage(target, power, caster_peer)
			_heal(caster, int(round(float(power) * ability.drain_ratio)))
		AbilityData.Effect.TAUNT:
			var mob := target as Mob
			if mob:
				mob.force_target(caster, ability.duration_seconds)
			_damage(target, power, caster_peer)
		AbilityData.Effect.SUMMON:
			_summon(ability, caster)
		AbilityData.Effect.SPEED:
			if ability.speed_multiplier < 1.0:
				_damage(target, power, caster_peer)
			_apply_speed(target if target else caster, ability.speed_multiplier, ability.duration_seconds)


func _damage(target: Node3D, amount: int, caster_peer: int) -> void:
	if target == null or amount <= 0:
		return
	var stats := target.get_node_or_null("Stats") as Stats
	if stats and not stats.is_dead:
		stats.apply_damage(amount, caster_peer)


func _heal(target: Node3D, amount: int) -> void:
	if target == null or amount <= 0:
		return
	var stats := target.get_node_or_null("Stats") as Stats
	if stats and not stats.is_dead:
		stats.heal(amount)


func _hostiles_near(centre: Vector3, radius: float) -> Array[Node3D]:
	var found: Array[Node3D] = []
	if radius <= 0.0:
		return found
	for node in get_tree().get_nodes_in_group("Hostiles"):
		var mob := node as Mob
		if mob == null or mob.is_friendly:
			continue
		var stats := mob.get_node_or_null("Stats") as Stats
		if stats and stats.is_dead:
			continue
		if centre.distance_to(mob.global_position) <= radius:
			found.append(mob)
	return found


func _friendlies_near(centre: Vector3, radius: float) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for container in get_tree().get_nodes_in_group("Players"):
		for child in container.get_children():
			var body := child as Node3D
			if body == null:
				continue
			if centre.distance_to(body.global_position) <= radius:
				found.append(body)
	return found


func _summon(ability: AbilityData, caster: Node3D) -> void:
	if ability.summon_mob_id == &"":
		return
	var container := _find_mob_container()
	if container == null:
		return
	var spot := caster.global_position + caster.global_transform.basis.z * -2.5
	var pet := container.spawn_mob(ability.summon_mob_id, spot, false) as Mob
	if pet == null:
		return
	pet.become_pet(caster.get_multiplayer_authority(), ability.summon_seconds)


func _find_mob_container() -> MobContainer:
	var scene := get_tree().get_current_scene()
	if scene == null:
		return null
	var found := scene.find_child("MobContainer", true, false)
	return found as MobContainer


func _apply_speed(target: Node3D, multiplier: float, duration: float) -> void:
	if target == null or duration <= 0.0:
		return
	if target.has_method("apply_speed_modifier"):
		target.apply_speed_modifier(multiplier, duration)
