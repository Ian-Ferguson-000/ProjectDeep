@tool
extends Node2D
class_name TavernProp

signal interaction_requested(prop_id: String)

@export var prop_id := ""
@export var display_name := "Inspect"
@export var interaction_text := "Nothing unusual catches your eye."
@export var interaction_enabled := true
@export var obstacle_enabled := false
@export var prop_texture:Texture2D:
	set(value):
		prop_texture=value
		_refresh_prop()
@export var visual_scale:=Vector2.ONE:
	set(value):
		visual_scale=value
		_refresh_prop()
@export var visual_offset:=Vector2.ZERO:
	set(value):
		visual_offset=value
		_refresh_prop()
@export var collision_size:=Vector2(120.0,48.0):
	set(value):
		collision_size=value
		_refresh_prop()
@export var collision_offset:=Vector2.ZERO:
	set(value):
		collision_offset=value
		_refresh_prop()
@export var prop_enabled:=true:
	set(value):
		prop_enabled=value
		_refresh_prop()

func _ready() -> void:
	add_to_group("tavern_interactable")
	_refresh_prop()

func _refresh_prop()->void:
	if not is_inside_tree():return
	var visual:=get_node_or_null("Visual") as Sprite2D
	if visual!=null:
		visual.texture=prop_texture;visual.scale=visual_scale;visual.position=visual_offset;visual.visible=prop_enabled
	var body:=get_node_or_null("CollisionBody") as StaticBody2D
	if body!=null:
		body.position=collision_offset
		body.process_mode=Node.PROCESS_MODE_INHERIT if prop_enabled and obstacle_enabled else Node.PROCESS_MODE_DISABLED
	var collision:=get_node_or_null("CollisionBody/CollisionShape2D") as CollisionShape2D
	if collision!=null:
		var rectangle:=RectangleShape2D.new();rectangle.size=collision_size;collision.shape=rectangle
		collision.disabled=not prop_enabled or not obstacle_enabled
	var obstacle:=get_node_or_null("NavigationObstacle2D") as NavigationObstacle2D
	if obstacle!=null:
		obstacle.position=collision_offset
		var half:=collision_size*0.5
		obstacle.vertices=PackedVector2Array([Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(half.x,half.y),Vector2(-half.x,half.y)])
		obstacle.avoidance_enabled=prop_enabled and obstacle_enabled

func interact(_actor: Node) -> String:
	if not interaction_enabled or not prop_enabled:
		return ""
	interaction_requested.emit(prop_id)
	return interaction_text

func prompt() -> String:
	return "[E] " + display_name if interaction_enabled else ""
