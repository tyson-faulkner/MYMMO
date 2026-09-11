# ClassData — the definition of one playable class.
#
# Kingsmourn has exactly four: Valkyr (tank), Bard (healer), Necromancer and
# Tinker (ranged damage). There are no playable races — your class and your
# gear are your whole identity, which also means one body, one skeleton and one
# animation set for the entire game.
#
# This is a Resource, which in Godot means "a data file you can edit without
# touching code". Every class lives in resources/classes/*.tres, so retuning a
# class is editing a file, not programming.
class_name ClassData
extends Resource

## Shown in menus and on the character frame.
@export var display_name: String = ""

## Machine id, lowercase, used as a dictionary key everywhere.
@export var id: StringName = &""

## "Tank", "Healer / Support" or "Ranged Damage".
@export var role: String = ""

## What this class's resource bar is called. Free flavour at zero code cost:
## Bard spends Verse, Tinker spends Charge, Necromancer spends Soul.
@export var resource_label: String = "Mana"

@export var max_resource: int = 100

## Valkyr is the exception to the rule. Tanks want a resource that BUILDS as
## the fight goes on rather than draining away, so when this is true the bar
## starts empty and fills when you deal or take damage.
@export var resource_builds_in_combat: bool = false

## Passive regeneration per second while out of combat (ignored when the
## resource builds in combat instead).
@export var resource_regen_per_second: float = 5.0

@export var base_health: int = 100

## Health gained per level. Tanks gain the most.
@export var health_per_level: int = 12

@export var base_armor: int = 0

## Placeholder body tint until real class art exists. Taken from the approved
## reference pack in docs/reference/.
@export var placeholder_color: Color = Color.WHITE

## Flavour line for the class-select screen.
@export var description: String = ""
