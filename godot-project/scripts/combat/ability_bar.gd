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

## 1-8 class and spec, 9 the capstone, 10-12 the rune moves.
const SLOT_COUNT := 12
## How far a dash carries you.
const DASH_METRES := 8.0

## Server-side cooldowns, the authoritative ones: slot -> msec when ready.
var _server_ready_at: Dictionary = {}
## The local copy, so the UI can grey a button out immediately.
var _local_ready_at: Dictionary = {}

var _dot_hosts: Dictionary = {}

## The ability being executed right now, so every hit and heal it causes is
## recorded under its name.
var _current_ability: StringName = &""
## True while a passive is casting the ability it chains to, so a chain can
## never chain into itself.
var _chaining: bool = false

## Mouseover casting: the party frame the mouse is over, set by the HUD. A
## heal pressed while hovering goes to that person. Client-side only; the
## server just sees a target path like any other.
var hovered_ally: Node3D = null


func _ready() -> void:
	var stats := _get_stats()
	if stats:
		stats.cheated_death.connect(_on_cheated_death)


func _get_body() -> Node3D:
	return get_parent() as Node3D


func _get_stats() -> Stats:
	var body := _get_body()
	return body.get_node_or_null("Stats") as Stats if body else null


func _get_runes() -> RuneLoadout:
	var body := _get_body()
	return body.get_node_or_null("RuneLoadout") as RuneLoadout if body else null


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


func _spec_id() -> StringName:
	var stats := _get_stats()
	return stats.spec_id if stats else &""


func _granted() -> Array:
	var runes := _get_runes()
	return runes.granted_ids() if runes else []


## What the ability aims at for THIS build: a Medic's Field Repair reaches an
## ally, everyone else's patches themselves.
func _target_rule(ability: AbilityData) -> AbilityData.TargetRule:
	if SpecDatabase.targets_allies(_spec_id(), ability.id):
		return AbilityData.TargetRule.ALLY
	return ability.target_rule


func ability_in_slot(slot: int) -> AbilityData:
	var stats := _get_stats()
	var level := stats.level if stats else 1
	return AbilityDatabase.ability_in_slot(_class_id(), slot, level, _spec_id(), _granted())


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
	if _target_rule(ability) == AbilityData.TargetRule.ENEMY and target == null:
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
	match _target_rule(ability):
		AbilityData.TargetRule.SELF, AbilityData.TargetRule.GROUND:
			return _get_body()
		AbilityData.TargetRule.ALLY:
			# Mouseover first: the frame under the mouse is who you meant.
			if hovered_ally and is_instance_valid(hovered_ally) and hovered_ally.is_inside_tree():
				return hovered_ally
			var targeting_ally := _get_targeting()
			if targeting_ally and targeting_ally.current_target is Node3D:
				var candidate := targeting_ally.current_target
				# Healing something hostile is almost always a misclick.
				if not (candidate is Mob and not (candidate as Mob).is_friendly):
					return candidate
			# No target and no mouseover: the lowest party member in range.
			var lowest := lowest_party_member(ability.cast_range)
			return lowest if lowest else _get_body()
		_:
			var targeting := _get_targeting()
			return targeting.current_target if targeting else null


