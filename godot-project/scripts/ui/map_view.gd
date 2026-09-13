# MapView — the minimap, and the big map, which are the same drawing at two
# sizes. North is up. Everything on it is derived: the player, party members
# in their class colours, enemies nearby, NPCs with their quest marks, and a
# translucent numbered circle over every objective area. The tracked
# objective gets an arrow on the edge with a distance, or "you're here".
class_name MapView
extends Control

var follow: Node3D = null
var metres_per_pixel: float = 0.7
## Enemies further than this are not drawn (the minimap only).
var enemy_range: float = 70.0
var areas: Array = []
var tracked: Dictionary = {}
var big: bool = false

var _redraw_accumulated: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(delta: float) -> void:
	_redraw_accumulated += delta
	if _redraw_accumulated >= 0.1:
		_redraw_accumulated = 0.0
		queue_redraw()


func _to_local(world: Vector3) -> Vector2:
	if follow == null:
		return size * 0.5
	var delta := world - follow.global_position
	return size * 0.5 + Vector2(delta.x, delta.z) / metres_per_pixel


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.1, 0.09, 0.82))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.62, 0.35, 0.9), false, 2.0)
	if follow == null or not is_instance_valid(follow):
		return
	var centre := size * 0.5
	# Objective areas, numbered to match the log.
	for area in areas:
		var at := _to_local(area["centre"])
		var radius := float(area["radius"]) / metres_per_pixel
		var is_tracked: bool = not tracked.is_empty() and area.get("quest_id") == tracked.get("quest_id") and int(area.get("index", -1)) == int(tracked.get("index", -2))
		draw_circle(at, radius, Color(1.0, 0.85, 0.4, 0.28 if is_tracked else 0.16))
		draw_arc(at, radius, 0.0, TAU, 32, Color(1.0, 0.85, 0.4, 0.9 if is_tracked else 0.5), 1.5)
		draw_string(font, at + Vector2(-4, 5), str(area.get("number", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.92, 0.6))
	# NPCs and their marks.
	for node in get_tree().get_nodes_in_group("NPCs"):
		var npc := node as Node3D
		if npc == null:
			continue
		var at := _to_local(npc.global_position)
		if not Rect2(Vector2.ZERO, size).has_point(at):
			continue
		draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), Color(0.95, 0.9, 0.7))
		var marker := npc.get_node_or_null("QuestMarker") as Label3D
		if marker and marker.visible and not marker.text.is_empty():
			draw_string(font, at + Vector2(5, -4), marker.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, marker.modulate)
	# Enemies close enough to matter.
	for node in get_tree().get_nodes_in_group("Hostiles"):
		var mob := node as Mob
		if mob == null or not mob.is_inside_tree():
			continue
		var stats := mob.get_node_or_null("Stats") as Stats
		if stats and stats.is_dead:
			continue
		if follow.global_position.distance_to(mob.global_position) > enemy_range and not big:
			continue
		var at := _to_local(mob.global_position)
		if not Rect2(Vector2.ZERO, size).has_point(at):
			continue
		var colour := Color(0.45, 0.75, 1.0) if mob.is_friendly else (Color(1.0, 0.55, 0.2) if mob.mob_data and mob.mob_data.is_boss else Color(0.95, 0.3, 0.25))
		draw_circle(at, 3.0 if mob.mob_data and mob.mob_data.is_boss else 2.0, colour)
	# Party members, class coloured.
	var local_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	for container in get_tree().get_nodes_in_group("Players"):
		for child in container.get_children():
			var member := child as Node3D
			if member == null or member == follow:
				continue
			if not PartyManager.members_of(local_id).has(int(str(member.name)) if str(member.name).is_valid_int() else -1):
				continue
			var member_stats := member.get_node_or_null("Stats") as Stats
			var class_id: StringName = member_stats.class_data.id if member_stats and member_stats.class_data else &"valkyr"
			var at := _to_local(member.global_position)
			draw_circle(at, 4.0, CombatRecorder.CLASS_COLOURS.get(class_id, Color.WHITE))
	# The player: a triangle pointing the way the body faces.
	var body := follow.get_node_or_null("Body") as Node3D
	var forward := Vector2(0, -1)
	if body:
		var facing := body.global_basis.z
		forward = Vector2(facing.x, facing.z).normalized() if facing.length() > 0.01 else forward
	var tip := centre + forward * 7.0
	var left := centre + forward.rotated(2.4) * 6.0
	var right := centre + forward.rotated(-2.4) * 6.0
	draw_colored_polygon(PackedVector2Array([tip, left, right]), Color.WHITE)
	# The tracked objective: an edge arrow with distance, or "you're here".
	if not tracked.is_empty():
		var goal: Vector3 = tracked["centre"]
		var flat := goal - follow.global_position
		flat.y = 0.0
		var distance := flat.length()
		var inside := distance <= float(tracked["radius"])
		var label := "%s · here" % tracked.get("short", "") if inside else "%s · %dm" % [tracked.get("short", ""), int(distance)]
		if inside:
			draw_string(font, Vector2(6, size.y - 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 1.0, 0.6))
		else:
			var direction := Vector2(flat.x, flat.z).normalized()
			var edge := centre + direction * (minf(size.x, size.y) * 0.5 - 10.0)
			var arrow_tip := edge + direction * 8.0
			var arrow_left := edge + direction.rotated(2.5) * 6.0
			var arrow_right := edge + direction.rotated(-2.5) * 6.0
			draw_colored_polygon(PackedVector2Array([arrow_tip, arrow_left, arrow_right]), Color(1.0, 0.85, 0.4))
			draw_string(font, Vector2(6, size.y - 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.9, 0.6))
	if big:
		draw_string(font, Vector2(8, 16), "%.0f metres across — M to close" % (size.x * metres_per_pixel), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.78, 0.7))
