extends "res://legacy/tests/fighter_production_test.gd"


func _run() -> void:
	GameBalance.set_actions_override(GameBalance.ALL_ACTIONS)
	for id in [
		"eldritch_bowstaff", "demon_blade", "dragonbone_dagger", "grim_reaver", "storm_trident"
	]:
		for slot in ["basic", "special"]:
			if id == "storm_trident" and slot == "special":
				continue
			for haste in [0.1, 0.5, 1.0, 4.0, 10.0, 100.0]:
				for hz in [30, 120]:
					fixture(id)
					player.warrior_kit = kit
					player.run_state.selected_gear = GearData.create(
						id, id, 3, false, 0, "", "", "warrior"
					)
					player.fighter_frenzy_left = 4
					player.fighter_frenzy_haste = haste
					player.run_state.class_resource = player.run_state.get_class_resource_max()
					player.aim_direction = Vector2.from_angle(0.7)
					player.use_action(slot)
					var state: Dictionary = kit.swing
					var label := "%s/%s/%.1fx/%dHz" % [id, slot, haste, hz]
					expect(not state.is_empty(), label + ": native input creates melee timeline")
					var duration: float = state.duration
					var count: int = state.attacks.size()
					for index in count:
						for phase in [0.1, 0.5, 0.9]:
							state.elapsed = (
								duration
								* (
									float(state.windup)
									+ float(state.active) * (index + phase) / count
								)
							)
							var pose: Dictionary = kit.swing_presentation()
							var expected := (
								0.7
								+ deg_to_rad(
									(
										float(state.degrees)
										* ((1 - phase if index % 2 == 1 else phase) - 0.5)
									)
								)
							)
							expect(
								absf(angle_difference(float(pose.angle), expected)) < 0.0001,
								label + ": visible blade follows authored angle"
							)
							expect(
								float(pose.turn) == (-1 if index % 2 == 1 else 1),
								label + ": trail follows actual sweep direction"
							)
					state.elapsed = 0.0
					var target := foe()
					target.position = (
						player.position + player.aim_direction * float(state.reach) * 0.8
					)
					var elapsed := 0.0
					var first_hit := -1.0
					for step in ceili(duration * hz) + 1:
						var before := target.health
						kit._tick_swing(1.0 / hz)
						elapsed += 1.0 / hz
						if target.health < before and first_hit < 0:
							first_hit = elapsed
						expect(
							(
								elapsed >= duration * float(state.windup)
								or target.health == target.max_health
							),
							label + ": windup causes no damage"
						)
					# A centerline victim must be reached by the midpoint of the first
					# sweep, allowing only one physics step of scheduling tolerance.
					expect(
						(
							first_hit >= duration * float(state.windup)
							and (
								first_hit
								<= (
									(
										duration
										* (float(state.windup) + float(state.active) * 0.5 / count)
									)
									+ 1.0 / hz
									+ 0.001
								)
							)
						),
						label + ": centerline contact agrees with visible crossing"
					)
					# The hidden test target has a 14px circular hurtbox. Account for
					# that body and the authored 2-degree contact padding on each side,
					# rather than accepting any hit after windup as visually correct.
					var angular_tolerance := (
						rad_to_deg(asin(14.0 / (float(state.reach) * 0.8))) + 2.0
					)
					var earliest := (
						duration
						* (
							float(state.windup)
							+ (
								float(state.active)
								/ count
								* (0.5 - angular_tolerance / float(state.degrees))
							)
						)
					)
					expect(
						first_hit + 0.0001 >= earliest,
						label + ": damage cannot precede blade reaching the target capsule"
					)
					await clear()
	print("Fighter swing contact: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
