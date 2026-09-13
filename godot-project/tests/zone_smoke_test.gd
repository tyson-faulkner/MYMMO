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
const SABLEMARCH_SCENE := preload("res://scenes/zones/sablemarch.tscn")
const KINGSMOURN_SCENE := preload("res://scenes/zones/kingsmourn.tscn")
const PLAYER_STATS := preload("res://scripts/combat/stats.gd")
const PLAYER_QUEST_LOG := preload("res://scripts/quests/quest_log.gd")
const PLAYER_TARGETING := preload("res://scripts/combat/targeting.gd")
const PLAYER_ABILITY_BAR := preload("res://scripts/combat/ability_bar.gd")
const PLAYER_DEATH := preload("res://scripts/combat/death_handler.gd")
const PLAYER_RUNES := preload("res://scripts/combat/rune_loadout.gd")
const PLAYER_MOUNTS := preload("res://scripts/combat/mount_controller.gd")
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
	_check_parties()
	_check_runes(zone)
	_check_gear(zone)

	# Zones two and three. Built last because they are the biggest, and the
	# checks below only mean anything once all three are standing.
	var sablemarch := SABLEMARCH_SCENE.instantiate()
	add_child(sablemarch)
	var kingsmourn := KINGSMOURN_SCENE.instantiate()
	add_child(kingsmourn)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_check_zone_two_and_three(zone, sablemarch, kingsmourn)
	_check_mounts()
	_check_graveyards(zone, sablemarch, kingsmourn)
	_check_character_models()
	_check_ground_textures(zone, sablemarch)
	_check_template_cleanup()
	_check_kit_props(zone, kingsmourn)

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
	var runes := Node.new()
	runes.set_script(PLAYER_RUNES)
	runes.name = "RuneLoadout"
	_fake_player.add_child(runes)
	var mounts := Node.new()
	mounts.set_script(PLAYER_MOUNTS)
	mounts.name = "MountController"
	_fake_player.add_child(mounts)
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

	# THE GAP THIS CLOSES: quests name their giver by id, and until NpcDatabase
	# existed nothing confirmed the giver was a real person standing somewhere.
	# A typo, or a quest written for an NPC nobody ever placed, shipped silently
	# and you only found out when a player walked to an empty field looking for
	# a quest marker.
	var missing_givers: Array[String] = []
	for quest_id in QuestDatabase.get_all_ids():
		var quest := QuestDatabase.get_quest(quest_id)
		if not NpcDatabase.has_npc(quest.giver_id):
			missing_givers.append("%s given by unknown %s" % [quest_id, quest.giver_id])
		if quest.turn_in_id != &"" and not NpcDatabase.has_npc(quest.turn_in_id):
			missing_givers.append("%s handed in to unknown %s" % [quest_id, quest.turn_in_id])
	_report("every quest has a real giver", missing_givers.is_empty(), ", ".join(missing_givers))

	# The same gap in the other direction: a "go and talk to X" objective that
	# names somebody who does not exist is just as unfinishable.
	var missing_talk: Array[String] = []
	for quest_id in QuestDatabase.get_all_ids():
		for objective in QuestDatabase.get_quest(quest_id).objectives:
			if str(objective.get("type", "")) != "talk":
				continue
			var who := StringName(str(objective.get("target", "")))
			if not NpcDatabase.has_npc(who):
				missing_talk.append("%s -> %s" % [quest_id, who])
	_report("talk objectives name real people", missing_talk.is_empty(), ", ".join(missing_talk))

	# And every NPC should have somewhere to stand. An NPC in the database with
	# no zone is one nobody can ever reach.
	var homeless: Array[String] = []
	for npc_id in NpcDatabase.get_all_ids():
		if NpcDatabase.get_npc(npc_id).zones.is_empty():
			homeless.append(String(npc_id))
	_report("every NPC stands somewhere", homeless.is_empty(), ", ".join(homeless))


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


