class_name FloatingDamageNumber
extends Node2D

var label: Label

## Creates and styles the label, selects elemental color, and returns self for fluent construction. Call
## before adding the node to the tree so _ready() sees a complete label.
func setup(amount: int, damage_type: String, is_critical := false) -> FloatingDamageNumber:
	label=Label.new(); label.text=str(amount); label.position=Vector2(-40,-18); label.size=Vector2(80,36)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size",26 if is_critical else 21)
	label.add_theme_color_override("font_color",_damage_color(damage_type)); label.add_theme_color_override("font_outline_color",Color("#24140f")); label.add_theme_constant_override("outline_size",5)
	add_child(label); return self

## Starts randomized upward drift, scale pop, alpha fade, and eventual queue_free(). The effect owns its
## lifetime.
func _ready() -> void:
	var drift:=Vector2(randf_range(-16,16),-58)
	var tween:=create_tween().set_parallel(true)
	tween.tween_property(self,"position",position+drift,0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self,"scale",Vector2(1.15,1.15),0.16).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self,"modulate:a",0.0,0.35).set_delay(0.38)
	tween.chain().tween_callback(queue_free)

## Maps known damage-type strings to display colors and returns white for unknown/future types.
func _damage_color(type: String) -> Color:
	return CombatFeedback.damage_color(type)
