extends RefCounted
class_name SlasherWallRenderer

static func build_visuals(topology:Dictionary,profile_id:String,origin:Vector2,tile_size:int,show_deep_facades:bool=false)->Node2D:
	var root:=Node2D.new();root.name="TopologyWalls";var profile:=WallTilesetProfile.get_profile(profile_id);var source:=WallTilesetProfile.texture(profile)
	if source==null:return root
	var by_cell:=_group_edges(topology);var south_edges:Dictionary={};var inset_cells:Dictionary={};var visual_ids:Dictionary=Dictionary(topology.get("visual_edge_ids",{}));var inset_ids:Dictionary=Dictionary(topology.get("inset_edge_ids",{}));var restrict:=topology.has("visual_edge_ids")
	for edge_value in Array(topology.get("edges",[])):
		var edge:Dictionary=edge_value
		if restrict and not visual_ids.has(int(edge.id)):continue
		if inset_ids.has(int(edge.id)):inset_cells[Vector2i(edge.cell)]=true
		if Vector2i(edge.direction)==Vector2i.DOWN:south_edges[Vector2i(edge.cell)]=edge
	var ordered_cells:Array=by_cell.keys();ordered_cells.sort_custom(func(a:Vector2i,b:Vector2i):return a.y<b.y or (a.y==b.y and a.x<b.x))
	var walkable_cells:Dictionary=Dictionary(topology.get("walkable_cells",{}))
	for cell_value in ordered_cells:_render_boundary_cell(root,source,profile,Vector2i(cell_value),int(by_cell[cell_value]),by_cell,south_edges,walkable_cells,origin,tile_size,inset_cells.has(Vector2i(cell_value)))
	if not show_deep_facades:return root
	_render_facades(root,source,profile,south_edges,Dictionary(topology.get("walkable_cells",{})),inset_cells,origin,tile_size)
	return root

static func _group_edges(topology:Dictionary)->Dictionary:
	var by_cell:Dictionary={};var visual_ids:Dictionary=Dictionary(topology.get("visual_edge_ids",{}));var restrict:=topology.has("visual_edge_ids")
	for edge_value in Array(topology.get("edges",[])):
		var edge:Dictionary=edge_value;var cell:=Vector2i(edge.cell)
		if restrict and not visual_ids.has(int(edge.id)):continue
		by_cell[cell]=int(by_cell.get(cell,0))|_direction_bit(Vector2i(edge.direction))
	return by_cell

static func _direction_bit(direction:Vector2i)->int:
	return int({Vector2i.UP:1,Vector2i.RIGHT:2,Vector2i.DOWN:4,Vector2i.LEFT:8}.get(direction,0))

static func _render_boundary_cell(root:Node2D,source:Texture2D,profile:Dictionary,cell:Vector2i,mask:int,by_cell:Dictionary,south_edges:Dictionary,walkable_cells:Dictionary,origin:Vector2,tile_size:int,is_inset:bool=false)->void:
	var tile:=Node2D.new();tile.name="WallMask_%d_%d_%d"%[mask,cell.x,cell.y];tile.position=origin+(Vector2(cell)+Vector2(0.5,0.5))*tile_size;tile.set_meta("wall_mask",mask);tile.set_meta("unsupported_mask",false);tile.set_meta("inset_boundary",is_inset);root.add_child(tile)
	var placed:Dictionary={};var step:=float(tile_size)/float(_subtiles_per_cell(profile));var half:=step
	if (mask&1)!=0:
		for index in 3:
			var role:="north";var position:=Vector2((index-1)*step,-half);var map_x:=roundi(origin.x/step)+cell.x*3+index
			if index==0 and (mask&8)!=0:role="north_west"
			elif index==2 and (mask&2)!=0:role="north_east"
			_place_subtile(tile,source,profile,role,position,cell,map_x,placed,tile_size)
	if (mask&4)!=0:
		for index in 3:
			var role:="south";var position:=Vector2((index-1)*step,half+step);var map_x:=roundi(origin.x/step)+cell.x*3+index
			if index==0 and (mask&8)!=0:role="south_west"
			elif index==2 and (mask&2)!=0:role="south_east"
			var bend_index:=-1 if is_inset else _overhang_bend_index(cell,index,south_edges,walkable_cells)
			if bend_index>=0:role="right_bend_cap_%d"%bend_index
			_place_subtile(tile,source,profile,role,position,cell,map_x,placed,tile_size)
	if (mask&8)!=0:
		for index in 3:
			var role:="west";var position:=Vector2(-half,(index-1)*step);var map_y:=roundi(origin.y/step)+cell.y*3+index;var variant:=map_y+1
			if index==0 and (mask&1)!=0:role="north_west"
			elif index==0 and (int(by_cell.get(cell+Vector2i.UP,0))&8)==0:role="concave_west_top"
			elif (mask&1)!=0:variant=0
			_place_subtile(tile,source,profile,role,position,cell,variant,placed,tile_size)
		if (mask&4)==0 and (int(by_cell.get(cell+Vector2i.DOWN,0))&8)==0:_place_subtile(tile,source,profile,"concave_west_bottom",Vector2(-half,half+step),cell,0,placed,tile_size)
	if (mask&2)!=0:
		for index in 3:
			var role:="east";var position:=Vector2(half,(index-1)*step);var map_y:=roundi(origin.y/step)+cell.y*3+index;var variant:=map_y+1
			if index==0 and (mask&1)!=0:role="north_east"
			elif index==0 and (int(by_cell.get(cell+Vector2i.UP,0))&2)==0:role="concave_east_top"
			elif (mask&1)!=0:variant=0
			_place_subtile(tile,source,profile,role,position,cell,variant,placed,tile_size)
		if (mask&4)==0 and (int(by_cell.get(cell+Vector2i.DOWN,0))&2)==0:_place_subtile(tile,source,profile,"concave_east_bottom",Vector2(half,half+step),cell,0,placed,tile_size)
	tile.set_meta("wall_roles",placed.values())

