# QuestDatabase — every quest in the game, as data.
#
# The chain below walks a player from the gates of Thornfell out to the
# Deepbarrow, which is roughly levels 1 to 12. Adding a quest is
# adding an entry: no code, no scene work.
#
# The setting, per docs/ironveil-design.md: the king is dead with no heir and
# the great houses are all certain the throne is theirs. The enemies are people.
# Two houses are settled in the reference art — blue-and-gold sword-and-sunburst,
# and a green banner with a white stag — and both are out here throwing their
# weight around.
extends Node

const DEFINITIONS := {
	&"q_arrival":
	{
		"title": "Report to the Gate",
		"giver": &"npc_halvard",
		"level": 1,
		"offer":
		"You're the one the city sent? Gods help us. Walk the wall with me, then we'll talk about what's wrong with this valley.",
		"progress": "Speak with Serjeant Halvard.",
		"completion": "Good. You can follow an order. That already puts you above half the men out here.",
		"objectives": [{"type": "talk", "target": "npc_halvard", "count": 1, "text": "Speak with Serjeant Halvard"}],
		"xp": 30,
		"currency": 2
	},
	&"q_wolves":
	{
		"title": "Thinning the Vale",
		"giver": &"npc_halvard",
		"level": 1,
		"prereq": &"q_arrival",
		"offer":
		"The wolves came down with the cold and never went back up. They've stopped being afraid of people, which tells you how many bodies they've found.",
		"progress": "Cull the wolves in the low pasture.",
		"completion": "That'll keep the flocks alive another week. Small mercies.",
		"objectives": [{"type": "kill", "target": "vale_wolf", "count": 6, "text": "Vale Wolves culled"}],
		"xp": 75,
		"currency": 4,
		"items": {"wolfsbane_ring": 1}
	},
	&"q_bandits":
	{
		"title": "Hedge and Ditch",
		"giver": &"npc_halvard",
		"level": 2,
		"prereq": &"q_wolves",
		"offer":
		"Half these bandits were levy soldiers a year ago. The war ended and nobody paid them. They still have the swords we gave them.",
		"progress": "Break up the bandit camps along the hedgerow.",
		"completion": "I'd have preferred to hang them properly, with a magistrate. There isn't one. There isn't a king either.",
		"objectives": [{"type": "kill_tag", "target": "bandit", "count": 8, "text": "Bandits driven off"}],
		"xp": 90,
		"currency": 6
	},
	&"q_supplies":
	{
		"title": "Stolen Stores",
		"giver": &"npc_maren",
		"level": 2,
		"prereq": &"q_bandits",
		"offer": "They took the winter stores. Bring back what you can find in their camps — anything at all.",
		"progress": "Recover stolen provisions.",
		"completion": "It's not much. It's more than we had this morning. Thank you.",
		"objectives": [{"type": "collect", "target": "chicken_leg", "count": 4, "text": "Provisions recovered"}],
		"xp": 100,
		"currency": 8
	},
	&"q_risen":
	{
		"title": "The War Won't Stay Buried",
		"giver": &"npc_halvard",
		"level": 3,
		"prereq": &"q_supplies",
		"offer":
		"The dead levies are walking again. Somebody is doing that to them on purpose, and when I find out who, I'll want a word.",
		"progress": "Put the risen levies back down.",
		"completion": "They were ours. Every one of them wore our colours. Remember that when someone tells you this war was clean.",
		"objectives": [{"type": "kill", "target": "risen_levy", "count": 6, "text": "Risen Levies put down"}],
		"xp": 130,
		"currency": 10,
		"items": {"halvards_cloak": 1}
	},
	&"q_bard":
	{
		"title": "A Verse for the Fallen",
		"giver": &"npc_ilsa",
		"level": 4,
		"prereq": &"q_risen",
		"offer":
		"Somebody has to write down who they were, or in thirty years the houses will each claim the dead agreed with them. Sit. Tell me the names.",
		"progress": "Speak with Ilsa the Skald.",
		"completion":
		"Histories decide claims, and claims decide thrones. That is why a bard is worth a company of spears, and why I sleep with the door barred.",
		"objectives": [{"type": "talk", "target": "npc_ilsa", "count": 1, "text": "Speak with Ilsa the Skald"}],
		"xp": 140,
		"currency": 8
	},
	&"q_stag":
	{
		"title": "Outriders on the Road",
		"giver": &"npc_halvard",
		"level": 4,
		"prereq": &"q_bard",
		"offer":
		"The White Stag has outriders on our road, counting our carts and calling it a courtesy. Send them home.",
		"progress": "Drive off the Stag outriders.",
		"completion": "They'll be back with three times the number. But not this week.",
		"objectives": [{"type": "kill_tag", "target": "stag", "count": 8, "text": "Stag Outriders driven off"}],
		"xp": 175,
		"currency": 14
	},
	&"q_sunburst":
	{
		"title": "Blue and Gold",
		"giver": &"npc_halvard",
		"level": 5,
		"prereq": &"q_stag",
		"offer":
		"Now the Sunburst has serjeants in the fields, doing the same counting, and swearing it's for our protection. Same answer.",
		"progress": "Drive off the Sunburst serjeants.",
		"completion":
		"Two houses, one road, and not one of them has asked the valley what it wants. That's the whole war in a sentence.",
		"objectives": [{"type": "kill_tag", "target": "sunburst", "count": 8, "text": "Sunburst Serjeants driven off"}],
		"xp": 200,
		"currency": 16,
		"items": {"gear_levy_trinket": 1}
	},
	&"q_reach_barrow":
	{
		"title": "The Long Barrow",
		"giver": &"npc_ilsa",
		"level": 6,
		"prereq": &"q_sunburst",
		"offer":
		"The old kings are buried up the vale, and something up there is answering when the Grave-Binders call. Go and look. Don't go in.",
		"progress": "Travel to the barrow approach.",
		"completion": "You felt it too, then. Good. I'd have worried about you if you hadn't.",
		"objectives": [{"type": "reach", "target": "barrow_approach", "count": 1, "text": "Reach the barrow approach"}],
		"xp": 185,
		"currency": 12
	},
	&"q_gravebinders":
	{
		"title": "Who Binds the Binders",
		"giver": &"npc_ilsa",
		"level": 6,
		"prereq": &"q_reach_barrow",
		"offer":
		"Someone is paying the Grave-Binders, and they are not doing this for the love of the craft. Stop them and search them.",
		"progress": "Kill the Grave-Binders working the barrow slopes.",
		"completion":
		"House seals, both houses, in the same purse. They are each paying the same necromancers to raise the same dead. Of course they are.",
		"objectives": [{"type": "kill", "target": "grave_binder", "count": 5, "text": "Grave-Binders stopped"}],
		"xp": 250,
		"currency": 22
	},
	&"q_wights":
	{
		"title": "Restless Guard",
		"giver": &"npc_ilsa",
		"level": 7,
		"prereq": &"q_gravebinders",
		"offer": "The barrow's own guard is awake now, and it does not care which house you serve. Clear the approach.",
		"progress": "Destroy the Barrow Wights.",
		"completion": "The door is clear. What's behind it is a different problem.",
		"objectives": [{"type": "kill", "target": "barrow_wight", "count": 6, "text": "Barrow Wights destroyed"}],
		"xp": 310,
		"currency": 28,
		"items": {"gear_levy_ring": 1}
	},
	&"q_first_king":
	{
		"title": "The Deepbarrow",
		"giver": &"npc_halvard",
		"level": 8,
		"prereq": &"q_wights",
		"offer":
		"Whatever the Binders woke down there is wearing a crown, and every house in the realm will claim it the moment they hear. Get there first. Take friends.",
		"progress": "Defeat Captain Reyne and the First King inside the barrow.",
		"completion":
		"A dead king with no heir started this. Now we have two of them. I'd laugh if I had it in me.",
		"objectives":
		[
			{"type": "kill", "target": "captain_reyne", "count": 1, "text": "Captain Reyne defeated"},
			{"type": "kill", "target": "the_first_king", "count": 1, "text": "The First King defeated"}
		],
		"xp": 650,
		"currency": 120
	},
	# --- Greymarch, levels 8-14 ----------------------------------------------
	# The borderland both houses burnt. Neither army will move first, so the
	# dead of last year's fighting are still lying where they fell, and lately
	# they have stopped lying still.
	&"sm_arrival":
	{
		"title": "Carry the News",
		"giver": &"npc_wrenn",
		"level": 8,
		"prereq": &"q_first_king",
		"offer":
		"You came up the barrow road, so you have seen it. Sit down before you tell me. Whatever it is, it will still be true in a minute.",
		"progress": "Speak with Sister Wrenn.",
		"completion":
		"A second crown. Wonderful. There are two armies in this field who would each kill everyone in the other for the first one.",
		"objectives": [{"type": "talk", "target": "npc_wrenn", "count": 1, "text": "Tell Sister Wrenn what you found"}],
		"xp": 220,
		"currency": 14
	},
	&"sm_wounded":
	{
		"title": "Both Sides of the Line",
		"giver": &"npc_wrenn",
		"level": 8,
		"prereq": &"sm_arrival",
		"offer":
		"I treat whoever is bleeding. Both houses let me, because both houses expect to need me. Fetch what is left in the ruined steadings — bandages, spirit, anything.",
		"progress": "Recover supplies from the burnt steadings.",
		"completion":
		"Thank you. Half of this goes to the Stag and half to the Sunburst, and neither will thank me, and I will do it again next week.",
		"objectives": [{"type": "collect", "target": "chicken_leg", "count": 5, "text": "Supplies recovered"}],
		"xp": 260,
		"currency": 18
	},
	&"sm_pickets":
	{
		"title": "Nobody Fires First",
		"giver": &"npc_aske",
		"level": 9,
		"prereq": &"sm_wounded",
		"offer":
		"My orders are to hold this line and not to advance. Their orders are the same. So we sit, and we shoot anyone who walks between us, and you have been walking between us all morning.",
		"progress": "Deal with the pickets on both lines.",
		"completion":
		"You will notice I did not ask which side you thinned. That is the only way I can live with the answer.",
		"objectives": [{"type": "kill_tag", "target": "picket", "count": 10, "text": "Pickets driven off"}],
		"xp": 320,
		"currency": 22,
		"items": {"gear_marcher_cloak": 1}
	},
	&"sm_drowned":
	{
		"title": "The River Gives Them Back",
		"giver": &"npc_ferryman",
		"level": 10,
		"prereq": &"sm_pickets",
		"offer":
		"They dammed the river to flood the other one out. Both of them did, at different ends. Now the water sits on the field and everything in it comes up eventually.",
		"progress": "Put down the drowned dead in the flood.",
		"completion": "They are quieter for a while after. Not long. A while.",
		"objectives": [{"type": "kill", "target": "drowned_levy", "count": 8, "text": "Drowned dead put down"}],
		"xp": 400,
		"currency": 28
	},
	&"sm_seals":
	{
		"title": "Whose Hand",
		"giver": &"npc_ilsa",
		"level": 11,
		"prereq": &"sm_drowned",
		"offer":
		"I followed you up the road because somebody has to write this down correctly. Bring me what the Binders here are carrying, the way you did in the vale.",
		"progress": "Take the seals from the Field-Binders.",
		"completion":
		"Same two seals. Same purse. Whoever is paying them is paying them from both houses' coin, which means it is neither house paying. It means somebody is spending their money for them.",
		"objectives": [{"type": "kill", "target": "field_binder", "count": 6, "text": "Field-Binders stopped"}],
		"xp": 460,
		"currency": 34,
		"items": {"seal_of_two_houses": 1}
	},
	&"sm_colm":
	{
		"title": "The Serjeant-Major's Arithmetic",
		"giver": &"npc_colm",
		"level": 11,
		"prereq": &"sm_seals",
		"offer":
		"I have buried four hundred and eleven men in this field. I know because I dug most of the holes. Now some of them are out walking and I want to know how many, so go and count.",
		"progress": "Clear the march wights from the old burial ground.",
		"completion":
		"More than I put in. That is the part I want you to think about on your way back.",
		"objectives": [{"type": "kill", "target": "march_wight", "count": 7, "text": "March wights cleared"}],
		"xp": 540,
		"currency": 40,
		"items": {"gear_marcher_trinket": 1}
	},
	&"sm_reach_redoubt":
	{
		"title": "The Water Fort",
		"giver": &"npc_colm",
		"level": 12,
		"prereq": &"sm_colm",
		"offer":
		"There is a fort out in the flood that we took nine times and they took nine times. Nobody holds it now. Go and look at it, and do not go inside.",
		"progress": "Reach the approach to the Drowned Hold.",
		"completion": "You felt it. Everyone does. That is why nobody garrisons it any more.",
		"objectives": [{"type": "reach", "target": "redoubt_approach", "count": 1, "text": "Reach the Hold approach"}],
		"xp": 500,
		"currency": 30
	},
	&"sm_both_houses":
	{
		"title": "A Truce of Sorts",
		"giver": &"npc_aske",
		"level": 12,
		"prereq": &"sm_reach_redoubt",
		"offer":
		"Colm and I have spoken. Do not tell anyone; we would both hang. Whatever is in that fort is walking out of it at night and it does not check colours before it kills.",
		"progress": "Thin both houses' dead around the Hold.",
		"completion":
		"Two officers of two houses agreeing about something. If the histories record one honest thing about this war, let it be that.",
		"objectives": [{"type": "kill_tag", "target": "drowned", "count": 12, "text": "Drowned dead thinned"}],
		"xp": 620,
		"currency": 46,
		"items": {"gear_marcher_ring": 1}
	},
	&"sm_ferry":
	{
		"title": "The Crossing",
		"giver": &"npc_ferryman",
		"level": 13,
		"prereq": &"sm_both_houses",
		"offer":
		"You want into the fort, you go by water, and my boat does not go while that is standing in the shallows. Clear the crossing and I will take you.",
		"progress": "Clear the crossing for the ferryman.",
		"completion": "Get in. Do not trail your hand in the water. I should not have to say it.",
		"objectives": [{"type": "kill", "target": "flood_warden", "count": 4, "text": "Flood wardens cleared"}],
		"xp": 700,
		"currency": 52,
		"items": {"ferrymans_coin": 1}
	},
	&"sm_redoubt":
	{
		"title": "The Drowned Hold",
		"giver": &"npc_wrenn",
		"level": 14,
		"prereq": &"sm_ferry",
		"offer":
		"Two captains died in that fort with their hands on each other. They are both still in there, and they are both still doing it. Take people with you. I will be here when you come back, and I will be busy.",
		"progress": "Break the Hold: the two captains, and whatever the water made.",
		"completion":
		"You look like everyone who comes back from there. Sit. The capital can wait an hour, and when you get there, it will not have waited at all.",
		"objectives":
		[
			{"type": "kill_tag", "target": "redoubt_captain", "count": 2, "text": "The drowned captains defeated"},
			{"type": "kill", "target": "the_weight_of_them", "count": 1, "text": "The Weight of Them destroyed"}
		],
		"xp": 1500,
		"currency": 180,
		"items": {"mount_marcher_bear": 1}
	},
	# --- Ironhold (14-20) ------------------------------------------------------
	# Short and functional on purpose: the players have said they do not read
	# quest text. Each line tells you where to go and what to hit.
	&"km_arrival":
	{
		"title": "The Capital",
		"giver": &"npc_orrin",
		"level": 14,
		"prereq": &"sm_redoubt",
		"offer": "You're from the Marches. Good. The city needs hands that have already seen the dead walk.",
		"progress": "Report to Castellan Orrin at the Irongate.",
		"completion": "Welcome to Ironhold. Nobody's buried the king and everybody's armed. Start in the market.",
		"objectives": [{"type": "talk", "target": "npc_orrin", "count": 1, "text": "Report to Castellan Orrin"}],
		"xp": 500,
		"currency": 40
	},
	&"km_streets":
	{
		"title": "Keep the Peace",
		"giver": &"npc_orrin",
		"level": 14,
		"prereq": &"km_arrival",
		"offer": "Agitators are working the market crowd for both houses. Clear them out before it becomes a riot.",
		"progress": "Drive the agitators out of the market ward.",
		"completion": "That buys a quiet night. One.",
		"objectives": [{"type": "kill_tag", "target": "agitator", "count": 8, "text": "Agitators driven off"}],
		"xp": 900,
		"currency": 45
	},
	&"km_retainers":
	{
		"title": "Colours in the Street",
		"giver": &"npc_orrin",
		"level": 14,
		"prereq": &"km_streets",
		"offer": "Stag and Sunburst retainers are brawling in the guild quarter. I don't care which side started it.",
		"progress": "Break up the retainers in the guild quarter.",
		"completion": "Both envoys will complain to me. Let them.",
		"objectives": [{"type": "kill_tag", "target": "retainer", "count": 10, "text": "House retainers subdued"}],
		"xp": 1000,
		"currency": 50
	},
	&"km_ilsa":
	{
		"title": "The Records Quarter",
		"giver": &"npc_ilsa",
		"level": 15,
		"prereq": &"km_retainers",
		"offer": "The histories are in the Archive, and the Archive is shut. Walk me to the quarter and we'll see who shut it.",
		"progress": "Reach the Records Quarter.",
		"completion": "Locked, and guarded by both houses. That's an answer of a kind.",
		"objectives": [{"type": "reach", "target": "records_quarter", "count": 1, "text": "Reach the Records Quarter"}],
		"xp": 800,
		"currency": 40
	},
	&"km_crypt":
	{
		"title": "Under the City",
		"giver": &"npc_orrin",
		"level": 15,
		"prereq": &"km_ilsa",
		"offer": "The royal crypt is under the palace ward, and things are coming up the stairs. Put them back down.",
		"progress": "Destroy the risen in the royal crypt.",
		"completion": "Same as the barrow. Somebody is doing this on purpose.",
		"objectives": [{"type": "kill", "target": "crypt_risen", "count": 8, "text": "Crypt risen destroyed"}],
		"xp": 1200,
		"currency": 60
	},
	&"km_binders":
	{
		"title": "Whose Hand, Again",
		"giver": &"npc_ilsa",
		"level": 16,
		"prereq": &"km_crypt",
		"offer": "Crown-Binders in the crypt. Same craft as the Grave-Binders in the Vale, better robes. Stop them and bring me anything they're carrying.",
		"progress": "Kill the Crown-Binders in the royal crypt.",
		"completion": "Palace seals. They were let in. Now I want to know by whom.",
		"objectives": [{"type": "kill", "target": "crown_binder", "count": 6, "text": "Crown-Binders stopped"}],
		"xp": 1300,
		"currency": 65,
		"items": {"kings_signet": 1}
	},
	&"km_envoys":
	{
		"title": "Two Envoys",
		"giver": &"npc_orrin",
		"level": 16,
		"prereq": &"km_binders",
		"offer": "Both envoys want to see whoever cleared the crypt. Hear them out. Believe neither.",
		"progress": "Speak with Envoy Tarrant and Envoy Vell.",
		"completion": "Each says the other let the binders in. One of them is lying and I'd wager on both.",
		"objectives":
		[
			{"type": "talk", "target": "npc_tarrant", "count": 1, "text": "Speak with Envoy Tarrant of the Stag"},
			{"type": "talk", "target": "npc_vell", "count": 1, "text": "Speak with Envoy Vell of the Sunburst"}
		],
		"xp": 900,
		"currency": 45
	},
	&"km_heralds":
	{
		"title": "The Older Crown",
		"giver": &"npc_orrin",
		"level": 17,
		"prereq": &"km_envoys",
		"offer": "Armoured dead are walking the outer wards, carrying a banner nobody alive has flown. Heralds. Kill them.",
		"progress": "Kill the First King's heralds in the outer wards.",
		"completion": "The barrow was never the end of it. He's coming here.",
		"objectives": [{"type": "kill", "target": "first_king_herald", "count": 4, "text": "Heralds destroyed"}],
		"xp": 1500,
		"currency": 75
	},
	&"km_records_gate":
	{
		"title": "The Archive Is Open",
		"giver": &"npc_ilsa",
		"level": 17,
		"prereq": &"km_heralds",
		"offer": "The guards on the Archive are gone — inside, I'd guess. Get to the doors. Archivist Pell will be there if he's alive.",
		"progress": "Reach the Archive.",
		"completion": "He's alive. He's also the only one who knows what's in there.",
		"objectives": [{"type": "reach", "target": "hall_of_records_gate", "count": 1, "text": "Reach the Archive"}],
		"xp": 1000,
		"currency": 50
	},
	&"km_hall":
	{
		"title": "The Archive",
		"giver": &"npc_pell",
		"level": 18,
		"prereq": &"km_records_gate",
		"offer": "Both houses are inside forging and burning, and Master Kell is letting them. Kell has the claim. Take a party. Stop him, and stop the thing he's bound the ledgers into.",
		"progress": "Clear the Archive: Master Kell, then the Bound Ledger.",
		"completion": "The claim is real and it names nobody living. He went to the throne room. So will everyone else.",
		"objectives":
		[
			{"type": "kill", "target": "master_kell", "count": 1, "text": "Master Kell defeated"},
			{"type": "kill", "target": "the_bound_ledger", "count": 1, "text": "The Bound Ledger destroyed"}
		],
		"xp": 2600,
		"currency": 220
	},
	&"km_palace":
	{
		"title": "The Palace Ward",
		"giver": &"npc_orrin",
		"level": 18,
		"prereq": &"km_hall",
		"offer": "Both houses have moved their guards into the palace ward. Nobody's asked me. Clear a path to the throne room.",
		"progress": "Clear the claimants' guards from the palace ward.",
		"completion": "Path's open. What's on the other end of it isn't either house.",
		"objectives": [{"type": "kill_tag", "target": "claimant_guard", "count": 12, "text": "Claimants' guards cleared"}],
		"xp": 1800,
		"currency": 90
	},
	&"km_throne":
	{
		"title": "The Broken Throne",
		"giver": &"npc_orrin",
		"level": 19,
		"prereq": &"km_palace",
		"offer": "Both claimants are in the throne room and the First King is walking in behind you wearing the older crown. Take everyone.",
		"progress": "Clear the throne room: Lord Ashcombe, Lady Severin, and the First King.",
		"completion": "The king's buried. The claim's settled — by nobody. That'll have to do.",
		"objectives":
		[
			{"type": "kill_tag", "target": "claimant", "count": 2, "text": "The claimants defeated"},
			{"type": "kill", "target": "first_king_crowned", "count": 1, "text": "The First King, Crowned — destroyed"}
		],
		"xp": 3000,
		"currency": 400,
		"items": {"mount_tombthrone": 1}
	}
}

