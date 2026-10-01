extends SceneTree

const ARRIVALS:=preload("res://scripts/game/nation_arrival_service.gd")

func _initialize()->void:
	var failures:Array[String]=[];var campaign:=CampaignState.new();campaign.apply_post_tutorial_state("victory")
	_expect(ARRIVALS.validate().is_empty(),"Nation arrival data did not validate.",failures)
	var expected:Array[Dictionary]=[
		{"dungeon":"forest","definition":"tank_ulric","nation":"helvetica","node":"helvetica_arrival"},
		{"dungeon":"ashen_farmstead","definition":"healer_rhea","nation":"verdant_concord","node":"concord_arrival"},
		{"dungeon":"crypt","definition":"rogue_tamsin","nation":"veiled_isles","node":"isles_arrival"},
		{"dungeon":"balors_hell","definition":"mage_nessa","nation":"sun_crowned_dominion","node":"dominion_arrival"}
	]
	var dialogue:=TavernDialogueService.new();var introduced:Dictionary={"nordia":true,"zarabia":true}
	for milestone in expected:
		campaign.record_dungeon_clear(String(milestone.dungeon));campaign._generate_candidate_wave(false)
		var featured:CandidateRecord=null
		for candidate in campaign.get_candidates():
			if candidate.adventurer.definition_id==String(milestone.definition):featured=candidate;break
		_expect(featured!=null,"Milestone %s did not produce its authored arrival."%milestone.dungeon,failures)
		if featured!=null:
			introduced[featured.adventurer.nation_id]=true
			var conversation:=dialogue.play("candidate_default",{"campaign":campaign,"candidate":featured})
			_expect(featured.adventurer.nation_id==String(milestone.nation) and String(conversation.node_id)==String(milestone.node),"Authored arrival identity or dispute dialogue is incorrect for %s."%milestone.definition,failures)
	_expect(introduced.size()==6,"The founding and milestone arrivals do not introduce all six nations.",failures)
	var reserved:=ARRIVALS.reserved_definition_ids();_expect(reserved.size()==4 and reserved.has("tank_ulric") and reserved.has("mage_nessa"),"Featured arrivals are not reserved from random recruitment.",failures)
	var generic_member:=campaign._generate_character("tank")
	_expect(not reserved.has(generic_member.definition_id),"Random recruitment consumed a reserved nation introduction.",failures)
	var loop_condition:={"loop_gte":1};var evidence_condition:={"evidence":"evidence_ashen_farmstead"};campaign.keeper_memory.loop_number=1;campaign.clues["evidence_ashen_farmstead"]=true
	_expect(dialogue.evaluate_condition(loop_condition,{"campaign":campaign}) and dialogue.evaluate_condition(evidence_condition,{"campaign":campaign}),"Expanded loop/evidence dialogue conditions do not evaluate.",failures)
	campaign.used_curated_ids.clear();campaign.candidate_pool.clear();campaign._generate_candidate_wave(false);var remembered:CandidateRecord=null
	for candidate in campaign.get_candidates():if candidate.adventurer.definition_id=="tank_ulric":remembered=candidate;break
	_expect(remembered!=null and String(dialogue.play("candidate_default",{"campaign":campaign,"candidate":remembered}).node_id)=="remembered_arrival","Milestone characters do not return with loop-aware dialogue.",failures)
	if failures.is_empty():print("NATION_ARRIVALS_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
