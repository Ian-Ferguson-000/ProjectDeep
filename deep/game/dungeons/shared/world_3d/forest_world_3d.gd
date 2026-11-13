extends Node3D
## One physical-looking diorama per authored room. Gameplay stays on the shared
## combat plane; a transparent effects pass preserves every existing telegraph.
const ART := preload("res://game/dungeons/shared/world_3d/forest_room_art.gd")
const EFFECT_LAYER := 1 << 19
const HIDDEN_LAYER := 1 << 20
const UNIT := 48.0
var dungeon: Node2D
## "forest" or "crypt": picks the art kit's theme and the lighting.
var theme := "forest"
var camera: Camera3D
var effects: SubViewport
var art: Node3D
var actors: Dictionary = {}
var props: Dictionary = {}
var doors: Dictionary = {}
var focus := Vector3.ZERO
var room_size := Vector2.ZERO
var zoom := 1.0


func to_world(point: Vector2, height: float = 0.0) -> Vector3:
	return Vector3((point.x - dungeon.ORIGIN.x) / UNIT, height, (point.y - dungeon.ORIGIN.y) / UNIT)


func _ready() -> void:
	room_size = Vector2(dungeon.layout.width, dungeon.layout.height)
	dungeon.visibility_layer |= EFFECT_LAYER
	get_viewport().canvas_cull_mask &= ~(EFFECT_LAYER | HIDDEN_LAYER)
	# Shared canvas, separate render masks: HUD remains in the main viewport.
	for child in dungeon.get_children():
		if child is CanvasItem and child != self:
			child.visibility_layer = EFFECT_LAYER if child == dungeon.actor_layer else HIDDEN_LAYER
	_build_environment()
	art = ART.new()
	art.world = self
	art.theme = theme
	art.name = "RoomGeometry"
	add_child(art)
	art.build(dungeon.layout)
	_build_effects_pass()
	camera = Camera3D.new()
	camera.name = "CryptCamera" if theme == "crypt" else "ForestCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.1
	camera.far = 150.0
	add_child(camera)
	camera.make_current()
	focus = to_world(dungeon.player.global_position)
	_sync_objects()
	_update_camera(1.0)


func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	var crypt := theme == "crypt"
	environment.background_color = Color("0b0910") if crypt else Color("172b26")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a7a4b8") if crypt else Color("b8d2b1")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	environment.ssao_radius = 1.5
	environment.ssao_intensity = 1.2
	var holder := WorldEnvironment.new()
	holder.environment = environment
	add_child(holder)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_color = Color("d4d2e6") if crypt else Color("ffe4b0")
	sun.light_energy = 0.75 if crypt else 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90
	add_child(sun)


func _build_effects_pass() -> void:
	effects = SubViewport.new()
	effects.name = "CombatEffects"
	effects.size = Vector2i(room_size * UNIT + dungeon.ORIGIN * 2)
	effects.transparent_bg = true
	effects.disable_3d = true
	effects.canvas_cull_mask = 1 | EFFECT_LAYER
	effects.world_2d = get_viewport().world_2d
	effects.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(effects)
	var plane := MeshInstance3D.new()
	plane.name = "CombatTelegraphs"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(effects.size) / UNIT
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = effects.get_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = material
	plane.mesh = mesh
	plane.position = to_world(Vector2(effects.size) * 0.5, 0.045)
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plane)


func _process(delta: float) -> void:
	if not is_instance_valid(dungeon.player):
		return
	# The previous dungeon scene restores the 2D mask as it leaves, a frame after
	# this one starts (Main swaps scenes with queue_free): keep the 2D art hidden.
	get_viewport().canvas_cull_mask &= ~(EFFECT_LAYER | HIDDEN_LAYER)
	_sync_objects()
	_update_camera(delta)
	art.fade_trees(to_world(dungeon.player.global_position), camera.global_position - focus, delta)