static func _place_subtile(parent:Node2D,source:Texture2D,profile:Dictionary,role:String,position:Vector2,cell:Vector2i,variant:int,placed:Dictionary,tile_size:int)->void:
	var key:="%d:%d"%[roundi(position.x),roundi(position.y)]
	if placed.has(key):return
	var sprite:=_piece(source,profile,role,variant);sprite.name=role.to_pascal_case();sprite.scale=Vector2.ONE*_construction_scale(profile,tile_size);sprite.position=position;parent.add_child(sprite);placed[key]=role

static func _render_facades(root:Node2D,source:Texture2D,profile:Dictionary,south_edges:Dictionary,walkable_cells:Dictionary,inset_cells:Dictionary,origin:Vector2,tile_size:int)->void:
	# Full-cell deep masonry is optional reviewable decoration, never a substitute for the navigation edge tile.
	for cell_value in south_edges:
		var cell:=Vector2i(cell_value);var edge:Dictionary=south_edges[cell]
		var depth:=mini(int(edge.facade_depth),int(Dictionary(profile.get("spec",{})).get("facade_rows",3)))
		if depth<=0:continue
		var facade:=Node2D.new();facade.name="DeepFacade_%d_%d"%[cell.x,cell.y];facade.position=origin+(Vector2(cell)+Vector2(0.5,0.5))*tile_size;facade.set_meta("wall_role","deep_facade");facade.set_meta("facade_depth",depth);facade.set_meta("inset_boundary",inset_cells.has(cell))
		var run:=_south_run(cell,south_edges);var step:=float(tile_size)/float(_subtiles_per_cell(profile));var row_count:=mini(int(Dictionary(profile.get("spec",{})).get("facade_rows",3)),depth*_subtiles_per_cell(profile))
		for row in range(1,row_count+1):
			for sub_index in 3:
				var run_index:=int(run.before)*3+sub_index;var total:=int(run.length)*3;var suffix:=""
				# An inset facade terminates against its own vertical contour, so it
				# uses seamless center masonry across the complete face. Exterior
				# facades still own visible left/right edge and transition pieces.
				if not inset_cells.has(cell):
					if run_index==0:suffix="_left"
					elif run_index==1:suffix="_after_left"
					elif run_index==total-2:suffix="_before_right"
					elif run_index==total-1:suffix="_right"
				var role:="facade_%d%s"%[row,suffix];var bend_index:=-1 if inset_cells.has(cell) else _overhang_bend_index(cell,sub_index,south_edges,walkable_cells)
				if bend_index>=0:role="right_bend_%d_%d"%[row,bend_index]
				var piece:=_piece(source,profile,role,run_index);piece.name=role.to_pascal_case();piece.scale=Vector2.ONE*_construction_scale(profile,tile_size);piece.position=Vector2((sub_index-1)*step,step*(2+row));facade.add_child(piece)
		facade.z_index=3;root.add_child(facade)

static func _south_run(cell:Vector2i,south_edges:Dictionary)->Dictionary:
	var before:=0;var cursor:=cell+Vector2i.LEFT
	while south_edges.has(cursor):before+=1;cursor+=Vector2i.LEFT
	var after:=0;cursor=cell+Vector2i.RIGHT
	while south_edges.has(cursor):after+=1;cursor+=Vector2i.RIGHT
	return {"before":before,"length":before+1+after}

static func _overhang_bend_index(cell:Vector2i,sub_index:int,south_source:Dictionary,walkable_cells:Dictionary)->int:
	# The atlas provides one four-subtile join. Mirror its ownership through
	# topology: a stem on the left consumes the run's first four subtiles; a
	# stem on the right consumes its last four. Short runs keep their ordinary
	# left/right end corners instead of allowing the join to overwrite one.
	var before:=0;var cursor:=cell+Vector2i.LEFT
	while south_source.has(cursor):before+=1;cursor+=Vector2i.LEFT
	var after:=0;cursor=cell+Vector2i.RIGHT
	while south_source.has(cursor):after+=1;cursor+=Vector2i.RIGHT
	var run_start:=cell-Vector2i.RIGHT*before
	var run_end:=cell+Vector2i.RIGHT*after
	var total:=(before+1+after)*3
	if total<4:return -1
	var index:=before*3+sub_index
	if walkable_cells.has(run_start+Vector2i.LEFT+Vector2i.DOWN) and index<4:return index
	if walkable_cells.has(run_end+Vector2i.RIGHT+Vector2i.DOWN) and index>=total-4:return index-(total-4)
	return -1

