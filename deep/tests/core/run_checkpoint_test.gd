extends SceneTree

## Mid-floor saves: entering a room and clearing it save the run, so a crash
## (here: throwing away the game and loading the slot from disk) puts you back
## in the same room with the same gold, keys and cleared rooms.

func _init() -> void: GameBalance.set_actions_override(GameBalance.ALL_ACTIONS)

const SLOT := 3
var failures: Array[String] = []

func _initialize() -> void:
	SimpleCombat.dodge_override = 0.0  # every hit must land in this test
	_run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _frames(count: int) -> void:
	for i in count: await process_frame

func _free_modals() -> void:
	for node in root.find_children("*","",true,false):
		if node.get_script() and String(node.get_script().resource_path).contains("relic_choice_modal"): node.queue_free()
	paused = false

func _is_rooms(node) -> bool:
	return node != null and node.has_method("_save_checkpoint")

func _run() -> void:
	root.size = Vector2i(1280,720)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CampaignState.save_path(SLOT)))
	var main = load("res://game/main/Main.tscn").instantiate(); root.add_child(main)
	await _frames(2)
	var campaign := CampaignState.new(); campaign.save_slot = SLOT
	campaign.apply_post_tutorial_state("victory")
	for candidate in campaign.get_candidates(): campaign.recruit_candidate(candidate.id)
	main.campaign = campaign; main.run_state = RunState.new(); main.run_state.attach_campaign(campaign)
	var hero: CharacterRecord = campaign.living_roster()[0]
	var ids: Array[String] = [hero.id]
	main.start_dungeon("forest",HearthCatalog.gear(hero.gear_id),ids)
	await _frames(6); await _free_modals(); await _frames(2)
	var scene = main.current_scene
	_expect(_is_rooms(scene),"The run didn't start in the forest rooms (%s)" % scene)
	if not _is_rooms(scene): return _finish()
	_expect(campaign.expedition.active,"No active expedition")
	# Clear the start room's neighbour: walk into it, kill everything, then move on again.
	var state: RunState = main.run_state
	var start_room := int(state.field_run.current_room)
	var neighbor := int(Dictionary(state.get_field_room(start_room).neighbors).values()[0])
	state.enter_field_room(neighbor,start_room); scene._build_floor(); await _frames(3); await _free_modals()
	for foe in scene.actor_layer.get_children().filter(func(n): return n is SlasherEnemy):
		foe.health = 1; foe.receive_hit(99)
	await _frames(20)
	_expect(bool(state.get_field_room(neighbor).get("cleared",false)),"The fought room isn't marked cleared")
	state.gold = 77; state.keys = 2
	scene._save_checkpoint()
	var health_before: int = scene.player.health
	var key_before := String(state.field_run.forest_floor_key)

	# "Crash": throw the game away and load the slot fresh from disk.
	main.queue_free(); await _frames(2)
	paused = false
	var main2 = load("res://game/main/Main.tscn").instantiate(); root.add_child(main2)
	await _frames(2)
	main2.continue_from_slot(SLOT)
	await _frames(6); await _free_modals(); await _frames(2)
	var resumed: RunState = main2.run_state
	_expect(_is_rooms(main2.current_scene),"Continuing didn't go back into the dungeon")
	_expect(String(resumed.field_run.get("forest_floor_key","")) == key_before,"Resumed on a different floor map")
	_expect(int(resumed.field_run.get("current_room",-1)) == neighbor,"Resumed in room %d, not %d" % [int(resumed.field_run.get("current_room",-1)),neighbor])
	_expect(bool(resumed.get_field_room(neighbor).get("cleared",false)),"The cleared room came back uncleared")
	_expect(resumed.gold == 77 and resumed.keys == 2,"Gold/keys lost: %d gold, %d keys" % [resumed.gold,resumed.keys])
	if _is_rooms(main2.current_scene):
		_expect(main2.current_scene.player.health == health_before,"Health %d after resume, was %d" % [main2.current_scene.player.health,health_before])
		_expect(main2.current_scene.actor_layer.get_children().filter(func(n): return n is SlasherEnemy and not n.dead).is_empty(),"Foes came back in the cleared room")
	main2.queue_free()
	_finish()

func _finish() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CampaignState.save_path(SLOT)))
	if failures.is_empty():
		print("RUN_CHECKPOINT_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures: printerr("FAIL: " + failure)
		quit(1)
