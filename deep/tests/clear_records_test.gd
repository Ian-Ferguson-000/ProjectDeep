extends SceneTree

## Dungeons are replayable; guardian defeats record clear times, best overall
## and best per class, and the run clock only counts time spent playing.

const FOREST := preload("res://scenes/slasher/SlasherForest.tscn")

var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	# Formatting.
	_expect(ClearRecords.format_time(754.34) == "12:34.3","format_time: %s" % ClearRecords.format_time(754.34))
	_expect(ClearRecords.format_time(5.0) == "0:05.0" and ClearRecords.format_time(3725.0) == "1:02:05","format_time edge cases")
	_expect(ClearRecords.format_time(0.0) == "--:--","Zero time should show dashes")
	_expect(ClearRecords.format_delta(70.0,60.0) == "+0:10.0" and ClearRecords.format_delta(50.0,60.0) == "-0:10.0","format_delta")

	# Records: first clear, slower, class best, overall record.
	var campaign := CampaignState.new(); campaign.apply_post_tutorial_state("victory")
	var first := ClearRecords.record_clear(campaign,"forest","warrior","Brina",600.0)
	_expect(bool(first.first_clear) and bool(first.best_overall) and bool(first.best_for_class),"First clear should set every best")
	var slower := ClearRecords.record_clear(campaign,"forest","warrior","Brina",700.0)
	_expect(not bool(slower.best_for_class) and not bool(slower.best_overall),"A slower clear replaced a best")
	_expect(String(slower.message).contains("10:00.0"),"Slower clear should quote the class best: %s" % slower.message)
	var mage := ClearRecords.record_clear(campaign,"forest","mage","Eamon",650.0)
	_expect(bool(mage.first_for_class) and bool(mage.best_for_class) and not bool(mage.best_overall),"First mage clear should be a class best but not the record")
	var record := ClearRecords.record_clear(campaign,"forest","mage","Eamon",540.0)
	_expect(bool(record.best_overall) and String(record.message).contains("1:00.0"),"Faster clear should be a new record: %s" % record.message)
	_expect(ClearRecords.clears(campaign,"forest") == 4 and ClearRecords.total_clears(campaign) == 4,"Clear count wrong")
	_expect(String(ClearRecords.best(campaign,"forest").hero) == "Eamon" and is_equal_approx(float(ClearRecords.best(campaign,"forest","warrior").time),600.0),"Bests stored wrongly")
	_expect(ClearRecords.recent(campaign,"forest").size() == 4 and is_equal_approx(float(ClearRecords.recent(campaign,"forest")[0].time),540.0),"Recent runs not newest first")
	for index in 12: ClearRecords.record_clear(campaign,"crypt","rogue","Vex",300.0 + index)
	_expect(ClearRecords.recent(campaign,"crypt").size() == ClearRecords.RECENT_LIMIT,"Recent list not capped")

	# Saved with the campaign; slot summaries count clears.
	var restored := CampaignState.new(); restored._load_dict(campaign.to_dict())
	_expect(ClearRecords.clears(restored,"forest") == 4 and String(ClearRecords.best(restored,"forest").hero) == "Eamon","Records lost on save/load")
	_expect(CampaignState._count_clears(campaign.clear_records) == 16,"Slot summary clear count wrong")

	# A real run: the clock, recording on guardian defeat, and replaying.
	campaign = CampaignState.new(); campaign.apply_post_tutorial_state("victory")
	for candidate in campaign.get_candidates(): campaign.recruit_candidate(candidate.id)
	var hero: CharacterRecord = campaign.living_roster()[0]
	_expect(bool(campaign.launch_expedition([hero.id],"forest").ok),"First expedition did not launch")
	var state := RunState.new(); state.attach_campaign(campaign); state.active_character_id = hero.id; state.start_new_run(null,"forest")
	state.tick_run_clock(42.5); state.tick_run_clock(10.0)
	_expect(is_equal_approx(state.dungeon_clock(),52.5) and is_equal_approx(campaign.expedition.run_seconds,52.5),"Run clock did not tick")
	var saved := ExpeditionState.from_dict(campaign.expedition.to_dict())
	_expect(is_equal_approx(saved.dungeon_seconds,52.5),"Run clock not saved with the expedition")
	var logs := state.record_active_dungeon_completion()
	_expect(ClearRecords.clears(campaign,"forest") == 1 and String(ClearRecords.best(campaign,"forest","%s" % hero.class_id).hero) == hero.display_name,"Guardian defeat did not record a clear")
	_expect(logs.has("First clear in 0:52.5."),"Clear message missing from the run log: %s" % str(logs))
	_expect(not state.last_clear.is_empty(),"Result screen data missing")
	state.finish_run("victory","Victory")
	_expect(campaign.has_completed_dungeon("forest"),"First guardian defeat should still unlock things")
	_expect(state.is_dungeon_unlocked("forest") and state.dungeon_available("forest"),"Forest closed after being cleared")
	campaign.calendar_day += 1
	for member in campaign.living_roster(): member.current_health = member.max_health; member.recovery_until = 0; member.status = CharacterRecord.STATUS_AVAILABLE
	var again := campaign.launch_expedition([hero.id],"forest")
	_expect(bool(again.ok),"A cleared dungeon could not be replayed: %s" % String(again.get("error","")))
	_expect(is_equal_approx(campaign.expedition.run_seconds,0.0),"A new expedition did not reset the clock")

	# Tutorial runs never set records.
	var tutorial := CampaignState.new()
	tutorial.expedition.begin([],"forest",true)
	var tutorial_state := RunState.new(); tutorial_state.attach_campaign(tutorial)
	tutorial_state.tick_run_clock(30.0); tutorial_state.record_active_dungeon_completion()
	_expect(tutorial.clear_records.is_empty(),"The tutorial set a clear time")

	# In the dungeon: the HUD clock runs during play and stops in menus.
	var scene = FOREST.instantiate(); scene._ensure_designer_controls(); scene.run_state = state; root.add_child(scene)
	for frame in 5: await process_frame
	for node in root.find_children("*","",true,false):
		if node.get_script() and String(node.get_script().resource_path).contains("relic_choice_modal"): node.hide()
	if scene.relic_modal: scene.relic_modal.hide()
	paused = false
	var label: Label = scene.clock_label
	_expect(label != null and label.visible,"Dungeon HUD has no clock")
	var before := state.dungeon_clock()
	for frame in 30: await process_frame
	_expect(state.dungeon_clock() > before,"The clock did not run during play")
	_expect(label.text.contains("best"),"HUD clock does not show the class best: %s" % label.text)
	scene.codex.show()
	before = state.dungeon_clock()
	for frame in 20: await process_frame
	_expect(is_equal_approx(state.dungeon_clock(),before),"The clock ran with a menu open")
	scene.queue_free()
	await process_frame

	if failures.is_empty(): print("CLEAR_RECORDS_TESTS_PASSED"); quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(value: bool, message: String) -> void:
	if not value and not failures.has(message): failures.append(message)
