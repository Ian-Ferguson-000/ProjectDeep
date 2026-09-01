extends RefCounted
class_name SlasherGridPathfinder

var cells:Dictionary={}
var blocked:Dictionary={}
var origin:=Vector2.ZERO
var tile_size:=48.0
var path_cache:Dictionary={}

func configure(walkable_cells:Dictionary,solid_props:Array,world_origin:Vector2,cell_size:float)->SlasherGridPathfinder:
	cells=walkable_cells.duplicate();origin=world_origin;tile_size=cell_size;blocked.clear();path_cache.clear()
	for prop_value:Variant in solid_props:
		var prop:Dictionary=Dictionary(prop_value);blocked[Vector2i(prop.get("cell",Vector2i.ZERO))]=true
	return self

func set_cell_blocked(cell:Vector2i,value:bool)->void:
	if value:blocked[cell]=true
	else:blocked.erase(cell)
	path_cache.clear()

func next_waypoint(from_world:Vector2,to_world:Vector2)->Vector2:
	var start:=nearest_walkable_cell(world_to_cell(from_world));var goal:=nearest_walkable_cell(world_to_cell(to_world))
	if start==goal:return to_world
	if has_clear_line(start,goal):return to_world
	var path:=find_cell_path(start,goal)
	if path.size()<2:return from_world
	return cell_to_world(Vector2i(path[1]))

func find_cell_path(start:Vector2i,goal:Vector2i)->Array[Vector2i]:
	start=nearest_walkable_cell(start);goal=nearest_walkable_cell(goal)
	var cache_key:="%d,%d>%d,%d"%[start.x,start.y,goal.x,goal.y]
	if path_cache.has(cache_key):
		var cached_result:Array[Vector2i]=[]
		for cached_cell:Vector2i in path_cache[cache_key]:cached_result.append(cached_cell)
		return cached_result
	var open:Array[Vector2i]=[start];var came_from:Dictionary={};var costs:Dictionary={start:0}
	while not open.is_empty():
		var best_index:=0;var best_score:=INF
		for index:int in open.size():
			var candidate:=open[index];var score:=float(costs[candidate])+absi(goal.x-candidate.x)+absi(goal.y-candidate.y)
			if score<best_score:best_score=score;best_index=index
		var current:Vector2i=open.pop_at(best_index)
		if current==goal:
			var result:Array[Vector2i]=[current]
			while came_from.has(current):current=Vector2i(came_from[current]);result.push_front(current)
			path_cache[cache_key]=result.duplicate();return result
		for direction:Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var neighbor:=current+direction
			if not is_walkable_cell(neighbor):continue
			var next_cost:=int(costs[current])+1
			if not costs.has(neighbor) or next_cost<int(costs[neighbor]):
				costs[neighbor]=next_cost;came_from[neighbor]=current
				if neighbor not in open:open.append(neighbor)
	return []

func has_clear_line(start:Vector2i,goal:Vector2i)->bool:
	var delta:=Vector2(goal-start);var steps:=maxi(1,int(ceil(maxf(absf(delta.x),absf(delta.y))*4.0)))
	var previous:=start
	for index:int in range(steps+1):
		var sample:=Vector2(start).lerp(Vector2(goal),float(index)/steps);var cell:=Vector2i(roundi(sample.x),roundi(sample.y))
		if not is_walkable_cell(cell):return false
		if cell.x!=previous.x and cell.y!=previous.y and (not is_walkable_cell(Vector2i(previous.x,cell.y)) or not is_walkable_cell(Vector2i(cell.x,previous.y))):return false
		previous=cell
	return true

func nearest_walkable_cell(requested:Vector2i)->Vector2i:
	if is_walkable_cell(requested):return requested
	for radius:int in range(1,12):
		for y:int in range(-radius,radius+1):
			for x:int in range(-radius,radius+1):
				if absi(x)!=radius and absi(y)!=radius:continue
				var candidate:=requested+Vector2i(x,y)
				if is_walkable_cell(candidate):return candidate
	return requested

func is_walkable_cell(cell:Vector2i)->bool:return cells.has(cell) and not blocked.has(cell)
func world_to_cell(point:Vector2)->Vector2i:return Vector2i(floori((point.x-origin.x)/tile_size),floori((point.y-origin.y)/tile_size))
func cell_to_world(cell:Vector2i)->Vector2:return origin+Vector2(cell)*tile_size+Vector2.ONE*tile_size*0.5
