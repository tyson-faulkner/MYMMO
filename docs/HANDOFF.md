# Ironveil (MyMMO) — Handoff

Read this first in any new session. Last updated 2026-09-11.

**One-line status:** Setup is fully done and verified. Design doc is locked (v0.1). Combat foundation (health/damage) is coded and working. Art kit for the world is not started yet (Phase 1 of 3). Nakama backend exists but isn't wired into gameplay — multiplayer today is host/join only, nothing saves.

---

## 1. What this project is

A small-scale MMO called **Ironveil**, built solo for a group of 5-10 friends. Visually it copies World of Warcraft's Stormwind style; the story is Game-of-Thrones political (a dead king, rival houses, no cosmic evil). Full pitch, world, classes, progression, gear, combat, and art rules are locked in `docs/ironveil-design.md` — read that before proposing anything that touches game design, it is the source of truth and should not be re-litigated casually.

Quick facts from that doc (see the file for the reasoning behind each):
- No playable races — one body, one skeleton. Class + gear is your identity.
- 4 classes = 1 full party: **Valkyr** (tank), **Bard** (healer), **Necromancer** (ranged), **Tinker** (ranged).
- Level cap 20. 7 abilities/class + 3 gear-slot rune choices (WoW Season-of-Discovery style).
- Tab-target combat (chosen over action combat — far cheaper over a network).
- Dungeons (5, works with 4), Raid (5, maybe 10), Heroic raid. One scaling system, not three.
- 3 mounts total. Duel-only PvP for v1. Resurrection-sickness style death penalty.
- First playable target: **one zone, four classes, one dungeon** — everything else is v2.
- Approved visual reference art (final direction, do not deviate) lives in `docs/reference/`: 4 character concepts, a gear/weapon sheet, and 4 environment references (tavern, street, town square, material bible).

## 2. Where things live (read this before touching paths)

**Gotcha:** Tyson's real, visible desktop is `C:\Users\tyson\OneDrive\Desktop` — OneDrive has taken over Desktop/Documents/Pictures. `C:\Users\tyson\Desktop` still exists on disk but is an invisible husk he never sees. Anything meant to be visible to him (shortcuts, etc.) must go under the OneDrive path.

The project itself is **not** in OneDrive on purpose — do not move it there. Syncing a git repo plus Godot's import cache risks corruption and eats his OneDrive quota.

```
C:\Users\tyson\Desktop\MyMMO/       <- the actual project (git repo root)
├── godot-project/                 Game client — Godot 4.7.2, from devmoreir4/godot-3d-multiplayer-template
├── nakama-server/                 Full heroiclabs/nakama source clone (only its docker-compose.yml is actually used)
├── blender-source/                Raw .blend files (source of truth for 3D art) — currently empty
├── docs/
│   ├── ironveil-design.md       Locked design doc (source of truth, see section 1)
│   ├── ironveil-kit-spec.md     Modular building-kit spec + build order (section 5 below)
│   ├── reference/                 Approved final visual reference images + README
│   └── HANDOFF.md                 This file
├── Claude outputs/                Scratch screenshots Claude has produced (e.g. first working build)
└── README.md                      Short project overview
```

GitHub: `https://github.com/tyson-faulkner/MYMMO`, branch `main`, origin tracking is set up.
**Tyson pushes from his own PowerShell** — the sandbox Claude runs in has no GitHub credentials, so Claude can commit locally but cannot push.

## 3. What's installed and verified working (as of 2026-09-08/09)

- **Git** repo at the path above, identity Tyson Faulkner / tyson_faulkner@outlook.com (repo-local config).
- **Docker Desktop** + `docker compose up` inside `nakama-server/` brings up cockroachdb + nakama + prometheus ("Startup done"). Nakama API on port 7350, console on 7351. Has to be running in its own PowerShell window whenever Nakama is needed.
- **Godot 4.7.2** (portable, single .exe, matches version `4.7.2.stable.official.ed1daf0bf`) at `C:\Users\tyson\OneDrive\Desktop\Godot.exe`. A `MyMMO.lnk` shortcut on his desktop opens the project folder.
- `scenes/nakama_test.tscn` has been run and printed "Nakama connection SUCCESS" with a real session token — the full chain (Godot client -> Nakama -> CockroachDB) is confirmed to work, as a standalone test only (see Architecture below).
- Godot's own cache is correctly gitignored; the working tree stays clean.

