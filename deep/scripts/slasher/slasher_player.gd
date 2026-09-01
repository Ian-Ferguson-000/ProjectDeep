extends CharacterBody2D
class_name SlasherPlayer

signal health_changed(current:int,maximum:int)
signal resource_changed(current:int,maximum:int)
signal ability_resolved(result:Dictionary)
signal defeated

const PROJECTILE:=preload("res://scripts/slasher/slasher_projectile.gd")
const ITEM_RUNTIME:=preload("res://scripts/slasher/slasher_item_runtime.gd")
var run_state:RunState
var pathfinder:SlasherGridPathfinder
var class_id:="warrior"
var max_health:=20
var health:=20
var speed:=185.0
var attack_power:=4
var spell_power:=4
var cooldowns:={"basic":0.0,"special":0.0,"defensive":0.0,"movement":0.0}
var invulnerable:=0.0
var defense_window:=0.0
var defense_kind:=""
var empowered:=false
var is_hidden:=false
var hidden_time:=0.0
var marked_enemy:SlasherEnemy
var companion:CharacterBody2D
var last_direction:=Vector2.RIGHT
var aim_direction:=Vector2.RIGHT
var facing_name:="right"
var sprite:AnimatedSprite2D
var animation_lock:=0.0
var presentation_ready:=false
var retribution_stored:=0
var input_locked:=false
var position_sanitizer:Callable
var camera:Camera2D
var screen_shake_time:=0.0
var screen_shake_duration:=0.0
var screen_shake_strength:=0.0
var basic_mouse_held:=false
var item_runtime:SlasherItemRuntime
var active_action_slot:="basic"
var consumable_aegis:=0
var consumable_speed_time:=0.0
var consumable_speed_multiplier:=1.0
var movement_debuff_multiplier:=1.0
var movement_debuff_time:=0.0
var next_attack_multiplier:=1.0

func setup(state:RunState)->void:
	run_state=state;class_id=state.selected_class_id
	var tuning:Dictionary=GameBalance.get_slasher_class_tuning(class_id)
	speed=float(tuning.get("speed",speed));max_health=state.max_health;health=state.current_health
	attack_power=maxi(2,state.get_derived_stat("attack_power")+(state.selected_gear.damage if state.selected_gear else 1))
	spell_power=maxi(2,state.get_derived_stat("spell_potency")+(state.selected_gear.damage if state.selected_gear else 1))
	if is_inside_tree():_refresh_presentation()

func _ready()->void:
	add_to_group("slasher_player")
	item_runtime=ITEM_RUNTIME.new();item_runtime.name="SlasherItemRuntime";add_child(item_runtime);item_runtime.setup(run_state,self)
	var shape:=CollisionShape2D.new();shape.name="PlayerHitbox";var circle:=CircleShape2D.new();circle.radius=float(GameBalance.get_slasher_class_tuning(class_id).get("collision_radius",18.0));shape.shape=circle;add_child(shape);_refresh_presentation()

func _refresh_presentation()->void:
	if sprite==null:sprite=AnimatedSprite2D.new();sprite.name="AnimatedSprite2D";add_child(sprite)
	var tuning:Dictionary=GameBalance.get_slasher_class_tuning(class_id)
	sprite.sprite_frames=SlasherSpriteLibrary.player_frames(class_id);sprite.position=Vector2(float(tuning.get("sprite_offset_x",0.0)),float(tuning.get("sprite_offset_y",-30.0)));sprite.scale=Vector2.ONE*float(tuning.get("sprite_scale",0.9));presentation_ready=true;_play_animation("idle");queue_redraw()

