class_name SpellEffect
extends Node2D

var caster:Node2D
var rune:Dictionary={}
var form:=""
var direction:=Vector2.RIGHT
var remaining:=0.0
var tick_left:=0.0
var radius:=64.0
var traveled:=0.0
var armed_left:=0.45
var hit_ids:Dictionary={}
var channel_active:=true
var animated_visual:AnimatedSprite2D
const FLAME_START:=preload("res://assets/generated_vfx/flamethrower/flamethrower_start.png")
const FLAME_ACTIVE:=preload("res://assets/generated_vfx/flamethrower/flamethrower_active.png")
const FLAME_END:=preload("res://assets/generated_vfx/flamethrower/flamethrower_end.png")

## Configures a shared beam, area, wave, trap, summon, or environmental actor from one rune record.
func setup(source:Node2D,spell:Dictionary,origin:Vector2,aim:Vector2) -> SpellEffect:
	caster=source;rune=spell;form=str(spell.form);global_position=origin;direction=aim.normalized() if not aim.is_zero_approx() else Vector2.RIGHT
	remaining=float(spell.get("duration",0.0));tick_left=0.0;radius=float(spell.get("radius",64.0))
	if spell.id=="flamethrower":_build_flamethrower_visual()
	queue_redraw()
	return self

## Constructs the preserved generated Flamethrower animation for its maintained beam lifecycle.
func _build_flamethrower_visual() -> void:
	animated_visual=AnimatedSprite2D.new();animated_visual.sprite_frames=SpriteFrames.new();animated_visual.sprite_frames.remove_animation("default")
	_add_strip("start",FLAME_START,3,18.0,false);_add_strip("active",FLAME_ACTIVE,9,24.0,true);_add_strip("end",FLAME_END,6,20.0,false)
	animated_visual.position=direction*80.0;animated_visual.rotation=direction.angle();animated_visual.scale=Vector2(1.25,1.25);add_child(animated_visual);animated_visual.play("start")
	## Advances ignition into the maintained active stream.
	animated_visual.animation_finished.connect(func():if animated_visual.animation=="start":animated_visual.play("active"))

## Slices one generated 128×96 horizontal effect strip into the maintained channel SpriteFrames.
func _add_strip(animation:StringName,texture:Texture2D,count:int,fps:float,loops:bool) -> void:
	animated_visual.sprite_frames.add_animation(animation);animated_visual.sprite_frames.set_animation_speed(animation,fps);animated_visual.sprite_frames.set_animation_loop(animation,loops)
	for index in count:
		var frame:=AtlasTexture.new();frame.atlas=texture;frame.region=Rect2(index*128,0,128,96);animated_visual.sprite_frames.add_frame(animation,frame)

## Advances positioning, lifetime, wavefronts, arming, target acquisition, and periodic damage for every shared form.
func _physics_process(delta:float) -> void:
	if not is_instance_valid(caster):queue_free();return
	if form in ["beam","aura"]:global_position=caster.global_position
	if form=="beam":
		var next_direction:Vector2=(caster.get_global_mouse_position()-caster.global_position).normalized()
		if not next_direction.is_zero_approx():direction=next_direction
		if animated_visual:animated_visual.rotation=direction.angle();animated_visual.position=direction*80.0
	if form=="summoned":global_position=global_position.move_toward(caster.global_position+Vector2(38,18),110.0*delta)
	if form=="wave":traveled+=260.0*delta;remaining-=delta
	elif form!="beam":remaining-=delta
	if form=="trap":armed_left-=delta
	tick_left-=delta
	if tick_left<=0:
		tick_left=float(rune.get("tick_interval",0.25));_apply_tick()
	if form!="beam" and remaining<=0:queue_free()
	queue_redraw()

