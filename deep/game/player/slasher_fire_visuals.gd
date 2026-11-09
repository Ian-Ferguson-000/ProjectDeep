extends RefCounted

# Reuse the game's animated fire atlas rather than introducing a second art style.
const FLAME := preload("res://assets/effect_packs/fireball/fireball_flight.png")
const IMPACT := preload("res://assets/effect_packs/fireball/fireball_impact.png")
const GROUND := preload("res://assets/field/farmstead/fire_patch.png")

static func flame(canvas: Node2D, point: Vector2, scale_value: float, clock: float, phase: float = 0.0, opacity: float = 1.0) -> void:
	var frame := int(floor(fposmod(clock*18.0+phase,10.0)))
	canvas.draw_set_transform(point,-PI/2.0,Vector2.ONE*scale_value)
	canvas.draw_texture_rect_region(FLAME,Rect2(-24,-16,48,32),Rect2(frame*48,0,48,32),Color(1,1,1,opacity))
	canvas.draw_set_transform(Vector2.ZERO)

static func embers(canvas: Node2D, point: Vector2, radius: float, clock: float, count: int = 7, opacity: float = 1.0) -> void:
	for index in count:
		var rise := fposmod(clock*45.0+index*13.0,65.0)
		var offset := Vector2(sin(index*2.4+clock)*radius,-rise)
		canvas.draw_circle(point+offset,2.0,Color(1,0.65,0.15,opacity*(1.0-rise/65.0)))

static func explosion(canvas: Node2D, point: Vector2, radius: float, progress: float) -> void:
	var frame := mini(7,int(progress*8.0))
	canvas.draw_texture_rect_region(IMPACT,Rect2(point-Vector2.ONE*radius,Vector2.ONE*radius*2.0),Rect2(frame*48,0,48,32),Color(1,1,1,1.0-progress*0.5))
	canvas.draw_arc(point,radius*lerpf(0.25,1.0,progress),0,TAU,48,Color(1,0.8,0.35,1.0-progress),5.0)
	for index in 8:
		var direction := Vector2.RIGHT.rotated(index*TAU/8.0)
		canvas.draw_line(point+direction*radius*progress*0.5,point+direction*radius*progress,Color(1,0.45,0.08,1.0-progress),3.0)
