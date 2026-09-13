# ZoneBuilder — puts the physical world together from a short list of shapes.
#
# Why build geometry from a script instead of placing thousands of nodes by
# hand: a blockout written as data is something the build loop can extend in
# one line, and every piece here is a PLACEHOLDER with a swap-in point. When the
# modular kit from docs/kingsmourn-kit-spec.md exists, each entry stops being a
# tinted box and starts being a .glb, without the zone layout changing at all.
#
# The palette is the one the design doc locked: cream stone, blue slate roofs,
# warm timber, gold heraldry, green farmland. Bright and painted, never grey.
class_name ZoneBuilder
extends Node3D

const STONE := Color(0.85, 0.80, 0.70)
const STONE_DARK := Color(0.68, 0.63, 0.55)
const SLATE := Color(0.24, 0.36, 0.54)
const TIMBER := Color(0.42, 0.29, 0.18)
const PLASTER := Color(0.90, 0.87, 0.79)
const GOLD := Color(0.79, 0.64, 0.15)
const GRASS := Color(0.44, 0.56, 0.29)
const GRASS_DARK := Color(0.34, 0.45, 0.24)
const COBBLE := Color(0.55, 0.53, 0.50)
const ROAD := Color(0.50, 0.42, 0.32)
const BARROW := Color(0.35, 0.36, 0.38)
const WATER := Color(0.28, 0.45, 0.58)

## Which layout to build. Each one is a static function below returning a list
## of shape dictionaries.
@export_enum(
	"thornhollow_vale",
	"barrow_interior",
	"sablemarch",
	"redoubt_interior",
	"kingsmourn",
	"royal_crypt_interior",
	"hall_of_records_interior",
	"throne_interior"
) var layout: String = "thornhollow_vale"

## Logical piece name -> the file the Blender kit exports for it. A piece that
## doesn't exist yet simply falls back to its tinted box, so the town upgrades
## itself one piece at a time as the kit is built. Nothing here has to change
## when a new piece lands — only this table.
const KIT := {
	"wall": "res://assets/kit/wall_stone_2x3.glb",
	"wall_window": "res://assets/kit/wall_stone_window_2x3.glb",
	"wall_door": "res://assets/kit/wall_stone_door_2x3.glb",
	"wall_timber": "res://assets/kit/wall_timber_2x3.glb",
	"roof_slope": "res://assets/kit/roof_slate_slope_2m.glb",
	"roof_ridge": "res://assets/kit/roof_slate_ridge_2m.glb",
	"roof_corner": "res://assets/kit/roof_slate_corner.glb",
	"street": "res://assets/kit/street_cobble_2x2.glb",
	"stair": "res://assets/kit/stair_stone_2m.glb",
	"low_wall": "res://assets/kit/wall_low_2m.glb",
	"lamp": "res://assets/kit/lamp_iron.glb",
	"stall": "res://assets/kit/market_stall.glb",
	"tree": "res://assets/kit/tree_round.glb",
	"fountain": "res://assets/kit/fountain.glb"
}

## Painted ground textures from blender-source/tools/km_textures.py, laid over
## the ground plates. Each is painted AT its palette colour ("base"), so a plate
## of that colour shows the texture unchanged and a darker plate of the same
## ground tints it down instead of needing a texture of its own. A missing file
## falls back to the flat colour, same as the kit.
const GROUND_TEXTURES := {
	"grass": {"path": "res://assets/textures/ground/km_grass.png", "base": GRASS},
	"mud": {"path": "res://assets/textures/ground/km_mud.png", "base": Color(0.42, 0.38, 0.30)}
}

## World metres per texture tile. Matches GROUND_TILE_METERS in km_textures.py.
## Mapped in world space, so neighbouring plates line up with no seam.
const GROUND_TILE_METERS := 4.0

## Kit pieces are modelled 2m wide and 3m tall, origin at the base centre, with
## the dressed exterior face pointing -Z. Everything below is laid out on that.
const SECTION_WIDTH := 2.0
const SECTION_HEIGHT := 3.0

var _materials: Dictionary = {}
var _kit_cache: Dictionary = {}


## Answered once per run and remembered, because the layout asks it constantly.
static var _kit_ready: Dictionary = {}


