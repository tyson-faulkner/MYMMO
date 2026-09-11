"""Kingsmourn hand-painted texture library.

Generates the tileable, hand-painted-look textures every kit piece shares:
cream limestone, blue slate, warm timber, gray cobblestone, white plaster,
gold, black iron. Painted shading (dark crevices, lit edges, mottling) is
baked straight into the pixels -- no normal maps, matching the kit spec.

Colours are taken from docs/reference/03-environments/07-material-bible.png.

Run from Blender:  exec(open(<this file>).read())  then  build_all(TEX_DIR)
Textures are written as PNG so Blender can pack and embed them into each .glb.
"""

import os
import numpy as np

SIZE = 1024          # pixels per texture (~512 texels per world metre)
TILE_METERS = 2.0    # world size one texture tile covers


# ---------------------------------------------------------------- palette ---
# Linear-ish sRGB values sampled off the material bible.
CREAM_STONE = np.array([0.847, 0.745, 0.576])
CREAM_MORTAR = np.array([0.478, 0.404, 0.298])
SLATE = np.array([0.404, 0.455, 0.545])
SLATE_DARK = np.array([0.176, 0.208, 0.267])
TIMBER = np.array([0.478, 0.298, 0.145])
TIMBER_DARK = np.array([0.184, 0.106, 0.047])
COBBLE = np.array([0.600, 0.588, 0.565])
COBBLE_DARK = np.array([0.278, 0.271, 0.259])
PLASTER = np.array([0.910, 0.878, 0.812])
GOLD = np.array([0.831, 0.667, 0.259])
GOLD_DARK = np.array([0.400, 0.290, 0.075])
IRON = np.array([0.165, 0.158, 0.150])   # neutral, faintly warm -- see note in black_iron()
HERALDRY_BLUE = np.array([0.114, 0.169, 0.365])


# ------------------------------------------------------------------ noise ---
def _smooth(t):
    return t * t * (3.0 - 2.0 * t)


def value_noise(size, freq, seed, tile=True):
    """Tileable value noise in [0,1]. `freq` lattice cells across the image."""
    rng = np.random.default_rng(seed)
    grid = rng.random((freq, freq))
    if tile:
        grid = np.pad(grid, ((0, 1), (0, 1)), mode="wrap")
    else:
        grid = np.pad(grid, ((0, 1), (0, 1)), mode="edge")

    coords = np.linspace(0.0, freq, size, endpoint=False)
    i0 = np.floor(coords).astype(int)
    frac = _smooth(coords - i0)

    gy0 = grid[i0, :][:, i0]
    gy1 = grid[i0 + 1, :][:, i0]
    gx0 = grid[i0, :][:, i0 + 1]
    gx1 = grid[i0 + 1, :][:, i0 + 1]

    fy = frac[:, None]
    fx = frac[None, :]
    top = gy0 * (1 - fx) + gx0 * fx
    bot = gy1 * (1 - fx) + gx1 * fx
    return top * (1 - fy) + bot * fy


def fbm(size, freq, seed, octaves=4, gain=0.5):
    """Fractal value noise -- the mottling that sells the painted look."""
    out = np.zeros((size, size))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        out += amp * value_noise(size, freq * (2 ** o), seed + o * 101)
        total += amp
        amp *= gain
    return out / total


def _uv(size):
    """Pixel-centre UV grid in [0,1). v runs down the image."""
    a = (np.arange(size) + 0.5) / size
    return np.meshgrid(a, a)  # u (x across), v (y down)


def _tint(base, amount):
    """Per-pixel value multiplier -> RGB, keeping the hue of `base`."""
    return base[None, None, :] * amount[:, :, None]


def _finish(rgb):
    return np.clip(rgb, 0.0, 1.0)


def _rgba(rgb, alpha=None):
    h, w = rgb.shape[:2]
    a = np.ones((h, w, 1)) if alpha is None else alpha[:, :, None]
    return np.concatenate([_finish(rgb), a], axis=2)


