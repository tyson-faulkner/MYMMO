# Kingsmourn (MyMMO)

Read `docs/HANDOFF.md` first. Then `docs/BUILD_PLAN.md` (the build order and the
standing orders) and `docs/BUILD_PROGRESS.md` (where the last pass stopped).

## What this is

A small-scale MMO for 5-10 friends, built in Godot 4.7.2 with a Nakama backend
and original art from Blender. `docs/kingsmourn-design.md` is the locked design
document and is not to be re-litigated. `docs/reference/` holds the approved
visual direction.

## Working with Tyson

He is new to all of this. Plain English, no assumed knowledge, short answers —
cliff notes, not essays. Give him one copy-pasteable line at a time and say what
success looks like. Never claim something is done without having run it.

## Standing orders for the build loop

Tyson has asked not to be interrupted with questions while the game is being
built. If a detail is unspecified, decide it, build it, and write the decision
into `docs/BUILD_PROGRESS.md` under "Decisions made autonomously". Only stop for
something genuinely irreversible or genuinely ambiguous.

## Before you commit, run both of these

```
godot --headless --path godot-project --check-only --script res://<changed>.gd
godot --headless --path godot-project res://tests/zone_smoke_test.tscn
```

The smoke test builds the real zone, spawns the real enemies and walks the quest
chain. It must print `SMOKE TEST PASSED` before anything is committed. Add a
check to it whenever you add a system.

Known false positives from `--check-only`: autoload singletons (`Network`,
`ItemDatabase`, `QuestDatabase`, `MobDatabase`) are not registered in that mode,
so "Identifier not found" for those is noise, as is the
"Failed to compile depended scripts" that cascades from them. Build the script
class cache once with `--editor --quit` first or every `class_name` fails.

## Layout

```
godot-project/   the game client
  scripts/data/        ClassData, MobData, QuestData  (definitions)
  scripts/autoload/    Network, ItemDatabase, QuestDatabase, MobDatabase
  scripts/combat/      Stats: health, class resource, level, XP
  scripts/enemies/     Mob AI, MobContainer, MobSpawner
  scripts/npc/         NPC interaction and quest handing
  scripts/quests/      QuestLog, server-owned
  scripts/world/       ZoneBuilder, AreaTrigger, DungeonPortal
  scenes/zones/        thornhollow_vale.tscn — the first zone
  tests/               zone_smoke_test.gd
nakama-server/   Nakama via Docker (only its docker-compose.yml is used)
blender-source/  raw .blend files, the source of truth for art
docs/            design doc, kit spec, reference pack, plan, progress
```

## Two rules that matter more than they look

**Server authority.** The client asks, the server decides, the server
broadcasts. Copy the pattern in `scripts/combat/stats.gd`. Anything that changes
health, XP, quest state, currency or loot follows it.

**Everything is data.** Enemies and quests are entries in
`scripts/autoload/mob_database.gd` and `quest_database.gd`. Adding the fortieth
enemy should be one dictionary entry, never new code. Keep it that way — it is
the only reason a whole game's worth of content is reachable.

## Art

Current art is placeholder primitives tinted to the locked palette: cream stone,
blue slate roofs, warm timber, gold heraldry, green farmland. Every placeholder
is a scene whose `Mesh` node can be replaced by a `.glb` with no code change.

When Blender is running with the Blender MCP addon (port 9876), work through
`docs/kingsmourn-kit-spec.md`: one piece at a time, on a 1m grid, exported as
`.glb` into `godot-project/assets/kit/`. Never redo an approved piece.

## Git

Commit every completed task, message `Kingsmourn: <what>`. Push when a milestone
lands — this machine has Tyson's GitHub credentials, so `git push` works here
even though the cloud sandbox can't.
