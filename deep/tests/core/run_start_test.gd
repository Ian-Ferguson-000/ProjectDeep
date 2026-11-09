extends SceneTree

## A run starts with no free relic: no relic choice opens on floor 1 and the
## adventurer carries nothing (slasher_balance.json → run_start.starter_relic).

const FOREST := preload("res://game/dungeons/forest/SlasherForest.tscn")
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	var state := RunState.new()
	state.start_new_run(GearData.create("t","Tester",3,false,0,"","","warrior"),"forest")
	var forest = FOREST.instantiate(); forest._ensure_designer_controls(); forest.run_state = state; root.add_child(forest)
	for i in 10: await process_frame
	_expect(not forest.starter_relic_enabled(),"The starter relic should be off")
	_expect(forest.relic_modal == null or not forest.relic_modal.visible,"A relic choice opened at the start of the run")
	_expect(not paused,"The run started paused (a choice window is up)")
	_expect(state.inventory_items.is_empty(),"The run started with relics: %s" % [state.inventory_items])
	forest._offer_starter_relic(); await process_frame
	_expect(forest.relic_modal == null or not forest.relic_modal.visible,"The starter relic could still be offered")
	forest.queue_free(); for i in 2: await process_frame
	if failures.is_empty():
		print("RUN_START_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures: printerr("FAIL: " + failure)
		quit(1)