# ------------------------------------------------------- masonry generator ---
def _block_field(size, cols, rows, warp_amount, seed):
    """Offset running-bond block layout. Returns (bx, by, cell_id, edge_dist).

    bx/by are 0..1 coordinates inside each block; edge_dist is the normalised
    distance to the nearest block edge (0 at the mortar, 1 at block centre).
    """
    u, v = _uv(size)
    # Warp the whole lattice so the courses aren't machine-straight.
    wu = (fbm(size, 4, seed + 7, octaves=3) - 0.5) * warp_amount
    wv = (fbm(size, 4, seed + 19, octaves=3) - 0.5) * warp_amount
    u = u + wu
    v = v + wv

    ry = v * rows
    row = np.floor(ry).astype(int)
    by = ry - row
    # Running bond: every other course shifts half a block.
    shift = (row % 2) * 0.5
    rx = (u + shift / cols) * cols
    col = np.floor(rx).astype(int)
    bx = rx - col

    cell = (row % rows) * 8191 + (col % cols) * 131
    dx = np.minimum(bx, 1.0 - bx)
    dy = np.minimum(by, 1.0 - by)
    return bx, by, cell, dx, dy


def _cell_random(cell, seed, lo=0.0, hi=1.0):
    """Deterministic per-block random value."""
    h = (cell.astype(np.int64) * 2654435761 + seed * 40503) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    return lo + (hi - lo) * ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def _courses(size, rows, seed, warp_amount=0.014):
    """Hand-cut ashlar: each course gets its own height, block count and phase.

    Every course tiles horizontally on its own, so the whole texture stays
    seamless while no two courses look alike -- that irregularity is what
    separates quarried stone from brickwork.
    """
    u, v = _uv(size)
    u = u + (fbm(size, 4, seed + 7, octaves=3) - 0.5) * warp_amount
    v = v + (fbm(size, 4, seed + 19, octaves=3) - 0.5) * warp_amount * 0.6

    rng = np.random.default_rng(seed)
    heights = 1.0 + (rng.random(rows) - 0.5) * 0.5
    edges = np.concatenate([[0.0], np.cumsum(heights / heights.sum())])
    counts = rng.choice([2, 3, 4], size=rows, p=[0.3, 0.45, 0.25])
    phases = rng.random(rows)

    vv = np.mod(v, 1.0)
    row = np.clip(np.searchsorted(edges, vv, side="right") - 1, 0, rows - 1)
    lo, hi = edges[row], edges[row + 1]
    by = (vv - lo) / (hi - lo)

    rx = (np.mod(u, 1.0) + phases[row]) * counts[row]
    col = np.floor(rx).astype(int)
    bx = rx - col

    cell = row * 8191 + np.mod(col, counts[row]) * 131
    # Distances to the block edges, converted to a common (texture-space) scale
    # so mortar reads the same width horizontally and vertically.
    dx = np.minimum(bx, 1.0 - bx) / counts[row]
    dy = np.minimum(by, 1.0 - by) * (hi - lo)
    return bx, by, cell, dx, dy


