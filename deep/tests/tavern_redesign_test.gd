extends SceneTree

const TAVERN := preload("res://scenes/tavern/Tavern.tscn")
const CLASS_IDS := ["warrior","mage","healer","tank","rogue","summoner"]

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	for viewport_size in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
		root.size = viewport_size
		var state := RunState.new(); state.set_class("warrior")
		GameBalance.set_debug_unlock_all_dungeons(true); state.campaign.tutorial_phase = CampaignState.TUTORIAL_COMPLETE; state.campaign.ensure_roster(); state.active_character_id = state.campaign.living_roster()[0].id
		var gear := GearData.create("test","Test Blade",3,false,0,"","Reliable gear.","warrior","none")
		var summary := {"outcome":"victory","headline":"Forest cleared","dungeon":"forest","depth":5,"gold":42,"changes":["+8 Mara Vell Favor"]}
		var gear_list: Array[GearData] = [gear]
		var tavern := TAVERN.instantiate(); tavern.setup(null,state,gear_list,"Welcome home.",summary); root.add_child(tavern)
		await process_frame
		_expect(tavern.backdrop != null and tavern.top_hud != null, "missing backdrop or HUD at %s"%viewport_size,failures)
		_expect(tavern.results_backdrop.visible and tavern.results_text.text.contains("Forest cleared"),"structured results missing at %s"%viewport_size,failures)
		_expect(tavern._grid_center(Vector2i(9,8)).x > 0 and tavern._grid_center(Vector2i(9,8)).x < viewport_size.x,"grid failed responsive centering at %s"%viewport_size,failures)
		var floor_path: Array[Vector2i] = tavern._find_navigation_path(tavern.player_pos,Vector2i(12,7))
		_expect(not floor_path.is_empty() and floor_path[floor_path.size()-1] == Vector2i(12,7),"click navigation could not route across Tavern floor",failures)
		var gate_station: Dictionary = tavern._station_at(Vector2i(11,1)); var gate_approach: Vector2i = tavern._best_station_approach(Vector2i(11,1))
		_expect(not gate_station.is_empty() and gate_approach != Vector2i(-1,-1) and tavern._distance(gate_approach,Vector2i(11,1))==1,"click navigation could not approach expedition gate",failures)
		_expect(tavern.expedition_gate_hit_target!=null and tavern.expedition_gate_hit_target.mouse_default_cursor_shape==Control.CURSOR_POINTING_HAND,"expedition gate mouse hit target missing",failures)
		tavern._on_expedition_gate_clicked();_expect(not tavern.expedition_backdrop.visible,"gate click bypassed modal ownership",failures)
		tavern._close_modal(tavern.results_backdrop);tavern.player_pos=Vector2i(10,1);tavern._on_expedition_gate_clicked();_expect(tavern.expedition_backdrop.visible,"adjacent gate click did not open expedition selector",failures);tavern._close_modal(tavern.expedition_backdrop)
		tavern._open_dungeon_selector()
		_expect(tavern.expedition_panel!=null and tavern.expedition_panel.size.x>=1100,"expedition planner did not expand across the viewport",failures)
		var dungeon_button_count := 0
		for entry in tavern.expedition_list.get_children():
			if entry is Button: dungeon_button_count += 1
		_expect(dungeon_button_count==7,"dungeon selector did not list all demo dungeons",failures)
		_expect(tavern.expedition_list.find_child("ForestDungeonButton",false,false) != null,"Forest selector entry missing",failures)
		_expect(tavern.expedition_list.find_child("AshenFarmsteadDungeonButton",false,false) != null,"Farmstead selector entry missing",failures)
		_expect(tavern.expedition_list.find_child("CryptDungeonButton",false,false) != null,"Crypt selector entry missing",failures)
		var forest_button:=tavern.expedition_list.find_child("ForestDungeonButton",false,false) as Button;var crypt_button:=tavern.expedition_list.find_child("CryptDungeonButton",false,false) as Button
		_expect(forest_button.text.begins_with("▶") and crypt_button.has_meta("base_text"),"destination selection feedback is unclear",failures)
		_expect(tavern.expedition_party_count!=null and tavern.expedition_party_count.text=="2 / 2","expedition planner does not expose its party cap",failures)
		_expect(tavern.expedition_readiness!=null and tavern.expedition_readiness.text.contains("READY") and tavern.expedition_launch.text.contains("Strategy"),"expedition planner lacks a clear launch summary",failures)
		tavern._select_expedition_mode(RunState.PLAY_MODE_SLASHER);_expect(tavern.expedition_readiness.text.contains("Slasher") and tavern.expedition_launch.text.contains("Slasher"),"mode selection did not update the launch summary",failures)
		tavern._close_modal(tavern.expedition_backdrop)
		tavern._open_armory()
		_expect(tavern.armory_backdrop.visible and tavern.armory_list.get_child_count()==1,"armory modal failed",failures)
		tavern._close_modal(tavern.armory_backdrop)
		state.campaign.banked_gold=200;state.campaign.relic_essence=100;state.campaign.successful_levels=50;tavern._open_company_ledger()
		_expect(tavern.company_panel!=null and tavern.company_panel.size.x>=1100,"company ledger did not expand across the viewport",failures)
		_expect(tavern.company_tabs!=null and tavern.company_tabs.get_tab_count()==4,"company ledger must expose four distinct tabs",failures)
		for required_page in ["Resources","Party Builder","Improvements","Memorial"]:_expect(tavern.company_pages.has(required_page),"company ledger missing %s tab"%required_page,failures)
		_expect(tavern.company_pages["Resources"].find_child("UpgradeStartingSuppliesButton",true,false)==null and tavern.company_pages["Improvements"].find_child("PartyRosterGrid",true,false)==null,"ledger tab content leaked between categories",failures)
		var party_grid:=tavern.company_pages["Party Builder"].find_child("PartyRosterGrid",true,false) as GridContainer;var selection_count:=tavern.company_pages["Party Builder"].find_child("PartySelectionCount",true,false) as Label
		_expect(party_grid!=null and party_grid.columns==2 and party_grid.get_child_count()==6,"party builder must show six recruits in a two-column card grid",failures)
		_expect(selection_count!=null and selection_count.text.contains("2 / 2"),"party builder does not explain the Forest party cap",failures)
		var clear_party:=tavern.company_pages["Party Builder"].find_child("ClearPartyButton",true,false) as Button;var auto_fill:=tavern.company_pages["Party Builder"].find_child("AutoFillPartyButton",true,false) as Button
		_expect(clear_party!=null and auto_fill!=null,"party builder is missing clear or auto-fill controls",failures)
		clear_party.pressed.emit();await process_frame;_expect(tavern.selected_party_ids.is_empty(),"Clear Party did not empty the planned party",failures)
		auto_fill=tavern.company_pages["Party Builder"].find_child("AutoFillPartyButton",true,false) as Button;auto_fill.pressed.emit();await process_frame;_expect(tavern.selected_party_ids.size()==2,"Auto Fill did not respect the Forest party cap",failures)
		var first_toggle:=tavern.company_pages["Party Builder"].find_child("%sLedgerPartyToggle"%tavern.selected_party_ids[0],true,false) as CheckButton;_expect(first_toggle!=null and first_toggle.text.begins_with("SLOT 1"),"party builder does not expose party slot order",failures)
		var upgrade_button:=tavern.company_pages["Improvements"].find_child("UpgradeStartingSuppliesButton",true,false) as Button;_expect(upgrade_button!=null and not upgrade_button.disabled and upgrade_button.text=="PURCHASE","improvements tab did not expose an unclipped affordable purchase",failures)
		var old_rank:=int(state.campaign.tavern_upgrades.starting_supplies);upgrade_button.pressed.emit();await process_frame;_expect(int(state.campaign.tavern_upgrades.starting_supplies)==old_rank+1,"company ledger upgrade click failed",failures);_expect(tavern.company_pages["Improvements"].find_child("UpgradeStartingSuppliesButton",true,false)!=null,"company ledger did not safely rebuild after its button signal",failures);tavern._close_modal(tavern.company_backdrop)
		tavern._open_expedition("forest")
		_expect(tavern.expedition_backdrop.visible and not tavern.expedition_launch.disabled,"Forest confirmation failed",failures)
		tavern._close_modal(tavern.expedition_backdrop)
		tavern._open_expedition("crypt")
		_expect(not tavern.expedition_launch.disabled and tavern.expedition_detail.text.contains("Testing unlock active"),"testing unlock did not enable Crypt",failures)
		tavern.free()
	GameBalance.set_debug_unlock_all_dungeons(false)
	for class_id in CLASS_IDS:
		var class_state := RunState.new(); class_state.set_class(class_id)
		var class_gear := GearData.create("test_"+class_id,"Test "+class_id.capitalize(),2,false,0,"","Class gear.",class_id,"none")
		var class_gear_list: Array[GearData] = [class_gear]
		var class_tavern := TAVERN.instantiate(); class_tavern.setup(null,class_state,class_gear_list,""); root.add_child(class_tavern); await process_frame
		class_tavern._open_armory()
		_expect(class_tavern.armory_detail.text.contains(class_state.selected_class_name),"armory omitted %s class identity"%class_id,failures)
		class_tavern.free()
	if failures.is_empty(): print("Player-ready Tavern redesign validation passed."); quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(value: bool,failure: String,failures: Array[String]) -> void:
	if not value: failures.append(failure)
