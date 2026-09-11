"""Kingsmourn modular kit -- shared Blender rig.

Everything the per-piece build scripts need: a clean scene, box-shaped mesh
building, world-scale box UV mapping, the shared hand-painted materials, a
preview render rig, and .glb export.

Conventions every piece follows:
  * Blender is Z-up; glTF export converts to Godot's Y-up automatically.
  * A piece sits with its base on Z=0 and is centred on the X axis, so
    placing walls at x = 0, 2, 4 ... butts them together with no gap.
  * All dimensions land on a 1m grid (or clean fractions of it).
  * UVs are box-projected at world scale: 1 texture tile == TILE_METERS,
    so a texture never changes density from one piece to the next.
"""

import os
import math
import numpy as np
import bpy
import bmesh
from mathutils import Vector

import km_textures
from km_textures import TILE_METERS

ROOT = r"C:\Users\tyson\Desktop\MyMMO"
KIT_DIR = os.path.join(ROOT, "godot-project", "assets", "kit")
BLEND_DIR = os.path.join(ROOT, "blender-source")
# Textures are art source, not a game asset: they get packed into each .glb,
# so the Godot project never needs the loose PNGs.
TEX_DIR = os.path.join(BLEND_DIR, "textures")
PREVIEW_DIR = os.path.join(ROOT, "docs", "reference", "kit-previews")

WALL_THICKNESS = 0.30

# +Y is the EXTERIOR face of every wall piece. Dressed detail (sills, jambs,
# lintels, beams) projects out along +Y; the -Y side stays flush because it
# faces the building's interior. Every piece must honour this or a wall run
# ends up with its ornament on the inside.
EXTERIOR = 1.0


