extends RefCounted

static func color_for(kind: String) -> Color:
	return {"ice":Color("#99e8ff"),"lightning":Color("#9bf8ff"),"gravity":Color("#b395ff"),"arcane":Color("#d8bdff")}.get(kind,Color("#d8bdff"))

static func sigil(canvas: Node2D, center: Vector2, radius: float, clock: float, tint: Color) -> void:
	canvas.draw_circle(center,radius,Color(tint,0.12))
	canvas.draw_arc(center,radius,0,TAU,48,Color(tint,0.8),2.0)
	for index in 6:
		var direction := Vector2.RIGHT.rotated(clock+index*TAU/6)
		canvas.draw_line(center+direction*(radius-7),center+direction*(radius+4),tint,3.0)

static func crystal(canvas: Node2D, center: Vector2, size_value: float, tint: Color) -> void:
	var points := PackedVector2Array([center+Vector2(0,-size_value*1.8),center+Vector2(size_value,0),center+Vector2(0,size_value*0.5),center+Vector2(-size_value,0)])
	canvas.draw_colored_polygon(points,Color(tint,0.7))
	points.append(points[0]);canvas.draw_polyline(points,tint,2.0)
	canvas.draw_line(center+Vector2(0,-size_value*1.5),center,tint.lightened(0.5),2.0)

static func lightning(canvas: Node2D, start: Vector2, end: Vector2, clock: float, tint: Color, opacity: float = 1.0) -> void:
	var points := PackedVector2Array([start])
	var side := (end-start).normalized().orthogonal()
	for index in range(1,9):points.append(start.lerp(end,index/9.0)+side*sin(index*4.7+floor(clock*35))*11.0)
	points.append(end)
	canvas.draw_polyline(points,Color(tint,opacity*0.25),11.0,true)
	canvas.draw_polyline(points,Color(tint,opacity),4.0,true)
	canvas.draw_polyline(points,Color(1,1,1,opacity),1.5,true)

static func burst(canvas: Node2D, center: Vector2, radius: float, progress: float, tint: Color, kind: String) -> void:
	canvas.draw_circle(center,radius*(0.2+progress*0.6),Color(tint,(1-progress)*0.22))
	canvas.draw_arc(center,radius*(0.2+progress*0.8),0,TAU,48,Color(tint,1-progress),4.0)
	for index in 10:
		var direction := Vector2.RIGHT.rotated(index*TAU/10)
		var point := center+direction*radius*progress
		if kind=="ice":crystal(canvas,point,8*(1-progress),Color(tint,1-progress))
		else:canvas.draw_line(point-direction*18*(1-progress),point,Color(tint,1-progress),3.0)

static func vortex(canvas: Node2D, center: Vector2, radius: float, clock: float, progress: float) -> void:
	var tint := color_for("gravity")
	canvas.draw_circle(center,radius,Color(0.16,0.06,0.24,0.7))
	for ring in 3:
		var line := PackedVector2Array()
		for index in 45:
			var angle := clock*4+ring*TAU/3+index*0.12
			var distance := radius*(1-float(index)/50)
			line.append(center+Vector2.RIGHT.rotated(angle)*distance)
		canvas.draw_polyline(line,Color(tint,0.6),2.5,true)
	canvas.draw_circle(center,13+sin(clock*12)*2,Color("#11071c"))
	canvas.draw_arc(center,radius,0,TAU*progress,48,tint,4)

static func mirror(canvas: Node2D, center: Vector2, clock: float, recorded: bool, direction: Vector2) -> void:
	var tint := Color("#f0d8ff")
	sigil(canvas,center,30,clock,tint)
	var points := PackedVector2Array([center+Vector2(0,-62),center+Vector2(22,-37),center+Vector2(18,-8),center+Vector2(-18,-8),center+Vector2(-22,-37),center+Vector2(0,-62)])
	canvas.draw_colored_polygon(points,Color(0.36,0.23,0.55,0.75))
	canvas.draw_polyline(points,tint,3,true)
	canvas.draw_line(center+Vector2(-12,-26),center+Vector2(10,-47),Color(1,1,1,0.7),3)
	if recorded:
		var start := center+Vector2(0,-25)
		var end := start+direction*100
		canvas.draw_line(start,end,tint,3)
		canvas.draw_line(end,end-direction.rotated(0.5)*14,tint,3)
		canvas.draw_line(end,end-direction.rotated(-0.5)*14,tint,3)

static func projectile(canvas: Node2D, point: Vector2, direction: Vector2, clock: float, kind: String) -> void:
	var tint := color_for(kind)
	if kind=="ice":
		canvas.draw_line(point-direction*24,point+direction*16,tint,5)
		crystal(canvas,point,9,tint)
	elif kind=="gravity":
		canvas.draw_circle(point,12,Color("#1b0a29"))
		canvas.draw_arc(point,17,0,TAU,24,tint,2)
		for index in 3:canvas.draw_circle(point+Vector2.RIGHT.rotated(clock*8+index*TAU/3)*17,4,tint)
	else:
		canvas.draw_line(point-direction*26,point+direction*12,tint,5)
		canvas.draw_line(point-direction*14,point+direction*12,Color.WHITE,2)
