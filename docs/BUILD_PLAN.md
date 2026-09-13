# Kingsmourn — Autonomous Build Plan

This file is **the prompt**. A new Claude session reads this plus
`docs/BUILD_PROGRESS.md` and continues building without asking Tyson anything.

## The loop prompt (paste this, or let the scheduled loop fire it)

> Continue the Kingsmourn autonomous build. Read `docs/BUILD_PLAN.md` and
> `docs/BUILD_PROGRESS.md`. Do the next unchecked task, in order. Write real
> code and content — no questions, no approval gates. Validate with headless
> Godot. Commit locally. Tick the box in BUILD_PROGRESS.md with a one-line
> note. Then continue to the next task, or schedule the next wake-up.

## Standing orders (these override the instinct to check in)

1. **Never stop to ask.** If a detail is unspecified, decide it, build it, and
   record the decision in BUILD_PROGRESS.md under "Decisions made autonomously".
   Tyson has explicitly asked not to be interrupted until the game is playable.
2. **The design doc is law.** `docs/kingsmourn-design.md` is locked. Do not
   re-open settled decisions (4 classes, no races, level cap 20, tab-target,
   slot ownership for gear, one scaling system). Anything it lists under
   "Still open" is yours to decide — decide it and write it down.
3. **Data-driven over hardcoded.** Quests, mobs, abilities, loot and NPCs are
   defined as data (Resources / dictionaries in a database autoload) so that
   adding the 40th quest is a data entry, not an engineering task. This is what
   makes "a whole game's worth of content" reachable in a loop.
4. **Placeholder art is allowed and expected.** Blender is not reachable from
   the sandbox in most sessions. Build with primitives styled to the palette
   (cream/tan stone `#D9CBB2`, blue slate `#3E5C8A`, timber `#6B4A2F`, gold
   `#C9A227`, grass `#6F8F4A`). Every placeholder must be a **swap-in point**:
   a scene whose mesh can be replaced by a `.glb` later with zero code change.
   Never block a gameplay task on art.
5. **Server authority, always.** Copy the pattern in `scripts/combat/stats.gd`:
   the client asks, the server decides, the server broadcasts. Any new system
   that changes health, currency, quest state or loot follows it.
6. **Validate before committing.** Run the headless check (see below). A commit
   that fails to parse is worse than no commit.
7. **Commit every completed task**, message `Kingsmourn: <what>`. Never push —
   the sandbox has no GitHub credentials. Pushing is Tyson's `git push`.
8. **Leave the repo playable.** At the end of every task the game must still
   launch. If a change is half-finished, finish it or revert it.

## Validation procedure (Godot headless)

GitHub is blocked from `device_bash` but reachable from the cloud container, so
Godot lives in the **cloud container**, and project files are staged up to it:

