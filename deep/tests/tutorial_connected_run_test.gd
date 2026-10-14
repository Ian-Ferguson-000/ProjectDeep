extends SceneTree

class TestRunState extends RunState:
	var save_count := 0
	func autosave_on_floor_entry() -> bool:
		save_count += 1
		return true

class FlowController extends "res://scripts/main.gd":
	var returns: Array[String] = []
	var loaded_dungeon := ""
	var connection_dialogues := 0
	var progression_prompts := 0
	func _ready() -> void: pass
	func _load_active_dungeon() -> void:
		loaded_dungeon = run_state.active_dungeon_id
	func _show_connected_dungeon_dialogue(_lines: Array[Dictionary]) -> void:
		connection_dialogues += 1
		_on_connected_dungeon_dialogue_finished(null)
	func _show_slasher_progression(on_complete: Callable) -> void:
		progression_prompts += 1
		on_complete.call()
	func return_to_tavern(outcome: String, _message: String) -> void:
		returns.append(outcome)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var campaign := CampaignState.new()
	campaign.tutorial_phase = CampaignState.TUTORIAL_EXPEDITION
	var alden := campaign.create_tutorial_adventurer()
	assert(campaign.begin_expedition([alden.id], "forest", true))
	campaign.expedition.tutorial_controls_complete = true
	campaign.expedition.tutorial_step = ForestTutorialSequence.STEP_COUNT
	var state := TestRunState.new()
	state.attach_campaign(campaign)
	state.active_character_id = alden.id
	state.start_new_run(null, "forest")
	var controller := FlowController.new()
	controller.campaign = campaign
	controller.run_state = state
	root.add_child(controller)
	controller.complete_slasher_forest_floor()
	assert(state.current_floor == 2 and controller.loaded_dungeon == "forest" and controller.returns.is_empty(), "Tutorial still must advance ordinary forest floors")
	state.gain_xp(1700, "forest boss progression fixture")
	state.current_floor = state.max_floors
	campaign.expedition.floor = state.current_floor
	state.gold = 37
	state.add_consumable("healing_potion")
	state.add_inventory_item("giant_bane_grip", 1)
	state.current_health = 2
	var inventory := state.inventory_items.duplicate(true)
	var provisions := state.consumable_items.duplicate()
	var xp := int(state.hero_profiles["warrior"].total_xp)
	var gear := state.selected_gear
	controller.complete_slasher_forest_floor()
	assert(controller.returns.is_empty(), "Tutorial returned to the tavern after forest")
	assert(state.active_dungeon_id == "crypt" and state.current_floor == 1 and controller.loaded_dungeon == "crypt", "Tutorial did not follow the normal Forest-to-Crypt transition")
	assert(state.forest_cleared and state.has_completed_dungeon("forest") and campaign.has_completed_dungeon("forest"), "Tutorial continuation missed forest clear credit")
	assert(campaign.expedition.active and campaign.expedition.dungeon_id == "crypt" and campaign.expedition.tutorial_run, "Transition settled or lost the tutorial expedition")
	assert(state.active_character_id == alden.id and state.current_health > 0 and state.gold == 37 and state.selected_gear == gear and state.inventory_items == inventory and state.consumable_items == provisions and int(state.hero_profiles["warrior"].total_xp) == xp, "Connected transition reset the adventurer or carried progress")
	assert(campaign.tutorial_phase == CampaignState.TUTORIAL_EXPEDITION and not campaign.post_tutorial_initialized, "Forest clear prematurely applied the tutorial epilogue")
	assert(controller.progression_prompts > 0 and controller.connection_dialogues == 1 and state.save_count >= 2, "Tutorial bypassed normal progression, connecting dialogue or saves")
	var restored := CampaignState.new()
	restored._load_dict(campaign.to_dict())
	assert(restored.expedition.active and restored.expedition.dungeon_id == "crypt" and restored.expedition.floor == 1 and restored.expedition.tutorial_controls_complete, "Save round-trip lost the continued tutorial run")
	state.current_floor = int(GameBalance.get_dungeon("crypt").floors)
	controller.complete_slasher_dungeon_floor()
	assert(state.active_dungeon_id == "balors_hell" and state.current_floor == 1 and controller.loaded_dungeon == "balors_hell" and controller.returns.is_empty(), "Tutorial Crypt clear did not continue to Balor's Hell")
	state.current_floor = int(GameBalance.get_dungeon("balors_hell").floors)
	controller.complete_slasher_dungeon_floor()
	assert(controller.returns == ["victory"], "Connected tutorial did not finish at the end of the normal route")
	controller.queue_free()
	await process_frame
	print("Tutorial connected run: Forest → Crypt → Balor's Hell, carried progress, normal progression, save round-trip and final return passed.")
	quit()