func _physics_process(delta:float)->void:
	for key in cooldowns:cooldowns[key]=maxf(0.0,float(cooldowns[key])-delta)
	var was_invulnerable:=invulnerable>0.0
	invulnerable=maxf(0.0,invulnerable-delta);defense_window=maxf(0.0,defense_window-delta);animation_lock=maxf(0.0,animation_lock-delta);hidden_time=maxf(0.0,hidden_time-delta)
	if was_invulnerable or invulnerable>0.0:queue_redraw()
	consumable_speed_time=maxf(0.0,consumable_speed_time-delta)
	if consumable_speed_time<=0.0:consumable_speed_multiplier=1.0
	movement_debuff_time=maxf(0.0,movement_debuff_time-delta)
	if movement_debuff_time<=0.0:movement_debuff_multiplier=1.0
	if movement_debuff_time>0.0:queue_redraw()
	if hidden_time<=0.0:is_hidden=false
	_update_screen_shake(delta)
	if defense_window<=0.0 and defense_kind!="retribution_ready":defense_kind=""
	_update_aim()
	if input_locked:basic_mouse_held=false;velocity=Vector2.ZERO;return
	var direction:=Input.get_vector("slasher_left","slasher_right","slasher_up","slasher_down")
	if direction.length()>0.1:last_direction=direction.normalized()
	velocity=direction*speed*consumable_speed_multiplier*movement_debuff_multiplier*(item_runtime.conversion("speed_multiplier",1.0) if item_runtime else 1.0);move_and_slide()
	_enforce_field_bounds()
	if animation_lock<=0.0:_play_animation("run" if direction.length()>0.1 else "idle")
	if Input.is_action_just_pressed("slasher_controller_basic"):use_action("basic")
	if Input.is_action_just_pressed("slasher_mobility"):use_action("movement")
	if Input.is_action_just_pressed("slasher_special"):use_action("special")
	if Input.is_action_just_pressed("slasher_defend"):use_action("defensive")
	if basic_mouse_held and not Input.is_key_pressed(KEY_SHIFT) and float(cooldowns.get("basic",0.0))<=0.0:
		var held_result:Dictionary=use_action("basic")
		if bool(held_result.get("started",false)):cooldowns.basic=float(_ability_tuning("basic").get("cooldown",0.4))*float(GameBalance.get_slasher_balance("input").get("held_basic_cooldown_multiplier",1.5))

func _unhandled_input(event:InputEvent)->void:
	if input_locked:return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				basic_mouse_held=not event.shift_pressed;use_action("defensive" if event.shift_pressed else "basic")
			else:basic_mouse_held=false
			get_viewport().set_input_as_handled()
		elif event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:use_action("movement");get_viewport().set_input_as_handled()

func _notification(what:int)->void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:basic_mouse_held=false

func use_action(slot:String)->Dictionary:
	var result:={"started":false,"slot":slot,"class_id":class_id,"targets_hit":0,"resource_gained":0,"resource_spent":0,"damage_prevented":0,"failure":""}
	if float(cooldowns.get(slot,0.0))>0.0:result.failure="%s is cooling down."%_action_name(slot);ability_resolved.emit(result);return result
	var tuning:Dictionary=_ability_tuning(slot)
	var resource_cost:=int(tuning.get("resource_cost",2 if slot=="special" else 0))
	if resource_cost>0 and not run_state.spend_class_resource(resource_cost):result.failure="Not enough %s."%run_state.get_class_resource_name();ability_resolved.emit(result);return result
	result.started=true
	active_action_slot=slot
	match slot:
		"basic":result=_basic(result)
		"movement":result=_movement(result)
		"special":result=_special(result)
		"defensive":result=_defensive(result)
	if int(result.get("targets_hit",0))>0 and int(tuning.get("resource_refund_on_hit",0))>0:_gain_resource(result,int(tuning.resource_refund_on_hit))
	result.resource_spent=resource_cost
	cooldowns[slot]=float(tuning.get("cooldown",0.4 if slot=="basic" else 3.0))*(item_runtime.cooldown_multiplier() if item_runtime else 1.0)
	resource_changed.emit(run_state.class_resource,run_state.get_class_resource_max());_play_action_animation("attack" if class_id=="warrior" else slot,float(cooldowns[slot]));animation_lock=minf(float(tuning.get("animation_lock",0.32)),float(cooldowns[slot]));ability_resolved.emit(result);return result

func _basic(result:Dictionary)->Dictionary:
	var tuning:=_ability_tuning("basic")
	match class_id:
		"mage","healer":_spawn_projectile(_configured_attack(tuning,"arcane" if class_id=="mage" else "radiant"),true)
		"summoner":
			marked_enemy=_enemy_near_aim(float(tuning.get("target_range",360.0)),float(tuning.get("aim_dot_threshold",0.8)));_ensure_companion()
			if is_instance_valid(marked_enemy):companion.set_meta("marked",marked_enemy);result.targets_hit=1;_gain_resource(result,int(tuning.get("resource_gain",1)))
			else:companion.set_meta("command_position",global_position+aim_direction*float(tuning.get("command_distance",180.0)))
		_:
			result.targets_hit=_melee_attack(_configured_attack(tuning,"physical"))
			if result.targets_hit>0:_gain_resource(result,int(tuning.get("resource_gain",1)))
	return result

