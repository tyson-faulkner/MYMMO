# Kingsmourn — Gear

Decided with Tyson, 2026-09-11. Built and tested the same day.

## Eleven slots

Head, Chest, Legs, Hands, Feet, Weapon, Off-hand, Ring, Ring, Trinket, Cloak.

## Three stats

- **Armour** — a flat amount off every hit you take.
- **Power** — a flat amount onto every hit and heal you deal.
- **Stamina** — five health each.

Flat, not percentages, so an item is worth exactly what its tooltip says at
every level and two items are trivially comparable.

## The rule that makes questing matter

**Rings, trinkets and cloaks belong to the open world. Armour and weapons belong
to dungeons.** A dungeon or raid loot table never contains a ring, trinket or
cloak, and a quest never rewards armour or a weapon. World gear therefore
cannot be outscaled by dungeon gear, because there is nothing to outscale it
with — and rings and trinkets lean into Power, so a world drop can genuinely be
the best thing you own.

Two tests enforce this in both directions. It cannot be broken by accident.

## Three tiers

| Tier | Name | Levels | Where from |
|---|---|---|---|
| Starter | Levy | 1–8 | Issued at creation; Odda sells replacements; Barrow drops |
| Mid | Marcher | 8–14 | Sablemarch quests and world drops; Redoubt drops; Wrenn sells some |
| Cap | Sovereign | 14–20 | Kingsmourn quests; Hall of Records and raid drops |

Everyone starts wearing the Levy chest, legs, feet and their class weapon.
Real numbers from the first swing.

## Class restrictions

**Armour fits everyone.** One body, one skeleton — the design doc's rule — so
there is no plate/cloth split. Classes differ by their abilities, not their
wardrobe.

**Weapons are class-locked**, purely for silhouette. A Valkyr with a staff
breaks the art rule. Spear / Blade / Staff / Bolt Thrower, with a matching
off-hand: Kite Shield / Lute / Skull Focus / Toolkit.

## Uniques

The flavour layer the design doc asked for: world items that do something no
raid drop does. All world-owned.

| Item | Slot | Effect |
|---|---|---|
| Wolfsbane Ring | Ring | Beasts take +20% |
| Halvard's Old Cloak | Cloak | (stats only, quest reward) |
| Seal of Two Houses | Ring | Soldiers of either house take +20% |
| Ferryman's Coin | Trinket | Grave-Chill lasts half as long |
| The First King's Signet | Ring | The dead take +20% |

## Vendors

Sovereigns finally buy something. Odda sells the Levy set for anyone who lost
theirs. Selle sells provisions. Sister Wrenn sells some Marcher pieces at the
front. Buying is checked on the server: right NPC, standing there, can afford
it.

## What is NOT built yet

The paper-doll — an eleven-slot equipment screen. The data, the equip/unequip
logic, the stat flow, the loot, the vendors and the save/load are all in and
tested. The screen you click on needs the desktop, because it needs to be
looked at.
