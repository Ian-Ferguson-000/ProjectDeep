extends SceneTree

func _initialize()->void:call_deferred("_run")

func _run()->void:
	var failures:Array[String]=[]
	_expect(GameBalance.get_base_classes().size()==6,"Demo must contain exactly six playable classes",failures)
	_expect(GameBalance.get_dungeons().size()==7 and GameBalance.get_dungeon_order().size()==7,"Demo must contain five regular and two secret dungeons",failures)
	_expect(GameBalance.get_merchants().size()==6,"Demo must contain exactly six merchants",failures)
	for dungeon_id in GameBalance.get_dungeon_order():
		var definition:=GameBalance.get_dungeon(String(dungeon_id));_expect(Array(definition.get("supported_modes",[])).has("strategy") and Array(definition.get("supported_modes",[])).has("slasher"),"%s does not support both modes"%dungeon_id,failures);_expect(not String(definition.get("runtime","")).is_empty() and not String(definition.get("slasher_runtime","")).is_empty(),"%s runtime routing is incomplete"%dungeon_id,failures)
	for class_id in GameBalance.get_base_classes().keys():
		for variant in range(4):_expect(ResourceLoader.exists("res://assets/roster_portraits/%s_%d.png"%[class_id,variant]),"Missing %s roster portrait variant %d"%[class_id,variant],failures)
	var campaign:=CampaignState.new();campaign.tutorial_phase=CampaignState.TUTORIAL_COMPLETE;campaign.ensure_roster();_expect(campaign.living_roster().size()==6,"Initial company roster is not six",failures)
	var forest_party:=campaign.default_party("forest");campaign.begin_expedition(forest_party,"forest","strategy");campaign.record_casualty(forest_party[0],"Acceptance-test casualty");campaign.expedition.carried_gold=80;campaign.expedition.carried_relic_essence=20;campaign.resolve_expedition("extract");_expect(campaign.memorial.size()==1 and campaign.living_roster().size()==6 and campaign.banked_gold==80,"Partial casualty, extraction, or replacement resolution failed",failures)
	campaign.successful_levels=20;var upgrade_result:=campaign.purchase_upgrade("starting_supplies");_expect(int(campaign.tavern_upgrades.starting_supplies)==1 and upgrade_result[0].contains("rank 1"),"Tavern meta-upgrade could not be purchased",failures)
	campaign.record_dungeon_clear("forest","strategy");campaign.record_dungeon_clear("forest","slasher");campaign.record_dungeon_clear("ashen_farmstead","strategy");campaign.record_dungeon_clear("crypt","slasher");campaign.record_dungeon_clear("sunken_mine","strategy");campaign.record_dungeon_clear("ember_foundry","slasher");_expect(campaign.unlocked_classes.size()==6,"All six classes did not unlock through the campaign graph",failures)
	campaign.tavern_upgrades.secret_research=1;_expect(campaign.can_unlock_secret("moonlit_grove") and campaign.can_unlock_secret("abyssal_archive"),"Secret clue/research chains did not reveal both dungeons",failures)
	for secret_id in ["moonlit_grove","abyssal_archive"]:
		var party:=campaign.default_party(secret_id);campaign.begin_expedition(party,secret_id,"strategy");campaign.record_dungeon_clear(secret_id,"strategy");campaign.resolve_expedition("victory")
	_expect(campaign.banked_relics.has("nature_relic") and campaign.banked_relics.has("fate_relic") and campaign.banked_relics.has("arcane_relic") and campaign.banked_relics.has("void_relic"),"Secret relic rewards were not banked",failures)
	for dungeon_id in GameBalance.get_dungeon_order():_expect(campaign.has_completed_dungeon(String(dungeon_id)),"%s lacks completion credit"%dungeon_id,failures)
	var round_trip:=CampaignState.new();round_trip._load_dict(CampaignState._migrate_dict(campaign.to_dict()));_expect(round_trip.completed_dungeon_modes.size()==7 and round_trip.banked_relics.size()==4 and round_trip.memorial.size()==1,"Final campaign save round trip lost progression",failures)
	if failures.is_empty():print("DEMO_ACCEPTANCE_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
