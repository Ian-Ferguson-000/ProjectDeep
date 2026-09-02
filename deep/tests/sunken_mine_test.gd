extends SceneTree

const MineScene:=preload("res://scenes/mine/SunkenMine.tscn")

func _initialize()->void:call_deferred("_run")

func _run()->void:
	var failures:Array[String]=[];var definition:=GameBalance.get_dungeon("sunken_mine")
	_expect(String(definition.get("runtime",""))=="sunken_mine","Mine does not route to its bespoke Strategy runtime",failures)
	_expect(String(definition.get("slasher_runtime",""))=="sunken_mine","Mine does not route to its bespoke Slasher runtime",failures)
	_expect(String(definition.get("merchant_id",""))=="mine" and int(definition.get("floors",0))==6,"Mine campaign definition is incomplete",failures)
	var campaign:=CampaignState.new();campaign.tutorial_phase=CampaignState.TUTORIAL_COMPLETE;campaign.ensure_roster();campaign.record_dungeon_clear("forest","strategy");campaign.record_dungeon_clear("crypt","strategy")
	var party:=campaign.default_party("sunken_mine");_expect(campaign.begin_expedition(party,"sunken_mine","strategy"),"Mine expedition could not begin after its unlock",failures)
	var state:=RunState.new();state.attach_campaign(campaign);state.active_character_id=party[0];state.start_new_run(null,"sunken_mine","strategy")
	var mine:=MineScene.instantiate();mine.setup(null,state);root.add_child(mine);await process_frame
	_expect(mine.dungeon_id=="sunken_mine" and mine.dungeon_title=="Sunken Mine","Mine scene identity was not applied",failures)
	_expect(mine.floor_cells.size()>0 and not mine.enemies.is_empty(),"Mine did not generate a playable tactical floor",failures)
	_expect(mine.traps.size()>=2 and String(mine.traps[0].get("hazard_kind","")) in ["deep_water","cave_in","ore_machinery"],"Mine hazards are not using bespoke hazard identities",failures)
	mine.free()
	_expect(ResourceLoader.exists("res://scenes/slasher/SlasherMine.tscn") and ResourceLoader.exists("res://scripts/slasher/slasher_mine.gd"),"Mine Slasher runtime assets are missing",failures)
	if failures.is_empty():print("SUNKEN_MINE_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
