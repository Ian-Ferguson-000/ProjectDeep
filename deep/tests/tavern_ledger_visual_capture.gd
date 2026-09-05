extends SceneTree

const TAVERN:=preload("res://scenes/tavern/Tavern.tscn")

func _initialize()->void:call_deferred("_capture")

func _capture()->void:
	var state:=RunState.new();state.campaign.apply_post_tutorial_state("victory");state.campaign.last_presented_wave_id=state.campaign.candidate_wave_id;state.campaign.tavern_phase=CampaignState.TAVERN_OPEN;state.set_class("warrior")
	state.campaign.banked_gold=235;state.campaign.relic_essence=47;state.campaign.successful_levels=18;state.campaign.banked_relics=["nature_relic","fate_relic"]
	var gear:=GearData.create("visual_test","Iron Vanguard Kit",3,true,2,"","Visual test gear.","warrior","block");var gear_list:Array[GearData]=[gear]
	var tavern:=TAVERN.instantiate();tavern.setup(null,state,gear_list,"");root.add_child(tavern);await process_frame;await process_frame
	root.get_texture().get_image().save_png("res://build/tavern_static_candidates_1280x720.png")
	tavern._open_calendar();await process_frame;await process_frame;root.get_texture().get_image().save_png("res://build/tavern_calendar_1280x720.png");tavern._close_modal(tavern.calendar_backdrop)
	var candidate:CandidateRecord=state.campaign.get_candidates()[0];tavern._open_candidate(candidate.id);await process_frame;await process_frame;root.get_texture().get_image().save_png("res://build/tavern_recruitment_1280x720.png");tavern.recruitment_dialogue.close()
	for candidate_value in state.campaign.get_candidates():var member:CharacterRecord=candidate_value.adventurer;member.status=CharacterRecord.STATUS_AVAILABLE;state.campaign.roster[member.id]=member
	state.campaign.candidate_pool.clear();state.campaign.retired_heroes.append({"name":"Sable Hart","class_id":"rogue","level":6,"retired_day":1,"expeditions":3,"victories":1});state.campaign.memorial.append({"name":"Orren Vale","class_id":"warrior","level":4,"cause":"Held the line in the Stone Crypt","expeditions":2,"victories":0})
	tavern._open_company_ledger();await process_frame;await process_frame
	for index in tavern.company_tabs.get_tab_count():
		tavern.company_tabs.current_tab=index;await process_frame;await process_frame
		var page_name:String=tavern.company_tabs.get_tab_title(index).to_lower().replace(" ","_");var error:=root.get_texture().get_image().save_png("res://build/ledger_%s.png"%page_name)
		if error!=OK:push_error("Unable to capture ledger tab %s"%page_name);quit(1);return
	tavern.free();root.content_scale_factor=1.5;await process_frame
	var scaled_state:=RunState.new();scaled_state.campaign.apply_post_tutorial_state("victory");scaled_state.campaign.last_presented_wave_id=scaled_state.campaign.candidate_wave_id;scaled_state.set_class("warrior")
	var scaled:=TAVERN.instantiate();scaled.setup(null,scaled_state,gear_list,"");root.add_child(scaled);await process_frame;await process_frame;scaled._open_calendar();await process_frame;await process_frame
	root.get_texture().get_image().save_png("res://build/tavern_calendar_150_percent.png");scaled._close_modal(scaled.calendar_backdrop);scaled._open_candidate(scaled_state.campaign.get_candidates()[0].id);await process_frame;await process_frame;root.get_texture().get_image().save_png("res://build/tavern_interaction_150_percent.png");scaled.free();root.content_scale_factor=1.0
	print("TAVERN_LEDGER_VISUAL_CAPTURE_PASSED");quit(0)
