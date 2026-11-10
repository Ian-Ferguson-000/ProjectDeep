extends RefCounted
class_name SlasherHitGeometry

## Combat capsules are separate from the small foot circles used for navigation.
## Cache a neutral pose's opaque bounds: weapons, casting effects and hit flashes
## must not make the body grow or shrink during an attack.
static var _bounds: Dictionary = {}


static func sprite_body(
	sprite: AnimatedSprite2D, origin: Vector2, fallback: float, player: bool = false
) -> Dictionary:
	if not is_instance_valid(sprite) or sprite.sprite_frames == null or not sprite.visible:
		return circle(origin, fallback)
	var frames := sprite.sprite_frames
	var animation := SlasherSpriteLibrary.resolved_animation(frames, "idle", "down")
	var texture := frames.get_frame_texture(animation, 0)
	if texture == null:
		return circle(origin, fallback)
	var key := texture.get_instance_id()
	if not _bounds.has(key):
		var image := texture.get_image()
		_bounds[key] = (
			Rect2(image.get_used_rect())
			if image != null
			else Rect2(Vector2.ZERO, texture.get_size())
		)
	var rect: Rect2 = _bounds[key]
	var inset := rect.size * Vector2(0.16 if player else 0.08, 0.09 if player else 0.04)
	rect = Rect2(rect.position + inset, rect.size - inset * 2.0)
	var center := (
		rect.get_center() + sprite.offset - texture.get_size() * 0.5
		if sprite.centered
		else rect.get_center() + sprite.offset
	)
	var half := rect.size * 0.5
	var local_radius := minf(half.x, half.y)
	var axis := (
		Vector2(0, half.y - local_radius) if half.y >= half.x else Vector2(half.x - local_radius, 0)
	)
	return {
		"a": sprite.to_global(center - axis),
		"b": sprite.to_global(center + axis),
		"radius": local_radius * minf(absf(sprite.global_scale.x), absf(sprite.global_scale.y))
	}


static func circle(center: Vector2, radius: float) -> Dictionary:
	return {"a": center, "b": center, "radius": radius}


static func body(actor: Node2D) -> Dictionary:
	if actor.has_method("combat_hurtbox"):
		return actor.call("combat_hurtbox")
	return circle(actor.global_position, 0.0)


static func _circle_time(start: Vector2, end: Vector2, center: Vector2, radius: float) -> float:
	var offset := start - center
	var movement := end - start
	var c := offset.length_squared() - radius * radius
	if c <= 0.0:
		return 0.0
	var a := movement.length_squared()
	if a <= 0.000001:
		return INF
	var b := offset.dot(movement)
	var discriminant := b * b - a * c
	if discriminant < 0.0:
		return INF
	var t := (-b - sqrt(discriminant)) / a
	return t if t >= 0.0 and t <= 1.0 else INF


## Earliest contact with the capsule, including initial overlap and zero motion.
static func sweep(start: Vector2, end: Vector2, actor: Node2D, padding: float = 0.0) -> float:
	var shape := body(actor)
	var a: Vector2 = shape.a
	var b: Vector2 = shape.b
	var radius := float(shape.radius) + padding
	var result := minf(_circle_time(start, end, a, radius), _circle_time(start, end, b, radius))
	var axis := b - a
	var length := axis.length()
	if length <= 0.0001:
		return result
	axis /= length
	var side := axis.orthogonal()
	var from := Vector2((start - a).dot(side), (start - a).dot(axis))
	var motion := Vector2((end - start).dot(side), (end - start).dot(axis))
	var low := 0.0
	var high := 1.0
	for i in 2:
		var minimum: float = -radius if i == 0 else 0.0
		var maximum: float = radius if i == 0 else length
		if absf(motion[i]) < 0.000001:
			if from[i] < minimum or from[i] > maximum:
				return result
		else:
			var t0: float = (minimum - from[i]) / motion[i]
			var t1: float = (maximum - from[i]) / motion[i]
			low = maxf(low, minf(t0, t1))
			high = minf(high, maxf(t0, t1))
			if low > high:
				return result
	return minf(result, low)


static func overlaps_circle(center: Vector2, radius: float, actor: Node2D) -> bool:
	return sweep(center, center, actor, radius) != INF


static func overlaps_sector(
	origin: Vector2, direction: Vector2, reach: float, degrees: float, actor: Node2D
) -> bool:
	var shape := body(actor)
	var a: Vector2 = shape.a
	var b: Vector2 = shape.b
	var radius := float(shape.radius)
	var closest := Geometry2D.get_closest_point_to_segment(origin, a, b)
	if degrees >= 360.0:
		return origin.distance_to(closest) <= reach + radius
	var half := deg_to_rad(degrees) * 0.5
	var forward := direction.normalized()
	# Radial boundaries also cover targets that straddle an angular edge.
	for sign_value in [-1.0, 1.0]:
		var tip := origin + forward.rotated(half * sign_value) * reach
		var pair := Geometry2D.get_closest_points_between_segments(origin, tip, a, b)
		if pair[0].distance_to(pair[1]) <= radius:
			return true
	for point: Vector2 in [a, b, closest]:
		var offset := point - origin
		if (
			offset.length() <= reach + radius
			and (offset.is_zero_approx() or forward.dot(offset.normalized()) >= cos(half))
		):
			return true
	return false


## Actors use combat capsules above; only world geometry blocks this ray.
static func projectile_wall(
	projectile: Node2D, start: Vector2, end: Vector2, mask: int
) -> Dictionary:
	if start.is_equal_approx(end):
		return {}
	var query := PhysicsRayQueryParameters2D.create(start, end, mask)
	var excluded: Array[RID] = []
	for group in ["slasher_player", "slasher_enemy"]:
		for actor in projectile.get_tree().get_nodes_in_group(group):
			if actor is CharacterBody2D:
				excluded.append(actor.get_rid())
	query.exclude = excluded
	query.hit_from_inside = true
	while true:
		var collision := projectile.get_world_2d().direct_space_state.intersect_ray(query)
		if collision.is_empty() or collision.get("collider") is StaticBody2D:
			return collision
		# Companions and other dynamic bodies are not scenery. Skip them without
		# allowing them to hide a wall farther along this frame's path.
		excluded.append(collision.rid)
		query.exclude = excluded
	return {}