1. `device_stage_files` the changed `.gd`/`.tscn` plus `project.godot`.
2. In the container: copy into a scratch project, strip the `Nakama=` and
   `Satori=` autoload lines and the `theme/custom_font` line from
   `project.godot` (their assets aren't staged).
3. `--headless --path <scratch> --editor --quit` **once** to build
   `global_script_class_cache.cfg`. Without this every `class_name` fails to
   resolve and you get useless false errors. `--import` alone does not do it.
4. `--headless --path <scratch> --check-only --script res://<file>.gd` per file.
5. Known false positives, ignore them: `Identifier not found: ItemDatabase`,
   `Nakama`, `QuestDatabase` — autoloads aren't registered in `--check-only`.
6. For a visual spot check: `xvfb-run -a <godot> --path <scratch>
   --rendering-driver opengl3 --resolution 1280x720` with a screenshot script
   (await two `process_frame`s **and** `RenderingServer.frame_post_draw`).

## Build order

Work top to bottom. Each milestone ends in a playable state.

### M1 — Character foundation
- [x] `ClassData` resource + the four classes as `.tres` (Valkyr, Bard,
      Necromancer, Tinker) with role, resource label, resource behaviour.
- [x] `Stats` extended: per-class resource label, resource spend/regen,
      level + XP, XP-to-level curve targeting ~8–10h to 20.
- [x] Class picker on the main menu, class carried through `Network.player_info`
      and applied on spawn.
- [x] Class tint on the placeholder body so four players are visually distinct.
      (Superseded: the four class models and their weapons shipped instead.)

### M2 — Targeting and abilities
- [x] Tab-target system: Tab cycles nearest hostile, click selects, target
      frame UI with name/health, target cleared on death or out of range.
- [x] `AbilityData` resource: id, name, cost, cooldown, range, cast time,
      effect type (damage / heal / buff / summon / taunt), power, target rule.
- [x] `AbilityBar` component on the player: keys 1–7, cooldown tracking,
      server-authoritative execution, resource cost enforced on the server.
- [x] Seven abilities per class as data (28 total), effects implemented
      generically so new abilities are data, not code.
- [x] Action bar UI with cooldown sweeps + resource bar + health bar.

### M3 — Enemies
- [x] `Mob` base: Stats, aggro radius, leash, chase, melee swing, death,
      respawn timer, XP + loot on death, all server-side.
- [x] `MobData` resource: id, name, level, health, damage, speed, aggro range,
      XP, loot table, tint. Mobs are data entries.
- [x] Mob spawner node: place one in a scene, give it a MobData and a count,
      it handles spawning and respawning.
- [x] At least 8 mob types for the first zone (bandits, wolves, risen dead,
      house soldiers) — all sharing the humanoid placeholder per the design doc.

### M4 — NPCs and quests
- [x] `NPC` base: name plate, interact prompt, dialogue panel, quest markers.
- [x] `QuestData` resource: id, giver, title, text, objectives (kill / collect /
      talk / reach), rewards (XP, currency, items), prerequisite chain.
- [x] `QuestDatabase` autoload + `QuestLog` component on the player, server
      authoritative, with kill/collect credit hooks.
- [x] Quest log UI (accept, track, turn in) + objective tracker on screen.
- [x] At least 12 quests forming a chain through the first zone.

### M5 — The first zone
- [x] Zone scene: town square, outer farmland, road, river, hills, dungeon
      approach. Built from the modular kit pieces (or primitives standing in).
- [x] Populate: 6+ NPCs (quest givers, innkeeper, two vendors, guard captain),
      mob spawns by level band (1–5 near town, 6–12 outward), gathering nodes.
- [x] Zone transitions + spawn/graveyard points + spirit-healer corpse run.
- [x] Vendors and the shared quest/dungeon currency.

### M6 — The first dungeon
- [x] Instanced dungeon scene loaded per group, with its own spawn point.
- [x] Three trash packs + two bosses with scripted mechanics.
- [x] Boss scaling by player count (one system, per the design doc).
- [x] Dungeon loot tables: armour + weapons only (world owns rings, trinkets,
      cloaks — never break slot ownership). Enforced by the smoke test.
- [x] One mount reward from the dungeon (the Veil Saber from the barrow; more
      from the later dungeons; guaranteed at the top grudge tier).

### M7 — Persistence (Nakama)
- [x] Account login wired to the real client (not just `nakama_test.tscn`).
- [ ] Character create/select: name, class, appearance.
- [x] Save/load: position, level, XP, inventory, equipment, quest state,
      currency, mounts. Server writes, never the client.
- [x] Reconnect restores the character where it logged out.

### M8 — Systems polish
- [x] Death, corpse run, resurrection sickness.
- [x] Group/party system + shared quest credit + the dungeon group check.
- [ ] Duels.
- [x] The three rune-slot choices. (Gear stats and tiers still open.)
- [ ] Minimap, XP bar, buff bar, chat channels.

### M9 — Content expansion (the loop keeps running here)
- [x] Zone two, zone three.
- [x] Second dungeon, the raid (with the boss mechanics engine, grudge tiers
      and seasons).
- [ ] The heroic raid (+40% health and damage, the Crown names two).
- [ ] Remaining quests to fill 1–20 (~8–10 hours of play).
- [x] Art upgrade pass whenever Blender is reachable: kit spec Phases 1–3, then
      class silhouettes from `docs/reference/`, class weapons, and every enemy
      (ten body variants and the vale wolf).
- [ ] Endgame props (bookshelf, lectern, brazier, throne, banners) and the
      season-two boss skins.

## When something genuinely can't be done in the sandbox

Do not stop the loop. Record it in BUILD_PROGRESS.md under "Waiting on Tyson"
and **keep building everything that doesn't depend on it**. The only real ones:

- `git push` — no credentials in the sandbox.
- Blender modelling — needs Blender open on his PC with the MCP server up.
- Live multiplayer test with real friends, and Docker/Nakama running for M7
  integration testing (M7 code can still be written and unit-checked).
