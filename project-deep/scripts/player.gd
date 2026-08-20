extends CharacterBody2D

const BULLET_SCENE := preload("res://scenes/bullet.tscn")

@export var move_speed: float = 220.0
@export var shoot_cooldown: float = 0.12
@export var max_health: int = 5

var health: int
var _shoot_timer: float = 0.0
var damage_multiplier: float = 1.0

var _base_move_speed: float
var _base_shoot_cooldown: float
var _speed_multiplier: float = 1.0
var _fire_rate_multiplier: float = 1.0
var _active_buff_label: String = ""

@onready var sprite: ColorRect = $Sprite

func _ready() -> void:
	health = max_health
	_base_move_speed = move_speed
	_base_shoot_cooldown = shoot_cooldown
	add_to_group("player")

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * _base_move_speed * _speed_multiplier
	move_and_slide()

	_shoot_timer -= delta
	if Input.is_action_pressed("shoot") and _shoot_timer <= 0.0:
		_shoot()
		_shoot_timer = _base_shoot_cooldown * _fire_rate_multiplier

func _shoot() -> void:
	var mouse_pos := get_global_mouse_position()
	var dir := (mouse_pos - global_position).normalized()
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT
		
	# var bullet: Bullet_Scene.instantiate()
	var bullet: Bullet = BULLET_SCENE.instantiate()
	bullet.global_position = global_position + dir * 16.0
	bullet.direction = dir
	bullet.owner_type = Bullet.Owner.PLAYER
	bullet.speed = 500.0
	bullet.damage = maxi(1, int(round(damage_multiplier)))
	get_tree().current_scene.get_node("Bullets").add_child(bullet)

func take_damage(amount: int) -> void:
	health -= amount
	sprite.modulate = Color(1.0, 0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if health <= 0:
		die()

func die() -> void:
	set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_on_death_finished)

func _on_death_finished() -> void:
	var gm := get_tree().current_scene
	if gm.has_method("on_player_died"):
		gm.on_player_died()
	queue_free()

func heal(amount: int) -> void:
	health = mini(health + amount, max_health)
# func apply_powerup(type: PowerUp.Type) -> void:
func apply_powerup(type: PowerUp.Type) -> void:
	match type:
		PowerUp.Type.HEAL:
			heal(2)
			_show_buff("Healed!")
		PowerUp.Type.SPEED:
			_apply_timed_buff("speed", 1.5, 10.0, "Speed Up!")
		PowerUp.Type.FIRE_RATE:
			_apply_timed_buff("fire_rate", 0.5, 10.0, "Rapid Fire!")
		PowerUp.Type.DAMAGE:
			_apply_timed_buff("damage", 2.0, 10.0, "Power Shot!")

func _apply_timed_buff(kind: String, value: float, duration: float, label: String) -> void:
	match kind:
		"speed":
			_speed_multiplier = value
		"fire_rate":
			_fire_rate_multiplier = value
		"damage":
			damage_multiplier = value
	_active_buff_label = label
	_notify_buff(label)
	await get_tree().create_timer(duration).timeout
	match kind:
		"speed":
			_speed_multiplier = 1.0
		"fire_rate":
			_fire_rate_multiplier = 1.0
		"damage":
			damage_multiplier = 1.0
	if _active_buff_label == label:
		_active_buff_label = ""
		_notify_buff("")

func _show_buff(text: String) -> void:
	_notify_buff(text)
	get_tree().create_timer(1.2).timeout.connect(func(): _notify_buff(""), CONNECT_ONE_SHOT)

func _notify_buff(text: String) -> void:
	var gm := get_tree().current_scene
	if gm.has_method("set_buff_text"):
		gm.set_buff_text(text)

func get_buff_text() -> String:
	return _active_buff_label
