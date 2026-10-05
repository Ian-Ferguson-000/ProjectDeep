extends SceneTree

const VIEW := preload("res://scripts/ui/hearth_calendar_view.gd")
const TAVERN := preload("res://scenes/tavern/Tavern.tscn")
var failures: Array[String] = []

class MemoryState extends RunState:
	func autosave_on_floor_entry() -> bool: return true

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/calendar_%s.png" % name)

func run() -> void:
	var c := CampaignState.new()
	c.apply_post_tutorial_state("victory")
	for candidate in c.get_candidates(): c.recruit_candidate(candidate.id)
	c.last_presented_wave_id = c.candidate_wave_id
	var view := VIEW.new()
	root.add_child(view)
	view.open(c)
	check(view.grid.columns == 7 and view.day_buttons.size() == 28,"Calendar is not a seven-column four-week grid")
	check(view.tabs.get_tab_title(0) == "Calendar" and view.tabs.get_tab_title(1) == "History","Calendar/history tabs missing")
	check(view.heading.text == "Spring · Year 1" and view.previous_button.disabled,"Initial season or navigation was incorrect")
	check(view.day_buttons[0].text.contains("Today") and view.details.text.contains("Early Shift"),"Current day or shift was missing")
	c.calendar_shift = 1
	c._add_calendar_event("assessment","Asha receives an appraisal.")
	c.construction["recovery"] = {"due_day":5}
	var hero := c.living_roster()[0]
	hero.status = "recovering"
	hero.recovery_until = 5
	c.dispatches["42"] = {"expedition_id":42,"active":true,"dungeon_id":"forest","due_day":5,"due_shift_index":9}
	view.refresh()
	view.select_day(4)
	check(view.details.text.contains("Late Shift") and view.details.text.contains("early shift") and view.details.text.contains(hero.display_name),"Scheduled returns, construction, or recovery missing from day details")
	check(c.calendar_day == 1 and c.calendar_shift == 1,"Browsing the calendar advanced time")
	view.select_day(0)
	check(view.details.text.contains("Asha receives an appraisal.") and view.details.text.contains("Late"),"Recorded assessment or shift missing")
	view.tabs.current_tab = 1
	check(view.history_text.text.contains("RECENT HEARTH HISTORY") and view.history_text.text.contains("Asha"),"History tab lost existing calendar entries")
	view.change_season(1)
	check(view.heading.text == "Summer · Year 1" and view.selected_day == 29,"Season navigation failed")
	view.change_season(2)
	check(view.heading.text == "Winter · Year 1" and view.selected_day == 85,"Winter navigation failed")
	view.change_season(1)
	check(view.heading.text == "Spring · Year 2" and view.selected_day == 113,"Year boundary navigation failed")
	view.change_season(-10)
	check(view.season_index == 0 and view.previous_button.disabled,"Calendar navigated before Year 1")
	c.calendar_day = 112
	view.show_today()
	check(view.heading.text == "Winter · Year 1" and view.day_buttons[27].text.contains("Today"),"Today button did not restore the campaign date")
	view.free()

	var definitions := AdventurerContent.curated()
	check(definitions.size() == 48 and AdventurerContent.validate().is_empty(),"Expanded recruit content did not validate")
	var coverage: Dictionary = {}
	var new_ids: Array[String] = []
	for definition in definitions.slice(24):
		new_ids.append(definition.id)
		coverage[definition.get("class")] = int(coverage.get(definition.get("class"),0))+1
		check(not AdventurerContent.trait_definition(definition.trait).is_empty(),"New recruit has an unknown trait")
		check(definition.faith_id == "unaffiliated" or DivineFavorService.deities().has(definition.faith_id),"New recruit has an unknown faith")
		check(FileAccess.file_exists("res://assets/roster_portraits/%s_%d.png" % [definition.get("class"),definition.portrait]),"New recruit references an unavailable portrait")
	for class_id in ["warrior","mage","healer","tank","rogue","summoner"]:
		check(int(coverage.get(class_id,0)) == 4,"New recruits are not balanced across existing classes")
	var established := CampaignState.new()
	established.apply_post_tutorial_state("victory")
	for candidate in established.get_candidates(): established.recruit_candidate(candidate.id)
	for definition in definitions.slice(0,24):
		if not established.used_curated_ids.has(definition.id): established.used_curated_ids.append(definition.id)
	for class_id in ["healer","tank","rogue","summoner"]: established.unlock_class(class_id)
	var old_ids := established.used_curated_ids.duplicate()
	var loaded := CampaignState.new()
	loaded._load_dict(established.to_dict())
	var seen: Dictionary = {}
	for shift in 24:
		HearthCalendar.advance_shift(loaded)
		for candidate in loaded.get_candidates():
			if new_ids.has(candidate.adventurer.definition_id):
				seen[candidate.adventurer.definition_id] = true
				check(candidate.motivation == AdventurerContent.definition(candidate.adventurer.definition_id).motivation,"Authored recruit motivation did not reach the visitor dossier")
	check(seen.size() == 24,"Not all new recruits entered an established company's visitor waves")
	check(old_ids.all(func(id: Variant): return loaded.used_curated_ids.has(id)),"New visitors erased prior recruit history")
	var retained := CampaignState.new()
	for index in 60: retained._add_calendar_event("assessment","Recorded assessment %d." % index)
	check(retained.calendar_history.size() == 60,"Calendar still truncated a busy day to 40 entries")
	retained.calendar_day = 113
	retained._add_calendar_event("arrivals","A new year begins.")
	check(retained.calendar_history.size() == 1 and int(retained.calendar_history[0].day) == 113,"Rolling calendar history did not retire entries older than 112 days")

	root.size = Vector2i(1280,720)
	var state := MemoryState.new()
	state.campaign.apply_post_tutorial_state("victory")
	for candidate in state.campaign.get_candidates(): state.campaign.recruit_candidate(candidate.id)
	state.campaign.last_presented_wave_id = state.campaign.candidate_wave_id
	state.campaign.calendar_day = 12
	state.campaign.calendar_shift = 1
	state.campaign.construction["recovery"] = {"due_day":15}
	state.campaign.dispatches["80"] = {"expedition_id":80,"active":true,"dungeon_id":"forest","due_day":13,"due_shift_index":24}
	state.campaign.living_roster()[0].status = "recovering"
	state.campaign.living_roster()[0].recovery_until = 14
	state.campaign._add_calendar_event("arrivals","Four travelers arrive for the late shift.")
	var gear := HearthCatalog.gear(state.campaign.living_roster()[0].gear_id)
	var gear_list: Array[GearData] = [gear]
	var tavern := TAVERN.instantiate()
	tavern.setup(null,state,gear_list,"")
	root.add_child(tavern)
	await process_frame
	await process_frame
	tavern.toolbar_buttons["Calendar"].pressed.emit()
	await process_frame
	await process_frame
	check(tavern.management.section == "Calendar","Calendar toolbar still opened Reports")
	var management_calendar: HearthCalendarView = tavern.management.body.get_child(0)
	check(management_calendar.day_buttons.size() == 28,"Management calendar grid missing")
	await capture("management_1280")
	management_calendar.tabs.current_tab = 1
	await process_frame
	await process_frame
	check(management_calendar.history_text.size.y >= 80,"History tab collapsed to an empty strip")
	await capture("history_1280")
	tavern.management.hide()
	tavern._open_calendar()
	await process_frame
	await process_frame
	check(tavern.calendar_view.tabs.current_tab == 0,"Arrival calendar did not offer grid view by default")
	await capture("modal_1280")
	check(tavern.calendar_view.day_buttons[0].get_global_rect().position.y >= 0 and tavern.calendar_view.day_buttons[27].get_global_rect().end.y <= root.get_visible_rect().size.y,"Calendar modal grid overflowed viewport")
	root.size = Vector2i(960,540)
	await process_frame
	await process_frame
	await capture("modal_960")
	check(tavern.calendar_view.grid.get_global_rect().end.x <= root.get_visible_rect().size.x,"Calendar grid overflowed compact viewport")
	tavern._close_modal(tavern.calendar_backdrop)
	tavern.free()
	if failures.is_empty(): print("TAVERN_CALENDAR_TESTS_PASSED"); quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
