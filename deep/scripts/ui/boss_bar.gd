extends CanvasLayer
class_name SlasherBossBar

## A big boss health bar centred across the top of the screen, with the boss's
## name above it and optional notches at phase thresholds. Add it as a child of
## the boss: it follows that boss's health and goes away with it.

const WIDTH := 640.0
const TOP := 14.0

var enemy: Node
var fill: ColorRect
var title := ""
var notches: Array = []
var colour := Color("#c0392b")

func setup(boss: Node, boss_name: String, phase_notches: Array = [], bar_colour: Color = Color("#c0392b")) -> SlasherBossBar:
	enemy = boss; title = boss_name; notches = phase_notches; colour = bar_colour
	name = "BossBar"
	return self

func _ready() -> void:
	layer = 11
	var root := Control.new()
	root.name = "Bar"
	root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	root.offset_left = -WIDTH * 0.5; root.offset_right = WIDTH * 0.5
	root.offset_top = TOP; root.offset_bottom = TOP + 44.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var label := Label.new()
	label.name = "Name"
	label.text = title.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2.ZERO; label.size = Vector2(WIDTH,20)
	label.add_theme_font_size_override("font_size",15)
	label.add_theme_color_override("font_color",Color("#f0c552"))
	label.add_theme_color_override("font_outline_color",Color.BLACK)
	label.add_theme_constant_override("outline_size",5)
	root.add_child(label)
	var back := ColorRect.new(); back.color = Color(0.05,0.03,0.02,0.9); back.position = Vector2(0,22); back.size = Vector2(WIDTH,16); root.add_child(back)
	fill = ColorRect.new(); fill.name = "Fill"; fill.color = colour; fill.position = Vector2(2,24); fill.size = Vector2(WIDTH - 4.0,12); root.add_child(fill)
	for mark in notches:
		var notch := ColorRect.new(); notch.color = Color(1,0.85,0.4,0.9); notch.position = Vector2(2 + (WIDTH - 4.0) * float(mark) - 1,20); notch.size = Vector2(2,20); root.add_child(notch)

func fraction() -> float:
	if not is_instance_valid(enemy): return 0.0
	return clampf(float(enemy.get("health")) / maxf(1.0,float(enemy.get("max_health"))),0.0,1.0)

func _process(_delta: float) -> void:
	if not is_instance_valid(enemy) or bool(enemy.get("dead")):
		visible = false
		return
	fill.size.x = (WIDTH - 4.0) * fraction()
