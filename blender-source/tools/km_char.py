"""Ironveil character rig -- shared machinery for the people.

The kit is built out of boxes; bodies are built out of rings. Every limb and
the torso are generalised cylinders: a list of cross-sections swept along a
path and bridged into quads. That gives three things the kit's box modelling
cannot:

  * clean quad loops exactly where the spec wants them (shoulder, elbow,
    hip, knee), because a ring IS an edge loop;
  * cylindrical UVs for free, since each ring already carries its own
    parametric coordinate -- no unwrapping guesswork on an organic shape;
  * proportions driven by numbers, so "7 heads tall" is a constant rather
    than something eyeballed.

Conventions (from docs/ironveil-character-spec.md):
  * 1 unit = 1 metre, character ~1.8m, origin between the feet at z=0.
  * Blender Z-up, facing +Y. glTF export turns that into Godot's Y-up
    facing -Z, which is Godot's forward.
  * T-pose, so armour can be fitted by eye against the reference sheets.
"""

import math
import bpy
import bmesh
from mathutils import Vector, Matrix

import km_kit as K

HEIGHT = 1.80
HEADS = 7.0
HEAD = HEIGHT / HEADS          # one head unit, ~0.257m

CHAR_DIR = None                # set by km_kit paths below
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))


# ------------------------------------------------------------------ rings ---
def ring(centre, u, v, a, b, n, twist=0.0):
    """One elliptical cross-section: n points around `centre` in the plane
    spanned by u and v, with semi-axes a (along u) and b (along v)."""
    centre = Vector(centre)
    pts = []
    for i in range(n):
        t = twist + 2.0 * math.pi * i / n
        pts.append(centre + u * (math.cos(t) * a) + v * (math.sin(t) * b))
    return pts


def tube(bm, uv_layer, sections, u, v, n, mat=0,
         cap_start=True, cap_end=True, u_offset=0.0, v_scale=1.0):
    """Sweep `sections` into a quad tube and return its rings.

    Each section is (centre, a, b). UVs run around the tube in U and along
    it in V, measured in metres so texture density matches the kit's.

    `mat` may be a single index or one index per span between sections, so
    a limb can change material partway along (a sleeve ending at the elbow)
    without being split into two tubes and gaining a seam.
    """
    spans = len(sections) - 1
    mats = list(mat) if isinstance(mat, (list, tuple)) else [mat] * spans
    rings = [ring(c, u, v, a, b, n) for (c, a, b) in sections]
    verts = [[bm.verts.new(p) for p in r] for r in rings]

    # Arc length along the tube, for the V coordinate.
    lengths = [0.0]
    for i in range(1, len(sections)):
        lengths.append(lengths[-1] + (Vector(sections[i][0])
                                      - Vector(sections[i - 1][0])).length)

    for i in range(len(rings) - 1):
        for j in range(n):
            k = (j + 1) % n
            f = bm.faces.new([verts[i][j], verts[i][k],
                              verts[i + 1][k], verts[i + 1][j]])
            f.material_index = mats[i]
            f.smooth = True
            # j+1 rather than k on the seam, so U doesn't wrap to zero.
            us = [j / n + u_offset, (j + 1) / n + u_offset,
                  (j + 1) / n + u_offset, j / n + u_offset]
            vs = [lengths[i] * v_scale, lengths[i] * v_scale,
                  lengths[i + 1] * v_scale, lengths[i + 1] * v_scale]
            for loop, uu, vv in zip(f.loops, us, vs):
                loop[uv_layer].uv = (uu, vv)

    for do_cap, idx, flip in ((cap_start, 0, True), (cap_end, len(rings) - 1, False)):
        if not do_cap:
            continue
        vs = verts[idx][::-1] if flip else verts[idx]
        f = bm.faces.new(vs)
        f.material_index = mats[0] if idx == 0 else mats[-1]
        for loop in f.loops:
            p = loop.vert.co
            loop[uv_layer].uv = (p.dot(u) * v_scale, p.dot(v) * v_scale)

    return verts


def taper_box(bm, uv_layer, centre, u, v, w, size0, size1, length, mat=0):
    """A tapered box along `w` -- hands and feet, which read better blocky
    than round at this poly count."""
    centre = Vector(centre)
    sections = []
    for t, (a, b) in ((0.0, size0), (1.0, size1)):
        sections.append((centre + w * (length * t), a, b))
    rings = []
    for c, a, b in sections:
        rings.append([c + u * sx * a + v * sy * b
                      for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    verts = [[bm.verts.new(p) for p in r] for r in rings]
    for i in range(4):
        j = (i + 1) % 4
        f = bm.faces.new([verts[0][i], verts[0][j], verts[1][j], verts[1][i]])
        f.material_index = mat
        # Blocky on purpose: smooth shading rounds a four-sided box into
        # mush, and hands and feet need their edges.
        f.smooth = False
        for loop, uv in zip(f.loops, [(i / 4, 0), ((i + 1) / 4, 0),
                                      ((i + 1) / 4, length), (i / 4, length)]):
            loop[uv_layer].uv = uv
    for vs, flip in ((verts[0], True), (verts[1], False)):
        f = bm.faces.new(vs[::-1] if flip else vs)
        f.material_index = mat
        f.smooth = False
        for loop in f.loops:
            p = loop.vert.co
            loop[uv_layer].uv = (p.dot(u), p.dot(v))
    return verts


# ----------------------------------------------------------------- finish ---
def finish_char(bm, name, materials):
    """Mesh out a character bmesh, keeping the UVs built during sweeping.

    Per-face smoothing set during construction is preserved -- swept limbs
    are smooth, blocky hands and feet are flat -- so nothing overrides it
    here the way the kit's finish() does.
    """
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.normal_update()
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for m in materials:
        obj.data.materials.append(m)
    mesh.validate()
    return obj


SIDES = (-1, 1)   # build limbs in a loop over this so the halves can't drift
