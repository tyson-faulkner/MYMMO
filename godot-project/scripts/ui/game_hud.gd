# GameHUD — health, resource, experience, your target, your action bar and what
# you are supposed to be doing.
#
# Purely a view. It reads signals and draws; it never decides anything. The
# action bar buttons call into AbilityBar, which asks the server, same as
# pressing the key would.
class_name GameHUD
extends CanvasLayer

const SLOT_COUNT := 7
const LOW_HEALTH_FRACTION := 0.35

var _player: Node3D = null
var _stats: Stats = null
var _quest_log: QuestLog = null
var _targeting: Targeting = null
var _ability_bar: AbilityBar = null
var _death: DeathHandler = null

var _slot_buttons: Array[Button] = []
var _slot_cooldowns: Array[Label] = []

@onready var _player_name: Label = $PlayerFrame/Margin/Rows/NameRow/PlayerName
@onready var _player_level: Label = $PlayerFrame/Margin/Rows/NameRow/PlayerLevel
@onready var _health_bar: ProgressBar = $PlayerFrame/Margin/Rows/HealthBar
@onready var _health_text: Label = $PlayerFrame/Margin/Rows/HealthBar/Text
@onready var _resource_bar: ProgressBar = $PlayerFrame/Margin/Rows/ResourceBar
@onready var _resource_text: Label = $PlayerFrame/Margin/Rows/ResourceBar/Text
@onready var _xp_bar: ProgressBar = $PlayerFrame/Margin/Rows/XPBar
@onready var _currency: Label = $PlayerFrame/Margin/Rows/Currency

@onready var _target_frame: PanelContainer = $TargetFrame
@onready var _target_name: Label = $TargetFrame/Margin/Rows/TargetName
@onready var _target_health: ProgressBar = $TargetFrame/Margin/Rows/TargetHealth
## The target's cast bar, built in code under the health bar: fills while an
## enemy winds up, orange if you can stop it, red if you can't.
var _target_cast: ProgressBar = null
var _target_cast_text: Label = null

## The meter: one bar per fighter, three switchable columns, fed by the
## server's recorder. And the recap that replaces it for 20s when a boss dies.
const METER_COLUMNS := ["damage", "healing", "taken"]
const METER_TITLES := {"damage": "Damage", "healing": "Healing", "taken": "Damage Taken"}
var _meter: PanelContainer = null
var _meter_title: Button = null
var _meter_rows: VBoxContainer = null
var _meter_column: int = 0
var _recap: PanelContainer = null
var _recap_rows: VBoxContainer = null
var _coach: PanelContainer = null
var _coach_rows: VBoxContainer = null
var _recap_timer: float = 0.0

@onready var _action_bar: HBoxContainer = $ActionBar/Slots
@onready var _tracker: VBoxContainer = $QuestTracker/Rows
@onready var _quest_panel: PanelContainer = $QuestLogPanel
@onready var _quest_panel_rows: VBoxContainer = $QuestLogPanel/Margin/Scroll/Rows
@onready var _toast: Label = $Toast
@onready var _death_panel: PanelContainer = $DeathPanel
@onready var _corpse_distance: Label = $DeathPanel/Margin/Rows/CorpseDistance
@onready var _release_button: Button = $DeathPanel/Margin/Rows/ReleaseButton
@onready var _sickness: Label = $Sickness


func _ready() -> void:
	_build_action_bar()
	_build_target_cast_bar()
	_build_meter()
	_build_recap()
	CombatRecorder.meter_updated.connect(_on_meter_updated)
	CombatRecorder.fight_ended.connect(_on_fight_ended)
	_target_frame.visible = false
	_quest_panel.visible = false
	_toast.visible = false
	_death_panel.visible = false
	_sickness.visible = false
	_release_button.pressed.connect(_on_release_pressed)
	visible = false
	set_process(true)


func _process(delta: float) -> void:
	# The local character doesn't exist until you've joined, and it's replaced
	# on every reconnect, so the HUD keeps checking rather than assuming.
	if _player == null or not is_instance_valid(_player):
		_attach_to_local_player()
		return
	visible = true
	_refresh_target_frame()
	_refresh_cooldowns()
	_refresh_death_panel()
	if _recap_timer > 0.0:
		_recap_timer -= delta
		if _recap_timer <= 0.0 and _recap and not _coach.visible:
			_recap.visible = false


