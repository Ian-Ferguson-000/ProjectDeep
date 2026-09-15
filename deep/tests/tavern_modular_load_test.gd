extends SceneTree

func _initialize() -> void:
	var floor_scene:=load("res://scenes/tavern/taverntiles.tscn")
	var tavern_scene:=load("res://scenes/tavern/Tavern.tscn")
	var service:=TavernDialogueService.new()
	assert(floor_scene != null)
	assert(tavern_scene != null)
	assert(not service.conversations.is_empty())
	var dialogue_member:=CharacterRecord.new();dialogue_member.display_name="Test Hero";dialogue_member.origin="the test road";dialogue_member.occupation="pathfinder";dialogue_member.personality="Patient and determined.";dialogue_member.preference="honest company";dialogue_member.biography="Test Hero came to prove that stories can change."
	var dialogue_candidate:=CandidateRecord.create(dialogue_member,1,1,"I need to finish what I started.")
	var greeting:=service.play("candidate_default",{"candidate":dialogue_candidate})
	assert(greeting.node_id=="greeting" and greeting.lines.size()>=4)
	assert(String(greeting.lines[0].speaker)=="Test Hero" and String(greeting.lines[1].text).contains("finish what I started"))
	service.apply_effects(greeting.effects,{"campaign":CampaignState.new(),"candidate":dialogue_candidate})
	assert(dialogue_candidate.knowledge.origin=="exact" and dialogue_candidate.knowledge.preference=="exact")
	dialogue_candidate.knowledge.biography="exact"
	var deeper:=service.play("candidate_default",{"candidate":dialogue_candidate})
	assert(deeper.node_id=="known_history" and String(deeper.lines[1].text).contains("stories can change"))
	var roster_dialogue:=service.play("roster_default",{"member":dialogue_member})
	assert(roster_dialogue.lines.size()>=4 and String(roster_dialogue.lines[0].speaker)=="Test Hero")
	var floor:Node=floor_scene.instantiate()
	root.add_child(floor)
	await process_frame
	assert(floor.get_node("TileMapLayer").get_used_cells().size()==36*22)
	var campaign:=CampaignState.new()
	campaign.tavern_dialogue_flags["keeper_welcomed"]=true
	assert(service.evaluate_condition({"flag":"keeper_welcomed"},{"campaign":campaign}))
	var snapshot:=campaign.to_dict()
	assert(Dictionary(snapshot.get("tavern_dialogue_flags",{})).get("keeper_welcomed",false))
	var migrated:=CampaignState._migrate_dict({"version":6})
	assert(migrated.has("tavern_dialogue_flags"))
	var state:=RunState.new()
	state.campaign.apply_post_tutorial_state("victory")
	state.campaign.last_presented_wave_id=state.campaign.candidate_wave_id
	var tavern:Node=tavern_scene.instantiate()
	var empty_gear:Array[GearData]=[]
	tavern.setup(null,state,empty_gear,"")
	root.add_child(tavern)
	await process_frame
	assert(tavern.get_node_or_null("TavernWorld/Keeper") != null)
	assert(tavern.get_node("TavernWorld/Floor/TileMapLayer").get_used_cells().size()==36*22)
	assert(tavern.get_node_or_null("TavernWorld/Backdrop") == null)
	assert(tavern.get_node_or_null("TavernWorld/WallCollision") == null)
	var walls:=tavern.get_node("TavernWorld/Walls")
	var sections:=walls.find_children("*", "TavernWallSection", true, false)
	assert(sections.size() == 12)
	var wall_textures:Dictionary={}
	for section in sections:
		assert(not String(section.section_id).is_empty())
		assert(section.section_texture != null)
		assert(section.get_node_or_null("CollisionBody/CollisionShape2D") != null)
		assert(section.get_node_or_null("NavigationObstacle2D") != null)
		wall_textures[section.section_texture.resource_path]=true
	assert(wall_textures.size() == 6)
	var back_sections:Array[Node]=[
		walls.get_node("BackWall/WestEnd"),
		walls.get_node("BackWall/LanternBay"),
		walls.get_node("BackWall/CenterEast"),
		walls.get_node("BackWall/EastEnd"),
	]
	for index in range(1,back_sections.size()):
		var previous:Node=back_sections[index-1]
		var current:Node=back_sections[index]
		assert(current.position.x-current.collision_size.x*0.5<=previous.position.x+previous.collision_size.x*0.5)
	assert(back_sections.front().position.x-back_sections.front().collision_size.x*0.5<=256.5)
	assert(back_sections.back().position.x+back_sections.back().collision_size.x*0.5>=1407.5)
	assert(walls.get_node("SideWalls/WestRun").collision_size.y==704.0)
	assert(walls.get_node("SideWalls/EastRun").collision_size.y==704.0)
	assert(walls.get_node("SideWalls/WestRun").position.y-walls.get_node("SideWalls/WestRun").collision_size.y*0.5==192.0)
	assert(walls.get_node("SideWalls/WestRun").position.y+walls.get_node("SideWalls/WestRun").collision_size.y*0.5==896.0)
	assert(walls.get_node("SideWalls/WestRun").position.x+walls.get_node("SideWalls/WestRun").collision_offset.x==256.0)
	assert(walls.get_node("SideWalls/EastRun").position.x+walls.get_node("SideWalls/EastRun").collision_offset.x==1408.0)
	var keeper_body:=tavern.get_node("TavernWorld/Keeper") as CharacterBody2D
	keeper_body.position=Vector2(500,700);assert(keeper_body.move_and_collide(Vector2(-400,0))!=null)
	keeper_body.position=Vector2(1164,700);assert(keeper_body.move_and_collide(Vector2(400,0))!=null)
	keeper_body.position=Vector2(900,450);assert(keeper_body.move_and_collide(Vector2(0,-400))!=null)
	keeper_body.position=Vector2(350,600);assert(keeper_body.move_and_collide(Vector2(0,400))!=null)
	keeper_body.position=Vector2(832,700);assert(keeper_body.move_and_collide(Vector2(0,260))==null)
	keeper_body.position=Vector2(832,780)
	assert(walls.get_node("FrontWall/WestInner").position.x+walls.get_node("FrontWall/WestInner").collision_size.x*0.5>=704.0)
	assert(walls.get_node("FrontWall/EastInner").position.x-walls.get_node("FrontWall/EastInner").collision_size.x*0.5<=960.0)
	var bar:=tavern.get_node("TavernWorld/Fixtures/BarFixture") as TavernProp
	assert(bar.prop_texture!=null and bar.obstacle_enabled)
	assert(walls.find_child("BarFront",true,false)==null)
	var decor:=tavern.get_node("TavernWorld/Decor")
	var decor_props:=decor.find_children("*","TavernProp",true,false)
	assert(decor_props.size()==8)
	var decor_textures:Dictionary={}
	for prop in decor_props:
		assert(prop.prop_texture!=null)
		assert(prop.get_node_or_null("CollisionBody/CollisionShape2D")!=null)
		decor_textures[prop.prop_texture.resource_path]=true
	assert(decor_textures.size()==8)
	assert(tavern.get_node("TavernWorld/Floor/TileMapLayer").z_index<tavern.get_node("TavernWorld/Decor/HearthRug").z_index)
	assert(tavern.get_node_or_null("TavernWorld/Lighting/AmbientTone")!=null)
	assert(tavern.get_node("TavernWorld/Props/TableEast/Visual").texture.resource_path.ends_with("tavern_social_table_cards.png"))
	for table_name in ["TableWest","TableEast","TableSouthWest"]:
		var table:=tavern.get_node("TavernWorld/Props/%s"%table_name)
		assert((table.get_node("CollisionBody/CollisionShape2D") as CollisionShape2D).shape.size==Vector2(106,58))
		for seat in table.find_children("Seat*","Marker2D",false,false):
			assert(absf(seat.position.x)<=24.0 and absf(seat.position.y)<=42.5)
	assert(tavern.get_node("TavernWorld/Keeper").position.y<tavern.get_node("TavernWorld/ActivityAnchors/Entrance").position.y)
	assert(tavern.prompt_panel.offset_bottom<=tavern.toolbar.offset_top)
	for candidate in state.campaign.get_candidates():
		assert(tavern.activity_controller.actors.has(candidate.id))
		assert((tavern.activity_controller.actors[candidate.id] as TavernActor).visible)
	print("Modular tavern resources loaded.")
	quit(0)
