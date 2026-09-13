# Ironveil — Design Document

Version 0.1 — 9 September 2026

A small-scale MMO for a group of 5–10 friends. Built solo in Godot, with a
Nakama backend and original art made in Blender.

---

## The pitch

A bright, prosperous kingdom in a mountain valley — and a very ugly argument
underneath it. The king is dead with no heir, and the great houses that were
his bannermen each believe the throne is theirs. Sunlit world, dirty politics.

Visually: World of Warcraft's Stormwind. Narratively: Game of Thrones.

## Tone and identity

- Bright and painted, not grim and grey. Blue slate roofs, cream stone, gold
  heraldry, green farmland, snow-capped peaks.
- The conflict is between people, not against demons. There is no cosmic evil.
- Because the enemies are people, nearly every enemy in the game shares one
  humanoid skeleton. This is a deliberate production decision as much as a
  creative one — it is the cheapest fantasy setting one person can build.

## The world

The last war killed so many that the dead themselves became the prize.

- Valkyrs claim the honoured slain.
- Necromancers put the rest back to work.
- Tinkers build machines so that fewer people have to die at all.
- Bards keep the histories that decide whose claim to the throne is legitimate.

All players are on the same side. The rival houses are the content, not a
faction wall between players — with a playerbase this small, splitting it in
half would mean half the server can never group with the other half.

Two houses appear in the visual reference and their heraldry is settled:
a blue-and-gold sword-and-sunburst, and a green banner with a white stag.

---

## Characters

**No playable races.** One body type. Character identity comes from class and
gear. This means one skeleton, one animation set, and every piece of armour
fits everybody automatically.

**Four classes, forming exactly one party:**

| Class | Role | Notes |
|---|---|---|
| Valkyr | Tank | Winged, shield and spear. Female-only. |
| Bard | Healer / support | Songs that mend and buff. |
| Necromancer | Ranged damage | Skeleton pets. |
| Tinker | Ranged damage | Turrets and bombs. |

Dungeons are therefore built around four roles, and 5–10 friends divides
cleanly into groups.

**Resource:** mana for all classes to start. Rename the bar per class for
flavour at zero code cost — Bard has *Verse*, Tinker has *Charge*, Necromancer
has *Soul*. Valkyr is the likely first exception, since tanks generally want a
resource that builds during a fight rather than draining.

---

## Progression

Level cap **20** for this first release. Later expansions raise it.

**Abilities:** seven unique abilities per class, plus three armour slots that
each grant a new move — with a choice between two options per slot. That gives
eight possible builds per class. (This is essentially WoW Season of Discovery's
rune system, arrived at independently.)

Two rules that matter:

1. **The two options in a slot must differ by situation, not by power.** If one
   is "12% more damage" and the other is "15% more damage", the choice is fake
   and everyone picks the same one. If one hits a single target hard and the
   other hits three, the answer depends on what you are doing.
2. **About half the slot choices should modify an existing ability rather than
   add a new one.** "Your Soulbolt now chains to a second target" costs a code
   tweak. A whole new ability costs animation, art, icon, and effects.

**Level-up moments:** use ability *ranks* to fill levels cheaply. Soulbolt I at
level 4, II at 8, III at 12 — same code and art, bigger numbers. This means
six or seven real abilities per class is genuinely enough content.

---

## Gear

Roughly three tiers across levels 1–20: starter, mid, and a cap set.

**Slot ownership is the core rule.** Certain slots belong to the open world and
questing — trinkets, rings, cloaks — and are simply never placed in dungeon or
raid loot tables. Raids and dungeons own armour pieces and weapons.

This makes world gear permanently relevant by structure rather than by delicate
number-tuning. It cannot be outscaled because there is nothing to outscale it
with. Questing stays worthwhile alongside dungeon grinding, and nobody grinds
for a world item only to have the first dungeon invalidate it an hour later.

Layer unique effects on top for flavour — a ring that procs something no raid
item does.

**Shared currency.** A special currency is earned from *both* questing and
dungeons, and buys meaningful rewards. This is the keystone that makes the gear
philosophy work: both paths lead somewhere.

---

## Combat

Tab-target, with click-to-select as well. Tab cycles to the nearest enemy,
clicking picks a specific one — the same targeting system underneath.

Tab-target was chosen over action combat deliberately: far less code, and it is
forgiving over a network. Action combat requires lag compensation, which is one
of the genuinely hard problems in multiplayer programming.

---

## Group content

- **Dungeons:** 5 players, completable with 4.
- **Raid:** 5 players, with a possible 10-player option.
- **Heroic raid:** a harder version, rewarding a unique mount.

**Build one scaling system, not three tunings.** Bosses check how many players
are inside the instance and scale health and damage accordingly. Then "a 5-man
that works with 4" and "a raid that works with 5 or 10" are the same code
written once, and it no longer matters how many friends log on that night.

What makes a raid a raid here is length, difficulty, and mechanics — not player
count.

---

## Death, mounts, PvP

**Death penalty:** resurrect at the spirit healer and take roughly a five-minute
debuff, or run back to your corpse with no timer. (This is WoW's resurrection
sickness, which means it is proven and simple to build.)

**Mounts:** three total — one from a dungeon, one unlocked out in the world, and
a unique one from the Heroic raid. Mounts are cheap mechanically (a model, a
ride animation, a speed buff) and are among the most motivating rewards in the
genre.

**PvP:** duels between players only, for version one. Duels are nearly free —
combat already exists, players simply target each other. AI opponents are
deferred indefinitely: combat AI smart enough to feel like a real opponent is
harder than everything else in this game combined.

---

## Art direction

Heavily World of Warcraft influenced. The reason WoW's art works is
**readability** — any character is identifiable by silhouette alone. Overly
realistic graphics are hard to get invested in and brutally expensive; overly
cartoony art loses the feeling entirely.

Concrete targets:

- Low polygon counts, roughly 3,000–8,000 triangles per character.
- Detail **painted into textures**, not modelled into geometry.
- Exaggerated proportions: big shoulders, oversized weapons.
- Saturated colours, simple lighting, no photorealistic materials.

This is also the most forgiving style to learn Blender with.

---

## Technical setup

| Piece | Choice |
|---|---|
| Engine | Godot 4.7.2 |
| Backend | Nakama, run via Docker |
| Art | Blender |
| Repository | github.com/tyson-faulkner/MYMMO |
| Client base | devmoreir4/godot-3d-multiplayer-template |

**Hosting plan:** start with Tailscale — free, about ten minutes to set up, and
it puts friends on a private network with the host machine so no router
port-forwarding is needed. The catch is the host PC has to be on. Move to a
small VPS when that becomes annoying. Note that `nakama-server` already contains
`docker-compose-postgres.yml`, which is lighter on memory than the CockroachDB
default and is the better choice on a cheap box.

---

## Scope discipline

An MMO is the hardest genre a solo developer can choose, and the thing that
kills these projects is planning three zones before anything is playable.

**First playable target:** one zone, four classes, one dungeon, something the
group can actually log into and play together. Everything beyond that is
version two. The three-zone, multi-dungeon, full-raid plan is not wrong — it is
just later.

---

## Still open

- Names for the realm, the capital city, and the first zone.
- How quests are delivered and tracked.
- Professions and crafting.
- Vendors, economy, and the details of the special currency.
- Any stat or talent system beyond the three rune slots.
- Character appearance customisation.
- XP curve tuning (target: roughly 8–10 hours from 1 to 20).
