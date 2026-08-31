extends CharacterBody2D
class_name SlasherEnemy

signal defeated(enemy:SlasherEnemy,reward:int)
signal reinforcement_requested(archetypes:Array,origin:Vector2)

var target:SlasherPlayer
var max_health:=20
var health:=20
var damage:=3
var speed:=75.0
var attack_range:=34.0
var attack_cooldown:=0.0
var elite:=false
var boss:=false
var dead:=false
var visual_id:="feral_wolf"
var behavior_id:=""
var sprite:AnimatedSprite2D
var role_label:Label
var facing_name:="down"
var animation_lock:=0.0
var movement_slow:=1.0
var status_time:=0.0
var tuning:Dictionary={}
var behavior_tuning:Dictionary={}
var reward:=3
var attack_knockback:=120.0
var visual_tuning:Dictionary={}
var hit_stun_timer:=0.0
var ai_state:="idle"
var state_timer:=0.0
var special_cooldown:=0.0
var awakened:=false
var captured_target:=Vector2.ZERO
var charge_direction:=Vector2.ZERO
var charge_remaining:=0.0
var action_landed:=false
var boss_phase:=0
var root_cooldown:=2.0
var howl_cooldown:=5.0
var speed_boost_multiplier:=1.0
var speed_boost_time:=0.0

func configure(floor_number:int,is_boss:bool=false,enemy_visual_id:String="feral_wolf",is_mini_boss:bool=false,enemy_behavior_id:String="")->void:
	behavior_id=enemy_behavior_id
	if behavior_id.is_empty() and enemy_visual_id.begins_with("wolf_"):behavior_id=enemy_visual_id
	visual_id=behavior_id if not behavior_id.is_empty() else enemy_visual_id
	visual_tuning=GameBalance.get_slasher_enemy_visual_tuning(visual_id)
	behavior_tuning=GameBalance.get_slasher_wolf_archetype(behavior_id) if is_wolf() else (GameBalance.get_slasher_wolfmaster_tuning() if is_boss else {})
	boss=is_boss;tuning=GameBalance.get_slasher_enemy_tuning("forest_boss" if boss else "forest_normal")
	var elite_tuning:=GameBalance.get_slasher_enemy_tuning("forest_elite");elite=is_mini_boss or behavior_id.is_empty() and not boss and floor_number>=int(elite_tuning.get("minimum_floor",3))
	max_health=int(tuning.get("health_base",75 if boss else 14))+floor_number*int(tuning.get("health_per_floor",18 if boss else 5))+(int(elite_tuning.get("health_bonus",10)) if elite else 0)
	health=max_health;damage=int(tuning.get("damage_base",6 if boss else 2))+floor_number*int(tuning.get("damage_per_floor",2 if boss else 1))+(int(elite_tuning.get("damage_bonus",2)) if elite else 0)
	speed=float(tuning.get("speed_base",62.0 if boss else 68.0))+floor_number*float(tuning.get("speed_per_floor",0.0 if boss else 3.0));attack_range=float(tuning.get("attack_range",44.0 if boss else 34.0));attack_knockback=float(tuning.get("attack_knockback",120.0));reward=int(elite_tuning.get("reward",5)) if elite else int(tuning.get("reward",18 if boss else 3))
	if is_wolf():speed*=float(behavior_tuning.get("speed_multiplier",1.0))
	if is_mini_boss:max_health=maxi(1,int(round(max_health*float(elite_tuning.get("mini_boss_health_multiplier",2.5)))));health=max_health;damage=maxi(1,int(round(damage*float(elite_tuning.get("mini_boss_damage_multiplier",1.5)))));reward=int(elite_tuning.get("mini_boss_reward",12))
	queue_redraw()

