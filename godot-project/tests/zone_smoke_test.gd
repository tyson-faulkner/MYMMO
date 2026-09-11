# Zone smoke test — proves the world actually assembles and the quest chain
# actually works, rather than merely compiling.
#
# Run it headless:
#   godot --headless --path <project> res://tests/zone_smoke_test.tscn
# It prints a PASS/FAIL line per check and exits non-zero if anything failed.
#
# This exists so the autonomous build loop can tell, every single pass, whether
# it has broken the game. A loop without a test is a loop that confidently
# produces rubble.
extends Node

const ZONE_SCENE := preload("res://scenes/zones/thornhollow_vale.tscn")
const PLAYER_STATS := preload("res://scripts/combat/stats.gd")
const PLAYER_QUEST_LOG := preload("res://scripts/quests/quest_log.gd")
const PLAYER_TARGETING := preload("res://scripts/combat/targeting.gd")
const PLAYER_ABILITY_BAR := preload("res://scripts/combat/ability_bar.gd")
const PLAYER_DEATH := preload("res://scripts/combat/death_handler.gd")
const TEST_PORT := 47311

var _failures: int = 0
var _players: Node3D = null
var _fake_player: CharacterBody3D = null


func _ready() -> void:
	_start_server()
	_spawn_fake_player()
	var zone := ZONE_SCENE.instantiate()
	add_child(zone)

	# Spawners wait a frame before spawning, and mobs need one more to settle.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_check_world(zone)
	_check_databases()
	await _check_quest_flow()
	_check_combat()
	await _check_abilities(zone)
	_check_death(zone)
	_check_persistence()

	print("")
	if _failures == 0:
		print("SMOKE TEST PASSED")
		get_tree().quit(0)
	else:
		print("SMOKE TEST FAILED (%d checks)" % _failures)
		get_tree().quit(1)


func _start_server() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(TEST_PORT, 8)
	if error != OK:
		_report("start headless server", false, "error %d" % error)
		return
	multiplayer.multiplayer_peer = peer
	_report("start headless server", true, "port %d" % TEST_PORT)


# A stand-in for a real player: the pieces the systems actually touch.
func _spawn_fake_player() -> void:
	_players = Node3D.new()
	_players.name = "PlayersContainer"
	_players.add_to_group("Players")
	add_child(_players)

	_fake_player = CharacterBody3D.new()
	_fake_player.name = "1"
	var stats := Node.new()
	stats.set_script(PLAYER_STATS)
	stats.name = "Stats"
	_fake_player.add_child(stats)
	var quest_log := Node.new()
	quest_log.set_script(PLAYER_QUEST_LOG)
	quest_log.name = "QuestLog"
	_fake_player.add_child(quest_log)
	var targeting := Node.new()
	targeting.set_script(PLAYER_TARGETING)
	targeting.name = "Targeting"
	_fake_player.add_child(targeting)
	var ability_bar := Node.new()
	ability_bar.set_script(PLAYER_ABILITY_BAR)
	ability_bar.name = "AbilityBar"
	_fake_player.add_child(ability_bar)
	var death := Node.new()
	death.set_script(PLAYER_DEATH)
	death.name = "DeathHandler"
	_fake_player.add_child(death)
	_players.add_child(_fake_player)
	_fake_player.global_position = Vector3(0, 1, 10)


func _check_world(zone: Node) -> void:
	var terrain := zone.get_node_or_null("Terrain")
	var built := terrain.get_child_count() if terrain else 0
	_report("vale geometry built", built > 80, "%d pieces" % built)

	var interior := zone.get_node_or_null("BarrowInterior")
	var interior_built := interior.get_child_count() if interior else 0
	_report("barrow interior built", interior_built > 20, "%d pieces" % interior_built)

	var npcs := zone.get_node_or_null("NPCs")
	var npc_count := npcs.get_child_count() if npcs else 0
	_report("NPCs placed", npc_count >= 6, "%d NPCs" % npc_count)

	var container := zone.get_node_or_null("MobContainer")
	var mob_count := container.get_child_count() if container else 0
	_report("mobs spawned", mob_count >= 50, "%d mobs" % mob_count)

	# Every mob must have found its definition, or it will stand there inert.
	var undefined := 0
	var bosses := 0
	if container:
		for child in container.get_children():
			var mob := child as Mob
			if mob == null or mob.mob_data == null:
				undefined += 1
			elif mob.mob_data.is_boss:
				bosses += 1
	_report("every mob has data", undefined == 0, "%d without data" % undefined)
	_report("bosses present", bosses >= 2, "%d bosses" % bosses)

	var portals := zone.get_node_or_null("Portals")
	_report("portals placed", portals != null and portals.get_child_count() >= 2, "")


