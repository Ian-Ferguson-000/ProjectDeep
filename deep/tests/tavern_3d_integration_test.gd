extends SceneTree
const TAVERN:=preload("res://scenes/tavern3d/Tavern3D.tscn")
var failures:Array[String]=[]

class MemoryCampaign extends CampaignState:
	func save_atomic() -> bool:return true

class ControllerStub extends Node:
	var starts:=0
	var party:Array[String]=[]
	func start_dungeon(_id:String,_gear:GearData,ids:Array[String],_patron:String="",_objective:String="") -> void:
		starts+=1
		party=ids.duplicate()

func _walk(body:CharacterBody3D,target:Vector3,npc:bool=false) -> bool:
	if npc:body.source.move_to(body.world.to_plan(target))
	else:body.move_to(target)
	for i in 1100:
		await physics_frame
		var flat:=body.position-target
		flat.y=0
		if flat.length()<0.6:return true
	print("WALK_FAILED: ",body.position," -> ",target," path end ",body.agent.get_final_position()," finished ",body.agent.is_navigation_finished())
	return false

func _initialize() -> void:call_deferred("_run")

func _expect(condition:bool,message:String) -> void:
	if not condition:failures.append(message);push_error(message)

func _run() -> void:
	root.size=Vector2i(1600,1000)
	var settings := root.get_node("GameSettings")
	var previous_dev: bool = settings.get_bool("dev_mode",false)
	settings.values["dev_mode"] = false
	var state:=RunState.new()
	state.campaign=MemoryCampaign.new()
	state.campaign.apply_post_tutorial_state("victory")
	state.campaign.last_presented_wave_id=state.campaign.candidate_wave_id
	state.campaign.first_normal_launch_completed=true
	state.campaign.tavern_phase=CampaignState.TAVERN_OPEN
	TavernTour.mark_done(state.campaign)
	state.set_class("warrior")
	var tavern:=TAVERN.instantiate()
	var controller:=ControllerStub.new()
	root.add_child(controller)
	tavern.setup(controller,state,[HearthCatalog.gear("sword_shield")] as Array[GearData],"")
	root.add_child(tavern)
	for i in 10:await physics_frame
	var w:Node3D=tavern.world_3d
	_expect(w.navigation_ready,"3D navigation never became ready")
	_expect(not tavern.world.visible,"Legacy art is still visible")
	_expect(w.region.navigation_mesh.get_polygon_count()>0,"Empty navigation bake")
	_expect(w.residents.size()==tavern.activity_controller.actors.size(),"Missing 3D residents")
	_expect(w.wings.find_child("LockedYardGate",true,false)!=null,"Tier zero gate is missing")
	_expect(w.keeper_body.position.y > -0.1,"Keeper fell through the floor")
	var map:RID=w.get_world_3d().navigation_map
	for target in [Vector3(-1.1,.1,-3.8),w.to_room(Vector2(tavern.expansions.lodging_floor.position.x+150,600))]:
		var path:=NavigationServer3D.map_get_path(map,w.keeper_body.position,target,true)
		_expect(path.size()>1 and path[-1].distance_to(target)<1.0,"No connected path to "+str(target))
	# Different frame padding must produce the same visible standing height.
	for body in [w.keeper_body] + w.residents.values():
		body._sync_visual()
		_expect(is_equal_approx(body.sprite.pixel_size * body._reference_bounds.size.y,1.65),"Character artwork has inconsistent height")
	_expect(is_equal_approx(w.keeper_body.KEEPER_SPEED,4.8),"Keeper traversal speed was not increased")
	# The actual collider catches a keeper walking into the counter.
	w.keeper_body.position=Vector3(-1.1,.1,-1.4)
	var hit:KinematicCollision3D=w.keeper_body.move_and_collide(Vector3(0,0,-2))
	_expect(hit!=null,"Bar counter has no physical collision")
	# Reachable fixture routes to the shared management page and freezes movement.
	w.keeper_body.position=Vector3(-1.1,.1,-1.0)
	var bar:Node3D=w.hotspots.find_child("The bar",false,false)
	var click:=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	click.position=w.camera.unproject_position(bar.global_position+Vector3(0,1.3,-0.7))
	w._unhandled_input(click)
	_expect(tavern.management.visible,"3D bar did not open Facilities")
	_expect(not w.input_allowed(),"Movement is allowed through a modal")
	tavern._close_top_modal()
	_expect(w.input_allowed(),"Closing the modal did not restore movement")
	state.campaign.establishment_tier=1
	tavern._hearth_changed()
	for i in 12:await physics_frame
	_expect(w.wings.find_child("LockedYardGate",true,false)==null,"Yard stayed locked after upgrading")
	var training:Vector3=w.to_room(Vector2(tavern.expansions.yard_floor.position.x+330,tavern.expansions.yard_floor.position.y+530))
	var yard_path:=NavigationServer3D.map_get_path(map,Vector3(0,.1,0),training,true)
	_expect(yard_path.size()>1 and yard_path[-1].distance_to(training)<1,"Yard is disconnected from the hall")
	# Both real movement controllers must traverse the doorway, not merely find a path.
	_expect(await _walk(w.keeper_body,training),"Keeper could not physically walk into the yard")
	var candidate_id:String=state.campaign.get_candidates()[0].id
	var npc:CharacterBody3D=w.residents[candidate_id]
	_expect(await _walk(npc,training+Vector3(1,0,0),true),"NPC could not physically walk into the yard")
	# Stairs have usable risers and a real upper landing.
	_expect(await _walk(w.keeper_body,Vector3(6.5,2.65,-4.95)),"Keeper could not climb the stairs")
	_expect(w.keeper_body.position.y>2.0,"Keeper reached stairs in plan only, not in height")
	# Merchant and candidate interactions still use the existing campaign UI.
	tavern._on_living_actor_interaction("merchant","tavern")
	_expect(tavern.merchant_shop_panel.visible,"Merchant shop did not open")
	tavern._close_top_modal()
	tavern._on_living_actor_interaction("candidate",candidate_id)
	_expect(tavern.actor_dialogue.is_playing(),"Candidate dialogue did not open")
	tavern.actor_dialogue._finish()
	_expect(tavern.recruitment_dialogue.visible,"Candidate dialogue did not lead to recruitment")
	tavern._close_top_modal()
	# Rebuild all wings at maximum tier, including rooms and equipment.
	state.campaign.establishment_tier=3
	state.campaign.banked_gold=100000
	for i in mini(4,state.campaign.rooms.size()):
		state.campaign.rooms[i]["quality"]=["cot","bunk","chamber","suite"][i]
	state.campaign.rooms[3]["furnishings"]=["crystal_ball","war_table"]
	tavern._hearth_changed()
	for i in 12:await physics_frame
	_expect(w.wings.find_child("ArcheryTarget",true,false)!=null,"Missing upgraded archery range")
	_expect(w.wings.find_child("TrainingWeights",true,false)!=null,"Missing upgraded weights")
	_expect(w.residents.size()==tavern.activity_controller.actors.size(),"Population refresh left stale proxies")
	_expect(w.wings.find_child("UpperBunk",true,false)!=null,"Bunk upgrade did not appear")
	_expect(w.wings.find_child("Furnishing_crystal_ball",true,false)!=null,"Room furnishing did not appear")
	var lodging_target:Vector3=w.to_room(Vector2(80,600))
	_expect(await _walk(w.keeper_body,lodging_target),"Keeper could not physically enter the lodgings")
	# Pause stops the same physics world; closing resumes input.
	tavern.pause_menu.open()
	_expect(not w.input_allowed(),"Pause menu did not stop the 3D keeper")
	tavern.pause_menu.close()
	w.keeper_body.position=Vector3(0,.1,3.3)
	tavern.keeper.position=w.to_plan(w.keeper_body.position)
	if "--capture" in OS.get_cmdline_user_args():
		root.size=Vector2i(1600,900)
		await _capture(tavern,w.to_room(Vector2(tavern.expansions.lodging_floor.position.x+240,600)),"lodgings")
		await _capture(tavern,training,"yard")
		await _capture(tavern,Vector3(0,.1,3.3),"playable")
		print("3D runtime draw calls: ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	# Dev access exposes all areas without buying tiers or rewriting rooms.
	state.campaign.establishment_tier=0
	var saved_rooms: Array = state.campaign.rooms.duplicate(true)
	settings.values["dev_mode"]=true
	settings.settings_changed.emit("dev_mode",true)
	for i in 12:await physics_frame
	_expect(tavern.expansions.accessible_room_count==18,"Dev mode did not expose every lodging room")
	_expect(w.wings.find_child("LockedYardGate",true,false)==null,"Dev yard is locked")
	_expect(w.wings.find_child("TrainingWeights",true,false)!=null,"Dev yard lacks full equipment")
	for index in tavern.expansions.accessible_room_count:
		var room_point: Vector3 = w.to_room(Vector2(tavern.expansions.lodging_floor.position.x+80+index*184+130,380))
		var room_path:=NavigationServer3D.map_get_path(map,Vector3(0,.1,0),room_point,true)
		_expect(room_path.size()>1 and room_path[-1].distance_to(room_point)<1.0,"Dev room is inaccessible: "+str(index+1))
	_expect(state.campaign.establishment_tier==0 and state.campaign.rooms==saved_rooms,"Dev access changed saved progression")
	settings.values["dev_mode"]=false
	settings.settings_changed.emit("dev_mode",false)
	for i in 12:await physics_frame
	_expect(w.wings.find_child("LockedYardGate",true,false)!=null,"Disabling dev mode did not restore yard gate")
	_expect(tavern.expansions.accessible_room_count==6,"Disabling dev mode did not restore room limit")
	# The shared departure callback launches once, including skip/fast-forward.
	state.campaign.recruit_candidate(candidate_id)
	tavern.selected_party_ids=[candidate_id] as Array[String]
	tavern.departure_running=true
	tavern.activity_controller.begin_departure(tavern.selected_party_ids,tavern._complete_expedition_launch)
	tavern.activity_controller.fast_forward()
	await process_frame
	_expect(controller.starts==1,"Departure failed to launch exactly once")
	tavern.activity_controller.fast_forward()
	_expect(controller.starts==1,"Departure skip launched twice")
	tavern.queue_free()
	controller.queue_free()
	settings.values["dev_mode"]=previous_dev
	await process_frame
	if failures.is_empty():print("TAVERN_3D_INTEGRATION_PASSED")
	quit(0 if failures.is_empty() else 1)

func _capture(tavern:Node,point:Vector3,suffix:String) -> void:
	var w:Node3D=tavern.world_3d
	w.keeper_body.walking=false
	w.keeper_body.position=point
	tavern.keeper.position=w.to_plan(point)
	tavern.keeper.set_modal_paused(true)
	for i in 45:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/visual_checks/tavern_3d_"+suffix+".png")
	tavern.keeper.set_modal_paused(false)