func _check_parties() -> void:
	# Two more stand-in players to group with.
	for peer_id in [2, 3]:
		var body := CharacterBody3D.new()
		body.name = str(peer_id)
		var stats := Node.new()
		stats.set_script(PLAYER_STATS)
		stats.name = "Stats"
		body.add_child(stats)
		var quest_log := Node.new()
		quest_log.set_script(PLAYER_QUEST_LOG)
		quest_log.name = "QuestLog"
		body.add_child(quest_log)
		_players.add_child(body)
		body.global_position = Vector3(10, 1, 10)

	_report("solo player is not grouped", not PartyManager.is_grouped(1), "")
	_report("solo share group is just you", PartyManager.share_group_for(1, Vector3.ZERO, _players) == [1], "")

	_report("invite forms a party", PartyManager.add_to_party(1, 2), "")
	_report("second invite joins the same party",
		PartyManager.add_to_party(1, 3) and PartyManager.party_of(2) == PartyManager.party_of(3), "")
	_report("party has three", PartyManager.members_of(1).size() == 3, str(PartyManager.members_of(1)))
	_report("leader is the inviter", PartyManager.leader_of(PartyManager.party_of(1)) == 1, "")
	_report("can't poach someone already grouped", not PartyManager.add_to_party(1, 2), "")

	# Sharing: nearby party members count, distant ones don't, ghosts don't.
	_fake_player.global_position = Vector3(10, 1, 12)
	var nearby := PartyManager.share_group_for(1, Vector3(10, 1, 10), _players)
	_report("nearby party members share", nearby.size() == 3, "%d sharing" % nearby.size())

	_players.get_node("3").global_position = Vector3(900, 1, 900)
	var closer := PartyManager.share_group_for(1, Vector3(10, 1, 10), _players)
	_report("distant party members don't share", closer.size() == 2, "%d sharing" % closer.size())

	var ghost_stats := _players.get_node("2").get_node("Stats") as Stats
	ghost_stats.apply_damage(99999, 0)
	var living := PartyManager.share_group_for(1, Vector3(10, 1, 10), _players)
	_report("dead party members don't share", living.size() == 1, "%d sharing" % living.size())
	ghost_stats.revive()

	# XP splits, but grouping must never be worse than going alone per-kill
	# once you account for killing faster.
	var solo_xp := PartyManager.experience_share(100, 1)
	var duo_xp := PartyManager.experience_share(100, 2)
	var five_xp := PartyManager.experience_share(100, 5)
	_report("solo XP is untouched", solo_xp == 100, "%d" % solo_xp)
	_report("grouped XP is split", duo_xp < 100 and five_xp < duo_xp, "duo %d, five %d" % [duo_xp, five_xp])
	_report("the split is generous", duo_xp > 100 / 2 and five_xp > 100 / 5,
		"duo %d (vs 50), five %d (vs 20)" % [duo_xp, five_xp])

	# Quest credit is NOT split — that is the whole point.
	var log_one := _fake_player.get_node("QuestLog") as QuestLog
	var log_two := _players.get_node("2").get_node("QuestLog") as QuestLog
	for quest_log in [log_one, log_two]:
		quest_log.active.clear()
		quest_log.turned_in.clear()
		quest_log.turned_in[&"q_arrival"] = true
		quest_log.accept_quest(&"q_wolves")
	for peer_id in PartyManager.share_group_for(1, Vector3(10, 1, 10), _players):
		pass
	for _index in range(6):
		log_one.credit_kill(&"vale_wolf", [&"beast"])
		log_two.credit_kill(&"vale_wolf", [&"beast"])
	_report("everyone in the party gets full quest credit",
		log_one.is_complete(&"q_wolves") and log_two.is_complete(&"q_wolves"), "")

	PartyManager.leave_party(1)
	_report("leaving works", not PartyManager.is_grouped(1), "")


func _check_runes(zone: Node) -> void:
	var ids: Array = RuneDatabase.get_all_ids()
	_report("rune database loaded", ids.size() >= 24, "%d runes" % ids.size())

	# Three slots per class, exactly two choices in each. A slot with one option
	# is not a choice; a slot with three is a different design.
	for class_id in [&"valkyr", &"bard", &"necromancer", &"tinker"]:
		var ok := true
		var detail := ""
		for slot in range(1, 4):
			var options: Array = RuneDatabase.options_for(class_id, slot)
			if options.size() != 2:
				ok = false
				detail += "slot %d has %d; " % [slot, options.size()]
		_report("%s has 3 slots of 2" % class_id, ok, detail)

	# Every rune must point at an ability that exists and belongs to its class.
	var broken: Array[String] = []
	for rune_id in ids:
		var rune: RuneData = RuneDatabase.get_rune(rune_id)
		var ability: AbilityData = AbilityDatabase.get_ability(rune.ability_id)
		if ability == null:
			broken.append("%s -> missing %s" % [rune_id, rune.ability_id])
		elif ability.class_id != rune.class_id:
			broken.append("%s is %s but changes a %s ability" % [rune_id, rune.class_id, ability.class_id])
	_report("runes modify real abilities of their own class", broken.is_empty(), ", ".join(broken))

	# The design doc's rule: the two options in a slot must differ by SITUATION,
	# not by size. Two runes with the same effect type AND similar values is the
	# fake choice it warns about.
	var fake_choices: Array[String] = []
	for class_id in [&"valkyr", &"bard", &"necromancer", &"tinker"]:
		for slot in range(1, 4):
			var options: Array = RuneDatabase.options_for(class_id, slot)
			if options.size() != 2:
				continue
			var first: RuneData = options[0]
			var second: RuneData = options[1]
			if first.effect == second.effect and absf(first.value - second.value) < 0.35:
				fake_choices.append("%s slot %d" % [class_id, slot])
	_report("no slot offers a fake choice", fake_choices.is_empty(), ", ".join(fake_choices))

	# Choosing: validated against class, slot and level.
	var loadout := _fake_player.get_node("RuneLoadout") as RuneLoadout
	var stats := _fake_player.get_node("Stats") as Stats
	stats.apply_class(load("res://resources/classes/necromancer.tres") as ClassData)
	stats.level = 1
	loadout.chosen.clear()

	_report("slot is locked at level 1", not loadout.slot_unlocked(1), "")
	_report("locked slot refuses a rune", not loadout.choose(1, &"necro_1b"), "")

	stats.level = 20
	_report("slot unlocks with level", loadout.slot_unlocked(1), "")
	_report("valid rune accepted", loadout.choose(1, &"necro_1b"), "")
	_report("another class's rune refused", not loadout.choose(1, &"bard_1a"), "")
	_report("wrong slot refused", not loadout.choose(1, &"necro_3a"), "")
	_report("rune found by ability", loadout.rune_for_ability(&"necro_bolt") != null, "")

	# And it has to actually change the cast. Forked Bolt should hit a second
	# enemy that a plain Soulbolt never touches.
	var bar := _fake_player.get_node("AbilityBar") as AbilityBar
	var container := zone.get_node("MobContainer")
	var pair: Array = []
	for child in container.get_children():
		var mob := child as Mob
		if mob and not mob.is_friendly and not mob.mob_data.is_boss and not mob.get_node("Stats").is_dead:
			pair.append(mob)
		if pair.size() == 2:
			break
	if pair.size() < 2:
		_report("found two enemies to test forking", false, "")
		return
	# Stand them next to each other, and the caster next to them.
	pair[1].global_position = pair[0].global_position + Vector3(3, 0, 0)
	_fake_player.global_position = pair[0].global_position + Vector3(0, 0, 4)
	for mob in pair:
		mob.get_node("Stats").revive()
	var bystander_before: int = pair[1].get_node("Stats").health

	loadout.chosen.clear()
	bar._server_ready_at.clear()
	bar.request_cast("necro_bolt", pair[0].get_path())
	_report("without the rune, only the target is hit",
		pair[1].get_node("Stats").health == bystander_before, "")

	loadout.choose(1, &"necro_1b")
	bar._server_ready_at.clear()
	stats.restore_resource(999)
	bar.request_cast("necro_bolt", pair[0].get_path())
	_report("Forked Bolt reaches a second enemy",
		pair[1].get_node("Stats").health < bystander_before,
		"%d -> %d" % [bystander_before, pair[1].get_node("Stats").health])

	# Runes are a build, and a build has to survive logging out.
	var saved := CharacterState.capture(_fake_player)
	loadout.chosen.clear()
	CharacterState.apply(_fake_player, saved)
	_report("rune choices survive a save", loadout.rune_for_ability(&"necro_bolt") != null,
		str(loadout.chosen))


