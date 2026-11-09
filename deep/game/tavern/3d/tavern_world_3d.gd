extends Node3D

const ROOM := preload("res://assets/tavern3d/hearth_room.glb")
const RESIDENT := preload("res://game/tavern/3d/tavern_resident_3d.gd")
const WINGS := preload("res://game/tavern/3d/tavern_wings_3d.gd")
const SCALE := 64.0
const CENTER := Vector2(832,544)
var hub: Node
var region: NavigationRegion3D
var room: Node3D
var wings: Node3D
var keeper_body: CharacterBody3D
var residents: Dictionary = {}
var hotspots: Node3D
var camera: Camera3D
var yaw := 0.45
var elevation := 0.82
var zoom := 19.0
var cutaway := true
var dragging := false
var labels_visible := true
var navigation_ready := false
var pending_interaction: Node3D
var prompt_target: Node3D
var status: Label
var _rebuilding := false
var _rebuild_requested := false
var _focus := Vector3(0,0,0)

func to_room(point: Vector2) -> Vector3:
	return Vector3((point.x-CENTER.x)/SCALE,0.06,(point.y-CENTER.y)/SCALE)

func to_plan(point: Vector3) -> Vector2:
	return Vector2(point.x,point.z)*SCALE+CENTER

func _ready() -> void:
	get_viewport().msaa_3d=Viewport.MSAA_4X
	region=NavigationRegion3D.new()
	region.name="RoomNavigation"
	add_child(region)
	room=ROOM.instantiate()
	room.name="RoomModel"
	region.add_child(room)
	_build_collision(room)
	_batch_static_art(room)
	_build_lighting()
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.far=180
	add_child(camera)
	camera.make_current()
	hotspots=Node3D.new()
	hotspots.name="Interactions"
	add_child(hotspots)
	# Move the retained domain anchors onto the actual furniture in the new room.
	var table_points := {"TableWest":Vector2(-4.6,0.55),"TableEast":Vector2(4.55,0.55),"TableSouthWest":Vector2(-3.8,3.25)}
	for table_name in table_points:
		var table: Node2D=hub.world.get_node("Props/"+table_name)
		var point:Vector2=table_points[table_name]
		table.position=to_plan(Vector3(point.x,0,point.y))
		for marker in table.find_children("Seat*","Marker2D",false,false):
			marker.position.y=signf(marker.position.y)*64.0
	# Avoid the stairs and hearth at the original merchant spots.
	for record in [["Merchant_forest",Vector2(-6.5,-2.0)],["Merchant_crypt",Vector2(7.8,0.2)],["Merchant_tavern",Vector2(-1.1,-3.8)]]:
		hub.activity_anchors.get_node(record[0]).position=to_plan(Vector3(record[1].x,0,record[1].y))
	for actor in hub.activity_controller.actors.values():
		if actor.actor_kind=="merchant":
			var anchor:Node2D=hub.activity_anchors.find_child("Merchant_"+actor.actor_id,true,false)
			if anchor!=null:actor.position=anchor.position
	keeper_body=RESIDENT.new()
	keeper_body.name="Keeper3D"
	keeper_body.world=self
	keeper_body.source=hub.keeper
	keeper_body.is_keeper=true
	add_child(keeper_body)
	var ui:=CanvasLayer.new()
	ui.layer=1
	add_child(ui)
	status=Label.new()
	status.position=Vector2(18,76)
	status.add_theme_font_size_override("font_size",13)
	status.add_theme_color_override("font_outline_color",Color.BLACK)
	status.add_theme_constant_override("outline_size",5)
	status.text="WASD / arrows: move · Click: walk / interact · E: interact\nRight-drag: orbit · Wheel: zoom · C: walls · N: names · R: reset"
	status.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(status)
	rebuild_wings()
	_sync_residents()
	_update_camera(1.0)

