extends SceneTree
const FOREST := preload("res://game/dungeons/forest/Forest3D.tscn")
class MemoryCampaign extends CampaignState:
	func save_atomic() -> bool: return true
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func expect(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error(message)
func _run() -> void:
	root.size = Vector2i(1600,1000)
	var original_mask := root.canvas_cull_mask
	var scene := FOREST.instantiate()
	scene._ensure_designer_controls()
	var state := RunState.new()
	state.campaign = MemoryCampaign.new()
	state.requested_seed = 246810
	state.start_new_run(GearData.create("forest3d_test","Forest 3D",3,false,0,"","","warrior"),"forest")
	state.current_floor = 2
	state.starter_reward_claimed = true
	scene.run_state = state
	root.add_child(scene)
	for i in 8: await process_frame
	expect(scene.rooms_active,"3D scene lost the room graph")
	expect(scene.world_3d.art.get_child_count()>0,"3D geometry was not built")
	expect(not scene.player.camera.enabled,"Legacy camera overrides 3D aiming")
	var w: Node3D = scene.world_3d
	# Verify the entire inverse screen mapping, not just the player's location.
	for point in [scene.player.position,Vector2(240,240),Vector2(600,400)]:
		var screen: Vector2 = w.camera.unproject_position(w.to_world(point))
		expect((root.canvas_transform.affine_inverse()*screen).distance_to(point)<0.2,"Mouse aiming is misaligned with 3D ground")
	# Screen-relative keyboard and controller movement preserve their direction.
	var move: Vector2 = scene.player._screen_input_to_world(Vector2.RIGHT)
	var projected := root.canvas_transform.basis_xform(move)
	expect(projected.x>0 and absf(projected.y)<0.01,"Right movement is not screen-relative")
	var before: Vector2 = scene.player.position
	Input.action_press("slasher_right")
	for i in 12: await physics_frame
	Input.action_release("slasher_right")
	var moved: Vector2 = root.canvas_transform.basis_xform(scene.player.position-before)
	expect(moved.x>2 and absf(moved.y)<2,"Actual movement did not follow screen-right")
	if "--capture" in OS.get_cmdline_user_args(): await capture("start")
	var first: String = scene.door_nodes.keys()[0]
	var neighbor := int(scene.room.neighbors[first])
	scene.transition_cooldown = 0
	scene.player.position = scene.door_nodes[first].position
	scene._check_doors()
	for i in 8: await process_frame
	expect(scene.room_id==neighbor,"3D door did not enter its connected room")
	expect(scene.world_3d!=w,"Room transition did not replace 3D geometry")
	if "--capture" in OS.get_cmdline_user_args(): await capture("combat")
	# Exercise combat locks and actual damage/death callbacks in a combat room.
	for record in state.field_run.rooms:
		if String(record.role) != "combat": continue
		state.enter_field_room(int(record.id),-1)
		scene._build_floor()
		for i in 5: await physics_frame
		expect(not scene.exit_open and scene.enemies_remaining>0,"Combat doors were not locked")
		for model in scene.world_3d.doors.values(): expect(model.get_node("Brambles").visible,"Locked brambles are invisible")
		var blocked_room: int = scene.room_id
		scene.player.position = scene.door_nodes.values()[0].position
		scene.transition_cooldown = 0
		scene._check_doors()
		expect(scene.room_id==blocked_room,"Player escaped through a locked door")
		scene.transition_cooldown=100.0
		for enemy in get_nodes_in_group("slasher_enemy"):
			if enemy is SlasherEnemy:
				enemy.health=1
				enemy.receive_hit(999)
		for i in 5: await process_frame
		expect(scene.exit_open and state.get_field_room(scene.room_id).cleared,"Defeating enemies did not clear the room")
		for model in scene.world_3d.doors.values(): expect(not model.get_node("Brambles").visible,"Cleared brambles remained visible")
		break
	# Props use the real damage and chest-opening paths and remove their models.
	var prop: SlasherBreakableProp = scene.BREAKABLE_PROP.new()
	prop.setup("rock",Vector2i(5,5)); prop.position=scene._world(Vector2i(5,5))
	scene.actor_layer.add_child(prop)
	await process_frame
	var model: Node3D = scene.world_3d.props[prop]
	prop.receive_attack({"damage":999},scene.player)
	await process_frame
	expect(not model.visible,"Destroyed rock retained its 3D obstacle")
	var chest: SlasherBreakableProp = scene.BREAKABLE_PROP.new()
	chest.setup("chest",Vector2i(6,5)); chest.position=scene._world(Vector2i(6,5))
	scene.actor_layer.add_child(chest)
	await process_frame
	chest.open_chest()
	await process_frame
	expect(scene.world_3d.props[chest].has_meta("opened"),"Opened chest retained its closed model")
	# Select each peaceful room role, including its actual healing/shop trigger.
	for role in ["rest","shop","treasure"]:
		var selected := -1
		for record in state.field_run.rooms:
			if String(record.role)==role: selected=int(record.id); break
		if selected<0:
			selected=0
			state.update_field_room(selected,{"role":role,"template_id":"","cleared":true})
		state.enter_field_room(selected,-1)
		scene._build_floor()
		for i in 5: await process_frame
		if role=="rest":
			scene.player.health=1
			expect(scene.rest_at_campfire() and scene.player.health>1,"3D campfire did not heal")
			expect(not scene.rest_at_campfire(),"Campfire healed twice")
		if role=="shop": expect(scene.has_dungeon_merchant,"3D trader camp lost its merchant")
		if "--capture" in OS.get_cmdline_user_args(): await capture(role)
	# Water remains nonwalkable and renders below the bank, never as grass.
	for template in ForestRoomLibrary.templates():
		if not str(template.get("map",[])).contains("~"): continue
		state.update_field_room(0,{"role":"combat","template_id":String(template.id),"cleared":true})
		state.enter_field_room(0,-1)
		scene._build_floor()
		for i in 5: await process_frame
		expect(not scene.layout.water_cells.is_empty(),"Pond room lost its water")
		for cell in scene.layout.water_cells: expect(not scene.layout.cells.has(cell),"Water became walkable")
		expect(scene.world_3d.art.batches.has("box487e78false"),"Pond has no 3D water surface")
		if "--capture" in OS.get_cmdline_user_args(): await capture("pond")
		break
	# Build the real guardian floor and preserve its damageable weak points.
	state.current_floor=5
	scene._build_floor()
	for record in state.field_run.rooms:
		if String(record.role)!="boss": continue
		state.enter_field_room(int(record.id),-1)
		scene._build_floor()
		break
	for i in 6: await process_frame
	var colossus: SlasherColossus
	for actor in scene.actor_layer.get_children():
		if actor is SlasherColossus: colossus=actor
	expect(colossus!=null,"Guardian floor did not build the colossus")
	if colossus!=null:
		scene.player.position=colossus.position+Vector2(140,220)
		scene.player.invulnerable=999.0
		expect(scene.world_3d.actors[colossus].name=="HeartwoodColossus","Colossus has no 3D model")
		colossus.heart.open_for(10)
		var health: int=colossus.health
		colossus.heart.receive_attack({"damage":2},scene.player)
		expect(colossus.health<health,"Colossus weak-point damage was lost")
		colossus.telegraphs=[{"kind":"slam","pos":scene.player.position+Vector2(90,0),"radius":74.0,"t":0.0,"total":5.0}]
		colossus.set_physics_process(false)
		if "--capture" in OS.get_cmdline_user_args(): await capture("guardian")
		colossus.health=1
		colossus.heart.open_for(10)
		colossus.heart.receive_attack({"damage":999},scene.player)
		for i in 5: await process_frame
		expect(scene.world_3d.art.get_node_or_null("FallenHeartwood")!=null,"Defeated guardian did not leave a 3D stump")
	scene.queue_free()
	await process_frame
	expect(root.canvas_cull_mask==original_mask,"3D presentation leaked its render mask on exit")
	expect(root.canvas_transform==Transform2D.IDENTITY,"3D presentation leaked its aim transform on exit")
	# Tutorial uses the connected-floor fallback but must still present in 3D.
	var tutorial_campaign := MemoryCampaign.new()
	var alden := tutorial_campaign.create_tutorial_adventurer()
	tutorial_campaign.begin_expedition([alden.id],"forest",true)
	var tutorial_state := RunState.new()
	tutorial_state.attach_campaign(tutorial_campaign)
	tutorial_state.active_character_id=alden.id
	tutorial_state.start_new_run(null,"forest")
	var tutorial := FOREST.instantiate()
	tutorial.run_state=tutorial_state
	root.add_child(tutorial)
	for i in 5: await process_frame
	expect(not tutorial.rooms_active and tutorial.world_3d!=null,"Tutorial fallback did not build in 3D")
	expect(tutorial.tutorial_sequence!=null,"3D tutorial lost its onboarding UI")
	tutorial.queue_free()
	await process_frame
	if failures.is_empty(): print("FOREST_3D_TEST_PASSED")
	quit(0 if failures.is_empty() else 1)
func capture(suffix: String) -> void:
	await create_timer(3.0).timeout
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/visual_checks/forest_3d_"+suffix+".png")
