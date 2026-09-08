extends SlasherEnemy
class_name SlasherHellEnemy

signal hell_effect_requested(kind:String,origin:Vector2,payload:Dictionary)

const BEHAVIORS:=["infernal_caster","rift_stalker","hellcharger","cinder_bomber","fire_spirit","infernal_legate","balor"]
const TELEPORT_INDICATOR:=preload("res://scripts/slasher/slasher_teleport_indicator.gd")

var pattern_index:=0
var pattern_cooldown:=1.0
var projectile_cap:=96
var teleport_target:=Vector2.ZERO
var trail_cooldown:=0.0
var fuse:=2.2
var queued_pattern:=-1

func configure(floor_number:int,is_boss:bool=false,enemy_visual_id:String="infernal_caster",is_mini_boss:bool=false,enemy_behavior_id:String="infernal_caster")->void:
	super.configure(floor_number,is_boss,enemy_visual_id,is_mini_boss,enemy_behavior_id)
	behavior_id=enemy_behavior_id if not enemy_behavior_id.is_empty() else ("balor" if is_boss else enemy_visual_id);visual_id=enemy_visual_id;behavior_tuning=GameBalance.get_slasher_enemy_tuning(behavior_id);visual_tuning=GameBalance.get_slasher_enemy_visual_tuning(visual_id)
	max_health=int(behavior_tuning.get("health_base",240 if is_boss else 20))+floor_number*int(behavior_tuning.get("health_per_floor",5));health=max_health;damage=int(behavior_tuning.get("damage_base",5))+floor_number*int(behavior_tuning.get("damage_per_floor",1));speed=float(behavior_tuning.get("speed",80.0));reward=int(behavior_tuning.get("reward",8));projectile_cap=int(behavior_tuning.get("projectile_cap",96));boss=is_boss;mini_boss=is_mini_boss;elite=is_mini_boss

func _physics_process(delta:float)->void:
	if behavior_id not in BEHAVIORS:super._physics_process(delta);return
	retarget_timer-=delta;if retarget_timer<=0.0:_retarget_party();retarget_timer=0.35
	if dead or not is_instance_valid(target):return
	activation_delay=maxf(0.0,activation_delay-delta);attack_cooldown=maxf(0.0,attack_cooldown-delta);special_cooldown=maxf(0.0,special_cooldown-delta);state_timer=maxf(0.0,state_timer-delta);pattern_cooldown=maxf(0.0,pattern_cooldown-delta);trail_cooldown=maxf(0.0,trail_cooldown-delta)
	if activation_delay>0.0:velocity=Vector2.ZERO;return
	match behavior_id:
		"infernal_caster":_process_caster()
		"rift_stalker":_process_stalker()
		"hellcharger":_process_charger(delta)
		"cinder_bomber":_process_bomber()
		"fire_spirit":_process_spirit(delta)
		"infernal_legate":_process_elite()
		"balor":_process_balor()
	queue_redraw()

func _process_caster()->void:
	var distance:=global_position.distance_to(target.global_position)
	if ai_state=="windup":
		velocity=Vector2.ZERO
		if state_timer<=0.0:_fire_fan(5,0.18,250.0);ai_state="idle";attack_cooldown=1.45
	elif distance<150.0:_move_toward(global_position+(global_position-target.global_position).normalized()*220.0)
	elif distance>290.0:_move_toward(target.global_position)
	elif attack_cooldown<=0.0:_windup(0.58)
	else:velocity=Vector2.ZERO

func _process_stalker()->void:
	if ai_state=="teleport_windup":
		velocity=Vector2.ZERO
		if state_timer<=0.0:global_position=teleport_target;visible=true;_radial(8,pattern_index*0.31,190.0);pattern_index+=1;ai_state="teleport_recovery";state_timer=float(behavior_tuning.get("teleport_recovery",1.5));_play_animation("attack",true)
		return
	if ai_state=="teleport_recovery":
		velocity=Vector2.ZERO;visible=true
		if state_timer<=0.0:ai_state="idle";_play_animation("idle")
		return
	if special_cooldown<=0.0:
		var warning_time:=float(behavior_tuning.get("teleport_windup",1.0));var recovery_time:=float(behavior_tuning.get("teleport_recovery",1.5));teleport_target=_safe_point(target.global_position+Vector2.RIGHT.rotated(pattern_index*2.1)*125.0);visible=true;ai_state="teleport_windup";state_timer=warning_time;special_cooldown=warning_time+recovery_time+2.8;_spawn_teleport_indicator(warning_time);_play_animation("attack",true);return
	if attack_cooldown<=0.0:_fire_fan(3,0.22,225.0);attack_cooldown=1.35
	else:_move_toward(target.global_position-global_position.direction_to(target.global_position)*175.0)

