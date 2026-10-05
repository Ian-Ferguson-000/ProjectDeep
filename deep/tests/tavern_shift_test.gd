extends SceneTree

const STORY := preload("res://scripts/game/story_event_service.gd")
const CRISIS := preload("res://scripts/game/world_crisis.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func company() -> CampaignState:
	var c := CampaignState.new()
	c.apply_post_tutorial_state("victory")
	for candidate in c.get_candidates(): check(c.recruit_candidate(candidate.id).ok,"Founders failed to recruit")
	c.supplies = 100
	return c

func restored(c: CampaignState) -> CampaignState:
	var copy := CampaignState.new()
	copy._load_dict(c.to_dict())
	return copy

func run() -> void:
	var founders := CampaignState.new()
	founders.apply_post_tutorial_state("victory")
	check(not HearthCalendar.advance_shift(founders).ok,"Calendar bypassed founding recruitment")
	var c := company()
	var original_ids := c.candidate_pool.keys()
	c._generate_candidate_wave()
	original_ids = c.candidate_pool.keys()
	var member := c.living_roster()[0]
	var ecology := c.dungeon_ecology.duplicate(true)
	c.construction["recovery"] = {"due_day":2}
	c.market_stock["sentinel"] = true
	var late := HearthCalendar.advance_shift(c)
	check(late.ok and c.calendar_day == 1 and c.calendar_shift == 1,"Early-to-late changed the date")
	check(c.dungeon_ecology == ecology and c.construction.has("recovery"),"Daily effects ran during late shift")
	check(original_ids.all(func(id: Variant): return not c.candidate_pool.has(id)) and c.character(member.id) != null,"Visitor replacement removed recruits or retained old visitors")
	HearthCalendar.advance_shift(c)
	check(c.calendar_day == 2 and c.calendar_shift == 0 and not c.construction.has("recovery") and int(c.tavern_upgrades.recovery) == 1,"Morning did not complete construction once")
	check(c.market_stock.has("sentinel"),"Merchant stock refreshed outside its week")
	HearthCalendar.advance_shift(c)
	check(int(c.tavern_upgrades.recovery) == 1,"Construction completed twice")
	c.calendar_day = 7
	c.calendar_shift = 1
	HearthCalendar.advance_shift(c)
	check(c.market_stock.is_empty(),"Weekly merchant refresh did not run")
	check(not HearthFacilities.quote(c,"recovery").available,"Recovery upgrade allowed redundant purchases")
	c.tavern_upgrades.recovery = 3
	check(int(restored(c).tavern_upgrades.recovery) == 3,"Existing recovery ranks were lost")

	var batches := company()
	var sizes: Dictionary = {}
	for step in 12:
		HearthCalendar.advance_shift(batches)
		var count := batches.candidate_pool.size()
		check(count >= 1 and count <= 4,"Ordinary batch outside 1-4 range")
		sizes[count] = true
	check(sizes.size() > 1,"Visitor volumes never varied")
	var candidate := batches.get_candidates()[0]
	batches.inspect_candidate(candidate.id,"observe")
	batches.mark_arrivals_presented(batches.candidate_wave_id)
	var copy := restored(batches)
	check(copy.calendar_shift == batches.calendar_shift and copy.period_elapsed_shifts == batches.period_elapsed_shifts,"Shift or period progress was lost")
	check(copy.candidate_pool[candidate.id].knowledge == candidate.knowledge and copy.last_presented_wave_id == batches.last_presented_wave_id,"Reload lost assessment or presentation state")
	HearthCalendar.advance_shift(batches)
	HearthCalendar.advance_shift(copy)
	check(JSON.stringify(batches.to_dict().candidate_pool) == JSON.stringify(copy.to_dict().candidate_pool),"Reload rerolled the next batch")
	batches.tavern_upgrades.roster_services = 3
	for step in 6:
		HearthCalendar.advance_shift(batches)
		check(batches.candidate_pool.size() >= 4 and batches.candidate_pool.size() <= 7,"Upgraded visitor volume outside 4-7 range")

	var runs := company()
	runs.record_dungeon_clear("forest")
	runs.establishment_tier = 1
	var party := runs.living_roster()
	for hero in party:
		hero.level = 20
		hero.max_health = 1000
		hero.current_health = 1000
	check(HearthExpeditions.dispatch(runs,[party[0].id],"forest","cautious").ok,"Dispatch failed")
	check(runs.calendar_shift == 0 and runs.calendar_day == 1,"Dispatch advanced time")
	check(not HearthExpeditions.dispatch(runs,[party[0].id],"forest","cautious").ok,"An away recruit was dispatched twice")
	check(not HearthArmory.unequip(runs,party[0].id,"weapon").ok,"Away equipment was unlocked")
	check(HearthExpeditions.dispatch(runs,[party[1].id],"forest","cautious").ok,"Second available party could not depart")
	check(not HearthExpeditions.dispatch(runs,[party[1].id],"crypt","cautious").ok,"Dispatch bypassed dungeon unlock")
	var saved_runs := restored(runs)
	var returns := HearthCalendar.advance_shift(runs)
	HearthCalendar.advance_shift(saved_runs)
	check(returns.reports.size() == 2 and runs.dispatches.is_empty() and runs.period_completed_runs == 2,"Simultaneous returns were lost or counted incorrectly")
	check(runs.pending_settlement_summary.reports.size() == 2,"Only the last simultaneous report was queued")
	check(JSON.stringify(runs.return_reports) == JSON.stringify(saved_runs.return_reports),"Saved expedition simulations rerolled")
	check(party[0].status == "recovering" and party[0].recovery_until == 2,"Returning recruit did not rest until next morning")
	HearthCalendar.advance_shift(runs)
	check(party[0].status == "available" and party[0].current_health == party[0].max_health,"Morning recovery did not restore readiness")
	check(runs.period_completed_runs == 2,"Completed dispatches counted again")

	var mixed := company()
	mixed.record_dungeon_clear("forest")
	mixed.establishment_tier = 1
	mixed.tavern_upgrades.recovery = 1
	var mixed_party := mixed.living_roster()
	mixed_party[0].level = 20
	mixed_party[0].max_health = 1000
	mixed_party[0].current_health = 1000
	HearthExpeditions.dispatch(mixed,[mixed_party[0].id],"forest","cautious")
	check(mixed.launch_expedition([mixed_party[1].id],"forest").ok,"Manual run alongside dispatch failed")
	var manual_id := mixed.expedition.expedition_id
	check(not HearthCalendar.advance_shift(mixed).ok,"Calendar advanced during active manual run")
	mixed.settle_expedition(manual_id,"retreat")
	check(mixed.calendar_day == 1 and mixed.calendar_shift == 1 and mixed.return_reports.size() == 2 and mixed.period_completed_runs == 2,"Manual settlement missed simultaneous dispatch return or advanced too far")
	check(mixed_party[1].status == "available" and mixed_party[1].current_health == mixed_party[1].max_health,"Infirmary did not grant immediate readiness")
	mixed.settle_expedition(manual_id,"retreat")
	check(mixed.period_completed_runs == 2 and mixed.period_elapsed_shifts == 1,"Duplicate settlement changed time or progress")

	var morning_return := company()
	HearthCalendar.advance_shift(morning_return)
	var hero := morning_return.living_roster()[0]
	morning_return.launch_expedition([hero.id],"forest")
	morning_return.settle_expedition(morning_return.expedition.expedition_id,"victory")
	check(morning_return.calendar_day == 2 and morning_return.calendar_shift == 0 and hero.recovery_until == 3,"Late run did not return next morning and rest until the following morning")

	var gate := company()
	gate.period_completed_runs = 5
	gate.period_elapsed_shifts = 5
	check(not HearthCalendar.can_advance_to_next_event(gate) and not HearthCalendar.advance_to_next_event(gate).ok,"Shortcut opened before either milestone")
	gate.period_completed_runs = 6
	check(HearthCalendar.can_advance_to_next_event(gate),"Six runs did not unlock shortcut")
	gate.period_completed_runs = 0
	gate.period_elapsed_shifts = 6
	check(HearthCalendar.can_advance_to_next_event(gate),"Three days did not unlock shortcut")
	gate.construction["recovery"] = {"due_day":3}
	var skipped := HearthCalendar.advance_to_next_event(gate)
	check(skipped.ok and gate.calendar_day == 3 and gate.calendar_shift == 0 and not gate.construction.has("recovery"),"Shortcut stopped at routine arrivals instead of construction")
	STORY.mark_played("balor_threshold",gate)
	check(gate.period_elapsed_shifts > 0,"Routine story reset period progress")
	gate.pending_story_event_id = "crisis_open_war"
	var before := HearthCalendar.shift_index(gate)
	HearthCalendar.advance_to_next_event(gate)
	check(HearthCalendar.shift_index(gate) == before,"Shortcut skipped pending major dialogue")
	STORY.mark_played("crisis_open_war",gate)
	check(gate.period_elapsed_shifts == 0 and gate.period_completed_runs == 0,"Major story did not reset progress")
	gate.period_elapsed_shifts = 2
	STORY.mark_played("crisis_open_war",gate)
	check(gate.period_elapsed_shifts == 2,"Duplicate story completion reset progress again")
	var crisis_skip := company()
	crisis_skip.calendar_day = 70
	crisis_skip.calendar_shift = 1
	crisis_skip.period_elapsed_shifts = 6
	for value in crisis_skip.dungeon_ecology.values():
		value.last_day = 70
		value.pressure = 0.0
		value.stability = 100.0
	HearthCalendar.advance_to_next_event(crisis_skip)
	check(crisis_skip.calendar_day == 71 and crisis_skip.pending_story_event_id == "crisis_open_war","Shortcut failed to stop at a major crisis event")
	var bounded := company()
	bounded.period_elapsed_shifts = 6
	bounded.world_crisis.level = 59
	bounded.world_crisis.war_stage = "open_war"
	# Freeze ecology progression to isolate the no-event limit from outbreaks.
	for value in bounded.dungeon_ecology.values(): value.last_day = 10000
	var no_event := HearthCalendar.advance_to_next_event(bounded)
	check(no_event.ok and bounded.calendar_day == 113 and bounded.calendar_shift == 0 and String(no_event.message).contains("no qualifying event"),"Shortcut did not stop and report its 112-day limit")
	bounded.ending_state = {"ending_id":"test"}
	var ending_day := bounded.calendar_day
	check(not HearthCalendar.advance_to_next_event(bounded).ok and bounded.calendar_day == ending_day,"Shortcut advanced beyond an ending")
	var defeat := company()
	defeat.launch_expedition(defeat.default_party("forest"),"forest")
	defeat.settle_expedition(defeat.expedition.expedition_id,"death")
	check(defeat.period_completed_runs == 1 and defeat.calendar_shift == 1 and defeat.memorial.size() == 2,"Defeat did not count as one completed run")
	var replacement := defeat.get_candidates()[0]
	defeat.recruit_candidate(replacement.id)
	check(defeat.first_company_recruited and HearthCalendar.advance_shift(defeat).ok,"Recruiting replacements restored the founding recruitment lock")
	CRISIS.perform_reset(gate)
	check(gate.calendar_shift == 0 and gate.period_elapsed_shifts == 0 and gate.period_completed_runs == 0,"Campaign reset retained shift or period progress")

	var old := company()
	old.record_dungeon_clear("forest")
	old.launch_expedition([old.living_roster()[0].id],"forest")
	var legacy := old.to_dict()
	legacy.version = 15
	legacy.expedition.erase("departure_shift_index")
	legacy.expedition.erase("due_shift_index")
	legacy.expedition.due_day = 8
	var imported := CampaignState.new()
	imported._load_dict(CampaignState._migrate_dict(legacy))
	check(imported.calendar_shift == 0 and imported.period_elapsed_shifts == 0 and imported.expedition.due_shift_index == -1 and imported.expedition.due_day == 8,"Old expedition timing was not preserved")
	imported.settle_expedition(imported.expedition.expedition_id,"victory")
	check(imported.calendar_day == 8 and imported.calendar_shift == 0,"Imported manual run lost its original due date")
	var legacy_dispatch := company()
	legacy_dispatch.record_dungeon_clear("forest")
	var legacy_hero := legacy_dispatch.living_roster()[0]
	legacy_hero.level = 20
	legacy_hero.max_health = 1000
	legacy_hero.current_health = 1000
	HearthExpeditions.dispatch(legacy_dispatch,[legacy_hero.id],"forest","cautious")
	var record: Dictionary = legacy_dispatch.dispatches.values()[0]
	record.erase("departure_shift_index")
	record.erase("due_shift_index")
	record.due_day = 8
	var recovering := legacy_dispatch.living_roster()[1]
	recovering.status = "recovering"
	recovering.recovery_until = 9
	var legacy_data := legacy_dispatch.to_dict()
	legacy_data.version = 15
	var loaded := CampaignState.new()
	loaded._load_dict(CampaignState._migrate_dict(legacy_data))
	HearthCalendar.advance(loaded,6,false)
	check(loaded.dispatches.size() == 1 and loaded.character(recovering.id).recovery_until == 9,"Migration shortened existing dispatch or recovery")
	HearthCalendar.advance(loaded,1,false)
	check(loaded.dispatches.is_empty() and loaded.character(recovering.id).status == "recovering","Imported dispatch missed due date or recovering hero returned early")

	if failures.is_empty(): print("TAVERN_SHIFT_TESTS_PASSED"); quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
