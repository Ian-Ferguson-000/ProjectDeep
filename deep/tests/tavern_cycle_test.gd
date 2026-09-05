extends SceneTree

func _initialize()->void:call_deferred("_run")

func _run()->void:
	var failures:Array[String]=[]
	var campaign:=CampaignState.new();campaign.apply_post_tutorial_state("victory")
	_expect(campaign.calendar_day==1 and campaign.get_calendar_date()=={"absolute_day":1,"weekday":"Monday","season":"Spring","season_day":1,"year":1},"Calendar did not begin on Monday, Spring 1, Year 1",failures)
	_expect(campaign.roster.is_empty() and campaign.candidate_pool.size()==2,"Tutorial company was not converted to two candidates",failures)
	var candidates:=campaign.get_candidates();_expect(candidates[0].adventurer.display_name=="Brina" and candidates[1].adventurer.display_name=="Eamon","Fixed first candidate wave is incorrect",failures)
	var first_id:=candidates[0].id;var second_id:=candidates[1].id
	_expect(bool(campaign.recruit_candidate(first_id).ok),"First recruit failed",failures)
	_expect(not bool(campaign.recruit_candidate(first_id).ok),"Recruitment double-applied",failures)
	_expect(not bool(campaign.launch_expedition([first_id],"forest","strategy").ok),"First expedition launched before both conversations",failures)
	_expect(bool(campaign.recruit_candidate(second_id).ok),"Second recruit failed",failures)
	var launch:=campaign.launch_expedition([first_id],"forest","strategy");_expect(bool(launch.ok) and campaign.expedition.party_ids==[first_id],"One-person first launch was not accepted",failures)
	var run_id:=int(launch.expedition_id);campaign.expedition.carried_gold=25
	var settlement:=campaign.settle_expedition(run_id,"victory",{"headline":"Forest victory"})
	_expect(bool(settlement.ok) and campaign.calendar_day==2 and campaign.banked_gold==145,"Victory settlement did not bank rewards and advance one day",failures)
	_expect(campaign.character(first_id)==null and campaign.retired_heroes.size()==1,"Participating survivor did not retire",failures)
	_expect(campaign.character(second_id)!=null,"Unselected roster member was removed",failures)
	_expect(campaign.candidate_pool.size()==2,"Settlement did not create the next deterministic candidate wave",failures)
	var snapshot:=campaign.to_dict();var restored:=CampaignState.new();restored._load_dict(snapshot)
	_expect(JSON.stringify(restored.to_dict().candidate_pool)==JSON.stringify(snapshot.candidate_pool),"Candidate wave rerolled after serialization",failures)
	var duplicate:=campaign.settle_expedition(run_id,"victory",{});_expect(bool(duplicate.get("duplicate",false)) and campaign.calendar_day==2,"Settlement double-applied",failures)
	campaign.calendar_day=28;_expect(campaign.get_calendar_date().season=="Spring" and campaign.get_calendar_date().season_day==28,"Spring boundary is incorrect",failures)
	campaign.calendar_day=29;_expect(campaign.get_calendar_date().season=="Summer" and campaign.get_calendar_date().season_day==1,"Summer boundary is incorrect",failures)
	campaign.calendar_day=113;_expect(campaign.get_calendar_date().year==2 and campaign.get_calendar_date().season=="Spring","Year boundary is incorrect",failures)
	campaign.tavern_upgrades.roster_services=3;_expect(campaign.get_roster_capacity()==12,"Dynamic room capacity formula is incorrect",failures)
	campaign.candidate_pool.clear();campaign._generate_candidate_wave();_expect(campaign.candidate_pool.size()==5,"Room rank candidate-count formula is incorrect",failures)
	var defeat:=CampaignState.new();defeat.apply_post_tutorial_state("death");for candidate in defeat.get_candidates():defeat.recruit_candidate(candidate.id)
	var defeat_party:=defeat.default_party("forest");var defeat_launch:=defeat.launch_expedition(defeat_party,"forest","slasher");defeat.expedition.carried_gold=99;defeat.settle_expedition(int(defeat_launch.expedition_id),"death",{"headline":"The company is lost."})
	_expect(defeat.banked_gold==120 and defeat.memorial.size()==2 and defeat.calendar_day==2 and defeat.candidate_pool.size()>=2,"Defeat did not discard loot, memorialize the party, advance once, and recover candidates",failures)
	var legacy_brina:=CharacterRecord.create("old_brina","Brina","warrior",{},0);var legacy_eamon:=CharacterRecord.create("old_eamon","Eamon","mage",{},0)
	var legacy_data:=CampaignState._migrate_dict({"version":4,"tutorial_phase":CampaignState.TUTORIAL_COMPLETE,"post_tutorial_initialized":true,"completed_dungeon_modes":{},"roster":[legacy_brina.to_dict(),legacy_eamon.to_dict()]});var converted:=CampaignState.new();converted._load_dict(legacy_data)
	_expect(converted.roster.is_empty() and converted.candidate_pool.size()==2 and converted.first_company_ids.size()==2,"Untouched legacy first company was not migrated into candidates",failures)
	var progressed_data:=CampaignState._migrate_dict({"version":4,"tutorial_phase":CampaignState.TUTORIAL_COMPLETE,"post_tutorial_initialized":true,"completed_dungeon_modes":{"forest":["strategy"]},"roster":[legacy_brina.to_dict()]});var progressed:=CampaignState.new();progressed._load_dict(progressed_data)
	_expect(progressed.roster.size()==1 and progressed.character("old_brina")!=null,"Progressed legacy migration deleted an existing roster",failures)
	if failures.is_empty():print("TAVERN_CYCLE_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
