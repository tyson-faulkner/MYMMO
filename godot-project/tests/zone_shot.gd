extends Node3D

const SHOTS := [
	{"scene": "res://scenes/zones/sablemarch.tscn", "name": "sablemarch_camp",
		"eye": Vector3(600, 30, 176), "look": Vector3(600, 2, 96)},
	{"scene": "res://scenes/zones/sablemarch.tscn", "name": "sablemarch_field",
		"eye": Vector3(600, 60, 60), "look": Vector3(600, 0, -110)},
	{"scene": "res://scenes/zones/sablemarch.tscn", "name": "sablemarch_redoubt",
		"eye": Vector3(600, -992, -560), "look": Vector3(600, -998, -680)},
	{"scene": "res://scenes/zones/kingsmourn.tscn", "name": "kingsmourn_gate",
		"eye": Vector3(1200, 26, 196), "look": Vector3(1200, 6, 80)},
	{"scene": "res://scenes/zones/kingsmourn.tscn", "name": "kingsmourn_market",
		"eye": Vector3(1200, 22, 156), "look": Vector3(1200, 4, 86)},
	{"scene": "res://scenes/zones/kingsmourn.tscn", "name": "kingsmourn_palace",
		"eye": Vector3(1200, 40, -62), "look": Vector3(1200, 12, -178)},
	{"scene": "res://scenes/zones/kingsmourn.tscn", "name": "kingsmourn_records",
		"eye": Vector3(1126, 22, 4), "look": Vector3(1126, 10, -76)},
	{"scene": "res://scenes/zones/kingsmourn.tscn", "name": "kingsmourn_hall",
		"eye": Vector3(1200, -1492, -558), "look": Vector3(1200, -1496, -680)},
	{"scene": "res://scenes/zones/kingsmourn.tscn", "name": "kingsmourn_vault",
		"eye": Vector3(1200, -1492, -716), "look": Vector3(1200, -1497, -760)},
	{"scene": "res://scenes/zones/kingsmourn.tscn", "name": "kingsmourn_throne",
		"eye": Vector3(1200, -1988, -648), "look": Vector3(1200, -1994, -740)},
	{"scene": "res://scenes/zones/kingsmourn.tscn", "name": "kingsmourn_crypt",
		"eye": Vector3(1200, -1194, -586), "look": Vector3(1200, -1198, -680)},
	{"scene": "res://scenes/zones/thornhollow_vale.tscn", "name": "barrow_tomb",
		"eye": Vector3(0, -494, -716), "look": Vector3(0, -498, -760)},
]

var _camera: Camera3D


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, -140, 0)
	light.light_energy = 1.2
	add_child(light)

	_camera = Camera3D.new()
	_camera.fov = 62
	_camera.far = 4000.0
	_camera.current = true
	add_child(_camera)

	for shot in SHOTS:
		await _take(shot)
	get_tree().quit()


func _take(shot: Dictionary) -> void:
	var zone: Node3D = (load(str(shot["scene"])) as PackedScene).instantiate()
	add_child(zone)
	_camera.global_position = shot["eye"]
	_camera.look_at(shot["look"], Vector3.UP)
	for i in range(6):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://%s.png" % shot["name"])
	print("shot: %s" % shot["name"])
	zone.queue_free()
	await get_tree().process_frame
