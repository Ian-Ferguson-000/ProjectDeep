extends RefCounted
class_name HearthCalendar

const ECOLOGY := preload("res://scripts/game/dungeon_ecology.gd")
const CRISIS := preload("res://scripts/game/world_crisis.gd")

static func shift_index(c: CampaignState) -> int:
	return (c.calendar_day - 1) * 2 + c.calendar_shift

static func shift_name(c: CampaignState) -> String:
	return "Early Shift" if c.calendar_shift == 0 else "Late Shift"

static func can_advance_to_next_event(c: CampaignState) -> bool:
	return c.first_company_recruited and (c.period_completed_runs >= 6 or c.period_elapsed_shifts >= 6)

static func reset_story_period(c: CampaignState) -> void:
	c.period_completed_runs = 0
	c.period_elapsed_shifts = 0

static func _check(c: CampaignState) -> Dictionary:
	if c.expedition.active: return HearthArmory.fail("Return from the manual expedition before advancing the calendar.")
	if not c.first_company_recruited: return HearthArmory.fail("Welcome both founding adventurers before advancing the calendar.")
	if not c.ending_state.is_empty(): return HearthArmory.fail("The company has reached its ending.")
	return {"ok":true}

static func advance_shift(c: CampaignState, internal: bool = false) -> Dictionary:
	var check := _check(c)
	if not check.ok: return check
	if not internal and not c.pending_story_event_id.is_empty(): return HearthArmory.fail("Hear the pending story before advancing time.")
	var events: Array[String] = []
	var reports: Array[Dictionary] = []
	var old_loop := int(c.keeper_memory.get("loop_number",0))
	for candidate in c.get_candidates():
		c._add_calendar_event("departure","%s leaves at the shift change." % candidate.adventurer.display_name)
	c.candidate_pool.clear()
	c.calendar_shift = 1 - c.calendar_shift
	c.period_elapsed_shifts += 1
	if c.calendar_shift == 0:
		c.calendar_day += 1
		events.append_array(ECOLOGY.advance_to_day(c,c.calendar_day))
		events.append_array(CRISIS.advance(c))
		if old_loop != int(c.keeper_memory.get("loop_number",0)):
			return {"ok":true,"reset":true,"message":"The Hearth falls. A new beginning awaits.","events":events,"reports":reports}
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
				var retired := retire(c,member)
				if retired.ok: events.append("%s retires." % member.display_name)
		if (c.calendar_day-1)%7 == 0: c.market_stock.clear()
	for key in c.dispatches.keys():
		var e := ExpeditionState.from_dict(c.dispatches[key])
		var due := e.due_shift_index <= shift_index(c) if e.due_shift_index >= 0 else e.due_day <= c.calendar_day
		if not due: continue
		var result := HearthExpeditions.resolve_auto(c,e)
		if result.ok:
			reports.append(result.report)
			events.append("An expedition returns from %s." % e.dungeon_id.capitalize())
	c._generate_candidate_wave(false)
	for event in events: c._add_calendar_event("hearth",event)
	return {"ok":true,"message":"Day %d · %s. %s" % [c.calendar_day,shift_name(c)," ".join(events)],"events":events,"reports":reports}

# Day-based callers retain their duration; all time passes through shift boundaries.
static func advance(c: CampaignState, days: int = 1, stop_at_event: bool = true) -> Dictionary:
	var check := _check(c)
	if not check.ok: return check
	var events: Array[String] = []
	var reports: Array[Dictionary] = []
	for step in clampi(days,0,3650)*2:
		var result := advance_shift(c,true)
		if not result.ok: return result
		events.append_array(result.events)
		reports.append_array(result.reports)
		if result.get("reset",false): return result
		if stop_at_event and not events.is_empty(): break
	return {"ok":true,"message":"Day %d · %s. %s" % [c.calendar_day,shift_name(c)," ".join(events)],"events":events,"reports":reports}

static func advance_to_next_event(c: CampaignState) -> Dictionary:
	var check := _check(c)
	if not check.ok: return check
	if not can_advance_to_next_event(c): return HearthArmory.fail("Complete six runs or manage three full days before skipping to the next event.")
	if not c.pending_story_event_id.is_empty(): return {"ok":true,"message":"A story event awaits.","events":[],"reports":[]}
	for step in 224:
		var result := advance_shift(c,true)
		if not result.ok: return result
		if result.get("reset",false) or not result.events.is_empty() or not c.pending_story_event_id.is_empty() or not c.ending_state.is_empty(): return result
	return {"ok":true,"message":"Advanced 112 days; no qualifying event occurred.","events":[],"reports":[]}

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
