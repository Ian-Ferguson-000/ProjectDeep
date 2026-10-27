extends SceneTree

## progression.json "enabled_actions": only basic attacks work, and the control
## tutorial skips the dash, special and defend steps.

var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	GameBalance.set_actions_override(null)
	_expect(GameBalance.action_enabled("basic"),"Basic attacks should be on")
	for slot in ["movement","special","defensive"]: _expect(not GameBalance.action_enabled(slot),"%s should be switched off" % slot)
	var state := RunState.new(); state.set_class("warrior"); state.start_new_run(null,"forest")
	state.class_resource = state.get_class_resource_max()
	var player := SlasherPlayer.new(); player.setup(state); root.add_child(player); player.set_physics_process(false)
	await process_frame
	_expect(bool(player.use_action("basic").started),"Basic attack did not work")
	for slot in ["movement","special","defensive"]:
		var result := player.use_action(slot)
		_expect(not bool(result.started) and String(result.failure) == "disabled","%s still works" % slot)
	_expect(state.class_resource == state.get_class_resource_max(),"A disabled action spent resource")
	var tutorial := ForestTutorialSequence.new(); root.add_child(tutorial)
	tutorial.begin(1,Vector2.ZERO)
	tutorial.observe_ability({"started":true,"slot":"basic","input_source":"mouse"})
	_expect(tutorial.current_step == 5,"Tutorial did not skip the switched-off steps (step %d)" % tutorial.current_step)
	tutorial.begin(2,Vector2.ZERO)
	_expect(tutorial.current_step == 5,"A saved tutorial on a switched-off step got stuck")
	GameBalance.set_actions_override(GameBalance.ALL_ACTIONS)
	_expect(bool(player.use_action("special").started),"Switching actions back on did not restore them")
	GameBalance.set_actions_override(null)
	player.free(); tutorial.free()
	if failures.is_empty(): print("BASIC_ONLY_TESTS_PASSED"); quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(value: bool, message: String) -> void:
	if not value and not failures.has(message): failures.append(message)
