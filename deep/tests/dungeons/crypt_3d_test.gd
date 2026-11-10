extends SceneTree
## The 3D Stone Crypt (game/dungeons/crypt/Crypt3D.tscn): rooms build in stone, aim
## and movement match the screen, doors connect and lock with iron bars, rest,
## shop and treasure rooms work, the Charnel King has a 3D body whose weak point
## still takes damage, and leaving restores the viewport. Main loads it for the crypt.
## Run with `-- --capture` (not headless) for build/visual_checks/crypt_3d_*.png.
const CRYPT := preload("res://game/dungeons/crypt/Crypt3D.tscn")


class MemoryCampaign:
	extends CampaignState

	func save_atomic() -> bool:
		return true


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func _run() -> void:
	root.size = Vector2i(1600, 1000)
	var original_mask := root.canvas_cull_mask
	expect(
		load("res://game/main/main.gd").SlasherCryptScene == CRYPT, "Main doesn't load the 3D crypt"
	)
	var scene := CRYPT.instantiate()
	scene._ensure_designer_controls()
	var state := RunState.new()
	state.campaign = MemoryCampaign.new()
	state.requested_seed = 13579
	state.start_new_run(
		GearData.create("crypt3d_test", "Crypt 3D", 3, false, 0, "", "", "warrior"), "crypt"
	)
	state.current_floor = 2
	scene.run_state = state
	root.add_child(scene)
	for i in 8:
		await process_frame
	paused = false
	var w: Node3D = scene.world_3d
	expect(scene.rooms_active, "The 3D crypt lost the room graph")
	expect(
		w != null and w.theme == "crypt" and w.art.theme == "crypt",
		"The crypt isn't using the crypt theme"
	)
	expect(w.art.get_child_count() > 0, "No 3D geometry was built")
	expect(
		not w.art.batches.has("box536c3cfalse") and not w.art.batches.has("box819259false"),
		"The crypt has grass in it"
	)
	expect(not scene.player.camera.enabled, "The 2D camera still overrides 3D aiming")
	for point in [scene.player.position, Vector2(240, 240), Vector2(700, 420)]:
		var screen: Vector2 = w.camera.unproject_position(w.to_world(point))
		expect(
			(root.canvas_transform.affine_inverse() * screen).distance_to(point) < 0.2,
			"Mouse aim is misaligned with the 3D floor"
		)
	var before: Vector2 = scene.player.position
	Input.action_press("slasher_right")
	for i in 12:
		await physics_frame
	Input.action_release("slasher_right")
	var moved: Vector2 = root.canvas_transform.basis_xform(scene.player.position - before)
	expect(moved.x > 2 and absf(moved.y) < 2, "Movement didn't follow screen-right")
	await capture("start")
	# Doors.
	var first: String = scene.door_nodes.keys()[0]
	var neighbor := int(scene.room.neighbors[first])
	scene.transition_cooldown = 0
	scene.player.position = scene.door_nodes[first].position
	scene._check_doors()
	for i in 8:
		await process_frame
	expect(scene.room_id == neighbor, "A 3D door didn't lead to its room")
	expect(scene.world_3d != w, "Changing room didn't rebuild the 3D room")
	# A fighting room: locked behind iron bars, foes and hazards present.
	for record in state.field_run.rooms:
		if String(record.role) != "combat":
			continue
		state.enter_field_room(int(record.id), -1)
		scene._build_floor()
		for i in 5:
			await physics_frame
		expect(not scene.exit_open and scene.enemies_remaining > 0, "Combat doors weren't locked")
		for model in scene.world_3d.doors.values():
			expect(model.get_node("Brambles").visible, "Locked doors show no iron bars")
		var proxies: Array = scene.world_3d.actors.values().filter(func(a): return a is Sprite3D)
		expect(proxies.size() >= 2, "Crypt foes have no 3D sprites")
		await capture("combat")
		break
	for role in ["rest", "shop", "treasure"]:
		var selected := -1
		for record in state.field_run.rooms:
			if String(record.role) == role:
				selected = int(record.id)
				break
		if selected < 0:
			selected = 0
			state.update_field_room(selected, {"role": role, "template_id": "", "cleared": true})
		state.enter_field_room(selected, -1)
		scene._build_floor()
		for i in 5:
			await process_frame
		if role == "rest":
			scene.player.health = 1
			expect(
				scene.rest_at_campfire() and scene.player.health > 1,
				"The crypt's rest brazier didn't heal"
			)
		if role == "shop":
			expect(scene.has_dungeon_merchant, "The crypt trader is missing")
		await capture(role)
	# The guardian floor: Big Skelly Boi.
	state.current_floor = 5
	scene._build_floor()
	for record in state.field_run.rooms:
		if String(record.role) != "boss":
			continue
		state.enter_field_room(int(record.id), -1)
		scene._build_floor()
		break
	for i in 6:
		await process_frame
	var king: SlasherCharnelKing
	for actor in scene.actor_layer.get_children():
		if actor is SlasherCharnelKing:
			king = actor
	expect(king != null, "The guardian floor has no Charnel King")
	if king != null:
		scene.player.position = king.position + Vector2(140, 260)
		for i in 3:
			await process_frame
		var model = scene.world_3d.actors.get(king)
		expect(model != null and model.name == "CharnelKing", "The Charnel King has no 3D body")
		expect(not king.draw_body, "The 2D body is still drawn under the 3D one")
		king.heart.open_for(10)
		var health: int = king.health
		king.heart.receive_attack({"damage": 2}, scene.player)
		expect(king.health < health, "The Charnel King's weak point took no damage")
		king.set_physics_process(false)
		await capture("guardian")
	# The merchant stop between floors uses the old single floor; it renders too.
	state.slasher_merchant_interlude = true
	scene._build_floor()
	for i in 5:
		await process_frame
	expect(
		(
			not scene.rooms_active
			and scene.world_3d != null
			and scene.world_3d.art.get_child_count() > 0
		),
		"The crypt's merchant stop has no 3D floor"
	)
	await capture("interlude")
	state.slasher_merchant_interlude = false
	scene.queue_free()
	for i in 3:
		await process_frame
	expect(
		root.canvas_cull_mask == original_mask and root.canvas_transform == Transform2D.IDENTITY,
		"Leaving the crypt didn't restore the viewport"
	)
	if failures.is_empty():
		print("CRYPT_3D_TEST_PASSED")
	quit(0 if failures.is_empty() else 1)


func capture(suffix: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await create_timer(2.0).timeout
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/visual_checks/crypt_3d_" + suffix + ".png")
