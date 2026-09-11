# Kingsmourn — Build Progress

> ## PRIORITY, set by Tyson 2026-09-11 before sleeping
>
> **Characters come before Phase 2 props.** He wants to wake up to classes and
> enemies that are modelled and skinned to look like the reference art in
> `docs/reference/01-characters/` — explicitly NOT grey blobs. A cobblestone
> tile matters less to him than a Valkyr that looks like a Valkyr.
>
> Build order for that: base humanoid body (WoW proportions, big shoulders,
> ~7 heads tall) → shared skeleton and skinning → the four class silhouettes as
> armour and texture on that body → enemy variants. Full spec in
> `docs/kingsmourn-character-spec.md`.
>
> **Premade assets are allowed.** He has said so explicitly: a CC0 low-poly
> rigged humanoid as a starting base is fine, as long as it matches the guide —
> low-poly, exaggerated proportions, detail painted into the texture, saturated
> colours, and the palettes in the reference pack. Re-texture it to the classes
> rather than shipping it as-is.
>
> **If animation proves too slow, ship static posed models rather than nothing.**
> A silhouette-correct Valkyr standing still beats a capsule.

Updated by the autonomous build loop. Newest entry at the top of the log.
Milestone checkboxes live in `docs/BUILD_PLAN.md` — tick them there as they land.

## Current state

- **Milestone:** M1-M7 done, parties and runes in. Next: gear slots and stats, then vendors, then content volume.
- **Loop status:** running
- **Last verified playable:** 2026-09-11, `tests/zone_smoke_test.gd`, 121/121 checks passing

## Not yet verified against a live backend

The persistence save format, its validation and its offline behaviour are all
covered by the smoke test. What is NOT verified from the cloud sandbox is the
round trip against a running Nakama: Docker is on Tyson's machine and the
sandbox can't reach it. Someone running the loop locally should host a game with
`docker compose up` running, level up, quit, rejoin, and confirm the character
comes back.

## Waiting on Tyson (nothing here blocks the loop)

- `git push` — the sandbox has no GitHub credentials. Commits pile up locally
  and he pushes when he wants them on GitHub.
- Blender modelling — needs Blender open on his PC with the MCP server on port
  9876. Until then, all art is styled placeholder geometry with swap-in points.
- Docker/Nakama running — only needed to integration-test M7, not to write it.

## How to verify (run this every pass)

Godot lives in the cloud container (GitHub is blocked from the device VM).
Stage the project files up, then:

- `validate.sh` — `--check-only` on every script, with the documented autoload
  false positives filtered out.
- `godot --headless --path <proj> res://tests/zone_smoke_test.tscn` — builds the
  real zone, spawns the real enemies, and walks the quest chain end to end.
  36 checks. Non-zero exit if any fail.
- `xvfb-run` + the screenshot harness when a change is visual.

## Decisions made autonomously

Recorded here so the design stays coherent and nothing gets asked twice.

- 2026-09-11 — Art strategy: build every visual as a scene with a replaceable
  `Mesh` node using the design-doc palette, so a `.glb` swap later needs no code
  change. Rationale: never block gameplay work on Blender availability.
- 2026-09-11 — Names, which the design doc left open: the realm is **Aldermarch**,
  the capital is **Kingsmourn**, the first zone is **Thornhollow Vale**, the
  first dungeon is **The Barrow of the First King**, and the shared
  quest-and-dungeon currency is the **Sovereign**.
- 2026-09-11 — The Valkyr's resource is **Valor**, and it builds from damage
  dealt and taken rather than draining, which the design doc predicted a tank
  would need.
- 2026-09-11 — Mobs and quests are dictionary entries in an autoload rather than
  individual `.tres` files. Adding the fortieth enemy is then one entry, which
  is what makes a zone's worth of content reachable in a loop.
- 2026-09-11 — Enemy movement is direct steering with a leash, not navmesh
  pathfinding. A navmesh needs baked geometry, and the geometry is still a
  blockout that changes every pass.