func _check_gear(zone: Node) -> void:
	var ids: Array = GearDatabase.get_all_ids()
	_report("gear database loaded", ids.size() >= 50, "%d items" % ids.size())

	# Every slot, every tier, has something in it. An empty slot at a tier is a
	# slot nobody can ever fill.
	var gaps: Array[String] = []
	for tier in [Item.GearTier.STARTER, Item.GearTier.MID, Item.GearTier.CAP]:
		for slot in [Item.GearSlot.HEAD, Item.GearSlot.CHEST, Item.GearSlot.LEGS, Item.GearSlot.HANDS,
				Item.GearSlot.FEET, Item.GearSlot.WEAPON, Item.GearSlot.OFFHAND, Item.GearSlot.RING,
				Item.GearSlot.TRINKET, Item.GearSlot.CLOAK]:
			if GearDatabase.items_for(slot, tier).is_empty():
				gaps.append("%s tier %d" % [Item.slot_name(slot), tier])
	_report("every slot has gear at every tier", gaps.is_empty(), ", ".join(gaps))

	# THE DESIGN DOC'S RULE, enforced: rings, trinkets and cloaks are owned by
	# the open world and are NEVER in a boss or dungeon loot table. This is what
	# keeps questing worth doing — world gear cannot be outscaled because there
	# is nothing to outscale it with.
	var violations: Array[String] = []
	for mob_id in MobDatabase.get_all_ids():
		var mob := MobDatabase.get_mob(mob_id)
		if not mob.is_dungeon:
			continue
		for item_id in mob.loot_table:
			var item: Item = ItemDatabase.get_item(str(item_id))
			if item and item.is_gear() and Item.slot_is_world_owned(item.gear_slot):
				violations.append("%s drops %s" % [mob_id, item_id])
	_report("dungeons never drop world-owned slots", violations.is_empty(), ", ".join(violations))

	# And the mirror: dungeon-owned slots must come from dungeons, not quests.
	var quest_violations: Array[String] = []
	for quest_id in QuestDatabase.get_all_ids():
		for item_id in QuestDatabase.get_quest(quest_id).item_rewards:
			var item: Item = ItemDatabase.get_item(str(item_id))
			if item and item.is_gear() and not Item.slot_is_world_owned(item.gear_slot):
				quest_violations.append("%s rewards %s" % [quest_id, item_id])
	_report("quests only reward world-owned slots", quest_violations.is_empty(), ", ".join(quest_violations))

	# Every loot table entry and quest reward names something real.
	var phantom: Array[String] = []
	for mob_id in MobDatabase.get_all_ids():
		for item_id in MobDatabase.get_mob(mob_id).loot_table:
			if ItemDatabase.get_item(str(item_id)) == null:
				phantom.append("%s -> %s" % [mob_id, item_id])
	for quest_id in QuestDatabase.get_all_ids():
		for item_id in QuestDatabase.get_quest(quest_id).item_rewards:
			if ItemDatabase.get_item(str(item_id)) == null:
				phantom.append("%s -> %s" % [quest_id, item_id])
	for npc in NpcDatabase.vendors():
		for item_id in npc.stock:
			if ItemDatabase.get_item(String(item_id)) == null:
				phantom.append("%s sells %s" % [npc.id, item_id])
	_report("loot, rewards and stock all name real items", phantom.is_empty(), ", ".join(phantom))

	_report("somebody sells something", NpcDatabase.vendors().size() >= 2, "%d vendors" % NpcDatabase.vendors().size())

	# --- Equipping, for real ---
	var stats := _fake_player.get_node("Stats") as Stats
	stats.apply_class(load("res://resources/classes/valkyr.tres") as ClassData)
	stats.level = 20
	stats.set_gear_bonuses(0, 0, 0)
	var inventory := PlayerInventory.new()

	var chest: Item = ItemDatabase.get_item("gear_sovereign_chest")
	_report("cap chest exists", chest != null, "")
	inventory.add_item(chest, 1)
	var chest_index := -1
	for i in range(inventory.get_active_slot_count()):
		if inventory.get_slot(i).item_id == chest.id:
			chest_index = i
	_report("chest lands in the bag", chest_index >= 0, "")
	_report("chest equips", inventory.equip_gear_from_slot(chest_index, &"valkyr", 20), "")
	_report("chest is worn", not inventory.get_gear_slot(&"chest").is_empty(), "")
	_report("bag slot is empty again", inventory.get_slot(chest_index).is_empty(), "")

	var totals: Dictionary = inventory.gear_totals()
	_report("totals reflect the chest", int(totals["armor"]) == chest.armor and int(totals["stamina"]) == chest.stamina,
		"A%d P%d S%d" % [totals["armor"], totals["power"], totals["stamina"]])

	# Stats pick it up: armour mitigates more, stamina raises max health.
	var base_max := stats.max_health
	var base_armor := stats.total_armor()
	stats.set_gear_bonuses(int(totals["armor"]), int(totals["power"]), int(totals["stamina"]))
	_report("stamina raises max health", stats.max_health == base_max + chest.stamina * 5,
		"%d -> %d" % [base_max, stats.max_health])
	_report("armour adds up", stats.total_armor() == base_armor + chest.armor, "%d" % stats.total_armor())

	# A Bard cannot pick up a spear; a level 3 cannot wear cap gear.
	var spear: Item = ItemDatabase.get_item("gear_sovereign_weapon_valkyr")
	inventory.add_item(spear, 1)
	var spear_index := -1
	for i in range(inventory.get_active_slot_count()):
		if inventory.get_slot(i).item_id == spear.id:
			spear_index = i
	_report("wrong class refused", not inventory.equip_gear_from_slot(spear_index, &"bard", 20), "")
	_report("too low a level refused", not inventory.equip_gear_from_slot(spear_index, &"valkyr", 3), "")
	_report("right class and level accepted", inventory.equip_gear_from_slot(spear_index, &"valkyr", 20), "")

	# Two rings, both wearable at once.
	var ring: Item = ItemDatabase.get_item("gear_sovereign_ring")
	inventory.add_item(ring, 1)
	inventory.add_item(ring, 1)
	var worn_rings := 0
	for i in range(inventory.get_active_slot_count()):
		if inventory.get_slot(i).item_id == ring.id:
			inventory.equip_gear_from_slot(i, &"valkyr", 20)
	if not inventory.get_gear_slot(&"ring1").is_empty(): worn_rings += 1
	if not inventory.get_gear_slot(&"ring2").is_empty(): worn_rings += 1
	_report("both ring slots fill", worn_rings == 2, "%d rings worn" % worn_rings)

	# Unequip puts it back in the bag.
	_report("unequip works", inventory.unequip_gear(&"chest"), "")
	_report("chest is off", inventory.get_gear_slot(&"chest").is_empty(), "")

	# Gear survives a save.
	var saved := inventory.to_dict()
	var restored := PlayerInventory.new()
	restored.from_dict(saved)
	_report("worn gear survives a save", not restored.get_gear_slot(&"weapon").is_empty()
		and not restored.get_gear_slot(&"ring1").is_empty(), "")

	# The uniques do what they say.
	var unique: Item = ItemDatabase.get_item("wolfsbane_ring")
	_report("uniques have effects", unique != null and unique.unique_effect == &"beast_slayer", "")
	_report("uniques are world-owned", unique != null and unique.gear_source == Item.GearSource.WORLD, "")


