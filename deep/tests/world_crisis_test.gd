extends SceneTree

const CRISIS:=preload("res://scripts/game/world_crisis.gd")
const STORY:=preload("res://scripts/game/story_event_service.gd")

func _initialize()->void:
	var failures:Array[String]=[];var staged:=CampaignState.new();staged.apply_post_tutorial_state("victory");staged.calendar_day=71;CRISIS.ensure(staged);staged.world_crisis.level=29;staged.world_crisis.war_stage="border_tension";CRISIS.advance(staged)
	_expect(staged.pending_story_event_id=="crisis_open_war" and STORY.lines(staged.pending_story_event_id,staged).size()==2,"Open war did not queue its authored Hearth scene.",failures)
	var staged_copy:=CampaignState.new();staged_copy._load_dict(staged.to_dict());_expect(staged_copy.pending_story_event_id=="crisis_open_war","Queued crisis story did not survive save/load.",failures)
	var campaign:=CampaignState.new();campaign.apply_post_tutorial_state("victory");campaign.first_company_recruited=true
	var alden:=campaign.create_tutorial_adventurer();campaign.completed_dungeons["forest"]=true;campaign.contribution=140;campaign.reputation=25
	CRISIS.ensure(campaign);campaign.world_crisis.level=100;campaign.world_crisis.hearth_integrity=5
	for ecology_id in campaign.dungeon_ecology:
		var state:=Dictionary(campaign.dungeon_ecology[ecology_id]);state.outbreak=true;state.pressure=100.0;campaign.dungeon_ecology[ecology_id]=state
	var advance:=HearthCalendar.advance(campaign,1,false)
	_expect(bool(advance.ok) and int(campaign.keeper_memory.loop_number)==1,"Hearth destruction did not begin a new loop.",failures)
	_expect(campaign.calendar_day==1 and campaign.tutorial_phase==CampaignState.TUTORIAL_NEW and campaign.roster.is_empty(),"Physical campaign state was not reset after the Hearth fell.",failures)
	_expect(Array(campaign.keeper_memory.remembered_people).has(alden.id) and Array(campaign.keeper_memory.discoveries).has("suppressed_forest") and int(Dictionary(campaign.keeper_memory.last_inheritance).contribution)==140,"Keeper Memory did not inherit people, discoveries, and the prior record.",failures)
	_expect(campaign.banked_gold==0 and campaign.divine_favor.is_empty() and campaign.active_boons.is_empty(),"Physical wealth or divine bargains leaked across loops.",failures)
	var prepared_alden:=campaign.create_tutorial_adventurer();_expect(prepared_alden.max_health==CampaignState.TUTORIAL_STARTING_HEALTH+2 and not prepared_alden.accomplishments.is_empty(),"Keeper foreknowledge does not materially improve Alden's repeated start.",failures)
	var repeated:=STORY.lines("remembered_last_customer",campaign)
	_expect(repeated.size()==3 and String(repeated[0].text).contains("Hearth fell") and String(repeated[2].text).contains("This time"),"The first repeated Alden scene does not acknowledge Keeper foreknowledge.",failures)
	var snapshot:=campaign.to_dict();var loaded:=CampaignState.new();loaded._load_dict(snapshot)
	_expect(loaded.world_crisis==campaign.world_crisis and int(loaded.keeper_memory.loop_number)==1,"Crisis and loop state did not round trip.",failures)
	var migrated:=CampaignState._migrate_dict({"version":12,"keeper_memory":{"loop_number":2,"discoveries":[],"remembered_people":[]}})
	_expect(int(migrated.version)==CampaignState.SAVE_VERSION and Dictionary(migrated.world_crisis).is_empty(),"Version 12 crisis migration is unsafe.",failures)
	if failures.is_empty():print("WORLD_CRISIS_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
