extends RefCounted
class_name SlasherWallTopology

const DIRECTIONS:Array[Vector2i]=[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]

static func build(cells:Dictionary,doorway_edges:Array=[],max_facade_depth:int=2)->Dictionary:
	var doors:Dictionary={}
	for value in doorway_edges:doors[_edge_key_from_value(value)]=true
	var edges:Array[Dictionary]=[]
	for value in cells:
		var cell:=Vector2i(value)
		for direction in DIRECTIONS:
			if cells.has(cell+direction):continue
			var points:=_directed_points(cell,direction);var key:=_canonical_edge_key(points[0],points[1])
			if doors.has(key):continue
			edges.append({"id":edges.size(),"start":points[0],"end":points[1],"cell":cell,"direction":direction,"orientation":_orientation(direction),"facade_depth":_facade_depth(cells,cell,direction,max_facade_depth),"variant":absi(cell.x*73856093^cell.y*19349663^direction.x*97^direction.y*193)})
	edges.sort_custom(_edge_less);for index in edges.size():edges[index].id=index
	var vertices:=_classify_vertices(cells,edges);var contours:=_trace_contours(edges)
	return {"edges":edges,"vertices":vertices,"contours":contours,"visual_edge_ids":_visual_edge_ids(edges,contours),"inset_edge_ids":_inset_edge_ids(edges,contours),"walkable_cells":cells.duplicate(),"collision_runs":_merge_collision_runs(edges),"doorway_edges":doors}

static func _visual_edge_ids(edges:Array[Dictionary],contours:Array[Array])->Dictionary:
	# Both exterior contours and enclosed voids are architectural boundaries.
	# Keeping every traced contour visible lets the renderer turn holes into
	# inward-facing pits/insets while collision continues to use the same edges.
	var result:Dictionary={}
	for contour in contours:
		if contour.is_empty():continue
		for edge_id_value in contour:result[int(edge_id_value)]=true
	return result

static func _inset_edge_ids(edges:Array[Dictionary],contours:Array[Array])->Dictionary:
	var result:Dictionary={}
	for contour in contours:
		if contour.is_empty():continue
		var twice_area:=0
		for edge_id_value in contour:
			var edge:Dictionary=edges[int(edge_id_value)];var a:=Vector2i(edge.start);var b:=Vector2i(edge.end);twice_area+=a.x*b.y-b.x*a.y
		if twice_area<0:
			for edge_id_value in contour:result[int(edge_id_value)]=true
	return result

static func _directed_points(cell:Vector2i,direction:Vector2i)->Array[Vector2i]:
	if direction==Vector2i.UP:return [cell,cell+Vector2i.RIGHT]
	if direction==Vector2i.RIGHT:return [cell+Vector2i.RIGHT,cell+Vector2i.ONE]
	if direction==Vector2i.DOWN:return [cell+Vector2i.ONE,cell+Vector2i.DOWN]
	return [cell+Vector2i.DOWN,cell]

static func _orientation(direction:Vector2i)->String:
	return {Vector2i.UP:"north",Vector2i.RIGHT:"east",Vector2i.DOWN:"south",Vector2i.LEFT:"west"}.get(direction,"north")

static func _facade_depth(cells:Dictionary,cell:Vector2i,direction:Vector2i,maximum:int)->int:
	# Opposing boundaries split the empty gap instead of painting full facades over one another.
	for distance in range(1,maximum*2+2):
		if cells.has(cell+direction*distance):return mini(maximum,int((distance-1)/2.0))
	return maximum

static func _classify_vertices(cells:Dictionary,edges:Array[Dictionary])->Array[Dictionary]:
	var incident:Dictionary={}
	for edge in edges:
		for point in [edge.start,edge.end]:
			if not incident.has(point):incident[point]=[]
			incident[point].append(edge.id)
	var result:Array[Dictionary]=[]
	for point_value in incident:
		var point:=Vector2i(point_value);var occupancy:Array[bool]=[cells.has(point+Vector2i(-1,-1)),cells.has(point+Vector2i(0,-1)),cells.has(point+Vector2i(-1,0)),cells.has(point)];var count:=0
		for present in occupancy:count+=1 if present else 0
		var edge_ids:Array=incident[point];var kind:="straight"
		if edge_ids.size()==1:kind="end"
		elif count==1:kind="convex"
		elif count==3:kind="concave"
		elif count==2 and occupancy[0]==occupancy[3]:kind="saddle"
		var orientations:Array[String]=[]
		if kind=="saddle":
			for quadrant_index in occupancy.size():
				if occupancy[quadrant_index]:orientations.append(_orientation_for_quadrant(quadrant_index))
		result.append({"position":point,"kind":kind,"occupancy":occupancy,"edge_ids":edge_ids.duplicate(),"orientation":_corner_orientation(occupancy,kind),"orientations":orientations})
	result.sort_custom(func(a:Dictionary,b:Dictionary):return a.position.y<b.position.y or (a.position.y==b.position.y and a.position.x<b.position.x))
	return result

