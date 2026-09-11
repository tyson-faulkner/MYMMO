# DamageOverTime — a effect that keeps hurting after the cast ends.
#
# Lives as a child of the thing being hurt, ticks on the server only, and
# removes itself when it's spent. Stats broadcasts each tick's health change, so
# clients see it without this node existing on their side at all.
class_name DamageOverTime
extends Node

var damage_per_tick: int = 0
var tick_seconds: float = 1.0
var remaining_seconds: float = 0.0
var source_peer_id: int = 0

var _accumulated: float = 0.0


static func apply(
	target: Node, amount: int, duration: float, interval: float, caster_peer_id: int
) -> DamageOverTime:
	if target == null or amount <= 0 or duration <= 0.0:
		return null
	var effect := DamageOverTime.new()
	effect.name = "DoT_%d" % Time.get_ticks_msec()
	effect.damage_per_tick = amount
	effect.tick_seconds = maxf(0.25, interval)
	effect.remaining_seconds = duration
	effect.source_peer_id = caster_peer_id
	target.add_child(effect)
	return effect


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
	while _accumulated >= tick_seconds:
		_accumulated -= tick_seconds
		stats.apply_damage(damage_per_tick, source_peer_id)
		if stats.is_dead:
			queue_free()
			return
	if remaining_seconds <= 0.0:
		queue_free()
