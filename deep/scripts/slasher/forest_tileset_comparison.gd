extends Control

## A visual-only comparison using the production forest generator and artwork.
const TERRAIN_ART = preload("res://scripts/slasher/slasher_forest_terrain_art.gd")
const CELL := 48
const SEED := 83492791
var cameras: Array[Camera2D] = []
var containers: Array[SubViewportContainer] = []
var center := Vector2(1120, 720)
var magnification := 0.37
var dragging := false
var layout: Dictionary
var mode := 0
var map_row: HBoxContainer
var captions: Array[Label] = []

func _overview_center() -> Vector2:
	var minimum := Vector2i(9999, 9999)
	var maximum := Vector2i(-9999, -9999)
	for value: Variant in layout.cells:
		var cell: Vector2i = value
		minimum = minimum.min(cell)
		maximum = maximum.max(cell)
	return (Vector2(minimum) + Vector2(maximum) + Vector2.ONE) * CELL / 2.0

func _ready() -> void:
	layout = SlasherForestGenerator.generate(SEED, 2, "forest")
	center = _overview_center()
	var background := ColorRect.new()
	background.color = Color("111c19")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var title := Label.new()
	title.text = "FOREST / TERRAIN STUDY"
	title.position = Vector2(28, 18)
	title.add_theme_font_size_override("font_size", 26)
	add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Same floor, trees and props • New grass, connected dirt paths, rocks and flowers"
	subtitle.position = Vector2(28, 54)
	subtitle.modulate = Color("a9c4b7")
	add_child(subtitle)
	map_row = HBoxContainer.new()
	map_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_row.offset_left = 24
	map_row.offset_right = -24
	map_row.offset_top = 112
	map_row.offset_bottom = -58
	map_row.add_theme_constant_override("separation", 16)
	add_child(map_row)
	for new_art in [false, true]:
		var container := SubViewportContainer.new()
		container.stretch = true
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_row.add_child(container)
		containers.append(container)
		var viewport := SubViewport.new()
		viewport.disable_3d = true
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(viewport)
		var world := Node2D.new()
		world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		viewport.add_child(world)
		_build_map(world, new_art)
		var camera := Camera2D.new()
		viewport.add_child(camera)
		cameras.append(camera)
		var caption := Label.new()
		caption.text = "NEW SHEET · grass + dirt" if new_art else "EXISTING · TX forest grass"
		caption.position = Vector2(656 if new_art else 28, 86)
		caption.add_theme_font_size_override("font_size", 18)
		add_child(caption)
		captions.append(caption)
	var instructions := Label.new()
	instructions.text = "Drag to pan • Wheel to zoom • 1 Existing / 2 New / 3 Both • R Reset"
	instructions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	instructions.position = Vector2(28, -38)
	add_child(instructions)
	_sync_cameras()
	resized.connect(_layout_captions)
	_layout_captions()
	if "--forest-capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()

func _build_map(world: Node2D, new_art: bool) -> void:
	var floor_layer := Node2D.new()
	floor_layer.z_index = -10
	world.add_child(floor_layer)
	if new_art:
		TERRAIN_ART.build_ground(floor_layer, layout, CELL)
	else:
		for value: Variant in layout.cells:
			var cell: Vector2i = value
			var ground := SlasherForestArt.make_ground_sprite(cell, CELL)
			ground.position = Vector2(cell) * CELL + Vector2.ONE * CELL / 2.0
			floor_layer.add_child(ground)
	var walls := SlasherWallGenerator.new()
	walls.profile_id = String(DungeonRuntimeProfile.get_profile("forest").get("wall_profile", "forest"))
	walls.render_collisions = false
	world.add_child(walls)
	walls.generate(layout.cells)
	var decor := Node2D.new()
	decor.y_sort_enabled = true
	world.add_child(decor)
	for record: Dictionary in layout.decorations:
		var sprite := TERRAIN_ART.make_decoration(String(record.kind)) if new_art else SlasherForestArt.make_sprite(String(record.kind))
		sprite.position += Vector2(record.cell) * CELL + Vector2(24, 24) + Vector2(record.offset)
		decor.add_child(sprite)
	for record: Dictionary in layout.solid_props:
		var sprite := SlasherForestArt.make_sprite(String(record.kind))
		sprite.position += Vector2(record.cell) * CELL + Vector2(24, 24)
		decor.add_child(sprite)
	for record: Dictionary in [
		{"cell": layout.start, "kind": "campfire"},
		{"cell": layout.exit, "kind": "exit"},
		{"cell": layout.merchant, "kind": "merchant"}]:
		var sprite := SlasherForestArt.make_sprite(record.kind)
		if record.kind == "campfire":
			sprite.scale = Vector2.ONE * (72.0 / maxf(sprite.texture.get_width(), sprite.texture.get_height()))
		sprite.position += Vector2(record.cell) * CELL + Vector2(24, 24)
		decor.add_child(sprite)

func _sync_cameras() -> void:
	for camera in cameras:
		camera.position = center
		camera.zoom = Vector2.ONE * magnification

func _layout_captions() -> void:
	if captions.size() < 2: return
	captions[0].visible = containers[0].visible
	captions[1].visible = containers[1].visible
	captions[1].position.x = 28 if mode == 2 else size.x / 2.0 + 16

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			magnification = clampf(magnification * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 0.15, 2.0)
	if event is InputEventMouseMotion and dragging:
		center -= event.relative / magnification
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			center = _overview_center()
			magnification = 0.37
		if event.keycode in [KEY_1, KEY_2, KEY_3]:
			mode = event.keycode - KEY_1 + 1
			containers[0].visible = mode != 2
			containers[1].visible = mode != 1
			_layout_captions()
	_sync_cameras()

func _capture() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/forest_tileset_comparison.png")
	center = Vector2(layout.rooms[0].get_center()) * CELL
	magnification = 0.85
	_sync_cameras()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/forest_tileset_comparison_detail.png")
	# Exercise the real comparison controls after rendering the previews.
	for key in [KEY_1, KEY_2, KEY_3, KEY_R]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		_input(event)
		if key == KEY_1: assert(containers[0].visible and not containers[1].visible)
		if key == KEY_2: assert(not containers[0].visible and containers[1].visible)
		if key == KEY_3: assert(containers[0].visible and containers[1].visible)
		if key == KEY_R: assert(center == _overview_center() and is_equal_approx(magnification, 0.37))
	print("Forest comparison rendered; existing/new/split/reset controls verified.")
	get_tree().quit()
