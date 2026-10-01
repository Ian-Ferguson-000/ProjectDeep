extends SceneTree

const SLASHER_FOREST:=preload("res://scenes/slasher/SlasherForest.tscn")
func _initialize()->void:call_deferred("_run")
func _run()->void:
	var failures:Array[String]=[];var state:=RunState.new();state.campaign.tutorial_phase=CampaignState.TUTORIAL_COMPLETE;state.campaign.ensure_roster();var party:=state.campaign.default_party("forest")
	_expect(party.size()==2,"Forest did not provide a two-member party",failures);state.campaign.begin_expedition(party,"forest");state.active_character_id=party[0];state.set_class(state.campaign.character(party[0]).class_id);state.start_new_run(null,"forest")
	var scene:=SLASHER_FOREST.instantiate();scene.setup(null,state);root.add_child(scene);await process_frame;await process_frame
	_expect(scene.party_portraits.size()==2,"Slasher HUD did not show both living recruits",failures)
	scene.player.combo_updated.emit({"type":"progress","progress":{"name":"Crosscut","index":1,"total":3,"next":"Charge"}});_expect(scene.combo_label!=null and "CROSSCUT" in scene.combo_label.text and "CHARGE" in scene.combo_label.text,"Slasher HUD did not render combo progress",failures)
	var active_id:=state.active_character_id;var position:Vector2=scene.player.global_position;scene.player.cooldowns.special=3.0;scene.player.combo_runtime.record_action("basic");scene._cycle_party_member()
	_expect(state.active_character_id!=active_id and scene.player.global_position==position,"Party swap changed position or failed to change control",failures)
	var saved:Dictionary=state.campaign.expedition.member_runtime.get(active_id,{});var cooldown:=float(Dictionary(saved.get("slasher",{})).get("cooldowns",{}).get("special",0.0));_expect(cooldown>0.0,"Party swap did not save the outgoing cooldown",failures)
	scene._tick_benched_party(1.0);saved=state.campaign.expedition.member_runtime.get(active_id,{});_expect(float(Dictionary(saved.get("slasher",{})).get("cooldowns",{}).get("special",0.0))<cooldown,"Benched cooldown did not continue advancing",failures)
	var combo_states:Dictionary=Dictionary(Dictionary(Dictionary(saved.get("slasher",{})).get("combo",{})).get("states",{}));var active_combo:Dictionary={}
	for combo_id in combo_states:
		if int(Dictionary(combo_states[combo_id]).get("index",0))>0:active_combo=Dictionary(combo_states[combo_id]);break
	_expect(not active_combo.is_empty() and float(active_combo.get("remaining",0.0))<2.5,"Benched combo progress was not saved and ticked down",failures)
	scene.free()
	if failures.is_empty():print("PARTY_RUNTIME_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)
func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