func _check_databases() -> void:
	_report("mob database loaded", MobDatabase.get_all_ids().size() >= 10, "%d mobs" % MobDatabase.get_all_ids().size())
	_report(
		"quest database loaded",
		QuestDatabase.get_all_ids().size() >= 12,
		"%d quests" % QuestDatabase.get_all_ids().size()
	)

	# The chain has to be walkable: every prerequisite must exist.
	var broken: Array[String] = []
	for quest_id in QuestDatabase.get_all_ids():
		var quest := QuestDatabase.get_quest(quest_id)
		if quest.prerequisite != &"" and QuestDatabase.get_quest(quest.prerequisite) == null:
			broken.append(String(quest_id))
		if quest.giver_id == &"":
			broken.append("%s has no giver" % quest_id)
	_report("quest chain is intact", broken.is_empty(), ", ".join(broken))

	# Kill objectives must point at enemies that exist, or the quest is a wall.
	var unreachable: Array[String] = []
	var all_tags := {}
	for mob_id in MobDatabase.get_all_ids():
		for tag in MobDatabase.get_mob(mob_id).tags:
			all_tags[tag] = true
	for quest_id in QuestDatabase.get_all_ids():
		for objective in QuestDatabase.get_quest(quest_id).objectives:
			var kind := str(objective.get("type", ""))
			var target := StringName(str(objective.get("target", "")))
			if kind == "kill" and MobDatabase.get_mob(target) == null:
				unreachable.append("%s -> %s" % [quest_id, target])
			elif kind == "kill_tag" and not all_tags.has(target):
				unreachable.append("%s -> tag %s" % [quest_id, target])
	_report("kill objectives are completable", unreachable.is_empty(), ", ".join(unreachable))

	# A "collect 4 provisions" objective is a wall unless something actually
	# drops the thing. This check exists because q_supplies was exactly that.
	var undroppable: Array[String] = []
	for quest_id in QuestDatabase.get_all_ids():
		for objective in QuestDatabase.get_quest(quest_id).objectives:
			if str(objective.get("type", "")) != "collect":
				continue
			var wanted := str(objective.get("target", ""))
			var droppable := false
			for mob_id in MobDatabase.get_all_ids():
				if MobDatabase.get_mob(mob_id).loot_table.has(wanted):
					droppable = true
					break
			if not droppable:
				undroppable.append("%s wants %s, nothing drops it" % [quest_id, wanted])
	_report("collect objectives are obtainable", undroppable.is_empty(), ", ".join(undroppable))


func _check_quest_flow() -> void:
	var quest_log := _fake_player.get_node("QuestLog") as QuestLog
	var stats := _fake_player.get_node("Stats") as Stats

	_report("first quest is offered", quest_log.can_accept(&"q_arrival"), "")
	_report("later quest is gated", not quest_log.can_accept(&"q_wolves"), "needs q_arrival first")

	quest_log.accept_quest(&"q_arrival")
	_report("quest accepted", quest_log.is_active(&"q_arrival"), "")

	quest_log.credit_talk(&"npc_halvard")
	_report("talk objective credited", quest_log.is_complete(&"q_arrival"), "")

	var xp_before := stats.experience
	quest_log.turn_in(&"q_arrival")
	_report("quest handed in", quest_log.is_turned_in(&"q_arrival"), "")
	_report("XP awarded", stats.experience > xp_before or stats.level > 1, "xp %d, level %d" % [stats.experience, stats.level])
	_report("currency awarded", quest_log.currency > 0, "%d sovereigns" % quest_log.currency)
	_report("next quest unlocked", quest_log.can_accept(&"q_wolves"), "")

	# Kill credit, including the tag form used by "kill 8 bandits".
	quest_log.accept_quest(&"q_wolves")
	for _index in range(6):
		quest_log.credit_kill(&"vale_wolf", [&"beast"])
	_report("kill objective credited", quest_log.is_complete(&"q_wolves"), "")
	quest_log.turn_in(&"q_wolves")

	quest_log.accept_quest(&"q_bandits")
	for _index in range(8):
		quest_log.credit_kill(&"hedge_bandit", [&"bandit", &"human"])
	_report("tag kill objective credited", quest_log.is_complete(&"q_bandits"), "")

	# Collect credit, the path that was missing entirely.
	quest_log.turn_in(&"q_bandits")
	quest_log.accept_quest(&"q_supplies")
	for _index in range(4):
		quest_log.credit_collect(&"chicken_leg", 1)
	_report("collect objective credited", quest_log.is_complete(&"q_supplies"), "")
	await get_tree().process_frame


