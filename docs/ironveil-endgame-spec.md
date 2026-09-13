# Ironveil — The Archive & The Broken Throne (mechanics)

Fight design for dungeon 3 and the raid. Mechanics only, no backstory — the
players have said they skip the text. Every enemy named here already exists in
`mob_database.gd`; this document says what they *do*.

Party sizes per the design doc: dungeon 5 (works with 4), raid 5 (maybe 10),
one scaling system. Health numbers in the database are for 5.

---

## The Archive — level 18, 5 players

Layout: one long reading hall (trash), a side scriptorium (boss 1), the vault
stair (trash), the vault (boss 2). Reuses the building kit: interior walls,
timber upper story, doors. New props: bookshelf, lectern, brazier — three
pieces, all boxes.

Trash: `record_burner` (Sunburst) and `record_forger` (Stag) in mixed packs
of 3-4. They fight each other as well as you — same rule as the Hold
captains. Pull them apart from each other and they focus you; leave them and
they thin themselves out but the braziers spread (below).

### Boss 1 — Master Kell of the Records
Binder-type caster, 1700 HP.
- **Bind** (every 20s): roots the tank for 4s. Bard cleanses it or the tank
  eats 4s of Kell walking away from him.
- **Call the Shelves** (at 70% and 35%): two `record_burner` + two
  `record_forger` spawn from the stacks and immediately fight each other.
  Whoever wins turns on the party. Kill order: pick a side and kill the *other*
  side first so the survivors are the ones you chose.
- **Burn the Page** (every 12s): targets a random non-tank, 2s cast, big
  fire hit. Interruptible — Tinker's job.

Mechanically the lesson is "manage two factions at once", which the Hold
taught in the open and this tests indoors.

### Boss 2 — The Bound Ledger
Construct, 2200 HP, slow. The vault has four braziers, one per corner.
- **Ink Pool**: every 8s drops a pool under a random player. Pools persist.
  Standing in one slows you 50% and stacks a damage-over-time.
- **Turn the Page** (every 30s): the Ledger slams; every pool on the floor
  fires a bolt at the nearest player. More pools, more bolts. This is the
  enrage — the room fills and the party dies at around the 3-minute mark
  unless they clear pools.
- **Braziers**: a lit brazier burns away every pool within 6m when a player
  clicks it (3s channel). Then it's out for 25s. Four braziers, so the party
  rotates corners. The Bard should be calling which brazier is next.
- **Loot drop for the mount**: `Wraithcat` (see mount spec) at 5%.

Kill it before the floor fills. DPS check for a party in Marcher gear with a
few Sovereign pieces.

---

## The Broken Throne — level 20, 5-10 players

Layout: the throne room, one big hall. The building kit's biggest room plus
banners. One new prop: the throne.

Three bosses, no trash worth mentioning between them (a few
`stag_guard`/`sunburst_guard` at the doors).

### Boss 1 — Lord Ashcombe (Stag) and Lady Severin (Sunburst), together
Both 3200 HP. Same trick as the Hold but they are alive and *smart*: they
fight each other until you touch one, then both turn on you.
- **Shared health rule**: whichever one is lower gets healed by the other's
  retainers unless both are within 15% of each other. So you split damage and
  kill them together.
- **Ashcombe — Charge**: every 15s charges the furthest player, knocking them
  back. Stand near walls at your peril.
- **Severin — Sun Lance**: every 10s a line attack through the tank. Nobody
  stands behind the tank.
- **At 30% either**: both call their guards, 3 each. Necromancer's turn.

### Boss 2 — The First King, Crowned
5000 HP, slow, hits hard. The whole raid.
- **The Crown** (every 25s): he names one player. For 8s every hit on the
  King instead heals him for half the damage — unless the named player is
  standing on the throne dais. Get the named player up there, then unload.
- **Heralds** (at 75/50/25%): `first_king_herald` ×2 walk in through the
  doors. Tank picks them up; DPS kill them fast — each alive herald adds
  10% damage to the King.
- **Ironhold** (enrage at 15%): he stops using mechanics and just hits
  harder every 5s. Burn.

Heroic version: same fights, +40% health and damage, the Crown names two
players, and both must stand on the dais. Rewards `Ironhide`, the unique
mount, at 100% from the heroic King.

---

## What this needs built

Code, in order:
1. A `boss_ability` component: timer-driven abilities with a target rule
   (tank / random / furthest / line). One script, data-driven, every boss
   uses it.
2. Ground effects: `Ink Pool` is a persistent Area3D with a slow + DoT.
   Reused for anything else that leaves a puddle.
3. A `clickable` interactable: brazier and dais. The NPC dialogue click
   already does this — generalise it.
4. Add spawning (`Call the Shelves`, `Heralds`) via the existing
   `_spawner.spawn(data)` path.
5. Faction-vs-faction aggro, already partly there from the Hold captains.

Art: bookshelf, lectern, brazier, throne, banners. Five props, all simple.
