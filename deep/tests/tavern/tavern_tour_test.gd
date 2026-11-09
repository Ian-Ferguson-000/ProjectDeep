extends SceneTree

## The first-visit tavern guide: starts by itself once the tavern is free after
## the tutorial, opens each Hearth page and spotlights a real button on every
## step, saves that it's been seen, never starts again by itself, and can be
## replayed from the Esc menu.

const TAVERN := preload("res://game/tavern/2d/Tavern.tscn")
var failures: Array[String] = []

class MemoryState extends RunState:
	var saves := 0
	func autosave_on_floor_entry() -> bool:
		saves += 1
		return true

func _initialize() -> void: _run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _frames(count: int) -> void:
	for i in count: await process_frame

func _tavern(state: RunState):
	var gear_list: Array[GearData] = [HearthCatalog.gear(state.campaign.living_roster()[0].gear_id)]
	var tavern = TAVERN.instantiate(); tavern.setup(null,state,gear_list,""); root.add_child(tavern)
	await _frames(6)
	return tavern

func _run() -> void:
	root.size = Vector2i(1280,720)
	var state := MemoryState.new()
	state.campaign.apply_post_tutorial_state("victory")
	for candidate in state.campaign.get_candidates(): state.campaign.recruit_candidate(candidate.id)
	state.campaign.last_presented_wave_id = state.campaign.candidate_wave_id
	_expect(not TavernTour.done(state.campaign),"A new company has already seen the guide")
	var tavern = await _tavern(state)
	var tour: TavernTour = tavern.tavern_tour
	_expect(tour != null,"The guide didn't start on the first free visit to the tavern")
	if tour == null:
		tavern.start_tavern_tour(); await _frames(2); tour = tavern.tavern_tour
	# Every step: the page opens and its spotlight target is on screen.
	for index in TavernTour.STEPS.size():
		tour.show_step(index); await _frames(3)
		var data: Dictionary = TavernTour.STEPS[index]
		if not String(data.page).is_empty():
			_expect(tavern.management.visible and tavern.management.section == String(data.page),"Step %d didn't open the %s page" % [index + 1,data.page])
		else:
			_expect(not tavern.management.visible,"Step %d should show the tavern floor" % [index + 1])
		if not String(data.target).is_empty():
			_expect(tour.current_target() != null and tour.dim.hole.size != Vector2.ZERO,"Step %d (%s): no spotlight on %s" % [index + 1,data.title,data.target])
	# Back works, then finish from the last step.
	tour.show_step(3); await _frames(3)
	(tour.find_child("Back",true,false) as Button).pressed.emit(); await _frames(3)
	_expect(tour.step == 2,"Back didn't go back a step")
	tour.show_step(TavernTour.STEPS.size() - 1); await _frames(3)
	var saves_before := state.saves
	(tour.find_child("Next",true,false) as Button).pressed.emit(); await _frames(3)
	_expect(tavern.tavern_tour == null and not is_instance_valid(tour),"Finish didn't close the guide")
	_expect(TavernTour.done(state.campaign) and state.saves > saves_before,"Finishing didn't save that the guide was seen")
	_expect(not tavern.management.visible,"The Hearth was left open after the guide")
	# Not again by itself.
	tavern._restore_hub_focus(); await _frames(3)
	_expect(tavern.tavern_tour == null,"The guide started again after it was finished")
	# The Esc menu replays it.
	var menu: GamePauseMenu = tavern.pause_menu
	menu.open(); await process_frame
	var guide_button := menu.body.find_child("TavernGuide",true,false) as Button
	_expect(guide_button != null,"The tavern's Esc menu has no Tavern Guide")
	if guide_button != null:
		guide_button.pressed.emit(); await _frames(3)
		_expect(tavern.tavern_tour != null and not paused,"Tavern Guide didn't replay the guide")
		if tavern.tavern_tour != null:
			(tavern.tavern_tour.find_child("Skip",true,false) as Button).pressed.emit(); await _frames(2)
			_expect(tavern.tavern_tour == null,"Skip didn't close the guide")
	tavern.queue_free(); await _frames(2)

	# A company that has seen it doesn't get it again on a new visit.
	var seen := MemoryState.new()
	seen.campaign.apply_post_tutorial_state("victory")
	for candidate in seen.campaign.get_candidates(): seen.campaign.recruit_candidate(candidate.id)
	seen.campaign.last_presented_wave_id = seen.campaign.candidate_wave_id
	TavernTour.mark_done(seen.campaign)
	var again = await _tavern(seen)
	_expect(again.tavern_tour == null,"The guide started for a company that has seen it")
	again.queue_free(); await _frames(2)

	if failures.is_empty():
		print("TAVERN_TOUR_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures: printerr("FAIL: " + failure)
		quit(1)
