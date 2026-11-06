extends "res://scripts/scenes/tavern.gd"
## Shared campaign/UI controller with a 3D world adapter. The Node2D models are
## retained as domain objects; their movement and presentation belong to World3D.
const WORLD_3D := preload("res://scripts/scenes/tavern3d/tavern_world_3d.gd")
var world_3d: Node3D

func _ready() -> void:
	super._ready()
	world.hide()
	world.position = Vector2.ZERO
	world.scale = Vector2.ONE
	keeper.set_physics_process(false)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_3d = WORLD_3D.new()
	world_3d.name = "World3D"
	world_3d.hub = self
	add_child(world_3d)
	var settings := get_node_or_null("/root/GameSettings")
	if settings != null: settings.settings_changed.connect(_on_3d_settings_changed)

func _on_3d_settings_changed(key: String, _value: Variant) -> void:
	if key == "dev_mode": _refresh_wings()

func _update_camera(_snap: bool) -> void:
	if world != null:
		world.position = Vector2.ZERO
		world.scale = Vector2.ONE

func _refresh_wings() -> void:
	super._refresh_wings()
	if is_instance_valid(world_3d): world_3d.call_deferred("rebuild_wings")

func _recruit_candidate(candidate_id: String) -> void:
	super._recruit_candidate(candidate_id)
	if not run_state.campaign.candidate_pool.has(candidate_id): _refresh_wings()

func _unhandled_input(event: InputEvent) -> void:
	# Keep arrival/departure skipping and modal dismissal in the shared controller.
	# Normal E/Space input belongs to the 3D keeper, not toolbar focus.
	if arrivals_running or departure_running or _modal_visible():
		super._unhandled_input(event)
