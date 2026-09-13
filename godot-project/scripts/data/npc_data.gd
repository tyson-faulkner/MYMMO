# NpcData — the definition of one person you can talk to.
#
# NPCs used to live entirely in scene files: a name and a greeting typed into
# thornhollow_vale.tscn, and an id that nothing checked. That meant a quest
# could be handed out by somebody who did not exist anywhere in the world, and
# no test would catch it — you would only find out when a player walked to an
# empty patch of grass looking for a quest giver.
#
# Now they work like enemies and quests: defined as data, placed by id. A scene
# says "an NPC, here, called npc_halvard" and everything else comes from
# NpcDatabase.
class_name NpcData
extends Resource

@export var id: StringName = &""
@export var display_name: String = "Villager"

## Shown under the name: "Gate Serjeant", "Skald", "Field Surgeon".
@export var title: String = ""

@export_multiline var greeting: String = "Well met."

## Tint for the placeholder body until real character art replaces it.
@export var body_color: Color = Color(0.72, 0.66, 0.55)

## Which zone they stand in. Ilsa appears in two, so this is a list.
@export var zones: Array[StringName] = []

## Item ids this NPC sells for Sovereigns. Empty means they are not a vendor.
@export var stock: Array[StringName] = []