# --- The meter, the recap, the coach -----------------------------------------


func _build_meter() -> void:
	_meter = PanelContainer.new()
	_meter.name = "Meter"
	_meter.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_meter.anchor_left = 1.0
	_meter.anchor_right = 1.0
	_meter.anchor_top = 0.5
	_meter.anchor_bottom = 0.5
	_meter.offset_left = -290
	_meter.offset_right = -16
	_meter.offset_top = -60
	_meter.offset_bottom = 60
	_meter.visible = false
	add_child(_meter)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_meter.add_child(margin)
	var rows := VBoxContainer.new()
	margin.add_child(rows)
	_meter_title = Button.new()
	_meter_title.flat = true
	_meter_title.text = "Damage   ⇄"
	_meter_title.tooltip_text = "Click to switch column"
	_meter_title.pressed.connect(func() -> void:
		_meter_column = (_meter_column + 1) % METER_COLUMNS.size()
		_refresh_meter(CombatRecorder.live))
	rows.add_child(_meter_title)
	_meter_rows = VBoxContainer.new()
	rows.add_child(_meter_rows)


func _on_meter_updated(live: Dictionary) -> void:
	_refresh_meter(live)


func _refresh_meter(live: Dictionary) -> void:
	if _meter == null:
		return
	for child in _meter_rows.get_children():
		child.queue_free()
	if live.is_empty():
		_meter.visible = false
		return
	_meter.visible = true
	var column: String = METER_COLUMNS[_meter_column]
	_meter_title.text = "%s   ⇄" % METER_TITLES[column]
	var peers := live.keys()
	peers.sort_custom(func(a, b) -> bool: return int(live[a][column]) > int(live[b][column]))
	var top := 1
	for peer_id in peers:
		top = maxi(top, int(live[peer_id][column]))
	var local_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	for peer_id in peers:
		var entry: Dictionary = live[peer_id]
		var row := Button.new()
		row.flat = true
		row.custom_minimum_size = Vector2(0, 22)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var bar := ProgressBar.new()
		bar.max_value = top
		bar.value = int(entry[column])
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_FULL_RECT)
		bar.modulate = CombatRecorder.CLASS_COLOURS.get(StringName(str(entry.get("class", ""))), Color.WHITE)
		bar.modulate.a = 0.55
		row.add_child(bar)
		row.text = "  %s   %d" % [entry.get("name", "?"), int(entry[column])]
		if int(peer_id) == local_id:
			row.tooltip_text = "Click for your abilities and the coach"
			row.pressed.connect(_show_coach)
		_meter_rows.add_child(row)


func _build_recap() -> void:
	_recap = PanelContainer.new()
	_recap.name = "Recap"
	_recap.set_anchors_preset(Control.PRESET_CENTER)
	_recap.offset_left = -240
	_recap.offset_right = 240
	_recap.offset_top = -200
	_recap.offset_bottom = 200
	_recap.visible = false
	add_child(_recap)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_recap.add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	_recap_rows = VBoxContainer.new()
	_recap_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_recap_rows)

	_coach = PanelContainer.new()
	_coach.name = "Coach"
	_coach.set_anchors_preset(Control.PRESET_CENTER)
	_coach.offset_left = -240
	_coach.offset_right = 240
	_coach.offset_top = -180
	_coach.offset_bottom = 180
	_coach.visible = false
	add_child(_coach)
	var coach_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		coach_margin.add_theme_constant_override("margin_" + side, 12)
	_coach.add_child(coach_margin)
	_coach_rows = VBoxContainer.new()
	coach_margin.add_child(_coach_rows)


func _on_fight_ended(recap: Dictionary) -> void:
	_show_recap(recap)


