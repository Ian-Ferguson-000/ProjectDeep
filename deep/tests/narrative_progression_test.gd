extends SceneTree

const PROGRESSION:=preload("res://scripts/game/narrative_progression.gd")

func _initialize()->void:
	var failures:Array[String]=[];var campaign:=CampaignState.new()
	_expect(PROGRESSION.validate().is_empty(),"Codex or ending data did not validate.",failures)
	campaign.keeper_memory={"loop_number":1,"discoveries":["briarway_approach","suppressed_balors_hell","witnessed_hearth_fall_1"],"remembered_people":[]};campaign.clues={"abyssal_crypt":true,"abyssal_foundry":true};campaign.contribution=500
	var entries:=PROGRESSION.unlocked_codex(campaign)
	_expect(entries.size()>=3,"Keeper evidence did not unlock codex records across loops.",failures)
	var covenant:=PROGRESSION.ending_status(campaign,"keeper_covenant")
	_expect(bool(covenant.eligible),"Documented evidence did not unlock the Keeper's Covenant ending.",failures)
	var compact:=PROGRESSION.ending_status(campaign,"mortal_compact")
	_expect(not bool(compact.eligible) and not Array(compact.missing).is_empty(),"Ending prerequisites do not keep distinct ending families gated.",failures)
	var chosen:=PROGRESSION.choose_ending(campaign,"keeper_covenant")
	_expect(bool(chosen.ok) and String(campaign.ending_state.ending_id)=="keeper_covenant" and campaign.pending_story_event_id=="ending_keeper_covenant" and StoryEventService.lines(campaign.pending_story_event_id,campaign).size()==3,"Eligible ending choice or authored closing scene was not recorded.",failures)
	var snapshot:=campaign.to_dict();var loaded:=CampaignState.new();loaded._load_dict(snapshot)
	_expect(loaded.ending_state==campaign.ending_state,"Ending state did not round trip through saves.",failures)
	var migrated:=CampaignState._migrate_dict({"version":13})
	_expect(int(migrated.version)==CampaignState.SAVE_VERSION and Dictionary(migrated.ending_state).is_empty(),"Version 13 ending-state migration is unsafe.",failures)
	if failures.is_empty():print("NARRATIVE_PROGRESSION_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
