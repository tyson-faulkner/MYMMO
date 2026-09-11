# Running the build loop on your own PC

Doing it here instead of in the cloud session buys three things:

1. **`git push` works.** This machine has your GitHub login. The cloud sandbox
   doesn't, so commits pile up there until you push them by hand.
2. **Blender works.** The 3D art pipeline needs Blender actually running on this
   machine. The cloud sandbox can't reach it.
3. **It survives.** A cloud session eventually goes away. A terminal on your own
   PC keeps going.

Paste **one line at a time**, press Enter, wait for it to finish, then the next.

## One-time setup

**1. Install Claude Code.** In PowerShell:

```
npm install -g @anthropic-ai/claude-code
```

Success looks like: it finishes without a red error. (Already installed? It just
updates.)

**2. Point it at the project:**

```
cd C:\Users\tyson\Desktop\MyMMO
```

Success looks like: the prompt now ends in `MyMMO>`.

**3. Connect the Godot MCP server** you already built:

```
claude mcp add godot -- node C:\Users\tyson\mcp-servers\godot-mcp\build\index.js
```

Success looks like: `Added stdio MCP server godot`.

**4. Install uv**, which is what runs the Blender server:

```
pip install uv
```

Success looks like: `Successfully installed uv-...`.

**5. Connect the Blender MCP server:**

```
claude mcp add blender -- uvx blender-mcp
```

Success looks like: `Added stdio MCP server blender`.

**6. Install the Blender add-on.** This is the half that lives inside Blender
itself, and it's the part that actually lets anything drive it:

- Download `addon.py` from https://github.com/ahujasid/blender-mcp
- In Blender: Edit -> Preferences -> Add-ons -> Install from Disk -> pick
  `addon.py` -> tick the checkbox next to "Interface: Blender MCP"
- Press `N` in the 3D viewport to open the side panel, choose the
  **BlenderMCP** tab, and click **Connect to Claude**

Success looks like: the panel says it's listening on port 9876.

## Every time you want to build

**1.** Open Blender and click **Connect to Claude** (only needed for art work).

**2.** In PowerShell:

```
cd C:\Users\tyson\Desktop\MyMMO
```

**3.**

```
claude
```

**4.** Paste this and press Enter:

> Read CLAUDE.md, docs/BUILD_PLAN.md and docs/BUILD_PROGRESS.md. Continue the
> Kingsmourn build from the current milestone. Do the next unchecked tasks in
> order, without asking me anything — decide unspecified details yourself and
> record them in BUILD_PROGRESS.md. Run the smoke test before each commit, commit
> every completed task, and push when a milestone lands. Keep going until the
> milestone is finished.

## Checking it worked

```
claude mcp list
```

Success looks like: both `godot` and `blender` listed as connected.

If Blender shows as failed, it's almost always that Blender isn't open or
**Connect to Claude** hasn't been clicked in that side panel yet.

## The art loop (needs Blender open and connected)

The build loop above works anywhere. **Art only works here**, on this PC, with
Blender running and **Connect to Claude** pressed — nothing else can reach it.

Open Blender, connect it, then in the MyMMO folder run `claude` and paste:

> Read CLAUDE.md and docs/kingsmourn-kit-spec.md. Blender is open and the
> Blender MCP server is connected. Build the modular kit, Phase 1 first, one
> piece at a time in the listed order. For each piece: model it on a 1m grid in
> Blender, UV unwrap simply, texture it flat then add painted shading, render a
> preview so I can see it, and export the .glb to
> godot-project/assets/kit/. Match the palette in the kit spec — cream stone,
> blue slate roofs, warm timber, gold accents — and the reference images in
> docs/reference/. Never redo an approved piece. Commit each piece as you go.
> Work through as many pieces as you can without stopping to ask me.

Phase 1 is five pieces: a stone wall section, a wall with a window, a wall with
a door, a sloped slate roof plus corner, and a timber-frame upper storey. Those
five are enough to build every house in Thornhollow Vale, which is currently
made of tinted boxes.

### Swapping art in

Each placeholder in `scripts/world/zone_builder.gd` is a box with a colour.
Replacing one means loading a `.glb` instead of building a `BoxMesh` in
`_build_piece`. The layout — where every house, wall and prop sits — does not
change, because the blockout was authored on the same grid the kit uses.
