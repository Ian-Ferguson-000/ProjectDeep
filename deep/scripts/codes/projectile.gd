class_name CleanseProjectile
extends Node2D
var velocity := Vector2.ZERO
var lifetime := 1.5
var packet: DamagePacket
var max_distance:=384.0
var traveled:=0.0
var rune_id:=""
var impacted:=false
var animated_visual:AnimatedSprite2D
var aim_direction:=Vector2.RIGHT
var is_flamethrower:=false
var flamethrower_elapsed:=0.0
var flamethrower_active_time:=0.42
var flamethrower_hits:={}
const FLAMETHROWER_HALF_ANGLE:=26.0
const AETHER_START:=preload("res://assets/effect_packs/Aether Effect 01/Aether VFX 1/Ice VFX 1 Start.png")
const AETHER_FLIGHT:=preload("res://assets/effect_packs/Aether Effect 01/Aether VFX 1/IceVFX 1 Repeatable.png")
const AETHER_HIT:=preload("res://assets/effect_packs/Aether Effect 01/Aether VFX 1/Ice VFX 1 Hit.png")
const FIREBALL_START:=preload("res://assets/generated_vfx/fireball/fireball_start.png")
const FIREBALL_FLIGHT:=preload("res://assets/generated_vfx/fireball/fireball_flight.png")
const FIREBALL_HIT:=preload("res://assets/generated_vfx/fireball/fireball_impact.png")
const FLAMETHROWER_START:=preload("res://assets/generated_vfx/flamethrower/flamethrower_start.png")
const FLAMETHROWER_ACTIVE:=preload("res://assets/generated_vfx/flamethrower/flamethrower_active.png")
const FLAMETHROWER_END:=preload("res://assets/generated_vfx/flamethrower/flamethrower_end.png")
## Initializes position, velocity, damage/status packet, and maximum range from rune metadata. Call before
## parenting into RuntimeEntities.
func setup(origin: Vector2, direction: Vector2, rune: Dictionary = {}) -> CleanseProjectile:
	position=origin; aim_direction=direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	velocity=aim_direction*520.0
	rune_id=str(rune.get("id",""))
	packet=DamagePacket.create(null,int(rune.get("power",1)),str(rune.get("damage_type","spirit")),str(rune.get("status_effect","")),int(rune.get("status_power",0)),float(rune.get("knockback",90.0)),direction)
	max_distance=float(rune.get("range",12.0))*32.0
	if rune_id=="aether_blast": _build_aether_animation(direction)
	elif rune_id=="fireball": _build_fireball_animation(direction)
	elif rune_id=="flamethrower":
		is_flamethrower=true; velocity=Vector2.ZERO; lifetime=0.75
		_build_flamethrower_animation(aim_direction)
	return self

## Builds the Aether Blast startup, looping flight, and impact animations from the supplied effect sheets.
func _build_aether_animation(direction: Vector2) -> void:
	_build_projectile_animation(direction,AETHER_START,AETHER_FLIGHT,AETHER_HIT,1.35)

## Builds Fireball's generated startup, looping flame trail, and dissipating impact animations.
func _build_fireball_animation(direction: Vector2) -> void:
	_build_projectile_animation(direction,FIREBALL_START,FIREBALL_FLIGHT,FIREBALL_HIT,1.5)

## Builds Flamethrower's ignition, sustained cone, and ember-dissipation animation from generated strips.
func _build_flamethrower_animation(direction: Vector2) -> void:
	animated_visual=AnimatedSprite2D.new(); animated_visual.name="FlamethrowerAnimation"
	animated_visual.sprite_frames=SpriteFrames.new(); animated_visual.sprite_frames.remove_animation("default")
	_add_sized_sheet_animation(animated_visual.sprite_frames,"start",FLAMETHROWER_START,3,18.0,false,Vector2i(128,96))
	_add_sized_sheet_animation(animated_visual.sprite_frames,"active",FLAMETHROWER_ACTIVE,9,24.0,true,Vector2i(128,96))
	_add_sized_sheet_animation(animated_visual.sprite_frames,"end",FLAMETHROWER_END,6,20.0,false,Vector2i(128,96))
	animated_visual.rotation=direction.angle(); animated_visual.position=direction*80.0
	animated_visual.scale=Vector2(1.25,1.25); animated_visual.animation_finished.connect(_on_animation_finished)
	add_child(animated_visual); animated_visual.play("start")

## Creates the shared three-stage AnimatedSprite2D lifecycle from spell-specific horizontal strips.
func _build_projectile_animation(direction: Vector2, start_texture: Texture2D, flight_texture: Texture2D, hit_texture: Texture2D, visual_scale: float) -> void:
	animated_visual=AnimatedSprite2D.new(); animated_visual.name="ProjectileAnimation"
	animated_visual.sprite_frames=SpriteFrames.new(); animated_visual.sprite_frames.remove_animation("default")
	_add_sheet_animation(animated_visual.sprite_frames,"start",start_texture,3,14.0,false)
	_add_sheet_animation(animated_visual.sprite_frames,"flight",flight_texture,10,16.0,true)
	_add_sheet_animation(animated_visual.sprite_frames,"impact",hit_texture,8,18.0,false)
	animated_visual.rotation=direction.angle(); animated_visual.scale=Vector2(visual_scale,visual_scale)
	animated_visual.animation_finished.connect(_on_animation_finished)
	add_child(animated_visual); animated_visual.play("start")

