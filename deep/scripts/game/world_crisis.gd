extends RefCounted
class_name WorldCrisis

static func defaults(day:int=1)->Dictionary:
	return {"level":0,"outbreaks":0,"war_stage":"border_tension","refugees":0,"hearth_integrity":100,"collapsed":false,"last_day":day}

static func ensure(campaign)->void:
	if campaign.world_crisis.is_empty(): campaign.world_crisis=defaults(campaign.calendar_day)
	for key in defaults(campaign.calendar_day):
		if not campaign.world_crisis.has(key): campaign.world_crisis[key]=defaults(campaign.calendar_day)[key]

static func advance(campaign)->Array[String]:
	ensure(campaign);var events:Array[String]=[];var outbreak_count:=0;var unstable_count:=0
	if not campaign.ending_state.is_empty():return events
	for state_value in campaign.dungeon_ecology.values():
		var state:=Dictionary(state_value)
		if bool(state.get("outbreak",false)):outbreak_count+=1
		if float(state.get("stability",100))<=20.0:unstable_count+=1
	var old_level:=int(campaign.world_crisis.level)
	var level:=clampi(int((campaign.calendar_day-1)/7)*3+outbreak_count*18+unstable_count*4,0,100)
	campaign.world_crisis.level=maxi(old_level,level);campaign.world_crisis.outbreaks=outbreak_count;campaign.world_crisis.refugees=maxi(int(campaign.world_crisis.refugees),outbreak_count*12+int(campaign.world_crisis.level/5))
	var stage:="border_tension" if int(campaign.world_crisis.level)<30 else ("open_war" if int(campaign.world_crisis.level)<60 else ("fracture" if int(campaign.world_crisis.level)<85 else "last_siege"))
	if stage!=String(campaign.world_crisis.war_stage):
		events.append("The regional crisis enters %s."%stage.replace("_"," "));campaign.world_crisis.war_stage=stage
		var event_id:="crisis_%s"%stage
		if stage in ["open_war","fracture","last_siege"] and campaign.pending_story_event_id.is_empty():campaign.pending_story_event_id=event_id
	if int(campaign.world_crisis.level)>=70:
		campaign.world_crisis.hearth_integrity=maxi(0,int(campaign.world_crisis.hearth_integrity)-(6+outbreak_count*4))
		if int(campaign.world_crisis.hearth_integrity)<=50 and int(campaign.world_crisis.hearth_integrity)>0:events.append("The Hearth is under siege; integrity %d%%."%int(campaign.world_crisis.hearth_integrity))
	campaign.world_crisis.last_day=campaign.calendar_day
	if int(campaign.world_crisis.hearth_integrity)<=0:
		campaign.world_crisis.collapsed=true;events.append("The Hearth falls. The Keeper carries memory into another beginning.")
		perform_reset(campaign)
	return events

static func perform_reset(campaign)->Dictionary:
	ensure(campaign);var old_loop:=int(campaign.keeper_memory.get("loop_number",0));var memory:Dictionary=Dictionary(campaign.keeper_memory).duplicate(true)
	var remembered:Array=Array(memory.get("remembered_people",[])).duplicate()
	for member in campaign.living_roster():
		if not remembered.has(member.id):remembered.append(member.id)
	for record_value in campaign.memorial:
		var record:=Dictionary(record_value);var id:=String(record.get("id",record.get("name","")))
		if not id.is_empty() and not remembered.has(id):remembered.append(id)
	var discoveries:Array=Array(memory.get("discoveries",[])).duplicate()
	for dungeon_id in campaign.completed_dungeons:
		var discovery:="suppressed_%s"%dungeon_id
		if not discoveries.has(discovery):discoveries.append(discovery)
	discoveries.append("witnessed_hearth_fall_%d"%(old_loop+1))
	campaign.keeper_memory={"loop_number":old_loop+1,"discoveries":discoveries,"remembered_people":remembered,"last_inheritance":{"contribution":campaign.contribution,"reputation":campaign.reputation,"day":campaign.calendar_day,"memorial_count":campaign.memorial.size()}}
	campaign.tutorial_phase=campaign.TUTORIAL_NEW;campaign.tutorial_outcome="";campaign.tutorial_history={};campaign.tutorial_keepsake_id="";campaign.tutorial_letter_unlocked=false;campaign.keeper_journal_unlocked=true;campaign.post_tutorial_initialized=false
	campaign.roster.clear();campaign.memorial.clear();campaign.candidate_pool.clear();campaign.retired_heroes.clear();campaign.first_company_ids.clear();campaign.first_company_recruited=false;campaign.first_normal_launch_completed=false;campaign.used_curated_ids.clear();campaign.lineage_registry.clear();campaign.next_character_number=1
	campaign.expedition=ExpeditionState.new();campaign.dispatches.clear();campaign.settled_expeditions.clear();campaign.return_reports.clear();campaign.pending_settlement_summary={};campaign.pending_story_context="";campaign.pending_story_event_id="";campaign.ending_state.clear();campaign.next_expedition_id=1;campaign.last_settled_expedition_id=0
	campaign.banked_gold=0;campaign.supplies=0;campaign.relic_essence=0;campaign.lifetime_relic_essence=0;campaign.banked_relics.clear();campaign.successful_levels=0;campaign.reputation=0;campaign.contribution=0;campaign.completed_dungeons.clear();campaign.clues.clear();campaign.unlocked_classes.clear();campaign.unlocked_classes.append_array(["warrior","mage"])
	campaign.armory.clear();campaign.next_item_id=1;campaign.establishment_tier=0;campaign.construction.clear();campaign.market_stock.clear();campaign.consumable_stock.clear();campaign.tavern_upgrades={"recovery":0,"roster_services":0,"starting_supplies":0,"item_rarity":0,"merchant_stock":0,"relic_capacity":0,"secret_research":0,"replacement_quality":0};campaign.tavern_dialogue_flags.clear()
	campaign.faction_standing.clear();campaign.divine_favor.clear();campaign.active_boons.clear();campaign.divine_obligations.clear();campaign.dungeon_ecology.clear();campaign.calendar_history.clear();campaign.calendar_day=1;campaign.tavern_phase=campaign.TAVERN_OPEN;campaign.candidate_wave_id=0;campaign.last_presented_wave_id=0
	campaign.world_crisis=defaults(1);campaign.ECOLOGY.ensure(campaign)
	return {"loop_number":old_loop+1,"preserved":["keeper_memory","story_event_history"],"reset":["roster","economy","dungeons","factions","favor","calendar"]}