- 2026-09-11 — The dungeon is a separate region of the same world reached by a
  portal, buried 500m underground, rather than a per-group instance. For five to
  ten friends that is the right trade; real instancing belongs with persistence.
- 2026-09-11 — Godot runs in the cloud container, not the device VM: GitHub is
  blocked by the device's egress allowlist, so Godot can't be downloaded there
  this session. Validation stages files up to the container instead.

## Log

### 2026-09-11 — The rune slots: eight builds per class, no new art
Three armour slots, two runes each, four classes — 24 entries. Every one
modifies an ability that already exists rather than adding one, which is the
whole reason the build system costs nothing to make: "your Soulbolt forks to two
more enemies" is a number, a new ability is animation, art, an icon and effects.

The design doc's rule is enforced by a test, not just by intent: the two options
in a slot must differ by SITUATION, not by size. A check walks every slot and
fails if both options share an effect type with similar values, which is exactly
the fake choice the doc warns about — the one where everyone picks the bigger
number and the slot may as well not exist.

Slots unlock at 5, 11 and 17. Swapping is free: a respec cost only punishes the
people who experiment, which is the point of having eight builds.

Choices are server-validated (right class, right slot, high enough level) and
saved with the character, because a build you lose on logout is not a build.

### 2026-09-11 — Parties, because grouping was actively punished
Only whoever landed the killing blow got XP and quest credit. In a game built
for five to ten friends, that meant four people hunting the same camp needed
four times the kills. Nobody would ever have grouped, in a co-op game.

Now everyone in the party within 60m of the kill is credited, and:

- **Quest credit is not split.** Eight bandits means eight bandits for the whole
  party, not thirty-two between them. Splitting it is the exact maths that makes
  people refuse to group.
- **XP is split, gently.** A duo gets 68 each rather than 50, a five-man 48 each
  rather than 20. Grouping should never be worse than going alone.
- Ghosts and anyone too far away are excluded, so nobody farms from the inn.

Grouping rides on the chat that already exists — `/invite <name>`, `/leave`,
`/party` — rather than needing an invite window. Costs no UI, works today, and a
proper panel can replace it later without changing anything underneath.

Party size caps at ten, matching MAX_PLAYERS and the design doc's "raid is five,
with a possible ten-player option".

### 2026-09-11 — M7: characters survive logging out
Nakama was installed, verified, and connected to nothing — it powered a login
test scene and that was all. Now:

- `Account` autoload logs in by device id (no passwords for anyone to forget)
  and reads/writes the character to Nakama storage.
- `CharacterState` turns a character into a plain dictionary and back: class,
  level, XP, health, position, quest log, currency, inventory. Deliberately
  pure — no networking, no Nakama — so the part most likely to silently corrupt
  a save is the part easiest to test. It is versioned, with a migration hook.
- `PersistenceManager` decides when: every 45 seconds, on level-up, on quest
  hand-in, and on quit. Level-ups and hand-ins because those are the moments
  losing progress stings most.

**The game must work without it**, and does: if Docker isn't running, login
fails quietly, a warning is pushed, and everything else carries on exactly as
before. The smoke test asserts that path.

Trust model, stated plainly in the code: each client saves its own character
under its own Nakama account. The server decides every value during play, but
the client writes it down. For 5-10 friends that is the right trade; making it
server-authoritative means adding a Nakama server module and routing writes
through it, and nothing else would change.

Third time the same bug shape appeared: the save read the class off the body
while Stats held the real ClassData, so it recorded the wrong class. Stats is
the source of truth everywhere now — ability bar, save format, all of it.

### 2026-09-11 — Loot actually drops, and one quest was impossible
Enemies roll their loot table on death and leave the results on the ground, and
they pay out Sovereigns to whoever killed them. Both were defined as data and
neither was wired to anything.

