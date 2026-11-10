extends "res://legacy/tests/fighter_production_test.gd"


func _run() -> void:
	var settings: Node = root.get_node("GameSettings")
	var baseline: Dictionary = {}
	var state_baseline: Dictionary = {}
	for reduced in [false, true]:
		settings.values["reduced_effects"] = reduced
		for hz in [30, 120]:
			for id in ARSENAL.WEAPON_IDS:
				for population in [0, 1, 32]:
					fixture(id)
					player.warrior_kit = kit
					seed(42)
					var targets: Array[SlasherEnemy] = []
					for i in population:
						var target := foe(100000)
						target.position = (
							player.position + Vector2(80 + (i % 8) * 28, -65 + (i / 8) * 38)
							if population > 1
							else player.position + Vector2(90, 0)
						)
						targets.append(target)
					var result: Dictionary = kit.perform("special", {"started": true})
					expect(result.started, "%s / %d / %d Hz activation" % [id, population, hz])
					if id == "storm_trident":
						kit.trident.destination = player.position + Vector2(100, 0)
					for i in hz * 3:
						kit._physics_process(1.0 / hz)
						player.tick_fighter_frenzy(1.0 / hz)
						for target in targets:
							target._process_mage_control(1.0 / hz)
					var damage := 0
					for target in targets:
						damage += target.max_health - target.health
					var key := "%s/%d/%d" % [id, population, hz]
					var authoritative := combat_snapshot(targets)
					if not reduced:
						baseline[key] = damage
					else:
						expect(
							damage == int(baseline[key]),
							key + ": reduced effects preserve exact authoritative damage"
						)
					if not reduced:
						state_baseline[key] = authoritative
					else:
						expect(
							authoritative == state_baseline[key],
							(
								key
								+ ": reduced effects preserve individual damage, armor, control, curses, tethers, and owner bonuses"
							)
						)
					if hz == 120:
						expect(
							damage == int(baseline["%s/%d/30" % [id, population]]),
							key + ": total damage agrees at 30 and 120 Hz"
						)
					if population > 0:
						expect(
							damage > 0, key + ": populated scenario produces actual contact damage"
						)
					expect(
						kit.missiles.size() <= 4, key + ": projectile population remains bounded"
					)
					if population == 0:
						expect(damage == 0, key + ": empty-room use causes no phantom damage")
					kit.on_unequipped()
					expect(
						(
							kit.swing.is_empty()
							and kit.ranged_attack.is_empty()
							and kit.hammer_chain.is_empty()
							and kit.shield_bash.is_empty()
						),
						key + ": swap cancels all pending attacks"
					)
					if population == 1:
						if not kit.trident.is_empty():
							player.position = kit.trident.position
							kit._physics_process(0.01)
						kit.perform("special", {"started": true})
						targets[0].queue_free()
						await process_frame
						for i in hz:
							kit._physics_process(1.0 / hz)
						expect(
							kit.combat_targets().is_empty(),
							key + ": target despawn during activation clears cached targets safely"
						)
					player.health = 0
					kit._physics_process(1.0 / hz)
					expect(
						(
							kit.missiles.is_empty()
							and kit.leashes.is_empty()
							and kit.trident.is_empty()
						),
						key + ": owner death clears battlefield state"
					)
					await clear()
	print("Fighter scenario matrix: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func combat_snapshot(targets: Array[SlasherEnemy]) -> Dictionary:
	var victims: Array[Dictionary] = []
	for target in targets:
		var id := target.get_instance_id()
		victims.append(
			{
				"health": target.health,
				"armor": target.effective_armor(),
				"wounds": target.dragonbone_wounds.duplicate(true),
				"storm_left": target.storm_vulnerability_left,
				"storm_state": target.storm_pin_visual_state(),
				"slow": target.mage_slow_multiplier,
				"stun": target.mage_stun_remaining(),
				"curse_stacks": kit.curses.get(id, {}).get("stacks", 0),
				"curse_left": kit.curses.get(id, {}).get("left", 0),
				"leash_left": kit.leashes.get(id, {}).get("left", 0),
				"carried": target.has_meta("fighter_archon_carrier")
			}
		)
	return {
		"targets": victims,
		"haste": player.kit_buffs.speed_multiplier(),
		"frenzy_left": player.fighter_frenzy_left,
		"frenzy_damage": player.fighter_frenzy_damage,
		"rampage_stacks": kit.rampage_stacks,
		"critical_chance": kit.critical_chance(),
		"missiles": kit.missiles.size(),
		"summons": get_nodes_in_group("corrupted_mini_beast").size()
	}
