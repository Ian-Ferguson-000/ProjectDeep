extends Node2D

const DOOR_SCENE := preload("res://scenes/door.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const BOSS_SCENE := preload("res://scenes/boss.tscn")
const BOSS_EVERY_N_FLOORS := 5

signal floor_cleared
signal all_enemies_defeated
signal enemy_count_changed(remaining: int, total: int)

@export var floor_width: float = 720.0
@export var floor_height: float = 480.0
@export var wall_thickness: float = 24.0
@export var door_width: float = 80.0

var floor_number: int = 1
var is_boss_floor: bool = false
var _door_direction: Vector2 = Vector2.UP
var _active_door: Area2D
var _enemies_remaining: int = 0
var _enemies_total: int = 0

@onready var walls: Node2D = $Walls
@onready var enemies: Node2D = $Enemies
@onready var doors: Node2D = $Doors
@onready var pickups: Node2D = $Pickups
@onready var background: ColorRect = $Background

func generate(floor_num: int) -> void:
	floor_number = floor_num
	is_boss_floor = floor_num % BOSS_EVERY_N_FLOORS == 0
	_enemies_remaining = 0
	_enemies_total = 0
	_clear_children()
	_build_room()
	if is_boss_floor:
		_spawn_boss()
	else:
		_spawn_enemies()
	_spawn_door()
	background.color = _floor_color(floor_num)
	if is_boss_floor:
		background.color = Color(0.18, 0.08, 0.22)

func _clear_children() -> void:
	for child in walls.get_children():
		child.queue_free()
	for child in enemies.get_children():
		child.queue_free()
	for child in doors.get_children():
		child.queue_free()
	for child in pickups.get_children():
		child.queue_free()

func _build_room() -> void:
	var hw := floor_width / 2.0
	var hh := floor_height / 2.0
	var t := wall_thickness

	var sides := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	_door_direction = sides[randi() % sides.size()]

	_add_wall(Vector2(0, -hh - t / 2.0), Vector2(floor_width + t * 2, t), _door_direction == Vector2.UP)
	_add_wall(Vector2(0, hh + t / 2.0), Vector2(floor_width + t * 2, t), _door_direction == Vector2.DOWN)
	_add_wall(Vector2(-hw - t / 2.0, 0), Vector2(t, floor_height), _door_direction == Vector2.LEFT)
	_add_wall(Vector2(hw + t / 2.0, 0), Vector2(t, floor_height), _door_direction == Vector2.RIGHT)

func _add_wall(pos: Vector2, size: Vector2, has_door: bool) -> void:
	if has_door:
		var gap := door_width
		if size.x > size.y:
			var half_len := (size.x - gap) / 2.0
			_create_wall_segment(pos + Vector2(-(gap / 2.0 + half_len / 2.0), 0), Vector2(half_len, size.y))
			_create_wall_segment(pos + Vector2(gap / 2.0 + half_len / 2.0, 0), Vector2(half_len, size.y))
		else:
			var half_len := (size.y - gap) / 2.0
			_create_wall_segment(pos + Vector2(0, -(gap / 2.0 + half_len / 2.0)), Vector2(size.x, half_len))
			_create_wall_segment(pos + Vector2(0, gap / 2.0 + half_len / 2.0), Vector2(size.x, half_len))
	else:
		_create_wall_segment(pos, size)

func _create_wall_segment(pos: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 2
	wall.collision_mask = 0
	wall.add_to_group("walls")
	wall.position = pos

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)

	var visual := ColorRect.new()
	visual.size = size
	visual.position = -size / 2.0
	visual.color = Color(0.25, 0.25, 0.35)
	wall.add_child(visual)

	var wall_area := Area2D.new()
	wall_area.add_to_group("walls")
	var area_shape := CollisionShape2D.new()
	var area_rect := RectangleShape2D.new()
	area_rect.size = size
	area_shape.shape = area_rect
	wall_area.add_child(area_shape)
	wall.add_child(wall_area)

	walls.add_child(wall)

func _spawn_enemies() -> void:
	var count = min(floor_number, 8)
	var hw := floor_width / 2.0 - 60.0
	var hh := floor_height / 2.0 - 60.0

	for i in range(count):
		pass
		var enemy: CharacterBody2D = ENEMY_SCENE.instantiate()

		enemy.position = Vector2(randf_range(-hw, hw), randf_range(-hh, hh))
		_register_enemy(enemy)
		enemies.add_child(enemy)
		enemy.set_difficulty(floor_number)

func _spawn_boss() -> void:
	var boss: CharacterBody2D = BOSS_SCENE.instantiate()
	boss.position = Vector2.ZERO
	_register_enemy(boss)
	enemies.add_child(boss)
	boss.set_difficulty(floor_number)

func _register_enemy(enemy: CharacterBody2D) -> void:
	_enemies_total += 1
	_enemies_remaining += 1
	enemy.defeated.connect(_on_enemy_defeated)
	enemy_count_changed.emit(_enemies_remaining, _enemies_total)

func _on_enemy_defeated(_is_boss: bool) -> void:
	_enemies_remaining = maxi(0, _enemies_remaining - 1)
	enemy_count_changed.emit(_enemies_remaining, _enemies_total)
	if _enemies_remaining <= 0:
		_unlock_door()

func _unlock_door() -> void:
	if _active_door and _active_door.has_method("unlock"):
		_active_door.unlock()
	all_enemies_defeated.emit()

func _spawn_door() -> void:
	var hw := floor_width / 2.0
	var hh := floor_height / 2.0
	var door_pos := Vector2.ZERO

	if _door_direction == Vector2.UP:
		door_pos = Vector2(0, -hh - 12)
	elif _door_direction == Vector2.DOWN:
		door_pos = Vector2(0, hh + 12)
	elif _door_direction == Vector2.LEFT:
		door_pos = Vector2(-hw - 12, 0)
	elif _door_direction == Vector2.RIGHT:
		door_pos = Vector2(hw + 12, 0)

	var door: Area2D = DOOR_SCENE.instantiate()
	door.setup(_door_direction, door_pos)
	door.door_entered.connect(_on_door_entered)
	door.door_unlocked.connect(_on_door_unlocked)
	doors.add_child(door)
	_active_door = door

func _on_door_unlocked() -> void:
	pass

func _on_door_entered(door: Area2D) -> void:
	floor_cleared.emit(door)

func get_spawn_position() -> Vector2:
	var offset := -_door_direction * (floor_height * 0.3)
	return offset

func get_door_direction() -> Vector2:
	return _door_direction

func get_enemies_remaining() -> int:
	return _enemies_remaining

func _floor_color(floor_num: int) -> Color:
	var hue := fmod(floor_num * 0.07, 1.0)
	return Color.from_hsv(hue, 0.3, 0.15)
