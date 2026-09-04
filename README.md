# MyMMO

A small-scale MMO project combining a Godot game client, a Nakama multiplayer backend, and Blender for 3D art production.

## Folder structure

```
MyMMO/
├── godot-project/    Godot game client (devmoreir4/godot-3d-multiplayer-template)
├── blender-source/   Raw .blend files — source of truth for all 3D art
├── nakama-server/    Nakama multiplayer server (heroiclabs/nakama)
├── docs/             Personal notes, design docs, planning
└── README.md
```

## How the pieces connect

- **godot-project/** is the game client players run. It's a Godot project built from a 3D multiplayer template, and it talks to the Nakama server over the network for matchmaking, authentication, and real-time game state sync.
- **nakama-server/** is the backend that godot-project connects to. It handles player accounts, matchmaking, storage, and realtime multiplayer messaging. Run it locally via Docker (Nakama ships with a `docker-compose.yml`) rather than building it from source day-to-day.
- **blender-source/** holds the raw, editable `.blend` files for characters, props, and environments. Nothing here is used directly by the game — models are exported (e.g. to `.glb`/`.gltf`) into `godot-project/assets` (or wherever the Godot project expects imported art) once they're ready.
- **docs/** is a free-form space for design notes, TODOs, and planning that don't belong in either the client or server codebase.

## Getting started

1. Start the Nakama server: `cd nakama-server && docker compose up`
2. Open `godot-project/` in the Godot editor and run the client.
3. Point the client at your local Nakama instance (default: `127.0.0.1:7350`) for testing.
