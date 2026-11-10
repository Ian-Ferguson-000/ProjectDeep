extends SceneTree

## Run seeds and abandoning a run.
## - Codes round-trip and bad codes are refused; seeds can be saved and forgotten.
## - The same seed builds the same floors, rooms, foes, trader stock and drops.
## - The seed survives a save/resume and shows in the pause menu.
## - Abandon Run goes home to the tavern as a retreat, keeping only secured gold.


func _init() -> void:
	GameBalance.set_actions_override(GameBalance.ALL_ACTIONS)


const FOREST := preload("res://game/dungeons/forest/SlasherForest.tscn")
const SLOT := 3
var failures: Array[String] = []


func _initialize() -> void:
	RunState.coin_value_override = 1  # secured-gold arithmetic in plain gold
	_run.call_deferred()


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _free_modals() -> void:
	for node in root.find_children("*", "", true, false):
		if (
			node.get_script()
			and String(node.get_script().resource_path).contains("relic_choice_modal")
		):
			node.queue_free()
	paused = false


## Builds a seeded forest run and walks a few rooms, recording what's in them.
func _fingerprint(seed_value: int) -> Dictionary:
	var state := RunState.new()
	state.requested_seed = seed_value
	state.start_new_run(GearData.create("t", "Tester", 3, false, 0, "", "", "warrior"), "forest")
	var scene = FOREST.instantiate()
	scene._ensure_designer_controls()
	scene.run_state = state
	root.add_child(scene)
	await _frames(4)
	await _free_modals()
	var rooms: Array = []
	for value in state.field_run.rooms:
		rooms.append("%s:%s" % [String(value.role), str(value.get("neighbors", {}))])
	var visited: Array = []
	for value in state.field_run.rooms.slice(0, 4):
		state.field_run["current_room"] = int(value.id)
		state.field_run["previous_room"] = -1
		scene._build_floor()
		await _frames(2)
		await _free_modals()
		var foes: Array = (
			scene
			. actor_layer
			. get_children()
			. filter(func(n): return n is SlasherEnemy)
			. map(func(n): return "%s@%s" % [n.visual_id, n.global_position.round()])
		)
		foes.sort()
		visited.append(
			(
				"%s|%s|%s"
				% [
					String(scene.layout.get("template_id", "")),
					",".join(foes),
					str(snappedf(scene.drop_rng().randf(), 0.0001))
				]
			)
		)
	var trader := state.trader_offers("trader").map(func(o): return String(o.get("id", "")))
	var result := {
		"code": state.seed_code(),
		"rooms": rooms,
		"visited": visited,
		"trader": trader,
		"seeded": state.run_seeded
	}
	scene.queue_free()
	await _frames(2)
	return result


