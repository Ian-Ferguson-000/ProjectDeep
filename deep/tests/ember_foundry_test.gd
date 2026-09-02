extends SceneTree
const SCENE:=preload("res://scenes/foundry/EmberFoundry.tscn")
func _initialize()->void:call_deferred("_run")
func _run()->void:
	var failures:Array[String]=[];var definition:=GameBalance.get_dungeon("ember_foundry")
	_expect(String(definition.get("runtime",""))=="ember_foundry" and String(definition.get("slasher_runtime",""))=="ember_foundry","Foundry runtime routing is incomplete",failures)
	var campaign:=CampaignState.new();campaign.tutorial_phase=CampaignState.TUTORIAL_COMPLETE;campaign.ensure_roster();campaign.record_dungeon_clear("forest","strategy");campaign.record_dungeon_clear("ashen_farmstead","strategy");campaign.record_dungeon_clear("crypt","strategy");var party:=campaign.default_party("ember_foundry");_expect(campaign.begin_expedition(party,"ember_foundry","strategy"),"Foundry did not unlock after both prerequisite clears",failures)
	var state:=RunState.new();state.attach_campaign(campaign);state.active_character_id=party[0];state.start_new_run(null,"ember_foundry","strategy");var scene:=SCENE.instantiate();scene.setup(null,state);root.add_child(scene);await process_frame
	_expect(scene.dungeon_id=="ember_foundry" and not scene.enemies.is_empty() and scene.traps.size()>=3,"Foundry failed to generate its tactical encounter",failures);scene.free()
	_expect(ResourceLoader.exists("res://scenes/slasher/SlasherFoundry.tscn"),"Foundry Slasher scene is missing",failures)
	if failures.is_empty():print("EMBER_FOUNDRY_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)
func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