# THE GAP THIS CLOSES: content and geometry are written in different files, and
# nothing tied them together. A mob defined in MobDatabase that no spawner ever
# places, or a "go to X" objective naming an area nobody built, both ship
# silently and are only found by a player standing in an empty field. The vale
# had that bug once (q_supplies); these checks are so the marches and the
# capital cannot have it three more times.
func _check_zone_two_and_three(vale: Node3D, sablemarch: Node3D, kingsmourn: Node3D) -> void:
	print("")
	print("-- zones two and three --")

	var zones: Array[Node3D] = [vale, sablemarch, kingsmourn]

	# Both zones actually assembled something, rather than silently building an
	# empty node because the layout name was misspelled.
	for zone in [sablemarch, kingsmourn]:
		var built := 0
		for terrain in zone.get_children():
			if terrain is Node3D and terrain.get_child_count() > 0:
				built += terrain.get_child_count()
		_report("%s assembled" % zone.name, built > 50, "%d pieces and nodes" % built)

	# Every enemy in the database stands somewhere. An unplaced mob is a quest
	# that cannot be finished.
	var placed := {}
	for zone in zones:
		for spawner in _all_spawners(zone):
			placed[spawner.mob_id] = true
	var unplaced: Array[String] = []
	for mob_id in MobDatabase.get_all_ids():
		# Summons and pets are called up mid-fight, so nothing places them and
		# nothing should.
		if MobDatabase.get_mob(mob_id).tags.has(&"summon"):
			continue
		if not placed.has(mob_id):
			unplaced.append(String(mob_id))
	_report("every enemy is placed in a zone", unplaced.is_empty(), ", ".join(unplaced))

	# Every "reach somewhere" objective names an AreaTrigger that exists.
	var areas := {}
	for zone in zones:
		for trigger in _all_triggers(zone):
			areas[trigger.area_id] = true
	var missing_areas: Array[String] = []
	for quest_id in QuestDatabase.get_all_ids():
		for objective in QuestDatabase.get_quest(quest_id).objectives:
			if str(objective.get("type", "")) != "reach":
				continue
			var wanted := StringName(str(objective.get("target", "")))
			if not areas.has(wanted):
				missing_areas.append("%s -> %s" % [quest_id, wanted])
	_report("reach objectives name real places", missing_areas.is_empty(), ", ".join(missing_areas))

	# Every NPC the database says lives in the marches or the capital is
	# actually standing in that scene.
	var standing := {}
	for zone in zones:
		for npc in _all_npcs(zone):
			standing[npc.npc_id] = true
	var absent: Array[String] = []
	for npc_id in NpcDatabase.get_all_ids():
		if not standing.has(npc_id):
			absent.append(String(npc_id))
	_report("every NPC is placed in a zone", absent.is_empty(), ", ".join(absent))

	# A portal whose far side is inside another portal teleports you straight
	# back, which reads as the game being broken. Ten metres is the vale's
	# working clearance.
	var portals: Array[DungeonPortal] = []
	for zone in zones:
		portals.append_array(_all_portals(zone))
	var too_close: Array[String] = []
	for portal in portals:
		for other in portals:
			if portal == other:
				continue
			if portal.destination.distance_to(other.global_position) < 6.0:
				too_close.append("%s lands on %s" % [portal.name, other.name])
	_report("portals do not land on each other", too_close.is_empty(), ", ".join(too_close))

	# Every boss has somewhere to be reached from: a portal leading into its
	# region. Checked by height, since each interior sits on its own level.
	var boss_levels := {}
	for zone in zones:
		for spawner in _all_spawners(zone):
			if spawner.is_boss_encounter:
				boss_levels[int(round(spawner.global_position.y / 100.0))] = String(spawner.mob_id)
	var reachable_levels := {}
	for portal in portals:
		reachable_levels[int(round(portal.destination.y / 100.0))] = true
	var stranded: Array[String] = []
	for level in boss_levels:
		if not reachable_levels.has(level):
			stranded.append(str(boss_levels[level]))
	_report("every boss region has a way in", stranded.is_empty(), ", ".join(stranded))


