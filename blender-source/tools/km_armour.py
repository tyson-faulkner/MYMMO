"""Armour pieces built over the shared body.

Each class is the same base mesh with armour added on top, so these helpers
work in the body's coordinates and are shaped to sit just outside its
surface. Armour is added into the SAME mesh as the body and skinned by the
same distance weighting, which means a pauldron follows the shoulder
without any extra rigging.

Everything here is built from the same ring sweeps as the body -- plates
are short, wide, flattened tubes; skirts are tapering ones.
"""

import math
from mathutils import Vector

import km_char as C


def shell(bm, uv, sections, u, v, n, mat, cap_start=False, cap_end=False):
    """A plate shell over a limb or the torso -- an open tube by default,
    since armour is a surface laid over the body, not a closed solid."""
    return C.tube(bm, uv, sections, u, v, n, mat=mat,
                  cap_start=cap_start, cap_end=cap_end)


def pauldron(bm, uv, side, centre, radius, drop, mat, n=8, flare=1.35):
    """A shoulder plate: a dome that flares outward and hangs down.

    The single biggest silhouette element on a heavy class, which is why it
    gets its own helper rather than being hand-built per class.
    """
    cx, cy, cz = centre
    sections = []
    steps = 5
    for i in range(steps):
        t = i / (steps - 1.0)
        # Sweep outward along the arm while dropping and widening.
        x = cx + side * (0.02 + t * 0.14)
        z = cz + 0.05 - t * drop
        r = radius * (1.0 - 0.55 * t * t) * (1.0 + (flare - 1.0) * t)
        sections.append(((x, cy, z), r * 1.05, r))
    return C.tube(bm, uv, sections, C.Y, C.Z, n, mat=mat,
                  cap_start=True, cap_end=False)


def skirt(bm, uv, top_z, bottom_z, top_r, bottom_r, mat, n=12, y_off=0.0):
    """Faulds, tassets, a robe hem -- a flaring open cone around the hips.

    The hem is what reads at distance on the robed classes, so it gets a
    real flare rather than hanging straight.
    """
    sections = [
        ((0, y_off, top_z), top_r * 1.18, top_r),
        ((0, y_off, top_z - (top_z - bottom_z) * 0.45),
         (top_r + (bottom_r - top_r) * 0.45) * 1.18,
         top_r + (bottom_r - top_r) * 0.45),
        ((0, y_off, bottom_z), bottom_r * 1.18, bottom_r),
    ]
    return C.tube(bm, uv, sections, C.X, C.Y, n, mat=mat,
                  cap_start=False, cap_end=False)


def collar(bm, uv, z, radius, height, mat, n=12):
    """A raised gorget or hood collar around the neck."""
    sections = [
        ((0, 0, z), radius * 1.1, radius),
        ((0, -0.01, z + height), radius * 1.35, radius * 1.25),
    ]
    return C.tube(bm, uv, sections, C.X, C.Y, n, mat=mat,
                  cap_start=False, cap_end=False)


def wing(bm, uv, side, root, span, mat, n=6, feathers=6, thickness=0.014):
    """A wing spread up and back from the shoulder blades.

    A fan of broad, flat, overlapping blades radiating from one root. Each
    blade is a tube whose cross-section is wide across the wing and thin
    through it, so the wing is a surface rather than a bundle of spines --
    an earlier pass used narrow round tubes and read as antennae.

    The blades overlap near the root and separate towards the tips, which
    is what gives the stepped feathered edge the silhouette needs.
    """
    rx, ry, rz = root
    made = []
    for f in range(feathers):
        t = f / max(feathers - 1.0, 1.0)

        # Sweep from steep at the inner edge to nearly horizontal at the
        # outer tip, and get LONGER outward -- primaries are the long ones.
        # Peaking the length in the middle instead made a sunburst.
        angle = math.radians(26.0 + 62.0 * t)
        length = span * (0.52 + 0.48 * t)
        # Wide enough that neighbouring blades still overlap at the tips;
        # narrower blades left daylight between them.
        width = 0.115 * (1.0 - 0.22 * t)
        back = 0.10 + 0.16 * t

        direction = Vector((math.sin(angle) * side, 0.0, math.cos(angle)))
        # In-plane perpendicular: the direction the blade is WIDE along.
        across = Vector((math.cos(angle) * side, 0.0, -math.sin(angle)))

        base = Vector((rx, ry, rz))
        sections = []
        for s, w in ((0.06, 0.55), (0.40, 1.00), (0.76, 0.80), (1.00, 0.12)):
            centre = base + direction * (length * s) + C.Y * (-back * s)
            sections.append((centre, thickness, width * w))
        # v_scale stretches the feather texture along the blade. At 1:1 a
        # metre-long blade showed eleven courses of feathers and read as a
        # caterpillar; this puts three or four down its length.
        made.append(C.tube(bm, uv, sections, C.Y, across, n, mat=mat,
                           cap_start=True, cap_end=True, v_scale=0.30))

    # Coverts: one short wide blade closing the gap at the root, so the
    # wing meets the back as a surface rather than as six separate spokes.
    root_dir = Vector((math.sin(math.radians(48)) * side, 0.0,
                       math.cos(math.radians(48))))
    root_across = Vector((math.cos(math.radians(48)) * side, 0.0,
                          -math.sin(math.radians(48))))
    base = Vector((rx, ry, rz))
    made.append(C.tube(bm, uv, [
        (base - root_dir * 0.04, thickness * 1.2, 0.11),
        (base + root_dir * (span * 0.26) + C.Y * -0.06, thickness * 1.2, 0.185),
        (base + root_dir * (span * 0.48) + C.Y * -0.10, thickness, 0.135),
    ], C.Y, root_across, n, mat=mat, cap_start=True, cap_end=True, v_scale=0.30))
    return made


