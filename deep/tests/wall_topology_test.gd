extends SceneTree

func _initialize()->void:call_deferred("_run")

func _run()->void:
	var failures:Array[String]=[]
	_expect(WallTilesetProfile.validate().is_empty(),"Wall tileset profile failed validation: %s"%", ".join(WallTilesetProfile.validate()),failures)
	var fixtures:Dictionary={
		"rectangle":_rect(Vector2i.ZERO,Vector2i(5,4)),
		"l_shape":_union(_rect(Vector2i.ZERO,Vector2i(5,2)),_rect(Vector2i.ZERO,Vector2i(2,5))),
		"u_shape":_union(_rect(Vector2i.ZERO,Vector2i(2,6)),_rect(Vector2i(5,0),Vector2i(2,6)),_rect(Vector2i.ZERO,Vector2i(7,2))),
		"one_cell_neck":_union(_rect(Vector2i.ZERO,Vector2i(3,3)),_rect(Vector2i(3,1),Vector2i(3,1)),_rect(Vector2i(6,0),Vector2i(3,3))),
		"diagonal":{Vector2i.ZERO:true,Vector2i.ONE:true},
		"hole":_with_hole(_rect(Vector2i.ZERO,Vector2i(7,7)),Rect2i(2,2,3,3)),
	}
	for fixture_name in fixtures:
		var cells:Dictionary=fixtures[fixture_name];var topology:=SlasherWallTopology.build(cells,[],2);var expected:=_exposed_edge_count(cells)
		_expect(topology.edges.size()==expected,"%s does not own every exposed edge exactly once"%fixture_name,failures)
		var used:Dictionary={}
		for contour_value in topology.contours:
			var contour:Array=contour_value
			_expect(not contour.is_empty(),"%s produced an empty contour"%fixture_name,failures)
			if not contour.is_empty():
				var first:Dictionary=topology.edges[contour[0]];var last:Dictionary=topology.edges[contour.back()];_expect(Vector2i(last.end)==Vector2i(first.start),"%s produced an open contour"%fixture_name,failures)
			for edge_id in contour:_expect(not used.has(edge_id),"%s repeats an edge across contours"%fixture_name,failures);used[edge_id]=true
		_expect(used.size()==expected,"%s contour tracing omitted boundary edges"%fixture_name,failures)
		var repeat:=SlasherWallTopology.build(cells,[],2);_expect(_signature(topology)==_signature(repeat),"%s topology is not deterministic"%fixture_name,failures)
	var diagonal:Dictionary=SlasherWallTopology.build(fixtures.diagonal,[],2);_expect(_has_vertex_kind(diagonal,"saddle") and diagonal.contours.size()==2,"Diagonal contact was not split into independent saddle contours",failures)
	var hole_topology:Dictionary=SlasherWallTopology.build(fixtures.hole,[],3);_expect(hole_topology.contours.size()==2,"Enclosed inset did not produce separate exterior and interior contours",failures);_expect(Dictionary(hole_topology.visual_edge_ids).size()==hole_topology.edges.size(),"Enclosed inset omitted its inward-facing wall artwork",failures)
	var hole_visuals:=SlasherWallRenderer.build_visuals(hole_topology,"stone_wall",Vector2.ZERO,48,true);_expect(not hole_visuals.find_children("DeepFacade_*","Node2D",true,false).is_empty(),"Enclosed inset did not render its north-facing interior facade",failures)
	for facade in hole_visuals.find_children("DeepFacade_*","Node2D",true,false):
		if not bool(facade.get_meta("inset_boundary",false)):continue
		for piece in facade.get_children():
			if piece is Sprite2D and (piece as Sprite2D).texture is AtlasTexture:
				var atlas_cell:=Vector2i(((piece as Sprite2D).texture as AtlasTexture).region.position/16.0);_expect(atlas_cell.x in [4,5],"Inset facade used a bordered left/right atlas piece",failures)
	var inset:Dictionary=SlasherWallTopology.build(fixtures.l_shape,[],2);_expect(_has_vertex_kind(inset,"convex") and _has_vertex_kind(inset,"concave"),"L fixture lacks convex or concave classification",failures)
	var parallel:Dictionary=_union(_rect(Vector2i(0,0),Vector2i(4,2)),_rect(Vector2i(0,3),Vector2i(4,2)));var parallel_topology:=SlasherWallTopology.build(parallel,[],2)
	for edge in parallel_topology.edges:
		if Vector2i(edge.cell).y in [1,3] and Vector2i(edge.direction).y!=0:_expect(int(edge.facade_depth)==0,"Nearby parallel walls received overlapping facades",failures)
	var base:=SlasherWallTopology.build(fixtures.rectangle,[],2);var removed:Dictionary=base.edges[0];var doorway:=SlasherWallTopology.build(fixtures.rectangle,[[removed.start,removed.end]],2);_expect(doorway.edges.size()==base.edges.size()-1 and _has_vertex_kind(doorway,"end"),"Doorway did not suppress one edge and create wall ends",failures)
	var visuals:=SlasherWallRenderer.build_visuals(base,"stone_wall",Vector2.ZERO,48);var collisions:=SlasherWallRenderer.build_collisions(base,Vector2.ZERO,48);_expect(visuals.get_child_count()>0,"Wall renderer produced no atlas pieces",failures);_expect(collisions.get_child_count()<base.edges.size(),"Collinear collision edges were not merged",failures)
	for wall_cell in visuals.get_children():
		_expect(wall_cell.get_child_count()>=3 and wall_cell.get_child_count()<=10,"Boundary cell did not use the 3x3 construction-tile composition",failures)
		_expect(wall_cell.has_meta("wall_mask") and int(wall_cell.get_meta("wall_mask"))>0,"Boundary cell lacks a topology mask",failures)
		for piece in wall_cell.get_children():
			if piece is Sprite2D and (piece as Sprite2D).texture!=null:_expect((piece as Sprite2D).texture.get_size()==Vector2(16,16),"Wall renderer is not using the authored 16px construction tiles",failures)
	var isolated:=SlasherWallTopology.build({Vector2i.ZERO:true},[],3);var isolated_report:=SlasherWallRenderer.mask_report(isolated,"stone_wall");_expect(int(isolated_report.mask_counts.get(15,0))==1,"Isolated cell did not produce four-edge mask 15",failures);_expect(isolated_report.unsupported_masks.is_empty(),"Declared construction compositions left unsupported masks",failures)
	var profile:=WallTilesetProfile.get_profile("stone_wall")
	for mask in range(1,16):_expect(not WallTilesetProfile.roles_for_mask(profile,mask).is_empty(),"Boundary mask %d cannot resolve to construction roles"%mask,failures)
	hole_visuals.free();visuals.free();collisions.free()
	if failures.is_empty():print("WALL_TOPOLOGY_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)

func _rect(origin:Vector2i,size:Vector2i)->Dictionary:
	var cells:Dictionary={};for y in range(origin.y,origin.y+size.y):
		for x in range(origin.x,origin.x+size.x):cells[Vector2i(x,y)]=true
	return cells
func _union(a:Dictionary,b:Dictionary,c:Dictionary={})->Dictionary:var result:=a.duplicate();result.merge(b);result.merge(c);return result
func _with_hole(cells:Dictionary,hole:Rect2i)->Dictionary:
	var result:=cells.duplicate()
	for y in range(hole.position.y,hole.end.y):
		for x in range(hole.position.x,hole.end.x):result.erase(Vector2i(x,y))
	return result
func _exposed_edge_count(cells:Dictionary)->int:
	var count:=0
	for cell in cells:
		for direction in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:count+=1 if not cells.has(Vector2i(cell)+direction) else 0
	return count
func _has_vertex_kind(topology:Dictionary,kind:String)->bool:
	for vertex in topology.vertices:
		if String(vertex.kind)==kind:return true
	return false
func _signature(topology:Dictionary)->String:return JSON.stringify(topology)
func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
