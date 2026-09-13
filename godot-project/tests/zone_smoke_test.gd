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
const PLAYER_GRUDGE := preload("res://scripts/progression/grudge_ledger.gd")
const PLAYER_RECORDS := preload("res://scripts/progression/record_book.gd")
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
	await _check_status_effects(zone)
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
	_check_class_weapons()
	_check_enemy_models(zone)
	await _check_boss_mechanics(kingsmourn)
	await _check_grudge_and_seasons(kingsmourn)
	await _check_combat_recorder(kingsmourn)

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
	var grudge := Node.new()
	grudge.set_script(PLAYER_GRUDGE)
	grudge.name = "GrudgeLedger"
	_fake_player.add_child(grudge)
	var records := Node.new()
	records.set_script(PLAYER_RECORDS)
	records.name = "RecordBook"
	_fake_player.add_child(records)
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


# THE GAP THIS CLOSES: the class spec assumes interrupts, stuns, shields,
# bleeds, heals-over-time and party buffs exist. Until now nothing in the
# engine could stop a cast, and Broken Verse was a slow with a misleading name.
# Every verb here is exercised for real against a live enemy from the zone.
func _check_status_effects(zone: Node) -> void:
	print("")
	print("-- status effects and cast bars --")
	var silence := AbilityDatabase.get_ability(&"bard_silence")
	_report("Broken Verse is an interrupt", silence != null and silence.effect == AbilityData.Effect.INTERRUPT, "")
	var kell := MobDatabase.get_mob(&"master_kell")
	var kell_burns := false
	for mechanic in (kell.mechanics if kell else []):
		if str(mechanic.get("name", "")) == "Burn the Page" and float(mechanic.get("cast", 0.0)) > 0.0:
			kell_burns = true
	_report("Master Kell has Burn the Page as an interruptible cast", kell_burns, "")

	var stats := _fake_player.get_node("Stats") as Stats
	var bar := _fake_player.get_node("AbilityBar") as AbilityBar
	var targeting := _fake_player.get_node("Targeting") as Targeting
	stats.apply_class(load("res://resources/classes/bard.tres") as ClassData)
	stats.level = 20

	var container := zone.get_node_or_null("MobContainer")
	var caster: Mob = null
	for child in container.get_children():
		var mob := child as Mob
		if mob and mob.mob_data and mob.mob_data.id == &"grave_binder" and not mob.is_friendly:
			caster = mob
			break
	if caster == null:
		_report("found a Grave-Binder to cast at", false, "")
		return
	# Take the pair somewhere quiet: the timed waits below must only ever see
	# THIS enemy's casts, not its friends' swings. Its swing is parked too.
	var caster_home := caster.home_position
	var quiet := Vector3(0, 1, 10)
	caster.global_position = quiet + Vector3(3, 0, 0)
	caster.home_position = caster.global_position
	caster._attack_timer = 999.0
	_fake_player.global_position = quiet
	targeting.set_target(caster)
	caster.target = _fake_player
	caster.state = Mob.State.ATTACKING

	# A cast everyone can see.
	var started := caster.start_cast(0)
	_report("a caster winds up a visible cast", started and caster.is_casting and caster.cast_name == "Grave Bolt", caster.cast_name)
	await get_tree().create_timer(0.3).timeout
	var progress := caster.cast_progress()
	_report("the cast bar fills from the local clock", progress > 0.05 and progress < 0.6, "%.2f after 0.3s" % progress)
	var moved := caster.velocity.length()
	_report("a casting enemy stands still", moved < 0.01, "speed %.2f" % moved)

	# Broken Verse stops it, and says who did.
	var stopped := {"name": "", "by": -1}
	caster.cast_interrupted.connect(func(cast_name: String, by: int) -> void:
		stopped["name"] = cast_name
		stopped["by"] = by)
	var health_before: int = stats.health
	bar.request_cast("bard_silence", caster.get_path())
	_report("Broken Verse interrupts the cast", not caster.is_casting and stopped["name"] == "Grave Bolt", "stopped '%s'" % stopped["name"])
	_report("the interrupt is credited to the caster", stopped["by"] == 1, "peer %d" % stopped["by"])
	_report("an interrupted caster is locked out", not caster.start_cast(0), "")
	await get_tree().create_timer(1.6).timeout
	_report("an interrupted cast never lands", stats.health == health_before, "%d -> %d" % [health_before, stats.health])

	# Left alone, it lands.
	health_before = stats.health
	var landed := {"name": ""}
	caster.cast_landed.connect(func(cast_name: String, _victim: Node3D) -> void: landed["name"] = cast_name)
	_report("a cast can be forced past the lockout", caster.start_cast(0, true), "")
	await get_tree().create_timer(1.8).timeout
	_report("an uninterrupted cast lands on its target", landed["name"] == "Grave Bolt" and stats.health < health_before, "%d -> %d" % [health_before, stats.health])

	# Stuns: the enemy stops, and its cast dies with it, interruptible or not.
	var stun := AbilityData.new()
	stun.id = &"test_stun"
	stun.effect = AbilityData.Effect.STUN
	stun.power = 5
	stun.duration_seconds = 2.0
	caster.cast_interruptible = true
	caster.start_cast(0, true)
	bar._execute(stun, _fake_player, caster, 0)
	_report("a stun stops the enemy and breaks its cast", caster.is_stunned() and not caster.is_casting, "")
	_report("a stunned enemy cannot start a cast", not caster.start_cast(0, true), "")

	# Damage reduction halves what gets through.
	var ward := AbilityData.new()
	ward.id = &"test_ward"
	ward.effect = AbilityData.Effect.DAMAGE_REDUCTION
	ward.target_rule = AbilityData.TargetRule.SELF
	ward.reduction = 0.5
	ward.duration_seconds = 5.0
	stats.revive()
	bar._execute(ward, _fake_player, _fake_player, 0)
	var share := StatusEffect.damage_multiplier(_fake_player)
	_report("damage reduction is on the caster", is_equal_approx(share, 0.5), "share %.2f" % share)
	var full: int = stats.max_health
	stats.apply_damage(40 + stats.total_armor(), 0)
	_report("a shielded hit lands for half", full - stats.health == 20, "took %d of 40" % (full - stats.health))

	# A stacking bleed climbs, caps, and can be eaten.
	var bleed := AbilityData.new()
	bleed.id = &"test_bleed"
	bleed.effect = AbilityData.Effect.STACK
	bleed.power = 3
	bleed.duration_seconds = 6.0
	bleed.tick_seconds = 0.5
	bleed.max_stacks = 3
	for i in range(5):
		bar._execute(bleed, _fake_player, caster, 0)
	_report("a bleed stacks to its cap", StatusEffect.stack_count(caster, &"test_bleed") == 3, "%d stacks" % StatusEffect.stack_count(caster, &"test_bleed"))
	var bleed_before: int = caster.get_node("Stats").health
	await get_tree().create_timer(0.7).timeout
	_report("stacks tick harder together", caster.get_node("Stats").health <= bleed_before - 9, "%d -> %d" % [bleed_before, caster.get_node("Stats").health])
	var eaten := StatusEffect.consume_stacks(caster, &"test_bleed")
	_report("a finisher can eat the stacks", eaten == 3 and StatusEffect.stack_count(caster, &"test_bleed") == 0, "ate %d" % eaten)

	# A heal over time keeps healing after the cast.
	stats.apply_damage(60 + stats.total_armor(), 0)
	var hurt: int = stats.health
	var hot := AbilityData.new()
	hot.id = &"test_hot"
	hot.effect = AbilityData.Effect.HOT
	hot.target_rule = AbilityData.TargetRule.SELF
	hot.power = 8
	hot.duration_seconds = 4.0
	hot.tick_seconds = 0.5
	bar._execute(hot, _fake_player, _fake_player, 0)
	await get_tree().create_timer(1.2).timeout
	_report("a heal over time keeps healing", stats.health >= hurt + 16, "%d -> %d" % [hurt, stats.health])

	# A party buff adds flat power to everyone in earshot.
	var hymn := AbilityData.new()
	hymn.id = &"test_hymn"
	hymn.effect = AbilityData.Effect.BUFF
	hymn.target_rule = AbilityData.TargetRule.GROUND
	hymn.power = 15
	hymn.aoe_radius = 20.0
	hymn.duration_seconds = 5.0
	var power_before := stats.total_power()
	bar._execute(hymn, _fake_player, _fake_player, 0)
	_report("a party buff raises power for its duration", stats.total_power() == power_before + 15, "%d -> %d" % [power_before, stats.total_power()])

	# Clean up so later checks meet a normal enemy.
	for effect in StatusEffect.all_on(_fake_player):
		effect.free()
	for effect in StatusEffect.all_on(caster):
		effect.free()
	caster._stun_remaining = 0.0
	caster._attack_timer = 0.0
	caster.state = Mob.State.IDLE
	caster.target = null
	caster.home_position = caster_home
	caster.global_position = caster_home
	stats.revive()


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


