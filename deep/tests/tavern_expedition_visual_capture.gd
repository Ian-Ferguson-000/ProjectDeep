extends SceneTree

const TAVERN:=preload("res://scenes/tavern/Tavern.tscn")

func _initialize()->void:call_deferred("_capture")

func _capture()->void:
	var state:=RunState.new();state.campaign.tutorial_phase=CampaignState.TUTORIAL_COMPLETE;state.campaign.ensure_roster();state.active_character_id=state.campaign.living_roster()[0].id;state.set_class("warrior")
	var gear:=GearData.create("visual_test","Iron Vanguard Kit",3,true,2,"","Visual test gear.","warrior","block");var gear_list:Array[GearData]=[gear]
	var tavern:=TAVERN.instantiate();tavern.setup(null,state,gear_list,"");root.add_child(tavern);await process_frame;await process_frame;tavern._open_dungeon_selector();await process_frame;await process_frame
	var error:=root.get_texture().get_image().save_png("res://build/expedition_selector.png")
	if error!=OK:push_error("Unable to capture expedition selector");quit(1);return
	print("TAVERN_EXPEDITION_VISUAL_CAPTURE_PASSED");quit(0)