func _run() -> void:
	root.size = Vector2i(1280, 720)
	# ---- codes
	for value in [1, 12345, RunSeed.random_value(), RunSeed.random_value()]:
		_expect(
			RunSeed.decode(RunSeed.encode(value)) == value,
			"Seed %d didn't survive encode/decode" % value
		)
	var code := RunSeed.encode(424242)
	_expect(
		RunSeed.decode(code.to_lower().replace("-", " ")) == 424242,
		"Codes should ignore case, spaces and dashes"
	)
	for bad in ["", "ABC", "ABCD-EFG0", "ABCD-EFGI", "ABCDEFGHJ"]:
		_expect(not RunSeed.is_valid(bad), "'%s' should not be a valid seed" % bad)
	# ---- saved seeds
	var test_code := RunSeed.encode(777777)
	RunSeed.forget(test_code)
	_expect(
		RunSeed.save_seed(test_code, "test note") and RunSeed.is_saved(test_code),
		"Saving a seed failed"
	)
	_expect(String(RunSeed.saved()[0].note) == "test note", "A saved seed lost its note")
	RunSeed.forget(test_code)
	_expect(not RunSeed.is_saved(test_code), "Forgetting a seed failed")

	# ---- same seed, same run
	var first: Dictionary = await _fingerprint(987654321)
	var second: Dictionary = await _fingerprint(987654321)
	_expect(
		first.code == RunSeed.encode(987654321) and first.seeded,
		"The run didn't use the chosen seed (%s)" % first.code
	)
	_expect(first.rooms == second.rooms, "Same seed, different floor map")
	_expect(
		first.visited == second.visited,
		"Same seed, different rooms/foes/drops:\n%s\n%s" % [first.visited, second.visited]
	)
	_expect(first.trader == second.trader, "Same seed, different trader stock")
	var other: Dictionary = await _fingerprint(123456789)
	_expect(
		other.rooms != first.rooms or other.visited != first.visited,
		"Different seeds built the same run"
	)
	var unseeded := RunState.new()
	unseeded.start_new_run(GearData.create("t", "Tester", 3, false, 0, "", "", "warrior"), "forest")
	_expect(
		not unseeded.run_seeded and unseeded.requested_seed == 0, "A normal run is marked as seeded"
	)
	# The seed is kept by the run snapshot (saves and resumes).
	var resumed := RunState.new()
	resumed.current_floor = unseeded.current_floor
	resumed.restore_run_snapshot(unseeded.run_snapshot())
	_expect(resumed.seed_code() == unseeded.seed_code(), "The seed was lost across a save")

	# ---- abandon run, through the real game
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CampaignState.save_path(SLOT)))
	var main = load("res://game/main/Main.tscn").instantiate()
	root.add_child(main)
	await _frames(2)
	var campaign := CampaignState.new()
	campaign.save_slot = SLOT
	campaign.apply_post_tutorial_state("victory")
	for candidate in campaign.get_candidates():
		campaign.recruit_candidate(candidate.id)
	main.campaign = campaign
	main.run_state = RunState.new()
	main.run_state.attach_campaign(campaign)
	var hero: CharacterRecord = campaign.living_roster()[0]
	var ids: Array[String] = [hero.id]
	main.run_state.requested_seed = RunSeed.decode("K7QF-2MXA")
	main.start_dungeon("forest", HearthCatalog.gear(hero.gear_id), ids)
	await _frames(6)
	await _free_modals()
	await _frames(2)
	var scene = main.current_scene
	_expect(
		main.run_state.seed_code() == "K7QF-2MXA", "A seed chosen before setting out wasn't used"
	)
	var menu: GamePauseMenu = scene.pause_menu
	menu.open()
	await process_frame
	var seed_label := menu.body.find_child("SeedLabel", true, false) as Label
	_expect(
		seed_label != null and seed_label.text.contains("K7QF-2MXA"),
		"The pause menu doesn't show the seed"
	)
	_expect(
		menu.body.find_child("AbandonRun", true, false) != null, "The pause menu has no Abandon Run"
	)
	campaign.expedition.secured_gold = 30
	main.run_state.gold = 75
	var bank_before := campaign.banked_gold
	menu.show_page("confirm_abandon")
	await process_frame
	(menu.body.find_child("Confirm", true, false) as Button).pressed.emit()
	await _frames(6)
	_expect(
		String(main.current_scene.name) in ["Tavern", "Tavern3D"],
		"Abandoning didn't go back to the tavern (%s)" % main.current_scene.name
	)
	_expect(not campaign.expedition.active, "The expedition is still active after abandoning")
	_expect(not paused, "The game was left paused")
	_expect(
		(
			campaign.memorial.filter(func(m): return String(m.get("id", "")) == hero.id).is_empty()
			and campaign.retired_heroes.any(func(r): return String(r.get("id", "")) == hero.id)
		),
		"The adventurer died instead of coming home and retiring"
	)
	_expect(
		campaign.banked_gold > bank_before and campaign.banked_gold - bank_before <= 30,
		(
			"Abandoning should bank only the secured gold (banked %d)"
			% (campaign.banked_gold - bank_before)
		)
	)
	main.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CampaignState.save_path(SLOT)))

	if failures.is_empty():
		print("RUN_SEED_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)
