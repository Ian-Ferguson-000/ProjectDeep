extends SceneTree

const TAVERN := preload("res://scenes/tavern/Tavern.tscn")
var failures: Array[String] = []

class MemoryState extends RunState:
	var saves := 0
	func autosave_on_floor_entry() -> bool:
		saves += 1
		return true

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png("res://build/shift_%s.png" % name)

func run() -> void:
	root.size = Vector2i(1280,720)
	var state := MemoryState.new()
	state.campaign.apply_post_tutorial_state("victory")
	for candidate in state.campaign.get_candidates(): state.campaign.recruit_candidate(candidate.id)
	state.campaign.last_presented_wave_id = state.campaign.candidate_wave_id
	var gear := HearthCatalog.gear(state.campaign.living_roster()[0].gear_id)
	var gear_list: Array[GearData] = [gear]
	var tavern := TAVERN.instantiate()
	tavern.setup(null,state,gear_list,"")
	root.add_child(tavern)
	await process_frame
	await process_frame
	check(tavern.hud_date_label.text.contains("Early Shift"),"HUD did not show early shift")
	tavern._open_hearth("Reports")
	await process_frame
	var panel: HearthManagement = tavern.management
	check(panel.advance_button.text == "Advance to Late Shift" and not panel.next_event_button.visible,"Initial advance controls were wrong")
	check(panel.bank_label.text.contains("Early Shift"),"Management panel omitted shift")
	capture("early_1280")
	panel.advance_button.grab_focus()
	check(root.gui_get_focus_owner() == panel.advance_button,"Advance control could not receive keyboard focus")
	panel.advance_button.pressed.emit()
	await process_frame
	await process_frame
	check(not panel.visible and tavern.calendar_backdrop.visible and tavern.arrivals_need_sequence,"Shift advance did not present new arrivals")
	check(state.campaign.calendar_shift == 1 and state.saves > 0,"UI transition did not advance or autosave")
	check(tavern.calendar_text.text.contains("Late Shift"),"Arrival calendar omitted late shift")
	capture("arrival_calendar_1280")
	tavern._close_modal(tavern.calendar_backdrop)
	await process_frame
	check(tavern.arrivals_running,"Arrival entrance animation did not start")
	tavern._finish_arrivals()
	check(state.campaign.last_presented_wave_id == state.campaign.candidate_wave_id and tavern.toolbar.visible,"Arrival presentation was not recorded")
	check(tavern.activity_controller.actors.has(state.campaign.get_candidates()[0].id),"New visitors were missing from tavern actors")
	var waiting := state.campaign.get_candidates()[0]
	var assessment_saves := state.saves
	tavern._assess_candidate(waiting.id,"observe","")
	check(waiting.knowledge.equipment == "exact" and state.saves == assessment_saves + 1,"Candidate assessment was not persisted")
	tavern.recruitment_dialogue.close()
	state.campaign.banked_gold = 1000
	var recruitment_saves := state.saves
	tavern._recruit_candidate(waiting.id)
	check(state.campaign.character(waiting.id) != null and state.saves == recruitment_saves + 1,"Recruitment was not persisted")
	tavern._open_hearth("Reports")
	check(panel.advance_button.text == "End Day","Late shift did not offer End Day")
	state.campaign.period_elapsed_shifts = 5
	panel.refresh()
	check(not panel.next_event_button.visible,"Shortcut appeared at five elapsed shifts")
	state.campaign.period_elapsed_shifts = 6
	panel.refresh()
	check(panel.next_event_button.visible,"Shortcut remained hidden at three full days")
	await process_frame
	capture("unlocked_1280")
	root.size = Vector2i(960,540)
	await process_frame
	await process_frame
	check(panel.advance_button.get_global_rect().end.x <= root.size.x and panel.next_event_button.get_global_rect().end.x <= root.size.x,"Advance controls overflow compact viewport")
	capture("unlocked_960")
	panel.hide()
	state.campaign.pending_settlement_summary = {"headline":"Two parties return","reports":[{"expedition_id":1,"headline":"Forest victory","returned":["Brina"],"gold":10,"share":2,"net":8},{"expedition_id":2,"headline":"Crypt retreat","returned":["Eamon"],"gold":5,"share":1,"net":4}]}
	state.campaign.pending_story_event_id = "crisis_open_war"
	tavern._present_time_advance({"ok":true})
	check(tavern.results_backdrop.visible and not tavern.story_dialogue.visible,"Return reports did not precede story dialogue")
	check(tavern.results_text.text.contains("Forest victory") and tavern.results_text.text.contains("Crypt retreat"),"Simultaneous return report text was incomplete")
	await process_frame
	capture("reports_960")
	tavern._close_modal(tavern.results_backdrop)
	await process_frame
	await process_frame
	check(tavern.story_dialogue.visible and not tavern.calendar_backdrop.visible,"Pending story did not precede arrivals")
	tavern.story_dialogue.hide()
	tavern._on_story_finished()
	check(state.campaign.period_elapsed_shifts == 0 and state.campaign.pending_story_event_id.is_empty(),"Completing major dialogue did not reset progress")
	check(state.saves >= 4,"Presentation and story completion were not persisted")
	var snapshot := state.campaign.to_dict()
	tavern.free()
	var reloaded_state := MemoryState.new()
	reloaded_state.campaign._load_dict(snapshot)
	var reloaded := TAVERN.instantiate()
	reloaded.setup(null,reloaded_state,gear_list,"")
	root.add_child(reloaded)
	await process_frame
	await process_frame
	check(not reloaded.arrivals_running and not reloaded.calendar_backdrop.visible and not reloaded.results_backdrop.visible and not reloaded.story_dialogue.visible,"Reload repeated completed arrivals, reports, or story dialogue")
	check(reloaded_state.campaign.character(waiting.id) != null,"Reload lost a recruited visitor")
	reloaded.free()
	if failures.is_empty(): print("TAVERN_SHIFT_UI_TESTS_PASSED"); quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
