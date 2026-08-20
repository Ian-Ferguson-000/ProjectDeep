extends Area2D
class_name PowerUp

enum Type { HEAL, SPEED, FIRE_RATE, DAMAGE }

@export var pickup_type: Type = Type.HEAL

@onready var sprite: ColorRect = $Sprite

const COLORS := {
	Type.HEAL: Color(0.2, 1.0, 0.4),
	Type.SPEED: Color(1.0, 0.85, 0.2),
	Type.FIRE_RATE: Color(0.9, 0.4, 1.0),
	Type.DAMAGE: Color(1.0, 0.35, 0.35),
}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	sprite.color = COLORS[pickup_type]
	add_to_group("powerups")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("apply_powerup"):
		body.apply_powerup(pickup_type)
		queue_free()

static func random_type() -> Type:
	var roll := randi() % 4
	match roll:
		0: return Type.HEAL
		1: return Type.SPEED
		2: return Type.FIRE_RATE
		_: return Type.DAMAGE