func _process_charger(delta:float)->void:
	if ai_state=="charge":
		var step:=charge_direction*460.0*delta;global_position=_safe_point(global_position+step)
		if trail_cooldown<=0.0:hell_effect_requested.emit("flame_trail",global_position,{"radius":30.0,"lifetime":3.2,"telegraph":0.12,"damage":maxi(1,damage/2),"repeating":false});trail_cooldown=0.12
		charge_remaining-=step.length()
		if global_position.distance_to(target.global_position)<30.0 and not action_landed:target.receive_damage(damage,charge_direction*190.0,self);action_landed=true
		if charge_remaining<=0.0:ai_state="idle";state_timer=0.7;special_cooldown=2.5
		return
	if ai_state=="windup":
		velocity=Vector2.ZERO
		if state_timer<=0.0:ai_state="charge";charge_remaining=310.0;action_landed=false
		return
	if special_cooldown<=0.0:charge_direction=global_position.direction_to(target.global_position);_windup(0.68)
	else:_move_toward(target.global_position)

func _process_bomber()->void:
	if ai_state=="windup":
		velocity=Vector2.ZERO
		if state_timer<=0.0:hell_effect_requested.emit("eruption",captured_target,{"radius":62.0,"lifetime":0.9,"telegraph":0.85,"damage":damage,"repeating":false});_radial(6,pattern_index*0.25,150.0);pattern_index+=1;ai_state="idle";attack_cooldown=2.25
		return
	if attack_cooldown<=0.0:captured_target=target.global_position+target.velocity*0.42;_windup(0.78)
	else:_move_toward(target.global_position-global_position.direction_to(target.global_position)*235.0)

func _process_spirit(delta:float)->void:
	fuse-=delta;_move_toward(target.global_position)
	if fuse<=0.0 or global_position.distance_to(target.global_position)<=28.0:
		hell_effect_requested.emit("spirit_explosion",global_position,{"radius":56.0,"lifetime":0.35,"telegraph":0.12,"damage":damage,"repeating":false});defeated.emit(self,0);dead=true;queue_free()

func _process_elite()->void:
	if special_cooldown<=0.0:hell_effect_requested.emit("summon_spirits",global_position,{"count":3});special_cooldown=4.0
	if attack_cooldown<=0.0:_radial(12,pattern_index*0.2,175.0);pattern_index+=1;attack_cooldown=1.4
	else:_move_toward(target.global_position-global_position.direction_to(target.global_position)*190.0)

func _process_balor()->void:
	if ai_state=="boss_windup":
		velocity=Vector2.ZERO
		if state_timer<=0.0:ai_state="idle";_release_balor_wave()
		return
	if pattern_cooldown<=0.0:queued_pattern=pattern_index%3;ai_state="boss_windup";state_timer=0.9;captured_target=target.global_position

func _release_balor_wave()->void:
	match queued_pattern:
		0:
			for ring:int in 3:_radial(14,pattern_index*0.21+ring*0.11,170.0+ring*28.0,(-0.3 if ring%2==0 else 0.3))
		1:hell_effect_requested.emit("summon_minions",global_position,{"count":5})
		2:
			for index:int in 5:
				var point:=target.global_position+Vector2.RIGHT.rotated(TAU*float(index)/5.0+pattern_index)*float(55+index*18);hell_effect_requested.emit("balor_ground",point,{"radius":72.0,"lifetime":3.6,"telegraph":1.0,"damage":maxi(1,damage/2),"repeating":false})
	pattern_index+=1;pattern_cooldown=2.15

func _windup(duration:float)->void:ai_state="windup";state_timer=duration;captured_target=target.global_position;_play_animation("attack",true)

func _fire_fan(count:int,spread:float,shot_speed:float)->void:
	var center:=global_position.direction_to(target.global_position+target.velocity*0.25)
	for index:int in count:_spawn_projectile(center.rotated((float(index)-float(count-1)/2.0)*spread),shot_speed,0.0)

func _radial(count:int,rotation:float,shot_speed:float,curve:float=0.0)->void:
	for index:int in count:_spawn_projectile(Vector2.RIGHT.rotated(rotation+TAU*float(index)/float(count)),shot_speed,curve)

