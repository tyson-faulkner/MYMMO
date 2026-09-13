# Ironveil — Classes, Specs and Runes

Proposal, 2026-09-11. Builds on what is already in the game: four classes,
seven abilities each (28 in `AbilityDatabase`), three rune slots with two
choices each (24 in `RuneDatabase`).

## The problem specs solve

Four classes, one role each: Valkyr tanks, Bard heals, Necromancer and Tinker
do damage. With five to ten friends that has a failure mode you will hit on
night one: **two people pick Valkyr and one of them has to reroll**, or nobody
picks Bard and there is no healer. In WoW that's fine — there are always more
people. Here there aren't.

**Two specs per class fixes it.** Every class keeps its identity and gains a
second role. Result: two ways to tank, two ways to heal, four ways to do
damage. Any five friends can form a party no matter what they picked.

It also answers "what do I do at 17-20?" — the last new ability currently
unlocks at 16. Spec abilities fill that gap.

## The eight specs

A spec is: **a passive** that sets the role, **two or three spec abilities**,
and **a capstone** at 20. The other five abilities are shared, so switching
spec never means relearning the class. You pick a spec at level 10; its
abilities carry their own levels and anything you're already past unlocks on
the spot, so a healer's HoT can sit at level 4 without the spec having to.

| Class | Spec | Role | The idea |
|---|---|---|---|
| **Valkyr** | **Bulwark** | Tank | Wings as a wall. Absorbs, taunts, holds the line. |
| | **Lance** | Melee damage | Descend from height and hit one thing very hard. |
| **Bard** | **Hymn** | Healer | Verses that mend. What Bard is today. |
| | **Dirge** | Ranged damage | Songs that cut. The mockery-and-curses bard. |
| **Necromancer** | **Grave** | Ranged damage | Rot, bolts, raised levies. What Necromancer is today. |
| | **Pact** | Tank | Trades health for armour of bone; drains to stay standing. The tank that heals itself. |
| **Tinker** | **Artillery** | Ranged damage | Turrets, bombs, oil. What Tinker is today. |
| | **Medic** | Healer | Field repair on people. A turret that heals. Tonics. |

### Valkyr

*Shared:* Mourning Strike, Sweeping Spear, **Wingguard**, Descend, Judgment of
the Slain.

**Two defensives, decided 2026-09-11.** A tank needs a cheap one for every
pull and a big one for the moment it goes wrong:

- **Wingguard** (L6, shared, reworked): 30% less damage taken for 6s, 15s
  cooldown, costs Valor. Was a self-heal; now the every-pull button.
- **Unbroken Wing** (L12, Bulwark, new): 60% less damage taken for 10s,
  2-minute cooldown. Takes Rally the Fallen's old slot.
- **Rally the Fallen** (party heal) moves to the slot-2 rune as the new-move
  option, so either spec can take it for a healer-less night.

**Bulwark** — passive: +25% armour, threat doubled.
- L2 **Claim the Slain** (existing taunt, becomes spec-only).
- L12 **Unbroken Wing** (the 2-minute wall, above).
- L20 capstone **Last Stand of the Vale**: for 8s you cannot drop below 1 HP.
  Third tier: cheap, big, unkillable.

**Lance** — passive: +15% damage, Descend's cooldown halved.
- L10 **Piercing Fall**: Descend now deals heavy damage on landing and stuns 1.5s.
- L18 **Widow's Thrust**: a single-target strike that hits harder the lower the target's health.
- L20 capstone **Valkyrie's Choice**: mark a target; for 10s all your hits on it crit.

### Bard

*Shared:* Cutting Chord, Mending Verse, Dirge, Marching Air, Broken Verse.

**Decided 2026-09-11: Bard leans on heals-over-time and group buffs.** The
current kit has one buff and no HoT at all — every heal is a burst, which is a
Priest kit wearing a Bard hat. Songs should linger.

**Hymn** — passive: healing +20%, and Marching Air also applies Soothing Verse
to everyone it hits, so the speed buff is a party HoT.
- L4 **Soothing Verse** (new): single-target heal over time, 12s, cheap. Keep
  it rolling on the tank.
- L8 **Anthem of the Vale** (existing, reworked): party heal over 12s instead
  of a burst.
- L12 **Battle Hymn** (new): party +10% damage for 20s, 1-minute cooldown.
- L20 capstone **Chorus**: every HoT you have running ticks twice as fast for
  8s. The panic button that rewards having set up.
- **Ballad of the Long Barrow** (the big burst heal) moves to Bard's slot-2
  rune move, so either spec can carry one emergency heal.

Hymn is deliberately three spec abilities rather than two: a HoT healer needs
the third button. The rhythm is keep songs up, refresh, Chorus when it goes
bad — a different job from the Tinker Medic's direct heals and turret.

