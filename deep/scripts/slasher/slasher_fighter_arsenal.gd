extends "res://scripts/slasher/slasher_warrior_kit.gd"

const MINI_BEAST := preload("res://scripts/slasher/corrupted_mini_beast.gd")
const WEAPON_IDS := ["eldritch_bowstaff","demon_blade","storm_trident","valkyrian_sling","dragonbone_dagger","archon_crossbow","divine_hammer","grim_reaver","sentinel_shield","umbral_bow"]
const PURPLE := Color("#a956d8")
const STORM := Color("#75dcff")
const GOLD := Color("#ffe28a")
const SHADOW := Color("#69518f")

var curses: Dictionary={}
var wounds: Dictionary={}
var pins: Dictionary={}
var leashes: Dictionary={}
var missiles: Array[Dictionary]=[]
var frenzy_left:=0.0
var rampage_left:=0.0
var rampage_stacks:=0
var trident: Dictionary={}
var sling_damage_stacks:=0
var last_proc_count:=0
var spawned_beasts:=0
var repeat_smashes:=0
var visual_clock:=0.0

func tuning(slot: String) -> Dictionary:
	var result:=super(slot)
	match weapon_id:
		"eldritch_bowstaff":
			if slot=="basic":result.damage_coefficient=3.25;result.cooldown=0.2
			elif slot=="special":result.damage_coefficient=7.5
		"demon_blade":
			if slot=="basic":result.damage_coefficient=3.8;result.cooldown=0.2/(1.45 if frenzy_left>0 else 1.0)
			elif slot=="special":result.damage_coefficient=9.0
		"storm_trident":
			if slot=="basic":result.damage_coefficient=3.4
			elif slot=="special":result.damage_coefficient=6.5;result.cooldown=0.45
		"valkyrian_sling":
			if slot=="basic":result.damage_coefficient=3.0;result.cooldown=0.42
			elif slot=="special":result.damage_coefficient=5.0
		"dragonbone_dagger":
			if slot=="basic":result.damage_coefficient=2.65;result.cooldown=0.12
			elif slot=="special":result.damage_coefficient=6.5
		"archon_crossbow":
			if slot=="basic":result.damage_coefficient=4.0;result.cooldown=0.48
			elif slot=="special":result.damage_coefficient=7.5
		"divine_hammer":
			if slot=="basic":result.damage_coefficient=4.2;result.cooldown=0.3
			elif slot=="special":result.damage_coefficient=9.5
		"grim_reaver":
			if slot=="basic":result.damage_coefficient=4.0;result.cooldown=0.24
			elif slot=="special":result.damage_coefficient=9.0
		"sentinel_shield":
			if slot=="basic":result.damage_coefficient=3.2
			elif slot=="special":result.damage_coefficient=6.0;result.cooldown=0.65
		"umbral_bow":
			if slot=="basic":result.damage_coefficient=3.1;result.cooldown=0.38
			elif slot=="special":result.damage_coefficient=5.5
	return result

func attack_for(slot: String, source: String, resource_hit: bool=false) -> Dictionary:
	var attack:=super(slot,source,resource_hit)
	if weapon_id=="demon_blade" and frenzy_left>0:attack.damage=maxi(1,int(round(int(attack.damage)*1.45)))
	if weapon_id=="grim_reaver":
		var chance:=0.28+0.1*rampage_stacks
		if randf()<minf(0.88,chance):attack.critical=true;attack.damage=maxi(1,int(round(int(attack.damage)*1.75)))
	return attack

func modify_incoming_damage(amount: int) -> int:
	return amount*2 if weapon_id=="demon_blade" and frenzy_left>0 else amount

## Lets ordinary class attacks interact with an active weapon's persistent
## battlefield state (pins, opened armor and Reaver rampage).
func adjust_external_attack(target:Node2D,attack:Dictionary)->Dictionary:
	if String(attack.get("warrior_kit",""))==weapon_id:return attack
	var strike:=attack.duplicate(true);var id:=target.get_instance_id() if is_instance_valid(target) else 0
	if weapon_id=="storm_trident" and pins.has(id):strike.damage=maxi(1,int(strike.get("damage",1))*2);strike["storm_pin_bonus"]=true
	if weapon_id=="dragonbone_dagger" and wounds.has(id):strike.damage=maxi(1,int(round(int(strike.get("damage",1))*(1.0+0.12*int(wounds[id].stacks)))))
	if weapon_id=="grim_reaver" and rampage_left>0 and randf()<minf(0.88,0.28+0.1*rampage_stacks):strike.critical=true;strike.damage=maxi(1,int(round(int(strike.get("damage",1))*1.75)))
	return strike