func _show_recap(recap: Dictionary) -> void:
	if _recap == null:
		return
	for child in _recap_rows.get_children():
		child.queue_free()
	var local_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var tier := int(recap.get("tier", 0))
	var title := "%s%s — %s" % [
		recap.get("boss_name", "?"),
		"  ⟨%s⟩" % GrudgeLedger.roman(tier) if tier > 0 else "",
		"wiped" if bool(recap.get("wiped", false)) else CombatRecorder.format_seconds(float(recap.get("seconds", 0.0)))
	]
	var best := float(recap.get("best_seconds", 0.0))
	if best > 0.0 and not bool(recap.get("wiped", false)):
		title += "   (best %s)" % CombatRecorder.format_seconds(best)
	_recap_line(title, Color(1, 0.85, 0.45), 18)
	var names: Dictionary = recap.get("names", {})
	for column in METER_COLUMNS:
		var totals: Dictionary = recap.get("columns", {}).get(column, {})
		var parts := []
		var peers := totals.keys()
		peers.sort_custom(func(a, b) -> bool: return int(totals[a]) > int(totals[b]))
		for peer_id in peers:
			if int(totals[peer_id]) > 0:
				parts.append("%s %d" % [names.get(peer_id, "?"), int(totals[peer_id])])
		if not parts.is_empty():
			_recap_line("%s:  %s" % [METER_TITLES[column], "  ·  ".join(parts)], Color(0.9, 0.88, 0.8))
	var awards: Dictionary = recap.get("awards", {})
	if not awards.is_empty():
		_recap_line("Awards", Color(1, 0.85, 0.45), 15)
		for award in awards:
			_recap_line("   %s — %s" % [award, awards[award].get("name", "")], Color(0.85, 0.9, 0.75))
	var parse: Dictionary = recap.get("parses", {}).get(local_id, {})
	if not parse.is_empty():
		_recap_line("Your parse: %d  (%s)" % [int(parse.get("score", 0)), str(parse.get("colour", ""))], CombatRecorder.colour_for(int(parse.get("score", 0))), 17)
		_recap_line("   uptime %d/30 · rotation %d/25 · mechanics %d/25 · output %d/20" % [
			int(parse.get("uptime", 0)), int(parse.get("rotation", 0)), int(parse.get("mechanics", 0)), int(parse.get("output", 0))], Color(0.8, 0.78, 0.7))
	for line in recap.get("new_records", []):
		_recap_line("★ %s" % line, Color(1, 0.9, 0.5))
	var buttons := HBoxContainer.new()
	var coach_button := Button.new()
	coach_button.text = "Coach"
	coach_button.pressed.connect(_show_coach)
	buttons.add_child(coach_button)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void:
		_recap.visible = false
		_coach.visible = false)
	buttons.add_child(close)
	_recap_rows.add_child(buttons)
	_recap.visible = true
	_recap_timer = 20.0


func _recap_line(text: String, colour: Color, size: int = 13) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = colour
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	_recap_rows.add_child(label)


## Your abilities ranked, and three sentences about what to change.
func _show_coach() -> void:
	var recap: Dictionary = CombatRecorder.last_recap
	if recap.is_empty() or _coach == null:
		_show_toast("No boss fight recorded yet")
		return
	for child in _coach_rows.get_children():
		child.queue_free()
	var local_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var title := Label.new()
	title.text = "The coach — %s" % recap.get("boss_name", "")
	title.modulate = Color(1, 0.85, 0.45)
	title.add_theme_font_size_override("font_size", 17)
	_coach_rows.add_child(title)
	for row in recap.get("abilities", {}).get(local_id, []):
		var line := Label.new()
		line.text = "%s   %d total · %d casts · avg %d · best %d" % [row.get("name", ""), int(row.get("total", 0)), int(row.get("casts", 0)), int(row.get("average", 0)), int(row.get("biggest", 0))]
		line.modulate = Color(0.9, 0.88, 0.8)
		_coach_rows.add_child(line)
	var gap := Label.new()
	gap.text = ""
	_coach_rows.add_child(gap)
	for sentence in recap.get("coach", {}).get(local_id, []):
		var line := Label.new()
		line.text = "• " + str(sentence)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.modulate = Color(0.85, 0.9, 0.75)
		_coach_rows.add_child(line)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void: _coach.visible = false)
	_coach_rows.add_child(close)
	_coach.visible = true


# --- Death --------------------------------------------------------------


func _on_died_at(_where: Vector3) -> void:
	_death_panel.visible = true
	_show_toast("You have fallen")


func _on_resurrected() -> void:
	_death_panel.visible = false


