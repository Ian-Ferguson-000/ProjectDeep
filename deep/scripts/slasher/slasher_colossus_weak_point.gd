extends Node2D
class_name SlasherColossusWeakPoint

## A part of a colossus boss you can hurt: its heart, or a fist that has just
## slammed down. Hits only land while it is open (glowing); otherwise they
## glance off. Damage goes to the colossus's shared health.

var colossus: SlasherEnemy
var kind := "heart"
var open := false
var open_time := 0.0
var open_total := 0.0
var flash := 0.0
var texture: Texture2D
var radius := 30.0
# Fields other systems look for on things in the enemy group.
var boss := false
var elite := false
var mini_boss := false
var behavior_id := "colossus_weak_point"
var visual_id := "colossus_weak_point"
var movement_slow := 1.0
var status_time := 0.0

var dead: bool:
	get: return not is_instance_valid(colossus) or colossus.dead

func setup(owner_colossus: SlasherEnemy, part: String, part_radius: float, art: Texture2D = null) -> SlasherColossusWeakPoint:
	colossus = owner_colossus; kind = part; radius = part_radius; texture = art
	name = "WeakPoint_" + part
	return self

func _ready() -> void:
	add_to_group("slasher_enemy"); add_to_group("slasher_damageable")
	z_index = 5

func open_for(seconds: float) -> void:
	open = true; open_time = seconds; open_total = seconds
	queue_redraw()

func close() -> void:
	open = false; open_time = 0.0
	queue_redraw()

func receive_attack(attack: Dictionary, attacker: SlasherPlayer = null) -> int:
	if dead: return 0
	if not open:
		flash = 0.15
		AudioCue.play_from(self,"block")
		queue_redraw()
		return 0
	flash = 0.12
	return colossus.receive_attack(attack,attacker)

func receive_hit(amount: int, knockback: Vector2 = Vector2.ZERO, attacker: SlasherPlayer = null, stun: float = -1.0, shake: float = 1.0, sound: String = "impact") -> int:
	if dead or not open: return 0
	return colossus.receive_hit(amount,Vector2.ZERO,attacker,stun,shake,sound)

func _process(delta: float) -> void:
	flash = maxf(0.0,flash - delta)
	if open:
		open_time -= delta
		if open_time <= 0.0: close()
	queue_redraw()

func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if texture != null:
		draw_texture(texture,-texture.get_size() * 0.5,Color(1,1,1) if open else Color(0.55,0.5,0.5))
	elif kind == "heart": _draw_heart(t)
	else: _draw_fist(t)
	if open:
		# The window: a bright ring that shrinks as time runs out.
		var left := clampf(open_time / maxf(0.01,open_total),0.0,1.0)
		draw_arc(Vector2.ZERO,radius + 10.0,-PI * 0.5,-PI * 0.5 + TAU * left,40,Color(1.0,0.85,0.3,0.95),4.0)
		var bob := sin(t * 8.0) * 3.0
		_draw_bang(Vector2(0,-radius - 26 + bob))
	if flash > 0.0: draw_circle(Vector2.ZERO,radius,Color(1,1,1,flash * 3.0) if open else Color(0.6,0.6,0.7,flash * 3.0))

func _draw_heart(t: float) -> void:
	if open:
		var pulse := 1.0 + sin(t * 9.0) * 0.12
		draw_circle(Vector2.ZERO,radius * 1.35 * pulse,Color(1.0,0.45,0.12,0.25))
		draw_circle(Vector2.ZERO,radius * pulse,Color(1.0,0.55,0.15))
		draw_circle(Vector2.ZERO,radius * 0.55 * pulse,Color(1.0,0.92,0.6))
	else:
		# Closed: a dark seam in the bark.
		draw_colored_polygon(PackedVector2Array([Vector2(0,-radius),Vector2(radius * 0.35,0),Vector2(0,radius),Vector2(-radius * 0.35,0)]),Color(0.12,0.07,0.04))
		draw_line(Vector2(0,-radius),Vector2(0,radius),Color(0.55,0.25,0.1,0.6),2.0)

func _draw_fist(t: float) -> void:
	var bark := Color(0.42,0.28,0.17) if not open else Color(0.55,0.36,0.2)
	draw_circle(Vector2(0,6),radius * 1.1,Color(0,0,0,0.3))
	draw_circle(Vector2.ZERO,radius,bark.darkened(0.3))
	draw_circle(Vector2(0,-3),radius * 0.9,bark)
	for i in 4:
		var x := -radius * 0.6 + i * radius * 0.4
		draw_circle(Vector2(x,-radius * 0.55),radius * 0.24,bark.lightened(0.12))
	draw_line(Vector2(-radius * 0.5,radius * 0.2),Vector2(radius * 0.4,radius * 0.35),bark.darkened(0.45),3.0)
	if open:
		# Moss glowing with exposed sap where the fist split on impact.
		draw_circle(Vector2(radius * 0.2,-radius * 0.05),radius * 0.3,Color(1.0,0.6,0.2,0.85 + sin(t * 10.0) * 0.15))

func _draw_bang(at: Vector2) -> void:
	draw_circle(at,11,Color(0,0,0,0.6))
	draw_circle(at,9,Color(1.0,0.85,0.3))
	draw_rect(Rect2(at + Vector2(-1.5,-6),Vector2(3,8)),Color(0.15,0.08,0.02))
	draw_circle(at + Vector2(0,5),1.6,Color(0.15,0.08,0.02))
