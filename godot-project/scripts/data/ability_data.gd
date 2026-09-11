# AbilityData — one ability, as data.
#
# Effects are generic verbs so that a new ability is an entry in
# AbilityDatabase, not new code. The design doc's rune system depends on this:
# about half the rune choices are meant to MODIFY an existing ability rather
# than add one, and that is only cheap if abilities are values you can tweak.
class_name AbilityData
extends Resource

enum Effect {
	DAMAGE,       ## Straight damage to one enemy.
	AOE_DAMAGE,   ## Damage to everything hostile within aoe_radius of the target.
	HEAL,         ## Restore health to one friendly target (or yourself).
	AOE_HEAL,     ## Restore health to everyone friendly nearby.
	DOT,          ## Damage repeated over duration_seconds.
	DRAIN,        ## Damage that heals the caster for a share of it.
	TAUNT,        ## Force the target to attack the caster.
	SUMMON,       ## Spawn a pet that fights for the caster.
	SPEED         ## Temporary movement speed change (negative slows the target).
}

enum TargetRule {
	ENEMY,  ## Needs a hostile target.
	SELF,   ## Always the caster.
	ALLY,   ## A friendly target, falling back to the caster.
	GROUND  ## Centred on the caster, no target needed.
}

@export var id: StringName = &""
@export var display_name: String = ""

## Which class it belongs to: valkyr, bard, necromancer, tinker.
@export var class_id: StringName = &""

## Position on the action bar, 1-7.
@export_range(1, 7) var slot: int = 1

@export var effect: Effect = Effect.DAMAGE
@export var target_rule: TargetRule = TargetRule.ENEMY

## Damage, healing, or per-tick amount for a DOT.
@export var power: int = 10

## Resource cost. Valkyr abilities spend Valor, which is built by fighting.
@export var cost: int = 10

## Spends everything you have and scales with it. Used by the class finishers.
@export var spends_all_resource: bool = false

@export var cooldown: float = 0.0
@export var cast_range: float = 6.0
@export var aoe_radius: float = 0.0
@export var duration_seconds: float = 0.0
@export var tick_seconds: float = 1.0

## For DRAIN: the share of damage returned to the caster as health.
@export var drain_ratio: float = 0.5

## For SUMMON: which MobDatabase entry to raise.
@export var summon_mob_id: StringName = &""
@export var summon_seconds: float = 30.0

## For SPEED: multiplier applied for duration_seconds. Below 1.0 is a slow.
@export var speed_multiplier: float = 1.0

@export var level_required: int = 1

@export_multiline var description: String = ""


## Generating rather than spending: Valkyr builds Valor by fighting.
func generates_resource() -> bool:
	return cost < 0
