extends SceneTree
var failures: Array[String] = []
var capture := false
class MemoryState extends RunState:
	var saves := 0
	func autosave_on_floor_entry() -> bool:
		saves += 1
		return true
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func run() -> void:
	capture = OS.get_cmdline_user_args().has("--capture")
	for viewport_size in [Vector2i(1280,720), Vector2i(960,540)]:
		root.size = viewport_size; root.content_scale_size = viewport_size
		var state := MemoryState.new(); state.campaign.apply_post_tutorial_state("victory")
		for candidate in state.campaign.get_candidates(): state.campaign.recruit_candidate(candidate.id)
		state.campaign.last_presented_wave_id = state.campaign.candidate_wave_id
		var names: Array = state.campaign.living_roster().map(func(member): return member.display_name)
		var summary := {"headline":"Balors Hell: Victory", "reports":[{"headline":"Balors Hell: Victory","outcome":"victory","dungeon":"balors_hell","depth":5,"deployment_type":"manual","gold":2044,"share":408,"net":1636,"returned":names,"items":["Seal of the Breach"],"essence":3}],"slasher_progression":"Arcanist · 1 ability upgrade","changes":["Balor Seal pressure now 15%; resources 35%; stability 85%.","Objective fulfilled: Suppress the Breach. Aligned traditions recognize the Hearth's choice."]}
		state.campaign.pending_settlement_summary = summary.duplicate(true)
		var tavern = load("res://scenes/tavern/Tavern.tscn").instantiate()
		var gear_list: Array[GearData] = []
		tavern.setup(null,state,gear_list,"",summary); root.add_child(tavern)
		await process_frame; await process_frame
		var panel = tavern.results_backdrop.get_child(0)
		panel.set_process(false); panel._process(1.2)
		check(panel.victorious and panel.crest.victorious, "Victory presentation not selected")
		check(panel.reward_totals == [2044,408,1636] and panel.reward_labels[2].text == "1636", "Reward totals/animation incorrect")
		check(panel.party_cards.get_child_count() == names.size() and names.size() == 2, "Returning hero cards missing")
		check(tavern.activity_controller.paused and not tavern.keeper.input_enabled, "Results do not pause the tavern")
		check(panel.details.text.contains("Seal of the Breach") and panel.details.text.contains("Suppress the Breach"), "Progress or loot details omitted")
		check(panel.position.x >= 0 and panel.position.y >= 0 and panel.size.x <= viewport_size.x and panel.size.y <= viewport_size.y, "Result panel overflows viewport")
		check(panel.continue_button.get_global_rect().end.y <= viewport_size.y and panel.report_scroll.size.y > 70, "Footer/details clipped at compact viewport")
		var before := state.campaign.to_dict()
		panel.present(summary,state,""); panel._process(0.6)
		check(int(panel.reward_labels[2].text) > 0 and int(panel.reward_labels[2].text) < 1636, "Reward count-up does not reset")
		panel._process(0.6)
		if capture:
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/expedition_victory_%dx%d.png" % [viewport_size.x,viewport_size.y])
		var mixed := {"headline":"Two parties return","reports":[summary.reports[0],{"headline":"Crypt retreat","outcome":"retreat","gold":10,"share":2,"net":8,"lost":["A fallen friend"]}]}
		panel.present(mixed,state,"")
		check(not panel.victorious and panel.reward_totals == [2054,410,1644], "Mixed outcomes celebrate defeat or miscount rewards")
		check(panel.details.text.contains("Crypt retreat") and panel.details.text.contains("A fallen friend"), "Multiple reports or losses missing")
		panel.present({"outcome":"death","headline":"Crypt: Death","lost":["A fallen friend"]},state,"")
		check(not panel.victorious and panel.title_label.text == "The Fallen Remembered", "Defeat uses victory celebration")
		if capture:
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/expedition_defeat_%dx%d.png" % [viewport_size.x,viewport_size.y])
		panel.present({},state,"Welcome home")
		check(not panel.victorious and panel.details.text.contains("Welcome home"), "Message-only return broken")
		check(state.campaign.to_dict() == before, "Presentation changed campaign settlement")
		tavern._close_top_modal()
		check(not tavern.results_backdrop.visible and state.campaign.pending_settlement_summary.is_empty() and state.saves == 1, "Dismissal failed to clear/save the report")
		check(not tavern.activity_controller.paused and tavern.keeper.input_enabled, "Dismissal did not restore tavern controls")
		tavern.queue_free(); await process_frame
	if failures.is_empty(): print("EXPEDITION_RESULTS_TESTS_PASSED"); quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