func _ready()->void:
	add_to_group("slasher_enemy");add_to_group("slasher_damageable")
	if is_wolf():add_to_group("slasher_wolf")
	var shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=float(tuning.get("collision_radius",24.0 if boss else 14.0));shape.shape=circle;add_child(shape)
	sprite=AnimatedSprite2D.new();sprite.name="AnimatedSprite2D";sprite.sprite_frames=SlasherSpriteLibrary.enemy_frames(visual_id);sprite.position=Vector2(float(visual_tuning.get("sprite_offset_x",0.0)),float(visual_tuning.get("sprite_offset_y",-18.0)));sprite.scale=Vector2.ONE*float(visual_tuning.get("sprite_scale",1.05 if boss else 0.7));add_child(sprite)
	if is_wolf():
		sprite.modulate=Color.WHITE
		role_label=Label.new();role_label.text=String(behavior_tuning.get("name",behavior_id.capitalize())).to_upper();role_label.position=Vector2(-48,-53);role_label.size=Vector2(96,18);role_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;role_label.add_theme_font_size_override("font_size",10);role_label.add_theme_color_override("font_color",Color(String(behavior_tuning.get("color","#ffffff"))));role_label.add_theme_color_override("font_outline_color",Color.BLACK);role_label.add_theme_constant_override("outline_size",3);add_child(role_label)
	if behavior_id=="wolf_lurker":sprite.modulate.a=0.38;role_label.modulate.a=0.38
	_play_animation("idle")

func _physics_process(delta:float)->void:
	if dead or not is_instance_valid(target):return
	attack_cooldown=maxf(0.0,attack_cooldown-delta);animation_lock=maxf(0.0,animation_lock-delta);hit_stun_timer=maxf(0.0,hit_stun_timer-delta);status_time=maxf(0.0,status_time-delta);special_cooldown=maxf(0.0,special_cooldown-delta);state_timer=maxf(0.0,state_timer-delta);speed_boost_time=maxf(0.0,speed_boost_time-delta)
	if status_time<=0.0:movement_slow=1.0
	if speed_boost_time<=0.0:speed_boost_multiplier=1.0
	if hit_stun_timer>0.0 or status_time>0.0 and movement_slow<=0.05:velocity=Vector2.ZERO;_play_animation("idle");return
	if boss:_process_boss(delta)
	elif is_wolf():_process_wolf(delta)
	else:_process_default()
	queue_redraw()

func _process_wolf(delta:float)->void:
	match behavior_id:
		"wolf_lurker":_process_lurker(delta)
		"wolf_charger":_process_charger(delta)
		"wolf_howler":_process_howler()
		"wolf_hunter":_process_pursuer(true)
		_:_process_pursuer(false)

func _process_pursuer(is_hunter:bool)->void:
	var distance:=global_position.distance_to(target.global_position);var detection:=INF if is_hunter else float(behavior_tuning.get("detection_radius",560.0))
	if not awakened and distance>detection:velocity=Vector2.ZERO;_play_animation("idle");return
	awakened=true
	if distance>attack_range:_move_toward(target.global_position)
	elif attack_cooldown<=0.0:_bite(float(behavior_tuning.get("damage_multiplier",1.0)),is_hunter);attack_cooldown=float(behavior_tuning.get("bite_cooldown",0.85))
	else:velocity=Vector2.ZERO;_play_animation("idle")

func _process_lurker(delta:float)->void:
	var distance:=global_position.distance_to(target.global_position)
	if not awakened:
		velocity=Vector2.ZERO
		if distance<=float(behavior_tuning.get("ambush_radius",165.0)):_awaken_lurker()
		return
	if ai_state=="windup":
		velocity=Vector2.ZERO
		if state_timer<=0.0:_begin_dash(float(behavior_tuning.get("lunge_distance",175.0)))
		return
	if ai_state=="dash":_process_dash(delta,float(behavior_tuning.get("lunge_speed",470.0)),float(behavior_tuning.get("damage_multiplier",1.15)),float(behavior_tuning.get("recovery",0.75)));return
	if ai_state=="recovery" and state_timer>0.0:velocity=Vector2.ZERO;_play_animation("idle");return
	ai_state="pursue";_process_pursuer(false)

func _awaken_lurker()->void:
	awakened=true;ai_state="windup";state_timer=float(behavior_tuning.get("lunge_windup",0.28));captured_target=target.global_position;charge_direction=global_position.direction_to(captured_target);facing_name=SlasherSpriteLibrary.direction_name(charge_direction,facing_name)
	if sprite:sprite.modulate=Color.WHITE
	if role_label:role_label.modulate.a=1.0

