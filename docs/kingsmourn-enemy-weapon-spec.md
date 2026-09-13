# Kingsmourn — Enemy and Weapon Art Spec

Companion to `kingsmourn-character-spec.md`. That one covers the player classes
and the shared body; this one covers everything you fight and everything you
hold.

Decided with Tyson, 2026-09-11.

## The rule that makes this affordable

**Every human enemy is the base body with a different texture and one silhouette
tell.** No new meshes, no new rigs, no new animations. Eleven enemies then cost
eleven texture sets and a handful of small attachment props, not eleven
characters.

Two exceptions, both flagged as real modelling work: the **Vale Wolf** (the only
quadruped in the game) and the **Field Turret** (a prop, not a character).

The silhouette tell matters more than the texture. You should know what is
running at you before you can read any detail on it.

---

## The living

### Hedge Bandit — level 3
An unpaid levy soldier who still has the sword the realm gave him. Undyed brown
wool, a single scrap of old uniform still tied to one arm — the only sign he was
ever a soldier.

- **Tell:** hood up, no armour at all. The lightest outline in the game.
- **Palette:** undyed wool, dull brown leather, no metal.

### Bandit Cutthroat — level 4
The same man a few months later, with better things stolen.

- **Tell:** one mismatched pauldron, worn on the wrong shoulder.
- **Palette:** darker leather, one piece of dull looted steel.

### Stag Outrider — level 7
House of the White Stag, counting your carts and calling it a courtesy.

- **Tell:** tall riding boots and a green cloak. Reads as cavalry on foot.
- **Palette:** house green, white stag device on the tabard, oiled leather.

### Sunburst Serjeant — level 8
The other house, doing exactly the same thing in different colours.

- **Tell:** broad gold-trimmed pauldrons and a kettle helm. Visibly heavier than
  the Outrider — the two houses should differ in weight, not just hue.
- **Palette:** house blue, gold sword-and-sunburst, mail.

### Grave-Binder — level 10
A rogue necromancer, and the quest chain's revelation: both houses are paying
the same ones to raise the same dead.

- **Tell:** long hooded robe, hunched posture, bone fetishes hanging at the belt.
- **Palette:** dull violet, bone white, one gold house-seal purse — the purse is
  a story beat, so it should be visible.

---

## The dead

**Tone, decided:** classic undead. Skeletal, exposed bone, cold glowing eyes,
readable as undead from across a field.

**But keep the uniforms.** Each risen enemy wears the same clothing as its living
counterpart, in the same colours. The Risen Levy is bare bone in the exact
undyed wool the Hedge Bandit wears. It reads as undead instantly, and the moment
you get close it reads as *somebody's lad*, which is what the setting is about.

### Risen Levy — level 5
- **Tell:** the Hedge Bandit's exact outline, moving wrong.
- **Palette:** bone, undyed wool, cold blue-white eyes.

### Barrow Guardian — level 11
Older dead, still on duty.

- **Tell:** full helm and a round shield. Closed-up, anonymous.
- **Palette:** verdigris bronze, grey grave-wrappings, cold light in the visor.

### Barrow Wight — level 12
A dead lord rather than a dead soldier.

- **Tell:** taller than everything else on the surface, with a long tattered
  cloak that moves.
- **Palette:** near-black wrappings, tarnished silver, brighter cold light.

---

## Bosses

Bosses are the same body scaled up. Scale plus one unmistakable feature.

### Captain Reyne — level 12
- **Tell:** a stolen officer's coat that does not fit him, and a plumed helm.
- **Palette:** oxblood red, one good piece of plate among scavenged leather.
- **Scale:** ~1.3x.

### The First King — level 14
The thing every house in the realm will claim the moment they hear about it.

- **Tell:** **the crown.** It should be readable from the far side of the room,
  and it should be the brightest thing in the barrow. Everything else about him
  can be dark.
- **Palette:** gilded armour gone dull and green, deep shadow, one point of clean
  gold at the head.
- **Scale:** ~1.45x. The largest silhouette in the game.

---

## Real modelling work (not re-textures)

### Vale Wolf — level 2
The only quadruped. Lean, grey-brown, ribs showing — it came down with the cold
and stayed because it found bodies. Needs its own mesh, rig and a four-legged
run cycle.

### Field Turret
A brass-and-iron tripod with a cranked bolt thrower on top. A prop with a firing
animation, no skeleton needed.

---

## Weapons

Weapons hang off the existing hand and back sockets, so they are small separate
models. They matter more than their size suggests: at distance, weapon shape is
half of how you tell classes apart.

**Style:** oversized, per the art rule. A weapon that looks correctly sized looks
too small.

### Valkyr — spear and shield
Long spear, leaf-shaped head, dark steel with gold binding at the grip. Shield
is a tall kite, dark with a gold rim.
*Read:* the longest weapon in the game, held vertically at rest.

### Bard — blade and instrument
A short straight blade, almost a long knife, silver and worn. The **instrument**
is the real identifier and lives on the back socket: a stringed thing, storm-blue
lacquer, silver strings.
*Read:* the only class with something on its back that is not a pack.

### Necromancer — staff
Tall, dark wood, a bound bone or skull at the head, wrapped in violet cord.
*Read:* taller than the character, top-heavy.

### Tinker — bolt thrower
A cranked mechanical crossbow, brass and iron, deliberately over-engineered:
visible gears, a crank handle, a magazine. Warm orange accents.
*Read:* the bulkiest weapon, held two-handed at the hip rather than the shoulder.

### Enemy weapons
Reuse ruthlessly. Bandits and levies get the same plain sword; Stag Outriders get
a light spear; Sunburst Serjeants get sword and shield; Grave-Binders get a
smaller version of the Necromancer staff; barrow dead get the bronze versions of
the soldier weapons. Reyne gets an oversized version of the plain sword. The
First King gets nothing — his hands should be empty, because the crown is the
point.

---

## Build order

1. Risen Levy (proves the re-texture approach on the shared body)
2. Hedge Bandit, Bandit Cutthroat
3. The four class weapons — biggest readability gain per hour
4. Stag Outrider, Sunburst Serjeant
5. Barrow Guardian, Barrow Wight, Grave-Binder
6. Captain Reyne, The First King
7. Vale Wolf (its own mesh and rig — do it last, it is the expensive one)
8. Field Turret