Worse: `credit_collect` existed and NOTHING ever called it, so q_supplies
("recover 4 provisions") could never be completed — the chain dead-ended at
quest four. Picking an item up now credits it, on the server, when the item
genuinely enters the bag.

The smoke test gained a check that walks every collect objective and confirms
something in the game actually drops the thing it asks for. That class of bug —
content referring to content that doesn't exist — is the one most likely to
recur as the quest count grows.

### 2026-09-11 — Death, which was silently missing entirely
A player who hit zero health simply stayed there: nothing listened for it. Now
you become a ghost and choose, exactly as the design doc specifies: release to
the nearest graveyard and carry five minutes of Grave-Chill (everything you do
lands for 75%), or walk your ghost back to your body and resurrect clean.

The penalty costs time, never progress. Two graveyards exist — one in town, one
inside the barrow, because releasing in a dungeon should not strand you five
hundred metres overhead.

Reclaim distance is re-checked on the server, so a client cannot reclaim its
corpse from across the zone. Ghosts cannot swing.

### 2026-09-11 — Class selection, which finishes M1
The menu is Kingsmourn's now, not the template's. Picking a class shows its
role, its flavour line and what its resource bar is called, and the choice
travels through Network.player_info into the spawned character, so a Bard
actually arrives with 95 health and a Verse bar.

The server sanitises the class id coming off the wire. An unknown one would have
left the character with no ClassData, and therefore no health at all.

### 2026-09-11 — The HUD, which is what makes any of it visible
Health and class resource bars (the resource is named per class, so a
Necromancer sees Soul and a Valkyr sees Valor), XP bar, level, Sovereigns, a
target frame with the enemy's name and level, the seven-slot action bar with
live cooldowns and tooltips, an on-screen quest tracker, a quest log on L, and
toasts for levelling and completing things.

Slots above the player's level correctly show as locked, and abilities you can't
currently pay for dim rather than failing silently when pressed.

### 2026-09-11 — M2: tab-target and 28 abilities
Tab cycles the nearest enemy and clears the target when it dies or walks off.
Seven abilities per class, all four classes, defined as data: damage, area
damage, heals, area heals, damage over time, drains, taunts, summons and speed
changes are generic verbs, so the rune system in M8 can modify them rather than
needing new code for each.

Enemies gained factions, because summons forced the issue: a Necromancer's
raised levy and a Tinker's turret are the same Mob standing on the other side of
the fight. Placed enemies now hunt players and other people's pets; pets hunt
placed enemies; pets expire and do not respawn.

One real design bug the test caught: the ability bar read the character's class
off the body while Stats held the actual ClassData. The two could disagree, and
when they did the bar silently refused every ability of the class you thought
you were. Stats is now the single source of truth.

Also: Tab belonged to the player list, and tab-target combat obviously needs it
more. The player list moved to O.

### 2026-09-11 — M3/M4/M5/M6 blockout: a walkable zone with a dungeon
Thornhollow Vale exists and is playable end to end. 109 geometry pieces on the
surface, a buried barrow interior, 7 NPCs, 69 enemies across level bands 1-12,
two bosses, a stone circle, a portal into the barrow, and the twelve-quest chain
wired to the people who hand it out.

Three real bugs the smoke test caught and that are now fixed: mobs were being
built and never parented (spawn_mob went around the MultiplayerSpawner instead
of through it, so nothing replicated and nothing appeared); the barrow interior
was visible from the fields as a hall floating above the horizon; and the
player's out-of-bounds check would have yanked anyone entering the dungeon
straight back to town, because it assumed the world's floor was near y=0.

### 2026-09-11 — Loop initialised
Read the design doc, kit spec, reference pack and the whole client codebase.
Wrote `docs/BUILD_PLAN.md` (the loop prompt + M1–M9 build order) and this file.
Confirmed Godot 4.7.2 headless runs in the cloud container and matches Tyson's
Windows build exactly. Starting M1.