var _cache: Dictionary = {}


func _ready() -> void:
	for quest_id in DEFINITIONS:
		_cache[quest_id] = _build(quest_id, DEFINITIONS[quest_id])


func get_quest(quest_id: StringName) -> QuestData:
	if _cache.is_empty():
		_ready()
	return _cache.get(quest_id, null)


func get_all_ids() -> Array:
	return DEFINITIONS.keys()


## Every quest a given NPC hands out, in chain order.
func quests_offered_by(npc_id: StringName) -> Array:
	var offered: Array = []
	for quest_id in DEFINITIONS:
		if StringName(str(DEFINITIONS[quest_id].get("giver", &""))) == npc_id:
			offered.append(quest_id)
	return offered


func _build(quest_id: StringName, entry: Dictionary) -> QuestData:
	var quest := QuestData.new()
	quest.id = quest_id
	quest.title = str(entry.get("title", ""))
	quest.giver_id = StringName(str(entry.get("giver", &"")))
	quest.turn_in_id = StringName(str(entry.get("turn_in", entry.get("giver", &""))))
	quest.offer_text = str(entry.get("offer", ""))
	quest.progress_text = str(entry.get("progress", ""))
	quest.completion_text = str(entry.get("completion", ""))
	quest.objectives = entry.get("objectives", [])
	quest.required_level = int(entry.get("level", 1))
	quest.prerequisite = StringName(str(entry.get("prereq", &"")))
	quest.experience_reward = int(entry.get("xp", 0))
	quest.currency_reward = int(entry.get("currency", 0))
	quest.item_rewards = entry.get("items", {})
	return quest