**Dirge** — passive: damage +20%, Cutting Chord applies a stacking bleed.
- L10 **Mocking Verse**: a damage-over-time that also reduces the target's damage 10%.
- L18 **Crescendo**: consumes all your bleeds for a burst.
- L20 capstone **The Last Note**: on a kill, your next three Chords are instant.

### Necromancer

*Shared:* Soulbolt, Creeping Rot, Grave Draught, Chill of the Barrow, Harvest.

**Grave** — passive: Rot ticks 30% faster, levies last longer.
- L10 **Raise Levy** (existing pet, becomes spec-only).
- L18 **Corpse Burst** (existing, becomes spec-only).
- L20 capstone **Mass Grave**: raise three levies at once for 15s.

**Pact** — passive: +20% max health, Grave Draught heals for double, threat doubled.
- L10 **Bone Ward**: convert 20% of max health into an armour shield for 10s.
- L18 **Grave Claim**: a taunt that also roots the target 2s.
- L20 capstone **Refuse the Grave**: on lethal damage, instead drop to 30% and drain everything within 8m.

### Tinker

*Shared:* Bolt Thrower, Burning Oil, Blackpowder Charge, Snare Net, Overload.

**Artillery** — passive: +15% damage, turrets fire 30% faster.
- L10 **Field Turret** (existing, becomes spec-only).
- L18 **Field Repair** stays here as a self-only patch (existing).
- L20 capstone **Bombardment**: three Blackpowder Charges land in a line.

**Medic** — passive: healing +20%, Field Repair works on allies at range.
- L10 **Triage**: a cheap fast heal that's stronger under 40% health.
- L18 **Mending Turret**: a turret that heals the lowest ally in range every 2s.
- L20 capstone **Tonic of the Marches**: party-wide heal over time plus cleanse.

## Runes become moves

Today's runes tweak an existing ability — Forked Bolt, Heavy Bolt, Deep Rot.
Keep those, but **every slot now offers one modifier and one new active
ability**, and the three slots have the same theme across all four classes so
the system is learnable once:

| Slot | Theme | Modifier example | New-move example |
|---|---|---|---|
| **1** | Offence | Forked Bolt (existing) | *Graveshot*: a long-cooldown nuke |
| **2** | Defence / sustain | Unbroken (existing) | *Bracing Draught*: a self-heal on a cooldown |
| **3** | Mobility / utility | Quickstep (existing) | *Vault*: a short dash that breaks snares |

That gives every class the four levers asked for — **absorb more, move more,
more health, more damage** — as choices rather than as a spec. A Bulwark
Valkyr can take the slot-3 dash for a mechanic-heavy boss and swap back to
Feathered Rampart for a stand-and-hold one. Runes are swappable out of combat,
free, in town or at a gravestone.

Twelve new rune abilities to write (one per slot per class). The other twelve
already exist.

## New effect types the engine needs

The ability system has: damage, aoe_damage, dot, heal, aoe_heal, taunt, speed,
drain, summon. The specs need four more, all small:

- **damage_reduction** — Wingguard, Unbroken Wing, Bone Ward, Last Stand.
- **interrupt** — Broken Verse is *meant* to be one and is currently a slow,
  because nothing in the engine can stop a cast. The Archive boss and
  the parse both assume interrupts exist. This is the most urgent of the four.
- **stun** — Piercing Fall, Grave Claim's root.
- **stack** (a stacking debuff) — Dirge's bleeds, Crescendo consumes them.
- **hot** (heal over time) — Soothing Verse, Anthem, the Hymn passive. The
  DoT machinery already exists; this is its mirror.
- **buff** (party stat buff with a duration) — Battle Hymn.

## What changes in code

- `ClassData` gains a `specs` list; each spec is data: passive, the two
  ability swaps, capstone. **~20 lines of code, the rest is entries.**
- `AbilityBar` reads the active spec when building the bar. Existing.
- `Stats.apply_class()` applies the spec passive alongside the class.
- `CharacterState` saves `spec`. Switching spec: out of combat, at any inn or
  graveyard, free. A cost would only ever stop someone filling the role the
  night needs, and in a group of five that is the one thing you never want.
- The parse baseline (`ironveil-qol-spec.md` §3) is per spec, which it
  already assumes.
- 8 spec passives, 12 spec abilities (6 are existing ones re-flagged), 8
  capstones, 12 rune moves. **~26 new ability entries.** The ability system is
  data, so this is mostly writing.

## Build order

1. Spec data on `ClassData` and the save field — the frame.
2. Re-flag the seven existing abilities as spec-only (Claim the Slain,
   Wingguard, Mending Verse, Anthem, Raise Levy, Corpse Burst, Field Turret).
3. The eight passives — mostly stat multipliers, all existing machinery.
4. The six genuinely new spec abilities for Lance, Pact, Dirge and Medic.
5. Capstones.
6. Rune moves.

Steps 1-3 make specs *work*. A Necromancer can tank with Pact after step 3
even before its new abilities exist, because the passive does most of it.
