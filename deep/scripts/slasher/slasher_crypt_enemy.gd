extends SlasherEnemy
class_name SlasherCryptEnemy

var pattern_index:=0
var pattern_cooldown:=1.4
var transition_time:=0.0
var strafe_sign:=1.0
var summon_phase_mask:=0
var projectile_cap:=72
var crypt_floor:=1
var queued_pattern:=-1

func configure(floor_number:int,is_boss:bool=false,enemy_visual_id:String="skeletal_archer",is_mini_boss:bool=false,enemy_behavior_id:String="skeletal_archer")->void:
	super.configure(floor_number,is_boss,enemy_visual_id,is_mini_boss,enemy_behavior_id)
	crypt_floor=floor_number
	behavior_id=enemy_behavior_id if not enemy_behavior_id.is_empty() else ("crypt_lord" if is_boss else enemy_visual_id)
	behavior_tuning=GameBalance.get_slasher_enemy_tuning(behavior_id)
	visual_id=enemy_visual_id;visual_tuning=GameBalance.get_slasher_enemy_visual_tuning(visual_id)
	max_health=int(behavior_tuning.get("health_base",220 if is_boss else 22))+floor_number*int(behavior_tuning.get("health_per_floor",16 if is_boss else 3));health=max_health
	damage=int(behavior_tuning.get("damage_base",6 if is_boss else 2))+floor_number*int(behavior_tuning.get("damage_per_floor",1));speed=float(behavior_tuning.get("speed",72.0));attack_range=float(behavior_tuning.get("preferred_range",245.0));reward=int(behavior_tuning.get("reward",28 if is_boss else 5));projectile_cap=int(behavior_tuning.get("projectile_cap",72));boss=is_boss;mini_boss=is_mini_boss;elite=is_mini_boss

func _physics_process(delta:float)->void:
	if behavior_id not in ["skeletal_archer","grave_acolyte","soul_wisp","crypt_lord"]:super._physics_process(delta);return
	retarget_timer-=delta
	if retarget_timer<=0.0:_retarget_party();retarget_timer=0.4
	if dead or not is_instance_valid(target):return
	activation_delay=maxf(0.0,activation_delay-delta);attack_cooldown=maxf(0.0,attack_cooldown-delta);special_cooldown=maxf(0.0,special_cooldown-delta);state_timer=maxf(0.0,state_timer-delta);transition_time=maxf(0.0,transition_time-delta);pattern_cooldown=maxf(0.0,pattern_cooldown-delta)
	if activation_delay>0.0 or transition_time>0.0:velocity=Vector2.ZERO;_play_animation("idle");queue_redraw();return
	match behavior_id:
		"skeletal_archer":_process_archer()
		"grave_acolyte":_process_acolyte()
		"soul_wisp":_process_wisp(delta)
		"crypt_lord":_process_crypt_lord()
	queue_redraw()

func _process_archer()->void:
	var distance:=global_position.distance_to(target.global_position);var preferred:=float(behavior_tuning.get("preferred_range",250.0));var retreat:=float(behavior_tuning.get("retreat_range",145.0))
	if ai_state=="ranged_windup":
		velocity=Vector2.ZERO
		if state_timer<=0.0:_fire_fan(3 if crypt_floor>=int(behavior_tuning.get("spread_floor",4)) else 1,0.15,"arrow",false);ai_state="idle";attack_cooldown=float(behavior_tuning.get("cooldown",1.7))
		return
	if distance<retreat:_move_toward(global_position+(global_position-target.global_position).normalized()*preferred)
	elif distance>preferred*1.25:_move_toward(target.global_position)
	elif attack_cooldown<=0.0 and _has_line_of_sight():_begin_ranged_windup(float(behavior_tuning.get("telegraph",0.65)))
	else:velocity=Vector2.ZERO;_play_animation("idle")

func _process_acolyte()->void:
	var distance:=global_position.distance_to(target.global_position);var preferred:=float(behavior_tuning.get("preferred_range",220.0))
	if ai_state=="ranged_windup":
		velocity=Vector2.ZERO
		if state_timer<=0.0:_delayed_impact(captured_target);ai_state="idle";attack_cooldown=float(behavior_tuning.get("cooldown",2.5))
		return
	if distance<130.0:_move_toward(global_position+(global_position-target.global_position).normalized()*preferred)
	elif distance>preferred*1.35:_move_toward(target.global_position)
	elif attack_cooldown<=0.0:captured_target=target.global_position+target.velocity*0.42;_begin_ranged_windup(float(behavior_tuning.get("telegraph",0.9)))
	else:velocity=Vector2.ZERO;_play_animation("idle")