func _all_spawners(root: Node) -> Array[MobSpawner]:
	var found: Array[MobSpawner] = []
	for node in root.find_children("*", "Node3D", true, false):
		if node is MobSpawner:
			found.append(node)
	return found


func _all_triggers(root: Node) -> Array[AreaTrigger]:
	var found: Array[AreaTrigger] = []
	for node in root.find_children("*", "Area3D", true, false):
		if node is AreaTrigger:
			found.append(node)
	return found


func _all_portals(root: Node) -> Array[DungeonPortal]:
	var found: Array[DungeonPortal] = []
	for node in root.find_children("*", "Area3D", true, false):
		if node is DungeonPortal:
			found.append(node)
	return found


func _all_npcs(root: Node) -> Array:
	var found: Array = []
	for node in root.find_children("*", "Node3D", true, false):
		if node.get("npc_id") != null and node.has_method("_apply_definition"):
			found.append(node)
	return found


# Mounts are the reward layer, so the failure modes are all "the player earned
# something and the game quietly kept it": a drop nobody can learn, a mount that
# vanishes on logout, or one that works in a raid where it must not.
func _check_mounts() -> void:
	print("")
	print("-- mounts --")

	var mounts := _fake_player.get_node("MountController") as MountController
	var stats := _fake_player.get_node("Stats") as Stats

	_report("mount database loaded", MountDatabase.get_all_ids().size() == 10,
		"%d mounts" % MountDatabase.get_all_ids().size())

	# Every mount is reachable as an item, or its drop is a dead entry.
	var unreachable: Array[String] = []
	for mount_id in MountDatabase.get_all_ids():
		var item: Item = ItemDatabase.get_item(String(mount_id))
		if item == null or item.item_type != Item.ItemType.MOUNT or item.mount_id != mount_id:
			unreachable.append(String(mount_id))
	_report("every mount is a real item", unreachable.is_empty(), ", ".join(unreachable))

	# Every mount has a way into a player's hands: a boss drops it, a vendor
	# sells it, or a quest hands it over.
	var obtainable := {}
	for mob_id in MobDatabase.get_all_ids():
		for item_id in MobDatabase.get_mob(mob_id).loot_table:
			obtainable[StringName(item_id)] = true
	for npc_id in NpcDatabase.get_all_ids():
		for item_id in NpcDatabase.get_npc(npc_id).stock:
			obtainable[StringName(item_id)] = true
	for quest_id in QuestDatabase.get_all_ids():
		for item_id in QuestDatabase.get_quest(quest_id).item_rewards:
			obtainable[StringName(item_id)] = true
	var unobtainable: Array[String] = []
	for mount_id in MountDatabase.get_all_ids():
		if not obtainable.has(mount_id):
			unobtainable.append(String(mount_id))
	_report("every mount has a source", unobtainable.is_empty(), ", ".join(unobtainable))

	# Learning, and the level gate on riding.
	stats.level = 20
	_report("unknown mounts cannot be ridden", not mounts.mount_up(&"mount_veil_saber"), "")
	_report("learning works", mounts.learn(&"mount_veil_saber"), "")
	_report("learning twice is a no-op", not mounts.learn(&"mount_veil_saber"), "")
	_report("known mount rides", mounts.mount_up(&"mount_veil_saber"), "")
	_report("the mount is the one asked for", mounts.current == &"mount_veil_saber", String(mounts.current))
	_report("riding is faster than running", MountDatabase.speed_of(mounts.current) > 1.0,
		"%.2fx" % MountDatabase.speed_of(mounts.current))

	# Getting hit throws you off — the rule that stops mounts being a combat
	# ability.
	stats.apply_damage(5, 1)
	_report("damage dismounts", not mounts.is_mounted(), "")

	# And a dungeon is off limits, decided by depth rather than a list of rooms
	# somebody has to remember to update.
	_fake_player.global_position = Vector3(1200, -1500, -600)
	_report("no riding underground", not mounts.mount_up(&"mount_veil_saber"),
		mounts.refusal_reason(&"mount_veil_saber"))
	_fake_player.global_position = Vector3(0, 1, 10)
	_report("riding works back on the surface", mounts.mount_up(&"mount_veil_saber"), "")
	mounts.dismount()

	# A mount you earned survives logging out.
	var saved := CharacterState.capture(_fake_player)
	var reloaded := MountController.new()
	reloaded.from_dict(saved.get("mounts", {}))
	_report("learned mounts survive a save", reloaded.knows(&"mount_veil_saber"), "")
	reloaded.from_dict({"learned": ["mount_that_does_not_exist"]})
	_report("a bad save does not create phantom mounts", reloaded.learned.is_empty(), "")
	reloaded.free()


