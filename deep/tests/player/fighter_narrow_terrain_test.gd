extends "res://legacy/tests/fighter_production_test.gd"


func barrier(center: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = center
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	world.add_child(wall)


func gate(distance: float = 160) -> void:
	# A 20px gap admits a bolt/beast, but not a 28px enemy or 36px player.
	barrier(player.position + Vector2(distance, -110), Vector2(20, 200))
	barrier(player.position + Vector2(distance, 110), Vector2(20, 200))


func _run() -> void:
	for hz in [30, 120]:
		for id in ["archon_crossbow", "sentinel_shield", "divine_hammer"]:
			fixture(id)
			gate(80 if id == "divine_hammer" else 160)
			var target := foe()
			target.position = player.position + Vector2(90 if id != "divine_hammer" else 185, 0)
			var origin := player.position
			await physics_frame
			match id:
				"archon_crossbow":
					kit._launch_archon({"damage": 10, "warrior_cast": 1}, false)
				"sentinel_shield":
					kit.perform("special", {"started": true})
				"divine_hammer":
					kit._queue_hammer({"damage": 10, "warrior_cast": 1}, 1, target)
			for tick in hz * 2:
				kit._physics_process(1.0 / hz)
			if id != "divine_hammer":
				expect(
					target.position.x < origin.x + 150,
					(
						"%s/%dHz: carried/shoved body cannot squeeze through undersized opening"
						% [id, hz]
					)
				)
				expect(
					target.health < target.max_health,
					id + ": blocked displacement does not discard legitimate contact damage"
				)
			else:
				expect(
					player.position.x > origin.x and player.position.x < origin.x + 70,
					"Hammer lunge reaches the narrow gate but cannot squeeze player through it"
				)
			expect(
				(
					not target.has_meta("fighter_archon_carrier")
					and kit.hammer_chain.is_empty()
					and kit.shield_bash.is_empty()
				),
				id + ": collision leaves no attachment or movement restriction"
			)
			await clear()
	fixture("eldritch_bowstaff")
	gate()
	var prey := foe()
	prey.position = player.position + Vector2(250, 0)
	kit._spawn_corrupted(player.position, 1)
	var beast: CorruptedMiniBeast = get_nodes_in_group("corrupted_mini_beast")[0]
	beast.set_physics_process(false)
	await physics_frame
	for tick in 360:
		beast._physics_process(1.0 / 120.0)
	expect(
		beast.position.x > player.position.x + 170 and prey.health < prey.max_health,
		"Beast footprint fits narrow gate and can reach/bite prey beyond it"
	)
	await clear()
	for invalid in [Vector2.INF, Vector2(NAN, 0), "invalid"]:
		fixture("eldritch_bowstaff")
		player.position_sanitizer = func(_point: Vector2) -> Variant: return invalid
		player.pathfinder = SlasherGridPathfinder.new().configure(
			{Vector2i.ZERO: true}, [], player.position - Vector2(24, 24), 48
		)
		kit._spawn_corrupted(player.position, 6)
		expect(
			kit.spawned_beasts == 0,
			"Invalid sanitizer output is rejected before physics/navigation and never enables a summon collider"
		)
		expect(
			kit.effects.any(
				func(effect: Dictionary) -> bool: return effect.kind == "curse_overflow"
			),
			"Invalid spawn locations visibly dissipate curse energy"
		)
		await clear()
	fixture("eldritch_bowstaff")
	player.pathfinder = SlasherGridPathfinder.new().configure(
		{Vector2i.ZERO: true, Vector2i(5, 0): true}, [], player.position - Vector2(24, 24), 48
	)
	kit._spawn_corrupted(player.position + Vector2(240, 0), 6)
	expect(kit.spawned_beasts == 0, "Disconnected walkable island cannot host unreachable beasts")
	await clear()
	print("Fighter narrow terrain: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