func _special(result:Dictionary)->Dictionary:
	var tuning:=_ability_tuning("special")
	match class_id:
		"warrior":result.targets_hit=_melee_attack(_configured_attack(tuning,"physical"))
		"mage":_spawn_projectile(_configured_attack(tuning,"arcane"),false)
		"healer":empowered=true
		"tank":defense_kind="retribution_ready";defense_window=float(tuning.get("effect_duration",2.0));retribution_stored=0
		"phantom":
			var target:=_enemy_near_aim(float(tuning.get("target_range",100.0)),float(tuning.get("aim_dot_threshold",0.65)))
			if target:
				var isolated:=_nearby_enemy_count(target.global_position,float(tuning.get("isolation_radius",95.0)))<=1
				var low_health:=float(target.health)/maxf(1.0,float(target.max_health))<float(tuning.get("low_health_fraction",0.5))
				var coefficient:=float(tuning.get("bonus_damage_coefficient",3.0)) if is_hidden or isolated or low_health else float(tuning.get("damage_coefficient",2.0))
				var attack:=_configured_attack(tuning,"physical");attack.damage=_scaled_damage(tuning,coefficient);target.receive_attack(attack,self);result.targets_hit=1;is_hidden=false
		"summoner":
			_ensure_companion()
			if is_instance_valid(marked_enemy):companion.set_meta("marked",marked_enemy);companion.set_meta("pounce",true);result.targets_hit=1
	return result

func _movement(result:Dictionary)->Dictionary:
	var tuning:=_ability_tuning("movement");var distance:=float(tuning.get("movement_distance",150.0));var start:=global_position
	global_position=_safe_destination(global_position+aim_direction*distance,float(tuning.get("destination_clearance",22.0)))
	# Mobility protection begins after destination resolution, making Blink and every other movement
	# ability safe on landing without extending the window by its travel calculation.
	var landing_invulnerability:=maxf(0.05,float(tuning.get("invulnerability",0.05)))
	invulnerable=maxf(invulnerable,landing_invulnerability)
	result["invulnerability_granted"]=landing_invulnerability
	queue_redraw()
	match class_id:
		"warrior":result.targets_hit=_line_attack(start,global_position,float(tuning.get("path_radius",34.0)),_configured_attack(tuning,"physical"))
		"healer":
			if global_position.distance_to(start)>=float(tuning.get("heal_travel_threshold",80.0)):heal(_scaled_heal(tuning))
		"tank":result.targets_hit=_area_attack(global_position,float(tuning.get("area_radius",72.0)),_configured_attack(tuning,"physical"))
		"phantom":is_hidden=true;hidden_time=float(tuning.get("hidden_duration",0.5))
		"summoner":_ensure_companion();companion.global_position=global_position-aim_direction*float(tuning.get("mount_offset",24.0))
	if result.targets_hit>0 and int(tuning.get("resource_gain",0))>0:_gain_resource(result,int(tuning.get("resource_gain",0)))
	return result

func _defensive(result:Dictionary)->Dictionary:
	var tuning:=_ability_tuning("defensive");defense_window=float(tuning.get("effect_duration",1.0))
	match class_id:
		"warrior":defense_kind="parry"
		"mage":defense_kind="repel";_push_nearby(float(tuning.get("push_radius",100.0)),float(tuning.get("push_distance",70.0)))
		"healer":defense_kind="recover"
		"tank":defense_kind="guard"
		"phantom":defense_kind="evade";invulnerable=float(tuning.get("invulnerability",defense_window));global_position=_safe_destination(global_position-aim_direction*float(tuning.get("movement_distance",70.0)),float(tuning.get("destination_clearance",22.0)))
		"summoner":_ensure_companion();defense_kind="cover"
	return result

