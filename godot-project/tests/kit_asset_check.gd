extends SceneTree
## Verifies every exported kit piece in assets/kit/ is actually usable.
##
## A .glb that imports without an error can still be useless -- empty mesh,
## missing texture, wrong scale, sunk below the floor. This loads each one for
## real and checks the things that would break a build made out of them.
##
## Run:  godot --headless --path godot-project --script res://tests/kit_asset_check.gd

const KIT_DIR := "res://assets/kit"

# Pieces are modelled on a 1m grid; allow a little slack for chamfers and
# projecting detail like sills, but nothing should be wildly off-grid.
const GRID := 1.0
const GRID_SLACK := 0.55
const MAX_TRIS_PER_PIECE := 4000
# How far detail may hang below a piece's origin (jetty corbels, eaves).
const MAX_OVERHANG_BELOW := 0.40


func _init() -> void:
	var dir := DirAccess.open(KIT_DIR)
	if dir == null:
		print("KIT CHECK FAILED: no ", KIT_DIR)
		quit(1)
		return

	var files: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".glb"):
			files.append(f)
	files.sort()

	var failures: Array[String] = []
	for f in files:
		failures.append_array(_check(f))

	print("")
	if failures.is_empty():
		print("KIT CHECK PASSED (%d pieces)" % files.size())
		quit(0)
	else:
		for msg in failures:
			print("  FAIL: ", msg)
		print("KIT CHECK FAILED (%d problems in %d pieces)" % [failures.size(), files.size()])
		quit(1)


func _check(file_name: String) -> Array[String]:
	var problems: Array[String] = []
	var packed := load(KIT_DIR + "/" + file_name) as PackedScene
	if packed == null:
		problems.append("%s: will not load" % file_name)
		return problems

	var root := packed.instantiate()
	var meshes := 0
	var tris := 0
	var surfaces := 0
	var textured := 0
	var aabb := AABB()
	var first := true

	# Accumulate transforms as we descend. global_transform would be simpler,
	# but it only works inside the scene tree and these are loose instances.
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node = entry[0]
		var xform: Transform3D = entry[1]
		if node is Node3D:
			xform = xform * (node as Node3D).transform
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			var mesh := mi.mesh
			if mesh != null:
				meshes += 1
				for s in mesh.get_surface_count():
					surfaces += 1
					var arrays := mesh.surface_get_arrays(s)
					var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					tris += idx.size() / 3
					var mat := mesh.surface_get_material(s)
					if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture != null:
						textured += 1
				var box := xform * mesh.get_aabb()
				aabb = box if first else aabb.merge(box)
				first = false
		for c in node.get_children():
			stack.append([c, xform])

	if meshes == 0 or tris == 0:
		problems.append("%s: no geometry" % file_name)
	if surfaces > 0 and textured == 0:
		problems.append("%s: no surface has an albedo texture" % file_name)
	if tris > MAX_TRIS_PER_PIECE:
		problems.append("%s: %d tris, over the %d budget" % [file_name, tris, MAX_TRIS_PER_PIECE])

	if not first:
		# Pieces are authored with their origin on the surface they sit on.
		# Some legitimately hang below it -- jetty corbels on the timber
		# storey, a fascia under an eave -- so allow a little, but not a
		# piece that is simply sunk into the ground.
		if aabb.position.y < -MAX_OVERHANG_BELOW:
			problems.append("%s: sinks below the floor (min y = %.3f)" % [file_name, aabb.position.y])
		elif aabb.position.y > 0.05:
			problems.append("%s: floats above the floor (min y = %.3f)" % [file_name, aabb.position.y])
		# Footprint should land on the grid so pieces snap together.
		for axis in [Vector3.RIGHT, Vector3.BACK]:
			var extent: float = absf(aabb.size.dot(axis))
			var off: float = fmod(extent + GRID * 0.5, GRID) - GRID * 0.5
			if absf(off) > GRID_SLACK:
				problems.append("%s: %.2fm extent is off the 1m grid" % [file_name, extent])

	print("%-32s meshes=%d tris=%-5d textured=%d/%d  size=%.2f x %.2f x %.2f" % [
		file_name, meshes, tris, textured, surfaces,
		aabb.size.x, aabb.size.y, aabb.size.z])

	root.free()
	return problems
