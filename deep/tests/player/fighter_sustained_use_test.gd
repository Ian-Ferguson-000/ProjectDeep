extends "res://legacy/tests/fighter_production_test.gd"


func _run() -> void:
	for id in ARSENAL.WEAPON_IDS:
		fixture(id)
		player.warrior_kit = kit
		var origin := player.position
		var peak_effects := 0
		var peak_missiles := 0
		var peak_beasts := 0
		var peak_history := 0
		for frame in 900:  # Thirty simulated seconds per weapon, with crowd replacement.
			if frame % 30 == 0:
				for old in kit.enemies():
					old.queue_free()
				await process_frame
				player.position = origin
				for i in 16:
					var target := foe(1000)
					target.position = origin + Vector2(65 + (i % 4) * 35, -50 + (i / 4) * 35)
			if frame % 9 == 0:
				if not kit.trident.is_empty() and kit.trident.state == "deployed":
					player.position = kit.trident.position
					kit._physics_process(0.001)
					player.position = origin
				kit.perform("special", {"started": true})
				if (
					id == "storm_trident"
					and not kit.trident.is_empty()
					and kit.trident.state == "aiming"
				):
					kit.trident.destination = origin + Vector2(120, 0)
			kit._physics_process(1.0 / 30)
			player.tick_fighter_frenzy(1.0 / 30)
			for enemy in kit.enemies():
				enemy._process_mage_control(1.0 / 30)
			# Convert cursed crowds through actual deaths, including an external killer.
			if id == "eldritch_bowstaff" and frame % 30 == 29:
				for enemy in kit.enemies():
					enemy.receive_attack({"damage": 10000}, player)
			for beast in get_nodes_in_group("corrupted_mini_beast"):
				beast.set_physics_process(false)
				beast._physics_process(1.0 / 30)
			peak_effects = maxi(peak_effects, kit.effects.size())
			peak_missiles = maxi(peak_missiles, kit.missiles.size())
			peak_beasts = maxi(peak_beasts, get_nodes_in_group("corrupted_mini_beast").size())
			peak_history = maxi(peak_history, kit.resolved_strikes.size())
		expect(
			peak_effects <= 32 and kit.effect_pool.size() <= 32,
			id + ": sustained effects and reusable pool remain bounded"
		)
		expect(
			peak_missiles <= 4 and kit.missile_pool.size() <= 8,
			id + ": sustained projectiles and pool remain bounded"
		)
		expect(
			peak_beasts <= 24 and get_nodes_in_group("corrupted_mini_beast_pool").size() <= 24,
			id + ": active and pooled summons stay within global cap"
		)
		expect(
			peak_history <= 2000,
			id + ": hit history remains time-bounded under repeated activations"
		)
		expect(peak_history > 0, id + ": sustained scenario exercises real enemy contacts")
		var effects_disjoint := true
		var missiles_disjoint := true
		for active_effect in kit.effects:
			for pooled_effect in kit.effect_pool:
				if is_same(active_effect, pooled_effect):
					effects_disjoint = false
		for active_missile in kit.missiles:
			for pooled_missile in kit.missile_pool:
				if is_same(active_missile, pooled_missile):
					missiles_disjoint = false
		expect(effects_disjoint, id + ": active effects are not simultaneously reusable")
		expect(missiles_disjoint, id + ": active projectiles are not simultaneously reusable")
		player.health = 0
		kit._physics_process(1.0 / 30)
		for beast in get_nodes_in_group("corrupted_mini_beast"):
			beast._physics_process(1.0 / 30)
		expect(
			(
				kit.missiles.is_empty()
				and kit.leashes.is_empty()
				and get_nodes_in_group("corrupted_mini_beast").is_empty()
			),
			id + ": death clears long-lived combat state"
		)
		print(
			(
				"SUSTAINED %s: effects=%d missiles=%d beasts=%d hit_records=%d"
				% [id, peak_effects, peak_missiles, peak_beasts, peak_history]
			)
		)
		await clear()
	print("Fighter sustained use: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