func on_external_hit(target:SlasherEnemy,attack:Dictionary,was_dead:bool)->void:
	if String(attack.get("warrior_kit",""))==weapon_id or was_dead:return
	var id:=target.get_instance_id()
	if weapon_id=="eldritch_bowstaff" and target.dead and curses.has(id):_spawn_corrupted(target.global_position,int(curses[id].stacks));curses.erase(id)
	if weapon_id=="grim_reaver" and target.dead:rampage_stacks=mini(6,rampage_stacks+1);rampage_left=6.0

func can_active_parry()->bool:
	if weapon_id!="valkyrian_sling":return false
	for missile in missiles:
		if missile.kind=="sling" and missile.returning and Vector2(missile.position).distance_to(actor.global_position)<=105.0:return true
	return false

func hit(target: Node2D, attack: Dictionary, primary: bool=false) -> int:
	var strike:=attack.duplicate(true)
	var id:=target.get_instance_id() if is_instance_valid(target) else 0
	if weapon_id=="storm_trident" and pins.has(id):strike.damage=maxi(1,int(strike.damage)*2);strike["storm_pin_bonus"]=true
	if weapon_id=="dragonbone_dagger" and wounds.has(id):strike.damage=maxi(1,int(round(int(strike.damage)*(1.0+0.12*int(wounds[id].stacks)))))
	return super(target,strike,primary)

func on_direct_hit(target: Node2D, attack: Dictionary) -> void:
	super(target,attack)
	if not target is SlasherEnemy:return
	var enemy:=target as SlasherEnemy;var id:=enemy.get_instance_id()
	match weapon_id:
		"eldritch_bowstaff":
			var stacks:=int(curses.get(id,{}).get("stacks",0))+1;curses[id]={"target":weakref(enemy),"stacks":stacks,"left":8.0}
			if enemy.dead:_spawn_corrupted(enemy.global_position,stacks);curses.erase(id)
		"demon_blade":
			frenzy_left=4.0;actor.active_buff_time=maxf(actor.active_buff_time,4.0);actor.active_buff_damage=maxf(actor.active_buff_damage,1.45);actor.active_buff_haste=maxf(actor.active_buff_haste,1.45)
		"dragonbone_dagger":
			wounds[id]={"target":weakref(enemy),"stacks":mini(6,int(wounds.get(id,{}).get("stacks",0))+1),"left":4.0}
		"divine_hammer":
			_radiant_splash(enemy,attack)
			if enemy.dead and not bool(attack.get("divine_repeat",false)):_repeat_divine_smash(enemy.global_position,attack)
		"grim_reaver":
			if enemy.dead:rampage_stacks=mini(6,rampage_stacks+1);rampage_left=6.0

func _spawn_corrupted(origin: Vector2, count: int) -> void:
	last_proc_count=count
	for index in count:
		var beast:=MINI_BEAST.new().setup(actor,origin+Vector2.RIGHT.rotated(TAU*float(index)/maxf(1.0,float(count)))*18.0,index)
		actor.get_parent().add_child(beast);spawned_beasts+=1
	flash(origin,35+count*4,"burst",0.5)

func _radiant_splash(primary: SlasherEnemy, attack: Dictionary) -> void:
	if bool(attack.get("radiant_splash",false)):return
	for enemy in enemies():
		if enemy!=primary and enemy.global_position.distance_to(primary.global_position)<=105.0:
			var splash:=secondary_copy(attack);splash.damage=maxi(1,int(round(int(attack.damage)*0.45)));splash.damage_type="aether";splash.damage_source="Radiant Splash";splash["radiant_splash"]=true
			enemy.receive_attack(splash,actor)
	flash(primary.global_position,105,"burst",0.3)

