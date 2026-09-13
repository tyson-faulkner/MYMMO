# Body — the character's visible model: which class it looks like, which way it
# faces, and which clip it is playing.
#
# Every class model (assets/characters/char_<class>.glb) is built on the same
# 26-bone skeleton with the same eight clips, so changing class is swapping the
# model under ClassModel and re-pointing the equipment sockets at its skeleton.
# Nothing else about the character has to know.
#
# (The file keeps its template name so the scene's uid reference stays valid;
# the robot it was named after is gone.)
class_name Body
extends Node3D

signal animation_finished(animation_name: StringName)

const LERP_VELOCITY: float = 0.15

const CLASS_MODELS := {
	&"valkyr": "res://assets/characters/char_valkyr.glb",
	&"bard": "res://assets/characters/char_bard.glb",
	&"necromancer": "res://assets/characters/char_necromancer.glb",
	&"tinker": "res://assets/characters/char_tinker.glb"
}

const MODEL_NODE := "ClassModel"
const SKELETON_PATH := "ClassModel/Armature/Skeleton3D"

## The class models are exported facing -Z. Everything else on the character —
## movement facing, the pickup area in front — was laid out for +Z, which is
## what the template robot faced. Turning the model round is one number;
## turning everything else round is a bug hunt.
const MODEL_YAW := PI

## Clips that should repeat. The exports mark every clip play-once, and a
## play-once Idle simply freezes on its last frame.
const LOOPING_CLIPS: Array[StringName] = [&"Idle", &"Run", &"Sprint", &"Fall"]

## Clips the character script waits to finish (attacking, picking up). If the
## model is swapped mid-clip its player is freed and that signal never comes,
## so a swap reports them finished instead of leaving the character stuck.
const ONE_SHOT_CLIPS: Array[StringName] = [&"Attack1", &"Emote2"]

## Equipment socket node on this body -> socket bone in every class skeleton.
const SOCKETS := {"HeadAttach": &"HeadAttach", "LeftHandAttach": &"LeftHandAttach", "BackAttach": &"BackAttach"}

@export_category("Objects")
@export var _character: CharacterBody3D = null
@export var animation_player: AnimationPlayer = null

## Which class's model is currently worn, or &"" if it couldn't be told.
var model_class: StringName = &""

var _current_state: StringName = &""
var _head_hidden := false


func _ready() -> void:
	var model := get_node_or_null(MODEL_NODE) as Node3D
	if model:
		model_class = _class_for_path(model.scene_file_path)
		_bind_model(model)


## Wear this class's model. Safe to call repeatedly: the same class is a no-op.
func set_class_model(class_id: StringName) -> bool:
	if class_id == model_class and get_node_or_null(MODEL_NODE) != null:
		return true
	var path: String = str(CLASS_MODELS.get(class_id, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("Body: no model for class '%s'" % class_id)
		return false
	var scene := load(path) as PackedScene
	if scene == null:
		return false
	var model := scene.instantiate() as Node3D
	if model == null:
		return false

	if _current_state in ONE_SHOT_CLIPS:
		animation_finished.emit(_current_state)
	var old := get_node_or_null(MODEL_NODE)
	if old:
		remove_child(old)
		old.queue_free()

	model.name = MODEL_NODE
	model.rotation.y = MODEL_YAW
	add_child(model)
	model_class = class_id
	_bind_model(model)

	# Carry on with whatever the state machine was doing, on the new body.
	var state := _current_state if not (_current_state in ONE_SHOT_CLIPS) else &"Idle"
	_current_state = &""
	play_animation_state(state if state != &"" else &"Idle", true)
	return true


func get_skeleton() -> Skeleton3D:
	return get_node_or_null(SKELETON_PATH) as Skeleton3D


## First person: collapse the head so the camera isn't inside it. Worn head
## gear goes with it, because its socket is a child of the head bone.
func set_head_hidden(hidden: bool) -> void:
	_head_hidden = hidden
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	var head := skeleton.find_bone("Head")
	if head >= 0:
		skeleton.set_bone_pose_scale(head, Vector3.ZERO if hidden else Vector3.ONE)


func apply_rotation(_velocity: Vector3) -> void:
	var new_rotation_y = lerp_angle(rotation.y, atan2(-_velocity.x, -_velocity.z), LERP_VELOCITY)
	rotation.y = new_rotation_y


func get_movement_animation(_velocity: Vector3) -> StringName:
	if not _character.is_on_floor():
		if _velocity.y < 0:
			return &"Fall"
		if _current_state == &"Jump2":
			return &"Jump2"
		return &"Jump"

	if _velocity:
		if _character._is_running() and _character.is_on_floor():
			return &"Sprint"
		return &"Run"

	return &"Idle"


func play_animation_state(state: StringName, restart: bool = false) -> void:
	if not animation_player:
		return
	if not animation_player.has_animation(state):
		return
	if not restart and _current_state == state and animation_player.is_playing():
		return
	_current_state = state
	animation_player.play(state)


func _bind_model(model: Node3D) -> void:
	animation_player = model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player:
		for clip in LOOPING_CLIPS:
			if animation_player.has_animation(clip):
				animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		# Binding can happen twice for one model — set before this node's _ready,
		# then again by _ready itself — so it must not double-connect.
		if not animation_player.animation_finished.is_connected(_on_clip_finished):
			animation_player.animation_finished.connect(_on_clip_finished)

	var skeleton := get_skeleton()
	if skeleton == null:
		push_warning("Body: model '%s' has no skeleton at %s" % [model.name, SKELETON_PATH])
		return
	for socket_name in SOCKETS:
		var attachment := get_node_or_null(socket_name) as BoneAttachment3D
		if attachment == null:
			continue
		attachment.use_external_skeleton = true
		# Clear first: the attachment cached the previous model's skeleton, which
		# is being freed, and re-assigning the same path would not look again.
		attachment.external_skeleton = NodePath()
		attachment.external_skeleton = attachment.get_path_to(skeleton)
		attachment.bone_name = String(SOCKETS[socket_name])
		attachment.bone_idx = skeleton.find_bone(attachment.bone_name)
	set_head_hidden(_head_hidden)


func _on_clip_finished(clip: StringName) -> void:
	animation_finished.emit(clip)


static func _class_for_path(path: String) -> StringName:
	for class_id in CLASS_MODELS:
		if CLASS_MODELS[class_id] == path:
			return class_id
	return &""