func _spawn_projectile(direction:Vector2,shot_speed:float,curve:float)->void:
	if get_tree().get_nodes_in_group("hell_projectile").size()>=projectile_cap:return
	var projectile_visual:="flaming_disk" if behavior_id=="balor" else ("rift_shard" if behavior_id=="rift_stalker" else "hellfire_orb")
	var projectile:=HOSTILE_PROJECTILE.new().setup(self,target,global_position+direction*25.0,direction,maxi(1,int(round(damage*0.42))),{"projectile_speed":shot_speed,"projectile_range":620.0,"hit_radius":10.0,"color":"#ff5b18","visual_type":projectile_visual,"movement_pattern":"curve" if not is_zero_approx(curve) else "straight","angular_velocity":curve});get_parent().add_child(projectile);projectile.add_to_group("hell_projectile")

func _spawn_teleport_indicator(warning_time:float)->void:
	var indicator:SlasherTeleportIndicator=TELEPORT_INDICATOR.new().setup(teleport_target,warning_time);get_parent().add_child(indicator);indicator.global_position=teleport_target

func _safe_point(point:Vector2)->Vector2:
	if pathfinder==null:return point
	return pathfinder.cell_to_world(pathfinder.nearest_walkable_cell(pathfinder.world_to_cell(point)))

func _draw()->void:
	super._draw()
	if behavior_id=="rift_stalker" and ai_state=="teleport_recovery":
		var recovery_duration:=float(behavior_tuning.get("teleport_recovery",1.5));var recovery_progress:=clampf(1.0-state_timer/maxf(0.1,recovery_duration),0.0,1.0);var pulse:=0.5+0.5*sin(recovery_progress*TAU*3.0)
		draw_circle(Vector2.ZERO,27.0,Color(0.52,0.12,0.78,0.12+0.08*pulse));draw_arc(Vector2.ZERO,27.0,-recovery_progress*TAU,TAU-recovery_progress*TAU,28,Color(0.94,0.42,1.0,0.72+0.2*pulse),3.0);draw_arc(Vector2.ZERO,21.0,recovery_progress*TAU,TAU+recovery_progress*TAU,24,Color("#ffd26a"),2.0)
	if sprite!=null and sprite.sprite_frames!=null:
		if ai_state in ["windup","boss_windup"]:draw_arc(Vector2.ZERO,48,0,TAU,32,Color("#ffd45d"),4)
		return
	var color:=Color("#ff7a20")
	match behavior_id:
		"infernal_caster":draw_arc(Vector2.ZERO,18,0,TAU,18,color,4);draw_line(Vector2(-12,-13),Vector2(0,-28),color,4);draw_line(Vector2(12,-13),Vector2(0,-28),color,4)
		"rift_stalker":draw_colored_polygon(PackedVector2Array([Vector2(0,-22),Vector2(17,15),Vector2(-17,15)]),Color("#7c2145"));draw_circle(Vector2(0,-4),5,color)
		"hellcharger":draw_rect(Rect2(-20,-13,40,26),Color("#77271b"));draw_line(Vector2(-14,-12),Vector2(-24,-24),color,5);draw_line(Vector2(14,-12),Vector2(24,-24),color,5)
		"cinder_bomber":draw_circle(Vector2.ZERO,18,Color("#531a20"));draw_circle(Vector2.ZERO,9,color)
		"fire_spirit":draw_colored_polygon(PackedVector2Array([Vector2(0,-18),Vector2(12,14),Vector2(0,8),Vector2(-12,14)]),color);draw_circle(Vector2.ZERO,5,Color("#fff09a"))
		"infernal_legate":draw_arc(Vector2.ZERO,30,0,TAU,24,Color("#ffc14d"),6);draw_line(Vector2(-22,-24),Vector2(0,-43),color,7);draw_line(Vector2(22,-24),Vector2(0,-43),color,7)
		"balor":draw_circle(Vector2.ZERO,38,Color("#50151b"));draw_arc(Vector2.ZERO,43,0,TAU,30,color,7);draw_line(Vector2(-28,-28),Vector2(-48,-52),color,9);draw_line(Vector2(28,-28),Vector2(48,-52),color,9);draw_circle(Vector2.ZERO,12,Color("#ffe467"))
	if ai_state in ["windup","boss_windup"]:draw_arc(Vector2.ZERO,48,0,TAU,32,Color("#ffd45d"),4)
