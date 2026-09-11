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
@export_enum("thornhollow_vale", "barrow_interior") var layout: String = "thornhollow_vale"

var _materials: Dictionary = {}


func _ready() -> void:
	var pieces: Array = []
	match layout:
		"thornhollow_vale":
			pieces = thornhollow_vale()
		"barrow_interior":
			pieces = barrow_interior()
	for piece in pieces:
		_build_piece(piece)


# A piece is {pos, size, color, solid, rot} — solid defaults to true, meaning it
# gets collision and you can stand on it.
func _build_piece(piece: Dictionary) -> void:
	var size: Vector3 = piece.get("size", Vector3.ONE)
	var position: Vector3 = piece.get("pos", Vector3.ZERO)
	var color: Color = piece.get("color", STONE)
	var solid: bool = piece.get("solid", true)
	var rotation_y: float = float(piece.get("rot", 0.0))

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = _material_for(color)

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


func _material_for(color: Color) -> StandardMaterial3D:
	var key := str(color)
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	_materials[key] = material
	return material


# --- Helpers used by the layouts -------------------------------------------


## A building: stone ground floor, plaster-and-timber upper storey, slate roof.
## The whole silhouette is what the kit will replace first.
static func house(at: Vector3, width: float, depth: float, storeys: int = 2) -> Array:
	var pieces: Array = []
	var ground_height := 3.0
	pieces.append({"pos": at + Vector3(0, ground_height * 0.5, 0), "size": Vector3(width, ground_height, depth), "color": STONE})
	if storeys > 1:
		# The upper storey overhangs, which is most of why the silhouette reads
		# as a medieval town rather than a row of boxes.
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
	pieces.append({"pos": Vector3(0, -0.5, 0), "size": Vector3(260, 1.0, 340), "color": GRASS})
	pieces.append({"pos": Vector3(0, -0.45, -120), "size": Vector3(200, 1.0, 90), "color": GRASS_DARK, "solid": false})

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
			pieces.append({"pos": Vector3(x, 0.08, z), "size": Vector3(13, 0.25, 11), "color": GRASS_DARK, "solid": false})
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
	pieces.append({"pos": Vector3(0, 1.0, -148), "size": Vector3(90, 2.0, 60), "color": GRASS_DARK})
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
