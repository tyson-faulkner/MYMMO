"""Kingsmourn hand-painted texture library.

Generates the tileable, hand-painted-look textures every kit piece shares:
cream limestone, blue slate, warm timber, gray cobblestone, white plaster,
gold, black iron -- plus the two ground textures ZoneBuilder lays over its
ground plates: meadow grass and marsh mud. Painted shading (dark crevices,
lit edges, mottling) is baked straight into the pixels -- no normal maps,
matching the kit spec.

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
COBBLE = np.array([0.505, 0.495, 0.478])
COBBLE_DARK = np.array([0.235, 0.229, 0.220])
PLASTER = np.array([0.910, 0.878, 0.812])
GOLD = np.array([0.831, 0.667, 0.259])
GOLD_DARK = np.array([0.400, 0.290, 0.075])
IRON = np.array([0.165, 0.158, 0.150])   # neutral, faintly warm -- see note in black_iron()
HERALDRY_BLUE = np.array([0.114, 0.169, 0.365])

# Ground. The material bible has no grass or mud swatch, so these are the
# palette colours the zones already use: grass is BUILD_PLAN's locked #6F8F4A
# (ZoneBuilder.GRASS) and mud is ZoneLayouts.MUD. The textures are painted AT
# those colours so a plate tinted to them in Godot comes out unchanged.
GRASS_BASE = np.array([0.440, 0.560, 0.290])
GRASS_DEEP = np.array([0.215, 0.318, 0.150])
GRASS_SUN = np.array([0.700, 0.745, 0.385])
MUD_BASE = np.array([0.420, 0.380, 0.300])
MUD_WET = np.array([0.205, 0.192, 0.165])
MUD_SILT = np.array([0.575, 0.520, 0.415])
MUD_SHEEN = np.array([0.470, 0.540, 0.560])   # sky caught in standing water


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


def _match_mean(rgb, target):
    """Rescale so the texture averages exactly `target`.

    Ground textures are tinted in Godot relative to their palette colour, so
    the painted detail may only move pixels around that colour, never shift
    the whole field darker or lighter -- or every plate renders off-palette.
    """
    mean = rgb.reshape(-1, 3).mean(axis=0)
    return rgb * (np.asarray(target) / np.maximum(mean, 1e-6))[None, None, :]


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
    # Narrow grout. Wider than this and a street reads as a dark net with
    # stones caught in it rather than as paving.
    gap = _smooth(np.clip(border / (0.085 / cells), 0, 1))

    tone = _cell_random(owner, seed, 0.78, 1.18)
    warm = _cell_random(owner, seed + 3, -0.035, 0.035)
    # Spherical profile: height falls off from the sett's centre to its rim, so
    # each stone reads as a rounded pebble instead of a flat polygon.
    radius = np.maximum(best + border, 1e-6)
    p_norm = np.clip(best / radius, 0, 1)
    dome = np.sqrt(np.clip(1.0 - p_norm ** 2, 0, 1))
    shade = 0.66 + dome * 0.42
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


# ----------------------------------------------------------------- ground ---
# Ground plates are hundreds of metres across and seen from above and far off,
# so these lean on broad light-and-shade drifts (which read at distance) over
# fine detail (which only reads underfoot). ZoneBuilder maps them at
# GROUND_TILE_METERS per tile, not the kit's 2m.
GROUND_TILE_METERS = 4.0


def _streaks(size, freq, seed, length, axis=0):
    """Fine noise smeared along one axis -- short painted strokes. Tileable,
    because the smear is a wrap-around rolling mean."""
    n = value_noise(size, freq, seed)
    acc = np.zeros_like(n)
    for step in range(length):
        acc += np.roll(n, step, axis=axis)
    return acc / length


def grass(size=SIZE, seed=241):
    """Meadow grass: sunlit and shaded drifts, clumped tufts with dark roots and
    lit tips, and short blade strokes. No flowers -- the palette has none."""
    drift = fbm(size, 3, seed, octaves=3, gain=0.55)          # the big painted patches
    clumps = fbm(size, 14, seed + 7, octaves=4)
    blades = _streaks(size, 160, seed + 13, length=9)
    speck = value_noise(size, 90, seed + 29)

    # Tufts: the upper part of the clump noise, softened, so grass bunches up
    # rather than sitting as an even carpet.
    tuft = _smooth(np.clip((clumps - 0.42) / 0.32, 0, 1))

    value = 0.84 + (drift - 0.5) * 0.42 + (blades - 0.5) * 0.30
    rgb = _tint(GRASS_BASE, value)

    # Dark between the tufts, lit on their crowns -- the same crevice/edge rule
    # as the stonework, applied to something soft.
    gaps = (1.0 - tuft)[:, :, None]
    rgb = rgb * (1.0 - gaps * 0.34) + GRASS_DEEP[None, None, :] * gaps * 0.34
    tips = (np.clip((blades - 0.58) / 0.2, 0, 1) * tuft)[:, :, None]
    rgb = rgb * (1.0 - tips * 0.45) + GRASS_SUN[None, None, :] * tips * 0.45

    # Warm the sunlit drifts a touch, cool the shaded ones.
    warm = (drift - 0.5) * 0.06
    rgb[:, :, 0] += warm
    rgb[:, :, 2] -= warm * 0.8

    # A scatter of dry flecks so a large field doesn't read as green felt.
    dry = np.clip((speck - 0.9) / 0.1, 0, 1)[:, :, None]
    rgb = rgb * (1.0 - dry * 0.35) + GRASS_SUN[None, None, :] * dry * 0.35
    return _rgba(_match_mean(rgb, GRASS_BASE))


def marsh_mud(size=SIZE, seed=251):
    """Churned marsh mud for Sablemarch: wet black hollows, drier ridged silt,
    ruts pressed through it, and sky caught in the standing water."""
    u, v = _uv(size)
    hollows = fbm(size, 4, seed, octaves=4)
    ridges = np.abs(fbm(size, 9, seed + 5, octaves=3) - 0.5) * 2.0
    grit = fbm(size, 40, seed + 11, octaves=3)
    speck = value_noise(size, 110, seed + 17)

    # Ruts: a few wobbling parallel tracks. Integer frequency across u keeps
    # them tileable; the warp keeps them from being ruled lines.
    warp = (fbm(size, 3, seed + 23, octaves=2) - 0.5) * 1.6
    rut = np.abs(np.sin((u * 3.0 + warp) * np.pi * 2.0))
    rut = 1.0 - _smooth(np.clip(rut / 0.16, 0, 1))                # 1 in the rut

    value = 0.86 + (grit - 0.5) * 0.30
    rgb = _tint(MUD_BASE, value)

    # Crease lines along the ridges: dark in the fold, a lit silty lip beside it.
    crease = (1.0 - _smooth(np.clip(ridges / 0.14, 0, 1)))[:, :, None]
    lip = (_smooth(np.clip((ridges - 0.14) / 0.10, 0, 1))
           * (1.0 - _smooth(np.clip((ridges - 0.30) / 0.12, 0, 1))))[:, :, None]
    rgb = rgb * (1.0 - crease * 0.38) + MUD_WET[None, None, :] * crease * 0.38
    rgb = rgb * (1.0 - lip * 0.30) + MUD_SILT[None, None, :] * lip * 0.30

    # Wet: low ground and the bottoms of ruts go dark and flat.
    wet = np.maximum(_smooth(np.clip((0.44 - hollows) / 0.12, 0, 1)), rut * 0.7)[:, :, None]
    rgb = rgb * (1.0 - wet * 0.62) + MUD_WET[None, None, :] * wet * 0.62

    # Standing water in the deepest hollows keeps a painted sky highlight.
    pool = _smooth(np.clip((0.34 - hollows) / 0.06, 0, 1))
    sheen = (pool * (0.55 + (fbm(size, 6, seed + 31) - 0.5) * 0.6))[:, :, None]
    rgb = rgb * (1.0 - sheen * 0.55) + MUD_SHEEN[None, None, :] * sheen * 0.55

    # Grit: pale stones and dark bits trodden in.
    stones = np.clip((speck - 0.92) / 0.08, 0, 1)[:, :, None] * (1.0 - wet)
    rgb = rgb * (1.0 - stones * 0.5) + MUD_SILT[None, None, :] * stones * 0.5
    return _rgba(_match_mean(rgb, MUD_BASE))


SKIN = np.array([0.741, 0.545, 0.427])
UNDERSUIT = np.array([0.212, 0.224, 0.259])


def skin(size=SIZE, seed=131):
    """Base-body skin: a warm mid tone with soft mottling.

    Deliberately plain. This is the body the armour goes over, and detail
    painted here would fight whatever the class texture puts on top.
    """
    mott = (fbm(size, 6, seed, octaves=5) - 0.5) * 0.10
    fine = (fbm(size, 40, seed + 11, octaves=3) - 0.5) * 0.04
    rgb = _tint(SKIN, 1.0 + mott + fine)
    warm = (fbm(size, 10, seed + 23) - 0.5) * 0.05
    rgb[:, :, 0] += warm
    rgb[:, :, 2] -= warm * 0.6
    return _rgba(rgb)


def undersuit(size=SIZE, seed=137):
    """Dark quilted cloth -- what a character wears under plate."""
    weave = (value_noise(size, 96, seed) - 0.5) * 0.10
    mott = (fbm(size, 8, seed + 7, octaves=4) - 0.5) * 0.22
    # Quilting: a diagonal lattice of seams pressed into the cloth.
    u, v = _uv(size)
    # Sparse and low-contrast. A tighter, harder lattice read as fishnet.
    quilt = np.minimum(
        np.abs(((u + v) * 5.0) % 1.0 - 0.5),
        np.abs(((u - v) * 5.0) % 1.0 - 0.5),
    )
    seam = _smooth(np.clip(quilt / 0.07, 0, 1)) * 0.16 + 0.84
    rgb = _tint(UNDERSUIT, (1.0 + weave + mott) * seam)
    return _rgba(rgb)


def plate(base, seed=151, trim=None, panel=7.0, size=SIZE):
    """Painted armour plate.

    The hand-painted look for metal is a broad sheen across the form plus
    hard panel grooves and chipped, lit edges -- NOT a shiny material. All
    of that is baked here so the shader stays fully rough like the kit's.
    """
    base = np.asarray(base, dtype=float)
    sheen = (fbm(size, 3, seed, octaves=2, gain=0.4) - 0.5) * 0.55
    grain = (fbm(size, 14, seed + 7, octaves=4) - 0.5) * 0.16
    u, v = _uv(size)

    # Panel lines: a grid of grooves with a lit lip on the upper side.
    gx = np.abs((u * panel) % 1.0 - 0.5)
    gy = np.abs((v * panel * 0.7) % 1.0 - 0.5)
    groove = np.minimum(gx, gy)
    dark = 1.0 - 0.42 * (1.0 - _smooth(np.clip(groove / 0.045, 0, 1)))
    lip = 0.26 * _smooth(np.clip((groove - 0.05) / 0.035, 0, 1)) \
        * (1.0 - _smooth(np.clip((groove - 0.10) / 0.05, 0, 1)))

    # Scuffs where a plate would actually catch: sparse bright nicks.
    nick = value_noise(size, 80, seed + 23)
    chips = np.clip((nick - 0.86) / 0.14, 0, 1) * 0.35

    rgb = _tint(base, 1.0 + sheen + grain) * dark[:, :, None]
    rgb += (lip + chips)[:, :, None] * 0.55

    if trim is not None:
        # A band of trim across the top of the sheet, for straps and edging.
        trim = np.asarray(trim, dtype=float)
        band = _smooth(np.clip((0.14 - v) / 0.05, 0, 1))
        trim_rgb = _tint(trim, 1.0 + sheen * 0.6 + grain)
        rgb = rgb * (1 - band[:, :, None]) + trim_rgb * band[:, :, None]

    return _rgba(rgb)


def cloth(base, seed=163, folds=9.0, size=SIZE):
    """Woven cloth with soft vertical folds -- tabards, robes, cloaks."""
    base = np.asarray(base, dtype=float)
    u, v = _uv(size)
    drape = np.sin(u * folds * 2.0 * np.pi
                   + (fbm(size, 3, seed + 5) - 0.5) * 6.0)
    shade = drape * 0.13
    weave = (value_noise(size, 120, seed) - 0.5) * 0.09
    mott = (fbm(size, 7, seed + 11, octaves=4) - 0.5) * 0.16
    # Wear along the hem.
    hem = 1.0 - 0.18 * _smooth(np.clip((v - 0.82) / 0.18, 0, 1))
    return _rgba(_tint(base, (1.0 + shade + weave + mott) * hem))


def leather(base, seed=173, size=SIZE):
    """Weathered leather: soft pebbling, darker in the creases."""
    base = np.asarray(base, dtype=float)
    pebble = (fbm(size, 26, seed, octaves=4) - 0.5) * 0.30
    crease = (fbm(size, 6, seed + 9, octaves=3) - 0.5) * 0.24
    rgb = _tint(base, 1.0 + pebble + crease)
    rgb[:, :, 0] += np.clip(pebble, 0, None) * 0.05
    return _rgba(rgb)


def feather(base=(0.93, 0.93, 0.91), seed=181, rows=11.0, cols=7.0, size=SIZE):
    """Layered feathers, for the Valkyr's wings.

    Same trick as the roof shingles -- overlapping rows with a shadow under
    each course and a lit lower edge -- but softer, and shaped to a point.
    """
    base = np.asarray(base, dtype=float)
    u, v = _uv(size)
    u = u + (fbm(size, 5, seed + 3, octaves=3) - 0.5) * 0.04

    ry = v * rows
    row = np.floor(ry).astype(int)
    by = ry - row
    rx = (u + (row % 2) * 0.5 / cols) * cols
    col = np.floor(rx).astype(int)
    bx = rx - col
    cell = (row % int(rows)) * 8191 + (col % int(cols)) * 131

    # Feather silhouette: rounded at the tip, tapering to the quill.
    taper = np.clip(1.0 - ((np.abs(bx - 0.5) * 2.0) ** 2) * (0.35 + by * 0.9), 0, 1)
    gap = _smooth(np.clip(taper / 0.18, 0, 1))

    overlap = 1.0 - 0.26 * (1.0 - _smooth(np.clip(by / 0.34, 0, 1)))
    lip = 0.22 * _smooth(np.clip((by - 0.74) / 0.24, 0, 1))
    quill = 1.0 - 0.14 * (1.0 - _smooth(np.clip(np.abs(bx - 0.5) / 0.05, 0, 1)))
    tone = _cell_random(cell, seed, 0.90, 1.06)
    barb = np.sin((bx - 0.5) * 40.0 + by * 6.0) * 0.025

    rgb = _tint(base, tone * overlap * quill + lip + barb)
    shadow = base[None, None, :] * 0.52
    g = gap[:, :, None]
    return _rgba(rgb * g + shadow * (1 - g))


def fur(base, seed=191, size=SIZE, clumps=22.0):
    """Fur: clumped strands with dark roots and lit tips."""
    base = np.asarray(base, dtype=float)
    u, v = _uv(size)
    strand = np.sin(u * clumps * 2.0 * np.pi
                    + (fbm(size, 5, seed + 3) - 0.5) * 14.0)
    clump = (fbm(size, 12, seed, octaves=5) - 0.5) * 0.40
    root = 0.72 + 0.36 * _smooth(np.clip(v, 0, 1))
    rgb = _tint(base, (1.0 + strand * 0.14 + clump) * root)
    return _rgba(rgb)


def glow(base, seed=197, size=SIZE):
    """A flat, bright accent colour for runes and arcane light.

    No emission -- the kit has no emissive materials -- so this just sits
    much brighter than everything around it, which reads as glow against
    the dark robes it is used on.
    """
    base = np.asarray(base, dtype=float)
    pulse = (fbm(size, 6, seed, octaves=3) - 0.5) * 0.22
    return _rgba(_tint(base, 1.0 + pulse))


def register(name, builder):
    """Add a parameterised texture under its own name.

    The class textures are all the same few generators with different
    palettes -- plate() in blackened steel for the Valkyr, in brass for the
    Tinker -- so they are registered at build time rather than written out
    as separate functions.
    """
    BUILDERS[name] = builder
    return name


BUILDERS = {
    "skin": skin,
    "undersuit": undersuit,
    "limestone": limestone,
    "slate": slate_roof,
    "timber": timber,
    "cobblestone": cobblestone,
    "plaster": plaster,
    "gold": gold_leaf,
    "iron": black_iron,
    "grass": grass,
    "mud": marsh_mud,
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

