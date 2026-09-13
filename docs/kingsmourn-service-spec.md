# Kingsmourn — Death, Loot, Hosting, Launcher and the Guild

Five decisions taken 2026-09-12. These are the ones that turn a working build
into something five to ten friends can actually live in.

---

## 1. Death

**Decided:** corpse runs are the default and the cheap option. Spirit healers
are spread through every zone so the walk is short, ghosts move faster than the
living, and the five-minute sickness only applies if you take the shortcut.

Most of this is already built in `DeathHandler`. What the decision changes:

**Ghost speed.** A ghost moves at **1.5x** normal running speed. This is the
whole reason corpse runs are tolerable — WoW's mistake was making the walk back
the same speed as the walk out. Implemented as a third travel multiplier on the
player next to the mount one; you can never be both, so they never stack.

**Graveyard density.** A corpse run is only short if there is a graveyard
nearby. One per zone is a punishment; four is a minor inconvenience. Target:
**no point in a surface zone more than ~90m from a graveyard**, and every
dungeon gets one at its entrance.

| Zone | Graveyards |
|---|---|
| Thornhollow Vale | Thornhollow Rest (town), Hedgerow Rest (mid), Barrow Watch (north) |
| The Barrow | The Barrow Threshold |
| Sablemarch | The Field Camp (south), The Fordside (east), Causeway Rest (mid), Redoubt Watch (north) |
| The Drowned Redoubt | The Redoubt Causeway |
| Kingsmourn | Kingsgate Rest (south), Market Rest, Guild Quarter Rest, Palace Rest |
| Crypt / Hall / Throne | one each at the entrance |

**Spirit healers.** Every graveyard has one — a single shared NPC
(`npc_spirit_healer`) placed at each, the same way WoW does it. Talking to one
offers "Return to life" — instant resurrection, full health, **five minutes of
Grave-Chill** (everything you do lands for 75%). Walking to your corpse instead
costs nothing but the walk.

**Already built and unchanged:** the ghost state, the transparent model, the
corpse marker, reclaim-on-approach, the sickness timer, and the Ferryman's Coin
unique that halves it.

---

## 2. Loot

**Decided:** three modes, need/greed/pass rolls in dungeons, and a reserve
system so nobody runs the same dungeon six times for one item.

### The three modes

Set by the party leader; the game remembers per party.

| Mode | Who gets it | Default for |
|---|---|---|
| **Free for All** | Whoever clicks the corpse first | Solo play and questing |
| **Group Loot** | Anything above the threshold triggers a roll | Dungeons |
| **Master Loot** | Above-threshold items go to the leader's window to hand out | Raids, and any night the group would rather just decide |

**Threshold** is a rarity setting (default: Rare and above). Below it,
everything is free-for-all so nobody rolls over three Sovereigns and a flask.

### Need / Greed / Pass

When a qualifying item drops under Group Loot, everyone in range gets a window
with the item, its stats, **and how it compares to what they're wearing** (the
same upgrade-arrow maths from the QOL spec — so the roll is an informed one).

- **Need** — a 1-100 roll. Greyed out, with a reason, when the item is not for
  you: wrong class for a weapon (`class_restriction` already exists on gear),
  or below your level. Need always beats Greed.
- **Greed** — a 1-100 roll, for anyone who wants it to sell or to keep.
- **Pass** — out.
- **60-second timer**, auto-pass on expiry, so one friend in the kitchen never
  holds up the run.
- Results are announced: *"Marcher Hauberk — Mike rolled Need 87, Tyson rolled
  Need 41. Mike wins."*

### Reserves — the part WoW never had

Before a dungeon or raid, each player may **reserve one item** from that
instance's loot table. Browse the table from the portal, pick one, locked in
until the next reset.

If a reserved item drops, **only players who reserved it may roll Need on it.**
If nobody reserved it, it rolls normally. Reserve one item, and the run stops
being a lottery for the thing you actually came for.

This composes with grudge bosses: grudge raises the drop *chance*, reserves
decide *who gets it*. Between them, "I've run this six times and never seen my
piece" stops existing.

### Loot history