func receive_damage(amount:int,knockback:Vector2,attacker:SlasherEnemy=null)->void:
	var tuning:=_ability_tuning("special" if defense_kind=="retribution_ready" else "defensive")
	if invulnerable>0.0:
		if defense_kind=="evade":run_state.gain_class_resource(int(tuning.get("resource_gain",1)));resource_changed.emit(run_state.class_resource,run_state.get_class_resource_max())
		return
	var prevented:=0
	if defense_window>0.0:
		match defense_kind:
			"parry":
				prevented=int(round(amount*float(tuning.get("mitigation",1.0))))
				if is_instance_valid(attacker):attacker.receive_attack(_attack_data(_scaled_damage(tuning,float(tuning.get("counter_coefficient",1.0)),"counter_flat_damage"),"physical",{"knockback":float(tuning.get("counter_knockback",35.0))}),self)
			"repel":
				prevented=int(round(amount*float(tuning.get("mitigation",0.5))))
				if is_instance_valid(attacker):attacker.position+=global_position.direction_to(attacker.global_position)*float(tuning.get("push_distance",70.0))
			"guard":
				prevented=int(round(amount*float(tuning.get("mitigation",0.75))))
				if prevented>0:run_state.gain_class_resource(int(tuning.get("resource_gain",1)))
			"cover":
				var wolf:=GameBalance.get_slasher_companion_tuning("wolf");var nearby:=is_instance_valid(companion) and companion.global_position.distance_to(global_position)<float(wolf.get("interception_radius",90.0))
				prevented=int(round(amount*float(wolf.get("cover_mitigation_near" if nearby else "cover_mitigation_far",0.6 if nearby else 0.3))))
			"retribution_ready":prevented=int(round(amount*float(tuning.get("mitigation",0.5))));retribution_stored+=int(round(amount*float(tuning.get("storage_fraction",0.5))))
		defense_window=0.0
	if consumable_aegis>0:
		var aegis_prevented:int=mini(consumable_aegis,maxi(0,amount-prevented));consumable_aegis-=aegis_prevented;prevented+=aegis_prevented
	var final:=maxi(0,amount-prevented)
	if item_runtime:
		var mitigation:Dictionary=item_runtime.mitigate_damage(final);prevented+=int(mitigation.prevented);final=int(mitigation.damage)
		if item_runtime.try_prevent_lethal(final,health):final=maxi(0,health-1)
	health=maxi(0,health-final);run_state.current_health=health
	move_and_collide(knockback*(0.25 if prevented>0 else 1.0));_enforce_field_bounds()
	if defense_kind=="recover" and final>0:heal(int(ceil(final*float(tuning.get("recover_fraction",0.5)))))
	if defense_kind=="retribution_ready" and retribution_stored>0:_area_attack(global_position,float(tuning.get("release_radius",80.0)),_attack_data(retribution_stored,"physical",{"knockback":float(tuning.get("release_knockback",30.0))}));retribution_stored=0
	defense_kind="";health_changed.emit(health,max_health);queue_redraw()
	if health<=0:defeated.emit()

func _spawn_projectile(data:Dictionary,gain_on_hit:bool)->void:
	if empowered:
		var empower:=_ability_tuning("special");data.damage=int(round(int(data.damage)*float(empower.get("empower_damage_multiplier",2.0))));data.status_duration=float(data.get("status_duration",0.0))+float(empower.get("empower_status_duration_bonus",1.0));empowered=false
	var projectile:SlasherProjectile=PROJECTILE.new().setup(self,global_position+aim_direction*24.0,aim_direction,data);get_parent().add_child(projectile)
	projectile.hit_landed.connect(func(hit_target:Node2D,_distance:float):
		if item_runtime and hit_target.is_in_group("slasher_enemy"):item_runtime.handle_event({"trigger":"hit","target":hit_target,"attack":data}))
	var echo_multiplier:float=float(data.get("echo_damage_multiplier",0.0))
	if echo_multiplier>0.0:
		var echo_data:Dictionary=data.duplicate(true);echo_data.damage=maxi(1,int(round(int(data.damage)*echo_multiplier)));echo_data["screen_shake_multiplier"]=float(data.get("screen_shake_multiplier",1.0))*0.6
		var echo:SlasherProjectile=PROJECTILE.new().setup(self,global_position+aim_direction.rotated(0.08)*24.0,aim_direction.rotated(0.08),echo_data);get_parent().add_child(echo)
	if gain_on_hit:projectile.hit_landed.connect(func(hit_target:Node2D,distance:float):
		if not hit_target.is_in_group("slasher_enemy"):return
		var tuning:=_ability_tuning("basic");var minimum:=float(tuning.get("focus_min_distance",0.0))
		if class_id!="mage" or distance>=minimum:run_state.gain_class_resource(int(tuning.get("resource_gain",1))+int(tuning.get("resource_refund_on_hit",0)));resource_changed.emit(run_state.class_resource,run_state.get_class_resource_max()))