func _process_charger(delta:float)->void:
	var distance:=global_position.distance_to(target.global_position)
	if ai_state=="windup":
		velocity=Vector2.ZERO
		if state_timer<=0.0:_begin_dash(float(behavior_tuning.get("charge_distance",310.0)))
		return
	if ai_state=="dash":_process_dash(delta,float(behavior_tuning.get("charge_speed",560.0)),float(behavior_tuning.get("damage_multiplier",1.4)),float(behavior_tuning.get("recovery",1.05)));return
	if ai_state=="recovery" and state_timer>0.0:velocity=Vector2.ZERO;_play_animation("idle");return
	if special_cooldown<=0.0 and distance<=float(behavior_tuning.get("charge_range",340.0)):
		ai_state="windup";state_timer=float(behavior_tuning.get("charge_windup",0.65));captured_target=target.global_position;charge_direction=global_position.direction_to(captured_target);facing_name=SlasherSpriteLibrary.direction_name(charge_direction,facing_name);return
	if distance<=float(behavior_tuning.get("detection_radius",520.0)):_move_toward(target.global_position)
	else:velocity=Vector2.ZERO;_play_animation("idle")

func _begin_dash(distance:float)->void:ai_state="dash";charge_remaining=distance;action_landed=false;_play_animation("attack",true)

func _process_dash(delta:float,dash_speed:float,damage_multiplier:float,recovery:float)->void:
	var step:=minf(charge_remaining,dash_speed*delta);var collision:=move_and_collide(charge_direction*step);charge_remaining-=step
	if not action_landed and global_position.distance_to(target.global_position)<=attack_range+18.0:_bite(damage_multiplier,false);action_landed=true
	if collision!=null or charge_remaining<=0.0 or action_landed:ai_state="recovery";state_timer=recovery;special_cooldown=recovery+0.8;velocity=Vector2.ZERO

func _process_howler()->void:
	if ai_state=="howl":
		velocity=Vector2.ZERO
		if state_timer<=0.0:_heal_wolves(float(behavior_tuning.get("howl_radius",245.0)),float(behavior_tuning.get("heal_fraction",0.16)),false);ai_state="idle";special_cooldown=float(behavior_tuning.get("howl_cooldown",7.5))
		return
	if special_cooldown<=0.0 and _nearby_wolves(float(behavior_tuning.get("howl_radius",245.0)))>0:ai_state="howl";state_timer=float(behavior_tuning.get("howl_windup",0.8));_play_animation("attack",true);return
	var distance:=global_position.distance_to(target.global_position);var retreat:=float(behavior_tuning.get("retreat_distance",125.0));var preferred:=float(behavior_tuning.get("preferred_distance",210.0))
	if distance<retreat:_move_toward(global_position+(global_position-target.global_position).normalized()*preferred)
	elif distance>preferred*1.25:_move_toward(target.global_position)
	elif distance<=attack_range+8.0 and attack_cooldown<=0.0:_bite(float(behavior_tuning.get("damage_multiplier",0.65)),false);attack_cooldown=float(behavior_tuning.get("bite_cooldown",1.5))
	else:velocity=Vector2.ZERO;_play_animation("idle")

