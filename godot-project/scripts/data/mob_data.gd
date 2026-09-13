# MobData — the definition of one kind of enemy.
#
# Ironveil's enemies are people, not demons, so nearly every one of them
# shares a single humanoid body. That is a production decision as much as a
# creative one: one skeleton, one animation set, and a new enemy costs a data
# file instead of an art budget. Adding the fortieth mob type should be filling
# in this form, never writing code.
class_name MobData
extends Resource

@export var id: StringName = &""
@export var display_name: String = "Enemy"
@export var level: int = 1
@export var max_health: int = 60

## Damage per swing before the target's armour.
@export var damage: int = 8
@export var attack_cooldown: float = 1.8

## How close it has to be to swing.
@export var attack_range: float = 2.2
@export var move_speed: float = 3.2

## How far away it notices you.
@export var aggro_radius: float = 9.0

## How far it will chase from its spawn before giving up and walking home.
## Without a leash, one player can drag the whole zone into town.
@export var leash_radius: float = 22.0
@export var respawn_seconds: float = 25.0

## XP awarded to the killer. Scaled by level difference at award time.
@export var experience_reward: int = 25

## Quest objectives match on this id, so several mob types can count toward the
## same "kill 8 bandits" objective by sharing a tag.
@export var tags: Array[StringName] = []

## Body tint for the placeholder humanoid. Real art swaps into the same scene
## slot later with no code change.
@export var placeholder_color: Color = Color(0.5, 0.45, 0.4)

## Roughly how tall, in metres. Gives silhouette variety before real art.
@export var scale_multiplier: float = 1.0

## The rigged .glb this enemy wears, or "" to stay a tinted placeholder. Every
## human is the shared body re-textured; the wolf is its own quadruped.
@export var model_path: String = ""

## Cast abilities, each a dictionary the Mob reads at runtime:
##   name          shown on the cast bar
##   cast          seconds of wind-up (the bar)
##   every         seconds between casts
##   power         damage (or healing) when it lands
##   effect        "damage" (default) or "heal" (heals the caster)
##   target        "current" (default), "random", "furthest"
##   range         how far the target may be, default 20
##   interruptible true by default; false is a boss's unstoppable cast
##   first         seconds before the first cast, default half of `every`
## Bosses get more of these from the mechanics engine; ordinary casters get one.
@export var casts: Array = []

## Boss mechanics, each a dictionary BossMechanics reads (see that script's
## header for the fields). Empty for everything that isn't a boss.
@export var mechanics: Array = []

## A friendly summon that heals instead of fighting: every attack_cooldown it
## mends the lowest-health player within aggro_radius by this much.
@export var heal_power: int = 0

## A tag this enemy fights when no player is close enough to matter: the
## Records packs (Stag vs Sunburst) and the two claimants. Empty means it only
## ever fights players.
@export var feud: StringName = &""

## Item ids that can drop, each with a 0..1 chance.
@export var loot_table: Dictionary = {}

## Shared currency (Sovereigns) dropped on death.
@export var currency_reward: int = 0

## True for anything that lives INSIDE a dungeon or raid — trash and bosses
## alike. This is what the slot-ownership test keys on: dungeon enemies may
## never drop rings, trinkets or cloaks. It is explicit rather than inferred
## from tags, because a barrow wight patrolling the surface carries the barrow
## tag and is still a world enemy.
@export var is_dungeon: bool = false

## True for dungeon and raid bosses. Bosses scale with how many players are in
## the instance — one system, written once (see the design doc).
@export var is_boss: bool = false