func _melee_attack(data:Dictionary)->int:
	var hits:=0;var reach:=float(data.get("reach",64.0));var threshold:=cos(deg_to_rad(float(data.get("arc_degrees",70.0))*0.5))
	for node in get_tree().get_nodes_in_group("slasher_damageable"):
		if node is Node2D and node.has_method("receive_attack"):
			var offset:Vector2=node.global_position-global_position
			if offset.length()<=reach and aim_direction.dot(offset.normalized())>=threshold:
				node.call("receive_attack",data,self)
				_apply_echo_hit(node,data)
				if node.is_in_group("slasher_enemy"):hits+=1
	return hits

func _line_attack(start:Vector2,end:Vector2,radius:float,data:Dictionary)->int:
	var hits:int=0;var segment:Vector2=end-start;var segment_length_squared:float=segment.length_squared()
	for node_value:Variant in get_tree().get_nodes_in_group("slasher_damageable"):
		var damageable:Node2D=node_value as Node2D
		if not is_instance_valid(damageable) or not damageable.has_method("receive_attack"):continue
		var progress:float=0.0 if segment_length_squared<=0.001 else clampf((damageable.global_position-start).dot(segment)/segment_length_squared,0.0,1.0)
		var closest:Vector2=start+segment*progress
		if closest.distance_to(damageable.global_position)<=radius:
			damageable.call("receive_attack",data,self)
			_apply_echo_hit(damageable,data)
			if damageable.is_in_group("slasher_enemy"):hits+=1
	return hits

func _area_attack(center:Vector2,radius:float,data:Dictionary)->int:
	var hits:=0
	for node in get_tree().get_nodes_in_group("slasher_damageable"):
		if node is Node2D and node.has_method("receive_attack") and center.distance_to(node.global_position)<=radius:
			node.call("receive_attack",data,self)
			_apply_echo_hit(node,data)
			if node.is_in_group("slasher_enemy"):hits+=1
	return hits

func _attack_data(damage:int,damage_type:String,extra:Dictionary={})->Dictionary:
	var data:={"damage":damage,"damage_type":damage_type,"knockback":0.0,"status":"","status_duration":0.0}
	for key in extra:data[key]=extra[key]
	return data

func _scaled_damage(tuning:Dictionary,coefficient_override:float=NAN,flat_key:String="flat_damage")->int:
	var stat_name:=String(tuning.get("power_stat","attack_power"))
	var stat_value:=spell_power if stat_name=="spell_power" else attack_power
	var coefficient:=float(tuning.get("damage_coefficient",1.0)) if is_nan(coefficient_override) else coefficient_override
	return maxi(1,int(round(stat_value*coefficient))+int(tuning.get(flat_key,0)))

func _scaled_heal(tuning:Dictionary)->int:
	return maxi(0,int(round(spell_power*float(tuning.get("heal_coefficient",0.0))))+int(tuning.get("flat_heal",0)))

func _configured_attack(tuning:Dictionary,damage_type:String)->Dictionary:
	var data:=_attack_data(_scaled_damage(tuning),damage_type)
	if next_attack_multiplier>1.0:data.damage=maxi(1,int(round(float(data.damage)*next_attack_multiplier)));next_attack_multiplier=1.0
	for key in ["reach","arc_degrees","area_radius","hit_radius","piercing","knockback","status","status_duration","status_strength","visual","visual_scale","tint","screen_shake_multiplier","echo_damage_multiplier","progression_flags"]:
		if tuning.has(key):data[key]=tuning[key]
	if tuning.has("projectile_range"):data.range=tuning.projectile_range
	if tuning.has("projectile_speed"):data.speed=tuning.projectile_speed
	return item_runtime.transform_attack(data,active_action_slot) if item_runtime else data

