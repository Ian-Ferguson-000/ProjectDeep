extends CanvasLayer
class_name SlasherBossBar

## A big boss health bar centred across the top of the screen: the boss's name
## between two ornaments, a bevelled frame, laurel wreaths curling round both
## ends, and a pale trail that shows the damage just dealt. Bosses get gold;
## mini bosses (gate and elite guardians) get silver. Optional notches mark
## phase thresholds. Add it as a child of the boss: it follows that boss's
## health and goes away with it. Everything is drawn in code, so it can be
## swapped for art later.

const WIDTH := 640.0
const TOP := 14.0
const BAR_Y := 24.0
const BAR_H := 16.0
## Room either side of the bar for the wreaths.
const SIDE := 46.0

var enemy: Node
var title := ""
var notches: Array = []
var colour := Color("#c0392b")
var gilded := true
var frame: BarFrame

func setup(boss: Node, boss_name: String, phase_notches: Array = [], bar_colour: Color = Color("#c0392b")) -> SlasherBossBar:
	enemy = boss; title = boss_name; notches = phase_notches; colour = bar_colour
	gilded = not (boss.get("mini_boss") == true and boss.get("boss") != true)
	name = "BossBar"
	return self

func _ready() -> void:
	layer = 11
	var root := Control.new()
	root.name = "Bar"
	root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	root.offset_left = -WIDTH * 0.5; root.offset_right = WIDTH * 0.5
	root.offset_top = TOP; root.offset_bottom = TOP + 52.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	frame = BarFrame.new(); frame.bar = self; frame.name = "Frame"
	frame.position = Vector2(-SIDE,0); frame.size = Vector2(WIDTH + SIDE * 2.0,52.0)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	var label := Label.new()
	label.name = "Name"
	label.text = title.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0,-2); label.size = Vector2(WIDTH,20)
	label.add_theme_font_size_override("font_size",15)
	label.add_theme_color_override("font_color",Color("#f6d77a") if gilded else Color("#e4e8ee"))
	label.add_theme_color_override("font_outline_color",Color("#1a0f05"))
	label.add_theme_constant_override("outline_size",6)
	root.add_child(label)

func fraction() -> float:
	if not is_instance_valid(enemy): return 0.0
	return clampf(float(enemy.get("health")) / maxf(1.0,float(enemy.get("max_health"))),0.0,1.0)

func _process(delta: float) -> void:
	if not is_instance_valid(enemy) or bool(enemy.get("dead")):
		visible = false
		return
	frame.tick(delta,fraction())

