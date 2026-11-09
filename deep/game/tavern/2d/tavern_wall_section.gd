@tool
extends Node2D
class_name TavernWallSection

## Side walls are viewed from above, using the same timber as the face-on walls.
@export var side_profile := false:
	set(value):
		side_profile = value
		_refresh_section()

## Foreground architecture fades locally when it covers the controlled character.
@export var occlusion_target_path: NodePath
var _occlusion_target: Node2D

@export var section_id := "wall_section"
@export var section_texture: Texture2D:
	set(value):
		section_texture = value
		_refresh_section()
@export var visual_scale := Vector2.ONE:
	set(value):
		visual_scale = value
		_refresh_section()
@export var connection_tags: PackedStringArray = ["timber_wall"]
@export var collision_size := Vector2(220.0, 32.0):
	set(value):
		collision_size = value
		_refresh_section()
@export var collision_offset := Vector2(0.0, 92.0):
	set(value):
		collision_offset = value
		_refresh_section()
@export var obstacle_enabled := true:
	set(value):
		obstacle_enabled = value
		_refresh_section()
@export var section_enabled := true:
	set(value):
		section_enabled = value
		_refresh_section()


func _ready() -> void:
	_refresh_section()
	if not Engine.is_editor_hint() and not occlusion_target_path.is_empty():
		_occlusion_target = get_node_or_null(occlusion_target_path) as Node2D
	set_process(_occlusion_target != null)


func _process(delta: float) -> void:
	if not is_instance_valid(_occlusion_target):
		set_process(false)
		return
	var sprite := get_node("Visual") as Sprite2D
	var feet := sprite.to_local(_occlusion_target.global_position)
	var head := sprite.to_local(_occlusion_target.to_global(Vector2(0, -48)))
	var bounds := sprite.get_rect().grow(12.0)
	var obscured := bounds.intersects(
		Rect2(head.min(feet) - Vector2(12, 0), Vector2(24, absf(feet.y - head.y)))
	)
	sprite.modulate.a = move_toward(sprite.modulate.a, 0.35 if obscured else 1.0, delta * 5.0)


func _refresh_section() -> void:
	queue_redraw()
	if not is_inside_tree():
		return
	var sprite := get_node_or_null("Visual") as Sprite2D
	if sprite != null:
		sprite.texture = section_texture
		sprite.scale = visual_scale
		sprite.visible = section_enabled and not side_profile
	var body := get_node_or_null("CollisionBody") as StaticBody2D
	if body != null:
		body.position = collision_offset
		body.process_mode = (
			Node.PROCESS_MODE_INHERIT
			if section_enabled and obstacle_enabled
			else Node.PROCESS_MODE_DISABLED
		)
	var collision := get_node_or_null("CollisionBody/CollisionShape2D") as CollisionShape2D
	if collision != null:
		var rectangle := RectangleShape2D.new()
		rectangle.size = collision_size
		collision.shape = rectangle
		collision.disabled = not section_enabled or not obstacle_enabled
	var obstacle := get_node_or_null("NavigationObstacle2D") as NavigationObstacle2D
	if obstacle != null:
		obstacle.position = collision_offset
		var half := collision_size * 0.5
		obstacle.vertices = PackedVector2Array(
			[
				Vector2(-half.x, -half.y),
				Vector2(half.x, -half.y),
				Vector2(half.x, half.y),
				Vector2(-half.x, half.y),
			]
		)
		obstacle.avoidance_enabled = section_enabled and obstacle_enabled


func _draw() -> void:
	if not side_profile or not section_enabled or section_texture == null:
		return
	var rect := Rect2(collision_offset - collision_size * 0.5, collision_size)
	# A shallow inner face and a continuous top beam keep the floor plan readable.
	draw_rect(rect.grow(3.0), Color("21170f"))
	var y := rect.position.y
	while y < rect.end.y:
		var height := minf(110.0, rect.end.y - y)
		draw_texture_rect_region(
			section_texture,
			Rect2(rect.position.x, y, rect.size.x, height),
			Rect2(10, 75, 36, height)
		)
		y += height
	draw_line(
		rect.position + Vector2(3, 0),
		Vector2(rect.position.x + 3, rect.end.y),
		Color("9a7143"),
		2.0
	)
	draw_line(
		Vector2(rect.end.x - 3, rect.position.y), rect.end - Vector2(3, 0), Color("322116"), 4.0
	)
	# End caps and spaced joints replace the repeated sideways plaster panels.
	y = rect.position.y
	while y < rect.end.y:
		var cap_y := minf(y, rect.end.y - 24.0)
		draw_texture_rect_region(
			section_texture,
			Rect2(rect.position.x - 4, cap_y, rect.size.x + 8, 24),
			Rect2(4, 0, 48, 69)
		)
		y += 176.0
	draw_texture_rect_region(
		section_texture,
		Rect2(rect.position.x - 4, rect.end.y - 24, rect.size.x + 8, 24),
		Rect2(4, 0, 48, 69)
	)
