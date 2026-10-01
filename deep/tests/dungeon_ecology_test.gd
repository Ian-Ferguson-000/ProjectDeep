extends SceneTree

const ECOLOGY:=preload("res://scripts/game/dungeon_ecology.gd")

func _initialize()->void:
	var failures:Array[String]=[]
	var campaign:=CampaignState.new();campaign.apply_post_tutorial_state("victory")
	var forest:=ECOLOGY.state(campaign,"forest");var crypt:=ECOLOGY.state(campaign,"crypt")
	_expect(forest==crypt and not forest.is_empty(),"Connected Balor route does not share one ecology.",failures)
	var initial_pressure:=float(forest.pressure);ECOLOGY.advance_to_day(campaign,campaign.calendar_day+4)
	_expect(float(ECOLOGY.state(campaign,"forest").pressure)>initial_pressure,"Dungeon pressure did not recover with time.",failures)
	var approach_logs:=ECOLOGY.record_progress(campaign,"forest");var after_approach:=ECOLOGY.state(campaign,"forest")
	_expect(not approach_logs.is_empty() and int(after_approach.suppression_count)==0 and float(after_approach.pressure)<initial_pressure+6.1,"Approach clear incorrectly suppressed the prisoner.",failures)
	ECOLOGY.record_progress(campaign,"crypt");ECOLOGY.record_progress(campaign,"balors_hell");var suppressed:=ECOLOGY.state(campaign,"balors_hell")
	_expect(roundi(float(suppressed.pressure))==15 and roundi(float(suppressed.resources))==35 and roundi(float(suppressed.stability))==85 and int(suppressed.suppression_count)==1,"Balor clear did not suppress the shared prison ecology.",failures)
	var snapshot:=campaign.to_dict();var restored:=CampaignState.new();restored._load_dict(snapshot)
	_expect(ECOLOGY.state(restored,"balors_hell")==suppressed,"Dungeon ecology did not round trip through the campaign save.",failures)
	for candidate in restored.get_candidates():restored.recruit_candidate(candidate.id)
	var balor_state:=ECOLOGY.state(restored,"balors_hell");balor_state.pressure=99.0;balor_state.stability=1.0;balor_state.last_day=restored.calendar_day;restored.dungeon_ecology["balor_prison"]=balor_state
	var advance:=HearthCalendar.advance(restored,1,false)
	_expect(bool(ECOLOGY.state(restored,"forest").outbreak) and Array(advance.events).any(func(event):return String(event).contains("breached containment")),"Calendar advancement did not surface the outbreak.",failures)
	var low_id:=ECOLOGY.ecology_id("ashen_farmstead");var low:=ECOLOGY.state(restored,"ashen_farmstead");low.pressure=0.0;low.resources=0.0;restored.dungeon_ecology[low_id]=low
	var low_threat:=ECOLOGY.threat_multiplier(restored,"ashen_farmstead");var low_reward:=ECOLOGY.reward_multiplier(restored,"ashen_farmstead")
	low.pressure=100.0;low.resources=100.0;restored.dungeon_ecology[low_id]=low
	_expect(ECOLOGY.threat_multiplier(restored,"ashen_farmstead")>low_threat and ECOLOGY.reward_multiplier(restored,"ashen_farmstead")>low_reward,"Pressure and resources do not affect risk/reward multipliers.",failures)
	if failures.is_empty():print("DUNGEON_ECOLOGY_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