func _process_boss(delta:float)->void:
	var health_fraction:=float(health)/maxf(1.0,float(max_health));var wolfmaster:=behavior_tuning
	if boss_phase<1 and health_fraction<=0.70:boss_phase=1;reinforcement_requested.emit(["wolf_vanguard","wolf_lurker"],global_position)
	if boss_phase<2 and health_fraction<=0.35:boss_phase=2;reinforcement_requested.emit(["wolf_charger","wolf_hunter","wolf_howler"],global_position)
	root_cooldown=maxf(0.0,root_cooldown-delta);howl_cooldown=maxf(0.0,howl_cooldown-delta)
	if ai_state=="root_windup":
		velocity=Vector2.ZERO
		if state_timer<=0.0:
			if target.global_position.distance_to(captured_target)<=float(wolfmaster.get("root_radius",74.0)):target.receive_damage(maxi(1,int(round(damage*float(wolfmaster.get("root_damage_multiplier",0.8))))),Vector2.ZERO,self);target.apply_movement_slow(float(wolfmaster.get("root_slow_multiplier",0.5)),float(wolfmaster.get("root_slow_duration",1.4)))
			ai_state="idle";root_cooldown=float(wolfmaster.get("enraged_root_cooldown",4.25) if boss_phase>=2 else wolfmaster.get("root_cooldown",6.5))
		return
	if ai_state=="boss_howl":
		velocity=Vector2.ZERO
		if state_timer<=0.0:_heal_wolves(float(wolfmaster.get("howl_radius",300.0)),float(wolfmaster.get("heal_fraction",0.12)),true);ai_state="idle";howl_cooldown=float(wolfmaster.get("howl_cooldown",8.5))
		return
	if howl_cooldown<=0.0 and _nearby_wolves(float(wolfmaster.get("howl_radius",300.0)))>0:ai_state="boss_howl";state_timer=0.8;_play_animation("attack",true);return
	if root_cooldown<=0.0:ai_state="root_windup";state_timer=float(wolfmaster.get("root_windup",0.85));captured_target=target.global_position;_play_animation("attack",true);return
	_process_default()

func _process_default()->void:
	var distance:=global_position.distance_to(target.global_position)
	if distance>attack_range:_move_toward(target.global_position)
	elif attack_cooldown<=0.0:_bite(1.0,false);attack_cooldown=float(tuning.get("attack_cooldown",0.75 if boss else 1.15))
	else:
		velocity=Vector2.ZERO
		if animation_lock<=0.0:_play_animation("idle")

func _move_toward(point:Vector2)->void:
	var direction:=global_position.direction_to(point);velocity=direction*speed*movement_slow*speed_boost_multiplier;facing_name=SlasherSpriteLibrary.direction_name(direction,facing_name);move_and_slide()
	if animation_lock<=0.0:_play_animation("run")

func _bite(multiplier:float,slows_player:bool)->void:
	velocity=Vector2.ZERO;target.receive_damage(maxi(1,int(round(damage*multiplier))),global_position.direction_to(target.global_position)*attack_knockback,self)
	if slows_player:target.apply_movement_slow(float(behavior_tuning.get("slow_multiplier",0.58)),float(behavior_tuning.get("slow_duration",1.6)))
	_play_animation("attack",true);animation_lock=float(tuning.get("animation_lock",0.35))

func _nearby_wolves(radius:float)->int:
	var count:=0
	for node_value:Variant in get_tree().get_nodes_in_group("slasher_wolf"):
		var wolf:=node_value as SlasherEnemy
		if is_instance_valid(wolf) and wolf!=self and not wolf.dead and global_position.distance_to(wolf.global_position)<=radius:count+=1
	return count

func _heal_wolves(radius:float,fraction:float,grant_boost:bool)->void:
	for node_value:Variant in get_tree().get_nodes_in_group("slasher_wolf"):
		var wolf:=node_value as SlasherEnemy
		if not is_instance_valid(wolf) or wolf==self or wolf.dead or global_position.distance_to(wolf.global_position)>radius:continue
		wolf.heal(maxi(1,int(round(wolf.max_health*fraction))))
		if grant_boost:wolf.speed_boost_multiplier=float(behavior_tuning.get("speed_boost",1.22));wolf.speed_boost_time=float(behavior_tuning.get("speed_boost_duration",3.0))

func heal(amount:int)->void:
	health=mini(max_health,health+maxi(0,amount));queue_redraw()
	if sprite:
		var resting_color:=Color.WHITE;resting_color.a=0.38 if behavior_id=="wolf_lurker" and not awakened else 1.0
		var tween:=create_tween();tween.tween_property(sprite,"modulate",Color("#b9ffb1"),0.12);tween.tween_property(sprite,"modulate",resting_color,0.22)

