extends "res://game/dungeons/shared/slasher_forest_rooms.gd"
## 3D presentation over the existing room/combat simulation. Room seeds,
## hit geometry, drops, checkpoints and input actions remain authoritative in 2D.
const PRESENTATION := preload("res://game/dungeons/shared/world_3d/forest_world_3d.gd")
var world_3d: Node3D
var _original_canvas_mask := 0


func _ready() -> void:
	_original_canvas_mask = get_viewport().canvas_cull_mask
	super._ready()


func _build_floor() -> void:
	super._build_floor()
	player.camera.enabled = false
	pause_menu.extra_controls = [["Zoom forest camera", "Mouse wheel", ""]]
	world_3d = PRESENTATION.new()
	world_3d.name = "ForestWorld3D"
	world_3d.dungeon = self
	add_child(world_3d)


func _build_mist() -> void:
	pass


func _build_vignette() -> void:
	pass


func _exit_tree() -> void:
	get_viewport().canvas_transform = Transform2D.IDENTITY
	get_viewport().canvas_cull_mask = _original_canvas_mask
	super._exit_tree()
