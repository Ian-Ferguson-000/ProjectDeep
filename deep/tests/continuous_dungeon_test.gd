extends SceneTree

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
	state.mark_extraction_available()
	state.record_active_dungeon_completion()
	_expect(campaign.has_completed_dungeon("forest"), "Forest completion was not awarded before descent", failures)
	_expect(state.is_dungeon_unlocked("crypt"), "Crypt did not unlock at the completion checkpoint", failures)
	var preserved_health := state.current_health
	_expect(state.transition_to_dungeon("crypt"), "Continuous transition into the Crypt failed", failures)
	_expect(state.active_dungeon_id == "crypt" and campaign.expedition.dungeon_id == "crypt" and state.active_play_mode == "strategy", "Active expedition did not change to the Crypt in the same mode", failures)
	_expect(state.current_floor == 1 and state.max_floors == 7, "Crypt floor state was not initialized", failures)
	_expect(state.gold == 73 and state.keys == 2 and state.current_health == preserved_health, "Carried run resources changed during descent", failures)
	_expect(state.get_consumables().has("healing_potion"), "Consumables did not survive descent", failures)
	_expect(not state.can_extract(), "The prior dungeon extraction point remained active", failures)
	if failures.is_empty():
		print("CONTINUOUS_DUNGEON_TESTS_PASSED")
		quit(0)
		return
	for failure in failures: push_error(failure)
	quit(1)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition: failures.append(message)
