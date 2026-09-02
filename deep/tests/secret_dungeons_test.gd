extends SceneTree
const GROVE:=preload("res://scenes/secret/MoonlitGrove.tscn")
const ARCHIVE:=preload("res://scenes/secret/AbyssalArchive.tscn")
func _initialize()->void:call_deferred("_run")
func _run()->void:
	var failures:Array[String]=[]
	for dungeon_id in ["moonlit_grove","abyssal_archive"]:
		var definition:=GameBalance.get_dungeon(dungeon_id);_expect(String(definition.runtime)==dungeon_id and String(definition.slasher_runtime)==dungeon_id,"%s lacks bespoke mode routing"%dungeon_id,failures);_expect(String(definition.get("merchant_id",""))=="","%s incorrectly declares a merchant"%dungeon_id,failures)
	var campaign:=CampaignState.new();campaign.tutorial_phase=CampaignState.TUTORIAL_COMPLETE;campaign.ensure_roster();campaign.record_dungeon_clear("forest","strategy");campaign.record_dungeon_clear("ashen_farmstead","strategy");campaign.record_dungeon_clear("crypt","strategy");campaign.record_dungeon_clear("ember_foundry","strategy");campaign.tavern_upgrades.secret_research=1
	for pair in [["moonlit_grove",GROVE],["abyssal_archive",ARCHIVE]]:
		var id:String=pair[0];_expect(campaign.can_unlock_secret(id),"%s clue/research unlock failed"%id,failures);var party:=campaign.default_party(id);campaign.begin_expedition(party,id,"strategy");var state:=RunState.new();state.attach_campaign(campaign);state.active_character_id=party[0];state.start_new_run(null,id,"strategy");var scene:Node=pair[1].instantiate();scene.setup(null,state);root.add_child(scene);await process_frame;_expect(scene.dungeon_id==id and scene.dungeon_merchant.is_empty() and not scene.enemies.is_empty(),"%s did not generate as a merchant-free secret runtime"%id,failures);scene.free();campaign.resolve_expedition("abandon")
	_expect(ResourceLoader.exists("res://scenes/slasher/SlasherGrove.tscn") and ResourceLoader.exists("res://scenes/slasher/SlasherArchive.tscn"),"Secret Slasher scenes are missing",failures)
	if failures.is_empty():print("SECRET_DUNGEON_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)
func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