## The party member (self included) with the lowest health fraction within
## reach, or null when alone. Removes the last excuse for a heal going nowhere.
func lowest_party_member(reach: float) -> Node3D:
	var body := _get_body()
	if body == null:
		return null
	var peer_id := body.get_multiplayer_authority()
	var lowest: Node3D = null
	var lowest_fraction := 2.0
	for member_id in PartyManager.members_of(peer_id):
		var member: Node3D = null
		for container in get_tree().get_nodes_in_group("Players"):
			var found := container.get_node_or_null(str(member_id)) as Node3D
			if found:
				member = found
				break
		if member == null or not member.is_inside_tree():
			continue
		if body.global_position.distance_to(member.global_position) > reach:
			continue
		var stats := member.get_node_or_null("Stats") as Stats
		if stats == null or stats.is_dead:
			continue
		var fraction := float(stats.health) / float(maxi(1, stats.max_health))
		if fraction < lowest_fraction:
			lowest_fraction = fraction
			lowest = member
	return lowest


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
	# Stunned means stunned: the server refuses, whatever the client pressed.
	if body.has_method("is_stunned") and body.is_stunned():
		return
	# The ability has to belong to this character's class and level, and be
	# on THIS build's bar: the right spec, or granted by a worn rune.
	if ability.class_id != _class_id() or stats.level < ability.level_required:
		return
	var slot := AbilityDatabase.slot_of(ability, _class_id(), _spec_id(), stats.level, _granted())
	if slot == 0:
		return
	if Time.get_ticks_msec() < int(_server_ready_at.get(slot, 0)):
		return

	var rule := _target_rule(ability)
	var target: Node3D = null
	if not target_path.is_empty():
		target = get_node_or_null(target_path) as Node3D
	if rule == AbilityData.TargetRule.SELF or rule == AbilityData.TargetRule.GROUND:
		target = body
	if rule == AbilityData.TargetRule.ALLY and target == null:
		target = body
	if rule == AbilityData.TargetRule.ENEMY:
		if target == null:
			return
		var target_stats := target.get_node_or_null("Stats") as Stats
		if target_stats == null or target_stats.is_dead:
			return
		# Range is checked HERE, against real positions, not wherever the
		# client claims to be standing.
		if body.global_position.distance_to(target.global_position) > ability.cast_range + 1.0:
			return

	# A rune sitting in an unlocked slot may change this ability.
	var runes := _get_runes()
	var rune: RuneData = runes.rune_for_ability(ability.id) if runes else null

	var cost := ability.cost
	var cooldown := ability.cooldown
	if rune:
		if rune.effect == RuneData.Effect.COST:
			cost = int(round(float(cost) * rune.value))
		elif rune.effect == RuneData.Effect.COOLDOWN:
			cooldown = cooldown * rune.value
	# The spec passive: Lance halves Descend's cooldown.
	cooldown *= SpecDatabase.per_ability(_spec_id(), "cooldown_mult", ability.id)
	# The Last Note: a banked charge makes this one free and doubled.
	var charged := StatusEffect.charges(body, ability.id) > 0
	if charged:
		cost = 0

	# Pay for it.
	var spent := 0
	if ability.spends_all_resource:
		spent = stats.mana
		if spent <= 0:
			return
		stats.spend_resource(spent)
	elif cost > 0:
		if not stats.spend_resource(cost):
			return
	elif cost < 0:
		stats.restore_resource(-cost)

	if cooldown > 0.0:
		_server_ready_at[slot] = Time.get_ticks_msec() + int(cooldown * 1000.0)

	CombatRecorder.record_cast(body.get_multiplayer_authority(), ability.id)
	_execute(ability, body, target, spent, rune, charged)
	if charged:
		StatusEffect.use_charge(body, ability.id)
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
func _execute(
	ability: AbilityData, caster: Node3D, target: Node3D, spent_resource: int, rune: RuneData = null, charged: bool = false
) -> void:
	var caster_peer := caster.get_multiplayer_authority()
	_current_ability = ability.id
	var power := ability.power
	var effect := ability.effect
	var radius := ability.aoe_radius
	var duration := ability.duration_seconds
	var summon_count := ability.summon_count
	var chain_targets := 0
	var splash_radius := 0.0
	var falloff := 0.5
	var spec := _spec_id()
	var tick := ability.tick_seconds * SpecDatabase.per_ability(spec, "tick_mult", ability.id)
	var drain_ratio := ability.drain_ratio * SpecDatabase.multiplier(spec, "drain_mult")

	# Runes reshape an existing ability rather than adding a new one, which is
	# why the whole build system costs no art.
	if rune:
		falloff = rune.falloff
		match rune.effect:
			RuneData.Effect.POWER:
				power = int(round(float(power) * rune.value))
				radius += rune.aoe_bonus
			RuneData.Effect.DURATION:
				duration *= rune.value
			RuneData.Effect.EXTRA_TARGETS:
				chain_targets = int(rune.value)
			RuneData.Effect.MAKE_AOE:
				# Single target becomes a small area, at reduced power and,
				# where it matters, for less time. Spreading something thin is
				# the trade for spreading it wide.
				effect = _as_area(effect)
				radius = maxf(radius, rune.value)
				power = int(round(float(power) * rune.falloff))
				duration *= rune.falloff
			RuneData.Effect.FOCUS:
				# An area ability drives into one target instead.
				effect = _as_single(effect)
				radius = 0.0
				power = int(round(float(power) * rune.value))
			RuneData.Effect.EXTRA_SUMMON:
				summon_count = 1 + int(rune.value)
			RuneData.Effect.SPLASH_HEAL:
				splash_radius = rune.value
	# Grave-Chill: everything you do lands for less while it lasts.
	var death_handler := caster.get_node_or_null("DeathHandler") as DeathHandler
	var output := death_handler.output_multiplier() if death_handler else 1.0
	if ability.spends_all_resource:
		# Scales with what you had banked: the more of the fight you carried,
		# the harder the finisher lands.
		power = int(round(float(ability.power) * (0.5 + float(spent_resource) / 50.0)))
	if output != 1.0:
		power = maxi(1, int(round(float(power) * output)))
	# The spec passive: a Lance hits harder, a Hymn heals for more.
	var heals: bool = effect in [AbilityData.Effect.HEAL, AbilityData.Effect.AOE_HEAL, AbilityData.Effect.HOT]
	var hurts: bool = effect in [AbilityData.Effect.DAMAGE, AbilityData.Effect.AOE_DAMAGE, AbilityData.Effect.DOT, AbilityData.Effect.DRAIN, AbilityData.Effect.STACK, AbilityData.Effect.STUN, AbilityData.Effect.INTERRUPT, AbilityData.Effect.TAUNT]
	if heals:
		power = int(round(float(power) * SpecDatabase.multiplier(spec, "healing_mult")))
	elif hurts:
		power = int(round(float(power) * SpecDatabase.multiplier(spec, "damage_mult")))
	# Respects paid at a gravestone: a little more of everything.
	var respects := StatusEffect.output_multiplier(caster)
	if respects != 1.0 and (heals or hurts):
		power = int(round(float(power) * respects))
	if charged:
		power *= 2
	# Gear. Flat, so a level-8 ring is still worth exactly what it says at 20.
	var caster_stats := caster.get_node_or_null("Stats") as Stats
	if caster_stats:
		power += caster_stats.total_power()
	# The slayer rings: a fifth again against the kind of thing they hate.
	if target is Mob and caster.has_method("get_inventory"):
		var inventory = caster.get_inventory()
		if inventory:
			power = _apply_slayer(power, inventory, target as Mob)

	match effect:
		AbilityData.Effect.DAMAGE:
			if target and ability.execute:
				# Widow's Thrust: up to double on something nearly dead.
				var victim_stats := target.get_node_or_null("Stats") as Stats
				if victim_stats and victim_stats.max_health > 0:
					var fraction := float(victim_stats.health) / float(victim_stats.max_health)
					power = int(round(float(power) * (2.0 - clampf(fraction, 0.0, 1.0))))
			if target and ability.consumes != &"":
				# Crescendo: every bleed at once, and then silence.
				power += ability.consume_bonus * StatusEffect.consume_stacks(target, ability.consumes)
			_damage(target, power, caster_peer)
			# A forking rune carries a share to the nearest other enemies.
			if chain_targets > 0 and target:
				var chained := 0
				for victim in _hostiles_near(target.global_position, 12.0):
					if victim == target or chained >= chain_targets:
						continue
					_damage(victim, int(round(float(power) * falloff)), caster_peer)
					chained += 1
		AbilityData.Effect.AOE_DAMAGE:
			var centre: Node3D = target if target else caster
			var blasts := maxi(1, ability.line_count)
			var step := Vector3.ZERO
			if blasts > 1:
				# Bombardment: the charges walk away from the caster in a line.
				step = centre.global_position - caster.global_position
				step.y = 0.0
				step = step.normalized() * radius * 1.6 if step.length() > 0.1 else -caster.global_transform.basis.z * radius * 1.6
			var struck := {}
			for index in range(blasts):
				for victim in _hostiles_near(centre.global_position + step * float(index), radius):
					if struck.has(victim):
						continue
					struck[victim] = true
					_damage(victim, power, caster_peer)
		AbilityData.Effect.HEAL:
			var healed: Node3D = target if target else caster
			if ability.low_health_bonus > 1.0:
				# Triage: a good deal stronger on someone under forty percent.
				var healed_stats := healed.get_node_or_null("Stats") as Stats
				if healed_stats and float(healed_stats.health) < 0.4 * float(healed_stats.max_health):
					power = int(round(float(power) * ability.low_health_bonus))
			_heal(healed, power)
			if splash_radius > 0.0:
				for friend in _friendlies_near(healed.global_position, splash_radius):
					if friend != healed:
						_heal(friend, int(round(float(power) * falloff)))
		AbilityData.Effect.AOE_HEAL:
			for friend in _friendlies_near(caster.global_position, radius):
				_heal(friend, power)
		AbilityData.Effect.DOT:
			DamageOverTime.apply(target, power, duration, tick, caster_peer, ability.id)
			if target and ability.weaken > 0.0:
				# Mocking Verse: they hit softer while it lasts.
				StatusEffect.apply(target, StatusEffect.Kind.WEAKEN, ability.id, ability.weaken, duration)
			if radius > 0.0 and target:
				# A spreading rune takes hold of everything around the target.
				for victim in _hostiles_near(target.global_position, radius):
					if victim != target:
						DamageOverTime.apply(
							victim, int(round(float(power) * falloff)), duration, tick, caster_peer, ability.id
						)
		AbilityData.Effect.DRAIN:
			_damage(target, power, caster_peer)
			_heal(caster, int(round(float(power) * drain_ratio)))
		AbilityData.Effect.TAUNT:
			if radius > 0.0:
				# Claiming everything nearby, rather than one thing for longer.
				for victim in _hostiles_near(caster.global_position, radius):
					var each := victim as Mob
					if each:
						each.force_target(caster, duration)
					_damage(victim, power, caster_peer)
			else:
				var mob := target as Mob
				if mob:
					mob.force_target(caster, duration)
					if ability.root_seconds > 0.0:
						# Grave Claim: yours, and going nowhere.
						mob.apply_speed_modifier(0.05, ability.root_seconds)
				_damage(target, power, caster_peer)
		AbilityData.Effect.SUMMON:
			for index in range(summon_count):
				_summon(ability, caster, index, duration, falloff if summon_count > 1 else 1.0)
		AbilityData.Effect.SPEED:
			if ability.speed_multiplier < 1.0:
				_damage(target, power, caster_peer)
			if ability.speed_multiplier >= 1.0 and radius > 0.0:
				# A march is for the whole party: everyone in earshot, one press.
				for friend in _friendlies_near(caster.global_position, radius):
					_apply_speed(friend, ability.speed_multiplier, duration)
			else:
				_apply_speed(target if target else caster, ability.speed_multiplier, duration)
		AbilityData.Effect.INTERRUPT:
			# The damage is a consolation; the cast stopping is the ability.
			_damage(target, power, caster_peer)
			if target and target.has_method("interrupt_cast"):
				var stopped := str(target.cast_name) if target.get("cast_name") != null else ""
				if target.interrupt_cast(caster_peer):
					CombatRecorder.record_interrupt(caster_peer, stopped)
		AbilityData.Effect.DAMAGE_REDUCTION:
			var shielded: Node3D = target if target else caster
			StatusEffect.apply(shielded, StatusEffect.Kind.DAMAGE_REDUCTION, ability.id, ability.reduction, duration)
			if radius > 0.0:
				for friend in _friendlies_near(shielded.global_position, radius):
					if friend != shielded:
						StatusEffect.apply(friend, StatusEffect.Kind.DAMAGE_REDUCTION, ability.id, ability.reduction * falloff, duration)
		AbilityData.Effect.STUN:
			_damage(target, power, caster_peer)
			_apply_stun(target, duration)
			if radius > 0.0 and target:
				for victim in _hostiles_near(target.global_position, radius):
					if victim != target:
						_apply_stun(victim, duration * falloff)
		AbilityData.Effect.STACK:
			StatusEffect.apply(target, StatusEffect.Kind.STACK, ability.id, float(power), duration, ability.tick_seconds, caster_peer, ability.max_stacks)
		AbilityData.Effect.HOT:
			var mended: Node3D = target if target else caster
			if _target_rule(ability) == AbilityData.TargetRule.GROUND and radius > 0.0:
				# A party song (Anthem, Tonic): everyone in earshot, in full.
				for friend in _friendlies_near(caster.global_position, radius):
					StatusEffect.apply(friend, StatusEffect.Kind.HOT, ability.id, float(power), duration, tick, caster_peer)
					if ability.cleanses and friend.has_method("apply_cleanse"):
						friend.apply_cleanse()
			else:
				StatusEffect.apply(mended, StatusEffect.Kind.HOT, ability.id, float(power), duration, tick, caster_peer)
				if radius > 0.0:
					for friend in _friendlies_near(mended.global_position, radius):
						if friend != mended:
							StatusEffect.apply(friend, StatusEffect.Kind.HOT, ability.id, float(power) * falloff, duration, tick, caster_peer)
		AbilityData.Effect.DASH:
			# A short leap the way you are facing, and out of whatever held you.
			var body_node := caster.get_node_or_null("Body") as Node3D
			var forward: Vector3 = body_node.global_basis.z if body_node else -caster.global_transform.basis.z
			forward.y = 0.0
			if forward.length() < 0.1:
				forward = Vector3.FORWARD
			var landing := caster.global_position + forward.normalized() * DASH_METRES
			if caster.has_method("teleport_to"):
				caster.teleport_to(landing)
			else:
				caster.global_position = landing
			if caster.has_method("apply_cleanse"):
				caster.apply_cleanse()
		AbilityData.Effect.UNKILLABLE:
			StatusEffect.apply(caster, StatusEffect.Kind.UNKILLABLE, ability.id, 1.0, duration)
		AbilityData.Effect.CHEAT_DEATH:
			StatusEffect.apply(caster, StatusEffect.Kind.CHEAT_DEATH, ability.id, ability.reduction, duration)
		AbilityData.Effect.CHARGES:
			var bank := StatusEffect.apply(caster, StatusEffect.Kind.CHARGES, ability.charges_ability, 1.0, duration, 1.0, caster_peer, ability.charges)
			if bank:
				bank.stacks = ability.charges
		AbilityData.Effect.HASTE_HOTS:
			StatusEffect.haste_hots(get_tree(), caster_peer, duration)
		AbilityData.Effect.BUFF:
			# A party buff reaches everyone in earshot; with no radius it is
			# just the caster (or the ally they picked).
			if radius > 0.0:
				for friend in _friendlies_near(caster.global_position, radius):
					StatusEffect.apply(friend, StatusEffect.Kind.BUFF, ability.id, float(power), duration)
			else:
				StatusEffect.apply(target if target else caster, StatusEffect.Kind.BUFF, ability.id, float(power), duration)

	# The spec passive's chain: Hymn's Marching Air also sings Soothing Verse;
	# Dirge's Cutting Chord also opens a bleed.
	var chained_id := SpecDatabase.chained(spec, ability.id)
	if chained_id != &"" and not _chaining:
		var chained_ability := AbilityDatabase.get_ability(chained_id)
		if chained_ability:
			_chaining = true
			if _target_rule(ability) == AbilityData.TargetRule.GROUND and radius > 0.0:
				# A party song chains onto everyone it reached.
				for friend in _friendlies_near(caster.global_position, radius):
					_execute(chained_ability, caster, friend, 0)
			else:
				_execute(chained_ability, caster, target, 0)
			_chaining = false
			_current_ability = ability.id


