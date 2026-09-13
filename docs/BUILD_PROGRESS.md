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

- **Milestone:** M1-M7 done, parties and runes in. Also shipped: **gear** (53
  items across three tiers, five uniques), **mounts** (all ten from the mount
  spec, each with a way to get it), **zones two and three** (Sablemarch and
  Kingsmourn, with their four interiors, linked by the Marcher Road and King's
  Road portals), **23 graveyards**, each with a spirit healer, the **four
  class models** worn by the player with their weapons on the sockets, painted
  grass and marsh-mud ground, the Phase 3 props (fountain, stalls, lamps,
  trees, planters), and **every enemy modelled**: ten textured variants of the
  shared body plus the vale wolf, worn by all 36 mob types.
- **Next:** ability effect types and enemy cast bars, the boss mechanics
  engine, grudge bosses and seasons, the combat recorder, specs and rune
  moves, then the QoL pass (minimap, healer frames, chests, chronicle).
- **Loop status:** running
- **Last verified playable:** 2026-09-13, `tests/zone_smoke_test.gd`, 189/189 checks passing (on Tyson's PC, Godot 4.7.2)

## Verified against a live backend (2026-09-12)

The save format, its validation and its offline behaviour are covered by the
smoke test. The live round trip is covered by `tests/save_quit_check.tscn`, run
on Tyson's PC against the real Docker Nakama, one windowed process per phase:

- `-- --phase=write` hosts, changes the character, closes the window the way
  the OS does. `-- --phase=verify` logs back in and checks it came back, then
  restores whatever save existed before.
- `-- --phase=dead --flag-dir=<dir>` closes the window while Nakama is paused
  from outside (`docker pause nakama-server-nakama-1`) and must still exit
  inside the 3-second quit cap.

Last run: character came back (level, XP, position); dead-server quit exited
in 3.0s. Needs Nakama up and a desktop session, so it is not part of the smoke
test.

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
- 2026-09-11 — Kit textures are **generated by code**, not hand-painted:
  `blender-source/tools/km_textures.py` produces the seven shared materials as
  tileable 1024px PNGs with the painted shading baked into the pixels. They are
  reproducible, tweakable in one place, and guaranteed seamless — which is what
  lets every piece share a stone scale.
- 2026-09-11 — The kit build runs **headless**, not over the Blender MCP socket.
  `read_factory_settings()` tears the MCP addon down with the scene and killed
  the connection mid-build; `blender --background --python km_build.py` has no
  such dependency and is faster. Blender's GUI no longer needs to be open.
- 2026-09-11 — **+Y is the exterior face** of every wall piece. Dressed detail
  (sills, jambs, lintels, timber beams) projects along +Y only, so a wall run
  never ends up with its ornament indoors.
- 2026-09-11 — The plain wall section has **no quoins**. Corner stones up one
  edge land mid-run when sections are butted together; they belong on a
  dedicated corner piece, which the kit does not have yet.
- 2026-09-11 — **Ground pieces invert the sit-on-the-floor rule**: a street tile
  has its walking surface at y=0 and its slab below. Giving it a base at y=0
  instead sinks every wall in the scene by the slab's thickness.
- 2026-09-11 — A **ridge cap** was added to the roof beyond the spec's list. Two
  opposing slopes leave an open seam along the top, so a roof made only of
  slope panels has a hole in it.
- 2026-09-11 — The **door leaf is its own node** inside the wall's `.glb`, with
  its origin on the hinge edge, so Godot can swing it by rotating that node.
- 2026-09-11 — Textures live in `blender-source/textures/` and are packed into
  each `.glb`, so `godot-project/assets/kit/` holds only game-ready `.glb`
  files. Godot unpacks its own copies on import; those follow the repo's
  existing convention of committing extracted textures and `.import` files.
- 2026-09-11 — Bodies are **generated from swept rings**, not sculpted and not
  a downloaded CC0 base. A premade base was allowed, but generating it keeps
  the proportions as named constants ("7 heads" is a number, not something
  eyeballed), puts the edge loops exactly where the spec wants them, and gives
  cylindrical UVs for free. It is also original art, which the kit spec
  requires of everything else.
- 2026-09-11 — Limbs are **separate tubes buried in the torso**, not stitched
  into one continuous surface. Each limb weights cleanly to its own bone and
  the intersection hides inside the silhouette; a truly stitched shoulder needs
  pole-heavy topology that is not worth it at 800 triangles. This is the one
  place the body is not a single surface, and it is deliberate.
- 2026-09-11 — Skin weights are **explicit inverse-distance to the bone
  segments**, not Blender's automatic heat weights. Heat weighting solves over
  a connected surface, and this body deliberately is not one, so islands it
  could not reach were weighted to whatever bone won. Crude, but local and
  deterministic.
- 2026-09-11 — Classes are **armour merged into the body's own mesh**, one
  skinned mesh per character, rather than separate garment objects. Simpler to
  weight, simpler to export, and one draw call per character.
- 2026-09-11 — The four equipment sockets are **real bones** (`HeadAttach`,
  `LeftHandAttach`, `RightHandAttach`, `BackAttach`), so a `BoneAttachment3D`
  binds by name and the existing equipment code keeps working. The template
  robot binds to `hand.L` / `spine.002` / `Head`; a class scene will bind to
  these instead.
- 2026-09-11 — Where the spec text and the reference sheet disagree, the
  **reference wins**. The spec gives the Bard "storm blues and silver"; the
  approved sheet is crimson and gold with blue panels. `docs/reference/` is
  named as the approved visual direction, so the build follows it and carries
  the storm-blue on the coat panel, drum rune and collar.
- 2026-09-12 — When the cloud package (`kingsmourn-pending.zip`) and the desktop
  disagreed on `zone_builder.gd`, the **desktop's copy won** and the package's
  additions were merged in by hand: the six `ZoneLayouts` cases and the widened
  layout enum came from the package; the MultiMesh cobble paving and the kit
  paths `stair_stone_2m.glb` / `wall_low_2m.glb` stayed as they were on disk,
  because those are the files that actually exist in `assets/kit/` — the
  package's older `stair_stone.glb` / `wall_low_2x1.glb` names point at nothing.
  The extracted textures and `.import` files for those three pieces, which the
  Blender session had left untracked, were committed alongside, per the
  convention already recorded above.
- 2026-09-12 — **Nakama HTTP requests run unthreaded** (`use_threads = false`
  on the client adapter, set in `account.gd`, not by editing the addon). A
  threaded `HTTPRequest` reads in blocking mode on a worker thread and its
  timeout cancels by joining that thread, so a server that accepts the
  connection but never answers froze the entire game — found by pausing the
  Nakama container during a save. Unthreaded requests are polled each frame
  and time out cleanly. The cost is a little main-thread polling on a handful
  of small requests.
- 2026-09-12 — **Quitting is owned by `level.gd`** (`save_and_quit()`), not by
  each `PersistenceManager`. Closing the window and both Quit buttons all route
  through it; the Quit buttons previously called `get_tree().quit()` directly,
  which never raises a close request, so they skipped the save entirely.
- 2026-09-13 — **The class model is turned 180° inside `Body`**, not the rest of
  the character. The exported models face -Z; movement facing and the pickup
  area were laid out for the template robot's +Z. One number instead of a bug
  hunt, and a smoke check fails if a model ever faces backwards.
- 2026-09-13 — **Equipment sockets are external-skeleton `BoneAttachment3D`s on
  `Body`**, not children of the model's skeleton. Changing class re-points three
  nodes at the new skeleton instead of re-parenting every hat and weapon.
- 2026-09-13 — **Skin colour no longer changes how a character looks.** The class
  models carry their own painted textures. `set_player_skin()` still accepts and
  remembers the menu's choice, so nothing that sends one breaks.
- 2026-09-13 — **Clip looping is set in code** (`Body.LOOPING_CLIPS`), not in the
  `.glb` import settings. The export marks every clip play-once, and a fix in
  the import dock would be silently undone by the next re-export from Blender.
- 2026-09-13 — **Ground textures tile at 4m in world space** (triplanar), not the
  kit's 2m: a ground plate is hundreds of metres across and mostly seen from far
  off. Each is normalised so its average IS its palette colour, which lets a
  darker plate of the same ground tint the one texture rather than need its own.

- 2026-09-13 — **Enemy models live in `MobDatabase.MODELS`, not per mob
  entry.** One table says which of the eleven models each of the 36 mob ids
  wears, so a zone-three retainer reusing the Stag Outrider is one line, and
  a mob with no line stays a tinted capsule rather than failing. Constructs
  (turret, the Ledger) deliberately have no line.
- 2026-09-13 — **Weapon visuals key on class, not item id.** Every tier of a
  class's weapon is the same model until tiers get their own art, so
  `player.gd` maps the worn gear's `class_restriction` to one node per slot.
  Adding a tier model later means a second table, not a rewrite.
- 2026-09-13 — **Weapon transforms are measured, not reasoned.** The socket
  bones at Idle are ~25 degrees off any axis, so the exact bases from a live
  probe (`tests/character_shot.gd` prints them) go into `player.tscn` — as
  rows, because that is how Godot serialises a Basis.

## Log

### 2026-09-13 — Enemy models: ten body variants and the vale wolf

- **Changed:** `blender-source/tools/km_enemies.py` builds the spec's ten human enemies as textures plus one silhouette tell each on the shared body and skeleton (so the class clips play unchanged); `km_wolf.py` is the one quadruped, with its own 14-bone rig and its own Idle/Run/Attack1. All eleven export to `assets/enemies/`. `MobDatabase.MODELS` maps all 36 mob ids onto them (zones two and three reuse by house and kind); `Mob` instantiates the model under `Body`, hides the capsule, loops Idle/Run from observed movement and plays Attack1 on a swing. `km_anim.make_action` takes a `rest` pose so non-human rigs can use it.
- **Test:** smoke 189/189 with 6 new checks (files exist, every model rigged with the three clips, eleven distinct models, every human mob dressed, wolf has a quadruped skeleton, 70 spawned mobs dressed / 0 capsules). In-game shots of six enemies looked at: models face the player, Idle plays.
- **Surprising:** the wolf's fur texture reads as wood grain at distance; it needs a real clumped-fur generator later. Also `--check-only`-style parse errors ("cannot infer type") in the screenshot script quietly become a 10-minute idle window, not a crash: watch the `.err` log, not the exit code.

### 2026-09-13 — Class weapons on the sockets

- **Changed:** eight models in `assets/weapons/` (spear + kite shield, blade + lute, staff + skull focus, bolt thrower + toolkit; 80–288 tris) from `blender-source/tools/km_weapons.py`. `player.tscn` gains a `RightHandAttach` socket and the eight hidden instances; `player.gd` shows a class's weapon and off-hand from the *gear* it wears (any tier maps to the one model), on equip, unequip, spawn and save-restore, instead of the template's item ids.
- **Test:** smoke 183/183 with 2 new checks (all eight models have geometry; each class's gear lights exactly its two nodes, unarmed lights none). Live probe prints every weapon's up as (0,1,0). Front and back shots of all four classes looked at.
- **Surprising:** `Transform3D(...)` in a `.tscn` is **row-major** — I wrote rotations as columns twice and got their inverses (spear flat, lute upside down). Also the rig's "Left" bones are on the character's anatomical right; the weapon follows the attack clip's arm, so it is fine, but do not trust the names.

### 2026-09-13 — Kit Phase 3: lamp, market stall, tree, planter, fountain

- **Changed:** five props built headlessly (`piece_09`–`piece_12`, plus `11b` planter), 144–488 tris each, with new painted textures (foliage, water, striped awning, lamp glow). ZoneBuilder swaps its placeholder boxes for them via `fountain()`, `lamp()`, `tree()`, `planter()` and `ZoneLayouts.stall()`; kit pieces gained `scale` (the capital's fountain is the same piece at 1.4x) and an explicit `collision` box, so trees collide at the trunk. Lamps and planters were added to the vale square and market ward.
- **Test:** kit check 15/15; smoke 181/181 with 4 new checks (all five pieces real, 2 fountains/8 lamps/2 planters/14 trees/8 stalls placed, tree collision < 1.5m wide). Tour shots re-taken and looked at.
- **Surprising:** the fountain had to sit at y=0.25, the square slab's top, not 0 — the placeholder boxes had been sunk into the slab and nobody noticed.

### 2026-09-13 — Mud tiling repeat fixed

- **Changed:** ground plates now use `assets/shaders/ground.gdshader`, a world-space triplanar shader; ZoneBuilder gives every textured plate its own UV offset and rotation, seeded from the plate's position so all clients agree. Inside a plate the texture is also read a second time, rotated and rescaled, and blended in by ~20m noise blobs — the offset alone can't help a single 280m plate repeat against itself.
- **Test:** smoke 177/177; two new checks confirm every grass and mud plate reads from a distinct offset/angle. Re-shot `ground_sablemarch_mud.png`: the pale-pool lattice is gone.
- **Surprising:** the request said "per plate", but the visible grid was within one plate, not between plates — hence the second read.

### 2026-09-13 — Skin colour picker removed from the menu

- **Changed:** the "Player Skin" row is gone from `main_menu_ui.tscn`; the menu's host/join signals no longer carry a skin, and `level.gd` passes an empty one to `Network`, which lands on its default. Appearance customisation is cut from v1 and the class models bring their own textures.
- **Test:** smoke 175/175, new check: the menu scene has no `SkinInput`. Screenshot harnesses updated to the new `_on_host_pressed(nickname, class_id)`.
- **Surprising:** nothing. `Network.player_info` still has a skin slot and `Character.SkinColor` still exists — dead but harmless, left for a later sweep rather than touching the wire format now.

### 2026-09-13 — Template hats and weapons removed

- **Changed:** fedora, headphones, pirate/sheriff/wizard hats, sombrero, sword, big sword and axe are gone from `ItemDatabase`, `player.tscn` (nodes, ext_resources and 9 synced `visible` properties), the level's item spawner and `assets/items/`; 49 files deleted. The backpack stays for its four bag slots.
- **Test:** smoke 175/175, two new checks — none of the ids resolve, and nothing but the camera remote hangs on the head or hand sockets.
- **Surprising:** nothing. The inventory UI still draws an empty hat slot; it is harmless and goes when the equipment paper-doll replaces that panel.

### 2026-09-13 — The classes wear their own models, and the ground is painted

**Characters.** `player.tscn` no longer instances the template robot. `Body`
wears `char_valkyr.glb` by default and swaps to the chosen class's model
whenever `apply_class()` runs — at spawn, when the menu's class arrives, and
when a save is restored. All four share one skeleton and eight clips, so a swap
is the model node plus three socket re-points. The scene went from 4,930 lines
to 258: the robot's skin, materials, meshes and ~4,300 lines of baked animation
are gone.

- The node was renamed `GodotRobot3D` -> `Body`, including every synchronised
  property path; a new smoke check resolves each of them against the real scene
  so a stale path can't come back quietly.
- Idle, Run, Sprint and Fall loop. A model swapped mid-attack reports the attack
  finished, so the character can't get stuck unable to swing again.
- First person collapses the head bone; the camera sits at 1.68m, 0.17m forward.
- The nickname clears the tallest part of the model (the Valkyr's halo).

**Ground.** `km_textures.py` gained `grass` and `marsh_mud`, generated in Blender
into `blender-source/textures/` and copied to
`godot-project/assets/textures/ground/`. ZoneBuilder paints any piece carrying
`{texture: ...}`: the vale's plates, farmland and barrow mound are grass;
Sablemarch's plates, field camp and redoubt approach are mud; Kingsmourn's
outskirts are grass.

**Verified:** smoke test 171/171 (7 new checks: every class swaps on and back,
clips loop, sockets bind, models face forward, no robot left in the scene, every
synced path resolves, both grounds painted). `character_check.gd` passes all
five rigged models. Screenshots from the running game via
`tests/character_shot.tscn`: `Claude outputs/char_*.png`, `ground_*.png`.

**Not done:** the template's hats, swords and backpack keep transforms fitted to
the robot's bones, so one equipped would sit wrong on a class body — they are
template items rather than Kingsmourn gear, and none is equipped by default. The
mud's 4m repeat is visible from low angles.

### 2026-09-12 — Saving on quit actually saves, and a dead server can't freeze the game

Quitting logged a script error in `persistence_manager.gd` and, it turned out,
never saved at all.

- **Why it failed.** The save hung off `NOTIFICATION_PREDELETE`, which fires
  after the node has left the tree, so `multiplayer` was null. And even from
  `WM_CLOSE_REQUEST`, the Nakama write was an `await` nobody waited for: the
  process exited mid-request. The menu Quit buttons skipped it entirely.
- **Fix.** `level.gd` turns off auto-accept quit. Closing the window or either
  Quit button calls `save_and_quit()`, which awaits
  `PersistenceManager.save_now()` against a 3-second cap, then quits. The
  PREDELETE/close hooks in `PersistenceManager` are gone.
- **Found on the way.** With Nakama paused, the quit hung forever — not at the
  cap, forever, and the rest of the game with it. Threaded `HTTPRequest`
  deadlocks on a server that never replies (see decisions). Fixed by running
  the Nakama adapter unthreaded, which also removes the same freeze from
  autosaves mid-session.
- **Verified** with the new `tests/save_quit_check.tscn` (see "Verified
  against a live backend"): quit save written in ~200ms; level 13 / 777 XP /
  field-camp position all came back on relog; dead-server quit exited after
  3004ms. Smoke test 164/164.

### 2026-09-12 — Cloud package applied: zones two and three, mounts, gear data, 23 graveyards, `deploy/`

Everything written in the cloud while the desktop was unreachable is now in the
repo, applied per `APPLY_THESE.md` (that file, `pending/`, the zip and the stale
`_to_delete/` lock files are gone).

- **World.** Sablemarch (x~600) and Kingsmourn (x~1200) with their four
  interiors (redoubt, royal crypt, hall of records, throne), all as
  `ZoneLayouts` data; the Marcher Road and King's Road portals link the three
  regions, six portals lead underground, gated 8/14/16/18/20. The barrow finally
  has lights.
- **Data.** 34 quests, 36 enemies incl. the Hall of Records and raid bosses,
  16 NPCs, 53 gear items across three tiers with five uniques; three new
  autoloads (`GearDatabase`, `MountDatabase`, `NpcDatabase`), registered with
  Gear/Mount ahead of `ItemDatabase` because it delegates to them.
- **Mounts.** All ten from the mount spec exist and each has a source; a
  `MountController` node now sits on the player next to `RuneLoadout`. Riding
  is 1.5-1.8x, damage dismounts, no riding below y=-100.
- **Death.** Ghosts at 1.5x; 23 graveyards each with a spirit healer; the
  smoke test proves no surface point is more than ~15s of ghost-running away.
- **Ops.** `deploy/` (compose file, systemd unit, setup/deploy/backup scripts).
- **Verified:** class cache rebuilt, `--check-only` clean on the hand-merged
  `zone_builder.gd`, smoke test **164/164, SMOKE TEST PASSED**, zero script
  errors. The only stderr is the usual single-peer RPC noise.

Still missing, per the package: the mount list UI and mount models, boss
abilities from the endgame spec, the equipment paper-doll UI, wiring the
`char_*.glb` models into `player.tscn`, Phase 3 kit props, and the Nakama
persistence round-trip against a live Docker.

### 2026-09-11 — Characters: one body, one skeleton, four classes, eight clips

The priority banner asked for classes that look like the reference art rather
than grey blobs. They exist, they are rigged, and they animate.

**Assets** (`godot-project/assets/characters/`), all on the same 26-bone
skeleton with the same 8 animation clips:

| Asset | Tris | What reads at distance |
|---|---|---|
| `char_base_rigged` | 844 | the shared body — the source for everything below |
| `char_valkyr` | 2,566 | wings, heavy pauldrons, halo; blackened plate and gold |
| `char_necromancer` | 2,190 | hood with teal eyes, bone ribcage, torn hem |
| `char_tinker` | 1,712 | the tool pack on his back, one oversized gauntlet |
| `char_bard` | 1,848 | fur mantle, wide coat hem, drum on his back |

`char_base_body` is also exported, unrigged, as the source mesh.

**How it works.** `km_char.py` builds bodies out of swept rings rather than
boxes: a ring *is* an edge loop, so loops land exactly at shoulder, elbow, hip
and knee, and each ring carries its own parametric coordinate, which gives
correct cylindrical UVs without unwrapping an organic shape. `km_rig.py` holds
the one shared skeleton. `km_armour.py` holds the pieces classes reuse —
pauldron, skirt, collar, hood, ragged hem, wing, mantle, pack, beard, halo.
`km_anim.py` holds the clip set. A class is armour added into the same mesh as
the body, skinned by the same weighting, so a pauldron follows the shoulder
with no extra rigging.

**Proportions:** 1.80m, 7 heads, shoulders 0.45m across, arm span 1.82m.

**What the test renders caught** — each fixed before the piece was committed:
`Matrix.Rotation` pivots on the world origin, not a bone's head, so the first
pose test flung the arms across the scene; automatic heat weights cannot solve
a body whose limbs are separate tubes, and a hand flew off to the hip;
`export_apply=True` bakes the rest pose in and throws the skin binding away;
the Necromancer's ribs sat inside his robe where nothing could see them; the
Bard and Tinker were bald and beardless and read as the same head twice; and
`new_scene()` did not purge actions, so four of five characters shipped with
clips named `Idle.001` that the game could never find.

**Verification:** `godot-project/tests/character_check.gd` loads every rigged
`.glb` in Godot and checks the skeleton, every humanoid bone, all four
equipment socket bones, that the mesh is actually bound with weights, the
triangle budget, the height, and that all eight clips are present by name.

```
godot --headless --path godot-project --script res://tests/character_check.gd
```

**Not done:** enemy texture variants (step 7 of the character spec) and the
`vale_wolf` quadruped. Weapons are not modelled yet — the sockets exist and
are named, but there is no spear, staff, blade or bolt thrower to hang on
them. `player.tscn` still instances the template robot; swapping it to a class
scene is a gameplay change, not an art one, and was left alone.

### 2026-09-11 — The modular kit, Phases 1 and 2: ten pieces you can build a street from

Built the kit spec's Phase 1 (structure) and Phase 2 (ground) end to end, one
piece at a time, each rendered and checked before the next.

**Pieces** (all in `godot-project/assets/kit/`, heaviest is 276 tris):

| Piece | Size | Notes |
|---|---|---|
| `wall_stone_2x3` | 2 x 3 x 0.3m | plinth with a chamfered cap |
| `wall_stone_window_2x3` | 2 x 3m | sill, jambs, lintel, keystone, leaded glass |
| `wall_stone_door_2x3` | 2 x 3m | + `door_leaf` as a separate hinged node |
| `roof_slate_slope_2m` | 2m of ridge | 45 degrees, 0.35m eave, timber fascia |
| `roof_slate_ridge_2m` | 2m | caps the seam between two slopes |
| `roof_slate_corner` | 2 x 2m | hip corner, matches the slope exactly |
| `wall_timber_2x3` | 2 x 3m | plaster + beams, jetties 0.25m on corbels |
| `street_cobble_2x2` | 2 x 2m | tileable, walking surface at y=0 |
| `stair_stone_2m` | 2m wide | 5 steps, 1m rise over 1.5m |
| `wall_low_2m` | 2 x 0.9m | coping oversails 5cm each side |

**The pipeline**, in `blender-source/tools/`:

- `km_textures.py` — the seven shared hand-painted textures, generated.
- `km_kit.py` — mesh helpers, world-scale box UV mapping, shared materials,
  the sunlit preview rig, `.glb` export.
- `km_build.py` — headless driver. `blender --background --python km_build.py
  -- piece_01_wall` builds, renders, saves the `.blend` and exports the `.glb`.
- One `piece_NN_*.py` per piece.

Everything is box-UV mapped at world scale, so a texture never changes density
between pieces and the stonework runs unbroken across a join. Every repeating
piece's preview renders three copies side by side; that is the check that
matters for a modular kit, and it caught nothing only because it was there from
the first piece.

**What the previews caught** (each fixed before the piece was committed): quoins
that would land mid-wall in a run; window dressing built on the wrong face and
therefore invisible from outside; a five-voussoir arch that read as noise at
this scale; iron reading navy because dark surfaces drink sky ambient; a door
barely two planks wide; roof shingles stretched by 1/cos(45) because sloped
faces were being projected down an axis; timber braces spiking through the
interior plaster; a cobble street washed out to near-white and z-fighting the
preview's ground plane.

**Verification:** `godot-project/tests/kit_asset_check.gd` loads every `.glb` in
Godot and checks it has geometry, an albedo texture, a sane triangle count,
sits on its origin and lands on the 1m grid. All ten pass. Run it with:

```
godot --headless --path godot-project --script res://tests/kit_asset_check.gd
```

**Not done:** Phase 3 (props — lamp, stall, tree, fountain) is untouched, and
`CLAUDE.md` was changed mid-session to make characters the priority over props,
so Phase 3 should wait on that call. The kit also has no wall *corner* piece,
which a building needs and which the spec never listed.

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
