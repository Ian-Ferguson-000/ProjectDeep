extends SceneTree

## progression.json "enabled_actions": basic attacks and movement work, while the
## control tutorial skips the special and defend steps.

var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	GameBalance.set_actions_override(null)
	_expect(GameBalance.action_enabled("basic"),"Basic attacks should be on")
	_expect(GameBalance.action_enabled("movement"),"Movement should be on")
	_expect(is_equal_approx(float(GameBalance.get_slasher_class_tuning("mage").get("speed",0.0)),277.5),"Mage speed should include the 50% increase")
	for slot in ["special","defensive"]: _expect(not GameBalance.action_enabled(slot),"%s should be switched off" % slot)
	var state := RunState.new(); state.set_class("warrior"); state.start_new_run(null,"forest")
	state.class_resource = state.get_class_resource_max()
	var player := SlasherPlayer.new(); player.setup(state); root.add_child(player); player.set_physics_process(false)
	await process_frame
	_expect(bool(player.use_action("basic").started),"Basic attack did not work")
	player.cooldowns.movement=0.0
	_expect(bool(player.use_action("movement").started),"Movement did not work")
	for slot in ["special","defensive"]:
		var result := player.use_action(slot)
		_expect(not bool(result.started) and String(result.failure) == "disabled","%s still works" % slot)
	_expect(state.class_resource == state.get_class_resource_max(),"A disabled action spent resource")
	var tutorial := ForestTutorialSequence.new(); root.add_child(tutorial)
	tutorial.begin(1,Vector2.ZERO)
	tutorial.observe_ability({"started":true,"slot":"basic","input_source":"mouse"})
	_expect(tutorial.current_step == 2,"Tutorial skipped the enabled movement step (step %d)" % tutorial.current_step)
	tutorial.begin(2,Vector2.ZERO)
	_expect(tutorial.current_step == 2,"A saved tutorial did not restore the enabled movement step")
	tutorial.observe_ability({"started":true,"slot":"movement","input_source":"mouse"})
	_expect(tutorial.current_step == 5,"Tutorial did not skip the switched-off steps (step %d)" % tutorial.current_step)
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
