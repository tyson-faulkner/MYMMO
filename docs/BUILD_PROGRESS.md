# Kingsmourn — Build Progress

Updated by the autonomous build loop. Newest entry at the top of the log.
Milestone checkboxes live in `docs/BUILD_PLAN.md` — tick them there as they land.

## Current state

- **Milestone:** M1 — Character foundation
- **Loop status:** running
- **Last verified playable:** pending first validation run

## Waiting on Tyson (nothing here blocks the loop)

- `git push` — the sandbox has no GitHub credentials. Commits pile up locally
  and he pushes when he wants them on GitHub.
- Blender modelling — needs Blender open on his PC with the MCP server on port
  9876. Until then, all art is styled placeholder geometry with swap-in points.
- Docker/Nakama running — only needed to integration-test M7, not to write it.

## Decisions made autonomously

Recorded here so the design stays coherent and nothing gets asked twice.

- 2026-09-11 — Art strategy: build every visual as a scene with a replaceable
  `Mesh` node using the design-doc palette, so a `.glb` swap later needs no code
  change. Rationale: never block gameplay work on Blender availability.
- 2026-09-11 — Godot runs in the cloud container, not the device VM: GitHub is
  blocked by the device's egress allowlist, so Godot can't be downloaded there
  this session. Validation stages files up to the container instead.

## Log

### 2026-09-11 — Loop initialised
Read the design doc, kit spec, reference pack and the whole client codebase.
Wrote `docs/BUILD_PLAN.md` (the loop prompt + M1–M9 build order) and this file.
Confirmed Godot 4.7.2 headless runs in the cloud container and matches Tyson's
Windows build exactly. Starting M1.
