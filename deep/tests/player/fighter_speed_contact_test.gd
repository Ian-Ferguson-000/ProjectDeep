extends "res://legacy/tests/fighter_production_test.gd"


func _run() -> void:
	GameBalance.set_actions_override(GameBalance.ALL_ACTIONS)
	var damage_baselines: Dictionary = {}
	for id in [
		"divine_hammer",
		"sentinel_shield",
		"storm_trident",
		"archon_crossbow",
		"umbral_bow",
		"valkyrian_sling"
	]:
		for haste in [0.1, 0.5, 1.0, 4.0, 10.0, 100.0]:
			for hz in [30, 120]:
				fixture(id)
				player.warrior_kit = kit
				seed(42)
				player.run_state.selected_gear = GearData.create(
					id, id, 3, false, 0, "", "", "warrior"
				)
				player.run_state.class_resource = player.run_state.get_class_resource_max()
				player.fighter_frenzy_left = 30
				player.fighter_frenzy_haste = haste
				var target := foe()
				target.position = player.position + Vector2(90, 0)
				var slot := (
					"special"
					if id in ["divine_hammer", "sentinel_shield", "storm_trident"]
					else "basic"
				)
				var label := "%s/%.1fx/%dHz" % [id, haste, hz]
				expect(
					bool(player.use_action(slot).get("started", false)),
					label + ": native attack starts"
				)
				var contact_time := 0.0
				if not kit.hammer_chain.is_empty():
					contact_time = float(kit.hammer_chain.duration)
				elif not kit.shield_bash.is_empty():
					contact_time = float(kit.shield_bash.duration)
				elif not kit.ranged_attack.is_empty():
					contact_time = (
						float(kit.ranged_attack.duration) * float(kit.ranged_attack.release)
					)
				elif not kit.trident.is_empty():
					contact_time = float(kit.trident.left)
					kit.trident.destination = target.position
				expect(contact_time > 0, label + ": test observes actual windup/release deadline")
				var elapsed := 0.0
				var first_hit := -1.0
				for tick in ceili((contact_time + 4.0) * hz):
					kit._physics_process(1.0 / hz)
					elapsed += 1.0 / hz
					if target.health < target.max_health and first_hit < 0:
						first_hit = elapsed
					if elapsed + 0.00001 < contact_time:
						expect(
							target.health == target.max_health and kit.missiles.is_empty(),
							label + ": no damage or projectile before visible release"
						)
				expect(
					first_hit >= contact_time - 0.00001,
					label + ": authoritative contact cannot precede anticipation"
				)
				expect(first_hit >= 0, label + ": attack still reaches target at extreme speed")
				expect(
					(
						kit.hammer_chain.is_empty()
						and kit.shield_bash.is_empty()
						and kit.ranged_attack.is_empty()
					),
					label + ": timeline completes without permanent recovery lock"
				)
				var key := "%s/%.1f" % [id, haste]
				var damage := target.max_health - target.health
				if hz == 30:
					damage_baselines[key] = damage
				else:
					expect(
						damage == int(damage_baselines[key]),
						label + ": damage agrees across simulation rates at same speed"
					)
				await clear()
	print("Fighter speed contact: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
