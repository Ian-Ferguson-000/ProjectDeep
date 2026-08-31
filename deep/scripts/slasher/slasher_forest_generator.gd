extends RefCounted
class_name SlasherForestGenerator

# TUNING: These fallbacks mirror data/dungeons.json forest.slasher. Edit that data block for campaign and Endless pacing.
const DEFAULT_CYCLE_LENGTH:=8
const DEFAULT_ELITE_FLOOR:=5

static func generate(seed_value:int,floor_number:int)->Dictionary:
	var config:=GameBalance.get_slasher_balance("generation")
	var width:=int(config.get("width",44));var height:=int(config.get("height",28))
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	var dungeon_tuning:Dictionary=Dictionary(GameBalance.get_dungeon("forest").get("slasher",{}));var cycle_length:int=maxi(1,int(dungeon_tuning.get("cycle_length",DEFAULT_CYCLE_LENGTH)));var cycle_floor:int=((floor_number-1)%cycle_length)+1;var is_boss_floor:bool=cycle_floor==cycle_length;var is_elite_floor:bool=cycle_floor==int(dungeon_tuning.get("elite_floor_in_cycle",DEFAULT_ELITE_FLOOR))
	var cells:Dictionary={};var rooms:Array[Rect2i]=[]
	var room_count:=int(config.get("base_rooms",6))+mini(int(config.get("room_growth_cap",3)),maxi(0,floor_number-1)*int(config.get("room_growth_per_floor",1)))
	var corridor_width:=maxi(2,int(config.get("corridor_width",2)))
	for index in room_count:
		var size:=Vector2i(rng.randi_range(int(config.get("room_width_min",9)),int(config.get("room_width_max",14))),rng.randi_range(int(config.get("room_height_min",7)),int(config.get("room_height_max",11))))
		if (is_boss_floor or is_elite_floor) and index==room_count-1:size=Vector2i(int(config.get("room_width_max",14)),int(config.get("room_height_max",11)))
		var origin:=Vector2i(rng.randi_range(2,width-size.x-3),rng.randi_range(2,height-size.y-3))
		var room:=Rect2i(origin,size);rooms.append(room);_carve_rect(cells,room)
		if index>0:_carve_corridor(cells,rooms[index-1].get_center(),room.get_center(),index%2==0,corridor_width)
	var start:=rooms[0].get_center();var exit:=rooms[-1].get_center()
	var enemy_spawns:Array[Vector2i]=[]
	for index in range(1,rooms.size()):
		# TUNING: This cap prevents very deep Endless floors from spawning unbounded enemy counts; stats still scale with absolute depth.
		var room:Rect2i=rooms[index];var count:int=mini(int(config.get("enemy_count_per_room_cap",7)),1+int(floor_number/2.0)+(1 if index==rooms.size()-1 else 0))
		for spawn_index in count:
			var candidate:=Vector2i(rng.randi_range(room.position.x+2,room.end.x-3),rng.randi_range(room.position.y+2,room.end.y-3))
			if candidate!=exit and candidate not in enemy_spawns:enemy_spawns.append(candidate)
	var loot_spawns:Array[Vector2i]=[]
	for index in range(1,rooms.size(),2):loot_spawns.append(rooms[index].get_center()+Vector2i(1,0))
	var merchant:=rooms[int(rooms.size()/2.0)].get_center()
	var boss_spawn:=exit+Vector2i(-2,0) if is_boss_floor or is_elite_floor else Vector2i(-1,-1)
	if is_boss_floor or is_elite_floor:
		enemy_spawns.clear()
		enemy_spawns.append(boss_spawn)
	var reserved:=_reserved_cells([start,exit,merchant]+enemy_spawns+loot_spawns,int(config.get("spawn_clearance_cells",2)))
	var decorations:=_make_decorations(cells,reserved,rng,float(config.get("decoration_density",0.16)),float(config.get("edge_decoration_density",0.48)))
	var solid_props:=_make_solid_props(cells,reserved,start,exit,rng,float(config.get("solid_prop_density",0.025)))
	return {"width":width,"height":height,"cells":cells,"rooms":rooms,"start":start,"exit":exit,"enemy_spawns":enemy_spawns,"loot_spawns":loot_spawns,"merchant":merchant,"boss_spawn":boss_spawn,"is_boss_floor":is_boss_floor,"is_elite_floor":is_elite_floor,"cycle_floor":cycle_floor,"cycle_number":int((floor_number-1)/cycle_length)+1,"edges":classify_edges(cells),"decorations":decorations,"solid_props":solid_props}

