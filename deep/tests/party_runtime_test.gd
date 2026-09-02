extends SceneTree

const FOREST:=preload("res://scenes/forest/Forest.tscn")
const SLASHER_FOREST:=preload("res://scenes/slasher/SlasherForest.tscn")

func _initialize()->void:call_deferred("_run")

func _run()->void:
	var failures:Array[String]=[];var state:=RunState.new();state.campaign.tutorial_phase=CampaignState.TUTORIAL_COMPLETE;state.campaign.ensure_roster();var party:=state.campaign.default_party("forest")
	_expect(party.size()==2,"Forest did not provide a two-member party",failures);state.campaign.begin_expedition(party,"forest","strategy");state.active_character_id=party[0];var first:=state.campaign.character(party[0]);state.set_class(first.class_id);state.start_new_run(GearData.create("party_test","Party Test",2,false,0,"","",first.class_id,"none"),"forest","strategy")
	var scene:=FOREST.instantiate();scene.setup(null,state);root.add_child(scene);await process_frame;await process_frame
	var player_turns:=0
	for actor in scene.initiative_order:
		if String(actor.get("kind",""))=="player":player_turns+=1
	_expect(player_turns==2,"Strategy initiative did not include every party member",failures)
	_expect(scene.strategy_party_tokens.size()==1,"Strategy did not render the inactive party token",failures)
	var original_id:=state.active_character_id;var original_position:Vector2i=scene.player_pos;scene._cycle_strategy_member();_expect(state.active_character_id==original_id,"Strategy allowed manual character control outside initiative",failures)
	scene._inspect_next_party_initiative();_expect(state.active_character_id==original_id and scene.initiative_inspection_index>=0,"Strategy initiative inspection changed control or failed to highlight a card",failures)
	var other_id:=party[1] if party[0]==original_id else party[0];scene.player_pos+=Vector2i.RIGHT;var moved_position:Vector2i=scene.player_pos;scene._save_strategy_member_runtime();scene._activate_strategy_member(other_id);var other_position:Vector2i=scene.player_pos
	_expect(other_position!=moved_position,"Strategy initialized two recruits on the same tile",failures);scene._activate_strategy_member(original_id);_expect(scene.player_pos==moved_position,"Strategy initiative handoff reset the outgoing recruit position",failures)
	_expect(scene.strategy_party_tokens.size()==1 and scene._inactive_party_at(other_position),"Strategy party token occupancy was not preserved",failures)
	scene.free()
	var slasher_state:=RunState.new();slasher_state.campaign.tutorial_phase=CampaignState.TUTORIAL_COMPLETE;slasher_state.campaign.ensure_roster();var slasher_party:=slasher_state.campaign.default_party("forest");slasher_state.campaign.begin_expedition(slasher_party,"forest","slasher");slasher_state.active_character_id=slasher_party[0];var slasher_member:=slasher_state.campaign.character(slasher_party[0]);slasher_state.set_class(slasher_member.class_id);slasher_state.start_new_run(GearData.create("slasher_party_test","Party Test",2,false,0,"","",slasher_member.class_id,"none"),"forest","slasher")
	var slasher:=SLASHER_FOREST.instantiate();slasher.setup(null,slasher_state);root.add_child(slasher);await process_frame;await process_frame
	_expect(get_nodes_in_group("slasher_companion").is_empty(),"Slasher spawned benched recruits as companion actors",failures);_expect(slasher.party_portraits.size()==2,"Slasher party HUD did not show both living recruits",failures)
	var slasher_id:=slasher_state.active_character_id;var swap_position:Vector2=slasher.player.global_position;slasher.player.cooldowns.special=3.0;slasher._cycle_party_member();_expect(slasher_state.active_character_id!=slasher_id and slasher.player.global_position==swap_position,"Slasher swap changed position or failed to change control",failures)
	var saved_runtime:Dictionary=slasher_state.campaign.expedition.member_runtime.get(slasher_id,{});var saved_cooldown:=float(Dictionary(saved_runtime.get("slasher",{})).get("cooldowns",{}).get("special",0.0));_expect(saved_cooldown>0.0,"Slasher swap did not preserve the outgoing cooldown",failures)
	slasher._tick_benched_party(1.0);saved_runtime=slasher_state.campaign.expedition.member_runtime.get(slasher_id,{});_expect(float(Dictionary(saved_runtime.get("slasher",{})).get("cooldowns",{}).get("special",0.0))<saved_cooldown,"Benched Slasher cooldown did not continue advancing",failures)
	slasher.free()
	if failures.is_empty():print("PARTY_RUNTIME_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