func _sync_objects() -> void:
	# Scan only actors: dynamically spawned summons, projectiles, loot and props
	# keep their existing lifetimes. Procedural effects stay in the shared pass.
	for source in dungeon.actor_layer.get_children():
		if source.name == "ColossusRemains":
			if not actors.has(source):
				actors[source] = (
					art.bone_heap(to_world(source.global_position))
					if theme == "crypt"
					else art.stump(to_world(source.global_position))
				)
			source.self_modulate.a = 0.0
		elif source is SlasherBreakableProp:
			if not props.has(source):
				props[source] = art.make_prop(source.prop_kind, to_world(source.global_position))
			var model: Node3D = props[source]
			model.visible = source.visible and not source.destroyed
			if is_instance_valid(source.sprite):
				source.sprite.visibility_layer = HIDDEN_LAYER
			if source.is_open and not model.has_meta("opened"):
				model.set_meta("opened", true)
				art.open_chest(model)
		elif source is CharacterBody2D:
			var source_sprite = source.get("sprite")
			if source_sprite is AnimatedSprite2D:
				if not actors.has(source):
					if source is SlasherCharnelKing:
						actors[source] = art.charnel_king(to_world(source.global_position))
						# Its arms and sweeping hands stay drawn on the floor.
						source.draw_body = false
						source.queue_redraw()
					elif source is SlasherColossus:
						actors[source] = art.colossus(to_world(source.global_position))
						source.self_modulate.a = 0.0
					else:
						var proxy := Sprite3D.new()
						proxy.name = "Actor_" + source.name
						proxy.billboard = BaseMaterial3D.BILLBOARD_ENABLED
						proxy.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
						proxy.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
						proxy.shaded = false
						add_child(proxy)
						actors[source] = proxy
				if actors[source] is Sprite3D:
					_sync_sprite(source, source_sprite, actors[source])
				else:
					actors[source].visible = source.visible and not source.dead
					if source is SlasherCharnelKing:
						_pose_charnel_king(source, actors[source])
					elif source is SlasherColossus:
						_animate_colossus(source, actors[source])
	for source in actors.keys():
		if not is_instance_valid(source):
			actors[source].queue_free()
			actors.erase(source)
	for source in props.keys():
		if not is_instance_valid(source):
			props[source].queue_free()
			props.erase(source)
	# Shop wares: a plinth with the item floating above it; price stays on the floor.
	for source in dungeon.actor_layer.get_children():
		if not String(source.name).begins_with("ShopOffer_"):
			continue
		if not actors.has(source):
			var ware := source.get_node_or_null("Ware") as Sprite2D
			var glow := source.get_child(1) as Polygon2D
			actors[source] = art.ware_stand(
				to_world(source.global_position),
				ware.texture if ware else null,
				glow.color if glow else Color("e8c76a")
			)
			if ware:
				ware.visibility_layer = HIDDEN_LAYER
		art.ware_bob(actors[source], Time.get_ticks_msec() / 1000.0)
	for name in ["TavernPortal", "HiddenWay"]:
		var source := dungeon.actor_layer.get_node_or_null(name) as Node2D
		if source == null or actors.has(source):
			continue
		actors[source] = (
			art.tavern_portal(to_world(source.global_position))
			if name == "TavernPortal"
			else art.hidden_way(to_world(source.global_position))
		)
		source.visibility_layer = HIDDEN_LAYER
		for child in source.get_children():
			if child is CanvasItem:
				child.visibility_layer = HIDDEN_LAYER
	for source in dungeon.actor_layer.get_children():
		if source.name not in ["CampMerchant", "InterludeMerchant"]:
			continue
		if actors.has(source):
			continue
		for original in source.get_children():
			if original is Sprite2D:
				var proxy := Sprite3D.new()
				proxy.texture = original.texture
				proxy.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				proxy.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
				proxy.shaded = false
				proxy.pixel_size = absf(original.scale.x) / UNIT
				proxy.position = to_world(source.global_position, 0.02)
				proxy.offset.y = -original.position.y / maxf(.001, original.scale.x)
				add_child(proxy)
				actors[source] = proxy
				original.visibility_layer = HIDDEN_LAYER
	for direction in dungeon.door_nodes:
		if not is_instance_valid(dungeon.door_nodes[direction]):
			continue
		var source: Node2D = dungeon.door_nodes[direction]
		if not doors.has(direction):
			doors[direction] = art.door(to_world(source.global_position), direction)
		var barrier := source.get_node_or_null("Brambles")
		doors[direction].get_node("Brambles").visible = (
			is_instance_valid(barrier) and barrier.visible
		)
		# Three-dimensional posts/gate replace the old bushes; retain door hints.
		if is_instance_valid(barrier):
			barrier.visibility_layer = HIDDEN_LAYER