## Slices one horizontal 48×32 effect sheet into an animation without duplicating source textures.
func _add_sheet_animation(frames: SpriteFrames, animation: StringName, texture: Texture2D, count: int, fps: float, loops: bool) -> void:
	_add_sized_sheet_animation(frames,animation,texture,count,fps,loops,Vector2i(48,32))

## Slices a horizontal effect strip using a caller-provided frame size for non-projectile spell shapes.
func _add_sized_sheet_animation(frames: SpriteFrames, animation: StringName, texture: Texture2D, count: int, fps: float, loops: bool, frame_size: Vector2i) -> void:
	frames.add_animation(animation); frames.set_animation_speed(animation,fps); frames.set_animation_loop(animation,loops)
	for index in count:
		var frame:=AtlasTexture.new(); frame.atlas=texture; frame.region=Rect2(index*frame_size.x,0,frame_size.x,frame_size.y)
		frames.add_frame(animation,frame)

## Advances startup into looping flight and removes the projectile after its non-looping impact completes.
func _on_animation_finished() -> void:
	if not animated_visual: return
	if animated_visual.animation=="start": animated_visual.play("active" if is_flamethrower else "flight")
	elif animated_visual.animation in ["impact","end"]: queue_free()

## Stops travel at an optional contact point, plays a bespoke strip, or spawns generic impact frames.
func _begin_impact(contact_position:Variant=null) -> void:
	if impacted: return
	impacted=true; velocity=Vector2.ZERO
	if contact_position is Vector2:global_position=contact_position
	if animated_visual and animated_visual.sprite_frames.has_animation("impact"):animated_visual.play("impact")
	else:_spawn_impact_frames();queue_free()
	queue_redraw()

## Adds a frame-driven generic elemental impact beside this projectile before it is removed.
func _spawn_impact_frames() -> void:
	var parent:=get_parent()
	if not parent:return
	var impact:=SpellImpact.new().setup(rune_id,packet.damage_type if packet else "spirit");parent.add_child(impact);impact.global_position=global_position
## Moves, tracks lifetime/range, finds the first nearby spell target, applies one packet, and frees itself.
## This is proximity collision, not a physics Area2D.
func _physics_process(delta: float) -> void:
	if impacted: return
	if is_flamethrower:
		_process_flamethrower(delta)
		return
	var movement:=velocity*delta
	if is_inside_tree():
		var query:=PhysicsRayQueryParameters2D.create(global_position,global_position+movement,1)
		var collision:=get_world_2d().direct_space_state.intersect_ray(query)
		if not collision.is_empty():_begin_impact(collision.position);return
	position += movement; traveled+=movement.length(); lifetime -= delta
	for target in get_tree().get_nodes_in_group("spell_target"):
		if _is_valid_spell_target(target) and global_position.distance_to(target.global_position) < 48:
			packet.source=self
			if target.has_method("receive_damage"): target.receive_damage(packet)
			elif target.has_method("take_cleanse"): target.take_cleanse(packet.base_damage)
			_begin_impact(target.global_position); return
	if lifetime <= 0 or traveled>=max_distance: _begin_impact()

## Damages each eligible target once inside the aimed cone, then advances into the extinguish animation.
func _process_flamethrower(delta: float) -> void:
	flamethrower_elapsed+=delta
	for target in get_tree().get_nodes_in_group("spell_target"):
		if not _is_valid_spell_target(target) or flamethrower_hits.has(target.get_instance_id()): continue
		if _is_in_flamethrower_cone(target.global_position):
			flamethrower_hits[target.get_instance_id()]=true; packet.source=self
			if target.has_method("receive_damage"): target.receive_damage(packet)
			elif target.has_method("take_cleanse"): target.take_cleanse(packet.base_damage)
	if flamethrower_elapsed>=flamethrower_active_time:
		impacted=true
		if animated_visual: animated_visual.play("end")
		else: queue_free()

## Reports whether a world position lies within the configured range and angular width of the flame cone.
func _is_in_flamethrower_cone(target_position: Vector2) -> bool:
	var offset:=target_position-global_position
	if offset.length_squared()<1.0 or offset.length()>max_distance: return false
	return aim_direction.dot(offset.normalized())>=cos(deg_to_rad(FLAMETHROWER_HALF_ANGLE))

## Rejects freed, hidden, defeated, or cleansed targets so their retained encounter nodes cannot block shots.
func _is_valid_spell_target(target: Node) -> bool:
	if not is_instance_valid(target) or not target is Node2D: return false
	if target is CanvasItem and not target.visible: return false
	if target.has_method("is_combat_target_active") and not target.is_combat_target_active(): return false
	return true
## Draws the current generic cleansing-orb placeholder.
func _draw() -> void:
	if rune_id not in ["aether_blast","fireball","flamethrower"] and not impacted:
		var color:=CombatFeedback.damage_color(packet.damage_type if packet else "spirit");draw_circle(Vector2.ZERO,10,color);draw_circle(Vector2.ZERO,5,Color.WHITE)
