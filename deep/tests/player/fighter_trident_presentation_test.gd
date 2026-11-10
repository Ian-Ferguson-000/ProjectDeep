extends "res://legacy/tests/fighter_production_test.gd"


func _run() -> void:
	fixture("storm_trident")
	for direction in [
		Vector2.RIGHT, Vector2.LEFT, Vector2(1, -0.5).normalized(), Vector2(1, 0.5).normalized()
	]:
		for height in [0.0, 55.0, 90.0]:
			kit.rules.flight_arc_height = height
			var origin := player.position
			var travel: Vector2 = direction * 300
			var missile: Dictionary = {
				"origin": origin, "destination": origin + travel, "position": origin
			}
			for progress in [0.0, 0.25, 0.5, 0.75, 1.0]:
				missile.position = origin + travel * progress
				var pose: Dictionary = kit.trident_flight_pose(missile)
				var expected: Vector2 = (
					origin + travel * progress + Vector2(0, -sin(PI * progress) * height)
				)
				expect(
					Vector2(pose.position).distance_to(expected) < 0.001,
					"Trident rendered flight matches preview arc"
				)
				# Independent finite difference checks the actual curve direction.
				var before: Vector2 = (
					origin
					+ travel * (progress - 0.0001)
					+ Vector2(0, -sin(PI * (progress - 0.0001)) * height)
				)
				var after: Vector2 = (
					origin
					+ travel * (progress + 0.0001)
					+ Vector2(0, -sin(PI * (progress + 0.0001)) * height)
				)
				expect(
					Vector2(pose.heading).dot(before.direction_to(after)) > 0.999,
					"Trident prongs and trail follow the visible flight tangent"
				)
				player.aim_direction = Vector2.DOWN
				var changed: Dictionary = kit.trident_flight_pose(missile)
				expect(
					Vector2(changed.heading).is_equal_approx(pose.heading),
					"Turning fighter cannot redirect airborne trident presentation"
				)
				expect(
					Vector2(missile.position).is_equal_approx(origin + travel * progress),
					"Arc presentation cannot move the authoritative projectile"
				)
	var zero: Dictionary = {
		"origin": player.position, "destination": player.position, "position": player.position
	}
	var zero_pose: Dictionary = kit.trident_flight_pose(zero)
	expect(
		Vector2(zero_pose.position).is_finite() and Vector2(zero_pose.heading).is_finite(),
		"Zero-length recovery fallback has a finite pose"
	)
	await clear()
	print("Trident presentation: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
