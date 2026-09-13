# RuneData — one of the two choices in one armour slot.
#
# Straight from the design doc: three armour slots, each granting a choice
# between two options, giving eight builds per class. Two rules govern every
# rune here, and breaking either makes the system pointless:
#
#   1. The two options in a slot must differ by SITUATION, not by power. If one
#      is "+12% damage" and the other is "+15% damage", the choice is fake and
#      everybody picks the same one. One should be better on a single target;
#      the other better on several, or over time, or for the group.
#
#   2. About half should MODIFY an existing ability rather than add a new one.
#      "Your Soulbolt forks to a second target" costs a number. A whole new
#      ability costs animation, art, an icon and effects.
#
# Every rune in RuneDatabase modifies an ability. None adds one. That is
# deliberate for the first pass: it means the whole build system costs no art.
class_name RuneData
extends Resource

enum Effect {
	POWER,        ## Multiply the ability's power.
	COOLDOWN,     ## Multiply its cooldown (below 1.0 is faster).
	COST,         ## Multiply its resource cost.
	DURATION,     ## Multiply its duration, for damage-over-time and buffs.
	EXTRA_TARGETS,## Chain to this many additional enemies, at reduced power.
	MAKE_AOE,     ## Turn a single-target ability into one with a radius.
	FOCUS,        ## Turn an area ability into a harder single-target one.
	EXTRA_SUMMON, ## Summon this many more, each weaker.
	SPLASH_HEAL,  ## Heal also reaches nearby allies, at reduced power.
	GRANT         ## A new move: puts `ability_id` on the bar while the rune is worn.
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var class_id: StringName = &""

## Which armour slot, 1 to 3. Each slot offers exactly two runes.
@export_range(1, 3) var slot: int = 1

## Which ability this rune changes.
@export var ability_id: StringName = &""

@export var effect: Effect = Effect.POWER

## What the effect is worth. A multiplier for POWER/COOLDOWN/COST/DURATION, a
## count for EXTRA_TARGETS/EXTRA_SUMMON, a radius for MAKE_AOE.
@export var value: float = 1.0

## Secondary knob: the share of power that reaches chained targets, splashed
## allies, or extra summons.
@export var falloff: float = 0.5

## Extra radius added on top of whatever the ability already had. Used by runes
## that widen a blast rather than changing what it does.
@export var aoe_bonus: float = 0.0

@export_multiline var description: String = ""