func _repeat_divine_smash(origin: Vector2, attack: Dictionary) -> void:
	actor.cooldowns["basic"]=0.0
	var nearest: SlasherEnemy;var best:=INF
	for enemy in enemies():
		var distance:=origin.distance_squared_to(enemy.global_position)
		if distance<best:best=distance;nearest=enemy
	if nearest==null:return
	var repeat:=secondary_copy(attack);repeat.damage=maxi(1,int(round(int(attack.damage)*0.8)));repeat.damage_type="aether";repeat.damage_source="Divine Repeat";repeat["divine_repeat"]=true
	repeat_smashes+=1;hit(nearest,repeat,true);flash(nearest.global_position,95,"burst",0.35)

func perform(slot: String, result: Dictionary) -> Dictionary:
	if slot=="defensive" and weapon_id=="valkyrian_sling":
		for missile in missiles:
			if missile.kind=="sling" and missile.returning and Vector2(missile.position).distance_to(actor.global_position)<=105.0:
				sling_damage_stacks+=1;missile.damage_stacks=sling_damage_stacks;missile.returning=false;missile.hit_ids={};missile.bounces=0;missile.position=actor.global_position;missile.direction=actor.aim_direction;flash(actor.global_position,48,"burst",0.3);result.projectiles_deflected=1;return result
	if slot in ["defensive","movement"]:return super(slot,result)
	var attack:=attack_for(slot,action_name(slot),slot=="basic")
	if slot=="special":attack.damage=maxi(1,int(round(int(attack.damage)*1.1)))
	match weapon_id:
		"eldritch_bowstaff":result.targets_hit=slash(actor.global_position,actor.aim_direction,175 if slot=="basic" else 225,150 if slot=="basic" else 260,attack)
		"demon_blade":result.targets_hit=slash(actor.global_position,actor.aim_direction,155 if slot=="basic" else 205,120 if slot=="basic" else 210,attack)
		"storm_trident":
			if slot=="basic":result.targets_hit=slash(actor.global_position,actor.aim_direction,235,24,attack,true,true)
			elif not trident.is_empty():result.started=false;result.failure="Retrieve the Storm Trident before throwing it again."
			else:_throw_trident(attack)
		"valkyrian_sling":_launch_sling(attack,slot=="special")
		"dragonbone_dagger":
			result.targets_hit=slash(actor.global_position,actor.aim_direction,115,105 if slot=="basic" else 190,attack)
			if slot=="special":
				var follow:=secondary_copy(attack);follow.damage=maxi(1,int(round(int(attack.damage)*0.55)));result.targets_hit+=slash(actor.global_position,actor.aim_direction.rotated(0.14),125,115,follow)
		"archon_crossbow":_launch_archon(attack,slot=="special")
		"divine_hammer":result.targets_hit=slash(actor.global_position if slot=="basic" else aimed_point(150),actor.aim_direction,145 if slot=="basic" else 175,220 if slot=="basic" else 360,attack)
		"grim_reaver":result.targets_hit=slash(actor.global_position,actor.aim_direction,205 if slot=="basic" else 250,245 if slot=="basic" else 360,attack)
		"sentinel_shield":
			attack.knockback=95.0 if slot=="basic" else 280.0;attack.hit_stun_duration=0.12 if slot=="basic" else 0.35
			result.targets_hit=slash(actor.global_position,actor.aim_direction,110 if slot=="basic" else 150,100 if slot=="basic" else 130,attack)
		"umbral_bow":_launch_umbral(attack,slot=="special")
	return result

func _throw_trident(attack: Dictionary) -> void:
	var destination:=aimed_point(410)
	trident={"state":"flying","position":actor.global_position,"destination":destination}
	missiles.append({"kind":"trident","position":actor.global_position,"destination":destination,"attack":attack,"speed":720.0})

func _launch_sling(attack: Dictionary, empowered: bool) -> void:
	sling_damage_stacks=0
	missiles.append({"kind":"sling","position":actor.global_position,"direction":actor.aim_direction,"attack":attack,"speed":660.0,"remaining":560.0,"returning":false,"hit_ids":{},"bounces":0,"max_bounces":6 if empowered else 4,"damage_stacks":0})

