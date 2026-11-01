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
	# Resolve the last live portion too, even when one slow frame spans expiry.
	delta=minf(delta,maxf(0.0,lifetime-age))
	if delta<=0.0:_finish();return
	age+=delta
	if movement_pattern in ["curve","orbit"]:direction=direction.rotated(angular_velocity*delta)
	if sprite!=null:sprite.rotation=direction.angle()
	if visual_type in ["knife","spore","bone"]:queue_redraw()
	var start:=global_position
	var movement:=direction*minf(speed*delta,maxf(0.0,max_range-traveled))
	var end:=start+movement
	var collision:=SlasherHitGeometry.projectile_wall(self,start,end,collision_mask_value)
	var wall_time:=start.distance_to(collision.position)/maxf(movement.length(),0.0001) if not collision.is_empty() else INF
	var hit:Node2D=null
	var hit_time:=INF
	if is_instance_valid(deflected_by):
		for node in get_tree().get_nodes_in_group("slasher_damageable"):
			if not node is Node2D or not node.has_method("receive_attack") or deflected_hit_ids.has(node.get_instance_id()):continue
			var contact:=SlasherHitGeometry.sweep(start,end,node,hit_radius)
			if contact<hit_time:hit_time=contact;hit=node
	elif is_instance_valid(target):
		hit_time=SlasherHitGeometry.sweep(start,end,target,hit_radius)
		hit=target if hit_time!=INF else null
	if is_instance_valid(hit) and hit_time<wall_time:
		global_position=start.lerp(end,hit_time);traveled+=movement.length()*hit_time
		if is_instance_valid(deflected_by):
			deflected_hit_ids[hit.get_instance_id()]=true
			hit.call("receive_attack",{"damage":damage,"damage_type":"physical","knockback":95.0},deflected_by)
		else:
			var previous_kind:bool=target._receiving_projectile
			target._receiving_projectile=true
			target.receive_damage(damage,direction*95.0,source if is_instance_valid(source) else null)
			if is_instance_valid(target):target._receiving_projectile=previous_kind
		_finish();return
	if wall_time!=INF:
		global_position=collision.position;_finish();return
	global_position=end;traveled+=movement.length()
	if traveled>=max_range or age>=lifetime:_finish()

func deflect(deflector:SlasherPlayer,outgoing_direction:Vector2)->bool:
	if impacted or is_instance_valid(deflected_by) or not is_instance_valid(deflector):return false
	AudioCue.play_from(self,"block")
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
	if visual_type=="spore":
		# A soft glowing spore that pulses as it drifts.
		var pulse:=1.0+sin(age*12.0)*0.15
		draw_circle(Vector2.ZERO,12.0*pulse,Color(tint.r,tint.g,tint.b,0.3));draw_circle(Vector2.ZERO,8.5*pulse,Color(0.12,0.02,0.1,0.9));draw_circle(Vector2.ZERO,7.0*pulse,tint);draw_circle(Vector2(-2,-2),2.6,Color(1,1,0.9,0.9))
		return
	if visual_type=="bone":
		# A tumbling thrown bone.
		draw_set_transform(Vector2.ZERO,age*16.0)
		draw_line(Vector2(-9,0),Vector2(9,0),Color("#3c3740"),6.0);draw_line(Vector2(-9,0),Vector2(9,0),tint,3.5)
		for end in [-1.0,1.0]:draw_circle(Vector2(9.0*end,-2.5),3.2,tint);draw_circle(Vector2(9.0*end,2.5),3.2,tint)
		draw_set_transform(Vector2.ZERO,0.0)
		return
	if visual_type=="knife":
		# A spinning thrown dagger: steel blade, dark grip.
		draw_set_transform(Vector2.ZERO,age*22.0)
		draw_colored_polygon(PackedVector2Array([Vector2(13,0),Vector2(2,-3.5),Vector2(-2,0),Vector2(2,3.5)]),Color("#dfe6ee"))
		draw_line(Vector2(2,-3.5),Vector2(13,0),Color("#8a96a3"),1.0)
		draw_line(Vector2(-1,-5),Vector2(-1,5),Color("#6b4a2b"),2.5)
		draw_line(Vector2(-2,0),Vector2(-9,0),Color("#4a2f1c"),3.0)
		draw_set_transform(Vector2.ZERO,0.0)
		return
	if visual_type=="arrow":draw_line(-direction*13.0,direction*13.0,tint,3.0);draw_colored_polygon(PackedVector2Array([direction*15.0,direction*7.0+direction.orthogonal()*5.0,direction*7.0-direction.orthogonal()*5.0]),tint);return
	var forward:=direction*11.0;var side:=direction.orthogonal()*5.0;draw_colored_polygon(PackedVector2Array([forward,-forward*0.65+side,-forward,-forward*0.65-side]),tint);draw_polyline(PackedVector2Array([forward,-forward*0.65+side,-forward,-forward*0.65-side,forward]),tint.darkened(0.55),2.0)
