# Running the Ironveil server

Everything needed to take a fresh Ubuntu box to an always-on Ironveil world.
Written for somebody who has never rented a server before — every step says
what it does and why.

## Why bother

Today one friend hosts from their PC, which means nobody can play unless that
person is online, and nothing saves. A $6–10/month box makes the world *there*:
log in at 2am on a Tuesday and your character is where you left it. This is the
single biggest thing standing between the build and something that feels like
an MMO.

## What you're renting

Any of these is plenty for ten players:

| Provider | Plan | Cost |
|---|---|---|
| Hetzner | CX22 (2 vCPU, 4GB) | ~€4/mo |
| DigitalOcean | Basic droplet (1 vCPU, 2GB) | $6/mo |
| Vultr | Regular (1 vCPU, 2GB) | $6/mo |

Pick **Ubuntu 24.04 LTS** and a region near most of your friends. Add your SSH
key during creation if the provider offers it — it saves a password step later.

## What ends up running

Two separate things, deliberately:

- **The backend** — Nakama plus CockroachDB, in Docker. Accounts, characters,
  inventories, records. Started by `docker-compose.yml`.
- **The game server** — the same Godot build everyone plays, run headless as a
  systemd service so it restarts on crash and on reboot.

Keeping them apart means you can push a new game build without going anywhere
near the database.

## First-time setup

From your PC, in the repo:

```
scp -r deploy/ you@your-server-ip:~/
ssh you@your-server-ip
cd deploy && chmod +x setup.sh && sudo ./setup.sh
```

`setup.sh` installs Docker, makes a locked-down service user, generates real
secrets, opens exactly three ports in the firewall, starts the backend,
installs the game service, and sets up nightly backups. It is safe to run more
than once.

**Write down the two values it prints.** The server key goes into the Godot
client; the console password is not shown again.

## Sending it a build

Export a **Linux/X11** build from Godot named `Ironveil.x86_64`, then from
your PC:

```
./deploy.sh you@your-server-ip /path/to/your/export/folder
```

Uploads, restarts the service, done — a few seconds. Run it again for every
update.

## Day to day

```
systemctl status ironveil                              # is the game up
tail -f /var/log/ironveil/server.log                   # what it's doing
docker compose -f /opt/ironveil/docker-compose.yml ps  # is the backend up
sudo systemctl restart ironveil                        # kick it
```

**The Nakama admin console** (player list, storage browser) is deliberately not
exposed to the internet. Reach it through an SSH tunnel from your own machine:

```
ssh -L 7351:localhost:7351 you@your-server-ip
```

then open `http://localhost:7351` in your browser and log in with the console
password from setup.

## Ports

| Port | What | Who can reach it |
|---|---|---|
| 22 | SSH | you |
| 8080 tcp+udp | the game | everyone |
| 7350 | Nakama API | everyone |
| 7351 | Nakama console | localhost only (SSH tunnel) |
| 26257 | CockroachDB | localhost only |

The database and the admin console are closed on purpose. An open Nakama
console is somebody else's server.

## Backups

`backup.sh` runs at 04:30 nightly and keeps seven days in
`/opt/ironveil/backups`. Losing everyone's characters to a bad update is the
one failure this project would not recover from, so this is not optional.

To pull a copy down to your own machine now and then:

```
scp you@your-server-ip:/opt/ironveil/backups/\*.tar.gz ./
```

## Two things setup.sh does not do

**A domain name.** Friends can type an IP; it just isn't pretty. If you want
`play.ironveil.example`, point an A record at the server's IP and use that
instead — no server-side change needed.

**TLS on Nakama.** Fine for a private server among friends. If you ever want
it, put Caddy in front of 7350 and it handles certificates by itself.
