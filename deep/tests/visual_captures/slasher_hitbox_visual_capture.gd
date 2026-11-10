extends SceneTree


class Overlay:
	extends Node2D
	var actors: Array[Node2D] = []

	func _draw() -> void:
		for actor in actors:
			var shape := SlasherHitGeometry.body(actor)
			var a: Vector2 = shape.a
			var b: Vector2 = shape.b
			var radius := float(shape.radius)
			draw_line(a, b, Color(0.2, 0.9, 1, 0.16), radius * 2, true)
			draw_circle(a, radius, Color(0.2, 0.9, 1, 0.12))
			draw_circle(b, radius, Color(0.2, 0.9, 1, 0.12))
			var angle: float = (b - a).angle()
			var side := Vector2.from_angle(angle + PI * 0.5) * radius
			draw_arc(a, radius, angle + PI * 0.5, angle + PI * 1.5, 24, Color.CYAN, 1.0, true)
			draw_arc(b, radius, angle - PI * 0.5, angle + PI * 0.5, 24, Color.CYAN, 1.0, true)
			draw_line(a + side, b + side, Color.CYAN, 1, true)
			draw_line(a - side, b - side, Color.CYAN, 1, true)
			draw_circle(actor.global_position, 3, Color(1, 0.6, 0.2))


func _initialize() -> void:
	call_deferred("_run")


func label_at(text: String, point: Vector2, size: int = 20) -> void:
	var label := Label.new()
	label.text = text
	label.position = point
	label.add_theme_font_size_override("font_size", size)
	root.add_child(label)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	RenderingServer.set_default_clear_color(Color("#162027"))
	label_at("Combat body alignment", Vector2(55, 35), 30)
	label_at(
		"Cyan: damageable body     Orange: ground position     Bodies stay stable during attacks",
		Vector2(55, 85),
		18
	)
	var overlay := Overlay.new()
	overlay.z_index = 100
	root.add_child(overlay)
	for index in 2:
		var id: String = ["warrior", "mage"][index]
		var state := RunState.new()
		state.set_class(id)
		state.start_new_run(GearData.create("visual", "Visual", 2, false, 0, "", "", id), "forest")
		var player := SlasherPlayer.new()
		player.setup(state)
		root.add_child(player)
		player.set_physics_process(false)
		player.position = Vector2(160 + index * 260, 290)
		overlay.actors.append(player)
		label_at("Fighter -10%" if index == 0 else "Mage -24%", player.position + Vector2(-65, 35))
	for index in 3:
		var id: String = ["briar_guardian", "crypt_lord", "balor"][index]
		var enemy: SlasherEnemy = (
			SlasherEnemy.new()
			if index == 0
			else SlasherCryptEnemy.new() if index == 1 else SlasherHellEnemy.new()
		)
		enemy.configure(
			3,
			index > 0,
			"crypt_boss" if index == 1 else id,
			index == 0,
			"elite_guardian" if index == 0 else id
		)
		root.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.position = Vector2(160 + index * 380, 550)
		overlay.actors.append(enemy)
		label_at(id.capitalize(), enemy.position + Vector2(-70, 45))
		print(
			id,
			" sprite: ",
			enemy.sprite,
			" frames: ",
			enemy.sprite.sprite_frames if enemy.sprite else null,
			" visible: ",
			enemy.sprite.visible if enemy.sprite else false,
			" body: ",
			enemy.combat_hurtbox()
		)
	var weak := SlasherColossusWeakPoint.new().setup(null, "heart", 30)
	root.add_child(weak)
	weak.position = Vector2(850, 280)
	weak.open_for(10)
	overlay.actors.append(weak)
	label_at("Colossus weak point", Vector2(755, 325))
	await process_frame
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("HITBOX_CAPTURE_PATH")
	if path.is_empty():
		path = ProjectSettings.globalize_path("user://hitbox_alignment.png")
	root.get_texture().get_image().save_png(path)
	print("HITBOX_VISUAL_CAPTURE_PASSED: ", path)
	quit()
