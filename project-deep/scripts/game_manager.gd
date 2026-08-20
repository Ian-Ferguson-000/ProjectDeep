extends Node2D

const FLOOR_SCENE := preload("res://scenes/floor.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var current_floor_num: int = 0
var _current_floor: Node2D
var _player: CharacterBody2D
var _transitioning: bool = false
var _door_is_open: bool = false

@onready var floor_container: Node2D = $FloorContainer
@onready var bullets: Node2D = $Bullets
@onready var camera: Camera2D = $Camera2D
@onready var hud: CanvasLayer = $HUD
@onready var floor_label: Label = $HUD/FloorLabel
@onready var health_label: Label = $HUD/HealthLabel
@onready var enemies_label: Label = $HUD/EnemiesLabel
@onready var buff_label: Label = $HUD/BuffLabel
@onready var hint_label: Label = $HUD/HintLabel
@onready var minimap: Control = $HUD/Minimap

func _ready() -> void:
	_spawn_player()
	_generate_floor(1)

func _spawn_player() -> void:
	if PLAYER_SCENE == null:
		push_error("PLAYER_SCENE is null!")
		return

	_player = PLAYER_SCENE.instantiate()

	if _player == null:
		push_error("Failed to instantiate player scene!")
		return

	if _player.get_parent() == null:
		add_child(_player)
	_player.z_index = 10




func _generate_floor(floor_num: int) -> void:
	if _current_floor:
		_current_floor.queue_free()
		_clear_bullets()

	current_floor_num = floor_num
	_door_is_open = false
	_current_floor = FLOOR_SCENE.instantiate()
	floor_container.add_child(_current_floor)
	_current_floor.generate(floor_num)
	_current_floor.floor_cleared.connect(_on_floor_cleared)
	_current_floor.all_enemies_defeated.connect(_on_all_enemies_defeated)
	_current_floor.enemy_count_changed.connect(_on_enemy_count_changed)

	_player.global_position = _current_floor.global_position + _current_floor.get_spawn_position()
	minimap.setup(_current_floor, _player)
	minimap.set_boss_floor(_current_floor.is_boss_floor)
	minimap.set_door_unlocked(false)
	_update_hud()

func _on_enemy_count_changed(remaining: int, _total: int) -> void:
	enemies_label.text = "Enemies: %d" % remaining

func _on_all_enemies_defeated() -> void:
	_door_is_open = true
	minimap.set_door_unlocked(true)
	hint_label.text = "Door unlocked! Walk through the green door."

func _on_floor_cleared(door: Area2D) -> void:
	if _transitioning:
		return
	_transitioning = true

	var door_dir: Vector2 = door.direction
	var tween := create_tween()
	tween.tween_property(_player, "global_position",
		_player.global_position + door_dir * 120.0, 0.4)
	tween.tween_callback(_advance_floor)

func _advance_floor() -> void:
	_generate_floor(current_floor_num + 1)
	_transitioning = false

func _clear_bullets() -> void:
	for child in bullets.get_children():
		child.queue_free()

func _process(_delta: float) -> void:
	if is_instance_valid(_player):
		camera.global_position = _player.global_position
		health_label.text = "HP: %d / %d" % [_player.health, _player.max_health]

func on_player_died() -> void:
	hint_label.text = "You died! Restart the game to try again."
	floor_label.text = "Game Over"

func set_buff_text(text: String) -> void:
	buff_label.text = text

func _update_hud() -> void:
	if _current_floor.is_boss_floor:
		floor_label.text = "Floor %d — BOSS" % current_floor_num
		hint_label.text = "Boss floor! Defeat the purple enemy to unlock the door."
	else:
		floor_label.text = "Floor %d" % current_floor_num
		hint_label.text = "Clear all enemies to unlock the door."
	enemies_label.text = "Enemies: %d" % _current_floor.get_enemies_remaining()
	buff_label.text = ""