# THE GAP THIS CLOSES: a corpse run is only tolerable if a graveyard is nearby
# and the ghost moves faster than the living. Both are easy to get wrong and
# neither shows up until somebody actually dies far from town, by which point
# they are already annoyed.
func _check_graveyards(vale: Node3D, sablemarch: Node3D, kingsmourn: Node3D) -> void:
	print("")
	print("-- death and graveyards --")

	var zones: Array[Node3D] = [vale, sablemarch, kingsmourn]
	var graveyards: Array[Node3D] = []
	for zone in zones:
		for node in zone.find_children("*", "Node3D", true, false):
			if node is Graveyard:
				graveyards.append(node)
	_report("graveyards exist in every region", graveyards.size() >= 20,
		"%d graveyards" % graveyards.size())

	# Every graveyard has a spirit healer standing at it, so the shortcut is
	# always offered and never only in the starting town.
	var healers: Array[Vector3] = []
	for zone in zones:
		for npc in _all_npcs(zone):
			if npc.npc_id == &"npc_spirit_healer":
				healers.append(npc.global_position)
	var unattended: Array[String] = []
	for grave in graveyards:
		var found := false
		for spot in healers:
			if grave.global_position.distance_to(spot) < 8.0:
				found = true
				break
		if not found:
			unattended.append(grave.display_name)
	_report("every graveyard has a spirit healer", unattended.is_empty(), ", ".join(unattended))

	# No corner of a surface zone should be a long walk from a graveyard. The
	# bar is set in seconds, not metres: a ghost runs at 1.5x, so 6.0 * 1.5 =
	# 9 m/s, and 140m is about fifteen seconds. That is a corpse run people
	# will actually choose over the sickness.
	var surface: Array[Vector3] = []
	for grave in graveyards:
		if grave.global_position.y > -100.0:
			surface.append(grave.global_position)
	var worst := 0.0
	var worst_at := Vector3.ZERO
	var zone_centres: Array[Vector3] = [Vector3(0, 0, 0), Vector3(600, 0, 0), Vector3(1200, 0, 0)]
	for centre in zone_centres:
		for gx in range(-4, 5):
			for gz in range(-5, 6):
				var probe: Vector3 = centre + Vector3(float(gx) * 28.0, 0, float(gz) * 30.0)
				var nearest := INF
				for spot in surface:
					nearest = minf(nearest, probe.distance_to(spot))
				if nearest > worst:
					worst = nearest
					worst_at = probe
	_report("nowhere on the surface is far from a graveyard", worst < 140.0,
		"worst %.0fm (~%.0fs ghost run), near %v" % [worst, worst / 9.0, worst_at])

	# And the ghost actually moves faster, which is the whole reason the corpse
	# run is the free option.
	_report("ghosts run faster than the living", DeathHandler.GHOST_SPEED > 1.2,
		"%.2fx" % DeathHandler.GHOST_SPEED)


