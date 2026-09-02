extends SceneTree

const TAVERN:=preload("res://scenes/tavern/Tavern.tscn")

func _initialize()->void:call_deferred("_capture")

func _capture()->void:
	var state:=RunState.new();state.campaign.tutorial_phase=CampaignState.TUTORIAL_COMPLETE;state.campaign.ensure_roster();state.active_character_id=state.campaign.living_roster()[0].id;state.set_class("warrior")
	state.campaign.banked_gold=235;state.campaign.relic_essence=47;state.campaign.successful_levels=18;state.campaign.banked_relics=["nature_relic","fate_relic"]
	var fallen:=state.campaign.living_roster()[5];state.campaign.record_casualty(fallen.id,"Held the line in the Stone Crypt");state.campaign.ensure_roster()
	var gear:=GearData.create("visual_test","Iron Vanguard Kit",3,true,2,"","Visual test gear.","warrior","block");var gear_list:Array[GearData]=[gear]
	var tavern:=TAVERN.instantiate();tavern.setup(null,state,gear_list,"");root.add_child(tavern);await process_frame;await process_frame;tavern._open_company_ledger();await process_frame;await process_frame
	for index in tavern.company_tabs.get_tab_count():
		tavern.company_tabs.current_tab=index;await process_frame;await process_frame
		var page_name:String=tavern.company_tabs.get_tab_title(index).to_lower().replace(" ","_");var error:=root.get_texture().get_image().save_png("res://build/ledger_%s.png"%page_name)
		if error!=OK:push_error("Unable to capture ledger tab %s"%page_name);quit(1);return
	print("TAVERN_LEDGER_VISUAL_CAPTURE_PASSED");quit(0)