def hood(bm, uv, mat, n=12, peak=1.90, back=-0.06):
    """A raised hood over the head, open at the face.

    The Necromancer's whole read is "hood up, long ragged hem", so the hood
    needs to rise to a point above the skull and sit proud of it, not wrap
    it like a swim cap.
    """
    sections = [
        ((0, back * 0.4, 1.50), 0.140, 0.135),
        ((0, back * 0.7, 1.60), 0.150, 0.152),
        ((0, back, 1.70), 0.146, 0.155),
        ((0, back * 1.5, 1.80), 0.118, 0.130),
        ((0, back * 2.4, peak - 0.03), 0.062, 0.075),
        ((0, back * 3.2, peak), 0.018, 0.022),
    ]
    return C.tube(bm, uv, sections, C.X, C.Y, n, mat=mat,
                  cap_start=False, cap_end=True)


def ragged_hem(bm, uv, mat, top_z, lengths, radius, n=5, y_scale=1.0,
               blade_width=0.075):
    """A skirt hem torn into hanging points.

    Made of separate tapered blades rather than one cone with a zigzag edge:
    the gaps between them are what read as "ragged" in silhouette, and the
    silhouette is the point.
    """
    import math
    made = []
    count = len(lengths)
    for i, length in enumerate(lengths):
        angle = 2.0 * math.pi * i / count
        dx, dy = math.cos(angle), math.sin(angle) * y_scale
        cx, cy = dx * radius, dy * radius
        # Splay outwards slightly as it falls, so the hem flares.
        tip = (cx * 1.22, cy * 1.22, top_z - length)
        sections = [
            ((cx, cy, top_z), blade_width, 0.022),
            ((cx * 1.08, cy * 1.08, top_z - length * 0.55),
             blade_width * 0.95, 0.020),
            ((tip[0], tip[1], tip[2] + length * 0.18),
             blade_width * 0.6, 0.017),
            (tip, blade_width * 0.10, 0.010),
        ]
        # Ring plane is horizontal-ish: wide tangentially, thin radially.
        across = Vector((-dy, dx, 0.0)).normalized()
        radial = Vector((dx, dy, 0.0)).normalized()
        made.append(C.tube(bm, uv, sections, across, radial, n, mat=mat,
                           cap_start=True, cap_end=True, v_scale=0.5))
    return made


def pack(bm, uv, mat, accent_mat, centre=(0.0, -0.20, 1.30)):
    """A tool pack across the shoulder blades -- the Tinker's silhouette.

    The spec says the Tinker is bulky at the BACK, not the shoulders, so
    this is what distinguishes him from the Valkyr at distance.
    """
    cx, cy, cz = centre
    made = []
    # Main crate.
    made.append(C.tube(bm, uv, [
        ((cx, cy + 0.06, cz - 0.20), 0.150, 0.070),
        ((cx, cy, cz), 0.168, 0.090),
        ((cx, cy + 0.02, cz + 0.20), 0.140, 0.072),
    ], C.X, C.Y, 8, mat=mat, cap_start=True, cap_end=True))

    # Canisters either side, and a stack pipe over one shoulder.
    for side in (-1, 1):
        made.append(C.tube(bm, uv, [
            ((cx + side * 0.115, cy - 0.055, cz - 0.17), 0.042, 0.042),
            ((cx + side * 0.115, cy - 0.055, cz + 0.10), 0.042, 0.042),
        ], C.X, C.Y, 8, mat=accent_mat, cap_start=True, cap_end=True))
    # Exhaust stack, set well out to one side. Closer in it stood right
    # beside the head and read as part of the neck.
    made.append(C.tube(bm, uv, [
        ((cx + 0.148, cy - 0.03, cz + 0.14), 0.034, 0.034),
        ((cx + 0.156, cy - 0.01, cz + 0.36), 0.030, 0.030),
        ((cx + 0.156, cy - 0.01, cz + 0.42), 0.042, 0.042),
    ], C.X, C.Y, 8, mat=accent_mat, cap_start=True, cap_end=True))
    return made