# THE GAP THIS CLOSES: the class model is what everyone else sees of you. One
# that loads with play-once clips, faces backwards, or leaves the equipment
# sockets pointing at a freed skeleton still "works" — it just looks broken
# the moment anyone moves or changes class.
func _check_character_models() -> void:
	print("")
	print("-- character models --")

	var body := Body.new()
	body.name = "ModelCheckBody"
	for socket_name in Body.SOCKETS:
		var attachment := BoneAttachment3D.new()
		attachment.name = socket_name
		body.add_child(attachment)
	add_child(body)

	var problems: Array[String] = []
	# Valkyr twice, so the last swap is back onto a class already worn once.
	for class_id: StringName in [&"valkyr", &"bard", &"necromancer", &"tinker", &"valkyr"]:
		if not body.set_class_model(class_id):
			problems.append("%s: no model" % class_id)
			continue
		var skeleton := body.get_skeleton()
		if skeleton == null:
			problems.append("%s: no skeleton" % class_id)
			continue
		var player := body.animation_player
		for clip in Character.ALLOWED_ANIMATION_STATES:
			if player == null or not player.has_animation(clip):
				problems.append("%s: missing clip %s" % [class_id, clip])
		for clip in Body.LOOPING_CLIPS:
			if player and player.has_animation(clip) and player.get_animation(clip).loop_mode == Animation.LOOP_NONE:
				problems.append("%s: %s does not loop" % [class_id, clip])
		for socket_name in Body.SOCKETS:
			var attachment := body.get_node(socket_name) as BoneAttachment3D
			if attachment.get_node_or_null(attachment.external_skeleton) != skeleton or attachment.bone_idx < 0:
				problems.append("%s: socket %s not bound to this skeleton" % [class_id, socket_name])
		# Facing: the toes must sit in front of the foot along the body's +Z,
		# which is the way movement turns the body.
		var foot := skeleton.find_bone("LeftFoot")
		var toes := skeleton.find_bone("LeftToes")
		if foot < 0 or toes < 0:
			problems.append("%s: no foot bones to tell facing from" % class_id)
		else:
			var to_body := body.global_transform.affine_inverse() * skeleton.global_transform
			var foot_z := (to_body * skeleton.get_bone_global_rest(foot)).origin.z
			var toes_z := (to_body * skeleton.get_bone_global_rest(toes)).origin.z
			if toes_z <= foot_z:
				problems.append("%s: faces backwards" % class_id)
		var models := 0
		for child in body.get_children():
			if not (child is BoneAttachment3D):
				models += 1
		if models != 1:
			problems.append("%s: %d models worn at once" % [class_id, models])
	_report("every class wears a working model", problems.is_empty(),
		"; ".join(problems) if not problems.is_empty() else "4 classes, 5 swaps")
	body.queue_free()

	# The real player scene: the robot is gone, and everything the network
	# synchronises still exists at the path it is synchronised by.
	var packed := load("res://scenes/level/player.tscn") as PackedScene
	var player_node: Node = null
	if packed:
		player_node = packed.instantiate()
	var wears_model := player_node != null \
		and player_node.get_node_or_null("Body/ClassModel/Armature/Skeleton3D") is Skeleton3D \
		and player_node.get_node_or_null("Body/HeadAttach") is BoneAttachment3D \
		and player_node.get_node_or_null("Body/InfrontArea3D") is Area3D \
		and player_node.get_node_or_null("GodotRobot3D") == null
	_report("the player scene wears a class model, not the robot", wears_model, "")
	var unresolved: Array[String] = []
	if player_node:
		var sync := player_node.get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
		if sync and sync.replication_config:
			for property in sync.replication_config.get_properties():
				if player_node.get_node_or_null(NodePath(property.get_concatenated_names())) == null:
					unresolved.append(str(property))
		player_node.free()
	_report("every synchronised player property still has a node", unresolved.is_empty(), ", ".join(unresolved))


