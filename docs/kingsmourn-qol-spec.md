# Kingsmourn — Quality of Life & Systems Spec

Agreed 2026-09-11. Everything here is built into the game, not an addon: the
server already owns every number an addon would want, so it is cheaper to do
natively and impossible to cheat.

The recurring principle: **most famous WoW addons exist to patch a problem
Blizzard shipped.** Don't ship the problem. Questie exists because quest
locations were hidden; healer frames exist because the default ones were bad;
mass-buff addons exist because buffs were single-target. Each of those is one
design decision here, not a feature.

Ordered by build priority. Each section says what it is, the rules, what
already exists in the code to build on, and roughly how big it is.

---

## 1. Combat recorder (the foundation for 2, 3 and 4)

Everything below needs the same thing: a record of every combat event. Build
this once.

**What the server records, per event:** timestamp, source, target, ability id,
amount, kind (damage / heal / absorb / interrupt / death), whether it was a
crit, and whether the damage was *avoidable* (a boss mechanic that could have
been dodged — the boss ability system flags these).

**Existing hooks:** `Stats.apply_damage(amount, source_peer_id)` already
carries who did it. Add the ability id to that call and every ability already
routes through `AbilityBar`, so the change is one parameter. Heals go through
`Stats.heal()`. Boss abilities (per `kingsmourn-endgame-spec.md`) carry an
`avoidable` flag in their data.

**Fight boundaries:** a fight starts when a boss encounter takes damage and
ends on its death or a wipe. Trash is recorded but not scored.

**Storage:** the recap for the last fight in memory; per-boss personal bests
and server records in Nakama storage. Raw event logs are not kept past the
recap — nobody will read them and they grow forever.

Size: ~300 lines. Everything else in this document reads from it.

---

## 2. The meter and the recap

**Live bars.** A small panel during any fight: damage, healing, damage taken as
three switchable columns, one bar per party member, class-coloured. Because the
server computes all of it, nobody can fudge their numbers.

**The recap.** When a boss dies, a panel appears for 20 seconds (and stays in
the log after):