# ------------------------------------------------------------------ scene ---
def new_scene():
    """Empty the current scene.

    Deliberately NOT read_factory_settings(): that reloads preferences and
    tears the Blender-MCP addon's server down with it, killing the connection
    this whole build runs over. Clear objects by hand instead.
    """
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    # Actions and armatures must go too. Several characters are built in one
    # Blender process, and a leftover "Idle" makes the next one's action
    # come out as "Idle.001" -- which is then the clip name in the .glb.
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras,
                  bpy.data.lights, bpy.data.worlds, bpy.data.actions,
                  bpy.data.armatures):
        for item in list(block):
            block.remove(item, do_unlink=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    return scene


def purge():
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


# ---------------------------------------------------------------- meshing ---
def box(bm, lo, hi, mat=0, faces_out=None):
    """Add an axis-aligned box spanning lo..hi. Returns its 6 faces."""
    lo, hi = Vector(lo), Vector(hi)
    vs = []
    for z in (lo.z, hi.z):
        for y in (lo.y, hi.y):
            for x in (lo.x, hi.x):
                vs.append(bm.verts.new((x, y, z)))
    idx = [(0, 1, 3, 2), (4, 6, 7, 5),          # bottom, top
           (0, 4, 5, 1), (2, 3, 7, 6),          # -Y, +Y
           (0, 2, 6, 4), (1, 5, 7, 3)]          # -X, +X
    faces = []
    for quad in idx:
        f = bm.faces.new([vs[i] for i in quad])
        f.material_index = mat
        faces.append(f)
    if faces_out is not None:
        faces_out.extend(faces)
    return faces


def prism(bm, profile, extrude_axis, lo, hi, mat=0):
    """Extrude a 2D profile into a solid.

    `profile` is a list of (a, b) points; `extrude_axis` is 'x', 'y' or 'z'
    and the profile lives in the other two axes, in their natural order.
    """
    order = {"x": (1, 2), "y": (0, 2), "z": (0, 1)}[extrude_axis]
    ai = "xyz".index(extrude_axis)

    # Make the far cap face along +axis regardless of how the caller wound
    # the profile. Note the parity: X cross Z is -Y, not +Y, so a profile
    # wound the same way gives an inward normal on the Y axis.
    parity = -1.0 if extrude_axis == "y" else 1.0
    area = 0.0
    for i in range(len(profile)):
        a0, b0 = profile[i]
        a1, b1 = profile[(i + 1) % len(profile)]
        area += a0 * b1 - a1 * b0
    if area * parity < 0:
        profile = list(reversed(profile))

    def pt(p, depth):
        v = [0.0, 0.0, 0.0]
        v[order[0]], v[order[1]] = p
        v[ai] = depth
        return v

    lo_vs = [bm.verts.new(pt(p, lo)) for p in profile]
    hi_vs = [bm.verts.new(pt(p, hi)) for p in profile]
    faces = [bm.faces.new(lo_vs[::-1]), bm.faces.new(hi_vs)]
    n = len(profile)
    for i in range(n):
        j = (i + 1) % n
        faces.append(bm.faces.new([lo_vs[i], lo_vs[j], hi_vs[j], hi_vs[i]]))
    for f in faces:
        f.material_index = mat
    return faces


def strut(bm, p0, p1, width, y0, y1, mat=0):
    """A beam running from p0 to p1 in the XZ plane, `width` across its face
    and spanning y0..y1 in depth. This is what makes diagonal braces cheap."""
    (x0, z0), (x1, z1) = p0, p1
    dx, dz = x1 - x0, z1 - z0
    length = math.hypot(dx, dz)
    ux, uz = dx / length, dz / length
    px, pz = -uz * width / 2.0, ux * width / 2.0
    corners = [(x0 - px, z0 - pz), (x1 - px, z1 - pz),
               (x1 + px, z1 + pz), (x0 + px, z0 + pz)]
    return prism(bm, corners, "y", y0, y1, mat)


def frame(bm, lo, hi, hole_lo, hole_hi, axis, mat=0):
    """A rectangular slab with a rectangular hole -- walls with openings.

    Built as four boxes around the hole so every face stays a clean quad.
    `axis` is the slab's thickness axis ('y' for a wall facing along Y).
    """
    assert axis == "y", "only Y-thickness slabs are needed so far"
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    hx0, hz0 = hole_lo
    hx1, hz1 = hole_hi
    faces = []
    box(bm, (x0, y0, z0), (x1, y1, hz0), mat, faces)          # under
    box(bm, (x0, y0, hz1), (x1, y1, z1), mat, faces)          # over
    box(bm, (x0, y0, hz0), (hx0, y1, hz1), mat, faces)        # left jamb
    box(bm, (hx1, y0, hz0), (x1, y1, hz1), mat, faces)        # right jamb
    return faces


def finish(bm, name, materials, smooth=False, tile=TILE_METERS, rotate_axes=()):
    """Turn a bmesh into a real object: weld, box-UV, assign materials.

    `tile` overrides the world size one texture tile covers, for pieces that
    want a finer grain than the 2m default (a plank door, say).
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

    box_uv(obj, tile=tile, rotate_axes=rotate_axes)
    if not smooth:
        for p in mesh.polygons:
            p.use_smooth = False
    mesh.validate()
    return obj


def sit_on_floor(obj, z=0.0):
    """Drop the piece so its lowest point rests on z.

    Every piece is authored sitting on the floor, and working the offset out
    by hand means re-deriving it whenever a detail like a fascia board grows
    past the bottom. Measure it instead.
    """
    lowest = min((obj.matrix_basis @ v.co).z for v in obj.data.vertices)
    obj.location.z += z - lowest
    return obj


def box_uv(obj, tile=TILE_METERS, rotate_axes=()):
    """World-scale box projection: pick the dominant axis per face, project.

    `rotate_axes` names axes whose faces get their UVs swapped -- used where a
    texture's direction matters (planks running across a door, not up it).
    """
    mesh = obj.data
    uv = mesh.uv_layers.get("UVMap") or mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        n = poly.normal
        axis = max(range(3), key=lambda i: abs(n[i]))

        # Sloped faces (a roof pitch) have no dominant axis. Projecting them
        # down an axis squashes the texture by 1/cos(pitch) -- shingles come
        # out stretched. Map those in the face's own plane instead: u runs
        # horizontally along the face, v straight up the slope.
        if abs(n[axis]) < 0.88:
            up = Vector((0.0, 0.0, 1.0))
            u_dir = Vector(n).cross(up)
            if u_dir.length < 1e-6:
                u_dir = Vector((1.0, 0.0, 0.0))
            u_dir.normalize()
            v_dir = u_dir.cross(Vector(n)).normalized()
            for li in poly.loop_indices:
                co = mesh.vertices[mesh.loops[li].vertex_index].co
                uv.data[li].uv = (co.dot(u_dir) / tile, co.dot(v_dir) / tile)
            continue

        # Project onto the two axes that aren't the face's dominant one,
        # flipping one of them so the mapping isn't mirrored on back faces.
        if axis == 0:      # faces pointing along X -> use Y,Z
            ia, ib = 1, 2
            flip = n.x > 0
        elif axis == 1:    # along Y -> use X,Z
            ia, ib = 0, 2
            flip = n.y < 0
        else:              # along Z -> use X,Y
            ia, ib = 0, 1
            flip = n.z < 0
        swap = "xyz"[axis] in rotate_axes
        for li in poly.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            a, b = co[ia] / tile, co[ib] / tile
            if flip:
                a = -a
            if swap:
                a, b = b, a
            uv.data[li].uv = (a, b)


# -------------------------------------------------------------- materials ---
def material(kind, name=None):
    """A shared hand-painted material. Shading is in the texture, so the
    surface itself is fully rough and non-metallic."""
    name = name or ("KM_%s" % kind)
    existing = bpy.data.materials.get(name)
    if existing:
        return existing

    # Always regenerate rather than reusing whatever PNG is on disk.
    # Generation is ~0.15s, and caching by filename meant a palette change
    # silently did nothing until the old file was deleted by hand.
    path = os.path.join(TEX_DIR, "km_%s.png" % kind)
    km_textures.save_png(km_textures.BUILDERS[kind](), path)

    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.18

    img = bpy.data.images.load(path, check_existing=True)
    img.pack()                      # so the .glb is self-contained
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Smart"
    tex.location = (-400, 200)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def materials(*kinds):
    return [material(k) for k in kinds]


# ----------------------------------------------------------------- render ---
def preview_rig(target_size=3.0, ground=True):
    """Sunlit, bright, heraldic -- the lighting the reference art implies."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.film_transparent = False
    scene.render.resolution_x = 900
    scene.render.resolution_y = 760
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"

    world = bpy.data.worlds.new("KM_World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.50, 0.58, 0.72, 1.0)   # sky bounce
    bg.inputs["Strength"].default_value = 0.55

    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.4
    sun.data.angle = math.radians(6.0)
    sun.data.color = (1.0, 0.96, 0.88)
    sun.rotation_euler = (math.radians(54), 0, math.radians(38))
    bpy.context.collection.objects.link(sun)

    fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "AREA"))
    fill.data.energy = 140.0
    fill.data.size = 8.0
    fill.data.color = (0.82, 0.87, 1.0)
    fill.location = (-6.0, 5.0, 3.5)
    fill.rotation_euler = (math.radians(65), 0, math.radians(-140))
    bpy.context.collection.objects.link(fill)

    # Ground pieces have their own top surface at z=0, which is exactly where
    # this plane is -- they z-fight and the piece vanishes. Those previews
    # turn it off.
    if not ground:
        return scene

    ground = bpy.data.meshes.new("Ground")
    bm = bmesh.new()
    box(bm, (-14, -14, -0.12), (14, 14, 0.0))
    bm.to_mesh(ground)
    bm.free()
    gobj = bpy.data.objects.new("Ground", ground)
    gmat = bpy.data.materials.new("KM_Ground")
    gmat.use_nodes = True
    gbsdf = gmat.node_tree.nodes["Principled BSDF"]
    gbsdf.inputs["Base Color"].default_value = (0.44, 0.47, 0.38, 1.0)
    gbsdf.inputs["Roughness"].default_value = 1.0
    ground.materials.append(gmat)
    bpy.context.collection.objects.link(gobj)
    return scene