## The drawn bar: frame, fill, damage trail, wreaths and ornaments.
class BarFrame extends Control:
	var bar: SlasherBossBar
	var shown := 1.0
	var trail := 1.0
	var trail_hold := 0.0
	var flash := 0.0
	var time := 0.0

	func tick(delta: float, value: float) -> void:
		time += delta
		if value < shown - 0.0001:
			flash = 0.18
			trail_hold = 0.45
		shown = value
		# The pale trail waits a moment, then slides down to the real health.
		trail_hold = maxf(0.0,trail_hold - delta)
		if trail_hold <= 0.0: trail = move_toward(trail,shown,delta * 0.6)
		trail = maxf(trail,shown)
		flash = maxf(0.0,flash - delta)
		queue_redraw()

	func _metal() -> Array:
		# [highlight, base, shadow]
		if bar.gilded: return [Color("#ffe9a3"),Color("#d4a63a"),Color("#7a5514")]
		return [Color("#f4f7fb"),Color("#aab2bd"),Color("#5a616b")]

	func _draw() -> void:
		var metal := _metal()
		var left := SlasherBossBar.SIDE
		var width := SlasherBossBar.WIDTH
		var rect := Rect2(left,SlasherBossBar.BAR_Y,width,SlasherBossBar.BAR_H)
		# Wreaths behind the frame.
		_wreath(Vector2(left + 6.0,rect.get_center().y),-1.0,metal)
		_wreath(Vector2(left + width - 6.0,rect.get_center().y),1.0,metal)
		# Frame: dark edge, metal rim, inner shadow.
		draw_rect(rect.grow(5.0),Color("#140b04"))
		draw_rect(rect.grow(3.5),metal[2])
		draw_rect(rect.grow(2.5),metal[1])
		draw_line(rect.position + Vector2(-2.5,-2.5),Vector2(rect.end.x + 2.5,rect.position.y - 2.5),metal[0],1.0)
		draw_rect(rect,Color(0.06,0.03,0.02,0.95))
		# Damage trail, then the health itself with a highlight strip.
		var inner := rect.grow(-2.0)
		draw_rect(Rect2(inner.position,Vector2(inner.size.x * trail,inner.size.y)),Color(1.0,0.93,0.8,0.85))
		var fill_colour: Color = bar.colour.lerp(Color.WHITE,flash * 2.5)
		draw_rect(Rect2(inner.position,Vector2(inner.size.x * shown,inner.size.y)),fill_colour)
		draw_rect(Rect2(inner.position,Vector2(inner.size.x * shown,3.0)),fill_colour.lightened(0.35))
		draw_rect(Rect2(inner.position + Vector2(0,inner.size.y - 3.0),Vector2(inner.size.x * shown,3.0)),fill_colour.darkened(0.3))
		for mark in bar.notches:
			var x := inner.position.x + inner.size.x * float(mark)
			draw_line(Vector2(x,rect.position.y - 4.0),Vector2(x,rect.end.y + 4.0),metal[2],4.0)
			draw_line(Vector2(x,rect.position.y - 4.0),Vector2(x,rect.end.y + 4.0),metal[0],2.0)
		# Studs at the ends of the frame.
		for x in [rect.position.x - 1.0,rect.end.x + 1.0]:
			_gem(Vector2(x,rect.get_center().y),7.0,metal)
		# Small ornaments either side of the name.
		var half_name := minf(width * 0.45,float(bar.title.length()) * 5.6 + 22.0)
		var centre := left + width * 0.5
		for side in [-1.0,1.0]:
			var at := Vector2(centre + side * half_name,8.0)
			draw_line(at,at + Vector2(side * 46.0,0),metal[2],3.0)
			draw_line(at,at + Vector2(side * 46.0,0),metal[1],1.5)
			_gem(at,4.5,metal)
			_gem(at + Vector2(side * 50.0,0),3.0,metal)

	## A laurel branch curling round one end of the bar in a C, tied with a
	## ribbon at the bottom, leaves pointing along it toward a berry at the top.
	func _wreath(base: Vector2, side: float, metal: Array) -> void:
		var sway := sin(time * 1.6) * 0.06
		var centre := base + Vector2(side * 4.0,0)
		var stem := PackedVector2Array()
		for step in 13:
			var angle := deg_to_rad(78.0 + float(step) / 12.0 * 204.0)
			var offset := Vector2(cos(angle),sin(angle)) * 24.0
			if side > 0.0: offset.x = -offset.x
			stem.append(centre + offset)
		draw_polyline(stem,metal[2],3.4,true)
		draw_polyline(stem,metal[1],1.8,true)
		for index in range(1,stem.size()):
			var along := (stem[index] - stem[index - 1]).normalized()
			var size := 10.0 - float(index) * 0.35
			for flip in [-1.0,1.0]: _leaf(stem[index],along.rotated(flip * 0.85 + sway) * size,metal)
		var tip := stem[stem.size() - 1]
		draw_circle(tip,3.4,metal[2])
		draw_circle(tip,2.3,Color("#c0392b") if bar.gilded else Color("#6fa8dc"))
		# Ribbon tie where the branch starts.
		var ribbon := Color("#8e1f1f") if bar.gilded else Color("#2e4a6b")
		var tie := stem[0]
		draw_line(tie,tie + Vector2(-6.0 * side,12),ribbon.darkened(0.3),4.0)
		draw_line(tie,tie + Vector2(5.0 * side,11),ribbon,4.0)
		draw_circle(tie,4.5,ribbon.darkened(0.2)); draw_circle(tie,3.0,ribbon.lightened(0.15))

	func _leaf(at: Vector2, out: Vector2, metal: Array) -> void:
		var tip := at + out
		var side_vector := out.orthogonal().normalized() * 3.2
		var middle := at + out * 0.5
		var leaf := PackedVector2Array([at,middle + side_vector,tip,middle - side_vector])
		draw_colored_polygon(leaf,metal[1])
		draw_polyline(PackedVector2Array([at,middle + side_vector,tip,middle - side_vector,at]),metal[2],1.0)
		draw_line(at,middle + side_vector * 0.3,metal[0],1.0)

	func _gem(at: Vector2, radius: float, metal: Array) -> void:
		var points := PackedVector2Array([at + Vector2(0,-radius),at + Vector2(radius,0),at + Vector2(0,radius),at + Vector2(-radius,0)])
		draw_colored_polygon(points,metal[2])
		var inner := PackedVector2Array()
		for p in points: inner.append(at + (p - at) * 0.7)
		draw_colored_polygon(inner,metal[1])
		draw_circle(at + Vector2(-radius * 0.2,-radius * 0.2),radius * 0.18,metal[0])
