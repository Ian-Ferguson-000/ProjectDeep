extends Node2D
class_name SlasherProjectile

signal hit_landed(target:Node2D,travel_distance:float)

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
	var movement:=direction*speed*delta
	var query:=PhysicsRayQueryParameters2D.create(global_position,global_position+movement,1)
	query.exclude.append(source.get_rid())
	var collision:=get_world_2d().direct_space_state.intersect_ray(query)
	if not collision.is_empty() and collision.get("collider") is StaticBody2D:
		var collider:Node2D=collision.get("collider") as Node2D
		if is_instance_valid(collider) and collider.is_in_group("slasher_damageable"):
			_damage_impact(collider)
			if not piercing:_impact(false);return
		else:_impact(true);return
	global_position+=movement;traveled+=movement.length()
	for node in get_tree().get_nodes_in_group("slasher_damageable"):
		if node is Node2D and not hit_ids.has(node.get_instance_id()) and global_position.distance_to(node.global_position)<=float(attack.get("hit_radius",24.0)):
			_damage_impact(node)
			if not piercing:_impact(false);return
	if traveled>=max_range:_impact(true)

func _damage_impact(primary:Node2D=null)->void:
	var radius:float=float(attack.get("area_radius",0.0))
	if radius<=0.0:
		if is_instance_valid(primary):_damage_target(primary)
		return
	_spawn_splash_visual(radius)
	for node_value:Variant in get_tree().get_nodes_in_group("slasher_damageable"):
		var damageable:Node2D=node_value as Node2D
		if is_instance_valid(damageable) and global_position.distance_to(damageable.global_position)<=radius:_damage_target(damageable)

func _damage_target(target:Node2D)->void:
	var target_id:int=target.get_instance_id()
	if hit_ids.has(target_id) or not target.has_method("receive_attack"):return
	hit_ids[target_id]=true;target.call("receive_attack",attack,source);hit_landed.emit(target,traveled)

func _spawn_splash_visual(radius:float)->void:
	var effect:=AnimatedSprite2D.new();var frames:=SpriteFrames.new();frames.remove_animation("default");frames.add_animation("splash");frames.set_animation_speed("splash",20.0);frames.set_animation_loop("splash",false)
	var visual:String=String(attack.get("visual","aether"));var texture:Texture2D=FIREBALL_IMPACT if visual=="fireball" else AETHER_IMPACT
	for index in 8:
		var frame:=AtlasTexture.new();frame.atlas=texture;frame.region=Rect2(index*48,0,48,32);frames.add_frame("splash",frame)
	effect.sprite_frames=frames;effect.global_position=global_position;effect.modulate=Color(String(attack.get("tint","#ffffff")));effect.scale=Vector2.ONE*maxf(1.0,radius/32.0);get_parent().add_child(effect);effect.animation_finished.connect(effect.queue_free);effect.play("splash")

func _impact(apply_splash:bool)->void:
	if impacted:return
	if apply_splash:_damage_impact()
	impacted=true;sprite.play("impact")

func _on_animation_finished()->void:
	if sprite.animation=="start":sprite.play("flight")
	elif sprite.animation=="impact":queue_free()

func _add_strip(name:StringName,texture:Texture2D,count:int,fps:float,loop:bool)->void:
	sprite.sprite_frames.add_animation(name);sprite.sprite_frames.set_animation_speed(name,fps);sprite.sprite_frames.set_animation_loop(name,loop)
	for index in count:
		var frame:=AtlasTexture.new();frame.atlas=texture;frame.region=Rect2(index*48,0,48,32);sprite.sprite_frames.add_frame(name,frame)
