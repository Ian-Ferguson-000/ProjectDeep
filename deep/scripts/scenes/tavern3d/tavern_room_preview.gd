extends Node3D
## Isolated art preview. The existing 2D tavern remains the campaign's hub.

const ROOM := preload("res://assets/tavern3d/hearth_room.glb")
var room: Node3D
var camera: Camera3D
var yaw := 0.60
var elevation := 0.72
var distance := 23.0
var cutaway := true
var dragging := false
var help_label: Label

func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	room = ROOM.instantiate()
	room.name = "HearthRoom"
	add_child(room)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("242934")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b9c8de")
	settings.ambient_light_energy = 0.65
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.ssao_enabled = true
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("ffe3b3")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.light_angular_distance = 3.0
	add_child(sun)
	for x in [-6.0,-1.1,3.3,8.2]:
		_add_lamp(Vector3(x,2.45,-4.8),Color("ffb44d"),1.4,4.5)
	_add_lamp(Vector3(-7.6,1.1,-3.35),Color("ff7d2e"),2.2,5.0)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 150.0
	add_child(camera)
	camera.make_current()
	_update_camera()
	_set_cutaway()
	var ui := CanvasLayer.new()
	add_child(ui)
	help_label = Label.new()
	help_label.position = Vector2(24,20)
	help_label.add_theme_font_size_override("font_size",18)
	help_label.add_theme_color_override("font_outline_color",Color.BLACK)
	help_label.add_theme_constant_override("outline_size",6)
	ui.add_child(help_label)
	_update_help()

func _add_lamp(location: Vector3, color: Color, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.position = location
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	add_child(light)

func _update_camera() -> void:
	var focus := Vector3(0,1,0)
	camera.position = focus + Vector3(sin(yaw)*cos(elevation),sin(elevation),cos(yaw)*cos(elevation))*32.0
	camera.look_at(focus)
	camera.size = distance

func _set_cutaway() -> void:
	for group_name in ["FrontWall","EastWall","CeilingBeams"]:
		var group := room.find_child(group_name,true,false) as Node3D
		if group != null: group.visible = not cutaway

func _update_help() -> void:
	help_label.text = "THE HEARTH / 3D ROOM STUDY\nDrag to orbit · Scroll to zoom · C: full room / cutaway · R: reset\n18 × 11 m · %s" % ("Cutaway" if cutaway else "Full room")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(8.0,distance-1.0)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(40.0,distance+1.0)
		_update_camera()
	elif event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x*0.006
		elevation = clampf(elevation+event.relative.y*0.006,0.15,1.45)
		_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			cutaway = not cutaway
			_set_cutaway()
			_update_help()
		elif event.keycode == KEY_R:
			yaw=0.60; elevation=0.72; distance=23.0
			_update_camera()
