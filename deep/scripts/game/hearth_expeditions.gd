extends RefCounted
class_name HearthExpeditions

const COMPATIBILITY := preload("res://scripts/game/party_compatibility.gd")
const ECOLOGY := preload("res://scripts/game/dungeon_ecology.gd")
const DIVINE := preload("res://scripts/game/divine_favor_service.gd")

static func readiness(c: CampaignState, ids: Array[String], dungeon_id: String) -> Dictionary:
	if not HearthCatalog.data().dungeon_levels.has(dungeon_id): return HearthArmory.fail("Unknown dungeon.")
	if ids.is_empty() or ids.size() > c.get_party_cap(dungeon_id): return HearthArmory.fail("Choose a party within this dungeon's capacity.")
	if c.dispatches.size() + int(c.expedition.active) >= int(HearthCatalog.tier(c.establishment_tier).expedition_slots): return HearthArmory.fail("All expedition slots are occupied.")
	var seen: Dictionary = {}
	for id in ids:
		var member := c.character(id)
		if seen.has(id): return HearthArmory.fail("An adventurer cannot join twice.")
		seen[id] = true
		if member == null or member.status != CharacterRecord.STATUS_AVAILABLE or member.recovery_until > c.calendar_day: return HearthArmory.fail("Every party member must be home and recovered.")
		var weapon: Dictionary = c.armory.get(member.equipment.get("weapon",""),{})
		if weapon.is_empty() or weapon.get("owner","")!=id: return HearthArmory.fail("Equip every adventurer with an owned class weapon.")
	var cost := maxi(1,ids.size()-int(c.tavern_upgrades.starting_supplies))
	if c.supplies < cost: return HearthArmory.fail("This party needs %d supplies." % cost)
	return {"ok":true,"supplies":cost}

static func risk(c: CampaignState, ids: Array[String], dungeon_id: String) -> Dictionary:
	var rating := 0.0
	var classes: Dictionary = {}
	var reasons: Array[String] = []
	for id in ids:
		var member := c.character(id)
		if member == null: continue
		classes[member.class_id] = true
		var mods := HearthCatalog.modifiers(c,member)
		var gear_rating := 0.0
		for value in mods.values(): gear_rating += float(value)*0.12
		rating += (float(member.level)+1.0+gear_rating+member.provisions.size()*0.3)*(float(member.current_health)/maxi(1,member.max_health))
	var target := float(HearthCatalog.data().dungeon_levels.get(dungeon_id,2))*float(c.get_party_cap(dungeon_id))*ECOLOGY.threat_multiplier(c,dungeon_id)
	rating *= 1.0 + maxi(0,classes.size()-1)*0.12
	var compatibility:=COMPATIBILITY.evaluate(c,ids)
	rating*=float(compatibility.multiplier)
	var ratio := rating/maxf(1.0,target)
	reasons.append("Party strength %.1f / dungeon demand %.1f" % [rating,target])
	reasons.append("%d distinct class roles; health, equipment and provisions included." % classes.size())
	reasons.append("Social cohesion: %s (%+d)."%[String(compatibility.band),int(compatibility.score)])
	reasons.append_array(compatibility.reasons)
	return {"ratio":ratio,"band":"Low" if ratio>=1.4 else ("Moderate" if ratio>=0.95 else "High"),"compatibility":compatibility,"reasons":reasons}

static func dispatch(c: CampaignState, ids: Array[String], dungeon_id: String, policy: String) -> Dictionary:
	if policy not in ["cautious","balanced","bold"]: return HearthArmory.fail("Choose a valid retreat policy.")
	if not c.has_completed_dungeon(dungeon_id): return HearthArmory.fail("Manually clear this dungeon before dispatching a party.")
	var check := readiness(c,ids,dungeon_id)
	if not check.ok: return check
	var e := ExpeditionState.new()
	e.begin(ids, dungeon_id, false, c.next_expedition_id)
	c.next_expedition_id += 1
	e.deployment_type = "automated"
	e.departure_day = c.calendar_day
	e.departure_shift_index = HearthCalendar.shift_index(c)
	e.due_shift_index = e.departure_shift_index + 1
	e.due_day = 1 + int(e.due_shift_index / 2)
	e.retreat_policy = policy
	e.simulation_seed = 7919+e.expedition_id*104729
	e.risk_ratio = float(risk(c,ids,dungeon_id).ratio)
	lock_party(c,e)
	c.supplies -= int(check.supplies)
	c.dispatches[str(e.expedition_id)] = e.to_dict()
	c._add_calendar_event("dispatch","A party departs for %s; due Day %d · %s." % [dungeon_id.capitalize(),e.due_day,"Early Shift" if e.due_shift_index % 2 == 0 else "Late Shift"])
	return {"ok":true,"message":"Expedition dispatched. Expected return: Day %d · %s." % [e.due_day,"Early Shift" if e.due_shift_index % 2 == 0 else "Late Shift"]}

