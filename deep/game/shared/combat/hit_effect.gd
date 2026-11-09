class_name CombatHitEffect
extends Node2D

var color:=Color.WHITE
var radius:=8.0

## Selects the effect color and returns self. Call before adding to the scene tree.
func setup(damage_type: String) -> CombatHitEffect:
	color=_damage_color(damage_type); return self

## Queues drawing, expands/fades the effect, and frees it after the tween.
func _ready() -> void:
	queue_redraw()
	var tween:=create_tween().set_parallel(true)
	tween.tween_property(self,"scale",Vector2(2.2,2.2),0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self,"modulate:a",0.0,0.22)
	tween.chain().tween_callback(queue_free)

## Draws the circular ring and eight radial sparks using the selected color.
func _draw() -> void:
	draw_arc(Vector2.ZERO,radius,0,TAU,18,color,3,true)
	for i in 8:
		var direction:=Vector2.from_angle(TAU*i/8.0)
		draw_line(direction*5,direction*14,color,3,true)

## Maps damage types to burst colors, defaulting to white.
func _damage_color(type: String) -> Color:
	return CombatFeedback.damage_color(type)