def _camera(location, look_at):
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 52
    cam = bpy.data.objects.new("Cam", cam_data)
    cam.location = location
    direction = Vector(look_at) - Vector(location)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    return cam


def _bounds(objs):
    pts = []
    for o in objs:
        for c in o.bound_box:
            pts.append(o.matrix_world @ Vector(c))
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def repeat_objs(objs, count, offset):
    """Linked duplicates of a piece, stepped along `offset`.

    The honest test of a modular piece: if copies don't butt together
    invisibly, it isn't finished.
    """
    made = []
    for i in range(1, count):
        for o in objs:
            dup = o.copy()          # linked data -- same mesh, new transform
            dup.location = Vector(o.location) + Vector(offset) * i
            bpy.context.collection.objects.link(dup)
            made.append(dup)
    # Flush the new transforms, or matrix_world stays at the origin and the
    # preview camera frames the row as though it were a single piece.
    bpy.context.view_layer.update()
    return made


def _render_strip(objs, angles, elevation, margin=1.55, res=None):
    """Render the piece from a few yaw angles; return the stitched pixels."""
    scene = bpy.context.scene
    saved = (scene.render.resolution_x, scene.render.resolution_y)
    if res:
        scene.render.resolution_x, scene.render.resolution_y = res
    lo, hi = _bounds(objs)
    centre = (lo + hi) * 0.5
    radius = max((hi - lo).length * 0.5, 0.5)
    dist = radius * margin / math.tan(math.radians(26))
    dist = max(dist, radius * 2.0)

    frames = []
    tmp = os.path.join(PREVIEW_DIR, "_tmp_view.png")
    for yaw in angles:
        el = math.radians(elevation)
        az = math.radians(yaw)
        loc = centre + Vector((math.cos(az) * math.cos(el),
                               math.sin(az) * math.cos(el),
                               math.sin(el))) * dist
        cam = _camera(loc, centre)
        bpy.context.scene.render.filepath = tmp
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(tmp)
        w, h = img.size
        px = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        frames.append(np.flipud(px.reshape(h, w, 4)))
        bpy.data.images.remove(img)
        bpy.data.objects.remove(cam, do_unlink=True)

    if os.path.exists(tmp):
        os.remove(tmp)
    scene.render.resolution_x, scene.render.resolution_y = saved
    gap = np.ones((frames[0].shape[0], 8, 4))
    strip = frames[0]
    for f in frames[1:]:
        strip = np.concatenate([strip, gap, f], axis=1)
    strip[:, :, 3] = 1.0
    return strip


