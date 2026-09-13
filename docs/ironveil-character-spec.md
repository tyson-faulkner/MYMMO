# Ironveil — Character Build Spec

The kit spec covers buildings. This covers the people. Same discipline: one
piece at a time, approved before the next, never redo an approved piece.

## The one rule that matters most

**Readability by silhouette.** The reason World of Warcraft's art works is that
you can identify any character from its outline alone, at distance, in a fight.
That is the target, and it is worth more than detail.

Concretely, from the design doc:

- **3,000-8,000 triangles** per character.
- Detail **painted into the texture**, never modelled into geometry.
- **Exaggerated proportions**: big shoulders, oversized weapons.
- Saturated colours, simple lighting, no photorealistic materials.

## One body, one skeleton — this is load-bearing

There are **no playable races** in Ironveil. Every character shares one body
type and therefore one skeleton and one animation set. Every enemy that is a
person shares it too.

This is a production decision as much as a creative one. It means:

- One rig to make, one set of animations to make.
- Every piece of armour fits everybody automatically.
- A new enemy costs a texture, not a character.

**Do not deviate from the shared skeleton for any reason.** A class that needs
its own rig costs four times what it looks like it costs.

## The base body

Build this FIRST and get it approved before any class work. Everything else is
this mesh with different armour and textures on it.

- Humanoid, heroic proportions: roughly 7 heads tall, shoulders noticeably wider
  than realistic, hands and feet slightly oversized.
- T-pose or A-pose, origin at the feet, facing +Y (same convention as the kit's
  exterior face).
- 1 unit = 1 metre. A character stands about 1.8m.
- Clean quad topology with edge loops at shoulder, elbow, hip, knee — it has to
  deform.
- Single UV set, no overlapping shells.

### The skeleton

Standard humanoid hierarchy, named so Godot's retargeting recognises it: Hips,
Spine, Chest, Neck, Head, then Shoulder/UpperArm/LowerArm/Hand and
UpperLeg/LowerLeg/Foot for each side.

Plus four attachment bones the game already expects, matching the template's
existing sockets: **HeadAttach**, **LeftHandAttach**, **RightHandAttach**,
**BackAttach**.

**Trap, measured on the shipped rig (`km_rig.py`): the bones named "Left" sit
on the character's anatomical RIGHT, and "Right" on the anatomical left.** The
names follow the template's sockets, not the body. Consequences that are
already built in and must stay consistent:

- `Attack1` swings the "Right\*" arm, so main-hand weapons go on
  **RightHandAttach** and off-hands (shield, focus) on **LeftHandAttach**.
- Any new animation or attachment job should pick bones by measuring the
  socket's world position, never by the name. `tests/character_shot.gd` prints
  every socket's origin and axes for exactly this reason.
- Do not "fix" the names: every clip, socket and weapon transform in
  `player.tscn` is measured against them.

Also: the sockets' hand bases at Idle are ~25° off any axis, and Godot's
`Transform3D(...)` in a `.tscn` is written row-major. Copy the measured
transforms from `player.tscn` rather than deriving new ones.

### Animations needed, in priority order

The game already drives these state names, so match them exactly:
`Idle`, `Run`, `Sprint`, `Jump`, `Jump2`, `Fall`, `Attack1`, `Emote2`.

Idle, Run and Attack1 are the three that matter. The rest can be rough.

## The four classes

Palettes and silhouettes come from `docs/reference/01-characters/`. Each class
is **armour on the shared body**, plus a weapon on a hand socket.

### Valkyr — tank

Reference: `02-valkyr-dark-seraph.png`. Female-only, and deliberately **darker
than the town's bright cream-and-blue palette** — she is the one character who
should look out of place in a sunlit market square.

- Silhouette: the widest of the four. Heavy pauldrons, and **wings** as the
  read-at-distance feature.
- Palette: dark steel, blackened plate, gold trim.
- Weapon: spear, on the right hand socket. Shield on the left.

### Bard — healer

Reference: `01-bard-storm-skald.png`. "Storm Skald".

- Silhouette: the lightest. Long coat, no heavy plate, an instrument visible on
  the back socket so the role reads even from behind.
- Palette: storm blues and silver, weathered leather.
- Weapon: a light blade, and the instrument.

### Necromancer — ranged damage

Reference: `03-necromancer-veil-walker.png`. "Veil Walker".

- Silhouette: tall and narrow. Hood up, long ragged hem — the hem is what makes
  it read at distance.
- Palette: pale grave-green and dull violet, bone accents.
- Weapon: a staff.

### Tinker — ranged damage

Reference: `04-tinker-forge-engineer.png`. "Forge Engineer".

- Silhouette: bulky at the back, not the shoulders — a pack of tools and parts
  on the back socket is the distinguishing feature.
- Palette: brass, warm orange, oiled iron, leather.
- Weapon: a mechanical bolt thrower.

## Enemies

Every human enemy is the same base body with a different texture and a simple
armour variant. The roster is in `scripts/autoload/mob_database.gd`; each entry
already carries a `placeholder_color` giving the tone its real texture should
hit.

Non-human exceptions are few: `vale_wolf` needs a quadruped, and
`tinker_turret_pet` is a prop rather than a character. Everything else — bandits,
soldiers, risen levies, wights, both bosses — is the shared body.

## Build order

1. **Base body mesh** — approve before anything else.
2. **Skeleton and skinning** — approve the deformation before animating.
3. **Idle, Run, Attack1.**
4. **Valkyr** (most distinctive silhouette, best test of whether the approach
   works).
5. Necromancer, Tinker, Bard.
6. Remaining animations.
7. Enemy texture variants.

## Pipeline

Same as the kit: raw `.blend` files in `blender-source/`, exported `.glb` into
`godot-project/assets/characters/`. Render a preview of each piece for approval
before exporting.

Swapping a character in should be changing which scene `player.tscn` instances,
with the attachment sockets keeping their names so the existing equipment code
keeps working untouched.