func _build_collision(model: Node3D) -> void:
	var faces:=PackedVector3Array()
	for item in model.find_children("*","MeshInstance3D",true,false):
		var mesh:=item as MeshInstance3D
		# A smooth collision ramp under the visible treads makes the stair flight
		# traversable without catching capsules on every decorative nosing.
		if String(mesh.name).begins_with("Step") or String(mesh.name).begins_with("Tread"):continue
		# Fine props don't need individual rigid bodies; one static triangle soup.
		var local:Transform3D=model.global_transform.affine_inverse()*mesh.global_transform
		for vertex in mesh.mesh.get_faces():faces.append(local*vertex)
	var body:=StaticBody3D.new()
	body.name="RoomCollision"
	var shape:=CollisionShape3D.new()
	var geometry:=ConcavePolygonShape3D.new()
	geometry.set_faces(faces)
	shape.shape=geometry
	body.add_child(shape)
	model.add_child(body)
	var ramp:=StaticBody3D.new()
	ramp.name="StairRamp"
	ramp.position.x=6.5
	var ramp_shape:=CollisionShape3D.new()
	var convex:=ConvexPolygonShape3D.new()
	var vertices:=PackedVector3Array()
	for x in [-1.08,1.08]:
		vertices.append(Vector3(x,-0.1,-0.95))
		vertices.append(Vector3(x,-0.1,-5.2))
		vertices.append(Vector3(x,0.06,-0.95))
		vertices.append(Vector3(x,2.62,-5.2))
	convex.points=vertices
	ramp_shape.shape=convex
	ramp.add_child(ramp_shape)
	model.add_child(ramp)

func _batch_static_art(model: Node3D) -> void:
	# Keep editable Blender pieces in the source, but render each wall/fixture
	# group as one surface per shared material instead of hundreds of draw calls.
	for group in model.get_children():
		if not group is Node3D or group is StaticBody3D:continue
		var meshes:=group.find_children("*","MeshInstance3D",true,false)
		var surfaces:Dictionary={}
		for item in meshes:
			var mesh:=item as MeshInstance3D
			var transform:Transform3D=group.global_transform.affine_inverse()*mesh.global_transform
			for surface in mesh.mesh.get_surface_count():
				var material:=mesh.mesh.surface_get_material(surface)
				var key:=material.get_instance_id() if material!=null else 0
				if not surfaces.has(key):
					var tool:=SurfaceTool.new()
					tool.begin(Mesh.PRIMITIVE_TRIANGLES)
					tool.set_material(material)
					surfaces[key]=tool
				surfaces[key].append_from(mesh.mesh,surface,transform)
		if surfaces.is_empty():continue
		var combined:=ArrayMesh.new()
		for tool:SurfaceTool in surfaces.values():tool.commit(combined)
		var instance:=MeshInstance3D.new()
		instance.name="BatchedGeometry"
		instance.mesh=combined
		group.add_child(instance)
		for item in meshes:item.free()

func _build_lighting() -> void:
	var holder:=WorldEnvironment.new()
	var environment:=Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("20232a")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("b3c4d8")
	environment.ambient_light_energy=0.60
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled=true
	holder.environment=environment
	add_child(holder)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-55,-35,0)
	sun.light_energy=1.1
	sun.light_color=Color("ffe3ba")
	sun.shadow_enabled=true
	sun.light_angular_distance=3
	add_child(sun)
	for x in [-6.0,-1.1,3.3,8.2]:
		var light:=OmniLight3D.new()
		light.position=Vector3(x,2.45,-4.8)
		light.light_color=Color("ffb44d")
		light.light_energy=1.1
		light.omni_range=4.0
		add_child(light)
	var fire:=OmniLight3D.new()
	fire.position=Vector3(-7.6,1.1,-3.35)
	fire.light_color=Color("ff8a35")
	fire.light_energy=2
	fire.omni_range=5
	add_child(fire)

func rebuild_wings() -> void:
	if _rebuilding:
		_rebuild_requested=true
		return
	_rebuilding=true
	navigation_ready=false
	if is_instance_valid(wings):wings.free()
	for child in hotspots.get_children():child.free()
	pending_interaction=null
	prompt_target=null
	wings=WINGS.new()
	wings.name="CampaignWings"
	wings.world=self
	region.add_child(wings)
	wings.build(hub.expansions,hub.run_state.campaign)
	_build_interactions()
	call_deferred("_bake_navigation")

func _bake_navigation() -> void:
	var mesh:=NavigationMesh.new()
	mesh.geometry_parsed_geometry_type=NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask=1
	mesh.cell_size=0.15
	mesh.cell_height=0.10
	mesh.agent_radius=0.30
	mesh.agent_height=1.7
	mesh.agent_max_climb=0.30
	mesh.agent_max_slope=48
	mesh.region_min_size=1.0
	mesh.region_merge_size=2.0
	NavigationServer3D.map_set_cell_size(get_world_3d().navigation_map,mesh.cell_size)
	NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map,mesh.cell_height)
	region.navigation_mesh=mesh
	region.bake_navigation_mesh(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	while NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map)==0:
		await get_tree().physics_frame
	navigation_ready=true
	_rebuilding=false
	# Refresh paths after a tier/room change and settle off-mesh spawn anchors.
	for body in residents.values():
		if not is_instance_valid(body):continue
		body.target=Vector3.INF
		if is_instance_valid(body.source) and body.source.state!=TavernActor.ActivityState.SEATED:
			var closest:=NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map,body.position)
			if closest.distance_to(body.position)<3.0:body.position=closest+Vector3.UP*0.08
	if _rebuild_requested:
		_rebuild_requested=false
		call_deferred("rebuild_wings")

