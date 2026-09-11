extends SceneTree
## Verifies the rigged character assets are actually usable in Godot.
##
## A rigged .glb can import without complaint and still be useless: skeleton
## missing, bones renamed, the equipment sockets absent, or the mesh not
## actually bound to anything. This checks the things the game depends on.
##
## Run:  godot --headless --path godot-project --script res://tests/character_check.gd

const CHAR_DIR := "res://assets/characters"

# The sockets scripts/player/player.gd and player.tscn bind equipment to.
const REQUIRED_SOCKETS := ["HeadAttach", "LeftHandAttach", "RightHandAttach", "BackAttach"]

# Enough of the humanoid hierarchy that Godot's retargeting will recognise it.
const REQUIRED_BONES := [
	"Hips", "Spine", "Chest", "Neck", "Head",
	"LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"RightUpperLeg", "RightLowerLeg", "RightFoot",
]

const MIN_HEIGHT := 1.6
const MAX_HEIGHT := 2.0
const MAX_TRIS := 8000


func _init() -> void:
	var dir := DirAccess.open(CHAR_DIR)
	if dir == null:
		print("CHARACTER CHECK FAILED: no ", CHAR_DIR)
		quit(1)
		return

	var files: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".glb") and f.contains("rigged"):
			files.append(f)
	files.sort()

	if files.is_empty():
		print("CHARACTER CHECK FAILED: no rigged character in ", CHAR_DIR)
		quit(1)
		return

	var failures: Array[String] = []
	for f in files:
		failures.append_array(_check(f))

	print("")
	if failures.is_empty():
		print("CHARACTER CHECK PASSED (%d rigged)" % files.size())
		quit(0)
	else:
		for m in failures:
			print("  FAIL: ", m)
		print("CHARACTER CHECK FAILED (%d problems)" % failures.size())
		quit(1)


func _check(file_name: String) -> Array[String]:
	var problems: Array[String] = []
	var packed := load(CHAR_DIR + "/" + file_name) as PackedScene
	if packed == null:
		problems.append("%s: will not load" % file_name)
		return problems

	var root := packed.instantiate()
	var skel: Skeleton3D = null
	var meshes: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Skeleton3D and skel == null:
			skel = n
		if n is MeshInstance3D:
			meshes.append(n)
		for c in n.get_children():
			stack.append(c)

	if skel == null:
		problems.append("%s: no Skeleton3D" % file_name)
		root.free()
		return problems

	var names := {}
	for i in skel.get_bone_count():
		names[skel.get_bone_name(i)] = i

	for b in REQUIRED_BONES:
		if not names.has(b):
			problems.append("%s: missing bone '%s'" % [file_name, b])
	for s in REQUIRED_SOCKETS:
		if not names.has(s):
			problems.append("%s: missing equipment socket bone '%s'" % [file_name, s])

	# The mesh must actually be bound to the skeleton, not just sitting near it.
	var tris := 0
	var skinned := 0
	var aabb := AABB()
	var first := true
	for mi in meshes:
		if mi.skin == null and mi.skeleton.is_empty():
			continue
		skinned += 1
		var mesh := mi.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			tris += idx.size() / 3
			var bones = arrays[Mesh.ARRAY_BONES]
			if bones == null or bones.size() == 0:
				problems.append("%s: surface %d has no bone weights" % [file_name, s])
		var box := mesh.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false

	if skinned == 0:
		problems.append("%s: no mesh is bound to the skeleton" % file_name)
	if tris > MAX_TRIS:
		problems.append("%s: %d tris, over the %d budget" % [file_name, tris, MAX_TRIS])
	if not first:
		var height := aabb.size.y
		if height < MIN_HEIGHT or height > MAX_HEIGHT:
			problems.append("%s: %.2fm tall, expected roughly 1.8m" % [file_name, height])

	print("%-28s bones=%d tris=%d skinned_meshes=%d height=%.2fm" % [
		file_name, skel.get_bone_count(), tris, skinned, aabb.size.y])

	root.free()
	return problems