The server keeps a log of every above-threshold drop and who ended up with it,
visible to the whole party. Two reasons: a master looter can be visibly fair,
and it feeds the chronicle (*"Mike has taken four of the last six Sovereign
drops"* is exactly the kind of thing Ilsa should say).

### What already exists

Item drops, loot tables per mob with per-item chances, ground pickup, and the
`class_restriction` field the Need button needs. Missing: party loot mode,
the roll window, reserves, and the history log.

---

## 3. Hosting — an always-on server

**Decided:** a $6-10/month VPS. This is the single most important item on the
list. Today one friend hosts and nobody else can play unless that person is
online — that is a LAN game. A VPS makes the world *there*, at 2am, whether
anyone else is or not.

**Recommended box:** Hetzner CX22 (~€4/mo) or DigitalOcean's $6 droplet.
2 vCPU / 4GB is far more than ten players need. Ubuntu 24.04 LTS.

**What runs on it:**

- **Nakama + CockroachDB** in Docker — accounts, characters, saves, records.
- **The game server** — the same Godot build, run headless as a systemd
  service, restarting on crash and on boot.

**Ports:** 8080 game (UDP/TCP), 7350 Nakama API, 7351 Nakama console (bind to
localhost only, reach it over an SSH tunnel — never expose the console).

**Deployment kit** is in `deploy/` alongside this document: a
`docker-compose.yml`, the systemd unit, a `setup.sh` that goes from a fresh
Ubuntu box to a running server in one command, and `deploy.sh` for pushing a
new build afterwards.

**Backups:** a nightly `pg_dump`-equivalent of the Cockroach volume to a second
directory, keeping seven days. Losing everyone's characters to a bad update
would end the project, and the cron line that prevents it takes two minutes.

---

## 4. Getting friends into the game

**Decided:** lowest possible effort for them. Build a launcher.

**The bar to clear:** a friend gets one link, double-clicks one thing, types a
name, and is in. No IP addresses, no zip files, no "which version are you on".

**The launcher** is a small separate Godot app, `KingsmournLauncher.exe`:

1. On start, fetches `version.json` from the VPS.
2. If the local build is older, downloads the new `game.pck` with a progress
   bar.
3. Shows a small news line (what changed) and a Play button.
4. Launches the game with the server address already baked in.

Roughly 250 lines plus a simple UI. The reason it's worth building rather than
using itch.io: **the server address is baked in**, so nobody ever types an IP,
and you control what the first screen says.

**The fallback, if the launcher slips:** a private itch.io page with the itch
app, which auto-updates for free and takes about ten minutes to set up. Worth
doing that first anyway, as the thing the launcher downloads from.

**What they do once:** download the launcher, run it, pick a name and a class.
That's the whole onboarding.

---

## 5. The guild — OTPH

**Decided:** one guild, **OTPH**, everyone in it, crested with the tavern
reference art.

With five to ten friends there is no need for applications, ranks, or a charter
— everyone is in it from the moment they make a character. What it should
actually do:

- **`<OTPH>` under every player's name** in the world and on the player list.
- **Guild chat** on `/g`, always available, separate from local chat. This is
  the channel people will actually live in.
- **A roster panel**: who's online now, and for everyone else their level,
  class, spec and when they were last seen. On a small server "who played last
  night" is genuinely interesting.
- **The guild hall.** Bryn Aldercott's inn in Thornhollow Vale becomes the OTPH
  tavern — the reference tavern art is the interior it is built toward, and the
  crest hangs over the door. A real place to meet, with the hearth as a bind
  point.
- **The crest** — the tavern graphic — shows on the roster panel, the launcher,
  and the loading screen.
- **The chronicle is the guild's.** Ilsa's weekly line (QOL spec §6) is guild
  news: first kills, records taken, who died most. The guild and the history
  are the same feature wearing two hats.

**Deliberately not built:** ranks and permissions, a guild bank, guild levels,
applications. Every one of those exists to manage strangers.

---

## Build order for this document

| # | Thing | Size | Why here |
|---|---|---|---|
| 1 | Graveyards + spirit healers + ghost speed | small | Done in this pass |
| 2 | VPS deployment kit | small | Done in this pass; unblocks everything social |
| 3 | Nakama persistence wiring | medium | The server is pointless until characters save |
| 4 | Guild tag, `/g` chat, roster | small | Cheap, and it's what makes it feel like *your* server |
| 5 | Loot modes + need/greed/pass | medium | Needed before the first real dungeon night |
| 6 | Reserves + loot history | small | Right after rolls work |
| 7 | Launcher | medium | Last — you can hand out a zip until then |
