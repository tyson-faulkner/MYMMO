# Kingsmourn — World Structure

Three zones, three dungeons, one raid, level cap 20.

Decided with Tyson, 2026-09-11. This supersedes the single-zone plan, where
Thornhollow Vale covered levels 1-12 on its own.

---

## The shape

| | Content | Levels |
|---|---|---|
| Zone 1 | **Thornhollow Vale** | 1 – 8 |
| Dungeon 1 | **The Barrow of the First King** | 8 |
| Zone 2 | **Sablemarch** | 8 – 14 |
| Dungeon 2 | **The Drowned Redoubt** | 14 |
| Zone 3 | **Kingsmourn** | 14 – 20 |
| Dungeon 3 | **The Hall of Records** | 18 |
| Raid | **The Throne of Kingsmourn** | 20 |

Roughly eight to ten hours from 1 to 20, unchanged. Each zone is about a third
of that, and each ends on its dungeon.

---

## The arc

The three zones walk you inward: **the edge of the realm, the war, the throne.**

### Zone 1 — Thornhollow Vale (1-8)
A valley far enough from the capital that the war is only rumour, until it
isn't. Wolves, then unpaid soldiers turned bandit, then the dead those soldiers
used to be.

**What you learn:** both great houses are paying the same Grave-Binders to raise
the same dead. Neither is the good one.

**Ends with:** the Barrow, and the discovery that there is a *second* crown.

### Zone 2 — Sablemarch (8-14)
The borderland between the two houses, burnt to the ground by both. Trenches,
ruined farms, a river choked with the dead of the last war. Both armies are dug
in and neither will move first.

**Why it works:** every enemy here already exists — Stag Outriders, Sunburst
Serjeants, and risen levies, all in one place, now fighting each other as well
as you. The war stops being something people mention and becomes something you
are standing in.

**What you learn:** the crown you found is being used. Someone is marching the
barrow dead, and both houses think they are the one holding the leash.

**Ends with:** the Drowned Redoubt, a siege fort in flooded ground where both
armies' dead have been piling up for a year and have started getting up.

### Zone 3 — Kingsmourn (14-20)
The capital. The old king lies in state and has done for a year, because burying
him means settling the claim, and nobody will settle the claim. The city is
sunlit, prosperous, and about a week from tearing itself apart.

**Why it works:** a city is walls, roofs, doors and streets — it reuses the
building kit almost entirely. It is by far the cheapest zone to build and the
strongest place to end.

**What you learn:** who actually woke the First King, and why.

**Ends with:** the Hall of Records at 18, and the Throne at 20.

---

## The dungeons

### 1. The Barrow of the First King — level 8
Built. Entry hall, Captain Reyne, the descent, the tomb.

The moment: a dead king with a crown, in a realm whose whole war is about who
gets to wear one.

### 2. The Drowned Redoubt — level 14
A siege fort in flooded ground, half underwater, held by nobody. Both houses
threw men at it for a year and the water gave them all back.

Bosses: a Stag captain and a Sunburst captain who died fighting each other and
are still doing it — you fight them together, and they fight each other too. The
second boss is what the water has made of the pile.

### 3. The Hall of Records — level 18
Where the histories are kept, which is to say where the claim is decided. Both
houses have people inside forging and burning, and they have run into each other.

Thematically the keystone: Ilsa says early on that *histories decide claims, and
claims decide thrones*. This is where that stops being a line and becomes a
dungeon. It is also the Bard's zone, if any single place belongs to a class.

### Raid — The Throne of Kingsmourn — level 20
The throne room. The old king in state, both houses arrived at once, and the
First King walking in behind you wearing the older crown.

Heroic version rewards the unique mount, per the design doc.

---

## What this changes in the build

1. **Re-band the existing content.** The twelve Thornhollow quests currently
   require levels 1-11 and need compressing into 1-8. The Vale's enemies
   currently run level 2-12 and should top out around 8, with the 10-12 enemies
   (Grave-Binders, Barrow Wights) moving to the barrow approach and the dungeon.

2. **The barrow dungeon's gate drops to level 8** from 10.

3. **Two more zone scenes**, both built from `ZoneBuilder` the same way. Sablemarch
   needs new terrain art — burnt ground, ruins, trenches, flood. Kingsmourn needs
   almost none: it is the kit you already have, denser, plus a palace.

4. **Roughly 22 more quests** — ten for Sablemarch, twelve for Kingsmourn.

5. **New enemies, all on the shared body:** house infantry variants for the
   front, drowned dead for the Redoubt, city guard and house retainers for the
   capital. Only the raid needs anything genuinely new.

## Build order

Finish Thornhollow first. A zone that is actually good, all the way through, is
worth more than three that are half-built — and everything the second and third
zones need is proven by finishing the first.

1. Re-band Thornhollow and the Barrow to 1-8.
2. Wire the class and enemy models in. Get it *looking* finished.
3. Sablemarch: layout, enemies, ten quests.
4. The Drowned Redoubt.
5. Kingsmourn: layout, twelve quests.
6. The Hall of Records.
7. The Throne of Kingsmourn, then its heroic version and the mount.
