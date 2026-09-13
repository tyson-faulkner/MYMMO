# Ironveil — Modular Kit Build Spec

Low-poly, WoW-Classic-styled modular kit for Ironveil.

## Style rules (apply to every piece)

- Low-poly, WoW-Classic proportions: chunky, slightly oversized details, no realism
- Palette: cream/tan stone, blue slate roofs, warm brown timber, gold accents
- Hand-painted texture look: painted highlights/shadows baked into the texture; no realistic
  materials, no normal maps yet
- Every piece snaps to a **1-meter grid** so pieces click together like LEGO
- Export each piece as its own `.glb` into `godot-project/assets/kit/`

## Build order (one piece at a time — approve each before the next)

### Phase 1 — Structure (buildings)

1. Stone wall section (2m wide x 3m tall)
2. Wall with window
3. Wall with door + wooden door
4. Blue slate roof section (sloped) + roof corner piece
5. Timber-frame upper-story wall (white plaster + brown beams)

### Phase 2 — Ground

6. Cobblestone street tile (2m x 2m, tileable)
7. Stone stair piece
8. Low stone wall / ledge

### Phase 3 — Props

9. Street lamp (black iron, warm glow)
10. Market stall (wood frame + red/gold cloth awning)
11. Round tree (green canopy, WoW-style blob foliage) + planter box
12. Fountain (centerpiece)

## Workflow per piece

1. Model the shape in Blender (via Blender MCP)
2. UV unwrap simple
3. Texture: start with flat colors, then add painted shading (darker crevices, lighter edges)
4. Render a preview screenshot -> approve or give one correction -> export `.glb`
5. Move to next piece — **never redo an approved piece**

## Reference

- Match the vibe of the two Stormwind screenshots (style reference only — all geometry and
  textures original)
- Target: "Game of Thrones mixed with Stormwind" — sunlit, bright, heraldic

## Pipeline notes

- Raw `.blend` working files live in `blender-source/`
- Exported game-ready `.glb` files go to `godot-project/assets/kit/`
- Blender MCP auto-starts its server on port 9876 when Blender launches
