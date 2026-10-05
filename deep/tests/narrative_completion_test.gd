extends SceneTree

const OBJECTIVES:=preload("res://scripts/game/dungeon_objective_service.gd")
const ARRIVALS:=preload("res://scripts/game/nation_arrival_service.gd")
const DIVINE:=preload("res://scripts/game/divine_favor_service.gd")
const PROGRESSION:=preload("res://scripts/game/narrative_progression.gd")
const EVENTS:=preload("res://scripts/game/story_event_service.gd")

func _initialize()->void:
	var failures:Array[String]=[]
	for path in ["res://docs/story/NarrativeVision.md","res://docs/story/CampaignArcPlan.md","res://docs/story/NarrativeAdaptationRoadmap.md","res://docs/story/CoreCastBriefs.md","res://docs/story/NationAndCultureGuide.md","res://docs/story/CosmologySecret.md"]:_expect(FileAccess.file_exists(path),"Missing canon document: %s"%path,failures)
	var nations:=NarrativeContent.nations();var canonical:=0
	for nation_id in nations:
		if nation_id=="crossroads":continue
		if String(Dictionary(nations[nation_id]).get("status",""))=="current_canon":canonical+=1
	_expect(canonical==6,"The six nations are not all marked as current canon.",failures)
	_expect(NarrativeContent.next_route_stage("forest")=="crypt" and NarrativeContent.next_route_stage("crypt")=="balors_hell","Balor route is incomplete.",failures)
	_expect(NarrativeContent.next_route_stage("ashen_farmstead")=="sunken_mine" and NarrativeContent.next_route_stage("sunken_mine")=="ember_foundry","Adragor Cinderway is incomplete.",failures)
	var foundry_objectives:=OBJECTIVES.objective_ids("ember_foundry")
	_expect(["suppress","rebind","recover_evidence","negotiate"].all(func(id:String):return foundry_objectives.has(id)),"The second route does not support all four resolution families.",failures)
	_expect(ARRIVALS.validate().is_empty() and ARRIVALS.reserved_definition_ids().size()==4,"Authored arrivals do not complete the six-nation introduction.",failures)
	var identity_campaign:=CampaignState.new();var fara:=identity_campaign._character_from_definition(AdventurerContent.definition("healer_fara"));var rhea:=identity_campaign._character_from_definition(AdventurerContent.definition("summoner_rhea"))
	_expect(fara.faith_id==rhea.faith_id and fara.nation_id!=rhea.nation_id,"Faith remains nationalized in authored characters.",failures)
	_expect(DIVINE.validate().is_empty() and DIVINE.deities().size()==12,"Pantheons are incomplete.",failures)
	var blank:=CampaignState.new()
	for event_id in ["last_customer_opening","remembered_last_customer","crisis_open_war","crisis_fracture","crisis_last_siege"]:_expect(not EVENTS.lines(event_id,blank).is_empty(),"Missing campaign story event: %s"%event_id,failures)
	_expect(PROGRESSION.validate().is_empty() and PROGRESSION.endings().size()==4,"Ending families are incomplete.",failures)
	for ending_id in PROGRESSION.endings():_expect(EVENTS.lines("ending_%s"%ending_id,blank).size()>=2,"Ending %s has no authored presentation."%ending_id,failures)
	_expect(CampaignState.SAVE_VERSION==16,"Narrative completion contract expects save version 16.",failures)
	if failures.is_empty():print("NARRATIVE_COMPLETION_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