static func lock_party(c: CampaignState, e: ExpeditionState) -> void:
	for id in e.party_ids:
		var member := c.character(id)
		member.status = CharacterRecord.STATUS_EXPEDITION
		member.expeditions += 1
		e.locked_loadouts[id] = {"equipment":member.equipment.duplicate(true),"provisions":member.provisions.duplicate()}

static func resolve_auto(c: CampaignState, e: ExpeditionState) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = e.simulation_seed
	var logs: Array[String] = []
	var floors := int(GameBalance.get_dungeon(e.dungeon_id).get("floors",5))
	var outcome := "victory"
	var threshold: float = {"cautious":0.65,"balanced":0.4,"bold":0.2}[e.retreat_policy]
	var reward_multiplier:=ECOLOGY.reward_multiplier(c,e.dungeon_id)
	for floor_index in range(1,floors+1):
		e.floor = floor_index
		for id in e.living_party_ids():
			var member := c.character(id)
			var incoming := maxi(1,roundi(rng.randf_range(0.10,0.24)*member.max_health/maxf(0.25,e.risk_ratio)))
			if floor_index == floors: incoming = roundi(incoming*1.5)
			member.current_health -= incoming
			if member.current_health > 0 and member.current_health < member.max_health*0.6 and not member.provisions.is_empty():
				var bottle: String = member.provisions.pop_back()
				var effects: Dictionary = GameBalance.get_consumable(bottle).get("effects",{})
				var healing := int(effects.get("heal",0))+int(effects.get("temporary_aegis",0))
				if effects.get("hidden",false): healing += incoming
				if effects.has("movement") or effects.has("movement_multiplier"): healing += int(incoming/2)
				if effects.has("resource") or effects.has("next_attack_damage_multiplier"): e.risk_ratio += 0.1
				member.current_health = mini(member.max_health,member.current_health+healing)
				logs.append("%s uses %s." % [member.display_name,GameBalance.get_consumable(bottle).name])
			if member.current_health <= 0:
				e.record_casualty(id)
				logs.append("%s falls on floor %d." % [member.display_name,floor_index])
		if e.living_party_ids().is_empty(): outcome = "death"; break
		e.carried_gold += roundi((10+floor_index*3)*reward_multiplier)
		e.carried_relic_essence += 1
		e.carried_contribution += 4
		var health_fraction := 1.0
		for id in e.living_party_ids():
			var member := c.character(id)
			health_fraction = minf(health_fraction,float(member.current_health)/member.max_health)
		if health_fraction < threshold and floor_index < floors:
			outcome = "retreat"
			logs.append("The %s policy orders a retreat after floor %d." % [e.retreat_policy,floor_index])
			break
	return settle(c,e,outcome,{"events":logs})