## Applies one form-specific tick while enforcing eligibility and hit-once rules where appropriate.
func _apply_tick() -> void:
	if form=="aura" and rune.status_effect in ["regeneration","fortify","haste"]:return
	var candidates:=get_tree().get_nodes_in_group("spell_target")
	if form=="summoned":
		var target:=_nearest_target(candidates,280.0)
		if target:_damage(target)
		return
	for target in candidates:
		if not _valid_target(target):continue
		var inside:=false
		match form:
			"beam":inside=_inside_beam(target)
			"aura","zone","environmental":inside=global_position.distance_to(target.global_position)<=radius
			"trap":inside=armed_left<=0 and global_position.distance_to(target.global_position)<=radius
			"wave":inside=abs(global_position.distance_to(target.global_position)-traveled)<34.0 and direction.dot((target.global_position-global_position).normalized())>0.2
		if inside:
			if form=="wave" and hit_ids.has(target.get_instance_id()):continue
			_damage(target);hit_ids[target.get_instance_id()]=true
			if form=="trap":remaining=0;break

## Resolves the nearest active target within a supplied radius for autonomous summoned attacks.
func _nearest_target(candidates:Array,maximum:float) -> Node2D:
	var best:Node2D;var distance:=maximum
	for target in candidates:
		if _valid_target(target):
			var value:=global_position.distance_to(target.global_position)
			if value<distance:distance=value;best=target
	return best

## Tests beam range and width, with Flamethrower using its wider configured cone.
func _inside_beam(target:Node2D) -> bool:
	var offset:Vector2=target.global_position-global_position;var reach:=float(rune.range)*32.0
	if offset.length()>reach:return false
	if rune.id=="flamethrower":return direction.dot(offset.normalized())>=cos(deg_to_rad(float(rune.spread_angle)*0.5))
	var closest:=Geometry2D.get_closest_point_to_segment(target.global_position,global_position,global_position+direction*reach)
	return closest.distance_to(target.global_position)<=18.0

## Applies the rune's common packet and combat feedback contract to one target.
func _damage(target:Node2D) -> void:
	var push:Vector2=(target.global_position-global_position).normalized()
	var packet:=DamagePacket.create(caster,int(rune.power),str(rune.damage_type),str(rune.status_effect),int(rune.status_power),float(rune.knockback),push)
	var accepted:=0
	if target.has_method("receive_damage"):accepted=int(target.receive_damage(packet))
	elif target.has_method("take_cleanse"):target.take_cleanse(packet.base_damage);accepted=packet.base_damage
	if accepted>0:_spawn_impact(target.global_position)

## Spawns a short frame-driven elemental hit animation at an accepted target contact point.
func _spawn_impact(contact_position:Vector2) -> void:
	var parent:=get_parent()
	if not parent:return
	var impact:=SpellImpact.new().setup(str(rune.id),str(rune.damage_type));parent.add_child(impact);impact.global_position=contact_position

## Rejects hidden, inactive, freed, and non-damageable retained encounter nodes.
func _valid_target(target:Node) -> bool:
	if not is_instance_valid(target) or not target is Node2D:return false
	if target is CanvasItem and not target.visible:return false
	if target.has_method("is_combat_target_active") and not target.is_combat_target_active():return false
	return target.has_method("receive_damage") or target.has_method("take_cleanse")

## Draws replaceable elemental placeholders for persistent and instantaneous spell forms.
func _draw() -> void:
	var color:=CombatFeedback.damage_color(str(rune.get("damage_type","spirit")))
	match form:
		"beam":
			if rune.id!="flamethrower":var reach:=float(rune.range)*32.0;draw_line(Vector2.ZERO,direction*reach,color,7.0,true)
		"wave":draw_arc(Vector2.ZERO,traveled,-0.9+direction.angle(),0.9+direction.angle(),24,color,8.0)
		"summoned":draw_circle(Vector2.ZERO,14,color);draw_circle(Vector2.ZERO,7,Color.WHITE)
		_:draw_circle(Vector2.ZERO,radius,Color(color,0.18));draw_arc(Vector2.ZERO,radius,0,TAU,48,color,3.0)
