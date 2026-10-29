extends SceneTree

## The Isaac-style dungeon HUD: hearts and counters bottom left, the run's relics
## top left, updating when a relic is picked up or health drops.

const FOREST := preload("res://scenes/slasher/SlasherForest.tscn")
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	var state := RunState.new()
	state.start_new_run(GearData.create("h","H",3,false,0,"","","warrior"),"forest")
	var scene = FOREST.instantiate(); scene._ensure_designer_controls(); scene.run_state = state; root.add_child(scene)
	for i in 4: await process_frame
	paused = false
	var hud: DungeonHud = scene.dungeon_hud
	_expect(hud != null,"No dungeon HUD")
	if hud != null:
		var viewport_height: float = root.get_visible_rect().size.y
		_expect(hud.heart_count() == int(ceil(scene.player.max_health / 4.0)),"Heart count does not follow max health")
		_expect(hud._hearts_top() > viewport_height * 0.7,"Hearts are not along the bottom")
		_expect(hud._counters.position.y > viewport_height * 0.7 and hud._counters.position.x < 100,"Coins and keys are not bottom left")
		_expect(hud.potion_slot.visible and hud.potion_slot.position.x < 60 and hud.potion_slot.position.y > viewport_height * 0.8,"Potion slot is not in the bottom-left corner")
		_expect(hud._items.columns == 5,"Relic grid should be five across")
		_expect(hud.item_slots.is_empty(),"Relic row should start empty")
		state.add_inventory_item("chalk_rune_tablet",1); scene._refresh_hud()
		_expect(hud.item_slots.size() == 1,"Picked-up relic not shown")
		if hud.item_slots.size() == 1:
			var slot: Control = hud.item_slots[0]
			_expect(slot.global_position.y < 80 and slot.global_position.x < 80,"Relic row is not top left")
			_expect(slot.tooltip_text.begins_with("Chalk Rune Tablet"),"Relic tooltip lacks its name")
		state.gold = 12; state.keys = 3; scene._refresh_hud()
		_expect(scene.gold_value_label.text == "12" and scene.key_value_label.text == "03","Counters did not update")
		scene.player.health = 1; scene._refresh_hud()
		_expect(hud.health == 1,"Hearts did not follow health")
	scene.queue_free()
	await process_frame
	if failures.is_empty(): print("DUNGEON_HUD_TESTS_PASSED")
	else:
		for failure in failures: printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)