func _check_combat() -> void:
	var stats := _fake_player.get_node("Stats") as Stats

	# Classes.
	for class_path in [
		"res://resources/classes/valkyr.tres",
		"res://resources/classes/bard.tres",
		"res://resources/classes/necromancer.tres",
		"res://resources/classes/tinker.tres"
	]:
		var data := load(class_path) as ClassData
		_report("class loads: %s" % class_path.get_file(), data != null and data.display_name != "", "")

	var valkyr := load("res://resources/classes/valkyr.tres") as ClassData
	stats.apply_class(valkyr)
	var expected_health: int = valkyr.base_health + valkyr.health_per_level * (stats.level - 1)
	_report(
		"class applied",
		stats.max_health == expected_health,
		"%d hp at level %d" % [stats.max_health, stats.level]
	)
	_report("resource renamed per class", stats.get_resource_label() == "Valor", stats.get_resource_label())
	_report("tank resource starts empty", stats.mana == 0, "valor %d" % stats.mana)

	# Damage, death and the killing blow being credited.
	var before := stats.health
	stats.apply_damage(30, 1)
	_report("damage applied and mitigated", stats.health < before, "%d -> %d" % [before, stats.health])
	_report("armour mitigates", stats.health == before - (30 - valkyr.base_armor), "armour %d" % valkyr.base_armor)
	_report("taking a hit builds Valor", stats.mana > 0, "valor %d" % stats.mana)

	var killed := {"who": -1}
	stats.died.connect(func(killer: int) -> void: killed["who"] = killer)
	stats.apply_damage(99999, 7)
	_report("death fires with the killer", killed["who"] == 7, "killer %d" % killed["who"])
	_report("dead means dead", stats.is_dead and stats.health == 0, "")
	stats.revive()
	_report("revive restores", not stats.is_dead and stats.health == stats.max_health, "")

	# The XP curve should land 1-20 in a sane total.
	var total := 0
	for level in range(1, Stats.MAX_LEVEL):
		total += Stats.xp_for_next_level(level)
	_report("XP curve is sane", total > 20000 and total < 120000, "%d total XP for 1-20" % total)