func _launch_archon(attack: Dictionary, empowered: bool) -> void:
	missiles.append({"kind":"archon","position":actor.global_position,"direction":actor.aim_direction,"attack":attack,"speed":760.0,"remaining":650.0 if empowered else 510.0,"hit_ids":{},"speared":0,"dragged":[]})

func _launch_umbral(attack: Dictionary, empowered: bool) -> void:
	missiles.append({"kind":"umbral","position":actor.global_position,"direction":actor.aim_direction,"attack":attack,"speed":700.0,"remaining":620.0 if empowered else 480.0,"hit_ids":{},"pierces":3 if empowered else 1})

func _physics_process(delta: float) -> void:
	super(delta)
	visual_clock+=delta
	frenzy_left=maxf(0.0,frenzy_left-delta);rampage_left=maxf(0.0,rampage_left-delta)
	if rampage_left<=0.0:rampage_stacks=0
	_tick_statuses(curses,delta);_tick_statuses(wounds,delta);_tick_statuses(pins,delta);_tick_statuses(leashes,delta)
	for id in pins:
		var enemy:SlasherEnemy=(pins[id].target as WeakRef).get_ref()
		if is_instance_valid(enemy) and not enemy.dead:enemy.movement_slow=0.0;enemy.status_time=maxf(enemy.status_time,0.08);enemy.hit_stun_timer=maxf(enemy.hit_stun_timer,0.08)
	var stolen:=0
	for id in leashes:
		var enemy:SlasherEnemy=(leashes[id].target as WeakRef).get_ref()
		if is_instance_valid(enemy) and not enemy.dead:enemy.movement_slow=minf(enemy.movement_slow,0.55);enemy.status_time=maxf(enemy.status_time,0.08);stolen+=1
	if stolen>0:actor.kit_buffs.grant_speed(source_id(),1.0+0.12*stolen,0.1)
	for index in range(missiles.size()-1,-1,-1):
		var missile:=missiles[index]
		var finished:=_tick_missile(missile,delta)
		if finished:missiles.remove_at(index)
	if not trident.is_empty() and trident.state=="deployed" and actor.global_position.distance_to(Vector2(trident.position))<=44.0:
		flash(Vector2(trident.position),38);trident.clear();actor.cooldowns["special"]=0.0
	queue_redraw()

func _tick_statuses(statuses: Dictionary, delta: float) -> void:
	for id in statuses.keys():
		var record:Dictionary=statuses[id];record.left-=delta
		var target:Node=(record.target as WeakRef).get_ref()
		if float(record.left)<=0.0 or not is_instance_valid(target) or ("dead" in target and target.dead):statuses.erase(id)

func _tick_missile(missile: Dictionary, delta: float) -> bool:
	match String(missile.kind):
		"trident":return _tick_trident(missile,delta)
		"sling":return _tick_sling(missile,delta)
		"archon":return _tick_archon(missile,delta)
		"umbral":return _tick_umbral(missile,delta)
	return true

func _tick_trident(missile: Dictionary, delta: float) -> bool:
	missile.position=Vector2(missile.position).move_toward(Vector2(missile.destination),float(missile.speed)*delta);trident.position=missile.position
	if not Vector2(missile.position).is_equal_approx(Vector2(missile.destination)):return false
	trident={"state":"deployed","position":Vector2(missile.destination)};last_proc_count=0
	for enemy in enemies():
		if enemy.global_position.distance_to(Vector2(missile.destination))<=115.0:
			hit(enemy,missile.attack,true);pins[enemy.get_instance_id()]={"target":weakref(enemy),"left":2.6};last_proc_count+=1
	flash(Vector2(missile.destination),115,"burst",0.5);return true