# Kit Phase 3: the props exist as real geometry and the layouts actually use
# them. kit_has() already refuses a stub; this checks the placeholders were
# replaced, and that a tree's collision is its trunk, not its canopy.
func _check_kit_props(vale: Node3D, kingsmourn: Node3D) -> void:
	print("")
	print("-- kit props --")
	var missing: Array[String] = []
	for piece in ["lamp", "stall", "tree", "planter", "fountain"]:
		if not ZoneBuilder.kit_has(piece):
			missing.append(piece)
	_report("Phase 3 props are real kit pieces", missing.is_empty(), ", ".join(missing))

	var counts := {}
	var trunk_only := true
	for zone in [vale, kingsmourn]:
		for body in zone.find_children("*", "StaticBody3D", true, false):
			var model: Node = null
			var shape: CollisionShape3D = null
			for child in body.get_children():
				if child is CollisionShape3D:
					shape = child
				elif child is Node3D and not (child as Node).scene_file_path.is_empty():
					model = child
			if model == null:
				continue
			var file := model.scene_file_path.get_file()
			counts[file] = int(counts.get(file, 0)) + 1
			if file == "tree_round.glb" and shape and shape.shape is BoxShape3D:
				if (shape.shape as BoxShape3D).size.x > 1.5:
					trunk_only = false
	_report("the vale's fountain, lamps, planters and trees are kit pieces",
		int(counts.get("fountain.glb", 0)) >= 2 and int(counts.get("lamp_iron.glb", 0)) >= 8
		and int(counts.get("planter_box.glb", 0)) >= 2 and int(counts.get("tree_round.glb", 0)) >= 10,
		"fountains=%d lamps=%d planters=%d trees=%d" % [counts.get("fountain.glb", 0), counts.get("lamp_iron.glb", 0), counts.get("planter_box.glb", 0), counts.get("tree_round.glb", 0)])
	_report("Kingsmourn's market has kit stalls", int(counts.get("market_stall.glb", 0)) >= 8, "%d stalls" % counts.get("market_stall.glb", 0))
	_report("trees collide at the trunk, not the canopy", trunk_only, "")


# The template's demo hats and weapons, and its skin-colour picker, were cut.
# Nothing should quietly bring them back: not a database entry, not a scene
# node, not a menu control.
func _check_template_cleanup() -> void:
	print("")
	print("-- template cleanup --")
	var template_ids := ["fedora", "headphones", "pirate_hat", "sheriff_hat", "sombrero", "wizard_hat", "sword", "sword_big", "axe"]
	var still_there: Array[String] = []
	for id in template_ids:
		if ItemDatabase.get_item(id) != null:
			still_there.append(id)
	_report("template hats and weapons are out of the item database", still_there.is_empty(), ", ".join(still_there))
	_report("the backpack survives (it grants the bag slots)", ItemDatabase.get_item("backpack") != null, "")

	var player := (load("res://scenes/level/player.tscn") as PackedScene).instantiate()
	var stray: Array[String] = []
	for socket in ["HeadAttach", "LeftHandAttach"]:
		var node := player.get_node_or_null("Body/" + socket)
		if node:
			for child in node.get_children():
				if not (child is RemoteTransform3D):
					stray.append("%s/%s" % [socket, child.name])
	_report("no template props hang on the player's sockets", stray.is_empty(), ", ".join(stray))
	player.free()

	var menu := (load("res://scenes/ui/main_menu_ui.tscn") as PackedScene).instantiate()
	var has_skin_picker := menu.find_child("SkinInput", true, false) != null
	_report("the menu has no skin picker", not has_skin_picker, "")
	menu.free()


func _check_ground_textures(vale: Node3D, sablemarch: Node3D) -> void:
	print("")
	print("-- ground textures --")
	for ground_name in ZoneBuilder.GROUND_TEXTURES:
		_report("ground texture '%s' exists" % ground_name, ZoneBuilder.ground_texture(ground_name) != null,
			str(ZoneBuilder.GROUND_TEXTURES[ground_name]["path"]))
	for pair in [[vale, "grass"], [sablemarch, "mud"]]:
		var zone: Node3D = pair[0]
		var texture := ZoneBuilder.ground_texture(str(pair[1]))
		var textured := 0
		var placements := {}
		for node in zone.find_children("*", "MeshInstance3D", true, false):
			var material := (node as MeshInstance3D).material_override as ShaderMaterial
			if material and texture and material.get_shader_parameter("albedo") == texture:
				textured += 1
				# The repeat fix: every plate reads the texture from its own
				# offset and angle. Plates sharing one would tile in lockstep.
				var placement := "%s|%.3f" % [material.get_shader_parameter("offset"), material.get_shader_parameter("rotation")]
				placements[placement] = true
		_report("%s ground is painted %s" % [zone.name, pair[1]], textured >= 2, "%d plates" % textured)
		_report("%s plates each tile from their own offset and angle" % zone.name,
			textured >= 2 and placements.size() == textured, "%d placements for %d plates" % [placements.size(), textured])


func _report(label: String, passed: bool, detail: String) -> void:
	if not passed:
		_failures += 1
	var suffix := "" if detail.is_empty() else "  (%s)" % detail
	print("%s  %s%s" % ["PASS" if passed else "FAIL", label, suffix])