static func settle(c: CampaignState, e: ExpeditionState, outcome: String, extra: Dictionary = {}) -> Dictionary:
	if outcome not in ["victory","retreat","death"]: return HearthArmory.fail("Unknown expedition outcome.")
	var key := str(e.expedition_id)
	if c.settled_expeditions.has(key): return {"ok":true,"duplicate":true,"logs":[]}
	if not e.active: return HearthArmory.fail("No expedition is active.")
	if e.deployment_type == "manual":
		c.expedition = ExpeditionState.new()
		var transition: Dictionary
		if e.due_shift_index >= 0:
			transition = HearthCalendar.advance_shift(c,true)
		else:
			transition = HearthCalendar.advance(c,maxi(0,e.due_day-c.calendar_day),false)
		if not transition.ok:
			c.expedition = e
			return transition
		if transition.get("reset",false): return {"ok":true,"reset":true,"duplicate":false,"logs":[transition.message],"report":{}}
	var divine_modifiers := DIVINE.settlement_modifiers(c,e)
	var gross := roundi(e.carried_gold*float(divine_modifiers.gold_multiplier)) if outcome != "death" else 0
	var share := 0 if bool(extra.get("legacy_resolve",false)) else int(gross*0.2)
	c.banked_gold += gross-share
	var essence := e.carried_relic_essence if outcome != "death" else 0
	c.relic_essence += essence
	c.lifetime_relic_essence += essence
	# Witnessed progress, mapped danger, and sacrifice remain useful even when no loot returns.
	var contribution := roundi(e.carried_contribution*float(divine_modifiers.contribution_multiplier))
	c.contribution += contribution
	var lost: Array[String] = []
	var returned: Array[String] = []
	var retire_after_settlement:Array[String]=[]
	for id in e.party_ids:
		var member := c.character(id)
		if member == null: continue
		if outcome == "death" or e.casualties.has(id) or member.status == CharacterRecord.STATUS_DEAD:
			if member.status != CharacterRecord.STATUS_DEAD:
				member.status = CharacterRecord.STATUS_DEAD
				var memorial := member.to_dict()
				memorial.merge({"name":member.display_name,"cause":"Lost in %s" % e.dungeon_id,"death_day":c.calendar_day},true)
				c.memorial.append(memorial)
			HearthArmory.release(c,member,true)
			lost.append(member.display_name)
			continue
		var ready_now := int(c.tavern_upgrades.get("recovery",0)) > 0
		member.status = CharacterRecord.STATUS_AVAILABLE if ready_now else "recovering"
		member.recovery_until = 0 if ready_now else c.calendar_day + 1
		member.fatigue = 0 if ready_now else member.fatigue + 1
		if ready_now: member.current_health = member.max_health
		if outcome == "victory":
			member.victories += 1
			c.successful_levels += member.level
			if e.deployment_type == "automated":
				var earned_xp := VisitorContestRules.scale_xp(50*e.floor,member.learning_potential)
				member.xp += earned_xp
				member.progression["total_xp"] = int(member.progression.get("total_xp",member.xp-earned_xp)) + earned_xp
				var thresholds: Array = GameBalance.get_progression().get("xp_thresholds",[])
				while member.level < 20 and thresholds.size() > member.level+1 and member.xp >= int(thresholds[member.level+1]): member.level += 1
				member.progression.level = member.level
				member.progression.xp = member.xp
			if member.expeditions>=member.career_limit:retire_after_settlement.append(id)
		member.personal_history.append({"day":c.calendar_day,"kind":outcome,"dungeon":e.dungeon_id})
		returned.append(member.display_name)
	COMPATIBILITY.record_shared_outcome(c,e.living_party_ids(),outcome)
	if outcome in ["victory","retreat"]:
		var represented_nations:Dictionary={}
		for id in e.living_party_ids():
			var survivor:=c.character(id)
			if survivor!=null:represented_nations[survivor.nation_id]=true
		for nation_id in represented_nations:c.faction_standing[nation_id]=int(c.faction_standing.get(nation_id,0))+1
	var retired:Array[String]=[]
	for id in retire_after_settlement:
		var veteran:=c.character(id)
		if veteran==null:continue
		veteran.status=CharacterRecord.STATUS_RETIRED;var retirement:=veteran.to_dict();retirement.merge({"name":veteran.display_name,"retired_day":maxi(c.calendar_day,e.due_day),"dungeon_id":e.dungeon_id,"descendant_checks":0,"descendant_created":false},true);c.retired_heroes.append(retirement);c.lineage_registry[veteran.id]={"retired_day":maxi(c.calendar_day,e.due_day),"checks":0,"descendant_created":false};HearthArmory.release(c,veteran);c.roster.erase(id);returned.erase(veteran.display_name);retired.append(veteran.display_name)
	var rewards: Array[String] = []
	if outcome == "victory":
		if e.deployment_type == "manual": c.reputation = mini(100,c.reputation+4+e.party_ids.size())
		else: c.reputation = mini(maxi(c.reputation,24),c.reputation+1)
		var pool: Array[String] = []
		for id in HearthCatalog.data().items:
			var entry := HearthCatalog.item(id)
			if entry.sources.has(e.dungeon_id) and int(entry.tier) <= mini(3,c.establishment_tier+int(c.tavern_upgrades.item_rarity)): pool.append(id)
		if not pool.is_empty():
			var reward_id: String = pool[posmod(e.expedition_id*31,pool.size())]
			HearthArmory.grant(c,reward_id)
			rewards.append(HearthCatalog.item(reward_id).name)
		# Secret dungeons have authored, unique rewards in addition to the
		# ordinary recovered item roll. They are banked exactly once per campaign.
		for unique_id in Array(GameBalance.get_dungeon(e.dungeon_id).get("unique_rewards", [])):
			if not c.banked_relics.has(String(unique_id)):
				c.banked_relics.append(String(unique_id))
				rewards.append(String(unique_id).replace("_"," ").capitalize())
	if outcome != "death":
		for id in e.carried_relics:
			if not c.banked_relics.has(id): c.banked_relics.append(id)
	var divine_result := DIVINE.record_expedition_outcome(c,e,outcome)
	var report := {"expedition_id":e.expedition_id,"outcome":outcome,"headline":"%s: %s" % [e.dungeon_id.capitalize(),outcome.capitalize()],"dungeon":e.dungeon_id,"deployment_type":e.deployment_type,"depth":e.floor,"gold":gross,"share":share,"net":gross-share,"essence":essence,"contribution":contribution,"returned":returned,"retired":retired,"lost":lost,"items":rewards,"events":extra.get("events",[]),"divine":divine_result}
	c.return_reports.append(report)
	var queued: Array = c.pending_settlement_summary.get("reports",[]).duplicate(true)
	queued.append(report.duplicate(true))
	c.pending_settlement_summary = report.duplicate(true)
	c.pending_settlement_summary["reports"] = queued
	c.period_completed_runs += 1
	c.settled_expeditions[key] = true
	c.last_settled_expedition_id = e.expedition_id
	c.dispatches.erase(key)
	c._add_calendar_event(outcome,report.headline)
	c.tavern_phase = CampaignState.TAVERN_ARRIVALS if c.last_presented_wave_id < c.candidate_wave_id else CampaignState.TAVERN_OPEN
	return {"ok":true,"duplicate":false,"logs":["Recovered %d gold; company share %d; net %d. Contribution recorded: %d." % [gross,share,gross-share,contribution]],"report":report}