static func classify_edges(cells:Dictionary)->Dictionary:
	var result:Dictionary={}
	for value:Variant in cells:
		var cell:Vector2i=value;var missing:Array[String]=[]
		if not cells.has(cell+Vector2i.UP):missing.append("up")
		if not cells.has(cell+Vector2i.RIGHT):missing.append("right")
		if not cells.has(cell+Vector2i.DOWN):missing.append("down")
		if not cells.has(cell+Vector2i.LEFT):missing.append("left")
		if missing.is_empty():continue
		var kind:="straight" if missing.size()==1 else ("outer_corner" if missing.size()==2 else "tip")
		result[cell]={"kind":kind,"missing":missing}
	return result

static func layout_is_connected(layout:Dictionary)->bool:
	return _connected_avoiding(layout.get("cells",{}),layout.get("start",Vector2i.ZERO),layout.get("exit",Vector2i.ZERO),{})

static func _connected_avoiding(cells:Dictionary,start:Vector2i,target:Vector2i,blocked:Dictionary)->bool:
	var open:Array[Vector2i]=[]
	open.append(start)
	var seen:Dictionary={start:true}
	while not open.is_empty():
		var cell:Vector2i=open.pop_front()
		if cell==target:return true
		for direction_value:Variant in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var direction:Vector2i=Vector2i(direction_value)
			var neighbor:Vector2i=cell+direction
			if cells.has(neighbor) and not blocked.has(neighbor) and not seen.has(neighbor):seen[neighbor]=true;open.append(neighbor)
	return false

static func _carve_rect(cells:Dictionary,room:Rect2i)->void:
	for y in range(room.position.y,room.end.y):
		for x in range(room.position.x,room.end.x):cells[Vector2i(x,y)]=true

static func _carve_corridor(cells:Dictionary,from:Vector2i,to:Vector2i,horizontal_first:bool,width:int)->void:
	var cursor:Vector2i=from;var axes:Array[Vector2i]=[]
	var horizontal:Vector2i=Vector2i(signi(to.x-cursor.x),0);var vertical:Vector2i=Vector2i(0,signi(to.y-cursor.y))
	if horizontal_first:
		axes.append(horizontal);axes.append(vertical)
	else:
		axes.append(vertical);axes.append(horizontal)
	for axis_value:Variant in axes:
		var axis:Vector2i=Vector2i(axis_value)
		while (axis.x!=0 and cursor.x!=to.x) or (axis.y!=0 and cursor.y!=to.y):
			_carve_corridor_slice(cells,cursor,axis,width);cursor+=axis
	var final_axis:Vector2i=axes[axes.size()-1]
	_carve_corridor_slice(cells,to,final_axis,width)

static func _carve_corridor_slice(cells:Dictionary,center:Vector2i,axis:Vector2i,width:int)->void:
	var perpendicular:=Vector2i(0,1) if axis.x!=0 else Vector2i(1,0)
	for offset in range(-int(width/2),int(ceil(width/2.0))):cells[center+perpendicular*offset]=true

static func _reserved_cells(points:Array,clearance:int)->Dictionary:
	var result:Dictionary={}
	for point_value:Variant in points:
		var point:Vector2i=point_value
		for y in range(-clearance,clearance+1):
			for x in range(-clearance,clearance+1):result[point+Vector2i(x,y)]=true
	return result

static func _make_decorations(cells:Dictionary,reserved:Dictionary,rng:RandomNumberGenerator,floor_density:float,edge_density:float)->Array[Dictionary]:
	var result:Array[Dictionary]=[];var floor_kinds:=["grass_tuft_a","grass_tuft_b","grass_tuft_c","mossy_rock"];var edge_kinds:=["low_bush_a","low_bush_b","rounded_bush","tree_small","tree_wide"]
	for value:Variant in cells:
		var cell:Vector2i=value
		if reserved.has(cell):continue
		var edge:bool=_is_edge(cells,cell);var chance:float=edge_density if edge else floor_density
		if rng.randf()>chance:continue
		var kinds:Array=edge_kinds if edge else floor_kinds
		result.append({"kind":String(kinds[rng.randi_range(0,kinds.size()-1)]),"cell":cell,"offset":Vector2(rng.randf_range(-8,8),rng.randf_range(-6,8)),"edge":edge})
	return result

static func _make_solid_props(cells:Dictionary,reserved:Dictionary,start:Vector2i,exit:Vector2i,rng:RandomNumberGenerator,density:float)->Array[Dictionary]:
	var result:Array[Dictionary]=[];var blocked:Dictionary={};var kinds:=["rock","barrel","tree_large","chest"]
	for value:Variant in cells:
		var cell:Vector2i=value
		if reserved.has(cell) or _is_edge(cells,cell) or rng.randf()>density:continue
		blocked[cell]=true
		if not _connected_avoiding(cells,start,exit,blocked):blocked.erase(cell);continue
		result.append({"kind":String(kinds[rng.randi_range(0,kinds.size()-1)]),"cell":cell})
	return result

static func _is_edge(cells:Dictionary,cell:Vector2i)->bool:
	for direction in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
		if not cells.has(cell+direction):return true
	return false