## True once Blender has exported this piece AND the export is actually usable.
##
## Checking the path alone is not enough. A half-written or failed export still
## leaves a file behind, ResourceLoader.exists() says yes, and the town then
## assembles itself out of nothing — invisible walls you can still collide with,
## which is a miserable thing to debug. So the piece has to load and contain
## real geometry before the layout is allowed to depend on it.
static func kit_has(piece: String) -> bool:
	if _kit_ready.has(piece):
		return _kit_ready[piece]
	var path: String = str(KIT.get(piece, ""))
	var ready := false
	if not path.is_empty() and ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene:
			var probe := scene.instantiate()
			if probe:
				ready = _has_geometry(probe)
				probe.queue_free()
	_kit_ready[piece] = ready
	return ready


static func _has_geometry(node: Node) -> bool:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance and mesh_instance.mesh and mesh_instance.mesh.get_surface_count() > 0:
			return true
	return false


func _kit_scene(piece: String) -> PackedScene:
	if _kit_cache.has(piece):
		return _kit_cache[piece]
	var scene: PackedScene = null
	if kit_has(piece):
		scene = load(str(KIT[piece])) as PackedScene
	_kit_cache[piece] = scene
	return scene


func _ready() -> void:
	var pieces: Array = []
	match layout:
		"thornhollow_vale":
			pieces = thornhollow_vale()
		"barrow_interior":
			pieces = barrow_interior()
		# Zones two and three, and their interiors, live in ZoneLayouts. Keeping
		# them out of this file means the desktop's Blender work on the kit
		# never collides with content work on the zones. They are listed by name
		# rather than looked up dynamically because GDScript will not call a
		# static function on a class by string.
		"sablemarch":
			pieces = ZoneLayouts.sablemarch()
		"redoubt_interior":
			pieces = ZoneLayouts.redoubt_interior()
		"kingsmourn":
			pieces = ZoneLayouts.kingsmourn()
		"royal_crypt_interior":
			pieces = ZoneLayouts.royal_crypt_interior()
		"hall_of_records_interior":
			pieces = ZoneLayouts.hall_of_records_interior()
		"throne_interior":
			pieces = ZoneLayouts.throne_interior()
		_:
			push_warning("ZoneBuilder: no layout named '%s'" % layout)
	for piece in pieces:
		_build_piece(piece)
	if layout == "thornhollow_vale":
		_pave_thornhollow()


## The square and the two roads, paved once the cobble piece exists. The flat
## slabs underneath stay: they are what you actually stand on.
func _pave_thornhollow() -> void:
	if not kit_has("street"):
		return
	_build_tiled_floor("street", Vector3(0, 0.25, 0), 46.0, 40.0)
	_build_tiled_floor("street", Vector3(0, 0.16, 40), 9.0, 120.0)
	_build_tiled_floor("street", Vector3(0, 0.16, -90), 7.0, 150.0)
	_build_tiled_floor("street", Vector3(0, 0.16, -112), 16.0, 14.0)


# A piece is {pos, size, color, solid, rot} — solid defaults to true, meaning it
# gets collision and you can stand on it. A piece may also carry {kit: "wall"},
# in which case the real model is used when it exists and the box when it
# doesn't, and {texture: "grass"}, which paints a GROUND_TEXTURES entry over it.
func _build_piece(piece: Dictionary) -> void:
	var kit_name := str(piece.get("kit", ""))
	if not kit_name.is_empty():
		var scene := _kit_scene(kit_name)
		if scene:
			_build_kit_piece(scene, piece)
			return
		# No model yet: fall through and draw the placeholder box.

	var size: Vector3 = piece.get("size", Vector3.ONE)
	var position: Vector3 = piece.get("pos", Vector3.ZERO)
	var color: Color = piece.get("color", STONE)
	var solid: bool = piece.get("solid", true)
	var rotation_y: float = float(piece.get("rot", 0.0))

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = _material_for(color, str(piece.get("texture", "")))

	if not solid:
		mesh_instance.position = position
		mesh_instance.rotation.y = rotation_y
		add_child(mesh_instance)
		return

	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.position = position
	body.rotation.y = rotation_y
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(mesh_instance)
	body.add_child(shape)
	add_child(body)


