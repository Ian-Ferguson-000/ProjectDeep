extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Visual capture requires a rendering display.")
		quit(1)
		return
	var output := OS.get_environment("SLASH_CAPTURE_DIR")
	if output.is_empty():
		output = ProjectSettings.globalize_path("user://fighter_slash_review")
	DirAccess.make_dir_recursive_absolute(output)
	var main: Node = load("res://game/main/main.gd").new()
	main._ensure_input_actions()
	main.free()
	var state := RunState.new()
	state.set_class("warrior")
	state.start_new_run(
		GearData.create("slash_capture", "Slash Capture", 3, false, 0, "", "", "warrior"), "forest"
	)
	var scene: Node = load("res://game/dungeons/forest/SlasherForest.tscn").instantiate()
	scene.setup(null, state)
	root.add_child(scene)
	await process_frame
	await process_frame
	if scene.relic_modal != null and scene.relic_modal.visible:
		scene.relic_modal.finish()
	var player: SlasherPlayer = scene.player
	player.set_physics_process(false)
	player.aim_direction = Vector2.RIGHT
	player.facing_name = "right"
	player.camera.reset_smoothing()
	for enemy in get_nodes_in_group("slasher_enemy"):
		enemy.set_physics_process(false)
	await create_timer(1.5).timeout
	for direction in [
		Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2(1, -1).normalized()
	]:
		player.aim_direction = direction
		player.facing_name = SlasherSpriteLibrary.direction_name(direction, "right")
		player.cooldowns.basic = 0.0
		var enemy := SlasherEnemy.new()
		enemy.configure(1, false, "feral_wolf")
		scene.add_child(enemy)
		enemy.global_position = player.global_position + direction * 90
		enemy.health = 999
		enemy.max_health = 999
		enemy.set_physics_process(false)
		player.use_action("basic")
		for index in 5:
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(
				output.path_join("fighter_slash_%s_%d.png" % [str(direction), index])
			)
			await create_timer(0.025).timeout
		enemy.free()
		await create_timer(0.25).timeout
	print("FIGHTER_SLASH_VISUAL_CAPTURE_PASSED: ", output)
	scene.free()
	quit()