func apply_consumable(effects:Dictionary)->void:
	if int(effects.get("heal",0))>0:heal(int(effects.heal)+run_state.get_derived_stat("potion_heal_bonus"))
	if bool(effects.get("resource_fill",false)):run_state.class_resource=run_state.get_class_resource_max()
	elif int(effects.get("resource",0))>0:run_state.gain_class_resource(int(effects.resource))
	if bool(effects.get("hidden",false)):is_hidden=true;hidden_time=maxf(hidden_time,5.0)
	if int(effects.get("temporary_aegis",0))>0:consumable_aegis+=int(effects.temporary_aegis)
	if float(effects.get("movement_multiplier",1.0))>1.0 or int(effects.get("movement",0))>0:consumable_speed_multiplier=maxf(float(effects.get("movement_multiplier",1.0)),1.0+int(effects.get("movement",0))*0.15);consumable_speed_time=6.0
	if int(effects.get("extra_actions",0))>0:
		for key:Variant in cooldowns:cooldowns[key]=maxf(0.0,float(cooldowns[key])-1.0)
	if float(effects.get("next_attack_damage_multiplier",1.0))>1.0:next_attack_multiplier=float(effects.next_attack_damage_multiplier)
	if int(effects.get("next_attack_accuracy",0))>0 and item_runtime:item_runtime.precision_count=maxi(item_runtime.precision_count,5)
	resource_changed.emit(run_state.class_resource,run_state.get_class_resource_max())

func apply_movement_slow(multiplier:float,duration:float)->void:
	multiplier=clampf(multiplier,0.1,1.0)
	if movement_debuff_time<=0.0 or multiplier<movement_debuff_multiplier:movement_debuff_multiplier=multiplier
	movement_debuff_time=maxf(movement_debuff_time,duration)
	queue_redraw()
	if sprite:
		var tween:=create_tween();tween.tween_property(sprite,"modulate",Color("#8fc7ff"),0.08);tween.tween_property(sprite,"modulate",Color.WHITE,0.22)

func _safe_destination(destination:Vector2,clearance:float=22.0)->Vector2:
	var query:=PhysicsRayQueryParameters2D.create(global_position,destination,1);query.exclude.append(get_rid());var hit:=get_world_2d().direct_space_state.intersect_ray(query)
	var resolved:Vector2=Vector2(hit.position)-aim_direction*clearance if not hit.is_empty() and hit.collider is StaticBody2D else destination
	if position_sanitizer.is_valid():
		var sanitized:Variant=position_sanitizer.call(resolved)
		if sanitized is Vector2:return sanitized
	return resolved

func _enforce_field_bounds()->void:
	if not position_sanitizer.is_valid():return
	var sanitized:Variant=position_sanitizer.call(global_position)
	if sanitized is Vector2:global_position=sanitized

func _enemy_near_aim(range_value:float,dot_threshold:float)->SlasherEnemy:
	var result:SlasherEnemy;var best:=range_value
	for node in get_tree().get_nodes_in_group("slasher_enemy"):
		if node is SlasherEnemy:
			var offset:Vector2=node.global_position-global_position
			if offset.length()<best and aim_direction.dot(offset.normalized())>=dot_threshold:best=offset.length();result=node
	return result

func _nearby_enemy_count(center:Vector2,radius:float)->int:
	var count:=0
	for node in get_tree().get_nodes_in_group("slasher_enemy"):
		if node is SlasherEnemy and center.distance_to(node.global_position)<=radius:count+=1
	return count
func _push_nearby(radius:float,distance:float)->void:
	for node in get_tree().get_nodes_in_group("slasher_enemy"):
		if node is SlasherEnemy and global_position.distance_to(node.global_position)<=radius:node.position+=global_position.direction_to(node.global_position)*distance
func _ensure_companion()->void:
	if is_instance_valid(companion):return
	var tuning:=GameBalance.get_slasher_companion_tuning("wolf");var spawn:Array=tuning.get("spawn_offset",[28,0])
	companion=load("res://scripts/slasher/slasher_wolf.gd").new();companion.name="BondedWolf";get_parent().add_child(companion);companion.global_position=global_position+Vector2(float(spawn[0]),float(spawn[1]));companion.call("setup",self)
