# Kingsmourn — Build Progress

Updated by the autonomous build loop. Newest entry at the top of the log.
Milestone checkboxes live in `docs/BUILD_PLAN.md` — tick them there as they land.

## Current state

- **Milestone:** M1-M6 all have a working first pass. Next: class selection on the menu, then M7 persistence.
- **Loop status:** running
- **Last verified playable:** 2026-09-11, `tests/zone_smoke_test.gd`, 50/50 checks passing

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