def mantle(bm, uv, mat, z=1.45, radius=0.24, n=14, lobes=9):
    """A thick fur ruff over the shoulders.

    Built as a ring of overlapping lobes so the outline is clumpy rather
    than a smooth doughnut -- fur has to break its own silhouette or it
    reads as a life ring.
    """
    import math
    made = []
    for i in range(lobes):
        angle = 2.0 * math.pi * i / lobes
        dx, dy = math.cos(angle), math.sin(angle) * 0.72
        cx, cy = dx * radius, dy * radius
        drop = 0.10 + 0.05 * ((i * 7) % 3) / 2.0
        made.append(C.tube(bm, uv, [
            ((cx * 0.72, cy * 0.72, z + 0.075), 0.075, 0.060),
            ((cx, cy, z), 0.092, 0.075),
            ((cx * 1.05, cy * 1.05, z - drop), 0.062, 0.050),
        ], Vector((-dy, dx, 0.0)).normalized(),
            Vector((dx, dy, 0.0)).normalized(), 6, mat=mat,
            cap_start=True, cap_end=True, v_scale=0.6))
    return made


def beard(bm, uv, mat, n=10, length=1.46, fullness=1.0):
    """A full beard hanging from the jaw, and the hair to match.

    Both the Bard and the Tinker reference sheets have one, and it is the
    cheapest way to stop two characters sharing a body from reading as the
    same bald head in different coats.
    """
    made = []
    made.append(C.tube(bm, uv, [
        ((0, 0.050, 1.665), 0.098 * fullness, 0.072),
        ((0, 0.066, 1.600), 0.112 * fullness, 0.090),
        ((0, 0.066, 1.530), 0.098 * fullness, 0.082),
        ((0, 0.058, length), 0.050 * fullness, 0.045),
    ], C.X, C.Y, n, mat=mat, cap_start=False, cap_end=True, v_scale=0.8))

    # Hair: a cap over the crown falling to the nape.
    made.append(C.tube(bm, uv, [
        ((0, -0.004, 1.805), 0.060, 0.062),
        ((0, -0.010, 1.760), 0.108, 0.114),
        ((0, -0.026, 1.690), 0.112, 0.120),
        ((0, -0.046, 1.620), 0.098, 0.100),
    ], C.X, C.Y, n, mat=mat, cap_start=True, cap_end=False, v_scale=0.8))
    return made


def halo(bm, uv, centre, radius, thickness, mat, n=16):
    """A thin ring standing behind the head."""
    cx, cy, cz = centre
    verts_outer = []
    for i in range(n):
        a = 2.0 * math.pi * i / n
        p = Vector((cx + math.cos(a) * radius, cy, cz + math.sin(a) * radius))
        verts_outer.append((p, Vector((math.cos(a), 0.0, math.sin(a)))))

    sections = []
    for p, radial in verts_outer:
        sections.append((p, radial))

    rings = []
    for p, radial in sections:
        quad = [
            p + radial * thickness + C.Y * thickness * 0.5,
            p - radial * thickness + C.Y * thickness * 0.5,
            p - radial * thickness - C.Y * thickness * 0.5,
            p + radial * thickness - C.Y * thickness * 0.5,
        ]
        rings.append([bm.verts.new(q) for q in quad])

    for i in range(n):
        j = (i + 1) % n
        for k in range(4):
            m = (k + 1) % 4
            f = bm.faces.new([rings[i][k], rings[i][m], rings[j][m], rings[j][k]])
            f.material_index = mat
            f.smooth = True
            for loop, coord in zip(f.loops, [(0, 0), (1, 0), (1, 1), (0, 1)]):
                loop[uv].uv = coord
    return rings