func _update_aim()->void:
	var stick_aim:=Input.get_vector("slasher_aim_left","slasher_aim_right","slasher_aim_up","slasher_aim_down")
	var mouse_offset:=get_global_mouse_position()-global_position
	if stick_aim.length()>0.2:aim_direction=stick_aim.normalized()
	elif mouse_offset.length()>4.0:aim_direction=mouse_offset.normalized()
	facing_name=SlasherSpriteLibrary.direction_name(aim_direction,facing_name)
func _ability_tuning(slot:String)->Dictionary:
	return run_state.get_effective_slasher_ability_tuning(slot) if run_state!=null else GameBalance.get_slasher_ability_tuning(class_id,slot)
func _apply_echo_hit(target:Node,data:Dictionary)->void:
	var multiplier:float=float(data.get("echo_damage_multiplier",0.0))
	if multiplier<=0.0:return
	var echo:Dictionary=data.duplicate(true);echo.erase("echo_damage_multiplier");echo.damage=maxi(1,int(round(int(data.damage)*multiplier)));echo.knockback=float(data.get("knockback",0.0))*0.5;target.call("receive_attack",echo,self)
func _action_name(slot:String)->String:return String(GameBalance.get_class_action(class_id,slot).get("name",slot.capitalize()))
func _gain_resource(result:Dictionary,amount:int)->void:run_state.gain_class_resource(amount);result.resource_gained=int(result.get("resource_gained",0))+amount
func heal(amount:int)->void:health=mini(max_health,health+amount);run_state.current_health=health;health_changed.emit(health,max_health)
func add_impact_shake(strength:float,duration:float)->void:
	strength*=GameSettings.get_float("screen_shake_intensity",1.0)
	if strength<=0.0 or duration<=0.0:return
	screen_shake_strength=minf(12.0,sqrt(screen_shake_strength*screen_shake_strength+strength*strength));screen_shake_time=maxf(screen_shake_time,duration);screen_shake_duration=maxf(screen_shake_duration,duration)
	if camera!=null:camera.offset=Vector2(randf_range(-1.0,1.0),randf_range(-1.0,1.0)).normalized()*screen_shake_strength
func _update_screen_shake(delta:float)->void:
	if camera==null:return
	if GameSettings.get_float("screen_shake_intensity",1.0)<=0.0:camera.offset=Vector2.ZERO;screen_shake_time=0.0;screen_shake_strength=0.0;screen_shake_duration=0.0;return
	if screen_shake_time<=0.0:camera.offset=Vector2.ZERO;screen_shake_strength=0.0;screen_shake_duration=0.0;return
	screen_shake_time=maxf(0.0,screen_shake_time-delta)
	var falloff:=screen_shake_time/maxf(0.001,screen_shake_duration)
	camera.offset=Vector2(randf_range(-1.0,1.0),randf_range(-1.0,1.0))*screen_shake_strength*falloff
func _draw()->void:
	if sprite==null or sprite.sprite_frames==null:draw_circle(Vector2.ZERO,18.0,Color.WHITE)
	if invulnerable>0.0:
		var pulse:=0.72+sin(Time.get_ticks_msec()*0.025)*0.18
		draw_arc(Vector2.ZERO,27.0,0.0,TAU,32,Color(0.62,0.88,1.0,pulse),3.0)
	if movement_debuff_time>0.0:draw_arc(Vector2.ZERO,24.0,0.0,TAU,28,Color("#79bfff"),3.0)
func _play_animation(state:String)->void:
	if sprite==null or sprite.sprite_frames==null:return
	var animation:=SlasherSpriteLibrary.resolved_animation(sprite.sprite_frames,state,facing_name)
	if not animation.is_empty() and sprite.animation!=animation:sprite.play(animation)

func _play_action_animation(state:String,cooldown:float)->void:
	if sprite==null or sprite.sprite_frames==null:return
	var animation:=SlasherSpriteLibrary.resolved_animation(sprite.sprite_frames,state,facing_name)
	if animation.is_empty():return
	var frame_count:int=sprite.sprite_frames.get_frame_count(animation)
	var base_fps:float=sprite.sprite_frames.get_animation_speed(animation)
	var natural_duration:float=float(frame_count)/maxf(0.001,base_fps)
	var playback_scale:float=maxf(1.0,natural_duration/maxf(0.001,cooldown))
	# Action playback always restarts so every successfully resolved attack gets a full swing.
	sprite.stop();sprite.play(animation,playback_scale)
