extends SceneTree

const MAIN:=preload("res://scripts/main.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var campaign := CampaignState.new()
	campaign.tutorial_phase = CampaignState.TUTORIAL_COMPLETE
	campaign.ensure_roster()
	var party := campaign.default_party("forest")
	_expect(campaign.begin_expedition(party, "forest", "strategy"), "Forest expedition could not begin", failures)
	var state := RunState.new()
	state.attach_campaign(campaign)
	state.active_character_id = party[0]
	state.start_new_run(null, "forest", "strategy")
	state.gold = 73
	state.keys = 2
	state.current_health = maxi(1, state.max_health - 4)
	state.add_consumable("healing_potion")
	state.current_floor = state.max_floors
	state.record_floor_checkpoint()
	state.record_active_dungeon_completion()
	_expect(campaign.has_completed_dungeon("forest"), "Forest completion was not awarded before descent", failures)
	_expect(state.is_dungeon_unlocked("crypt"), "Crypt did not unlock at the completion checkpoint", failures)
	_expect(not state.can_extract(), "Boss-bound expedition exposed extraction", failures)
	var main:=MAIN.new();_expect(not main.has_method("extract_expedition") and not main.has_method("_show_extraction_choice"),"Player-facing extraction route still exists",failures);main.free()
	if failures.is_empty():
		print("CONTINUOUS_DUNGEON_TESTS_PASSED")
		quit(0)
		return
	for failure in failures: push_error(failure)
	quit(1)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition: failures.append(message)
