class_name ImpactScreenShake
extends Node

var camera:Camera2D
var base_offset:=Vector2.ZERO
var trauma:=0.0
var duration:=0.18
var intensity:=3.0

## Binds a camera and starts a short low-amplitude shake that preserves its original offset.
func setup(target_camera:Camera2D,amount:float) -> ImpactScreenShake:
	camera=target_camera;base_offset=camera.offset;intensity=amount;trauma=duration;return self

## Refreshes an existing shake and keeps the strongest requested amplitude without stacking camera writers.
func add_trauma(amount:float) -> void:
	trauma=duration;intensity=maxf(intensity,amount)

## Applies decaying randomized camera offset and restores the exact base offset before cleanup.
func _process(delta:float) -> void:
	if not is_instance_valid(camera):queue_free();return
	trauma=maxf(0.0,trauma-delta)
	if trauma<=0:
		camera.offset=base_offset;queue_free();return
	var strength:=trauma/duration
	camera.offset=base_offset+Vector2(randf_range(-1.0,1.0),randf_range(-1.0,1.0)).normalized()*intensity*strength

## Restores the camera if the shake node is removed early by a scene reset or transition.
func _exit_tree() -> void:
	if is_instance_valid(camera):camera.offset=base_offset
