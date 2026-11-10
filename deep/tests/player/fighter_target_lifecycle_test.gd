extends "res://legacy/tests/fighter_production_test.gd"


func _run() -> void:
	GameBalance.set_actions_override(GameBalance.ALL_ACTIONS)
	var settings: Node = root.get_node("GameSettings")
	for reduced in [false, true]:
		settings.values.reduced_effects = reduced
		for despawn in [false, true]:
			for id in ARSENAL.WEAPON_IDS:
				fixture(id)
				player.warrior_kit = kit
				player.run_state.selected_gear = GearData.create(
					id, id, 3, false, 0, "", "", "warrior"
				)
				player.run_state.class_resource = player.run_state.get_class_resource_max()
				var target := foe()
				target.position = player.position + Vector2(90, 0)
				var target_id := target.get_instance_id()
				var reference: WeakRef = weakref(target)
				var label := "%s/reduced=%s/despawn=%s" % [id, reduced, despawn]
				expect(
					bool(player.use_action("special").get("started", false)),
					label + ": native special begins"
				)
				if id == "storm_trident":
					kit.trident.destination = target.position
				var contacted := false
				for tick in 360:
					kit._physics_process(1.0 / 120.0)
					if target.health < target.max_health:
						contacted = true
						break
				expect(
					contacted, label + ": actual contact establishes effect before target removal"
				)
				if id == "archon_crossbow":
					expect(
						target.has_meta("fighter_archon_carrier"),
						label + ": victim is attached before removal"
					)
				if id == "umbral_bow":
					expect(
						kit.leashes.has(target_id),
						label + ": victim contributes a live tether before removal"
					)
				var curse_count: int = kit.curses.get(target_id, {}).get("stacks", 0)
				if id == "eldritch_bowstaff":
					expect(curse_count > 0, label + ": native strike established curse stacks")
				if despawn:
					target.queue_free()
				else:
					target.receive_attack(
						{
							"damage": 1000000,
							"damage_type": "physical",
							"damage_source": "External lifecycle test"
						},
						null
					)
				await process_frame
				if id == "grim_reaver":
					expect(
						kit.rampage_stacks == 0,
						label + ": unrelated removal cannot award even a transient rampage stack"
					)
				if id == "umbral_bow":
					expect(
						(
							not kit.leashes.has(target_id)
							and is_equal_approx(player.kit_buffs.speed_multiplier(), 1.0)
						),
						(
							label
							+ ": death/despawn removes haste immediately, without waiting for expiry"
						)
					)
				for tick in 1680:
					kit._physics_process(1.0 / 120.0)
				expect(reference.get_ref() == null, label + ": removed target is genuinely freed")
				expect(
					not kit.curses.has(target_id) and not kit.leashes.has(target_id),
					label + ": no orphan curse or tether remains"
				)
				expect(
					kit.combat_targets().is_empty(),
					label + ": cached targeting excludes removed body"
				)
				expect(
					kit.missiles.is_empty() and kit.hammer_chain.is_empty(),
					label + ": projectile and chain lifetimes terminate"
				)
				expect(
					is_equal_approx(player.kit_buffs.speed_multiplier(), 1.0),
					label + ": removed victim contributes no haste"
				)
				if id == "eldritch_bowstaff":
					expect(
						kit.spawned_beasts == (0 if despawn else curse_count),
						(
							label
							+ ": actual death converts exactly once, despawn never fabricates a kill"
						)
					)
				if id == "grim_reaver":
					expect(
						kit.rampage_stacks == 0,
						label + ": external death or despawn never awards a scythe kill"
					)
				if id == "storm_trident":
					expect(
						not kit.trident.is_empty() and kit.trident.state == "deployed",
						label + ": target removal leaves trident recoverable"
					)
					player.position = kit.trident.position
					kit._physics_process(0.01)
					expect(
						kit.trident.is_empty(),
						label + ": physical recovery succeeds without target"
					)
				await clear()
	print("Fighter target lifecycle: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
