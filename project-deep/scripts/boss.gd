extends "res://scripts/enemy.gd"

const BURST_COUNT := 14

func _ready() -> void:
	max_health = 25
	health = max_health
	move_speed = 35.0
	shoot_interval = 1.2
	bullet_speed = 240.0
	add_to_group("enemies")
	_shoot_timer = randf_range(0.5, shoot_interval)
	_player = get_tree().get_first_node_in_group("player")
	sprite.size = Vector2(40, 40)
	sprite.position = Vector2(-20, -20)
	sprite.color = Color(0.6, 0.1, 0.8)
	add_to_group("bosses")

func _shoot_at_player() -> void:
	if not is_instance_valid(_player):
		return

	var to_player := (_player.global_position - global_position).normalized()
	_fire_bullet(to_player)
	_fire_bullet(to_player.rotated(0.25))
	_fire_bullet(to_player.rotated(-0.25))

	for i in BURST_COUNT:
		_fire_bullet(Vector2.RIGHT.rotated(TAU * float(i) / float(BURST_COUNT)))

func set_difficulty(floor_num: int) -> void:
	max_health = 20 + floor_num * 3
	health = max_health
	shoot_interval = maxf(0.8, 1.4 - floor_num * 0.04)
	bullet_speed = 220.0 + floor_num * 8.0

func die() -> void:
	defeated.emit(true)
	_try_drop_powerup(true)
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(2.0, 2.0), 0.2)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
