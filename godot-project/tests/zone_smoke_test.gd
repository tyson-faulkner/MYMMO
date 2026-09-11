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


func _report(label: String, passed: bool, detail: String) -> void:
	if not passed:
		_failures += 1
	var suffix := "" if detail.is_empty() else "  (%s)" % detail
	print("%s  %s%s" % ["PASS" if passed else "FAIL", label, suffix])