func _tick_sling(missile: Dictionary, delta: float) -> bool:
	var position:=Vector2(missile.position)
	if missile.returning:
		var step:=position.direction_to(actor.global_position)*float(missile.speed)*delta;missile.position=position+step
		return Vector2(missile.position).distance_to(actor.global_position)<=16.0
	var target:=_nearest_unhit(position,missile.hit_ids,320.0)
	var direction:=Vector2(missile.direction) if target==null else position.direction_to(target.global_position)
	var movement:=direction*float(missile.speed)*delta;missile.position=position+movement;missile.remaining-=movement.length();missile.direction=direction
	if target!=null and Vector2(missile.position).distance_to(target.global_position)<=28.0:
		var strike:Dictionary=Dictionary(missile.attack).duplicate(true);strike.damage=maxi(1,int(strike.damage)*(1+int(missile.damage_stacks)));hit(target,strike,true);missile.hit_ids[target.get_instance_id()]=true;missile.bounces+=1;arc(position,target.global_position)
	if int(missile.bounces)>=int(missile.max_bounces) or float(missile.remaining)<=0.0 or target==null:missile.returning=true
	return false

func _tick_archon(missile: Dictionary, delta: float) -> bool:
	var movement:=Vector2(missile.direction)*float(missile.speed)*delta;missile.position=Vector2(missile.position)+movement;missile.remaining-=movement.length()
	for reference in missile.dragged:
		var dragged:SlasherEnemy=(reference as WeakRef).get_ref()
		if is_instance_valid(dragged) and not dragged.dead and not dragged.boss and not dragged.mini_boss:dragged.global_position=Vector2(missile.position)-Vector2(missile.direction)*(26.0+missile.dragged.find(reference)*18.0)
	for enemy in enemies():
		if missile.hit_ids.has(enemy.get_instance_id()) or enemy.global_position.distance_to(Vector2(missile.position))>30.0:continue
		var strike:Dictionary=Dictionary(missile.attack).duplicate(true);strike.damage=maxi(1,int(round(int(strike.damage)*(1.0+0.35*int(missile.speared)))));hit(enemy,strike,true);missile.hit_ids[enemy.get_instance_id()]=true;missile.speared+=1;missile.dragged.append(weakref(enemy));last_proc_count=int(missile.speared)
	return float(missile.remaining)<=0.0

func _tick_umbral(missile: Dictionary, delta: float) -> bool:
	var movement:=Vector2(missile.direction)*float(missile.speed)*delta;missile.position=Vector2(missile.position)+movement;missile.remaining-=movement.length()
	for enemy in enemies():
		if missile.hit_ids.has(enemy.get_instance_id()) or enemy.global_position.distance_to(Vector2(missile.position))>28.0:continue
		hit(enemy,missile.attack,true);missile.hit_ids[enemy.get_instance_id()]=true;leashes[enemy.get_instance_id()]={"target":weakref(enemy),"left":4.0};missile.pierces-=1;last_proc_count=leashes.size();arc(actor.global_position,enemy.global_position)
		if int(missile.pierces)<=0:return true
	return float(missile.remaining)<=0.0

func _nearest_unhit(origin: Vector2, hit_ids: Dictionary, radius: float) -> SlasherEnemy:
	var nearest:SlasherEnemy;var best:=radius*radius
	for enemy in enemies():
		if hit_ids.has(enemy.get_instance_id()):continue
		var distance:=origin.distance_squared_to(enemy.global_position)
		if distance<best:best=distance;nearest=enemy
	return nearest