func add_hotspot(title: String, point: Vector3, source: Node = null, page: String = "") -> Area3D:
	var area:=Area3D.new()
	area.name=title.validate_node_name()
	area.position=point
	area.collision_layer=4
	area.collision_mask=0
	if source!=null:area.set_meta("interaction_source",source)
	area.set_meta("page",page)
	area.set_meta("title",title)
	var collision:=CollisionShape3D.new()
	var sphere:=SphereShape3D.new()
	sphere.radius=0.65
	collision.shape=sphere
	collision.position.y=0.75
	area.add_child(collision)
	hotspots.add_child(area)
	return area

func _build_interactions() -> void:
	var bar:=add_hotspot("The bar",Vector3(-1.1,0,-1.85),hub.world.get_node("Fixtures/BarFixture"))
	var bar_shape:=BoxShape3D.new()
	bar_shape.size=Vector3(4.95,1.5,1.4)
	bar.get_child(0).shape=bar_shape
	bar.get_child(0).position=Vector3(0,0.75,-0.7)
	add_hotspot("Expedition board",Vector3(-8.1,0,2.1),null,"Expeditions")
	add_hotspot("Armory",Vector3(7.9,0,3.0),null,"Armory")
	add_hotspot("Merchants",Vector3(7.9,0,1.8),null,"Merchants")
	add_hotspot("Upstairs lodgings",Vector3(6.5,0,-0.8),null,"Lodgings")
	add_hotspot("Upper landing",Vector3(6.5,2.55,-4.95),null,"Lodgings")
	add_hotspot("The road / expeditions",Vector3(0,0,5.4),null,"Expeditions")
	for prop in hub.expansions.find_children("*","TavernProp",true,false):
		if prop.interaction_enabled and prop.prop_enabled:
			add_hotspot(prop.display_name,to_room(prop.position),prop)

func simulation_paused() -> bool:
	return hub._modal_visible() or hub.tavern_tour!=null or hub.story_dialogue.is_playing() or hub.actor_dialogue.is_playing() or get_tree().paused

func input_allowed() -> bool:
	return navigation_ready and not simulation_paused() and not hub.arrivals_running and not hub.departure_running and hub.keeper.input_enabled and hub.keeper.possessed

func camera_direction(input: Vector2) -> Vector3:
	var right:=camera.global_basis.x
	var forward:=camera.global_basis.z
	right.y=0;forward.y=0
	return (right.normalized()*input.x+forward.normalized()*input.y).limit_length()

func screen_direction(direction: Vector3) -> Vector2:
	var right:=camera.global_basis.x
	var down:=camera.global_basis.z
	right.y=0;down.y=0
	return Vector2(direction.dot(right.normalized()),direction.dot(down.normalized()))

func _sync_residents() -> void:
	for id in residents.keys():
		if not is_instance_valid(residents[id]):
			residents.erase(id)
			continue
		var body:Node=residents[id]
		if not is_instance_valid(body.source) or hub.activity_controller.actors.get(id)!=body.source:
			body.queue_free()
			residents.erase(id)
	for id in hub.activity_controller.actors:
		if residents.has(id):continue
		var actor:TavernActor=hub.activity_controller.actors[id]
		var body:=RESIDENT.new()
		body.name="Resident_"+String(id).validate_node_name()
		body.world=self
		body.source=actor
		add_child(body)
		residents[id]=body

func _process(delta: float) -> void:
	if not is_instance_valid(keeper_body):return
	_sync_residents()
	_update_camera(delta)
	status.visible=not simulation_paused()
	if not input_allowed():
		pending_interaction=null
		keeper_body.walking=false
		dragging=false
		return
	prompt_target=nearest_interactable()
	hub._on_keeper_prompt("[E] "+_target_title(prompt_target) if prompt_target!=null else "")
	if is_instance_valid(pending_interaction) and _in_reach(pending_interaction):
		var target:=pending_interaction
		pending_interaction=null
		keeper_body.walking=false
		activate(target)

