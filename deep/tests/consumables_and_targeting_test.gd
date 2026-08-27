extends SceneTree

const FOREST := preload("res://scenes/forest/Forest.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var state := RunState.new()
	state.set_class("warrior")
	state.start_new_run(GearData.create("test", "Test Gear", 2, false, 0, "", "", "warrior", "none"))
	_expect(state.get_consumable_capacity() == 4, "base consumable capacity should be four", failures)
	_expect(state.add_consumable("healing_potion"), "failed to add Healing Potion", failures)
	_expect(state.add_consumable("focus_tonic"), "failed to add Focus Tonic", failures)
	_expect(state.add_consumable("smoke_vial"), "failed to add Smoke Vial", failures)
	_expect(state.add_consumable("warding_draught"), "failed to add Warding Draught", failures)
	_expect(not state.add_consumable("fleet_draught"), "consumable capacity allowed a fifth item", failures)

	var scene := FOREST.instantiate()
	scene.setup(null, state)
	root.add_child(scene)
	await process_frame
	scene.is_player_turn = true
	scene.is_resolving_enemy_turn = false
	scene.has_used_action = false

	scene._select_action("attack")
	_expect(scene.selected_action == "attack", "Attack did not enter targeting mode", failures)
	scene._cancel_selected_action()
	_expect(scene.selected_action == "move" and not scene.has_used_action, "Cancel did not preserve the action and restore neutral movement", failures)

	scene._preview_action_range("attack")
	await process_frame
	var preview_count := 0
	for child in scene.markers_root.get_children():
		if child.name.to_lower().begins_with("preview"):
			preview_count += 1
	_expect(preview_count > 0, "hovering Attack did not create faint range markers", failures)
	scene._clear_action_range_preview()
	state.set_class("mage")
	var mage_preview: Array[Vector2i] = scene._basic_range_preview_tiles()
	_expect(not mage_preview.is_empty(), "ranged hover preview failed for non-cardinal Mage targets", failures)
	state.set_class("warrior")

	scene._open_consumables()
	_expect(scene.consumables_backdrop.visible and not scene.has_used_action, "opening Consumables spent the action or failed to open", failures)
	var first_consumable_button := scene.consumables_box.get_child(0) as Button
	_expect(first_consumable_button != null and first_consumable_button.icon != null and maxi(first_consumable_button.icon.get_width(), first_consumable_button.icon.get_height()) <= 32, "consumable popup icon was not constrained to 32 pixels", failures)
	var focus_index := state.get_consumables().find("focus_tonic")
	scene._use_consumable(focus_index)
	_expect(scene.has_used_action, "using a consumable did not spend the action", failures)
	_expect(not state.get_consumables().has("focus_tonic"), "used consumable remained in its slot", failures)
	_expect(state.class_resource == 2, "Focus Tonic did not restore class resource", failures)
	for new_id in ["haste_potion", "fury_potion", "resource_elixir", "true_strike_tonic"]:
		_expect(not GameBalance.get_consumable(new_id).is_empty(), "missing new consumable %s" % new_id, failures)
	state.consumable_items = ["haste_potion"]
	scene.has_used_action = false; scene.movement_remaining = 3
	scene._use_consumable(0)
	_expect(scene.movement_remaining == 6, "Potion of Haste did not double remaining movement", failures)
	_expect(not scene.has_used_action, "Potion of Haste did not grant its additional action", failures)
	state.consumable_items = ["fury_potion"]
	scene.has_used_action = false; scene._use_consumable(0)
	_expect(scene.next_consumable_damage_multiplier == 2, "Potion of Fury did not arm double damage", failures)
	state.class_resource = 0; state.consumable_items = ["resource_elixir"]
	scene.has_used_action = false; scene._use_consumable(0)
	_expect(state.class_resource == state.get_class_resource_max(), "Resource Elixir did not fill the class meter", failures)
	state.consumable_items = ["true_strike_tonic"]
	scene.has_used_action = false; scene._use_consumable(0)
	_expect(scene.next_consumable_accuracy_bonus == 8, "True-Strike Tonic did not arm +8 Accuracy", failures)

	if failures.is_empty():
		print("Consumables, cancel targeting, and hover range preview validation passed.")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(value: bool, failure: String, failures: Array[String]) -> void:
	if not value: failures.append(failure)