## Refuse the Grave went off: everything within eight metres pays for it.
func _on_cheated_death() -> void:
	var body := _get_body()
	if body == null or not multiplayer.is_server():
		return
	var refuse := AbilityDatabase.get_ability(&"necro_refuse")
	var share := refuse.power if refuse else 30
	_current_ability = &"necro_refuse"
	var drained := 0
	for victim in _hostiles_near(body.global_position, 8.0):
		_damage(victim, share, body.get_multiplayer_authority())
		drained += share
	if drained > 0:
		_heal(body, drained)


## The world-owned uniques: rings that do something no raid drop does.
func _apply_slayer(power: int, inventory, mob: Mob) -> int:
	if mob == null or mob.mob_data == null:
		return power
	var tags: Array = mob.mob_data.tags
	var bonus := 1.0
	if inventory.has_effect(&"beast_slayer") and tags.has(&"beast"):
		bonus = 1.2
	elif inventory.has_effect(&"soldier_slayer") and tags.has(&"soldier"):
		bonus = 1.2
	elif inventory.has_effect(&"undead_slayer") and (tags.has(&"undead") or tags.has(&"risen")):
		bonus = 1.2
	return int(round(float(power) * bonus))


func _damage(target: Node3D, amount: int, caster_peer: int) -> void:
	if target == null or amount <= 0:
		return
	var stats := target.get_node_or_null("Stats") as Stats
	if stats and not stats.is_dead:
		stats.apply_damage(amount, caster_peer, _current_ability)