static func mask_report(topology:Dictionary,profile_id:String)->Dictionary:
	var profile:=WallTilesetProfile.get_profile(profile_id);var cells:=_group_edges(topology);var counts:Dictionary={};var unsupported:Array[Dictionary]=[];var composites:Array[Dictionary]=[]
	for cell_value in cells:
		var mask:=int(cells[cell_value]);counts[mask]=int(counts.get(mask,0))+1
		var roles:=WallTilesetProfile.roles_for_mask(profile,mask)
		if roles.is_empty():unsupported.append({"cell":Vector2i(cell_value),"mask":mask})
		elif mask not in [1,2,3,4,6,8,9,12]:composites.append({"cell":Vector2i(cell_value),"mask":mask,"roles":roles})
	return {"mask_counts":counts,"unsupported_masks":unsupported,"composite_masks":composites}

static func build_collisions(topology:Dictionary,origin:Vector2,tile_size:int)->Node2D:
	var root:=Node2D.new();root.name="TopologyWallCollisions"
	for run_value in Array(topology.get("collision_runs",[])):
		var run:Dictionary=run_value;var body:=StaticBody2D.new();var collision:=CollisionShape2D.new();var shape:=RectangleShape2D.new();var from_value:=float(run.from);var to_value:=float(run.to);var fixed:=float(run.fixed);var length:=(to_value-from_value)*tile_size
		if bool(run.horizontal):shape.size=Vector2(length,8);body.position=origin+Vector2((from_value+to_value)*0.5,fixed)*tile_size
		else:shape.size=Vector2(8,length);body.position=origin+Vector2(fixed,(from_value+to_value)*0.5)*tile_size
		collision.shape=shape;body.add_child(collision);root.add_child(body)
	return root

static func build_debug_overlay(topology:Dictionary,origin:Vector2,tile_size:int)->Node2D:
	var overlay:=WallDebugOverlay.new();overlay.name="WallTopologyDebug";overlay.topology=topology;overlay.origin=origin;overlay.tile_size=tile_size;return overlay

static func _add_piece(parent:Node2D,source:Texture2D,profile:Dictionary,role:String,variant:int,tile_size:int)->void:
	var sprite:=_piece(source,profile,role,variant);sprite.name=role.to_pascal_case();sprite.scale=Vector2.ONE*float(tile_size)/_source_tile_size(profile);parent.add_child(sprite)

static func _piece(source:Texture2D,profile:Dictionary,role:String,variant:int)->Sprite2D:
	var sprite:=Sprite2D.new();sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;var regions:=WallTilesetProfile.regions(profile,role)
	if regions.is_empty():return sprite
	var atlas:=AtlasTexture.new();atlas.atlas=source;atlas.region=regions[absi(variant)%regions.size()];sprite.texture=atlas;return sprite

static func _source_tile_size(profile:Dictionary)->float:return float(Dictionary(profile.get("spec",{})).get("logical_tile_size",16))
static func _subtiles_per_cell(profile:Dictionary)->int:return int(Dictionary(profile.get("spec",{})).get("subtiles_per_cell",3))
static func _construction_scale(profile:Dictionary,tile_size:int)->float:return float(tile_size)/(_source_tile_size(profile)*float(_subtiles_per_cell(profile)))

static func _variant(cell:Vector2i,role:String)->int:return absi(cell.x*73856093^cell.y*19349663^role.hash())

class WallDebugOverlay extends Node2D:
	var topology:Dictionary={};var origin:=Vector2.ZERO;var tile_size:=48
	func _ready()->void:queue_redraw()
	func _draw()->void:
		var masks:=SlasherWallRenderer._group_edges(topology)
		for cell_value in masks:
			var cell:=Vector2i(cell_value);var center:=origin+(Vector2(cell)+Vector2(0.5,0.5))*tile_size;draw_string(ThemeDB.fallback_font,center-Vector2(7,-4),str(int(masks[cell])),HORIZONTAL_ALIGNMENT_CENTER,14,12,Color("ffd36a"))
		for edge_value in Array(topology.get("edges",[])):
			var edge:Dictionary=edge_value;var a:=origin+Vector2(edge.start)*tile_size;var b:=origin+Vector2(edge.end)*tile_size;draw_line(a,b,Color("56d9ff"),2.0);var middle:=(a+b)*0.5;draw_string(ThemeDB.fallback_font,middle,String(edge.orientation).left(1)+str(edge.facade_depth),HORIZONTAL_ALIGNMENT_LEFT,30,10,Color.WHITE)
		for vertex_value in Array(topology.get("vertices",[])):
			var vertex:Dictionary=vertex_value;var color:Color=Color({"convex":Color.GREEN,"concave":Color.ORANGE,"saddle":Color.MAGENTA,"end":Color.RED}.get(String(vertex.kind),Color.GRAY));draw_circle(origin+Vector2(vertex.position)*tile_size,4,color)