func receive_hit(amount:int,knockback:Vector2=Vector2.ZERO,attacker:SlasherPlayer=null,stun_duration:float=-1.0,shake_multiplier:float=1.0)->void:
	if dead:return
	if behavior_id=="wolf_lurker" and not awakened:_awaken_lurker()
	health-=maxi(1,amount);var stun:=float(tuning.get("hit_stun_duration",0.12)) if stun_duration<0.0 else stun_duration;hit_stun_timer=maxf(hit_stun_timer,stun)
	var adjusted_knockback:=knockback*float(tuning.get("received_knockback_multiplier",1.0))
	if not adjusted_knockback.is_zero_approx():move_and_collide(adjusted_knockback)
	if is_instance_valid(attacker):
		var damage_shake_scale:=1.0+minf(float(maxi(1,amount)),20.0)*0.025;attacker.add_impact_shake(float(tuning.get("screen_shake_strength",4.5))*damage_shake_scale*shake_multiplier,float(tuning.get("screen_shake_duration",0.16)))
	queue_redraw()
	if health<=0:dead=true;remove_from_group("slasher_enemy");remove_from_group("slasher_damageable");remove_from_group("slasher_wolf");defeated.emit(self,reward);queue_free()

func receive_attack(attack:Dictionary,attacker:SlasherPlayer=null)->int:
	var amount:=maxi(1,int(attack.get("damage",1)));var push_direction:=attacker.global_position.direction_to(global_position) if is_instance_valid(attacker) else Vector2.ZERO
	receive_hit(amount,push_direction*float(attack.get("knockback",0.0)),attacker,float(attack.get("hit_stun_duration",tuning.get("hit_stun_duration",0.12))),float(attack.get("screen_shake_multiplier",1.0)))
	match String(attack.get("status","")):
		"slow":movement_slow=float(attack.get("status_strength",tuning.get("slow_multiplier",0.55)));status_time=float(attack.get("status_duration",tuning.get("slow_duration",1.5)))
		"stagger":movement_slow=float(attack.get("status_strength",tuning.get("stagger_multiplier",0.0)));status_time=float(attack.get("status_duration",tuning.get("stagger_duration",0.45)))
	if sprite:
		var tween:=create_tween();tween.tween_property(sprite,"modulate",Color.WHITE*2.0,0.05);tween.tween_property(sprite,"modulate",Color.WHITE,0.12)
	return amount

func is_wolf()->bool:return behavior_id.begins_with("wolf_")

func _draw()->void:
	var accent:=Color(String(behavior_tuning.get("color","#9b3f52"))) if is_wolf() else (Color("#9b3f52") if boss else (Color("#d88445") if elite else Color("#6f8d48")))
	if sprite==null or sprite.sprite_frames==null:draw_circle(Vector2.ZERO,24.0 if boss else 14.0,accent)
	var width:=52.0 if boss else 32.0;draw_rect(Rect2(-width/2.0,-32.0,width,5),Color("#241719"));draw_rect(Rect2(-width/2.0,-32.0,width*maxf(0.0,float(health)/max_health),5),accent)
	if ai_state in ["windup","dash"]:draw_line(Vector2.ZERO,charge_direction*minf(charge_remaining if charge_remaining>0.0 else 150.0,310.0),accent,4.0)
	if ai_state in ["howl","boss_howl"]:draw_arc(Vector2.ZERO,float(behavior_tuning.get("howl_radius",245.0)),0.0,TAU,48,accent,3.0)
	if ai_state=="root_windup":draw_circle(to_local(captured_target),float(behavior_tuning.get("root_radius",74.0)),Color(0.35,0.08,0.45,0.28));draw_arc(to_local(captured_target),float(behavior_tuning.get("root_radius",74.0)),0.0,TAU,40,Color("#c56ee8"),3.0)

func _play_animation(state:String,restart:bool=false)->void:
	if sprite==null or sprite.sprite_frames==null:return
	var animation:=SlasherSpriteLibrary.resolved_animation(sprite.sprite_frames,state,facing_name)
	if animation.is_empty():return
	if restart:sprite.stop();sprite.play(animation)
	elif sprite.animation!=animation:sprite.play(animation)