func _heal(target: Node3D, amount: int) -> void:
	if target == null or amount <= 0:
		return
	var stats := target.get_node_or_null("Stats") as Stats
	if stats and not stats.is_dead:
		var body := _get_body()
		stats.heal(amount, body.get_multiplayer_authority() if body else 0, _current_ability)


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


func _summon(
	ability: AbilityData, caster: Node3D, index: int = 0, duration_override: float = 0.0, strength: float = 1.0
) -> void:
	if ability.summon_mob_id == &"":
		return
	var container := _find_mob_container()
	if container == null:
		return
	# Spread multiples out so a Grave Tide doesn't stack inside itself.
	var angle := TAU * float(index) / 3.0
	var offset := Vector3(cos(angle) * 1.6, 0.0, sin(angle) * 1.6) if index > 0 else Vector3.ZERO
	var spot := caster.global_position + caster.global_transform.basis.z * -2.5 + offset
	var pet := container.spawn_mob(ability.summon_mob_id, spot, false) as Mob
	if pet == null:
		return
	var seconds := ability.summon_seconds
	if duration_override > 0.0 and ability.duration_seconds > 0.0:
		seconds = ability.summon_seconds * (duration_override / ability.duration_seconds)
	elif duration_override > 0.0:
		seconds = duration_override
	# Grave: levies last longer.
	seconds *= SpecDatabase.multiplier(_spec_id(), "summon_mult")
	pet.become_pet(caster.get_multiplayer_authority(), seconds)
	# Artillery: turrets fire faster. More of them means weaker ones.
	var swing := SpecDatabase.multiplier(_spec_id(), "pet_attack_mult")
	if (strength < 1.0 or swing != 1.0) and pet.mob_data:
		var tuned: MobData = pet.mob_data.duplicate()
		tuned.attack_cooldown = maxf(0.3, tuned.attack_cooldown * swing)
		if strength < 1.0:
			tuned.max_health = maxi(1, int(round(float(tuned.max_health) * strength)))
			tuned.damage = maxi(1, int(round(float(tuned.damage) * strength)))
		pet.mob_data = tuned
		var pet_stats := pet.get_node_or_null("Stats") as Stats
		if pet_stats and strength < 1.0:
			pet_stats.max_health = tuned.max_health
			pet_stats.health = tuned.max_health


## Turn a single-target effect into its area equivalent, for MAKE_AOE runes.
func _as_area(effect: AbilityData.Effect) -> AbilityData.Effect:
	match effect:
		AbilityData.Effect.DAMAGE:
			return AbilityData.Effect.AOE_DAMAGE
		AbilityData.Effect.HEAL:
			return AbilityData.Effect.AOE_HEAL
		_:
			return effect


## And back again, for FOCUS runes.
func _as_single(effect: AbilityData.Effect) -> AbilityData.Effect:
	match effect:
		AbilityData.Effect.AOE_DAMAGE:
			return AbilityData.Effect.DAMAGE
		AbilityData.Effect.AOE_HEAL:
			return AbilityData.Effect.HEAL
		_:
			return effect


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


func _apply_stun(target: Node3D, duration: float) -> void:
	if target == null or duration <= 0.0:
		return
	if target.has_method("apply_stun"):
		target.apply_stun(duration)
