extends SceneTree

const FOREST := preload("res://scenes/forest/Forest.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := RunState.new()
	state.set_class("warrior")
	state.start_new_run(GearData.create("economy_test", "Test Gear", 2, false, 1, "", "", "warrior", "none"))
	var scene = FOREST.instantiate()
	scene.setup(null, state)
	root.add_child(scene)
	await process_frame

	scene.is_player_turn = true
	scene.is_resolving_enemy_turn = false
	scene.has_used_action = false
	scene.movement_remaining = 2
	scene._select_action("movement")
	_assert(not scene.has_used_action, "Selecting mobility spent the action.")
	scene._try_class_movement(scene.player_pos)
	_assert(not scene.has_used_action, "An invalid mobility target spent the action.")

	scene.selected_action = "attack"
	scene._finish_player_action()
	_assert(scene.has_used_action, "A completed action was not marked spent.")
	_assert(scene.is_player_turn, "A completed action ended the turn despite remaining movement.")
	_assert(scene.selected_action == "move", "A completed action did not restore base movement mode.")
	_assert(scene.movement_remaining == 2, "A completed action changed base movement.")

	var actions: Dictionary = GameBalance.get_base_class("warrior").get("actions", {})
	_assert(String(actions["movement"].get("description", "")) in scene.move_button.tooltip_text, "Movement tooltip is not class-specific.")
	_assert(String(actions["basic"].get("description", "")) in scene.interact_button.tooltip_text, "Basic tooltip is not class-specific.")

	var backdrop_count := 0
	var floor_sprite_count := 0
	for child in scene.ground_layer.get_children():
		if child is Polygon2D and child.name == "DungeonBlackBackdrop" and child.color == Color.BLACK:
			backdrop_count += 1
		elif child is Sprite2D:
			floor_sprite_count += 1
	_assert(backdrop_count == 1, "Dungeon board does not have exactly one black backdrop.")
	_assert(floor_sprite_count == scene.floor_cells.size(), "Floor textures were rendered outside playable cells.")

	scene.movement_remaining = 0
	scene._finish_turn_if_exhausted()
	_assert(not scene.is_player_turn, "The turn did not advance after both action and movement were spent.")

	if _failed:
		quit(1)
	else:
		print("Dungeon action economy regression test passed.")
		quit(0)

var _failed := false

func _assert(condition: bool, failure_message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(failure_message)
