extends RefCounted
class_name HearthCalendar

static func advance(c: CampaignState, days: int = 1, stop_at_event: bool = true) -> Dictionary:
	if c.expedition.active: return HearthArmory.fail("Return from the manual expedition before advancing the calendar.")
	if not c.first_company_recruited: return HearthArmory.fail("Welcome both founding adventurers before advancing the calendar.")
	var events: Array[String] = []
	for step in clampi(days,0,3650):
		c.calendar_day += 1
		for branch in c.construction.keys():
			if int(c.construction[branch].due_day) > c.calendar_day: continue
			c.tavern_upgrades[branch] = int(c.tavern_upgrades.get(branch,0))+1
			if branch == "roster_services": c.establishment_tier = mini(3,c.establishment_tier+1)
			c.construction.erase(branch)
			events.append("%s completed." % branch.replace("_"," ").capitalize())
		for member in c.living_roster():
			if member.status == "recovering" and member.recovery_until <= c.calendar_day:
				member.status = CharacterRecord.STATUS_AVAILABLE
				member.current_health = member.max_health
				member.fatigue = 0
				events.append("%s is ready." % member.display_name)
			if member.status == CharacterRecord.STATUS_AVAILABLE and member.age_on(c.calendar_day) >= 60:
				retire(c,member)
				events.append("%s retires." % member.display_name)
		for key in c.dispatches.keys():
			var e := ExpeditionState.from_dict(c.dispatches[key])
			if e.due_day <= c.calendar_day:
				HearthExpeditions.resolve_auto(c,e)
				events.append("An expedition returns from %s." % e.dungeon_id.capitalize())
		if (c.calendar_day-1)%7 == 0:
			c._generate_candidate_wave(false)
			c.market_stock.clear()
			events.append("New candidates and merchant stock arrive.")
		if stop_at_event and not events.is_empty(): break
	for event in events: c._add_calendar_event("hearth",event)
	return {"ok":true,"message":"Day %d. %s" % [c.calendar_day," ".join(events)],"events":events}

static func retire(c: CampaignState, member: CharacterRecord) -> Dictionary:
	if member == null: return HearthArmory.fail("That adventurer has already left.")
	if not c.first_normal_launch_completed and c.first_company_ids.has(member.id): return HearthArmory.fail("The founding company must complete its first expedition briefing.")
	if member.status != CharacterRecord.STATUS_AVAILABLE: return HearthArmory.fail("Only adventurers at home can retire.")
	HearthArmory.release(c,member)
	for id in member.provisions: c.consumable_stock[id] = int(c.consumable_stock.get(id,0))+1
	member.provisions.clear()
	member.status = CharacterRecord.STATUS_RETIRED
	var record := member.to_dict()
	record.merge({"name":member.display_name,"retired_day":c.calendar_day,"descendant_checks":0,"descendant_created":false},true)
	c.retired_heroes.append(record)
	c.lineage_registry[member.id] = {"retired_day":c.calendar_day,"checks":0,"descendant_created":false}
	c.roster.erase(member.id)
	return {"ok":true,"message":"%s retires; equipment returned to the armory." % member.display_name}
