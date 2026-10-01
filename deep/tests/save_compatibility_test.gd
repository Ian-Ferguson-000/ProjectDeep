extends SceneTree

func _initialize()->void:call_deferred("_run")
func _run()->void:
	var failures:Array[String]=[];var source:=CampaignState.new();source.ensure_roster();var party:=source.default_party("forest")
	for id in party:source.character(id).status=CharacterRecord.STATUS_EXPEDITION
	var save_data:=source.to_dict();var expedition:Dictionary=save_data.get("expedition",{}).duplicate(true)
	expedition.merge({"active":true,"expedition_id":12,"dungeon_id":"forest","play_mode":"strategy","party_ids":party,"floor":3,"deployment_type":"manual","due_day":8},true);save_data["expedition"]=expedition
	save_data["completed_dungeon_modes"]={"forest":["strategy"]}
	var migrated:=CampaignState._migrate_dict(save_data);_expect(bool(migrated.get("completed_dungeons",{}).get("forest",false)),"Prior Forest clear was not preserved",failures)
	var loaded:=CampaignState.new();loaded._load_dict(migrated);_expect(CampaignState._settle_removed_mode_run(loaded,migrated),"Removed-runtime expedition was not settled",failures)
	_expect(not loaded.expedition.active and loaded.settled_expeditions.has("12"),"Defeat settlement did not close and record the expedition",failures)
	_expect(loaded.memorial.size()==party.size(),"Defeated expedition members were not recorded in the memorial",failures)
	_expect(loaded.unlocked_classes.has("tank") and loaded.unlocked_classes.has("rogue"),"Prior Forest clear did not preserve both class unlocks",failures)
	var memorial_count:=loaded.memorial.size();_expect(not CampaignState._settle_removed_mode_run(loaded,migrated),"Legacy expedition settled more than once",failures)
	var reloaded:=CampaignState.new();reloaded._load_dict(CampaignState._migrate_dict(loaded.to_dict()))
	_expect(not reloaded.expedition.active and reloaded.memorial.size()==memorial_count and reloaded.settled_expeditions.has("12"),"Saved defeat did not survive reload",failures)
	if failures.is_empty():print("SAVE_COMPATIBILITY_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)
func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