func _sync_sprite(source: Node2D, original: AnimatedSprite2D, proxy: Sprite3D) -> void:
	if original.sprite_frames == null:
		return
	var texture := original.sprite_frames.get_frame_texture(original.animation, original.frame)
	if texture == null:
		return
	original.visibility_layer = HIDDEN_LAYER
	proxy.texture = texture
	proxy.visible = source.visible and original.visible
	proxy.flip_h = original.flip_h
	proxy.modulate = source.modulate * original.modulate
	# A neutral-pose silhouette sets scale, never transparent sheet padding.
	# Keep intended species differences while matching the tavern's human scale.
	if not proxy.has_meta("frames") or proxy.get_meta("frames") != original.sprite_frames:
		proxy.set_meta("frames", original.sprite_frames)
		var idle := SlasherSpriteLibrary.resolved_animation(original.sprite_frames, "idle", "down")
		var reference := original.sprite_frames.get_frame_texture(idle, 0)
		var bounds := reference.get_image().get_used_rect()
		var height := 1.65 if source is SlasherPlayer else 1.0
		if source is SlasherEnemy:
			var sizes := {
				"sporeling": 0.65,
				"bandit_cutthroat": 1.3,
				"bandit_knifethrower": 1.3,
				"thornback_boar": 1.05,
				"briar_guardian": 1.9,
				"spore_beast": 1.5,
				"dark_druid": 1.9,
				"ice_mage": 1.65,
				"skeleton": 1.6,
				"skeletal_archer": 1.6,
				"grave_rat": 0.55,
				"ghoul": 1.45,
				"gravedigger": 1.55,
				"revenant": 1.7,
				"tomb_guard": 1.8,
				"necromancer": 1.7,
				"soul_wisp": 1.0,
				"crypt_boss": 2.2
			}
			height = float(
				sizes.get(source.visual_id, 0.95 if source.visual_id.contains("wolf") else 1.5)
			)
			if source.elite:
				height *= 1.15
		proxy.set_meta("bounds", bounds)
		proxy.set_meta("base_scale", original.scale)
		proxy.pixel_size = height / maxf(1.0, bounds.size.y)
	var bounds: Rect2i = proxy.get_meta("bounds")
	var base_scale: Vector2 = proxy.get_meta("base_scale")
	proxy.position = to_world(source.global_position, 0.03)
	proxy.offset = Vector2(
		texture.get_width() * .5 - bounds.get_center().x, bounds.end.y - texture.get_height() * .5
	)
	proxy.scale = Vector3(
		absf(original.scale.x / base_scale.x), absf(original.scale.y / base_scale.y), 1.0
	)


## The skull's jaw drops for the Soul Wail; its eyes burn red when it roars.
## Plays the Heartwood Colossus model's animation for what the boss is doing.
## Wind-ups are sped up or slowed so the blow lands as the telegraph runs out.
func _animate_colossus(boss: SlasherColossus, model: Node3D) -> void:
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		return
	var last_health := int(model.get_meta("last_health", boss.health))
	model.set_meta("last_health", boss.health)
	var key := "%s:%s:%d" % [boss.state, boss.pattern, boss.slams_left]
	if key == String(model.get_meta("anim_key", "")):
		if boss.health < last_health and player.current_animation == "Idle":
			player.play("Hit", 0.05)
			player.queue("Idle")
		return
	model.set_meta("anim_key", key)
	# Seconds into each clip where the blow lands (30 fps in Blender).
	var impact := {"RootSlamL": 25.0 / 30.0, "RootSlamR": 25.0 / 30.0, "SporeBloom": 33.0 / 30.0}
	var clip := "Idle"
	match boss.state:
		"roar":
			clip = "Roar"
		"telegraph", "attack":
			match boss.pattern:
				"root_slam":
					clip = "RootSlamL" if boss.slams_left % 2 == 1 else "RootSlamR"
				"spore_bloom":
					clip = "SporeBloom"
				"thorn_spiral":
					clip = "ThornSpiral"
		"window":
			# Hold the end of a slam (fist on the ground); otherwise settle to idle.
			if player.current_animation.begins_with("RootSlam"):
				return
	if boss.state == "attack" and player.current_animation == clip:
		return
	if not player.has_animation(clip):
		return
	var speed := 1.0
	if boss.state == "telegraph" and impact.has(clip) and boss.timer > 0.05:
		speed = clampf(float(impact[clip]) / boss.timer, 0.5, 2.5)
	player.play(clip, 0.15, speed)
	if clip != "Idle" and clip != "ThornSpiral":
		player.queue("Idle")