def limestone(size=SIZE, seed=11):
    """Cream limestone ashlar over a 2m tile -- irregular courses, deep mortar."""
    rows = 6
    bx, by, cell, dx, dy = _courses(size, rows, seed)

    mortar_w = 0.020          # in texture-space units (1.0 == the whole tile)
    mortar = _smooth(np.clip(np.minimum(dx, dy) / mortar_w, 0, 1))

    # Per-block tonal variation -- the biggest single win for a painted look.
    tone = _cell_random(cell, seed, 0.86, 1.15)
    # Bias the per-block hue jitter warm; limestone should never read olive.
    warm = _cell_random(cell, seed + 3, -0.015, 0.055)

    # Painted shading inside each block: lit along the top, shaded at the base.
    lift = (1.0 - by) * 0.15 - by * 0.07
    # Contact shadow hugging the mortar line.
    ao = 1.0 - 0.34 * (1.0 - _smooth(np.clip(np.minimum(dx, dy) / 0.055, 0, 1)))
    # Bright chip along the very top edge of each block.
    chip = 0.24 * (1.0 - _smooth(np.clip(by / 0.09, 0, 1)))

    grain = (fbm(size, 16, seed + 31, octaves=4) - 0.5) * 0.10
    speck = (fbm(size, 64, seed + 47, octaves=2) - 0.5) * 0.05

    value = tone * ao + lift + chip + grain + speck
    rgb = _tint(CREAM_STONE, value)
    rgb[:, :, 0] += warm
    rgb[:, :, 2] -= warm * 0.35

    mortar_rgb = _tint(CREAM_MORTAR, 0.68 + (fbm(size, 32, seed + 61) - 0.5) * 0.3)
    m = mortar[:, :, None]
    return _rgba(rgb * m + mortar_rgb * (1 - m))


def slate_roof(size=SIZE, seed=23):
    """Blue slate shingles: 6 across x 8 courses over a 2m tile."""
    cols, rows = 6, 8
    u, v = _uv(size)
    wu = (fbm(size, 6, seed + 5, octaves=3) - 0.5) * 0.010
    u = u + wu

    ry = v * rows
    row = np.floor(ry).astype(int)
    by = ry - row
    rx = (u + (row % 2) * 0.5 / cols) * cols
    col = np.floor(rx).astype(int)
    bx = rx - col
    cell = (row % rows) * 8191 + (col % cols) * 131

    # Rounded-bottom shingle silhouette.
    corner = 0.26
    cx = np.clip((np.abs(bx - 0.5) - (0.5 - corner)) / corner, 0, 1)
    round_off = 1.0 - np.clip((by - (1.0 - corner)) / corner, 0, 1) ** 2
    body = np.clip(round_off - cx ** 2 * np.clip((by - 0.55) / 0.45, 0, 1), 0, 1)

    gap_w = 0.055
    gap = _smooth(np.clip(np.minimum(bx, 1 - bx) / gap_w, 0, 1))
    gap = np.minimum(gap, _smooth(np.clip(body / 0.12, 0, 1)))

    tone = _cell_random(cell, seed, 0.80, 1.18)
    cool = _cell_random(cell, seed + 3, -0.030, 0.030)

    # Light rakes down the slope: dark where the course above overlaps,
    # bright lip along the exposed bottom edge of each shingle.
    overlap = 1.0 - 0.34 * (1.0 - _smooth(np.clip(by / 0.30, 0, 1)))
    lip = 0.30 * _smooth(np.clip((by - 0.76) / 0.22, 0, 1)) * _smooth(np.clip(body / 0.2, 0, 1))
    edge_ao = 1.0 - 0.22 * (1.0 - _smooth(np.clip(np.minimum(bx, 1 - bx) / 0.16, 0, 1)))

    grain = (fbm(size, 24, seed + 29, octaves=4) - 0.5) * 0.13
    value = tone * overlap * edge_ao + lip + grain
    rgb = _tint(SLATE, value)
    rgb[:, :, 2] += cool
    rgb[:, :, 0] -= cool * 0.6

    g = gap[:, :, None]
    return _rgba(rgb * g + SLATE_DARK[None, None, :] * (1 - g))