func draw_foreground(canvas: Node2D) -> void:
	super(canvas)
	for missile in missiles:
		var point:=to_local(Vector2(missile.position));var color:=STORM if missile.kind=="trident" else GOLD if missile.kind in ["sling","archon"] else SHADOW
		var heading:=Vector2(missile.get("direction",actor.aim_direction)).normalized()
		for trail in 4:canvas.draw_circle(point-heading*(trail+1)*9.0,maxf(1.0,6.0-trail),Color(color,0.42-float(trail)*0.08))
		canvas.draw_circle(point,9.0,color);canvas.draw_arc(point,14.0+sin(visual_clock*9.0)*2.0,0,TAU,18,Color(color,0.7),2.0)
		if missile.kind=="trident":_draw_lightning(canvas,point,28.0)
		elif missile.kind=="sling":
			canvas.draw_arc(point-heading.orthogonal()*8.0,12.0,-1.1,1.1,10,Color(GOLD,0.7),2.0)
			canvas.draw_arc(point+heading.orthogonal()*8.0,12.0,PI-1.1,PI+1.1,10,Color(GOLD,0.7),2.0)
		elif missile.kind=="archon":canvas.draw_line(point-heading*34.0,point+heading*14.0,Color("#d9e4ea"),5.0,true)
		elif missile.kind=="umbral":canvas.draw_polyline(PackedVector2Array([point,point-heading*14.0+heading.orthogonal()*sin(visual_clock*11.0)*7.0,point-heading*30.0]),Color(SHADOW,0.65),5.0,true)
	if not trident.is_empty() and trident.state=="deployed":
		var point:=to_local(Vector2(trident.position));canvas.draw_line(point+Vector2(0,25),point-Vector2(0,25),STORM,5);canvas.draw_line(point-Vector2(0,25),point+Vector2(-10,-12),STORM,4);canvas.draw_line(point-Vector2(0,25),point+Vector2(10,-12),STORM,4);_draw_lightning(canvas,point,44.0)
	for id in curses:
		var state:Dictionary=curses[id];var enemy:SlasherEnemy=(state.target as WeakRef).get_ref()
		if is_instance_valid(enemy):
			var point:=to_local(enemy.global_position);var stacks:=int(state.stacks)
			canvas.draw_arc(point,22.0+stacks*2.0,visual_clock*2.0,visual_clock*2.0+5.2,24,PURPLE,2.5,true)
			for i in stacks:canvas.draw_circle(point+Vector2.from_angle(TAU*i/maxf(1.0,stacks)+visual_clock*2.5)*(27.0+stacks),2.5,Color("#70edbd"))
	for id in wounds:
		var state:Dictionary=wounds[id];var enemy:SlasherEnemy=(state.target as WeakRef).get_ref()
		if is_instance_valid(enemy):
			var point:=to_local(enemy.global_position);var stacks:=int(state.stacks)
			for i in stacks:canvas.draw_line(point+Vector2(-12+i*4,-13),point+Vector2(-18+i*4,12),Color("#d54c45"),2.5,true)
	for id in pins:
		var state:Dictionary=pins[id];var enemy:SlasherEnemy=(state.target as WeakRef).get_ref()
		if is_instance_valid(enemy):_draw_lightning(canvas,to_local(enemy.global_position),27.0)
	for id in leashes:
		var enemy:SlasherEnemy=(leashes[id].target as WeakRef).get_ref()
		if is_instance_valid(enemy):
			var endpoint:=to_local(enemy.global_position);var points:=PackedVector2Array()
			for i in 12:
				var ratio:=float(i)/11.0;points.append(Vector2.ZERO.lerp(endpoint,ratio)+endpoint.orthogonal().normalized()*sin(ratio*18.0-visual_clock*8.0)*6.0)
			canvas.draw_polyline(points,Color(SHADOW,0.8),3.0,true)
	if frenzy_left>0:
		canvas.draw_arc(Vector2.ZERO,42+sin(visual_clock*12.0)*4.0,0,TAU,36,Color("#e44232"),4)
		for i in 6:canvas.draw_line(Vector2.from_angle(TAU*i/6.0+visual_clock*3.0)*32.0,Vector2.from_angle(TAU*i/6.0+visual_clock*3.0)*54.0,Color("#ff8e45"),3.0,true)
	if rampage_left>0:
		canvas.draw_arc(Vector2.ZERO,48,visual_clock*2.0,visual_clock*2.0+TAU*clampf(rampage_left/6.0,0,1),36,Color("#bd3349"),3+rampage_stacks)
		for i in rampage_stacks:canvas.draw_circle(Vector2.from_angle(TAU*i/maxf(1.0,rampage_stacks)-visual_clock)*58.0,3.0,Color("#a66cff"))

func _draw_lightning(canvas:Node2D,center:Vector2,radius:float)->void:
	for branch in 3:
		var points:=PackedVector2Array([center]);var ray:=Vector2.from_angle(TAU*branch/3.0+visual_clock*2.4)
		for step in range(1,5):points.append(center+ray*radius*step/4.0+ray.orthogonal()*sin(step*5.1+visual_clock*18.0+branch)*5.0)
		canvas.draw_polyline(points,Color(STORM,0.8),2.0,true)
