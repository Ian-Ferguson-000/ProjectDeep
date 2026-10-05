extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var tutorial_campaign:=CampaignState.new();var tutorial_starter:=tutorial_campaign.create_character("warrior");_expect(tutorial_campaign.begin_expedition([tutorial_starter.id], "forest", true),"tutorial expedition did not begin",failures)
	var tutorial_run:=RunState.new();tutorial_run.attach_campaign(tutorial_campaign);tutorial_run.active_character_id=tutorial_starter.id;tutorial_run.start_new_run(null, "forest")
	_expect(tutorial_run.max_health==3 and tutorial_run.current_health==3 and tutorial_starter.max_health==3 and tutorial_starter.current_health==3,"tutorial starter health was not capped at 3",failures)
	tutorial_run.finish_run("victory", "Tutorial clear")
	tutorial_campaign.tutorial_phase=CampaignState.TUTORIAL_COMPLETE;tutorial_campaign.ensure_roster(); tutorial_campaign.first_company_recruited = true;tutorial_run.restore_completed_tutorial_health()
	_expect(tutorial_starter.max_health>3 and tutorial_starter.current_health==tutorial_starter.max_health,"tutorial survivor retained the temporary health cap",failures)
	var campaign := CampaignState.new(); campaign.tutorial_phase = CampaignState.TUTORIAL_COMPLETE; campaign.ensure_roster(); campaign.first_company_recruited = true
	_expect(campaign.living_roster().size()==2,"campaign did not generate the two-recruit starting company",failures)
	_expect(campaign.unlocked_classes==["warrior","mage"],"starter replacement pool is incorrect",failures)
	var forest_party := campaign.default_party("forest"); _expect(forest_party.size()==2,"Forest party cap is not two",failures)
	_expect(campaign.begin_expedition(forest_party, "forest"),"Forest expedition did not begin",failures)
	var checkpoint_state:=RunState.new();checkpoint_state.attach_campaign(campaign);checkpoint_state.active_character_id=forest_party[0];checkpoint_state.active_dungeon_id="forest";checkpoint_state.current_floor=1;checkpoint_state.record_floor_checkpoint();checkpoint_state.record_floor_checkpoint();_expect(campaign.expedition.carried_relic_essence==1 and not checkpoint_state.can_extract(),"cleared checkpoint did not grant one-time essence while keeping extraction disabled",failures)
	var fallen := forest_party[0]; campaign.record_casualty(fallen,"test casualty")
	_expect(campaign.expedition.living_party_ids().size()==1,"surviving party could not continue shorthanded",failures)
	campaign.expedition.carried_gold=31;campaign.expedition.carried_relic_essence=4;campaign.resolve_expedition("victory")
	_expect(campaign.banked_gold==31 and campaign.relic_essence==4,"boss victory did not bank provisional loot",failures)
	_expect(campaign.living_roster().size()==1 and campaign.memorial.size()==1 and campaign.retired_heroes.is_empty() and campaign.candidate_pool.size()>=1,"casualty, returning survivor, or replacement wave failed",failures)
	campaign.record_dungeon_clear("forest");_expect(campaign.unlocked_classes.has("tank") and campaign.unlocked_classes.has("rogue"),"A Forest clear did not unlock both Tank and Rogue",failures)
	campaign.record_dungeon_clear("ashen_farmstead");campaign.record_dungeon_clear("crypt")
	_expect(campaign.unlocked_classes.has("healer") and campaign.unlocked_classes.has("summoner"),"later class unlocks failed",failures)
	campaign.tavern_upgrades["secret_research"]=1;campaign.record_dungeon_clear("ember_foundry")
	_expect(campaign.can_unlock_secret("moonlit_grove") and campaign.can_unlock_secret("abyssal_archive"),"secret clue chains failed",failures)
	HearthCalendar.advance(campaign,1,false)
	for candidate in campaign.get_candidates():campaign.recruit_candidate(candidate.id)
	var secret_party:=campaign.default_party("moonlit_grove");campaign.begin_expedition(secret_party, "moonlit_grove");campaign.record_dungeon_clear("moonlit_grove");campaign.resolve_expedition("victory")
	_expect(campaign.banked_relics.has("nature_relic") and campaign.banked_relics.has("fate_relic"),"secret unique relics were not banked",failures)
	var encoded:=campaign.to_dict();var restored:=CampaignState.new();restored._load_dict(encoded)
	_expect(restored.memorial.size()==1 and restored.living_roster().size()>=1 and restored.banked_relics.has("nature_relic"),"campaign serialization round trip failed",failures)
	var migrated:=CampaignState._migrate_dict({"version":0,"selected_class_id":"phantom","forest_cleared":true,"completed_runs":2});var migrated_campaign:=CampaignState.new();migrated_campaign._load_dict(migrated);_expect(int(migrated.version)==CampaignState.SAVE_VERSION and migrated_campaign.has_completed_dungeon("forest") and migrated_campaign.unlocked_classes.has("mage"),"legacy class-based campaign migration failed",failures)
	restored.banked_gold=100;restored.relic_essence=50;restored.successful_levels=20;var upgrade_logs:=restored.purchase_upgrade("secret_research");_expect(int(restored.tavern_upgrades.secret_research)==2 and upgrade_logs[0].contains("rank 2"),"tavern upgrade purchase failed",failures)
	restored.tavern_upgrades.replacement_quality=2;var improved:=restored.create_character("warrior");_expect(improved.level==3,"replacement quality did not improve arriving recruit level",failures);_expect(improved.max_health>3 and improved.current_health==improved.max_health,"replacement recruit spawned with placeholder health",failures)
	var upgraded_run:=RunState.new();restored.tavern_upgrades.starting_supplies=2;restored.tavern_upgrades.roster_services=1;upgraded_run.attach_campaign(restored);upgraded_run.start_new_run(null, "forest");_expect(upgraded_run.get_consumables().count("healing_potion")>=2 and upgraded_run.keys>=1 and upgraded_run.get_consumable_capacity()>GameBalance.get_consumable_base_capacity(),"starting supply or roster-service upgrade has no gameplay effect",failures)
	if failures.is_empty():print("CAMPAIGN_LOOP_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