def timber(size=SIZE, seed=37, planks=4):
    """Warm brown planks running vertically, with grain and a few knots."""
    u, v = _uv(size)
    px = u * planks
    col = np.floor(px).astype(int)
    bx = px - col
    cell = (col % planks) * 977

    tone = _cell_random(cell, seed, 0.82, 1.14)
    warm = _cell_random(cell, seed + 5, -0.04, 0.05)

    seam = _smooth(np.clip(np.minimum(bx, 1 - bx) / 0.045, 0, 1))
    # Barrel shading across each plank: lit centre, shaded edges.
    barrel = 1.0 - 0.30 * ((bx - 0.5) * 2.0) ** 2

    # Grain: noise squashed hard along the plank direction.
    g = fbm(size, 8, seed + 13, octaves=5)
    g_fine = value_noise(size, 128, seed + 17)
    stretched = np.take(g, np.arange(size), axis=0)
    grain = (stretched - 0.5) * 0.16 + (g_fine - 0.5) * 0.05
    streak = np.sin(px * np.pi * 2.0 * 3.0 + fbm(size, 6, seed + 23) * 9.0)
    grain += streak * 0.035

    value = tone * barrel + grain
    rgb = _tint(TIMBER, value)
    rgb[:, :, 0] += warm
    rgb[:, :, 2] -= warm * 0.5

    # Knots.
    rng = np.random.default_rng(seed + 99)
    for _ in range(3):
        ku, kv = rng.random(), rng.random()
        du = np.minimum(np.abs(u - ku), 1 - np.abs(u - ku))
        dv = np.minimum(np.abs(v - kv), 1 - np.abs(v - kv))
        d = np.sqrt((du * 3.0) ** 2 + dv ** 2)
        rings = np.cos(d * 140.0) * 0.5 + 0.5
        k = np.clip(1.0 - d / 0.055, 0, 1) ** 1.5
        rgb *= (1.0 - k * (0.45 - rings * 0.22))[:, :, None]

    s = seam[:, :, None]
    return _rgba(rgb * s + TIMBER_DARK[None, None, :] * (1 - s))


def cobblestone(size=SIZE, seed=53, cells=5):
    """Irregular rounded setts -- tileable Worley cells with domed shading."""
    rng = np.random.default_rng(seed)
    # Keep the jitter modest: crowded sites make sliver cells, and a sliver
    # cell's dome collapses into a dark smudge.
    pts = (np.stack(np.meshgrid(np.arange(cells), np.arange(cells)), -1)
           + rng.random((cells, cells, 2)) * 0.5 + 0.25) / cells
    pts = pts.reshape(-1, 2)
    ids = np.arange(pts.shape[0])

    u, v = _uv(size)
    # Warp the lattice so the setts have wobbly hand-cut outlines rather than
    # the dead-straight edges a raw Voronoi gives you.
    u = u + (fbm(size, 8, seed + 3, octaves=3) - 0.5) * 0.045
    v = v + (fbm(size, 8, seed + 9, octaves=3) - 0.5) * 0.045

    best = np.full((size, size), 1e9)
    second = np.full((size, size), 1e9)
    owner = np.zeros((size, size), dtype=np.int64)
    for p, pid in zip(pts, ids):
        du = np.abs(u - p[0])
        du = np.minimum(du, 1 - du)
        dv = np.abs(v - p[1])
        dv = np.minimum(dv, 1 - dv)
        d = np.sqrt(du * du + dv * dv)
        closer = d < best
        second = np.where(closer, best, np.minimum(second, d))
        owner = np.where(closer, pid, owner)
        best = np.where(closer, d, best)

    border = second - best                 # 0 on a cell boundary
    gap = _smooth(np.clip(border / (0.15 / cells), 0, 1))

    tone = _cell_random(owner, seed, 0.78, 1.18)
    warm = _cell_random(owner, seed + 3, -0.035, 0.035)
    # Spherical profile: height falls off from the sett's centre to its rim, so
    # each stone reads as a rounded pebble instead of a flat polygon.
    radius = np.maximum(best + border, 1e-6)
    p_norm = np.clip(best / radius, 0, 1)
    dome = np.sqrt(np.clip(1.0 - p_norm ** 2, 0, 1))
    shade = 0.62 + dome * 0.58
    grain = (fbm(size, 20, seed + 41, octaves=4) - 0.5) * 0.12
    speck = (value_noise(size, 96, seed + 67) - 0.5) * 0.06

    rgb = _tint(COBBLE, tone * shade + grain + speck)
    rgb[:, :, 0] += warm
    rgb[:, :, 2] -= warm * 0.5

    g = gap[:, :, None]
    grout = _tint(COBBLE_DARK, 0.8 + (fbm(size, 40, seed + 71) - 0.5) * 0.4)
    return _rgba(rgb * g + grout * (1 - g))


