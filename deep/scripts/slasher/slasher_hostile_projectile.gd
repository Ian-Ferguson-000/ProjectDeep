extends Node2D
class_name SlasherHostileProjectile

var source:SlasherEnemy
var target:SlasherPlayer
var direction:=Vector2.RIGHT
var speed:=280.0
var max_range:=280.0
var traveled:=0.0
var damage:=1
var hit_radius:=13.0
var tint:=Color("#c9ef72")
var impacted:=false
var movement_pattern:="straight"
var angular_velocity:=0.0
var lifetime:=3.0
var age:=0.0
var visual_type:="bolt"
var collision_mask_value:=1
var target_snapshot:=Vector2.ZERO
var sprite:AnimatedSprite2D
var deflected_by:SlasherPlayer
var deflected_hit_ids:Dictionary={}

func setup(owner:SlasherEnemy,player:SlasherPlayer,origin:Vector2,aim:Vector2,projectile_damage:int,config:Dictionary,target_point:Vector2=Vector2.INF)->SlasherHostileProjectile:
	source=owner;target=player;global_position=origin;direction=aim.normalized() if not aim.is_zero_approx() else Vector2.RIGHT
	damage=maxi(1,projectile_damage);speed=float(config.get("projectile_speed",config.get("burst_speed",285.0)));max_range=float(config.get("projectile_range",config.get("burst_range",285.0)));hit_radius=float(config.get("hit_radius",config.get("burst_hit_radius",13.0)));tint=Color(String(config.get("color",config.get("burst_color","#c9ef72"))))
	movement_pattern=String(config.get("movement_pattern","straight"));angular_velocity=float(config.get("angular_velocity",0.0));lifetime=float(config.get("lifetime",maxf(1.0,max_range/maxf(1.0,speed)+0.5)));visual_type=String(config.get("visual_type","bolt"));collision_mask_value=int(config.get("collision_mask",1));target_snapshot=target_point if target_point!=Vector2.INF else (player.global_position if is_instance_valid(player) else origin+direction*max_range);return self

func _ready()->void:
	z_index=4
	add_to_group("slasher_hostile_projectile")
	var frames:=SlasherSpriteLibrary.hostile_projectile_frames(visual_type)
	if frames!=null:
		sprite=AnimatedSprite2D.new();sprite.name="ProjectileAnimation";sprite.sprite_frames=frames;sprite.rotation=direction.angle();sprite.scale=Vector2.ONE*SlasherSpriteLibrary.hostile_projectile_scale(visual_type);sprite.play("flight");add_child(sprite)
	queue_redraw()

func _physics_process(delta:float)->void:
	if impacted:return
	age+=delta
	if age>=lifetime:_finish();return
	if movement_pattern in ["curve","orbit"]:direction=direction.rotated(angular_velocity*delta)
	if sprite!=null:sprite.rotation=direction.angle()
	var movement:=direction*speed*delta
	var query:=PhysicsRayQueryParameters2D.create(global_position,global_position+movement,collision_mask_value)
	if is_instance_valid(source):query.exclude.append(source.get_rid())
	var collision:=get_world_2d().direct_space_state.intersect_ray(query)
	if not collision.is_empty() and collision.get("collider") is StaticBody2D:_finish();return
	global_position+=movement;traveled+=movement.length()
	if is_instance_valid(deflected_by):
		for node_value:Variant in get_tree().get_nodes_in_group("slasher_enemy"):
			var enemy:SlasherEnemy=node_value as SlasherEnemy
			if not is_instance_valid(enemy) or deflected_hit_ids.has(enemy.get_instance_id()):continue
			if global_position.distance_to(enemy.global_position)<=hit_radius:
				deflected_hit_ids[enemy.get_instance_id()]=true
				enemy.receive_attack({"damage":damage,"damage_type":"physical","knockback":95.0},deflected_by)
				_finish();return
		if traveled>=max_range:_finish()
		return
	if is_instance_valid(target) and global_position.distance_to(target.global_position)<=hit_radius:
		target.receive_damage(damage,direction*95.0,source if is_instance_valid(source) else null);_finish();return
	if traveled>=max_range:_finish()

func deflect(deflector:SlasherPlayer,outgoing_direction:Vector2)->bool:
	if impacted or is_instance_valid(deflected_by) or not is_instance_valid(deflector):return false
	deflected_by=deflector
	direction=outgoing_direction.normalized() if not outgoing_direction.is_zero_approx() else -direction
	movement_pattern="straight";angular_velocity=0.0;traveled=0.0;age=0.0
	if sprite!=null:sprite.rotation=direction.angle();sprite.modulate=Color("#dffcff")
	queue_redraw()
	return true

func _finish()->void:
	if impacted:return
	impacted=true;queue_free()

func _draw()->void:
	if sprite!=null:return
	if visual_type=="soul":draw_circle(Vector2.ZERO,8.0,tint);draw_circle(Vector2.ZERO,3.5,Color("#e8ffff"));return
	if visual_type=="arrow":draw_line(-direction*13.0,direction*13.0,tint,3.0);draw_colored_polygon(PackedVector2Array([direction*15.0,direction*7.0+direction.orthogonal()*5.0,direction*7.0-direction.orthogonal()*5.0]),tint);return
	var forward:=direction*11.0;var side:=direction.orthogonal()*5.0;draw_colored_polygon(PackedVector2Array([forward,-forward*0.65+side,-forward,-forward*0.65-side]),tint);draw_polyline(PackedVector2Array([forward,-forward*0.65+side,-forward,-forward*0.65-side,forward]),tint.darkened(0.55),2.0)