func _on_sickness_changed(seconds_remaining: float) -> void:
	if seconds_remaining <= 0.0:
		_sickness.visible = false
		return
	_sickness.visible = true
	_sickness.text = "Grave-Chill — everything you do lands for less (%d:%02d)" % [
		int(seconds_remaining) / 60, int(seconds_remaining) % 60
	]


func _refresh_death_panel() -> void:
	if _death == null or not _death.is_ghost:
		if _death_panel.visible:
			_death_panel.visible = false
		return
	_death_panel.visible = true
	var distance := _player.global_position.distance_to(_death.corpse_position)
	if distance <= DeathHandler.CORPSE_RECLAIM_RANGE:
		_corpse_distance.text = "You are standing over your body."
	else:
		_corpse_distance.text = "Your body lies %d metres away. Walk back to it, or release." % int(distance)


func _on_release_pressed() -> void:
	if _death == null:
		return
	if multiplayer.is_server():
		_death.request_release()
	else:
		_death.request_release.rpc_id(1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quest_log"):
		_quest_panel.visible = not _quest_panel.visible
		if _quest_panel.visible:
			_rebuild_quest_panel()
		get_viewport().set_input_as_handled()


func _attach_to_local_player() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	var local_id := multiplayer.get_unique_id()
	for container in get_tree().get_nodes_in_group("Players"):
		var candidate := container.get_node_or_null(str(local_id)) as Node3D
		if candidate == null:
			continue
		_player = candidate
		_stats = candidate.get_node_or_null("Stats") as Stats
		_quest_log = candidate.get_node_or_null("QuestLog") as QuestLog
		_targeting = candidate.get_node_or_null("Targeting") as Targeting
		_ability_bar = candidate.get_node_or_null("AbilityBar") as AbilityBar
		_death = candidate.get_node_or_null("DeathHandler") as DeathHandler

		if _stats:
			_stats.health_changed.connect(_on_health_changed)
			_stats.resource_changed.connect(_on_resource_changed)
			_stats.xp_changed.connect(_on_xp_changed)
			_stats.leveled_up.connect(_on_leveled_up)
			_on_health_changed(_stats.health, _stats.max_health)
			_on_resource_changed(_stats.mana, _stats.max_mana, _stats.get_resource_label())
			_on_xp_changed(_stats.experience, Stats.xp_for_next_level(_stats.level))
		if _quest_log:
			_quest_log.log_changed.connect(_rebuild_tracker)
			_quest_log.quest_turned_in.connect(_on_quest_turned_in)
			_rebuild_tracker()
		if _ability_bar:
			_ability_bar.cast_failed.connect(_on_cast_failed)
		if _death:
			_death.died_at.connect(_on_died_at)
			_death.resurrected.connect(_on_resurrected)
			_death.sickness_changed.connect(_on_sickness_changed)
		var nickname := candidate.get_node_or_null("PlayerNick/Nickname") as Label3D
		if nickname:
			_player_name.text = nickname.text
		_refresh_slot_labels()
		return


# --- The player's own frame ------------------------------------------------


func _on_health_changed(current: int, maximum: int) -> void:
	_health_bar.max_value = maxi(1, maximum)
	_health_bar.value = current
	_health_text.text = "%d / %d" % [current, maximum]
	# Turn the bar red when things are getting serious.
	var fraction := float(current) / float(maxi(1, maximum))
	_health_bar.modulate = Color(1, 0.45, 0.4) if fraction <= LOW_HEALTH_FRACTION else Color.WHITE


func _on_resource_changed(current: int, maximum: int, label: String) -> void:
	_resource_bar.max_value = maxi(1, maximum)
	_resource_bar.value = current
	_resource_text.text = "%s   %d / %d" % [label, current, maximum]
	_refresh_slot_labels()


func _on_xp_changed(current: int, needed: int) -> void:
	if _stats:
		_player_level.text = "Level %d" % _stats.level
		if _quest_log:
			_currency.text = "%d Sovereigns" % _quest_log.currency
	if needed <= 0:
		_xp_bar.max_value = 1
		_xp_bar.value = 1
		return
	_xp_bar.max_value = needed
	_xp_bar.value = current


func _on_leveled_up(new_level: int) -> void:
	_show_toast("Level %d" % new_level)
	_refresh_slot_labels()


func _on_quest_turned_in(quest_id: StringName) -> void:
	var quest := QuestDatabase.get_quest(quest_id)
	if quest:
		_show_toast("Completed: %s" % quest.title)


func _on_cast_failed(_ability_id: StringName, reason: String) -> void:
	_show_toast(reason)


func _show_toast(message: String) -> void:
	_toast.text = message
	_toast.visible = true
	_toast.modulate = Color(1, 0.92, 0.6, 1)
	var tween := create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func() -> void: _toast.visible = false)


