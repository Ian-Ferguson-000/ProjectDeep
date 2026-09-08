extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var failures:Array[String]=[]
	var campaign:=CampaignState.new()
	campaign.tutorial_phase=CampaignState.TUTORIAL_COMPLETE
	campaign.ensure_roster()
	var party:=campaign.default_party("forest")
	_expect(campaign.begin_expedition(party,"forest",RunState.PLAY_MODE_SLASHER),"Forest expedition did not launch",failures)
	var expedition_id:=campaign.expedition.expedition_id
	var run:=RunState.new();run.attach_campaign(campaign);run.active_character_id=party[0];run.set_class(campaign.character(party[0]).class_id);run.start_new_run(null,"forest",RunState.PLAY_MODE_SLASHER)
	run.gold=47;run.current_health=maxi(1,run.max_health-2);var carried_health:=run.current_health
	run.record_active_dungeon_completion()
	_expect(run.is_dungeon_unlocked("crypt"),"Forest completion did not unlock the connected Crypt",failures)
	_expect(run.transition_to_dungeon("crypt"),"Connected Crypt transition failed",failures)
	_expect(campaign.expedition.active and campaign.expedition.expedition_id==expedition_id,"Connected transition settled or replaced the expedition",failures)
	_expect(campaign.expedition.dungeon_id=="crypt" and campaign.expedition.floor==1,"Expedition save did not move to Crypt floor one",failures)
	_expect(run.gold==47 and run.current_health==carried_health,"Connected transition reset carried rewards or health",failures)
	_expect(campaign.banked_gold==0 and campaign.calendar_day==1,"Connected transition visited settlement or advanced time",failures)
	_expect(campaign.candidate_wave_id==0,"Connected transition generated a tavern candidate wave",failures)
	var encoded:=campaign.to_dict();var restored:=CampaignState.new();restored._load_dict(encoded)
	_expect(restored.expedition.active and restored.expedition.dungeon_id=="crypt" and restored.expedition.expedition_id==expedition_id,"Save/load lost the connected expedition",failures)
	if failures.is_empty():print("CONNECTED_DUNGEON_FLOW_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