def render_views(objs, out_path, angles=(38, -128), elevation=26,
                 repeat=None):
    """Preview image: the piece from a couple of angles, plus -- if the piece
    is meant to repeat -- a row of copies proving the seams disappear."""
    strip = _render_strip(objs, angles, elevation)

    if repeat:
        # (count, offset) or (count, offset, yaw) for the row shot.
        count, offset = repeat[0], repeat[1]
        row_yaw = repeat[2] if len(repeat) > 2 else 34
        dups = repeat_objs(objs, count, offset)
        row = _render_strip(objs + dups, (row_yaw,), elevation, res=(1808, 620))
        for d in dups:
            bpy.data.objects.remove(d, do_unlink=True)
        # Pad the narrower strip so the two rows stack.
        w = max(strip.shape[1], row.shape[1])
        def pad(a):
            if a.shape[1] == w:
                return a
            fill = np.ones((a.shape[0], w - a.shape[1], 4))
            return np.concatenate([a, fill], axis=1)
        strip = np.concatenate([pad(strip), np.ones((8, w, 4)), pad(row)], axis=0)
        strip[:, :, 3] = 1.0

    km_textures.save_png(strip, out_path)
    return out_path


# ----------------------------------------------------------------- export ---
def export_glb(objs, name, subdir="kit", apply_modifiers=True):
    """Export the given objects as one self-contained .glb under assets/.

    `apply_modifiers` must be False for rigged characters: applying an
    armature modifier bakes the rest pose into the mesh and throws the skin
    binding away.
    """
    out_dir = os.path.join(ROOT, "godot-project", "assets", subdir)
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, name + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=apply_modifiers,
        export_yup=True,
        export_image_format="AUTO",
    )
    return path


def save_blend(name):
    path = os.path.join(BLEND_DIR, name + ".blend")
    bpy.ops.wm.save_as_mainfile(filepath=path, copy=True)
    return path


def report(objs):
    meshes = [o for o in objs if o.type == "MESH"]
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
    lo, hi = _bounds(meshes or objs)
    size = hi - lo
    return "tris=%d  size=%.2f x %.2f x %.2f m  base_z=%.3f" % (
        tris, size.x, size.y, size.z, lo.z)