# --- Target frame ----------------------------------------------------------


func _refresh_target_frame() -> void:
	if _targeting == null or _targeting.current_target == null:
		_target_frame.visible = false
		return
	var target := _targeting.current_target
	if not is_instance_valid(target):
		_target_frame.visible = false
		return
	var stats := target.get_node_or_null("Stats") as Stats
	if stats == null:
		_target_frame.visible = false
		return
	_target_frame.visible = true
	var mob := target as Mob
	if mob and mob.mob_data:
		_target_name.text = "%s   (Level %d)" % [mob.mob_data.display_name, mob.mob_data.level]
	else:
		_target_name.text = str(target.name)
	_target_health.max_value = maxi(1, stats.max_health)
	_target_health.value = stats.health
	_refresh_target_cast(mob)


func _build_target_cast_bar() -> void:
	var rows := _target_health.get_parent()
	_target_cast = ProgressBar.new()
	_target_cast.name = "TargetCast"
	_target_cast.min_value = 0.0
	_target_cast.max_value = 1.0
	_target_cast.show_percentage = false
	_target_cast.custom_minimum_size = Vector2(0, 16)
	_target_cast.visible = false
	rows.add_child(_target_cast)
	_target_cast_text = Label.new()
	_target_cast_text.name = "Text"
	_target_cast_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_target_cast_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_cast_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_target_cast_text.add_theme_font_size_override("font_size", 12)
	_target_cast.add_child(_target_cast_text)


func _refresh_target_cast(mob: Mob) -> void:
	if _target_cast == null:
		return
	if mob == null or not mob.is_casting:
		_target_cast.visible = false
		return
	_target_cast.visible = true
	_target_cast.value = mob.cast_progress()
	_target_cast.modulate = Color(1.0, 0.75, 0.35) if mob.cast_interruptible else Color(1.0, 0.45, 0.4)
	_target_cast_text.text = mob.cast_name if mob.cast_interruptible else "%s  (cannot be stopped)" % mob.cast_name


# --- Action bar ------------------------------------------------------------


func _build_action_bar() -> void:
	for slot in range(1, SLOT_COUNT + 1):
		var holder := VBoxContainer.new()
		holder.custom_minimum_size = Vector2(78, 74)

		var button := Button.new()
		button.custom_minimum_size = Vector2(78, 54)
		button.clip_text = true
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_slot_pressed.bind(slot))
		holder.add_child(button)

		var keybind := Label.new()
		keybind.text = str(slot)
		keybind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		keybind.modulate = Color(0.75, 0.72, 0.62)
		holder.add_child(keybind)

		_action_bar.add_child(holder)
		_slot_buttons.append(button)
		_slot_cooldowns.append(keybind)


func _on_slot_pressed(slot: int) -> void:
	if _ability_bar:
		_ability_bar.press_slot(slot)


func _refresh_slot_labels() -> void:
	if _ability_bar == null:
		return
	for index in range(SLOT_COUNT):
		var ability := _ability_bar.ability_in_slot(index + 1)
		var button := _slot_buttons[index]
		if ability == null:
			button.text = "—"
			button.disabled = true
			button.tooltip_text = "Unlocks at a higher level"
			continue
		button.disabled = false
		button.text = ability.display_name
		button.tooltip_text = "%s\n\n%s\n\nCost %d  •  Cooldown %.0fs  •  Range %.0fm" % [
			ability.display_name, ability.description, maxi(0, ability.cost), ability.cooldown, ability.cast_range
		]


