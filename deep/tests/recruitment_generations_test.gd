extends SceneTree

func _initialize()->void:call_deferred("_run")
func _run()->void:
	var failures:Array[String]=[]
	_expect(AdventurerContent.validate().is_empty(),"Adventurer content validation failed: %s"%", ".join(AdventurerContent.validate()),failures)
	_expect(AdventurerContent.curated().size()>=24,"Curated adventurer pool is not robust enough",failures)
	var campaign:=CampaignState.new();campaign.apply_post_tutorial_state("victory");var candidate:=campaign.get_candidates()[0];var original_gold:=campaign.banked_gold
	_expect(candidate.adventurer.biography.length()>40 and candidate.adventurer.attributes.size()==6,"Founding candidate lacks biography or attributes",failures)
	var observed:=campaign.inspect_candidate(candidate.id,"observe");var repeat:=campaign.inspect_candidate(candidate.id,"observe");_expect(bool(observed.ok) and bool(repeat.duplicate) and candidate.knowledge.equipment=="exact","Observation was not persistent and idempotent",failures)
	var talked:=campaign.inspect_candidate(candidate.id,"talk");_expect(bool(talked.ok) and candidate.knowledge.biography=="exact","Conversation did not reveal biography",failures)
	var appraisal:=campaign.appraise_candidate(candidate.id,"str");_expect(bool(appraisal.ok) and campaign.banked_gold==original_gold-12 and candidate.knowledge.str=="exact","Appraisal did not charge once and reveal exactly",failures)
	var appraisal_repeat:=campaign.appraise_candidate(candidate.id,"str");_expect(not bool(appraisal_repeat.ok) and campaign.banked_gold==original_gold-12,"Repeated appraisal charged or succeeded",failures)
	var trial:=campaign.run_candidate_trial(candidate.id);var gold_after_trial:=campaign.banked_gold;var trial_repeat:=campaign.run_candidate_trial(candidate.id);_expect(bool(trial.ok) and bool(trial_repeat.duplicate) and campaign.banked_gold==gold_after_trial,"Trial was not deterministic and idempotent",failures)
	var snapshot:=campaign.to_dict();var restored:=CampaignState.new();restored._load_dict(snapshot);var restored_candidate:=restored.candidate_pool.get(candidate.id) as CandidateRecord;_expect(restored_candidate!=null and restored_candidate.adventurer.biography==candidate.adventurer.biography and restored_candidate.knowledge==candidate.knowledge,"Candidate dossier rerolled after save/load",failures)
	for value in campaign.get_candidates():campaign.recruit_candidate(value.id)
	var party:=campaign.default_party("forest");var veteran:=campaign.character(party[0]);veteran.career_limit=1;var launch:=campaign.launch_expedition([veteran.id],"forest","strategy");var runtime:=RunState.new();runtime.attach_campaign(campaign);runtime.active_character_id=veteran.id;runtime.start_new_run(null,"forest","strategy");_expect(Dictionary(runtime.hero_profiles[veteran.class_id].base_stats)==veteran.attributes,"Saved adventurer attributes did not hydrate the runtime profile",failures);campaign.settle_expedition(int(launch.expedition_id),"victory",{"headline":"Career victory"})
	_expect(campaign.calendar_day==8 and campaign.character(veteran.id)==null and campaign.retired_heroes.size()==1,"Weekly settlement or automatic career retirement failed",failures)
	campaign.calendar_day=int(campaign.retired_heroes[0].retired_day)+112
	for attempt in 4:
		campaign._generate_candidate_wave(false)
		if campaign.get_candidates().any(func(value:CandidateRecord):return not value.adventurer.parent_id.is_empty()):break
	var descendants:Array[CandidateRecord]=campaign.get_candidates().filter(func(value:CandidateRecord):return not value.adventurer.parent_id.is_empty())
	_expect(descendants.size()==1 and descendants[0].adventurer.generation==2 and descendants[0].adventurer.family_name==veteran.family_name,"Guaranteed bounded descendant generation failed",failures)
	if not descendants.is_empty():var child:=descendants[0].adventurer;var parent_stats:Dictionary=Dictionary(campaign.retired_heroes[0].attributes);_expect(child.attributes!=parent_stats,"Descendant received automatic inherited power",failures)
	if failures.is_empty():print("RECRUITMENT_GENERATIONS_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)
func _expect(value:bool,message:String,failures:Array[String])->void:
	if not value:failures.append(message)