static func _corner_orientation(occupied:Array[bool],kind:String)->String:
	var target:=true if kind=="convex" else false
	var index:=occupied.find(target)
	return _orientation_for_quadrant(index)

static func _orientation_for_quadrant(index:int)->String:
	# The base atlas crop has arms toward east and south (the occupied south-east quadrant).
	return ["r180","r270","r90","r0"][index] if index>=0 and index<4 else "r0"

static func _trace_contours(edges:Array[Dictionary])->Array[Array]:
	var starts:Dictionary={}
	for edge in edges:
		if not starts.has(edge.start):starts[edge.start]=[]
		starts[edge.start].append(edge.id)
	var unused:Dictionary={};for edge in edges:unused[edge.id]=true
	var contours:Array[Array]=[]
	while not unused.is_empty():
		var first:int=int(unused.keys()[0]);var contour:Array=[];var current:=first
		while unused.has(current):
			unused.erase(current);contour.append(current);var edge:Dictionary=edges[current];var candidates:Array=Array(starts.get(edge.end,[]));var next:=-1;var best:=99
			var incoming:=Vector2i(edge.end)-Vector2i(edge.start)
			for candidate_value in candidates:
				var candidate:=int(candidate_value)
				if not unused.has(candidate):continue
				var outgoing:=Vector2i(edges[candidate].end)-Vector2i(edges[candidate].start);var priority:=_turn_priority(incoming,outgoing)
				if priority<best:best=priority;next=candidate
			if next<0:break
			current=next
		contours.append(contour)
	return contours

static func _turn_priority(incoming:Vector2i,outgoing:Vector2i)->int:
	var right:=Vector2i(-incoming.y,incoming.x);var left:=Vector2i(incoming.y,-incoming.x)
	if outgoing==right:return 0
	if outgoing==incoming:return 1
	if outgoing==left:return 2
	return 3

static func _merge_collision_runs(edges:Array[Dictionary])->Array[Dictionary]:
	var groups:Dictionary={}
	for edge in edges:
		var a:=Vector2i(edge.start);var b:=Vector2i(edge.end);var horizontal:=a.y==b.y;var fixed:=a.y if horizontal else a.x;var key:="%s:%d"%["h" if horizontal else "v",fixed]
		if not groups.has(key):groups[key]=[]
		groups[key].append({"from":mini(a.x,b.x) if horizontal else mini(a.y,b.y),"to":maxi(a.x,b.x) if horizontal else maxi(a.y,b.y),"horizontal":horizontal,"fixed":fixed})
	var result:Array[Dictionary]=[]
	for key in groups:
		var pieces:Array=groups[key];pieces.sort_custom(func(a:Dictionary,b:Dictionary):return a.from<b.from);var run:Dictionary=pieces[0].duplicate()
		for index in range(1,pieces.size()):
			var piece:Dictionary=pieces[index]
			if int(piece.from)==int(run.to):run.to=piece.to
			else:result.append(run);run=piece.duplicate()
		result.append(run)
	return result

static func _edge_less(a:Dictionary,b:Dictionary)->bool:
	return a.start.y<b.start.y or (a.start.y==b.start.y and (a.start.x<b.start.x or (a.start.x==b.start.x and a.orientation<b.orientation)))

static func _canonical_edge_key(a:Vector2i,b:Vector2i)->String:
	if b.y<a.y or (b.y==a.y and b.x<a.x):var swap:=a;a=b;b=swap
	return "%d,%d:%d,%d"%[a.x,a.y,b.x,b.y]

static func _edge_key_from_value(value:Variant)->String:
	if value is Dictionary:return _canonical_edge_key(Vector2i(value.get("start",Vector2i.ZERO)),Vector2i(value.get("end",Vector2i.ZERO)))
	if value is Array and value.size()>=2:return _canonical_edge_key(Vector2i(value[0]),Vector2i(value[1]))
	return String(value)
