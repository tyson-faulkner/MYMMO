# QuestDatabase — every quest in the game, as data.
#
# The chain below walks a player from the gates of Thornhollow Vale out to the
# Barrow of the First King, which is roughly levels 1 to 12. Adding a quest is
# adding an entry: no code, no scene work.
#
# The setting, per docs/kingsmourn-design.md: the king is dead with no heir and
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
		"xp": 60,
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
		"xp": 120,
		"currency": 4
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
		"xp": 180,
		"currency": 6
	},
	&"q_supplies":
	{
		"title": "Stolen Stores",
		"giver": &"npc_maren",
		"level": 3,
		"prereq": &"q_bandits",
		"offer": "They took the winter stores. Bring back what you can find in their camps — anything at all.",
		"progress": "Recover stolen provisions.",
		"completion": "It's not much. It's more than we had this morning. Thank you.",
		"objectives": [{"type": "collect", "target": "chicken_leg", "count": 4, "text": "Provisions recovered"}],
		"xp": 200,
		"currency": 8
	},
	&"q_risen":
	{
		"title": "The War Won't Stay Buried",
		"giver": &"npc_halvard",
		"level": 4,
		"prereq": &"q_supplies",
		"offer":
		"The dead levies are walking again. Somebody is doing that to them on purpose, and when I find out who, I'll want a word.",
		"progress": "Put the risen levies back down.",
		"completion": "They were ours. Every one of them wore our colours. Remember that when someone tells you this war was clean.",
		"objectives": [{"type": "kill", "target": "risen_levy", "count": 6, "text": "Risen Levies put down"}],
		"xp": 260,
		"currency": 10
	},
	&"q_bard":
	{
		"title": "A Verse for the Fallen",
		"giver": &"npc_ilsa",
		"level": 5,
		"prereq": &"q_risen",
		"offer":
		"Somebody has to write down who they were, or in thirty years the houses will each claim the dead agreed with them. Sit. Tell me the names.",
		"progress": "Speak with Ilsa the Skald.",
		"completion":
		"Histories decide claims, and claims decide thrones. That is why a bard is worth a company of spears, and why I sleep with the door barred.",
		"objectives": [{"type": "talk", "target": "npc_ilsa", "count": 1, "text": "Speak with Ilsa the Skald"}],
		"xp": 280,
		"currency": 8
	},
	&"q_stag":
	{
		"title": "Outriders on the Road",
		"giver": &"npc_halvard",
		"level": 6,
		"prereq": &"q_bard",
		"offer":
		"The White Stag has outriders on our road, counting our carts and calling it a courtesy. Send them home.",
		"progress": "Drive off the Stag outriders.",
		"completion": "They'll be back with three times the number. But not this week.",
		"objectives": [{"type": "kill_tag", "target": "stag", "count": 8, "text": "Stag Outriders driven off"}],
		"xp": 360,
		"currency": 14
	},
	&"q_sunburst":
	{
		"title": "Blue and Gold",
		"giver": &"npc_halvard",
		"level": 7,
		"prereq": &"q_stag",
		"offer":
		"Now the Sunburst has serjeants in the fields, doing the same counting, and swearing it's for our protection. Same answer.",
		"progress": "Drive off the Sunburst serjeants.",
		"completion":
		"Two houses, one road, and not one of them has asked the valley what it wants. That's the whole war in a sentence.",
		"objectives": [{"type": "kill_tag", "target": "sunburst", "count": 8, "text": "Sunburst Serjeants driven off"}],
		"xp": 420,
		"currency": 16
	},
	&"q_reach_barrow":
	{
		"title": "The Long Barrow",
		"giver": &"npc_ilsa",
		"level": 8,
		"prereq": &"q_sunburst",
		"offer":
		"The old kings are buried up the vale, and something up there is answering when the Grave-Binders call. Go and look. Don't go in.",
		"progress": "Travel to the barrow approach.",
		"completion": "You felt it too, then. Good. I'd have worried about you if you hadn't.",
		"objectives": [{"type": "reach", "target": "barrow_approach", "count": 1, "text": "Reach the barrow approach"}],
		"xp": 380,
		"currency": 12
	},
	&"q_gravebinders":
	{
		"title": "Who Binds the Binders",
		"giver": &"npc_ilsa",
		"level": 9,
		"prereq": &"q_reach_barrow",
		"offer":
		"Someone is paying the Grave-Binders, and they are not doing this for the love of the craft. Stop them and search them.",
		"progress": "Kill the Grave-Binders working the barrow slopes.",
		"completion":
		"House seals, both houses, in the same purse. They are each paying the same necromancers to raise the same dead. Of course they are.",
		"objectives": [{"type": "kill", "target": "grave_binder", "count": 5, "text": "Grave-Binders stopped"}],
		"xp": 520,
		"currency": 22
	},
	&"q_wights":
	{
		"title": "Restless Guard",
		"giver": &"npc_ilsa",
		"level": 10,
		"prereq": &"q_gravebinders",
		"offer": "The barrow's own guard is awake now, and it does not care which house you serve. Clear the approach.",
		"progress": "Destroy the Barrow Wights.",
		"completion": "The door is clear. What's behind it is a different problem.",
		"objectives": [{"type": "kill", "target": "barrow_wight", "count": 6, "text": "Barrow Wights destroyed"}],
		"xp": 640,
		"currency": 28
	},
	&"q_first_king":
	{
		"title": "The Barrow of the First King",
		"giver": &"npc_halvard",
		"level": 11,
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
		"xp": 1400,
		"currency": 120
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