# Instance a real kit model, and give it collision from its own bounds so you
# can walk into a wall that was exported an hour ago.
func _build_kit_piece(scene: PackedScene, piece: Dictionary) -> void:
	var model := scene.instantiate() as Node3D
	if model == null:
		return
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.position = piece.get("pos", Vector3.ZERO)
	body.rotation.y = float(piece.get("rot", 0.0))
	body.add_child(model)

	var bounds: AABB = _model_bounds(model)
	if bounds.size.length() > 0.01:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = bounds.size
		shape.shape = box
		shape.position = bounds.position + bounds.size * 0.5
		body.add_child(shape)
	add_child(body)


func _model_bounds(model: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var piece_bounds := mesh_instance.transform * mesh_instance.mesh.get_aabb()
		if first:
			bounds = piece_bounds
			first = false
		else:
			bounds = bounds.merge(piece_bounds)
	return bounds


## Cover a rectangle with a tiling kit piece.
##
## The square and the roads need around a thousand cobbles between them. A
## thousand StaticBody3D nodes would be absurd for something you only ever walk
## on, so this draws them as ONE MultiMesh — one node, one draw call, thousands
## of copies — and leaves collision to the flat slab already underneath.
func _build_tiled_floor(piece: String, centre: Vector3, size_x: float, size_z: float) -> void:
	var scene := _kit_scene(piece)
	if scene == null:
		return
	var sample := scene.instantiate() as Node3D
	if sample == null:
		return
	var source: MeshInstance3D = null
	for child in sample.find_children("*", "MeshInstance3D", true, false):
		var candidate := child as MeshInstance3D
		if candidate and candidate.mesh:
			source = candidate
			break
	if source == null:
		sample.queue_free()
		return

	var columns := maxi(1, int(ceil(size_x / SECTION_WIDTH)))
	var rows := maxi(1, int(ceil(size_z / SECTION_WIDTH)))

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = source.mesh
	multimesh.instance_count = columns * rows

	var index := 0
	for column in range(columns):
		for row in range(rows):
			var x := -size_x * 0.5 + SECTION_WIDTH * 0.5 + float(column) * SECTION_WIDTH
			var z := -size_z * 0.5 + SECTION_WIDTH * 0.5 + float(row) * SECTION_WIDTH
			# Quarter-turns break up the repeat without needing more art.
			var spin := float((column * 7 + row * 3) % 4) * (PI * 0.5)
			var basis := Basis(Vector3.UP, spin)
			multimesh.set_instance_transform(index, Transform3D(basis, Vector3(x, 0.0, z)))
			index += 1

	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.position = centre
	var material := source.get_active_material(0)
	if material:
		instance.material_override = material
	add_child(instance)
	sample.queue_free()


func _material_for(color: Color, texture_name: String = "") -> StandardMaterial3D:
	var key := "%s|%s" % [color, texture_name]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.roughness = 0.92
	var texture := ground_texture(texture_name)
	if texture:
		var base: Color = GROUND_TEXTURES[texture_name]["base"]
		material.albedo_texture = texture
		material.albedo_color = Color(
			clampf(color.r / base.r, 0.0, 1.5),
			clampf(color.g / base.g, 0.0, 1.5),
			clampf(color.b / base.b, 0.0, 1.5)
		)
		# World-space triplanar: the top of every plate samples the same world
		# grid, so the square's slab and the field around it tile continuously.
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE / GROUND_TILE_METERS
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	else:
		material.albedo_color = color
	_materials[key] = material
	return material


static var _ground_textures: Dictionary = {}


## The painted texture for a ground name, or null if there isn't one (or the
## PNG hasn't been generated yet).
static func ground_texture(texture_name: String) -> Texture2D:
	if texture_name.is_empty() or not GROUND_TEXTURES.has(texture_name):
		return null
	if _ground_textures.has(texture_name):
		return _ground_textures[texture_name]
	var path: String = GROUND_TEXTURES[texture_name]["path"]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_ground_textures[texture_name] = texture
	return texture


# --- Helpers used by the layouts -------------------------------------------


## A building.
##
## Once the kit exists this is a real modular structure: 2m wall sections tiled
## around the footprint, with a door on the face that looks at the street and
## windows everywhere else. Until then it's the same building drawn as tinted
## boxes, at the same size in the same place — so the town's layout was designed
## once and doesn't move when the art arrives.
static func house(at: Vector3, width: float, depth: float, storeys: int = 2) -> Array:
	if kit_has("wall"):
		return _house_from_kit(at, width, depth, storeys)
	return _house_from_boxes(at, width, depth, storeys)


## Snap a dimension to whole 2m sections, because that is what the pieces are.
static func _sections(length: float) -> int:
	return maxi(1, int(round(length / SECTION_WIDTH)))


static func _house_from_kit(at: Vector3, width: float, depth: float, storeys: int) -> Array:
	var pieces: Array = []
	var wide := _sections(width)
	var deep := _sections(depth)
	var half_w := float(wide) * SECTION_WIDTH * 0.5
	var half_d := float(deep) * SECTION_WIDTH * 0.5

	for storey in range(maxi(1, storeys)):
		var y := float(storey) * SECTION_HEIGHT
		var ground := storey == 0
		# Upper storeys switch to timber-framed plaster once that piece exists,
		# which is what gives the town its overhanging medieval silhouette.
		var upper_piece := "wall_timber" if (not ground and kit_has("wall_timber")) else "wall"

		# The face looking at the street gets the door; everything else gets
		# windows, with blank wall at the corners so openings never meet.
		var door_index := wide / 2

		for i in range(wide):
			var x := -half_w + SECTION_WIDTH * 0.5 + float(i) * SECTION_WIDTH
			# South face — towards the square.
			var south := upper_piece
			if ground and i == door_index and kit_has("wall_door"):
				south = "wall_door"
			elif _wants_window(i, wide, ground):
				south = _window_or(upper_piece)
			pieces.append({"kit": south, "pos": at + Vector3(x, y, half_d), "rot": PI})
			# North face.
			var north := _window_or(upper_piece) if _wants_window(i, wide, false) else upper_piece
			pieces.append({"kit": north, "pos": at + Vector3(x, y, -half_d), "rot": 0.0})

		for i in range(deep):
			var z := -half_d + SECTION_WIDTH * 0.5 + float(i) * SECTION_WIDTH
			var side := _window_or(upper_piece) if _wants_window(i, deep, false) else upper_piece
			pieces.append({"kit": side, "pos": at + Vector3(-half_w, y, z), "rot": PI * 0.5})
			var side_east := _window_or(upper_piece) if _wants_window(i, deep, false) else upper_piece
			pieces.append({"kit": side_east, "pos": at + Vector3(half_w, y, z), "rot": -PI * 0.5})

	pieces.append_array(_roof(at, wide, deep, half_w, half_d, float(maxi(1, storeys)) * SECTION_HEIGHT))
	return pieces


## Windows go in the middle of a run, never at the corners — a window that meets
## a corner looks like a mistake, and at the ends the sections butt into the
## neighbouring wall.
static func _wants_window(index: int, count: int, is_ground: bool) -> bool:
	if count <= 2:
		return not is_ground
	if index == 0 or index == count - 1:
		return false
	return true


static func _window_or(fallback: String) -> String:
	return "wall_window" if kit_has("wall_window") else fallback


## Measured from the exported pieces: a slope runs 2m horizontally and rises
## 2.67m, low edge at its origin and climbing towards -Z. So a roof is a row of
## slopes along each long eave, climbing inwards, with ridge caps tiling the
## join between them.
const ROOF_RUN := 2.0
const ROOF_RISE := 2.67


static func _roof(at: Vector3, wide: int, deep: int, half_w: float, half_d: float, eave_y: float) -> Array:
	var pieces: Array = []
	if kit_has("roof_slope"):
		for i in range(wide):
			var x := -half_w + SECTION_WIDTH * 0.5 + float(i) * SECTION_WIDTH
			# South eave, climbing north.
			pieces.append({"kit": "roof_slope", "pos": at + Vector3(x, eave_y, half_d), "rot": 0.0})
			# North eave, climbing south.
			pieces.append({"kit": "roof_slope", "pos": at + Vector3(x, eave_y, -half_d), "rot": PI})

			# Between the two slopes, cap the join. On a building only 4m deep
			# the slopes meet exactly and this is a single ridge line; on a
			# deeper one it becomes a flat top between the pitches, which is a
			# perfectly ordinary way for a townhouse to be roofed.
			if not kit_has("roof_ridge"):
				continue
			var inner := half_d - ROOF_RUN
			if inner <= 0.05:
				pieces.append({"kit": "roof_ridge", "pos": at + Vector3(x, eave_y + ROOF_RISE, 0.0), "rot": 0.0})
			else:
				var caps := maxi(1, int(round(inner * 2.0 / SECTION_WIDTH)))
				for j in range(caps):
					var z := -inner + SECTION_WIDTH * 0.5 + float(j) * SECTION_WIDTH
					pieces.append(
						{"kit": "roof_ridge", "pos": at + Vector3(x, eave_y + ROOF_RISE, z), "rot": 0.0}
					)
		return pieces
	# Placeholder: a slate slab with a cap, sized to the real footprint so the
	# silhouette is honest about how big the building is.
	pieces.append(
		{"pos": at + Vector3(0, eave_y + 0.45, 0), "size": Vector3(half_w * 2.0 + 1.1, 0.9, half_d * 2.0 + 1.1), "color": SLATE}
	)
	pieces.append(
		{"pos": at + Vector3(0, eave_y + 1.2, 0), "size": Vector3(half_w * 1.1, 0.7, half_d * 1.1), "color": SLATE}
	)
	return pieces


## The original box version, kept as the fallback for anything the kit hasn't
## reached yet.
static func _house_from_boxes(at: Vector3, width: float, depth: float, storeys: int = 2) -> Array:
	var pieces: Array = []
	var ground_height := 3.0
	pieces.append({"pos": at + Vector3(0, ground_height * 0.5, 0), "size": Vector3(width, ground_height, depth), "color": STONE})
	if storeys > 1:
		var upper_y := ground_height + 1.4
		pieces.append(
			{"pos": at + Vector3(0, upper_y, 0), "size": Vector3(width + 0.7, 2.8, depth + 0.7), "color": PLASTER}
		)
		pieces.append(
			{"pos": at + Vector3(0, upper_y, (depth + 0.7) * 0.5), "size": Vector3(width + 0.8, 0.3, 0.2), "color": TIMBER, "solid": false}
		)
	var roof_y := (ground_height + 2.8 + 1.4) if storeys > 1 else (ground_height + 0.6)
	pieces.append({"pos": at + Vector3(0, roof_y, 0), "size": Vector3(width + 1.1, 0.9, depth + 1.1), "color": SLATE})
	pieces.append({"pos": at + Vector3(0, roof_y + 0.75, 0), "size": Vector3(width * 0.55, 0.7, depth * 0.55), "color": SLATE})
	return pieces


## A round-canopy tree, WoW-style: trunk plus a blob.
static func tree(at: Vector3, size: float = 1.0) -> Array:
	return [
		{"pos": at + Vector3(0, 1.6 * size, 0), "size": Vector3(0.55 * size, 3.2 * size, 0.55 * size), "color": TIMBER},
		{
			"pos": at + Vector3(0, 4.2 * size, 0),
			"size": Vector3(3.4 * size, 2.6 * size, 3.4 * size),
			"color": GRASS_DARK,
			"solid": false
		}
	]


## A banner pole. Heraldry is how you tell whose road you're standing on.
static func banner(at: Vector3, color: Color) -> Array:
	return [
		{"pos": at + Vector3(0, 2.5, 0), "size": Vector3(0.18, 5.0, 0.18), "color": TIMBER},
		{"pos": at + Vector3(0, 4.0, 0.35), "size": Vector3(0.1, 2.2, 1.3), "color": color, "solid": false}
	]


# --- Layouts ---------------------------------------------------------------


## Thornhollow Vale: the first zone. Town at the south end, farmland and
## hedgerow in the middle, the barrow rising at the north end.
static func thornhollow_vale() -> Array:
	var pieces: Array = []

	# Ground: one big green plate, with a darker band further out so the eye has
	# somewhere to go.
	pieces.append({"pos": Vector3(0, -0.5, 0), "size": Vector3(260, 1.0, 340), "color": GRASS, "texture": "grass"})
	pieces.append({"pos": Vector3(0, -0.45, -120), "size": Vector3(200, 1.0, 90), "color": GRASS_DARK, "solid": false, "texture": "grass"})

	# The road: south gate, through the square, north to the barrow.
	pieces.append({"pos": Vector3(0, 0.06, 40), "size": Vector3(9, 0.2, 120), "color": ROAD, "solid": false})
	pieces.append({"pos": Vector3(0, 0.06, -90), "size": Vector3(7, 0.2, 150), "color": ROAD, "solid": false})

	# --- The town square ---
	pieces.append({"pos": Vector3(0, 0.1, 0), "size": Vector3(46, 0.3, 40), "color": COBBLE})
	# Fountain in the middle, per the kit spec's Phase 3 centrepiece.
	pieces.append({"pos": Vector3(0, 0.5, 0), "size": Vector3(7.5, 0.8, 7.5), "color": STONE_DARK})
	pieces.append({"pos": Vector3(0, 0.95, 0), "size": Vector3(6.2, 0.3, 6.2), "color": WATER, "solid": false})
	pieces.append({"pos": Vector3(0, 1.8, 0), "size": Vector3(1.2, 2.6, 1.2), "color": STONE})

	# Buildings around the square.
	for entry in [
		{"at": Vector3(-19, 0, -13), "w": 11.0, "d": 9.0, "s": 2},
		{"at": Vector3(-19, 0, 2), "w": 11.0, "d": 10.0, "s": 2},
		{"at": Vector3(-18, 0, 16), "w": 9.0, "d": 8.0, "s": 1},
		{"at": Vector3(19, 0, -13), "w": 12.0, "d": 9.0, "s": 2},
		{"at": Vector3(19, 0, 3), "w": 10.0, "d": 11.0, "s": 2},
		{"at": Vector3(18, 0, 17), "w": 9.0, "d": 8.0, "s": 1},
		{"at": Vector3(0, 0, -24), "w": 16.0, "d": 10.0, "s": 2}
	]:
		pieces.append_array(house(entry["at"], entry["w"], entry["d"], entry["s"]))

	# Banners: blue-and-gold sunburst on one side, green-and-white stag on the
	# other. Two houses, one road, neither of them asked the valley.
	pieces.append_array(banner(Vector3(-6, 0, -20), Color(0.22, 0.34, 0.62)))
	pieces.append_array(banner(Vector3(6, 0, -20), Color(0.27, 0.46, 0.29)))

	# Town wall and gate at the south.
	pieces.append({"pos": Vector3(-16, 2.5, 26), "size": Vector3(34, 5, 2), "color": STONE_DARK})
	pieces.append({"pos": Vector3(16, 2.5, 26), "size": Vector3(34, 5, 2), "color": STONE_DARK})
	pieces.append({"pos": Vector3(-5.5, 3.5, 26), "size": Vector3(1.6, 7, 2.4), "color": STONE})
	pieces.append({"pos": Vector3(5.5, 3.5, 26), "size": Vector3(1.6, 7, 2.4), "color": STONE})
	pieces.append({"pos": Vector3(0, 7.2, 26), "size": Vector3(12.5, 1.2, 2.4), "color": STONE})

	# --- Farmland and hedgerow, levels 1-5 ---
	for x in [-46, -30, 30, 46]:
		for z in [-6, 8, 22]:
			pieces.append({"pos": Vector3(x, 0.08, z), "size": Vector3(13, 0.25, 11), "color": GRASS_DARK, "solid": false, "texture": "grass"})
	for hedge in [Vector3(-38, 0, -18), Vector3(-38, 0, 30), Vector3(38, 0, -18), Vector3(38, 0, 30)]:
		pieces.append({"pos": hedge + Vector3(0, 0.8, 0), "size": Vector3(26, 1.6, 1.2), "color": GRASS_DARK})

	for spot in [
		Vector3(-30, 0, 34), Vector3(-52, 0, 12), Vector3(-44, 0, -30), Vector3(34, 0, 36),
		Vector3(52, 0, 6), Vector3(44, 0, -28), Vector3(-24, 0, -46), Vector3(26, 0, -48),
		Vector3(-60, 0, -60), Vector3(58, 0, -56)
	]:
		pieces.append_array(tree(spot, 1.0 + fposmod(spot.x * 0.07, 0.4)))

	# --- The river and its bridge, the border between level bands ---
	pieces.append({"pos": Vector3(0, -0.1, -70), "size": Vector3(240, 0.6, 14), "color": WATER, "solid": false})
	pieces.append({"pos": Vector3(0, 0.3, -70), "size": Vector3(11, 0.6, 16), "color": TIMBER})
	pieces.append({"pos": Vector3(-5.5, 0.9, -70), "size": Vector3(0.4, 1.2, 16), "color": TIMBER, "solid": false})
	pieces.append({"pos": Vector3(5.5, 0.9, -70), "size": Vector3(0.4, 1.2, 16), "color": TIMBER, "solid": false})

	# --- The barrow, north end ---
	# The mound is scenery you walk AROUND; the door sits on flat ground in
	# front of it, because a CharacterBody3D can't climb a two-metre step and a
	# blockout is not the place to be solving stairs.
	pieces.append({"pos": Vector3(0, 1.0, -148), "size": Vector3(90, 2.0, 60), "color": GRASS_DARK, "texture": "grass"})
	pieces.append({"pos": Vector3(0, 2.6, -152), "size": Vector3(66, 2.0, 46), "color": BARROW})
	pieces.append({"pos": Vector3(0, 4.2, -156), "size": Vector3(44, 2.0, 32), "color": BARROW})

	# A stone circle flanking the approach.
	for angle_step in range(10):
		var angle := TAU * float(angle_step) / 10.0
		pieces.append(
			{
				"pos": Vector3(cos(angle) * 30.0, 2.6, -106.0 + sin(angle) * 18.0),
				"size": Vector3(1.6, 5.2, 1.6),
				"color": BARROW,
				"rot": angle
			}
		)

	# The doorway, at ground level so you can simply walk in.
	pieces.append({"pos": Vector3(-5.5, 2.7, -116), "size": Vector3(3.5, 5.4, 3.5), "color": STONE_DARK})
	pieces.append({"pos": Vector3(5.5, 2.7, -116), "size": Vector3(3.5, 5.4, 3.5), "color": STONE_DARK})
	pieces.append({"pos": Vector3(0, 5.9, -116), "size": Vector3(15, 1.2, 3.5), "color": STONE_DARK})
	pieces.append({"pos": Vector3(0, 0.06, -112), "size": Vector3(16, 0.2, 14), "color": COBBLE, "solid": false})

	# Outer boundary, so nobody walks off the edge of the world.
	for wall in [
		{"pos": Vector3(0, 6, 172), "size": Vector3(262, 12, 2)},
		{"pos": Vector3(0, 6, -172), "size": Vector3(262, 12, 2)},
		{"pos": Vector3(-131, 6, 0), "size": Vector3(2, 12, 342)},
		{"pos": Vector3(131, 6, 0), "size": Vector3(2, 12, 342)}
	]:
		pieces.append({"pos": wall["pos"], "size": wall["size"], "color": GRASS_DARK, "solid": true})

	return pieces


## Inside the barrow. Reached through the portal at the mound, and placed far
## from the vale in world coordinates so the two never see each other.
static func barrow_interior() -> Array:
	var pieces: Array = []

	# A shell of rock around the whole thing. Without it you can see daylight
	# between the halls, which ruins the one thing a barrow has going for it.
	var shell_centre := Vector3(0, -494, -675)
	pieces.append({"pos": Vector3(0, -501.5, -675), "size": Vector3(74, 2, 220), "color": BARROW})
	pieces.append({"pos": Vector3(0, -485.0, -675), "size": Vector3(74, 2, 220), "color": BARROW})
	pieces.append({"pos": shell_centre + Vector3(-36, 0, 0), "size": Vector3(2, 18, 220), "color": BARROW})
	pieces.append({"pos": shell_centre + Vector3(36, 0, 0), "size": Vector3(2, 18, 220), "color": BARROW})
	pieces.append({"pos": Vector3(0, -494, -566), "size": Vector3(74, 18, 2), "color": BARROW})
	pieces.append({"pos": Vector3(0, -494, -784), "size": Vector3(74, 18, 2), "color": BARROW})

	# Deep underground and far north: out of sight of the vale entirely. A
	# dungeon sitting at surface level is visible from the fields as a hall
	# hanging in the sky.
	var origin := Vector3(0, -500, -600)

	# Entry hall.
	pieces.append({"pos": origin + Vector3(0, -0.5, 0), "size": Vector3(34, 1, 46), "color": BARROW})
	pieces.append({"pos": origin + Vector3(-17, 4, 0), "size": Vector3(1.5, 9, 46), "color": STONE_DARK})
	pieces.append({"pos": origin + Vector3(17, 4, 0), "size": Vector3(1.5, 9, 46), "color": STONE_DARK})
	pieces.append({"pos": origin + Vector3(0, 8.5, 0), "size": Vector3(34, 1, 46), "color": STONE_DARK})
	pieces.append({"pos": origin + Vector3(0, 4, 23), "size": Vector3(34, 9, 1.5), "color": STONE_DARK})

	# Corridor to the first boss.
	pieces.append({"pos": origin + Vector3(0, -0.5, -36), "size": Vector3(14, 1, 30), "color": BARROW})
	pieces.append({"pos": origin + Vector3(-7, 4, -36), "size": Vector3(1.5, 9, 30), "color": STONE_DARK})
	pieces.append({"pos": origin + Vector3(7, 4, -36), "size": Vector3(1.5, 9, 30), "color": STONE_DARK})
	pieces.append({"pos": origin + Vector3(0, 8.5, -36), "size": Vector3(14, 1, 30), "color": STONE_DARK})

	# Reyne's hall.
	pieces.append({"pos": origin + Vector3(0, -0.5, -72), "size": Vector3(42, 1, 42), "color": BARROW})
	pieces.append({"pos": origin + Vector3(-21, 5, -72), "size": Vector3(1.5, 11, 42), "color": STONE_DARK})
	pieces.append({"pos": origin + Vector3(21, 5, -72), "size": Vector3(1.5, 11, 42), "color": STONE_DARK})
	pieces.append({"pos": origin + Vector3(0, 10.5, -72), "size": Vector3(42, 1, 42), "color": STONE_DARK})
	for pillar_x in [-12, 12]:
		for pillar_z in [-60, -84]:
			pieces.append({"pos": origin + Vector3(pillar_x, 5, pillar_z), "size": Vector3(2.4, 11, 2.4), "color": STONE})

	# Descent to the tomb.
	pieces.append({"pos": origin + Vector3(0, -0.5, -106), "size": Vector3(14, 1, 30), "color": BARROW})
	pieces.append({"pos": origin + Vector3(-7, 4, -106), "size": Vector3(1.5, 9, 30), "color": STONE_DARK})
	pieces.append({"pos": origin + Vector3(7, 4, -106), "size": Vector3(1.5, 9, 30), "color": STONE_DARK})

	# The tomb of the First King.
	pieces.append({"pos": origin + Vector3(0, -0.5, -146), "size": Vector3(54, 1, 54), "color": BARROW})
	pieces.append({"pos": origin + Vector3(-27, 6, -146), "size": Vector3(1.5, 13, 54), "color": STONE_DARK})
	pieces.append({"pos": origin + Vector3(27, 6, -146), "size": Vector3(1.5, 13, 54), "color": STONE_DARK})
	pieces.append({"pos": origin + Vector3(0, 6, -173), "size": Vector3(54, 13, 1.5), "color": STONE_DARK})
	pieces.append({"pos": origin + Vector3(0, 12.5, -146), "size": Vector3(54, 1, 54), "color": STONE_DARK})
	# The bier, with a gold crown on it. This is the thing every house wants.
	pieces.append({"pos": origin + Vector3(0, 0.8, -160), "size": Vector3(10, 1.6, 5), "color": STONE})
	pieces.append({"pos": origin + Vector3(0, 1.9, -160), "size": Vector3(1.4, 0.7, 1.4), "color": GOLD, "solid": false})
	for pillar_x in [-16, 16]:
		for pillar_z in [-132, -152]:
			pieces.append({"pos": origin + Vector3(pillar_x, 6, pillar_z), "size": Vector3(2.8, 13, 2.8), "color": STONE})

	return pieces
