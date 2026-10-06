extends RefCounted
# Procedural weapon trails follow the original attack direction and reach.
# These strokes only render feedback; they never drive collision or damage.

static func glint(canvas: Node2D, point: Vector2, direction: Vector2, size: float, alpha: float) -> void:
	var side := direction.orthogonal()
	canvas.draw_colored_polygon(PackedVector2Array([point-direction*size,point-side*size*0.22,point+direction*size,point+side*size*0.22]),Color(1,0.98,0.87,alpha))
	canvas.draw_line(point-side*size*0.65,point+side*size*0.65,Color(1,0.94,0.7,alpha*0.6),1,true)

static func slash(canvas: Node2D, origin: Vector2, direction: Vector2, reach: float, degrees: float, tint: Color, progress: float, reverse: bool, heavy: bool, chain: bool=false) -> void:
	var sweep := deg_to_rad(minf(degrees,360))
	var sign_value := -1.0 if reverse else 1.0
	# A visible opening stroke travels across the swing, then its tapered tail fades.
	var travel := lerpf(0.38,1.0,ease(clampf(progress/0.72,0,1),0.65))
	var head := direction.angle()+sign_value*(-sweep*0.5+sweep*travel)
	var tail := head-sign_value*sweep*minf(travel,0.72)
	var alpha := pow(1-progress,0.65)
	var thickness := minf(reach*0.23,38 if heavy else 24)
	for layer in 3:
		var points := PackedVector2Array()
		var edge := PackedVector2Array()
		var outer := reach-float(layer)*3
		for index in 33:
			var t := float(index)/32
			var angle := lerpf(tail,head,t)
			var radius := outer-5*(1-t)
			var point := origin+Vector2.from_angle(angle)*radius
			points.append(point);edge.append(point)
		for index in range(32,-1,-1):
			var t := float(index)/32
			var width := thickness*sin(t*PI)*pow(t,0.3)*(1-float(layer)*0.28)
			points.append(origin+Vector2.from_angle(lerpf(tail,head,t))*(outer-5*(1-t)-maxf(0.3,width)))
		var color := tint.lerp(Color.WHITE,float(layer)*0.28)
		canvas.draw_colored_polygon(points,Color(color,alpha*(0.25+float(layer)*0.16)))
		if layer==0:canvas.draw_polyline(edge,Color(1,0.96,0.83,alpha*0.92),2.5,true)
	# Short inner wisps follow the cutting edge, rather than outlining a pie sector.
	for index in 3:
		var radius := reach-thickness-8-index*7
		var start := head-sign_value*sweep*(0.17+index*0.05)
		canvas.draw_arc(origin,maxf(4,radius),minf(start,head),maxf(start,head),16,Color(tint,alpha*0.25),1.5,true)
	var blade_direction := Vector2.from_angle(head)
	var tip := origin+blade_direction*reach
	if chain:
		chain_links(canvas,origin,tip,alpha)
		weight(canvas,tip,alpha)
		return
	canvas.draw_line(origin+blade_direction*maxf(14,reach*0.5),tip,Color(tint,alpha*0.45),5,true)
	canvas.draw_line(origin+blade_direction*reach*0.74,tip,Color(1,0.98,0.9,alpha),2,true)
	glint(canvas,tip-blade_direction*6,blade_direction.orthogonal(),12 if heavy else 8,alpha)

static func thrust(canvas: Node2D, origin: Vector2, direction: Vector2, reach: float, width: float, tint: Color, progress: float, spear: bool, chain: bool) -> void:
	var alpha := pow(1-progress,0.65)
	var advance := lerpf(0.6,1.0,clampf(progress/0.32,0,1))
	var tip := origin+direction*reach*advance
	var side := direction.orthogonal()
	var head_size := minf(26,reach*0.22)
	for index in 3:
		var offset := side*(index-1)*minf(width*0.55,14)
		var end := tip+offset-direction*(index*9+head_size)
		canvas.draw_colored_polygon(PackedVector2Array([origin+offset,end+side*3,end-direction*20-side*3]),Color(tint,alpha*0.2))
		canvas.draw_line(origin+direction*reach*0.18+offset,end,Color(tint,alpha*0.25),2,true)
	if chain:
		chain_links(canvas,origin,tip,alpha)
		weight(canvas,tip,alpha)
	else:
		canvas.draw_line(origin+direction*12,tip-direction*head_size,Color("#786348",alpha),5 if spear else 3,true)
		canvas.draw_line(origin+direction*reach*0.35,tip-direction*head_size,Color("#e5e9ed",alpha),2,true)
		var blade := PackedVector2Array([tip,tip-direction*head_size+side*7,tip-direction*head_size*0.82,tip-direction*head_size-side*7])
		canvas.draw_colored_polygon(blade,Color("#c6e5ef",alpha))
		canvas.draw_polyline(PackedVector2Array([blade[1],tip,blade[3]]),Color(1,1,0.93,alpha),2,true)
		glint(canvas,tip-direction*head_size*0.5,side,9,alpha)

static func chain_links(canvas: Node2D, start: Vector2, end: Vector2, alpha: float) -> void:
	var distance := start.distance_to(end)
	var count := maxi(1,int(distance/12))
	var direction := start.direction_to(end)
	var side := direction.orthogonal()
	for index in count:
		var point := start.lerp(end,(float(index)+0.5)/count)
		var points := PackedVector2Array()
		for vertex in 13:
			var angle := TAU*vertex/12
			points.append(point+direction*cos(angle)*7+side*sin(angle)*(3.5 if index%2==0 else 1.5))
		canvas.draw_polyline(points,Color("#625d59",alpha),3,true)
		canvas.draw_polyline(points,Color("#d9cfb6",alpha*0.8),1,true)

static func weight(canvas: Node2D, point: Vector2, alpha: float) -> void:
	canvas.draw_circle(point,11,Color("#565961",alpha))
	canvas.draw_arc(point,10,-2.8,-0.6,12,Color("#f1dec0",alpha),3,true)
	for index in 6:
		var radial := Vector2.from_angle(TAU*index/6)
		canvas.draw_colored_polygon(PackedVector2Array([point+radial*16,point+radial*8+radial.orthogonal()*3,point+radial*8-radial.orthogonal()*3]),Color("#b4afa8",alpha))

static func telegraph(canvas: Node2D, origin: Vector2, direction: Vector2, reach: float, degrees: float, line: bool, tint: Color, pulse: float) -> void:
	var alpha := 0.25+pulse*0.15
	if line:
		# Broken lane rails indicate an armed attack, rather than a constant sword beam.
		for sign_value in [-1,1]:
			var side: Vector2 = direction.orthogonal()*degrees*sign_value
			for index in 8:
				canvas.draw_line(origin+side+direction*reach*index/8,origin+side+direction*reach*(index+0.45)/8,Color(tint,alpha),1.5,true)
		glint(canvas,origin+direction*reach,direction,9,alpha+0.15)
	else:
		var angle := direction.angle();var half := deg_to_rad(degrees)*0.5
		canvas.draw_arc(origin,reach,angle-half,angle+half,32,Color(tint,alpha),1.5,true)
		glint(canvas,origin+direction*reach*0.6,direction,13,alpha+0.2)

