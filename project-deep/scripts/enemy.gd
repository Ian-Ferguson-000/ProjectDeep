extends CharacterBody2D

signal defeated(is_boss: bool)

const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const POWERUP_SCENE := preload("res://scenes/powerup.tscn")
const POWERUP_DROP_CHANCE := 0.35

@export var move_speed: float = 60.0
@export var max_health: int = 3
@export var shoot_interval: float = 1.8
@export var bullet_speed: float = 280.0

var health: int
var _shoot_timer: float = 0.0
var _player: Node2D

@onready var sprite: ColorRect = $Sprite

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	_shoot_timer = randf_range(0.5, shoot_interval)
	_player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		return

	var to_player := _player.global_position - global_position
	if to_player.length() > 80.0:
		velocity = to_player.normalized() * move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot_at_player()
		_shoot_timer = shoot_interval

func _shoot_at_player() -> void:
	if not is_instance_valid(_player):
		return

	var dir := (_player.global_position - global_position).normalized()
	_fire_bullet(dir)

	# Simple spread pattern for bullet hell feel
	for angle_offset in [-0.3, 0.3]:
		_fire_bullet(dir.rotated(angle_offset))

func _fire_bullet(dir: Vector2) -> void:
	var bullet: Bullet = BULLET_SCENE.instantiate()
	bullet.global_position = global_position
	bullet.direction = dir
	bullet.owner_type = Bullet.Owner.ENEMY
	bullet.speed = bullet_speed
	bullet.damage = 1
	get_tree().current_scene.get_node("Bullets").add_child(bullet)

func take_damage(amount: int) -> void:
	health -= amount
	sprite.modulate = Color(1.0, 0.6, 0.6)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(0.9, 0.2, 0.3), 0.1)
	if health <= 0:
		die()

func die() -> void:
	defeated.emit(false)
	_try_drop_powerup(false)
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.15)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)

func _try_drop_powerup(force_drop: bool) -> void:
	if not force_drop and randf() > POWERUP_DROP_CHANCE:
		return
	var powerup: PowerUp = POWERUP_SCENE.instantiate()
	powerup.pickup_type = PowerUp.random_type()
	powerup.global_position = global_position
	var floor_node := get_parent().get_parent()
	if floor_node.has_node("Pickups"):
		floor_node.get_node("Pickups").add_child(powerup)

func set_difficulty(floor_num: int) -> void:
	max_health = 2 + floor_num
	health = max_health
	shoot_interval = maxf(0.6, 1.8 - floor_num * 0.08)
	bullet_speed = 260.0 + floor_num * 10.0
