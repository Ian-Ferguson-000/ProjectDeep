extends Node2D
class_name SlasherProjectile

signal hit_landed(target:Node2D,travel_distance:float)
signal impact_resolved(position:Vector2,attack:Dictionary)

const FIREBALL_START:=preload("res://assets/effect_packs/fireball/fireball_start.png")
const FIREBALL_FLIGHT:=preload("res://assets/effect_packs/fireball/fireball_flight.png")
const FIREBALL_IMPACT:=preload("res://assets/effect_packs/fireball/fireball_impact.png")
const AETHER_START:=preload("res://assets/effect_packs/Aether Effect 01/Aether VFX 1/Ice VFX 1 Start.png")
const AETHER_FLIGHT:=preload("res://assets/effect_packs/Aether Effect 01/Aether VFX 1/IceVFX 1 Repeatable.png")
const AETHER_IMPACT:=preload("res://assets/effect_packs/Aether Effect 01/Aether VFX 1/Ice VFX 1 Hit.png")

var attack: Dictionary = {}
var source: SlasherPlayer
var direction:=Vector2.RIGHT
var speed:=520.0
var max_range:=320.0
var traveled:=0.0
var piercing:=false
var impacted:=false
var hit_ids: Dictionary = {}
var sprite: AnimatedSprite2D

func setup(owner:SlasherPlayer,origin:Vector2,aim:Vector2,attack_data:Dictionary)->SlasherProjectile:
	source=owner;global_position=origin;direction=aim.normalized() if not aim.is_zero_approx() else Vector2.RIGHT;attack=attack_data.duplicate(true)
	speed=float(attack.get("speed",520.0));max_range=float(attack.get("range",320.0));piercing=bool(attack.get("piercing",false));return self

func _ready()->void:
	sprite=AnimatedSprite2D.new();sprite.name="ProjectileAnimation";sprite.sprite_frames=SpriteFrames.new();sprite.sprite_frames.remove_animation("default");sprite.rotation=direction.angle();sprite.scale=Vector2.ONE*float(attack.get("visual_scale",1.4));add_child(sprite)
	var visual:=String(attack.get("visual","aether"));var tint:=Color(String(attack.get("tint","#ffffff")));sprite.modulate=tint
	_add_strip("start",FIREBALL_START if visual=="fireball" else AETHER_START,3,14.0,false)
	_add_strip("flight",FIREBALL_FLIGHT if visual=="fireball" else AETHER_FLIGHT,10,18.0,true)
	_add_strip("impact",FIREBALL_IMPACT if visual=="fireball" else AETHER_IMPACT,8,20.0,false)
	sprite.animation_finished.connect(_on_animation_finished);sprite.play("start")

func _physics_process(delta:float)->void:
	if impacted:return
	if not is_instance_valid(source):queue_free();return
	var start:=global_position
	var movement:=direction*minf(speed*delta,maxf(0.0,max_range-traveled))
	var end:=start+movement
	var collision:=SlasherHitGeometry.projectile_wall(self,start,end,1)
	var wall_time:=start.distance_to(collision.position)/maxf(movement.length(),0.0001) if not collision.is_empty() else INF
	var contacts:Array[Dictionary]=[]
	for node in get_tree().get_nodes_in_group("slasher_damageable"):
		if not node is Node2D or not node.has_method("receive_attack") or hit_ids.has(node.get_instance_id()):continue
		var contact:=SlasherHitGeometry.sweep(start,end,node,float(attack.get("hit_radius",24.0)))
		if contact<wall_time:contacts.append({"target":node,"time":contact})
	contacts.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return float(a.time)<float(b.time))
	var initial_traveled:=traveled
	for contact in contacts:
		if not is_instance_valid(contact.target) or hit_ids.has(contact.target.get_instance_id()):continue
		global_position=start.lerp(end,float(contact.time));traveled=initial_traveled+movement.length()*float(contact.time)
		_damage_impact(contact.target)
		if not piercing:_impact(false);return
	if wall_time!=INF:
		global_position=collision.position;traveled=initial_traveled+movement.length()*wall_time
		var collider:Node2D=collision.get("collider") as Node2D
		if is_instance_valid(collider) and collider.is_in_group("slasher_damageable"):
			_damage_impact(collider);_impact(false)
		else:_impact(true)
		return
	global_position=end;traveled=initial_traveled+movement.length()
	if traveled>=max_range:_impact(true)

func _damage_impact(primary:Node2D=null)->void:
	var radius:float=float(attack.get("area_radius",0.0))
	if radius<=0.0:
		if is_instance_valid(primary):_damage_target(primary)
		return
	_spawn_splash_visual(radius)
	for node_value:Variant in get_tree().get_nodes_in_group("slasher_damageable"):
		var damageable:Node2D=node_value as Node2D
		if is_instance_valid(damageable) and SlasherHitGeometry.overlaps_circle(global_position,radius,damageable):_damage_target(damageable)

func _damage_target(target:Node2D)->void:
	var target_id:int=target.get_instance_id()
	if hit_ids.has(target_id) or not target.has_method("receive_attack"):return
	hit_ids[target_id]=true
	var strike:Dictionary=source.item_runtime.adjust_for_target(attack,target) if is_instance_valid(source) and source.item_runtime and target.is_in_group("slasher_enemy") else attack
	if is_instance_valid(source):strike=source.adjust_active_weapon_attack(target,strike)
	target.call("receive_attack",strike,source);hit_landed.emit(target,traveled)

func _spawn_splash_visual(radius:float)->void:
	var effect:=AnimatedSprite2D.new();var frames:=SpriteFrames.new();frames.remove_animation("default");frames.add_animation("splash");frames.set_animation_speed("splash",20.0);frames.set_animation_loop("splash",false)
	var visual:String=String(attack.get("visual","aether"));var texture:Texture2D=FIREBALL_IMPACT if visual=="fireball" else AETHER_IMPACT
	for index in 8:
		var frame:=AtlasTexture.new();frame.atlas=texture;frame.region=Rect2(index*48,0,48,32);frames.add_frame("splash",frame)
	effect.sprite_frames=frames;effect.global_position=global_position;effect.modulate=Color(String(attack.get("tint","#ffffff")));effect.scale=Vector2.ONE*maxf(1.0,radius/32.0);get_parent().add_child(effect);effect.animation_finished.connect(effect.queue_free);effect.play("splash")

func _impact(apply_splash:bool)->void:
	if impacted:return
	if apply_splash:_damage_impact()
	if hit_ids.is_empty() and is_instance_valid(source) and source.has_method("notify_active_projectile_miss"):source.notify_active_projectile_miss(attack)
	impacted=true;impact_resolved.emit(global_position,attack.duplicate(true));sprite.play("impact")

func _on_animation_finished()->void:
	if sprite.animation=="start":sprite.play("flight")
	elif sprite.animation=="impact":queue_free()

func _add_strip(name:StringName,texture:Texture2D,count:int,fps:float,loop:bool)->void:
	sprite.sprite_frames.add_animation(name);sprite.sprite_frames.set_animation_speed(name,fps);sprite.sprite_frames.set_animation_loop(name,loop)
	for index in count:
		var frame:=AtlasTexture.new();frame.atlas=texture;frame.region=Rect2(index*48,0,48,32);sprite.sprite_frames.add_frame(name,frame)
