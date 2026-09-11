@tool
extends Node2D
class_name TavernWallSection

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

func _refresh_section() -> void:
	if not is_inside_tree():
		return
	var sprite := get_node_or_null("Visual") as Sprite2D
	if sprite != null:
		sprite.texture = section_texture
		sprite.scale = visual_scale
		sprite.visible = section_enabled
	var body := get_node_or_null("CollisionBody") as StaticBody2D
	if body != null:
		body.position = collision_offset
		body.process_mode = Node.PROCESS_MODE_INHERIT if section_enabled and obstacle_enabled else Node.PROCESS_MODE_DISABLED
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
		obstacle.vertices = PackedVector2Array([
			Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(half.x, half.y), Vector2(-half.x, half.y),
		])
		obstacle.avoidance_enabled = section_enabled and obstacle_enabled
