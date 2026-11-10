extends CharacterBody3D
## A 3D physical actor presenting an existing campaign actor or keeper.
var world: Node3D
var source: Node2D
var is_keeper := false
var agent: NavigationAgent3D
var sprite: Sprite3D
var label: Label3D
var bubble: Label3D
var target := Vector3.INF
var walking := false
var _last_source_position := Vector2.INF
const KEEPER_SPEED := 4.8
const RESIDENT_HEIGHT := 1.65
var _visual_frames: SpriteFrames
var _reference_bounds := Rect2i()


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.4
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.23
	capsule.height = 1.55
	shape.shape = capsule
	shape.position.y = 0.79
	add_child(shape)
	agent = NavigationAgent3D.new()
	agent.radius = 0.25
	agent.height = 1.6
	agent.path_desired_distance = 0.4
	agent.target_desired_distance = 0.35
	add_child(agent)
	sprite = Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.position.y = 0.95
	add_child(sprite)
	label = _label("Keeper" if is_keeper else source.display_name, 2.0)
	bubble = _label("", 2.35)
	set_meta("interaction_source", source)
	position = world.to_room(source.position) + Vector3.UP * 0.1
	_last_source_position = source.position
	if not is_keeper:
		source.set_physics_process(false)
		source.agent.avoidance_enabled = false


func _label(text_value: String, height: float) -> Label3D:
	var result := Label3D.new()
	result.text = text_value
	result.position.y = height
	result.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	result.font_size = 28
	result.pixel_size = 0.012
	result.outline_size = 8
	result.modulate = Color("ffe3a3")
	add_child(result)
	return result


func move_to(point: Vector3) -> void:
	target = point
	agent.target_position = point
	walking = true


func _physics_process(delta: float) -> void:
	if not is_instance_valid(source):
		queue_free()
		return
	visible = source.visible
	if not visible:
		return
	if not is_keeper:
		source.agent.avoidance_enabled = false
	var direction := Vector3.ZERO
	var allowed: bool = (
		world.input_allowed() if is_keeper else not world.simulation_paused() and not source.paused
	)
	# Domain scripts can teleport actors (arrivals, seating, fast-forward).
	if source.position.distance_to(_last_source_position) > 2.0:
		position = world.to_room(source.position) + Vector3.UP * 0.1
		walking = false
	if is_keeper:
		if allowed:
			var input: Vector2 = source.move_input()
			# F6/test sessions may not have Main's action map; still support WASD.
			if input == Vector2.ZERO:
				input = (
					Vector2(
						(
							float(Input.is_physical_key_pressed(KEY_D))
							- float(Input.is_physical_key_pressed(KEY_A))
						),
						(
							float(Input.is_physical_key_pressed(KEY_S))
							- float(Input.is_physical_key_pressed(KEY_W))
						)
					)
					. limit_length()
				)
			if input.length_squared() > 0.01:
				walking = false
				world.pending_interaction = null
				direction = world.camera_direction(input)
	else:
		var moving: bool = (
			source.state in [TavernActor.ActivityState.WALKING, TavernActor.ActivityState.DEPARTING]
		)
		if moving and allowed:
			var desired: Vector3 = world.to_room(source.destination)
			if target.distance_to(desired) > 0.05 or not walking:
				move_to(desired)
		else:
			walking = false
	if walking and allowed and world.navigation_ready:
		if agent.is_navigation_finished():
			walking = false
			if not is_keeper:
				source._arrive()
		else:
			direction = agent.get_next_path_position() - global_position
			direction.y = 0.0
			direction = direction.normalized()
	if not allowed:
		direction = Vector3.ZERO
	var speed := KEEPER_SPEED if is_keeper else 1.8
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.5
	# Sweep up AND forward over a riser. Raising in place alone lets floor snap
	# pull the capsule back onto the lower floor before its center crosses the lip.
	if (
		direction.length_squared() > 0.01
		and is_on_floor()
		and test_move(global_transform, direction * speed * delta)
	):
		var raised := global_transform
		raised.origin.y += 0.30
		var step_forward := direction * 0.40
		if (
			not test_move(global_transform, Vector3.UP * 0.30)
			and not test_move(raised, step_forward)
		):
			move_and_collide(Vector3.UP * 0.30)
			move_and_collide(step_forward)
	move_and_slide()
	if position.y < -3.0:
		position = world.to_room(Vector2(832, 780)) + Vector3.UP * 0.2
		velocity = Vector3.ZERO
	source.position = world.to_plan(position)
	_last_source_position = source.position
	var screen_direction: Vector2 = world.screen_direction(direction)
	if is_keeper:
		if screen_direction.length_squared() > 0.01:
			source.facing = SlasherSpriteLibrary.direction_name(screen_direction, source.facing)
		source._play_motion_animation("run" if direction.length_squared() > 0.01 else "idle")
	else:
		if screen_direction.length_squared() > 0.01:
			source._last_direction = SlasherSpriteLibrary.direction_name(
				screen_direction, source._last_direction
			)
		source._play("run" if direction.length_squared() > 0.01 else "idle")
	_sync_visual()


func _sync_visual() -> void:
	var original: AnimatedSprite2D = source.sprite
	if original.sprite_frames == null:
		return
	var texture: Texture2D = original.sprite_frames.get_frame_texture(
		original.animation, original.frame
	)
	if texture == null:
		return
	sprite.texture = texture
	# Measure one neutral pose per character, not transparent frame padding.
	# Keep this scale across run/idle frames so animation cannot pump in size.
	if _visual_frames != original.sprite_frames:
		_visual_frames = original.sprite_frames
		var pose := SlasherSpriteLibrary.resolved_animation(_visual_frames, "idle", "down")
		var reference := _visual_frames.get_frame_texture(pose, 0)
		_reference_bounds = reference.get_image().get_used_rect()
		sprite.pixel_size = RESIDENT_HEIGHT / maxf(1.0, _reference_bounds.size.y)
	sprite.offset = Vector2(
		texture.get_width() * 0.5 - _reference_bounds.get_center().x,
		_reference_bounds.end.y - texture.get_height() * 0.5
	)
	sprite.position.y = 0.0
	sprite.modulate = source.modulate
	if not is_keeper:
		var seated: bool = source.state == TavernActor.ActivityState.SEATED
		sprite.position.y = 0.35 if seated else 0.0
		sprite.scale.y = 0.80 if seated else 1.0
		bubble.text = source.bubble.text if source.bubble.visible else ""
		label.text = source.display_name
	label.visible = world.labels_visible