func _update_camera(delta: float) -> void:
	var desired:=keeper_body.position
	# Keep the hall comfortably framed; follow continuously into either wing.
	desired.x=desired.x*0.45 if absf(desired.x)<8.0 else desired.x-signf(desired.x)*3.6
	desired.z*=0.45
	desired.y=0.8
	_focus=_focus.lerp(desired,1.0-exp(-5.0*delta))
	camera.position=_focus+Vector3(sin(yaw)*cos(elevation),sin(elevation),cos(yaw)*cos(elevation))*34
	camera.look_at(_focus)
	camera.size=zoom*maxf(1.0,1.55/get_viewport().get_visible_rect().size.aspect())
	for group_name in ["FrontWall","RearWall","EastWall","WestWall","CeilingBeams"]:
		var group:=room.find_child(group_name,true,false) as Node3D
		if group==null:continue
		var near_wall:bool=(group_name=="FrontWall" and cos(yaw)>0) or (group_name=="RearWall" and cos(yaw)<0) or (group_name=="EastWall" and sin(yaw)>0) or (group_name=="WestWall" and sin(yaw)<0) or group_name=="CeilingBeams"
		group.visible=not cutaway or not near_wall

func _target_title(target: Node3D) -> String:
	if target==null:return ""
	var source:Node=null
	if target.has_meta("interaction_source") and is_instance_valid(target.get_meta("interaction_source")):source=target.get_meta("interaction_source")
	if source is TavernActor:return "Speak with "+source.display_name
	return String(target.get_meta("title","Inspect"))

func _in_reach(target: Node3D) -> bool:
	if not is_instance_valid(target):return false
	return keeper_body.position.distance_to(target.global_position)<2.0 and _line_clear(target)

func _line_clear(target: Node3D) -> bool:
	var start:=keeper_body.global_position+Vector3.UP*1.35
	var end:=target.global_position+Vector3.UP*1.35
	var ray:=PhysicsRayQueryParameters3D.create(start,end,1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func nearest_interactable() -> Node3D:
	var best:Node3D=null
	var distance:=2.0
	var candidates:Array=hotspots.get_children()+residents.values()
	for candidate in candidates:
		if not is_instance_valid(candidate):continue
		var target:=candidate as Node3D
		if not target.visible:continue
		var gap:=keeper_body.position.distance_to(target.global_position)
		if gap<distance and _line_clear(target):best=target;distance=gap
	return best

func activate(target: Node3D) -> void:
	if not input_allowed() or not _in_reach(target):return
	var source:Node=null
	if target.has_meta("interaction_source") and is_instance_valid(target.get_meta("interaction_source")):source=target.get_meta("interaction_source")
	var page:String=target.get_meta("page","")
	if not page.is_empty():
		if not hub._open_hearth(page):hub._show_dialogue("The Hearth","Finish the keeper's introduction to open "+page+".")
	elif is_instance_valid(source):hub._on_keeper_interaction(source)

func _unhandled_input(event: InputEvent) -> void:
	if not input_allowed():return
	if InputMap.has_action("interact") and event.is_action_pressed("interact"):
		activate(nearest_interactable())
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E:
				activate(nearest_interactable())
				get_viewport().set_input_as_handled()
			KEY_C:cutaway=not cutaway
			KEY_N:labels_visible=not labels_visible
			KEY_R:yaw=0.45;elevation=0.82;zoom=19
	elif event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT:dragging=event.pressed
		if not event.pressed:return
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:zoom=maxf(10,zoom-1)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:zoom=minf(32,zoom+1)
		elif event.button_index==MOUSE_BUTTON_LEFT:
			var origin:=camera.project_ray_origin(event.position)
			var query:=PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(event.position)*180,7)
			query.collide_with_areas=true
			query.exclude=[keeper_body.get_rid()]
			var hit:=get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty():return
			var collider:Node=hit.collider
			pending_interaction=collider as Node3D if (collider.has_meta("interaction_source") or collider.has_meta("page")) else null
			if is_instance_valid(pending_interaction):
				if _in_reach(pending_interaction):activate(pending_interaction);pending_interaction=null;return
				keeper_body.move_to(NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map,pending_interaction.global_position))
			else:keeper_body.move_to(NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map,hit.position))
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging:
		yaw-=event.relative.x*0.005
		elevation=clampf(elevation+event.relative.y*0.005,0.4,1.25)