def plaster(size=SIZE, seed=71):
    """Off-white lime plaster for timber-frame infill."""
    mott = (fbm(size, 6, seed, octaves=5) - 0.5) * 0.10
    fine = (fbm(size, 48, seed + 13, octaves=3) - 0.5) * 0.055
    trowel = np.sin(fbm(size, 4, seed + 29) * 14.0) * 0.022
    rgb = _tint(PLASTER, 1.0 + mott + fine + trowel)
    warm = (fbm(size, 8, seed + 37) - 0.5) * 0.03
    rgb[:, :, 0] += warm
    rgb[:, :, 2] -= warm
    return _rgba(rgb)


def gold_leaf(size=SIZE, seed=83):
    """Heraldic gold -- hammered highlights, no metallic map needed."""
    # Broad sweep of light plus finer hammer marks -- smooth, but not flat.
    sweep = (fbm(size, 3, seed + 11, octaves=2, gain=0.35) - 0.5) * 0.26
    hammer = (fbm(size, 10, seed, octaves=3) - 0.5) * 0.17
    fine = (fbm(size, 32, seed + 23, octaves=2) - 0.5) * 0.05
    rgb = _tint(GOLD, 1.0 + sweep + hammer + fine)
    rgb[:, :, 1] += (sweep + hammer) * 0.10
    return _rgba(rgb)


def black_iron(size=SIZE, seed=91):
    """Wrought iron: near-black with soft painted highlights and pitting.

    Kept neutral-to-warm on purpose. Anything dark picks up a lot of sky
    ambient, so a base colour with even a slight blue tilt renders navy
    rather than black once it's on a door strap out in the sun.
    """
    mott = (fbm(size, 12, seed, octaves=4) - 0.5) * 0.55
    pit = (value_noise(size, 64, seed + 17) - 0.5) * 0.25
    rgb = _tint(IRON, 1.0 + mott + pit)
    # Warm the highlights very slightly. A blue push here plus the sky fill
    # made the strap hinges read navy instead of black.
    rgb[:, :, 0] += np.clip(mott, 0, None) * 0.05
    return _rgba(rgb)


BUILDERS = {
    "limestone": limestone,
    "slate": slate_roof,
    "timber": timber,
    "cobblestone": cobblestone,
    "plaster": plaster,
    "gold": gold_leaf,
    "iron": black_iron,
}


# ------------------------------------------------------------ blender I/O ---
def save_png(rgba, path):
    """Write a float HxWx4 array out as a PNG through Blender's image system."""
    import bpy
    h, w = rgba.shape[:2]
    name = os.path.basename(path)
    img = bpy.data.images.get(name)
    if img and (img.size[0] != w or img.size[1] != h):
        bpy.data.images.remove(img)
        img = None
    if img is None:
        img = bpy.data.images.new(name, width=w, height=h, alpha=True)
    # Blender images are bottom-up; our arrays are top-down.
    img.pixels.foreach_set(np.flipud(rgba).astype(np.float32).ravel())
    img.file_format = "PNG"
    img.filepath_raw = path
    img.save()
    return img


def build_all(tex_dir, only=None, force=False):
    """Generate every texture that doesn't exist yet. Returns {name: path}."""
    out = {}
    for name, fn in BUILDERS.items():
        if only and name not in only:
            continue
        path = os.path.join(tex_dir, "km_%s.png" % name)
        if force or not os.path.exists(path):
            save_png(fn(), path)
        out[name] = path
    return out