func _refresh_cooldowns() -> void:
	if _ability_bar == null:
		return
	for index in range(SLOT_COUNT):
		var remaining := _ability_bar.seconds_remaining(index + 1)
		var label := _slot_cooldowns[index]
		var button := _slot_buttons[index]
		if remaining > 0.0:
			label.text = "%.1fs" % remaining
			button.modulate = Color(0.55, 0.55, 0.6)
			continue
		label.text = str(index + 1)
		var ability := _ability_bar.ability_in_slot(index + 1)
		# Dim anything you can't currently pay for.
		var affordable := true
		if ability and _stats and not ability.spends_all_resource and ability.cost > 0:
			affordable = _stats.has_resource(ability.cost)
		button.modulate = Color.WHITE if affordable else Color(0.75, 0.7, 0.55)


# --- Quests ----------------------------------------------------------------


func _rebuild_tracker() -> void:
	for child in _tracker.get_children():
		child.queue_free()
	if _quest_log == null:
		return
	if _stats:
		_on_xp_changed(_stats.experience, Stats.xp_for_next_level(_stats.level))
	for quest_id in _quest_log.active.keys():
		var quest := QuestDatabase.get_quest(quest_id)
		if quest == null:
			continue
		var complete := _quest_log.is_complete(quest_id)
		var title := Label.new()
		title.text = quest.title + ("  (ready to hand in)" if complete else "")
		title.modulate = Color(1, 0.85, 0.45) if complete else Color(0.95, 0.93, 0.85)
		_tracker.add_child(title)
		var progress: Array = _quest_log.progress_for(quest_id)
		for index in range(quest.objective_count()):
			var have := int(progress[index]) if index < progress.size() else 0
			var line := Label.new()
			line.text = "   %s  %d / %d" % [quest.objective_text(index), have, quest.objective_required(index)]
			line.modulate = Color(0.72, 0.78, 0.6) if have >= quest.objective_required(index) else Color(0.78, 0.75, 0.68)
			_tracker.add_child(line)
	if _quest_panel.visible:
		_rebuild_quest_panel()


func _rebuild_quest_panel() -> void:
	for child in _quest_panel_rows.get_children():
		child.queue_free()
	if _quest_log == null:
		return
	_add_panel_heading("Active")
	var any_active := false
	for quest_id in _quest_log.active.keys():
		var quest := QuestDatabase.get_quest(quest_id)
		if quest == null:
			continue
		any_active = true
		_add_panel_quest(quest, _quest_log.progress_for(quest_id), _quest_log.is_complete(quest_id))
	if not any_active:
		_add_panel_note("Nothing accepted. Look for a gold ! above someone's head.")

	_add_panel_heading("Completed")
	if _quest_log.turned_in.is_empty():
		_add_panel_note("None yet.")
	for quest_id in _quest_log.turned_in.keys():
		var quest := QuestDatabase.get_quest(quest_id)
		if quest:
			_add_panel_note(quest.title)


func _add_panel_heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = Color(1, 0.85, 0.45)
	_quest_panel_rows.add_child(label)


func _add_panel_note(text: String) -> void:
	var label := Label.new()
	label.text = "   " + text
	label.modulate = Color(0.72, 0.7, 0.64)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_panel_rows.add_child(label)


func _add_panel_quest(quest: QuestData, progress: Array, complete: bool) -> void:
	var title := Label.new()
	title.text = "   " + quest.title + ("  (ready to hand in)" if complete else "")
	title.modulate = Color(1, 0.9, 0.6) if complete else Color(0.95, 0.93, 0.85)
	_quest_panel_rows.add_child(title)
	var body := Label.new()
	body.text = "      " + quest.progress_text
	body.modulate = Color(0.72, 0.7, 0.64)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_panel_rows.add_child(body)
	for index in range(quest.objective_count()):
		var have := int(progress[index]) if index < progress.size() else 0
		var line := Label.new()
		line.text = "      %s  %d / %d" % [quest.objective_text(index), have, quest.objective_required(index)]
		line.modulate = Color(0.72, 0.78, 0.6) if have >= quest.objective_required(index) else Color(0.8, 0.78, 0.72)
		_quest_panel_rows.add_child(line)
	var reward := Label.new()
	reward.text = "      Reward: %d XP, %d Sovereigns" % [quest.experience_reward, quest.currency_reward]
	reward.modulate = Color(0.65, 0.68, 0.6)
	_quest_panel_rows.add_child(reward)
