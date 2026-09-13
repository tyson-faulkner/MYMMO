# StatusEffect — a timed thing sitting on a character: damage reduction, a
# stacking bleed, a heal over time, a party buff.
#
# The mirror of DamageOverTime, generalised. Lives as a child of the thing it
# affects, ticks on the server only, and removes itself when spent. Anything
# that needs to know "is this person shielded / bleeding / buffed" asks the
# static helpers, which just read the children. Stuns are not stored here:
# they need the body to stop moving, so Mob and Player own their own stun clock
# and the ability bar calls apply_stun() on them directly.
class_name StatusEffect
extends Node

enum Kind {
	DAMAGE_REDUCTION,  ## value = share of incoming damage removed (0.4 = 40% less).
	STACK,             ## value = damage per tick PER STACK. Re-applying adds a stack.
	HOT,               ## value = healing per tick.
	BUFF,              ## value = flat power added to every hit and heal.
	WEAKEN,            ## value = share taken off the bearer's own hits (Mocking Verse).
	UNKILLABLE,        ## the bearer cannot drop below 1 health (Last Stand).
	CHEAT_DEATH,       ## value = share of max health lethal damage leaves instead (Refuse the Grave).
	CHARGES,           ## stacks = free, doubled casts of the ability named by effect_id.
	OUTPUT_MULT        ## value = share added to everything the bearer does (paying respects: 0.05).
}

## Chorus: heals-over-time from this peer tick twice as fast until then.
var hasted_until_msec: int = 0

## Floor on what damage reduction can leave. Two Wingguards do not make you immortal.
const MIN_DAMAGE_SHARE := 0.15

var kind: Kind = Kind.DAMAGE_REDUCTION
## Which ability put it here, so the same effect refreshes instead of piling up.
var effect_id: StringName = &""
var value: float = 0.0
var stacks: int = 1
var max_stacks: int = 1
var remaining_seconds: float = 0.0
var tick_seconds: float = 1.0
var source_peer_id: int = 0

var _accumulated: float = 0.0


## Server only. Puts the effect on `target`, or refreshes the one already there
## from the same ability. For STACK that also adds a stack, up to the cap.
static func apply(
	target: Node, kind_in: Kind, id: StringName, amount: float, duration: float,
	interval: float = 1.0, caster_peer_id: int = 0, stack_cap: int = 1
) -> StatusEffect:
	if target == null or duration <= 0.0:
		return null
	var existing := find(target, kind_in, id)
	if existing:
		existing.remaining_seconds = maxf(existing.remaining_seconds, duration)
		existing.value = amount
		existing.max_stacks = maxi(1, stack_cap)
		if kind_in == Kind.STACK:
			existing.stacks = mini(existing.max_stacks, existing.stacks + 1)
		return existing
	var effect := StatusEffect.new()
	effect.name = "Status_%s_%d" % [id, Time.get_ticks_msec()]
	effect.kind = kind_in
	effect.effect_id = id
	effect.value = amount
	effect.max_stacks = maxi(1, stack_cap)
	effect.remaining_seconds = duration
	effect.tick_seconds = maxf(0.25, interval)
	effect.source_peer_id = caster_peer_id
	target.add_child(effect)
	return effect


static func all_on(target: Node) -> Array[StatusEffect]:
	var found: Array[StatusEffect] = []
	if target == null:
		return found
	for child in target.get_children():
		var effect := child as StatusEffect
		if effect and not effect.is_queued_for_deletion():
			found.append(effect)
	return found


static func find(target: Node, kind_in: Kind, id: StringName) -> StatusEffect:
	for effect in all_on(target):
		if effect.kind == kind_in and effect.effect_id == id:
			return effect
	return null


## What share of a hit gets through, 1.0 when nothing is protecting them.
## Reductions multiply, so two 40% shields leave 36%, not 20%.
static func damage_multiplier(target: Node) -> float:
	var share := 1.0
	for effect in all_on(target):
		if effect.kind == Kind.DAMAGE_REDUCTION:
			share *= clampf(1.0 - effect.value, 0.0, 1.0)
	return maxf(MIN_DAMAGE_SHARE, share)


static func find_kind(target: Node, kind_in: Kind) -> StatusEffect:
	for effect in all_on(target):
		if effect.kind == kind_in:
			return effect
	return null


static func has_kind(target: Node, kind_in: Kind) -> bool:
	return find_kind(target, kind_in) != null


## What the bearer's own hits are multiplied by: 0.9 under one Mocking Verse.
static func weaken_multiplier(target: Node) -> float:
	var share := 1.0
	for effect in all_on(target):
		if effect.kind == Kind.WEAKEN:
			share *= clampf(1.0 - effect.value, 0.0, 1.0)
	return maxf(0.25, share)


## Free casts banked for an ability (The Last Note).
static func charges(target: Node, ability_id: StringName) -> int:
	var effect := find(target, Kind.CHARGES, ability_id)
	return effect.stacks if effect else 0


static func use_charge(target: Node, ability_id: StringName) -> bool:
	var effect := find(target, Kind.CHARGES, ability_id)
	if effect == null or effect.stacks <= 0:
		return false
	effect.stacks -= 1
	if effect.stacks <= 0:
		effect.queue_free()
	return true


## Chorus: every heal-over-time this peer has running, anywhere, doubles its
## rate for a while.
static func haste_hots(tree: SceneTree, caster_peer_id: int, seconds: float) -> int:
	var hasted := 0
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	for container in tree.get_nodes_in_group("Players"):
		for character in container.get_children():
			for effect in all_on(character):
				if effect.kind == Kind.HOT and effect.source_peer_id == caster_peer_id:
					effect.hasted_until_msec = until
					hasted += 1
	return hasted


## What the bearer's damage and healing are multiplied by: 1.05 after
## paying respects at a gravestone.
static func output_multiplier(target: Node) -> float:
	var total := 1.0
	for effect in all_on(target):
		if effect.kind == Kind.OUTPUT_MULT:
			total += effect.value
	return total


## Flat power from every buff on them, added to hits and heals.
static func power_bonus(target: Node) -> int:
	var total := 0.0
	for effect in all_on(target):
		if effect.kind == Kind.BUFF:
			total += effect.value
	return int(round(total))


static func stack_count(target: Node, id: StringName) -> int:
	var effect := find(target, Kind.STACK, id)
	return effect.stacks if effect else 0


## Takes every stack off and says how many there were: a finisher that "eats
## the bleeds" (Crescendo) reads its bonus off this.
static func consume_stacks(target: Node, id: StringName) -> int:
	var effect := find(target, Kind.STACK, id)
	if effect == null:
		return 0
	var had := effect.stacks
	effect.queue_free()
	return had


func _process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		queue_free()
		return
	var stats := get_parent().get_node_or_null("Stats") as Stats
	if stats == null or stats.is_dead:
		queue_free()
		return
	remaining_seconds -= delta
	_accumulated += delta
	var interval := tick_seconds
	if kind == Kind.HOT and Time.get_ticks_msec() < hasted_until_msec:
		interval = tick_seconds * 0.5
	while _accumulated >= interval:
		_accumulated -= interval
		match kind:
			Kind.STACK:
				stats.apply_damage(maxi(1, int(round(value * float(stacks)))), source_peer_id, effect_id)
				if stats.is_dead:
					queue_free()
					return
			Kind.HOT:
				stats.heal(maxi(1, int(round(value))), source_peer_id, effect_id)
	if remaining_seconds <= 0.0:
		queue_free()
