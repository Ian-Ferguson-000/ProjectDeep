extends Control
## A short, code-drawn celebration using the Hearth's existing gold palette.
var victorious := false
var elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not is_visible_in_tree() or elapsed >= 3.0: return
	elapsed = minf(elapsed + delta, 3.0)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var gold := Color("#ffd36a") if victorious else Color("#a99678")
	for ring in range(5, 0, -1):
		draw_circle(center, 34 + ring * 5, Color(gold, 0.018 * (6 - ring)))
	draw_arc(center, 45, 0, TAU, 80, Color(gold, 0.35), 1.0, true)
	for side in [-1, 1]:
		for i in range(7):
			var angle := -0.2 + i * 0.22
			var pos := center + Vector2(side * cos(angle) * 53, 25 - sin(angle) * 55)
			var leaf := PackedVector2Array([pos, pos + Vector2(side * 9, -9), pos + Vector2(side * 5, -16), pos + Vector2(-side * 3, -8)])
			draw_colored_polygon(leaf, Color(gold, 0.65 + i * 0.04))
	var shield := PackedVector2Array([center+Vector2(-24,-27),center+Vector2(24,-27),center+Vector2(21,12),center+Vector2(0,32),center+Vector2(-21,12),center+Vector2(-24,-27)])
	draw_colored_polygon(shield, Color("#30261a"))
	draw_polyline(shield, gold, 2.0, true)
	# Upright blade and crossguard: the party's achievement, rather than new art.
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-21),center+Vector2(5,-12),center+Vector2(3,10),center+Vector2(-3,10),center+Vector2(-5,-12)]), gold)
	draw_line(center+Vector2(-12,10),center+Vector2(12,10),gold,3,true)
	draw_line(center+Vector2(0,10),center+Vector2(0,23),gold,4,true)
	if victorious and elapsed < 2.8:
		for i in range(18):
			var angle := i * 2.399
			var distance := 32 + elapsed * (12 + i % 4 * 5)
			var pos := center + Vector2.from_angle(angle) * distance
			var alpha := clampf(1.0 - elapsed / 2.8, 0, 1) * 0.8
			draw_circle(pos, 1.5 if i % 2 else 2.5, Color(gold, alpha))