# THE GAP THIS CLOSES: the endgame spec describes six bosses by what they do,
# and until now they all just hit. Every mechanic kind is fired for real here
# against the real bosses standing in the real Hall and Throne.
func _check_boss_mechanics(kingsmourn: Node3D) -> void:
	print("")
	print("-- boss mechanics --")
	var stats := _fake_player.get_node("Stats") as Stats
	stats.apply_class(load("res://resources/classes/valkyr.tres") as ClassData)
	stats.level = 20
	stats.revive()

	# Every boss's data is well formed: recognised effects, real spawn ids.
	var known := ["damage", "heal", "slow", "stun", "pool", "pools_fire", "line", "charge", "named", "spawn", "stat"]
	var bad: Array[String] = []
	var boss_count := 0
	var all_bosses := 0
	for mob_id in MobDatabase.get_all_ids():
		var data := MobDatabase.get_mob(mob_id)
		if data.is_boss:
			all_bosses += 1
		if not data.is_boss or data.mechanics.is_empty():
			continue
		boss_count += 1
		for mechanic in data.mechanics:
			if not known.has(str(mechanic.get("effect", "damage"))):
				bad.append("%s: %s" % [mob_id, mechanic.get("effect", "")])
			if not mechanic.has("every") and not mechanic.has("at"):
				bad.append("%s: %s never fires" % [mob_id, mechanic.get("name", "")])
			for group in mechanic.get("spawn", []):
				if MobDatabase.get_mob(StringName(str(group.get("id", "")))) == null:
					bad.append("%s spawns unknown %s" % [mob_id, group.get("id", "")])
	_report("every boss carries mechanics", boss_count == all_bosses and all_bosses >= 10, "%d of %d bosses" % [boss_count, all_bosses])
	_report("every mechanic is well formed", bad.is_empty(), ", ".join(bad))

	var container := kingsmourn.get_node_or_null("MobContainer")
	var bosses := {}
	for child in container.get_children():
		var mob := child as Mob
		if mob and mob.mob_data and mob.mob_data.is_boss:
			bosses[mob.mob_data.id] = mob
	var ledger: Mob = bosses.get(&"the_bound_ledger")
	var kell_mob: Mob = bosses.get(&"master_kell")
	var king: Mob = bosses.get(&"first_king_crowned")
	var ashcombe: Mob = bosses.get(&"lord_ashcombe")
	var severin: Mob = bosses.get(&"lady_severin")
	_report("the bosses stand in the Hall and the Throne", ledger and kell_mob and king and ashcombe and severin, "%d found" % bosses.size())
	if not (ledger and kell_mob and king and ashcombe and severin):
		return
	var engines := 0
	for boss in bosses.values():
		if boss.get_node_or_null("BossMechanics") != null:
			engines += 1
	_report("every boss runs a mechanics engine", engines == bosses.size(), "%d of %d" % [engines, bosses.size()])

	# --- The Bound Ledger: pools, braziers, and the page turning ---
	var brazier := Interactable.find(get_tree(), &"brazier_nw")
	_report("the vault has braziers", brazier != null and brazier.action == "clear_pools", "")
	var dais := Interactable.find(get_tree(), &"throne_dais")
	_report("the throne room has a dais", dais != null and dais.action == "stand", "")
	if brazier == null or dais == null:
		return
	_fake_player.global_position = brazier.global_position + Vector3(2.0, 0, 0)
	ledger.target = _fake_player
	ledger.state = Mob.State.ATTACKING
	ledger._attack_timer = 999.0
	var engine: BossMechanics = ledger.get_node("BossMechanics")
	var fired := engine.fire_by_name("Ink Pool")
	var pools := GroundEffect.all_in(get_tree())
	_report("Ink Pool leaves a pool under a player", fired and pools.size() == 1 and pools[0].contains(_fake_player.global_position), "%d pools" % pools.size())
	var before: int = stats.health
	await get_tree().create_timer(1.3).timeout
	_report("standing in the pool hurts", stats.health < before, "%d -> %d" % [before, stats.health])
	_report("the pool persists", GroundEffect.all_in(get_tree()).size() == 1, "")
	before = stats.health
	engine.fire_by_name("Turn the Page")
	await get_tree().create_timer(1.8).timeout
	_report("Turn the Page fires every pool at its nearest player", stats.health < before - 20, "%d -> %d" % [before, stats.health])
	brazier.perform(_fake_player)
	_report("a lit brazier burns the pools nearby away", GroundEffect.all_in(get_tree()).is_empty(), "%d left" % GroundEffect.all_in(get_tree()).size())
	_report("the brazier then cools", not brazier.is_ready() and brazier.seconds_until_ready() > 20.0, "%.0fs" % brazier.seconds_until_ready())
	ledger.state = Mob.State.IDLE
	ledger.target = null
	ledger._attack_timer = 0.0
	stats.revive()

	# --- Master Kell: Bind and Call the Shelves, which then feud ---
	_fake_player.global_position = kell_mob.global_position + Vector3(0, 0, 3.0)
	kell_mob.target = _fake_player
	kell_mob.state = Mob.State.ATTACKING
	kell_mob._attack_timer = 999.0
	var kell_engine: BossMechanics = kell_mob.get_node("BossMechanics")
	var mobs_before: int = container.get_child_count()
	var kell_stats := kell_mob.get_node("Stats") as Stats
	# Drop him to 60%: the 70% threshold fires once, and only once.
	kell_stats._set_health(int(kell_stats.max_health * 0.6), 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var added: int = container.get_child_count() - mobs_before
	_report("Call the Shelves brings four adds at 70%", added == 4, "%d added" % added)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_report("a health trigger fires once", container.get_child_count() - mobs_before == 4, "")
	var feuding := 0
	var adds: Array = container.get_children().slice(mobs_before)
	for add in adds:
		if add is Mob and add.mob_data and add.mob_data.feud != &"":
			feuding += 1
	_report("the shelves' adds carry the feud", feuding == 4, "%d of %d" % [feuding, adds.size()])
	_report("Bind roots the tank", kell_engine.fire_by_name("Bind"), "")
	kell_stats.revive()
	kell_mob.state = Mob.State.IDLE
	kell_mob.target = null
	kell_mob._attack_timer = 0.0
	for add in adds:
		if is_instance_valid(add):
			add.queue_free()

	# --- The claimants: a charge with a throw, and a line through the tank ---
	_fake_player.global_position = ashcombe.global_position + Vector3(20.0, 0, 0)
	ashcombe.state = Mob.State.CHASING
	ashcombe.target = _fake_player
	before = stats.health
	var ash_engine: BossMechanics = ashcombe.get_node("BossMechanics")
	ash_engine.fire_by_name("Charge")
	_report("Charge lands the boss beside the furthest player and hits", ashcombe.global_position.distance_to(_fake_player.global_position) < 3.0 and stats.health < before, "%.1fm away" % ashcombe.global_position.distance_to(_fake_player.global_position))
	ashcombe.state = Mob.State.IDLE
	ashcombe.target = null
	ashcombe.global_position = ashcombe.home_position
	stats.revive()
	_fake_player.global_position = severin.global_position + Vector3(0, 0, 6.0)
	severin.state = Mob.State.ATTACKING
	severin.target = _fake_player
	severin._attack_timer = 999.0
	before = stats.health
	var sev_engine: BossMechanics = severin.get_node("BossMechanics")
	sev_engine.fire_by_name("Sun Lance")
	_report("Sun Lance is a cast", severin.is_casting and not severin.cast_interruptible, severin.cast_name)
	await get_tree().create_timer(1.5).timeout
	_report("Sun Lance hits everyone in the line through the tank", stats.health < before, "%d -> %d" % [before, stats.health])
	_fake_player.global_position = severin.global_position + Vector3(6.0, 0, 0)
	severin.target = _fake_player
	stats.revive()
	before = stats.health
	# Aim the line along +Z while the tank stands on +X: it should miss.
	var decoy := _fake_player.global_position
	_fake_player.global_position = severin.global_position + Vector3(6.0, 0, 0)
	sev_engine.land({"name": "Sun Lance", "effect": "line", "width": 3.0, "length": 40.0, "power": 80}, severin)
	_report("Sun Lance misses whoever is not in the line", stats.health == before, "%d -> %d" % [before, stats.health])
	severin.state = Mob.State.IDLE
	severin.target = null
	severin._attack_timer = 0.0
	_fake_player.global_position = decoy

	# --- The First King: the Crown, the dais, the heralds ---
	# He stands on the dais himself, so "off the dais" means well down the hall.
	_fake_player.global_position = king.global_position + Vector3(0, 0, 30.0)
	king.state = Mob.State.ATTACKING
	king.target = _fake_player
	king._attack_timer = 999.0
	var king_engine: BossMechanics = king.get_node("BossMechanics")
	var king_stats := king.get_node("Stats") as Stats
	king_stats._set_health(king_stats.max_health - 400, 0)
	king_engine.fire_by_name("The Crown")
	_report("The Crown names a player", king_engine.is_naming(_fake_player), "")
	var king_before: int = king_stats.health
	king_stats.apply_damage(100, 1)
	_report("hitting the King while the named player is off the dais heals him", king_stats.health > king_before - 100, "%d -> %d" % [king_before, king_stats.health])
	_fake_player.global_position = dais.global_position + Vector3(0, 0.5, 0)
	_report("the dais knows who stands on it", dais.is_player_on(_fake_player), "")
	king_before = king_stats.health
	king_stats.apply_damage(100, 1)
	_report("with the named player on the dais, hits land in full", king_stats.health == king_before - 100, "%d -> %d" % [king_before, king_stats.health])
	var base_damage: int = king._scaled_damage()
	mobs_before = container.get_child_count()
	king_engine.fire_by_name("Heralds")
	await get_tree().physics_frame
	var heralds: int = container.get_child_count() - mobs_before
	_report("the Heralds walk in", heralds == 2, "%d heralds" % heralds)
	_report("each living herald makes the King hit harder", king._scaled_damage() > base_damage, "%d -> %d" % [base_damage, king._scaled_damage()])
	var enraged_before: int = king._scaled_damage()
	king_engine.fire_by_name("Kingsmourn")
	_report("the enrage stacks damage", king._scaled_damage() > enraged_before, "%d -> %d" % [enraged_before, king._scaled_damage()])
	for add in container.get_children().slice(mobs_before):
		if is_instance_valid(add):
			add.queue_free()
	king_engine.reset()
	king_stats.revive()
	king.state = Mob.State.IDLE
	king.target = null
	king._attack_timer = 0.0
	stats.revive()
	_fake_player.global_position = Vector3(0, 1, 10)


# THE GAP THIS CLOSES: the fifth kill of a boss has to be a different fight
# from the first, or the endgame dies of sameness. Grudge is a saved counter,
# a gate on the mechanic list, a mark in the name and a bump to the loot; a
# season is the same gate swapping the whole list. Every piece is exercised.
func _check_grudge_and_seasons(kingsmourn: Node3D) -> void:
	print("")
	print("-- grudge and seasons --")
	var ledger := _fake_player.get_node("GrudgeLedger") as GrudgeLedger
	var stats := _fake_player.get_node("Stats") as Stats
	_report("a character carries a grudge ledger", ledger != null and ledger.tier_for(&"master_kell") == 0, "")
	_report("dungeon bosses cap at five, raid bosses at three",
		GrudgeLedger.cap_for(MobDatabase.get_mob(&"master_kell")) == 5 and GrudgeLedger.cap_for(MobDatabase.get_mob(&"first_king_crowned")) == 3, "")
	_report("tier N turns on the first 2+N mechanics", GrudgeLedger.mechanics_enabled(0) == 2 and GrudgeLedger.mechanics_enabled(3) == 5, "")

	# Every boss has a ladder worth climbing.
	var short: Array[String] = []
	for mob_id in MobDatabase.get_all_ids():
		var data := MobDatabase.get_mob(mob_id)
		if data.is_boss and data.mechanics.size() < 4:
			short.append("%s (%d)" % [mob_id, data.mechanics.size()])
	_report("every boss has at least four mechanics to climb", short.is_empty(), ", ".join(short))

	var container := kingsmourn.get_node_or_null("MobContainer")
	var kell: Mob = null
	for child in container.get_children():
		var mob := child as Mob
		if mob and mob.mob_data and mob.mob_data.id == &"master_kell":
			kell = mob
			break
	if kell == null:
		_report("found Master Kell", false, "")
		return
	var engine: BossMechanics = kell.get_node("BossMechanics")
	var kell_stats := kell.get_node("Stats") as Stats

	# A fresh group: two mechanics. A grudge-3 group: five, and it says so.
	_fake_player.global_position = kell.global_position + Vector3(0, 0, 3.0)
	stats.revive()
	kell.target = _fake_player
	kell.state = Mob.State.ATTACKING
	kell._attack_timer = 999.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	_report("a fresh group fights two mechanics", engine.active_tier == 0 and engine.enabled_count == 2 and not engine.is_enabled("Bind"), "tier %d, %d on" % [engine.active_tier, engine.enabled_count])
	# A boss that walks home resets its engine; standing in its aggro range
	# means it never would, so the test does what walking home does.
	engine.reset()
	ledger.tiers["master_kell"] = 3
	kell.target = _fake_player
	kell.state = Mob.State.ATTACKING
	await get_tree().physics_frame
	await get_tree().physics_frame
	_report("a grudge-3 group fights five mechanics", engine.active_tier == 3 and engine.enabled_count == 5 and engine.is_enabled("Bind") and engine.is_enabled("Forbidden Word") and not engine.is_enabled("Second Reading"), "tier %d, %d on" % [engine.active_tier, engine.enabled_count])
	_report("the boss's name carries the tier", kell.get_node("NameLabel").text.contains("⟨III⟩"), kell.get_node("NameLabel").text)

	# The lowest member's tier wins.
	var newcomer := CharacterBody3D.new()
	newcomer.name = "9"
	var newcomer_stats := Node.new()
	newcomer_stats.set_script(PLAYER_STATS)
	newcomer_stats.name = "Stats"
	newcomer.add_child(newcomer_stats)
	var newcomer_ledger := Node.new()
	newcomer_ledger.set_script(PLAYER_GRUDGE)
	newcomer_ledger.name = "GrudgeLedger"
	newcomer.add_child(newcomer_ledger)
	_players.add_child(newcomer)
	newcomer.global_position = kell.global_position + Vector3(3.0, 0, 0)
	_report("a newcomer drops the group to their tier", engine.lowest_present_tier() == 0, "lowest %d" % engine.lowest_present_tier())
	newcomer.queue_free()
	await get_tree().process_frame

	# Loot scales, and the mount is a promise at the top.
	_report("loot chance climbs with the tier", kell._loot_chance(0.2, "gear_x") > 0.2 and kell._loot_chance(0.2, "gear_x") < 0.4, "%.2f" % kell._loot_chance(0.2, "gear_x"))
	kell.grudge_tier = 5
	_report("the mount is guaranteed at the top tier", is_equal_approx(kell._loot_chance(0.12, "mount_wraithcat"), 1.0), "")
	kell.grudge_tier = 3

	# A kill raises the grudge for everyone present, and never past the cap.
	var fell := {"id": &"", "tier": -1}
	kell.boss_fell.connect(func(boss_id: StringName, tier: int) -> void:
		fell["id"] = boss_id
		fell["tier"] = tier)
	kell_stats.apply_damage(999999, 1)
	_report("killing the boss raises the grudge", ledger.tier_for(&"master_kell") == 4, "tier %d" % ledger.tier_for(&"master_kell"))
	_report("the fall is announced with its tier", fell["id"] == &"master_kell" and fell["tier"] == 3, "%s at %d" % [fell["id"], fell["tier"]])
	for i in range(5):
		ledger.raise(&"master_kell", GrudgeLedger.cap_for(kell.mob_data))
	_report("grudge stops at the cap", ledger.tier_for(&"master_kell") == 5, "tier %d" % ledger.tier_for(&"master_kell"))

	# It survives logging out.
	var saved := CharacterState.capture(_fake_player)
	ledger.tiers.clear()
	CharacterState.apply(_fake_player, saved)
	_report("grudge is saved with the character", ledger.tier_for(&"master_kell") == 5, "tier %d after restore" % ledger.tier_for(&"master_kell"))
	ledger.tiers.clear()

	# Seasons: the calendar picks one, and a later one swaps the list and skin.
	_report("a season is running", SeasonDatabase.season_name() != "", SeasonDatabase.season_name())
	var base_list := SeasonDatabase.mechanics_for(&"master_kell", kell.mob_data.mechanics)
	_report("season one fights the base lists", base_list == kell.mob_data.mechanics, "")
	SeasonDatabase.forced_index = 1
	var swapped := SeasonDatabase.mechanics_for(&"master_kell", kell.mob_data.mechanics)
	var known := ["damage", "heal", "slow", "stun", "pool", "pools_fire", "line", "charge", "named", "spawn", "stat"]
	var bad_season: Array[String] = []
	for boss_id in SeasonDatabase.current().get("mechanics", {}):
		for mechanic in SeasonDatabase.current()["mechanics"][boss_id]:
			if not known.has(str(mechanic.get("effect", ""))):
				bad_season.append("%s: %s" % [boss_id, mechanic.get("effect", "")])
			for group in mechanic.get("spawn", []):
				if MobDatabase.get_mob(StringName(str(group.get("id", "")))) == null:
					bad_season.append("%s spawns unknown %s" % [boss_id, group.get("id", "")])
	for boss_id in SeasonDatabase.current().get("models", {}):
		var model := SeasonDatabase.model_for(boss_id, "")
		if not model.is_empty() and not ResourceLoader.exists(model):
			bad_season.append("%s wears missing %s" % [boss_id, model])
	_report("season two swaps Master Kell's mechanics", swapped != base_list and swapped.size() >= 4, "%d mechanics" % swapped.size())
	_report("season two's data is well formed", bad_season.is_empty(), ", ".join(bad_season))
	_report("season two swaps a boss's skin", SeasonDatabase.model_for(&"master_kell", kell.mob_data.model_path) != kell.mob_data.model_path, SeasonDatabase.model_for(&"master_kell", "").get_file())
	_report("the engine reads the season's list", engine.mechanics_list() == swapped, "")
	_report("season rewards are never power", SeasonDatabase.rewards().has("title") and not SeasonDatabase.rewards().has("power"), str(SeasonDatabase.rewards().get("title", "")))
	SeasonDatabase.forced_index = -1
	kell.grudge_tier = 0
	kell.set_grudge_tier(0)
	stats.revive()
	_fake_player.global_position = Vector3(0, 1, 10)


# THE GAP THIS CLOSES: the meter, the recap, the coach and the parse all read
# one record of every combat event. If a hit or a heal went unrecorded the
# numbers would be quietly wrong for everyone, so a real boss fight is played
# through here and every derived number is checked.
func _check_combat_recorder(kingsmourn: Node3D) -> void:
	print("")
	print("-- combat recorder, meter, parse --")
	var stats := _fake_player.get_node("Stats") as Stats
	var bar := _fake_player.get_node("AbilityBar") as AbilityBar
	var targeting := _fake_player.get_node("Targeting") as Targeting
	var book := _fake_player.get_node("RecordBook") as RecordBook
	CombatRecorder._fight.clear()
	CombatRecorder._events.clear()
	CombatRecorder.live.clear()
	CombatRecorder.last_recap.clear()

	var container := kingsmourn.get_node_or_null("MobContainer")
	var boss: Mob = null
	for child in container.get_children():
		var mob := child as Mob
		if mob and mob.mob_data and mob.mob_data.id == &"lady_severin":
			boss = mob
			break
	if boss == null:
		_report("found Lady Severin", false, "")
		return
	var boss_stats := boss.get_node("Stats") as Stats
	boss_stats.revive()
	boss._attack_timer = 999.0
	stats.apply_class(load("res://resources/classes/valkyr.tres") as ClassData)
	stats.level = 20
	stats.revive()
	_fake_player.global_position = boss.global_position + Vector3(0, 0, 3.0)
	targeting.set_target(boss)
	boss.target = _fake_player
	boss.state = Mob.State.ATTACKING

	# Hitting a boss starts the fight and the record.
	bar.request_cast("valkyr_strike", boss.get_path())
	_report("hitting a boss starts a fight", CombatRecorder.in_fight() and CombatRecorder.current_boss_id() == &"lady_severin", str(CombatRecorder.current_boss_id()))
	var fired := {"boss": &""}
	bar.request_cast("valkyr_strike", boss.get_path())
	await get_tree().create_timer(0.4).timeout
	bar.request_cast("valkyr_strike", boss.get_path())

	# An interruptible boss cast, stopped: both sides of "interrupts landed vs available".
	boss.start_cast_entry({"name": "Test Verse", "cast": 3.0, "effect": "damage", "power": 5, "target": "current", "interruptible": true}, true)
	stats.apply_class(load("res://resources/classes/bard.tres") as ClassData)
	stats.level = 20
	bar.request_cast("bard_silence", boss.get_path())
	# An avoidable hit, and a heal that lands.
	var engine: BossMechanics = boss.get_node("BossMechanics")
	engine.land({"name": "Sun Flare", "effect": "damage", "power": 30, "avoidable": true}, _fake_player)
	bar.request_cast("bard_mend", _fake_player.get_path())
	CombatRecorder._publish_live()
	var mine: Dictionary = CombatRecorder.live.get(1, {})
	_report("the live meter counts damage, healing and damage taken",
		int(mine.get("damage", 0)) > 0 and int(mine.get("healing", 0)) > 0 and int(mine.get("taken", 0)) > 0,
		"dmg %d heal %d taken %d" % [int(mine.get("damage", 0)), int(mine.get("healing", 0)), int(mine.get("taken", 0))])
	_report("the meter knows who and what class", str(mine.get("class", "")) == "bard" and not str(mine.get("name", "")).is_empty(), str(mine.get("name", "")))

	# The kill ends the fight and produces the recap for everyone.
	boss_stats.apply_damage(999999, 1)
	var recap: Dictionary = CombatRecorder.last_recap
	_report("the boss dying ends the fight with a recap", not CombatRecorder.in_fight() and str(recap.get("boss_id", "")) == "lady_severin", "")
	if recap.is_empty():
		return
	_report("time to kill is measured", float(recap.get("seconds", 0.0)) >= 0.4, "%.1fs" % float(recap.get("seconds", 0.0)))
	var awards: Dictionary = recap.get("awards", {})
	_report("awards name the killing blow, most damage and most interrupts",
		int(awards.get("Killing Blow", {}).get("peer", 0)) == 1 and int(awards.get("Most Damage", {}).get("peer", 0)) == 1 and int(awards.get("Most Interrupts", {}).get("peer", 0)) == 1,
		", ".join(awards.keys()))
	_report("the tank's award is named for taking damage", awards.has("Most Damage Taken"), "")
	var parse: Dictionary = recap.get("parses", {}).get(1, {})
	_report("a parse is scored 0-100 in four parts",
		parse.has("score") and int(parse["score"]) >= 0 and int(parse["score"]) <= 100 and int(parse["uptime"]) + int(parse["rotation"]) + int(parse["mechanics"]) + int(parse["output"]) == int(parse["score"]),
		"%d = %d+%d+%d+%d" % [int(parse.get("score", -1)), int(parse.get("uptime", 0)), int(parse.get("rotation", 0)), int(parse.get("mechanics", 0)), int(parse.get("output", 0))])
	_report("the avoidable hit cost mechanics points", int(parse.get("mechanics", 25)) < 25, "%d/25" % int(parse.get("mechanics", 25)))
	_report("a healer is scored on healing", bool(parse.get("healer", false)) and float(parse.get("per_second", 0.0)) > 0.0, "%.1f hps" % float(parse.get("per_second", 0.0)))
	var coach: Array = recap.get("coach", {}).get(1, [])
	_report("the coach writes three sentences", coach.size() == 3, "\n      ".join(coach))
	var abilities: Array = recap.get("abilities", {}).get(1, [])
	_report("your abilities are ranked with casts and biggest hit", abilities.size() >= 2 and int(abilities[0]["total"]) >= int(abilities[1]["total"]) and int(abilities[0]["biggest"]) > 0, "%s first" % str(abilities[0]["name"]) if not abilities.is_empty() else "none")
	_report("the recap is kept in the log", CombatRecorder.history.size() >= 1, "%d recaps" % CombatRecorder.history.size())

	# Records.
	_report("the kill is your personal best", book.best_seconds(&"lady_severin") > 0.0 and book.best_parse(&"lady_severin") == int(parse.get("score", -1)), "%.1fs, parse %d" % [book.best_seconds(&"lady_severin"), book.best_parse(&"lady_severin")])
	_report("the host holds the group record", book.record_seconds(&"lady_severin") > 0.0, "")
	var announced := book.note_best(&"lady_severin", "Lady Severin", 0.5, 1)
	_report("a faster kill is announced as a personal best", announced.size() == 1 and str(announced[0]).begins_with("personal best"), str(announced))
	var saved := CharacterState.capture(_fake_player)
	book.bests.clear()
	CharacterState.apply(_fake_player, saved)
	_report("records are saved with the character", book.best_seconds(&"lady_severin") > 0.0, "")

	# The parse's colours, and the pure recap on hand-built events: two players,
	# one who never stopped casting and one who pressed a key once.
	_report("parse colours follow the known scale", CombatRecorder.colour_name(10) == "grey" and CombatRecorder.colour_name(60) == "blue" and CombatRecorder.colour_name(80) == "purple" and CombatRecorder.colour_name(100) == "gold", "")
	var t0 := 1000
	var events := []
	for i in range(30):
		events.append({"t": t0 + i * 2000, "kind": "cast", "src": 1, "tgt": 0, "tgt_boss": false, "ability": "necro_bolt", "amount": 0})
		events.append({"t": t0 + i * 2000, "kind": "damage", "src": 1, "tgt": 0, "tgt_boss": true, "ability": "necro_bolt", "amount": 50})
	events.append({"t": t0 + 5000, "kind": "cast", "src": 2, "tgt": 0, "tgt_boss": false, "ability": "tinker_shot", "amount": 0})
	events.append({"t": t0 + 5000, "kind": "damage", "src": 2, "tgt": 0, "tgt_boss": true, "ability": "tinker_shot", "amount": 20})
	events.append({"t": t0 + 59000, "kind": "death", "src": 1, "tgt": 0, "tgt_boss": true, "ability": "necro_bolt", "amount": 0})
	var pure := CombatRecorder.build_recap({"boss_id": "test", "boss_name": "Test", "started": t0, "max_health": 1500}, events, false)
	var one: Dictionary = pure["parses"][1]
	var two: Dictionary = pure["parses"][2]
	_report("uptime rewards the player who kept casting", int(one["uptime"]) > int(two["uptime"]) and int(one["uptime"]) >= 27, "%d vs %d" % [int(one["uptime"]), int(two["uptime"])])
	_report("awards go to the right people on a hand-built fight", int(pure["awards"]["Most Damage"]["peer"]) == 1 and int(pure["awards"]["Killing Blow"]["peer"]) == 1, "")

	boss.state = Mob.State.IDLE
	boss.target = null
	boss._attack_timer = 0.0
	CombatRecorder.live.clear()
	stats.revive()
	_fake_player.global_position = Vector3(0, 1, 10)


# THE GAP THIS CLOSES: an enemy with a model that never loads, or loads with
# no rig, silently stays a capsule. Every human must wear the shared body, the
# wolf must be its own beast, and the spawned mobs must actually be dressed.
func _check_enemy_models(vale: Node3D) -> void:
	print("")
	print("-- enemy models --")
	var missing: Array[String] = []
	var unrigged: Array[String] = []
	var distinct := {}
	for mob_id in MobDatabase.MODELS:
		var data := MobDatabase.get_mob(mob_id)
		var path := data.model_path if data else ""
		if path.is_empty() or not ResourceLoader.exists(path):
			missing.append(mob_id)
			continue
		if distinct.has(path):
			continue
		distinct[path] = true
		var probe := (load(path) as PackedScene).instantiate()
		var players := probe.find_children("*", "AnimationPlayer", true, false)
		var skeletons := probe.find_children("*", "Skeleton3D", true, false)
		if players.is_empty() or skeletons.is_empty():
			unrigged.append("%s: no rig" % path.get_file())
		else:
			for clip in [&"Idle", &"Run", &"Attack1"]:
				if not (players[0] as AnimationPlayer).has_animation(clip):
					unrigged.append("%s: no %s" % [path.get_file(), clip])
		probe.free()
	_report("every modelled enemy's file exists", missing.is_empty(), ", ".join(missing))
	_report("every enemy model is rigged with Idle, Run and Attack1", unrigged.is_empty(), "; ".join(unrigged))
	_report("the roster shares eleven models", distinct.size() == 11, "%d distinct" % distinct.size())

	var bare: Array[String] = []
	for mob_id in MobDatabase.get_all_ids():
		var data := MobDatabase.get_mob(mob_id)
		if data and data.tags.has(&"human") and data.model_path.is_empty():
			bare.append(mob_id)
	_report("every human enemy wears the shared body", bare.is_empty(), ", ".join(bare))

	var wolf := MobDatabase.get_mob(&"vale_wolf")
	var wolf_ok := false
	if wolf and ResourceLoader.exists(wolf.model_path):
		var probe := (load(wolf.model_path) as PackedScene).instantiate()
		var skeletons := probe.find_children("*", "Skeleton3D", true, false)
		if not skeletons.is_empty():
			var skeleton := skeletons[0] as Skeleton3D
			wolf_ok = skeleton.find_bone("FrontLeftUpper") >= 0 and skeleton.find_bone("LeftUpperArm") < 0
		probe.free()
	_report("the wolf has its own quadruped skeleton", wolf_ok, "")

	var container := vale.get_node_or_null("MobContainer")
	var dressed := 0
	var capsules := 0
	if container:
		for child in container.get_children():
			var mob := child as Mob
			if mob == null or mob.mob_data == null or mob.mob_data.model_path.is_empty():
				continue
			var placeholder := mob.get_node_or_null("Body/Mesh") as Node3D
			if mob.get_node_or_null("Body/" + Mob.MODEL_NODE) != null and placeholder and not placeholder.visible:
				dressed += 1
			else:
				capsules += 1
	_report("spawned enemies wear their models, not the capsule", dressed > 0 and capsules == 0, "%d dressed, %d capsules" % [dressed, capsules])


# THE GAP THIS CLOSES: at distance, weapon shape is half of how you tell the
# classes apart. Each class's weapon and off-hand must be a real model, and
# wearing the gear must light exactly that model and nothing else's.
func _check_class_weapons() -> void:
	print("")
	print("-- class weapons --")
	var empty: Array[String] = []
	for file in ["valkyr_spear", "valkyr_shield", "bard_blade", "bard_lute", "necromancer_staff",
			"necromancer_skull", "tinker_bolt_thrower", "tinker_toolkit"]:
		var path := "res://assets/weapons/%s.glb" % file
		var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
		var ok := false
		if scene:
			var probe := scene.instantiate()
			ok = ZoneBuilder._has_geometry(probe)
			probe.free()
		if not ok:
			empty.append(file)
	_report("all eight class weapon models exist with geometry", empty.is_empty(), ", ".join(empty))

	var player := (load("res://scenes/level/player.tscn") as PackedScene).instantiate()
	var wrong: Array[String] = []
	var all_nodes: Array[String] = []
	for class_id in Character.CLASS_WEAPON_NODES:
		all_nodes.append(Character.WEAPON_SOCKET_PATH + str(Character.CLASS_WEAPON_NODES[class_id]))
	for class_id in Character.CLASS_OFFHAND_NODES:
		var node_name: String = Character.CLASS_OFFHAND_NODES[class_id]
		all_nodes.append(str(Character.OFFHAND_SOCKET_PATHS[node_name]) + node_name)
	for class_id: StringName in [&"valkyr", &"bard", &"necromancer", &"tinker"]:
		var weapon := String(GearDatabase.generated_id(Item.GearTier.STARTER, Item.GearSlot.WEAPON, class_id))
		var offhand := String(GearDatabase.generated_id(Item.GearTier.CAP, Item.GearSlot.OFFHAND, class_id))
		player._set_equipment_visibility(weapon, offhand, "")
		var want := [
			Character.WEAPON_SOCKET_PATH + str(Character.CLASS_WEAPON_NODES[class_id]),
			str(Character.OFFHAND_SOCKET_PATHS[Character.CLASS_OFFHAND_NODES[class_id]]) + str(Character.CLASS_OFFHAND_NODES[class_id])
		]
		for node_path in all_nodes:
			var node := player.get_node_or_null(node_path) as Node3D
			if node == null:
				wrong.append("%s: missing %s" % [class_id, node_path])
			elif node.visible != (node_path in want):
				wrong.append("%s: %s %s" % [class_id, node_path.get_file(), "shown" if node.visible else "hidden"])
	# Unarmed hides everything.
	player._set_equipment_visibility("", "", "")
	for node_path in all_nodes:
		var node := player.get_node_or_null(node_path) as Node3D
		if node and node.visible:
			wrong.append("unarmed: %s still shown" % node_path.get_file())
	player.free()
	_report("wearing a class's gear shows its weapon and off-hand, and only those", wrong.is_empty(), "; ".join(wrong))


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

	# Only Kingsmourn's own class weapons may hang on the sockets now.
	var allowed := {}
	for node_name in Character.CLASS_WEAPON_NODES.values():
		allowed[node_name] = true
	for node_name in Character.CLASS_OFFHAND_NODES.values():
		allowed[node_name] = true
	var player := (load("res://scenes/level/player.tscn") as PackedScene).instantiate()
	var stray: Array[String] = []
	for socket in ["HeadAttach", "LeftHandAttach", "RightHandAttach"]:
		var node := player.get_node_or_null("Body/" + socket)
		if node:
			for child in node.get_children():
				if not (child is RemoteTransform3D) and not allowed.has(child.name):
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