## 4. Architecture — how multiplayer actually works right now

**Nakama is not wired into gameplay.** It only powers the standalone `scenes/nakama_test.tscn` login check. Nothing else in the game touches it yet.

The actual multiplayer today is Godot's built-in ENet networking, in `godot-project/scripts/autoload/network.gd`:
- `start_host()` creates an ENet server on port 8080 (`MAX_PLAYERS = 10`).
- `join_game()` connects a client to an IP address on that port; the main menu has nickname/skin/address fields.
- Player sync happens over RPCs (`_register_player`, `_sync_registered_player`).
- `sanitize_address()` rejects `:` or `/`, so a custom port can't currently be typed into the join field.

**What this means:** friends can already play together today with zero extra code — one hosts, others join by IP — but **nothing persists**. Characters, levels, gear all vanish when the host closes the game. Persistence (accounts, characters, inventory, progress) needs Nakama wired in before this is really "an MMO" — that is a known, not-yet-done next step, not a bug.

Good news for later: `start_host()` already checks `if DisplayServer.get_name() == "headless"` and skips creating a local player — the template already anticipates running as a headless dedicated server (Godot headless + Nakama on the same box, independent of any one player's PC).

## 5. Current build state

Everything below is verified by `godot-project/tests/zone_smoke_test.gd` —
**100 checks**, which must print `SMOKE TEST PASSED` before anything is
committed. Run it every session.

**Built and working:**

- **Classes.** All four (Valkyr, Bard, Necromancer, Tinker), pickable on the
  main menu, each with its own health, armour and resource bar — Valor, Verse,
  Soul, Charge. Valor builds by fighting instead of draining, as a tank's
  should. Level cap 20 on a curve tuned for roughly 8-10 hours.
- **Combat.** Tab-target. 28 abilities, seven per class, all data-driven:
  damage, area damage, heals, area heals, damage over time, drains, taunts,
  summons and snares. Necromancers raise levies, Tinkers bolt down turrets, and
  both fight for their owner. Every cast is decided by the server against real
  positions — range, cost, cooldown, class and level.
- **Enemies.** 11 types plus two bosses, with aggro, chase, leash, attack,
  death and respawn. Factions, so pets and placed enemies hunt each other.
  Bosses scale health and damage with how many players are present — one
  system, so "a 5-man that works with 4" needs no second tuning pass.
- **The world.** Thornfell: town square, gate and wall, farmland,
  hedgerows, river and bridge, a stone circle, and the barrow. The Deepbarrow
sits 500m underground behind a portal, with an entry hall, two boss
  rooms and a rock shell.
- **Quests.** A twelve-quest chain from the gates to the First King, handed out
  by seven NPCs with ! and ? markers. Kill, kill-by-tag, collect, talk and reach
  objectives all credit properly, on the server.
- **Parties.** `/invite <name>` in chat. Everyone nearby shares XP (gently
  split) and gets FULL quest credit, so grouping is never worse than soloing.
- **Death.** Ghosts, corpse runs, and Grave-Chill for releasing at a graveyard.
  Costs time, never progress.
- **Loot and currency.** Enemies roll loot tables and pay Sovereigns — the
  shared quest-and-dungeon currency.
- **Persistence.** Class, level, XP, position, quest log, currency and inventory
  save to Nakama and come back. **The game runs fine without it**: if Docker
  isn't up, saving quietly switches off and nothing else changes.
- **UI.** Health, resource, XP, level, Sovereigns, target frame, seven-slot
  action bar with cooldowns and tooltips, quest tracker, quest log on L, death
  panel.

**Not done yet:**

- **The art.** Everything visible is placeholder primitives tinted to the locked
  palette. Every one is a swap-in point: replacing it means loading a `.glb`
  instead of building a `BoxMesh`, and the layout doesn't move because the
  blockout is on the same 1m grid the kit uses. See section 6.
- Gear stats and the three rune slots per class (the eight-builds-per-class
  variety from the design doc).
- Vendors actually selling things; professions; mounts.
- The raid and heroic raid; zones two and three.
- Duels.
- **Untested against a live backend:** the Nakama round trip needs someone with
  Docker running to level up, quit, rejoin, and confirm the character returns.
  The sandbox can't reach Docker.

## 6. The art kit spec (building blocks for the world)

Full detail in `docs/ironveil-kit-spec.md`. Summary:

- Low-poly, WoW-Classic proportions; cream/tan stone, blue slate roofs, warm brown timber, gold accents; hand-painted texture look (baked shading, no normal maps yet).
- Every piece snaps to a **1-meter grid** so pieces click together like LEGO.
- Export target: one `.glb` per piece into `godot-project/assets/kit/`.
- **Build order — one piece at a time, approve each before starting the next, never redo an approved piece:**
  1. Phase 1 (structure): stone wall section, wall with window, wall with door + door, sloped roof + corner piece, timber-frame upper-story wall.
  2. Phase 2 (ground): cobblestone street tile, stone stair, low stone wall/ledge.
  3. Phase 3 (props): street lamp, market stall, round tree + planter box, fountain.
- Per-piece workflow: model in Blender (via Blender MCP, which auto-starts its server on port 9876 when Blender launches) -> simple UV unwrap -> flat color then painted shading -> render a preview for approval -> export `.glb`.
- Raw `.blend` files stay in `blender-source/`; only exported `.glb` files go into the Godot project.

**This has not been started.** It's the natural next milestone after combat once art production begins.

## 7. Claude's toolchain — what Claude can do by itself in its sandbox

(Full detail in project memory `claude_toolchain.md` — re-derive this early in a session doing real Godot work, since the sandbox is fresh each session.)

- The sandbox can download and run Godot 4.7.2 itself (a portable Linux binary, no sudo needed) to validate scripts/scenes without touching Tyson's live project — copy files into a scratch folder, strip the Nakama/Satori autoloads first (their assets aren't copied), build the script-class cache once with `--editor --quit`, then use `--check-only` for real parse errors.
- It can also actually **run and screenshot** the game headlessly (Xvfb + OpenGL compatibility renderer, no GPU needed), then move the PNG through a mounted folder to actually look at it.
- **Still cannot:** push to GitHub (no credentials in the sandbox — Tyson always runs `git push` himself), sculpt organic 3D characters, or judge whether the game is actually fun.

## 8. How to work with Tyson (read before explaining anything technical)

- **He is brand new to all of this** — git, Docker, terminals, game engines, all of it. Explain every term in plain English the first time it comes up. No assumed knowledge.
- **Keep answers short — cliff-notes, not essays.** He's asked for this explicitly.
- Claude **cannot type into his terminal or apps** — computer-use screen control has been tried and only offers "Deny", and even when granted, terminals/IDEs are click-only. Never promise to "drive" his terminal or Godot for him. Instead: give him copy-paste commands, then verify the result afterward independently (e.g. via the sandbox, or by asking).
- When giving him commands: **one line per step**, tell him to paste it, press Enter, and wait before the next one. Multi-line pastes have glued together in his PowerShell before and both commands failed.
- The sandbox is an isolated Linux VM — it cannot see Docker, cannot reach his localhost ports, and only sees the folders connected to the session. It can read/write those folders and run git there.

---

## Continuing in a new session

Say: **"Read docs/HANDOFF.md and continue from the current milestone."** That's enough context to pick up work without re-explaining the project. If something here turns out to be stale (a milestone finished, a decision changed), update this file rather than letting it drift.