func _process_wisp(delta:float)->void:
	var distance:=global_position.distance_to(target.global_position);var preferred:=float(behavior_tuning.get("preferred_range",190.0));var radial:=global_position.direction_to(target.global_position)
	if absf(distance-preferred)>35.0:_move_toward(target.global_position-radial*preferred)
	else:
		velocity=radial.orthogonal()*strafe_sign*speed;move_and_slide();_play_animation("run")
	if attack_cooldown<=0.0:
		var predicted:=target.global_position+target.velocity*0.32;_spawn_projectile(global_position,global_position.direction_to(predicted),{"projectile_speed":205.0,"projectile_range":360.0,"hit_radius":10.0,"color":"#66ddff","visual_type":"soul","movement_pattern":"curve","angular_velocity":0.18*strafe_sign});attack_cooldown=float(behavior_tuning.get("cooldown",1.55));strafe_sign*=-1.0
	if special_cooldown<=0.0:_radial_ring(6,pattern_index*0.22,105.0,0.16,true);pattern_index+=1;special_cooldown=float(behavior_tuning.get("burst_cooldown",5.0))

func _process_crypt_lord()->void:
	var fraction:=float(health)/maxf(1.0,float(max_health));var desired:=2 if fraction<=0.35 else (1 if fraction<=0.70 else 0)
	if desired>boss_phase:_enter_phase(desired);return
	if ai_state=="boss_windup":
		velocity=Vector2.ZERO
		if state_timer<=0.0:ai_state="idle";_release_boss_pattern()
		return
	if pattern_cooldown>0.0:return
	queued_pattern=pattern_index%3;ai_state="boss_windup";state_timer=0.72 if boss_phase==0 else (0.62 if boss_phase==1 else 0.52);captured_target=target.global_position;_play_animation("attack",true)

func _release_boss_pattern()->void:
	match boss_phase:
		0:
			if pattern_index%2==0:_fire_fan(5,0.17,"soul",true)
			else:_gap_ring(14,3,pattern_index*0.19,175.0,0.0)
			pattern_cooldown=1.65
		1:
			if pattern_index%3==0:_delayed_impact(target.global_position+target.velocity*0.35)
			elif pattern_index%3==1:_radial_ring(12,pattern_index*0.31,160.0,0.34,true)
			else:_gap_ring(18,4,pattern_index*0.21,185.0,0.0)
			if summon_phase_mask&1==0:summon_phase_mask|=1;reinforcement_requested.emit(["skeletal_archer","grave_acolyte"],global_position)
			pattern_cooldown=1.35
		2:
			if pattern_index%3==0:_radial_ring(14,pattern_index*0.20,178.0,0.40,true);_radial_ring(14,-pattern_index*0.17,178.0,-0.40,true)
			elif pattern_index%3==1:_fire_fan(7,0.13,"soul",true)
			else:_lane_sweep()
			pattern_cooldown=1.15
	pattern_index+=1

func _enter_phase(value:int)->void:
	boss_phase=value;transition_time=0.8;pattern_cooldown=1.0;velocity=Vector2.ZERO
	if pathfinder!=null:global_position=pathfinder.cell_to_world(pathfinder.nearest_walkable_cell(pathfinder.world_to_cell(global_position)))
	for projectile in get_tree().get_nodes_in_group("crypt_projectile"):
		if is_instance_valid(projectile) and projectile.global_position.distance_to(global_position)<150.0:projectile.queue_free()

func _begin_ranged_windup(duration:float)->void:
	ai_state="ranged_windup";state_timer=duration;captured_target=target.global_position;facing_name=SlasherSpriteLibrary.direction_name(global_position.direction_to(captured_target),facing_name);_play_animation("attack",true)

func _has_line_of_sight()->bool:
	var query:=PhysicsRayQueryParameters2D.create(global_position,target.global_position,1);query.exclude=[get_rid()];var hit:=get_world_2d().direct_space_state.intersect_ray(query);return hit.is_empty() or hit.get("collider")==target

func _fire_fan(count:int,spread:float,visual:String,predictive:bool)->void:
	var point:=target.global_position+(target.velocity*0.35 if predictive else Vector2.ZERO);var center:=global_position.direction_to(point)
	for index:int in count:
		var offset:=(float(index)-float(count-1)/2.0)*spread;_spawn_projectile(global_position+center*24.0,center.rotated(offset),{"projectile_speed":245.0,"projectile_range":520.0,"hit_radius":11.0,"color":"#8beaff" if visual=="soul" else "#d8c3a2","visual_type":visual})

func _radial_ring(count:int,rotation:float,projectile_speed:float,curve:float,soul:bool)->void:
	for index:int in count:
		var direction:=Vector2.RIGHT.rotated(rotation+TAU*float(index)/float(count));_spawn_projectile(global_position+direction*28.0,direction,{"projectile_speed":projectile_speed,"projectile_range":560.0,"hit_radius":10.0,"color":"#7ae9ff","visual_type":"soul" if soul else "bolt","movement_pattern":"curve" if not is_zero_approx(curve) else "straight","angular_velocity":curve})

