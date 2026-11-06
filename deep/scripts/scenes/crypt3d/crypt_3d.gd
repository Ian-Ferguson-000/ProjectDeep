extends "res://scripts/slasher/slasher_crypt.gd"
## The Stone Crypt in 3D: the same presentation as the 3D forest
## (scripts/scenes/forest3d/forest_world_3d.gd) with the crypt theme. Rooms,
## foes, hazards, hit geometry, drops and checkpoints all stay in the 2D
## simulation underneath (slasher_crypt.gd), exactly as in the forest.
const PRESENTATION := preload("res://scripts/scenes/forest3d/forest_world_3d.gd")
var world_3d: Node3D
var _original_canvas_mask := 0

func _ready() -> void:
	_original_canvas_mask = get_viewport().canvas_cull_mask
	super._ready()

func _build_floor() -> void:
	super._build_floor()
	player.camera.enabled = false
	pause_menu.extra_controls = [["Zoom camera","Mouse wheel",""]]
	world_3d = PRESENTATION.new()
	world_3d.name = "CryptWorld3D"
	world_3d.theme = "crypt"
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