func _check_abilities(zone: Node) -> void:
	var ids: Array = AbilityDatabase.get_all_ids()
	_report("ability database loaded", ids.size() >= 28, "%d abilities" % ids.size())

	# Every class needs a full bar, one ability per slot, no gaps, no clashes.
	for class_id in [&"valkyr", &"bard", &"necromancer", &"tinker"]:
		var abilities: Array = AbilityDatabase.abilities_for_class(class_id)
		var slots := {}
		for ability in abilities:
			slots[ability.slot] = true
		_report(
			"%s has a full bar" % class_id,
			abilities.size() == 7 and slots.size() == 7,
			"%d abilities in %d slots" % [abilities.size(), slots.size()]
		)

	# A summon that names an enemy which doesn't exist is a dead button.
	var bad_summons: Array[String] = []
	for ability_id in ids:
		var ability: AbilityData = AbilityDatabase.get_ability(ability_id)
		if ability.effect == AbilityData.Effect.SUMMON and MobDatabase.get_mob(ability.summon_mob_id) == null:
			bad_summons.append("%s -> %s" % [ability_id, ability.summon_mob_id])
	_report("summons reference real enemies", bad_summons.is_empty(), ", ".join(bad_summons))

	# Level gating should actually gate.
	var low := AbilityDatabase.ability_in_slot(&"valkyr", 7, 1)
	var high := AbilityDatabase.ability_in_slot(&"valkyr", 7, 20)
	_report("abilities are level gated", low == null and high != null, "slot 7 locked at 1, open at 20")

	# --- Casting, for real, at a real enemy from the real zone ---
	var stats := _fake_player.get_node("Stats") as Stats
	var bar := _fake_player.get_node("AbilityBar") as AbilityBar
	var targeting := _fake_player.get_node("Targeting") as Targeting
	stats.apply_class(load("res://resources/classes/valkyr.tres") as ClassData)
	stats.level = 20

	var container := zone.get_node_or_null("MobContainer")
	var victim: Mob = null
	for child in container.get_children():
		var mob := child as Mob
		if mob and not mob.mob_data.is_boss:
			victim = mob
			break
	if victim == null:
		_report("found an enemy to cast at", false, "")
		return

	# Stand next to it so range checks are honest.
	_fake_player.global_position = victim.global_position + Vector3(0, 0, 2.0)
	targeting.set_target(victim)
	_report("target acquired", targeting.current_target == victim, victim.mob_data.display_name)

	var health_before: int = victim.get_node("Stats").health
	var valor_before: int = stats.mana
	bar.request_cast("valkyr_strike", victim.get_path())
	_report("damage ability hurt the target", victim.get_node("Stats").health < health_before,
		"%d -> %d" % [health_before, victim.get_node("Stats").health])
	_report("Valkyr opener builds Valor", stats.mana > valor_before, "valor %d" % stats.mana)

	# A taunt has to actually hold the enemy.
	bar.request_cast("valkyr_taunt", victim.get_path())
	_report("taunt takes the enemy", victim.target == _fake_player, "")

	# Healing.
	stats.apply_damage(60, 0)
	var hurt: int = stats.health
	stats.apply_class(load("res://resources/classes/bard.tres") as ClassData)
	stats.level = 20
	stats.apply_damage(60, 0)
	hurt = stats.health
	bar.request_cast("bard_mend", _fake_player.get_path())
	_report("heal ability restored health", stats.health > hurt, "%d -> %d" % [hurt, stats.health])

	# Damage over time keeps working after the cast.
	var dot_target_health: int = victim.get_node("Stats").health
	bar.request_cast("bard_dirge", victim.get_path())
	var dot := victim.get_children().filter(func(c: Node) -> bool: return c is DamageOverTime)
	_report("damage over time attached", dot.size() > 0, "%d effects" % dot.size())
	await get_tree().create_timer(1.2).timeout
	_report("damage over time ticks", victim.get_node("Stats").health < dot_target_health,
		"%d -> %d" % [dot_target_health, victim.get_node("Stats").health])

	# Summons change sides.
	stats.apply_class(load("res://resources/classes/necromancer.tres") as ClassData)
	stats.level = 20
	var mobs_before: int = container.get_child_count()
	bar.request_cast("necro_raise", _fake_player.get_path())
	await get_tree().process_frame
	var pets := 0
	for child in container.get_children():
		var mob := child as Mob
		if mob and mob.is_friendly:
			pets += 1
	_report("summon spawned a pet", container.get_child_count() > mobs_before, "%d -> %d mobs" % [mobs_before, container.get_child_count()])
	_report("the pet fights for you", pets > 0, "%d friendly" % pets)

	# The server must refuse a cast that is out of range, however politely the
	# client asks.
	_fake_player.global_position = victim.global_position + Vector3(0, 0, 60.0)
	var far_health: int = victim.get_node("Stats").health
	bar.request_cast("necro_bolt", victim.get_path())
	_report("out-of-range casts are refused", victim.get_node("Stats").health == far_health, "")