- **Time to kill**, with the group's best for that boss beside it.
- **The three columns** as totals.
- **Awards**, one line each, chosen so every role can win something: Most
  Damage, Most Healing, Most Damage Taken (the tank's award — say it that way),
  Most Interrupts, Fewest Avoidable Hits, Never Died, First Blood, Killing Blow.
- **Your parse** (section 3).

**The coach.** Click your own bar to see your abilities ranked — total damage,
casts, average hit, crit rate — and then three sentences the game writes for
you about what to change:

- *"You spent 31% of that fight with nothing on cooldown."* — idle time,
  the number one thing separating a new player from a good one.
- *"Creeping Rot fell off four times."* — uptime on your damage-over-time and
  buffs.
- *"Overload was ready 7 times; you used it 3."* — cooldown usage.

No addon does this well. They show numbers and leave you to work out the
lesson. The game already knows every cooldown and every buff, so it can just
say it.

Size: ~500 lines including the UI. The coach's three checks are each ~20 lines.

---

## 3. The parse

Warcraft Logs gives you a 0-100 score for how you played a fight, colour-coded.
It works there because millions of logs give a distribution to rank against.
With five to ten friends there is no distribution, so ours scores you
**against what the fight allowed**, not against a crowd. Same feel, honest
maths.

**Four components, 100 points:**

| Component | Points | What it measures |
|---|---|---|
| **Uptime** | 30 | Share of the fight you had a global cooldown in use. Missing three cast cycles while running when you didn't need to run shows up here. |
| **Rotation** | 25 | Key abilities used when available; damage-over-time and buff uptime. The coach's checks, scored. |
| **Mechanics** | 25 | Avoidable damage taken (per hit, scaled by how much), interrupts landed vs available, stood in the ink pool, was on the dais when named. Boss abilities carry the `avoidable` flag; this just reads it. |
| **Output** | 20 | Damage or healing per second against a **baseline for your class, spec and gear**. |

**Gear normalisation — the "item level parse" done natively.** Every gear item
has a budget (6/14/24 by tier, in `GearDatabase.TIER_BUDGET`), so a character's
total gear score is one sum. The output baseline scales with that sum. So a
player in Levy gear and a player in Sovereign gear are each scored against what
*their* gear should do — the thing WoW needed a whole second parse to fix.

**Colours,** WoW's, because everyone already knows them: grey 0-24, green
25-49, blue 50-74, purple 75-94, orange 95-99, gold 100.

**Comparisons,** in order of how much they should matter:

1. **Your own best on this boss.** The main one. Beating yourself is the loop.
2. **Your friends on the same class.** Shown when there is one. With two
   Necromancers on the server this is the rivalry; with one it says "no one to
   compare".
3. **The server record** for the boss, any class — who holds it and since when.

**Tanks and healers** get the same four components with role-appropriate
meaning: a healer's Output is healing per second, a tank's Mechanics weights
"held the boss" and "used a defensive before a big hit".

**Where it shows:** the recap, a "Records" tab in the character sheet, and the
skald (section 6) announces when a personal best or server record falls.

Size: ~250 lines on top of the recorder. The baseline table is data — one
number per class per spec per gear-score band — tuned by playing.

---

## 4. Healer frames

The VuhDo problem, solved by design rather than addon.

**Party frames.** One frame per party member, always visible, class-coloured,
showing health, resource, a small list of debuffs, and a range indicator (the
frame greys out when they're out of your heal's range). Dead members show as
dead. The tank's frame is marked.

**Mouseover casting, built in.** Hover a frame and press a heal key: it heals
that person. No clicking their body in the world. This is a targeting rule in
`AbilityBar`, not a UI feature — "if the mouse is over a party frame, that
frame's player is the target for this cast."

**Smart default.** Press a heal with no target and no mouseover: it goes to the
lowest-health party member in range. Removes the last excuse for a heal going
nowhere.

**Buffs are party-wide.** Marching Air, Anthem of the Vale and any future buff
hit the whole party in range with one press. There is no mass-buff addon
because there is nothing to mass.

Size: frames ~200 lines; the targeting rule ~40; making buffs party-wide is a
data change on the abilities.

---

## 5. Quest markers

Built in, and **derived from data, never hand-placed.** A quest names its
target; `MobDatabase` says what that is; the zone's spawners say where. So the
game computes the objective area itself. Move a camp and the marker moves. This
is the thing Questie cannot do.

**Four layers:**

- **NPCs:** yellow **!** quest available, yellow **?** ready to hand in, grey
  versions for "too low level" and "in progress". On the NPC, the minimap, the
  map.
- **Map:** a translucent circle over each objective area, numbered to match the
  quest log. Reach objectives use the `AreaTrigger` box; kill objectives use the
  bounding circle of matching spawners; talk objectives point at the NPC.
- **Minimap:** an arrow on the edge toward the *tracked* objective with a
  distance — "Agitators · 240m". One tracked quest at a time so it never
  clutters.
- **On arrival:** the arrow becomes "you're here" and the matching mobs get a
  marker over their heads so you're not killing the wrong wolves.

Plus a **"what now"** line in the log when nothing is tracked: the next quest in
the chain and who has it.

**Existing:** `QuestLog`, `QuestDatabase` objectives with typed targets,
`MobSpawner.mob_id`, `AreaTrigger.area_id`. The smoke test already proves
every target exists somewhere, which is the same lookup the markers need.

Size: ~400 lines including the map. The minimap itself does not exist yet and
is part of this.

---

## 6. Gravestones and the skald

**Gravestones.** When a player dies, a small stone appears where it happened
with their name and what killed them. Anyone who walks up can *pay respects*
(3s channel) for a 10-minute +5% damage-and-healing buff, once per stone per
player. Stones last 24 hours; a spot with three or more becomes a cairn and the
buff is +8%. Underground stones are cleared when the dungeon resets.

**The chronicle.** Ilsa already exists as the one who writes things down. The
server keeps a short log of notable events — first kill of each boss, personal
bests and records (section 3), grudge tiers reached (section 7), most deaths
in a night — and Ilsa tells you the last few when you talk to her, plus a
weekly line in chat: *"This week: the First King fell to five; Mike holds the
Kell record; Tyson died to wolves. Twice."* This isn't lore. It's your group's
history, which is the only kind anyone reads.

Size: gravestones ~200 lines (a spawned node with an interact). Chronicle ~150
plus Nakama storage for the log.

---

## 7. Grudge bosses

Every boss has a list of mechanics, in order. **Grudge tier N turns on the first
2+N of them.** Each kill raises that boss's grudge by one for every player
present, up to a cap: **5 for dungeon bosses, 3 for raid bosses** (raid nights
are harder to organise, so the ladder is shorter).

**Whose grudge counts:** the group fights at the **lowest member's tier**. A
fresh friend joining a grudge-4 group drops the run to their tier and climbs
with help. In a group of five this rule matters more than any other.

**Visible:** the boss's name carries the tier — *Master Kell ⟨IV⟩* — and the
chronicle records the first time each tier falls.

**Rewards** scale with tier: a modest loot-chance bump per tier, and mounts
change from a flat drop to **guaranteed at the top tier**. So nobody runs the
raid nine times for nothing. `MountController` and the loot tables are already
in place; this changes the drop-chance lookup to take the tier.

**Why it's worth building:** three dungeons and a raid at cap is normally where
a project like this dies. Grudge makes the fifth kill a different fight from
the first without a single new room. It also *is* the season system's engine
(section 9): the same mechanic-swapping code powers both.

**Existing:** the boss ability component from `kingsmourn-endgame-spec.md` is
where the mechanic list lives. Grudge is a per-player-per-boss counter in
`CharacterState`.

Size: ~150 lines once the boss ability system exists. Most of the work is
writing 2-3 extra mechanics per boss, which is data.

---

## 8. Chests

The rule: **a chest never contains something you'd shrug at.** Five great
chests a week beats fifty with a green in them.

**Contents, by tier:**

- **Common** (a few per zone, respawn 30 min): Sovereigns and one *run-changing*
  consumable — never a stat potion. Examples: *Marcher's Draught* (your first
  death in the next dungeon doesn't count); *Ferryman's Coin, lesser* (one free
  corpse-run teleport); *Widow's Salt* (your next gravestone buff is doubled).
- **Rare** (one per zone, 2 hours, announced in chat — *"something glints in
  the Sablemarch flood"*): a **gear token for the slot your character is
  weakest in** — the game knows your eleven slots and picks the worst — or a
  cosmetic: a weapon glow, a banner colour, a title.
- **Season chest** (one, at the end of the raid, once per season): the season's
  unique cosmetic.

**Once per character per respawn**, so nobody farms them. Chest locations are
a small list per zone; the rare one picks randomly from its list so people
actually look.

Size: ~200 lines plus consumable effects, which use the existing buff/DoT
machinery.

---

## 9. Seasons

The level cap stays 20 forever. Gear tiers stay. **Nobody's gear ever becomes
junk.** What changes each season is the bosses: a new skin and a new mechanic
set, six to eight weeks at a time.

**Season rewards are cosmetics, mounts and titles only. Never power.** That is
the whole reason it works.

**It's the grudge engine.** Grudge turns mechanics on within a season; a season
swaps the whole list and the model. Build the boss ability system once, get
both. A season is then: one new mechanic list per boss (data), one skin per
boss (art), one cosmetic reward set, and a chronicle line when it turns over.

Size: after grudge exists, the code is ~50 lines. The rest is content.

---

## 10. Upgrade arrows

A helmet drops. Is it better than yours? Today you'd open the bag, read three
numbers, remember your three, and do the maths.

**Per-class stat weights** (armour / power / stamina — Valkyr leans armour,
Necromancer leans power) give every item a single score for *your* class. Any
item that beats what's in its slot shows a green up-arrow; hovering shows the
delta — *"+4 armour, −2 power, upgrade"*. Rings compare against the worse of
the two.

**Existing:** `GearDatabase` already computes armour/power/stamina per item;
`PlayerInventory.gear` holds what's worn. This is ~120 lines.

---

## Build order

| # | System | Depends on | Size |
|---|---|---|---|
| 1 | Combat recorder | — | ~300 |
| 2 | Upgrade arrows | — | ~120 |
| 3 | Quest markers + minimap | — | ~400 |
| 4 | Healer frames + mouseover | — | ~250 |
| 5 | Meter, recap, coach | 1 | ~500 |
| 6 | Parse | 1, 5 | ~250 |
| 7 | Boss ability system | (endgame spec) | ~400 |
| 8 | Grudge | 7 | ~150 |
| 9 | Gravestones + chronicle | 1 | ~350 |
| 10 | Chests | — | ~200 |
| 11 | Seasons | 8 | ~50 + content |

Items 2, 3 and 4 have no dependencies and are the biggest quality-of-life jump
per hour. Everything else is downstream of the combat recorder, so it goes
first.
