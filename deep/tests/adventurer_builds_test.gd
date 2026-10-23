extends SceneTree

func _initialize()->void:call_deferred("_run")
func _run()->void:
	var failures:Array[String]=[]
	_expect(AdventurerBuilds.validate().is_empty(),"Stat build data is invalid: %s"%", ".join(AdventurerBuilds.validate()),failures)

	# Arrivals get varied, class-independent stat blocks.
	var campaign:=CampaignState.new();campaign.apply_post_tutorial_state("victory")
	campaign.unlocked_classes.assign(["warrior","mage","healer","tank","rogue","summoner"])
	var blocks:={};var builds:={};var count:=0;var off_calling:=0
	for wave in 10:
		campaign._generate_candidate_wave(false)
		for candidate in campaign.get_candidates():
			var member:=candidate.adventurer;count+=1
			_expect(not AdventurerBuilds.build(member.stat_build_id).is_empty(),"%s arrived without a stat build"%member.display_name,failures)
			_expect(member.attributes.size()==6 and member.attributes.values().all(func(value):return int(value)>=4 and int(value)<=20),"%s has an out-of-range stat block"%member.display_name,failures)
			_expect(member.calling_class_id==member.class_id,"Candidates should arrive in their calling class",failures)
			blocks[str(member.attributes)]=true;builds[member.stat_build_id]=true
			if AdventurerBuilds.ranked_classes(member.attributes,campaign.unlocked_classes)[0]!=member.calling_class_id:off_calling+=1
	_expect(blocks.size()>=int(count*0.9),"Stat blocks are not varied enough (%d unique of %d)"%[blocks.size(),count],failures)
	_expect(builds.size()>=8,"Too few stat builds appeared (%d)"%builds.size(),failures)
	_expect(off_calling>0,"No arrival was better suited to another class; assignment would never matter",failures)

	# Founders keep builds that suit their story.
	campaign=CampaignState.new();campaign.apply_post_tutorial_state("victory")
	var brina:CandidateRecord;var eamon:CandidateRecord
	for candidate in campaign.get_candidates():
		if candidate.adventurer.definition_id=="brina_founder":brina=candidate
		if candidate.adventurer.definition_id=="eamon_founder":eamon=candidate
	_expect(Array(AdventurerBuilds.build(brina.adventurer.stat_build_id).callings).has("warrior"),"Brina's build does not suit a warrior",failures)
	_expect(Array(AdventurerBuilds.build(eamon.adventurer.stat_build_id).callings).has("mage"),"Eamon's build does not suit a mage",failures)

	# The keeper chooses the class at recruitment, limited to unlocked classes.
	var locked:=campaign.recruit_candidate(brina.id,"summoner")
	_expect(not bool(locked.ok) and campaign.candidate_pool.has(brina.id),"A locked class could be assigned",failures)
	var signed:=campaign.recruit_candidate(eamon.id,"warrior");var eamon_member:=campaign.character(eamon.id)
	_expect(bool(signed.ok) and eamon_member.class_id=="warrior" and eamon_member.calling_class_id=="mage","Recruiting did not assign the chosen class",failures)
	_expect(eamon_member.gear_id=="sword_shield" and campaign.armory.has(String(eamon_member.equipment.get("weapon",""))),"Chosen class did not receive its starter weapon",failures)
	_expect(eamon_member.max_health==AdventurerBuilds.max_health_for("warrior",eamon_member.level,eamon_member.attributes),"Health was not recalculated for the chosen class",failures)
	campaign.recruit_candidate(brina.id);var brina_member:=campaign.character(brina.id)
	_expect(brina_member.class_id=="warrior","Recruiting without a choice should keep the calling",failures)

	# Retraining keeps level and stats, swaps class gear, and clears class-bound choices.
	var old_weapon:=String(brina_member.equipment.weapon);var stats_before:=brina_member.attributes.duplicate(true);var level_before:=brina_member.level
	brina_member.progression["evolution_path"]=["warrior_upgrade"];brina_member.progression["slasher_upgrades"]=["warrior_slasher"]
	_expect(not bool(campaign.reassign_class(brina.id,"warrior").ok),"Retraining into the current class succeeded",failures)
	_expect(not bool(campaign.reassign_class(brina.id,"rogue").ok),"Retraining into a locked class succeeded",failures)
	var retrained:=campaign.reassign_class(brina.id,"mage")
	_expect(bool(retrained.ok) and brina_member.class_id=="mage" and brina_member.calling_class_id=="warrior","Retraining did not change class",failures)
	_expect(brina_member.level==level_before and brina_member.attributes==stats_before,"Retraining changed level or attributes",failures)
	_expect(not campaign.armory.has(old_weapon) and brina_member.gear_id=="magic_missile_shield","Retraining did not swap the bound starter weapon",failures)
	_expect(Array(brina_member.progression.evolution_path).is_empty() and Array(brina_member.progression.slasher_upgrades).is_empty(),"Class-bound upgrade choices survived retraining",failures)
	_expect(brina_member.max_health==AdventurerBuilds.max_health_for("mage",brina_member.level,brina_member.attributes),"Retraining did not recalculate health",failures)

	# Saves keep builds and callings; old saves fall back to calling = class.
	var restored:=CampaignState.new();restored._load_dict(campaign.to_dict());var restored_brina:=restored.character(brina.id)
	_expect(restored_brina.stat_build_id==brina_member.stat_build_id and restored_brina.calling_class_id=="warrior" and restored_brina.class_id=="mage","Build or calling lost on save/load",failures)
	var legacy:=brina_member.to_dict();legacy.erase("stat_build_id");legacy.erase("calling_class_id")
	var legacy_member:=CharacterRecord.from_dict(legacy)
	_expect(legacy_member.calling_class_id==legacy_member.class_id and legacy_member.stat_build_id.is_empty(),"Legacy characters did not load safely",failures)

	# Expeditions run the reassigned class, and retraining is blocked while away.
	var launch:=campaign.launch_expedition([brina.id,eamon.id],"forest")
	_expect(bool(launch.ok),"Expedition with reassigned classes failed to launch: %s"%String(launch.get("error","")),failures)
	var runtime:=RunState.new();runtime.attach_campaign(campaign);runtime.active_character_id=brina.id;runtime.start_new_run(null,"forest")
	_expect(runtime.selected_class_id=="mage" and String(runtime.hero_profiles[brina.id].class_id)=="mage","Runtime did not use the reassigned class",failures)
	_expect(not bool(campaign.reassign_class(eamon.id,"mage").ok),"An adventurer retrained while on an expedition",failures)

	if failures.is_empty():print("ADVENTURER_BUILDS_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)
func _expect(value:bool,message:String,failures:Array[String])->void:
	if not value:failures.append(message)