func _check_death(zone: Node) -> void:
	var graveyards := zone.get_node_or_null("Graveyards")
	_report(
		"graveyards placed",
		graveyards != null and graveyards.get_child_count() >= 2,
		"%d" % (graveyards.get_child_count() if graveyards else 0)
	)

	var stats := _fake_player.get_node("Stats") as Stats
	var death := _fake_player.get_node("DeathHandler") as DeathHandler
	stats.apply_class(load("res://resources/classes/valkyr.tres") as ClassData)
	stats.level = 10
	stats.revive()

	# Dying makes a ghost, and remembers where the body fell.
	var fell_at := Vector3(12, 1, 18)
	_fake_player.global_position = fell_at
	stats.apply_damage(99999, 0)
	_report("death makes a ghost", death.is_ghost, "")
	_report("the corpse is where you fell", death.corpse_position.distance_to(fell_at) < 0.1,
		str(death.corpse_position))

	# Reclaiming from across the zone must be refused.
	_fake_player.global_position = fell_at + Vector3(0, 0, 60)
	death.request_reclaim_corpse()
	_report("distant corpse reclaim refused", death.is_ghost, "")

	# Walking back works, and costs nothing.
	_fake_player.global_position = fell_at + Vector3(0, 0, 2)
	death.request_reclaim_corpse()
	_report("corpse run resurrects", not death.is_ghost and not stats.is_dead, "")
	_report("corpse run has no penalty", death.sickness_remaining == 0.0, "")

	# Releasing works too, and does cost something.
	stats.apply_damage(99999, 0)
	_report("died again", death.is_ghost, "")
	death.request_release()
	_report("release resurrects", not death.is_ghost and not stats.is_dead, "")
	_report("release costs Grave-Chill", death.sickness_remaining > 0.0,
		"%ds" % int(death.sickness_remaining))
	_report("Grave-Chill weakens output", death.output_multiplier() < 1.0,
		"x%.2f" % death.output_multiplier())

	# Released at a graveyard, not left lying where the body is.
	_report("released at a graveyard", _fake_player.global_position.distance_to(fell_at) > 5.0,
		str(_fake_player.global_position.round()))


func _check_persistence() -> void:
	var stats := _fake_player.get_node("Stats") as Stats
	var quest_log := _fake_player.get_node("QuestLog") as QuestLog

	# Build a character worth losing.
	stats.apply_class(load("res://resources/classes/tinker.tres") as ClassData)
	stats._set_progression(14, 321)
	_fake_player.global_position = Vector3(41, 2, -87)
	quest_log.currency = 275
	if not quest_log.is_turned_in(&"q_wolves"):
		quest_log.turned_in[&"q_wolves"] = true

	var saved := CharacterState.capture(_fake_player)
	_report("save captures something", not saved.is_empty(), "%d fields" % saved.size())
	_report("save passes validation", CharacterState.looks_valid(saved), "")
	_report("save survives JSON", JSON.parse_string(JSON.stringify(saved)) is Dictionary, "")
	_report("save is versioned", int(saved.get("version", 0)) >= 1, "v%d" % int(saved.get("version", 0)))

	# Wipe the character, then restore it from the blob.
	stats.apply_class(load("res://resources/classes/bard.tres") as ClassData)
	stats._set_progression(1, 0)
	_fake_player.global_position = Vector3.ZERO
	quest_log.currency = 0
	quest_log.turned_in.clear()

	var restored := CharacterState.apply(_fake_player, saved)
	_report("save restores", restored, "")
	_report("class came back", stats.class_data != null and stats.class_data.id == &"tinker",
		str(stats.class_data.id) if stats.class_data else "none")
	_report("level and XP came back", stats.level == 14 and stats.experience == 321,
		"level %d, xp %d" % [stats.level, stats.experience])
	_report("position came back", _fake_player.global_position.distance_to(Vector3(41, 2, -87)) < 0.1,
		str(_fake_player.global_position.round()))
	_report("currency came back", quest_log.currency == 275, "%d sovereigns" % quest_log.currency)
	_report("finished quests came back", quest_log.is_turned_in(&"q_wolves"), "")
	_report("health matches the restored class", stats.max_health == stats.class_data.base_health
		+ stats.class_data.health_per_level * (stats.level - 1), "%d hp" % stats.max_health)

	# Junk must be refused rather than half-applied.
	_report("empty save refused", not CharacterState.looks_valid({}), "")
	_report("classless save refused", not CharacterState.looks_valid({"level": 5}), "")
	_report("impossible level refused", not CharacterState.looks_valid({"class": "bard", "level": 999}), "")

	# The game has to run with Nakama switched off. This is the check that says
	# "Docker not running" never becomes "game broken".
	_report("no login means no crash", not Account.is_logged_in(), Account.status_line())


func _report(label: String, passed: bool, detail: String) -> void:
	if not passed:
		_failures += 1
	var suffix := "" if detail.is_empty() else "  (%s)" % detail
	print("%s  %s%s" % ["PASS" if passed else "FAIL", label, suffix])
