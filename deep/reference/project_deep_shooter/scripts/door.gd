extends Area2D

signal door_entered(door: Area2D)
signal door_unlocked

@export var direction: Vector2 = Vector2.UP

@onready var sprite: ColorRect = $Sprite

var is_unlocked: bool = false
var _used: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("doors")
	set_locked(true)

func set_locked(locked: bool) -> void:
	is_unlocked = not locked
	if is_unlocked:
		sprite.color = Color(0.2, 0.9, 0.4)
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.85)
		door_unlocked.emit()
	else:
		sprite.color = Color(0.35, 0.35, 0.4)
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.45)

func unlock() -> void:
	if is_unlocked:
		return
	set_locked(false)
	var tween := create_tween()
	tween.set_loops(3)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.2)
	tween.tween_property(sprite, "modulate:a", 0.7, 0.2)

func _on_body_entered(body: Node2D) -> void:
	if _used or not is_unlocked:
		return
	if body.is_in_group("player"):
		_used = true
		sprite.modulate = Color(0.5, 1.0, 0.5)
		door_entered.emit(self)

func setup(dir: Vector2, pos: Vector2) -> void:
	direction = dir
	global_position = pos
	rotation = dir.angle() + PI / 2.0