func _pose_charnel_king(king: SlasherCharnelKing, model: Node3D) -> void:
	var jaw := model.get_node_or_null("Skull/Jaw") as Node3D
	var wailing := king.pattern == "soul_wail" and king.state in ["telegraph", "attack"]
	if jaw != null:
		jaw.position.y = lerpf(jaw.position.y, -1.15 - (0.55 if wailing else 0.0), 0.2)
	var colour := (
		Color("ff4a3a")
		if king.state == "roar"
		else (Color("7fe0ff") if wailing else Color("9fd8ff"))
	)
	for eye_name in ["Skull/Eye", "Skull/Eye2"]:
		var eye := model.get_node_or_null(eye_name) as MeshInstance3D
		if eye != null and eye.mesh.material is StandardMaterial3D:
			if not eye.has_meta("own"):
				eye.set_meta("own", true)
				eye.material_override = (eye.mesh.material as StandardMaterial3D).duplicate()
			(eye.material_override as StandardMaterial3D).albedo_color = colour
			(eye.material_override as StandardMaterial3D).emission = colour
	var glow := model.get_node_or_null("EyeGlow") as OmniLight3D
	if glow != null:
		glow.light_color = colour


func _update_camera(delta: float) -> void:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(1.0, size.y)
	var target := to_world(dungeon.player.global_position)
	# Small rooms fit on screen; larger rooms follow the player without changing
	# the north-up controls. This also keeps colossus arenas comfortably readable.
	var view_zoom: float = (
		zoom * 1.3 / maxf(0.5, dungeon._settings().get_float("slasher_zoom", 1.3))
	)
	# Guardian arenas pull back (dungeons.json slasher.guardian_camera_zoom) so the goliath fits.
	if bool(dungeon.layout.get("exit_under_body", false)):
		var pull := float(
			(
				Dictionary(
					GameBalance.get_dungeon(dungeon.run_state.active_dungeon_id).get("slasher", {})
				)
				. get("guardian_camera_zoom", 0.72)
			)
		)
		view_zoom /= clampf(pull, 0.72, 1.0)
	var arena := bool(dungeon.layout.get("exit_under_body", false))
	var width := minf(room_size.x + 6.0, 33.0) * view_zoom
	camera.size = maxf(
		width / maxf(aspect, 0.5), (minf(room_size.y, 22.0) * 0.80 + 7.0) * view_zoom
	)
	var half_x := camera.size * aspect * 0.5 - 1.0
	var half_z := camera.size * 0.5 / 0.80 - 1.5
	target.x = (
		room_size.x * 0.5
		if room_size.x < half_x * 2
		else clampf(target.x, half_x, room_size.x - half_x)
	)
	# Guardian arenas: the goliath towers past the north wall, so the camera may
	# look that far north too.
	var top := -7.5 if arena else 0.0
	var span := room_size.y - top
	target.z = (
		top + span * 0.5
		if span < half_z * 2
		else clampf(target.z, top + half_z, room_size.y - half_z)
	)
	focus = focus.lerp(target, 1.0 - exp(-delta * 8.0))
	var shake: Vector2 = dungeon.player.camera.offset / UNIT
	camera.position = focus + Vector3(10 + shake.x, 23, 18 + shake.y)
	camera.look_at(focus)
	# Orthographic projection is affine on the combat plane. Keep Godot's canvas
	# inverse identical, so all existing mouse-aim spells hit the rendered point.
	var origin := camera.unproject_position(to_world(Vector2.ZERO))
	var x_axis := camera.unproject_position(to_world(Vector2.RIGHT)) - origin
	var y_axis := camera.unproject_position(to_world(Vector2.DOWN)) - origin
	get_viewport().canvas_transform = Transform2D(x_axis, y_axis, origin)
	var inverse := Transform2D(x_axis, y_axis, Vector2.ZERO).affine_inverse()
	dungeon.player.spatial_input_basis = inverse
	effects.canvas_transform = Transform2D.IDENTITY


func _unhandled_input(event: InputEvent) -> void:
	if dungeon.player.input_locked or get_tree().paused:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = maxf(0.65, zoom - 0.08)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = minf(1.35, zoom + 0.08)
