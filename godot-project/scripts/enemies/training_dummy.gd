# Training Dummy — the simplest possible thing you can hit.
#
# It has no AI and never fights back. Its only job is to prove the combat
# chain works: your swing reaches the server, the server subtracts health,
# and every player sees the same number above its head.
extends StaticBody3D

const RESPAWN_DELAY_SECONDS := 3.0

@onready var _stats: Stats = $Stats
@onready var _label: Label3D = $HealthLabel
@onready var _mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	_stats.health_changed.connect(_on_health_changed)
	_stats.died.connect(_on_died)
	_on_health_changed(_stats.health, _stats.max_health)


func _on_health_changed(current: int, maximum: int) -> void:
	if current > 0:
		_label.text = "Training Dummy\n%d / %d" % [current, maximum]
		_mesh.visible = true
	else:
		_label.text = "Training Dummy\nDESTROYED"
		_mesh.visible = false


# Only the server runs the respawn timer, then tells everyone it's back.
func _on_died() -> void:
	if not multiplayer.is_server():
		return
	await get_tree().create_timer(RESPAWN_DELAY_SECONDS).timeout
	if is_instance_valid(_stats):
		_stats.revive()
