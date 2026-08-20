extends Area2D
class_name Bullet

enum Owner { PLAYER, ENEMY }

@export var speed: float = 400.0
@export var damage: int = 1
@export var lifetime: float = 4.0

var direction: Vector2 = Vector2.RIGHT
var owner_type: Owner = Owner.ENEMY

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if owner_type == Owner.PLAYER:
		$Sprite.color = Color(0.4, 0.85, 1.0)
	else:
		$Sprite.color = Color(1.0, 0.45, 0.2)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if owner_type == Owner.ENEMY and body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
	elif owner_type == Owner.PLAYER and body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("walls"):
		queue_free()