func _gap_ring(count:int,gap_count:int,rotation:float,projectile_speed:float,curve:float)->void:
	var gap_center:=global_position.direction_to(target.global_position).angle()
	for index:int in count:
		var angle:=rotation+TAU*float(index)/float(count)
		if absf(wrapf(angle-gap_center,-PI,PI))<TAU*float(gap_count)/float(count)*0.5:continue
		_spawn_projectile(global_position+Vector2.RIGHT.rotated(angle)*28.0,Vector2.RIGHT.rotated(angle),{"projectile_speed":projectile_speed,"projectile_range":560.0,"hit_radius":10.0,"color":"#a278ff","visual_type":"soul","movement_pattern":"curve","angular_velocity":curve})

func _delayed_impact(point:Vector2)->void:
	var marker:=SlasherCryptImpactMarker.new();get_parent().add_child(marker);marker.setup(self,target,point,maxi(1,damage/2))

func _lane_sweep()->void:
	var axis:=global_position.direction_to(target.global_position).orthogonal();var forward:=global_position.direction_to(target.global_position)
	for lane:int in [-2,-1,1,2]:
		var origin:=global_position+axis*float(lane)*32.0;_spawn_projectile(origin,forward,{"projectile_speed":215.0,"projectile_range":620.0,"hit_radius":12.0,"color":"#b27aff","visual_type":"soul"})

func _spawn_projectile(origin:Vector2,direction:Vector2,config:Dictionary)->void:
	if get_tree().get_nodes_in_group("crypt_projectile").size()>=projectile_cap:return
	var projectile:=HOSTILE_PROJECTILE.new().setup(self,target,origin,direction,maxi(1,int(round(damage*0.48))),config);get_parent().add_child(projectile);projectile.add_to_group("crypt_projectile")

func receive_hit(amount:int,knockback:Vector2=Vector2.ZERO,attacker:SlasherPlayer=null,stun_duration:float=-1.0,shake_multiplier:float=1.0)->int:
	if transition_time>0.0:return 0
	return super.receive_hit(amount,knockback,attacker,stun_duration,shake_multiplier)

func _draw()->void:
	super._draw()
	if ai_state=="ranged_windup":draw_line(Vector2.ZERO,to_local(captured_target),Color("#be8cffaa"),2.0);draw_circle(to_local(captured_target),12.0,Color("#be8cff44"))
	if ai_state=="boss_windup":
		var pulse:=1.0-clampf(state_timer/(0.72 if boss_phase==0 else 0.62),0.0,1.0);draw_arc(Vector2.ZERO,55.0+pulse*18.0,0.0,TAU,48,Color("#b989ff"),3.0+pulse*2.0)
		if queued_pattern in [0,1]:draw_line(Vector2.ZERO,to_local(captured_target),Color("#9feaff99"),3.0)
	if transition_time>0.0:draw_arc(Vector2.ZERO,48.0,0.0,TAU,48,Color("#d9baff"),5.0)

class SlasherCryptImpactMarker:
	extends Node2D
	var source:SlasherEnemy;var target:SlasherPlayer;var timer:=0.8;var damage:=2
	func setup(owner:SlasherEnemy,player:SlasherPlayer,point:Vector2,value:int)->void:source=owner;target=player;global_position=point;damage=value;z_index=3
	func _physics_process(delta:float)->void:
		timer-=delta;queue_redraw()
		if timer<=0.0:
			if is_instance_valid(target) and global_position.distance_to(target.global_position)<=58.0:target.receive_damage(damage,global_position.direction_to(target.global_position)*90.0,source)
			for index:int in 8:
				if not is_instance_valid(source):break
				var direction:=Vector2.RIGHT.rotated(TAU*float(index)/8.0);var projectile_visual:="necrotic_skull" if source.behavior_id=="grave_acolyte" else "soul";var projectile:=HOSTILE_PROJECTILE.new().setup(source,target,global_position,direction,maxi(1,damage/2),{"projectile_speed":145.0,"projectile_range":210.0,"hit_radius":9.0,"color":"#aa74ff","visual_type":projectile_visual});get_parent().add_child(projectile);projectile.add_to_group("crypt_projectile")
			queue_free()
	func _draw()->void:
		var progress:=clampf(1.0-timer/0.8,0.0,1.0);draw_circle(Vector2.ZERO,58.0,Color(0.45,0.18,0.72,0.12+progress*0.18));draw_arc(Vector2.ZERO,58.0,0.0,TAU,40,Color("#d39cff"),2.0+progress*3.0)
