extends Node2D
class_name SlasherMageActiveArsenal

## Persistent runtime for the Mage active-item arsenal. The node stays attached
## to the player so charges, marks, foliage, webs and channels survive the
## initial button press and can react to later basic attacks.

var actor:SlasherPlayer
var item_id:=""
var active_time:=0.0
var tick_time:=0.0
var charge_time:=0.0
var orb_energy:=0
var tome_stacks:=0
var tome_souls:=0
var dragon_fuel:=0.0
var web_active:=false
var web_points:Array[Vector2]=[]
var caught:Dictionary={}
var poison:Dictionary={}
var marked:Dictionary={}
var exposure:Dictionary={}
var delayed_bursts:Array[Dictionary]=[]
var missiles:Array[Dictionary]=[]
var anchor:=Vector2.ZERO
var defer_spend_once:=false
var flare_cooldown:=0.0
var _last_space_down:=false
var visual_clock:=0.0

func configure(player:SlasherPlayer,id:String)->void:
	actor=player;item_id=id;set_process(true);queue_redraw()

func activate()->bool:
	if not is_instance_valid(actor):return false
	defer_spend_once=false
	match item_id:
		"michaels_orb":active_time=maxf(active_time,45.0);orb_energy=mini(orb_energy,2)
		"gulthias_staff":_fire_gulthias_bolt()
		"skyblinder_staff":charge_time=0.01;active_time=2.25;_last_space_down=true
		"dragonstaff_of_ahghairon":dragon_fuel=maxf(dragon_fuel,2.5);active_time=dragon_fuel;anchor=actor.global_position
		"jade_serpent_staff":_fire_jade_dart()
		"arachne_staff":
			if web_active:_end_web()
			else:
				web_active=true;web_points=[actor.global_position];caught.clear();active_time=45.0;defer_spend_once=true
		"tome_of_toth":active_time=maxf(active_time,45.0);tome_stacks=0;tome_souls=0
		"shangos_shatterer":_cast_shango()
		"solar_scepter":active_time=10.0;tick_time=0.0;exposure.clear()
		"drumamus_bargain":active_time=4.5;charge_time=0.0;anchor=actor.global_position;actor.input_locked=true;_last_space_down=true
		_:return false
	queue_redraw();return true

func _process(delta:float)->void:
	if not is_instance_valid(actor):queue_free();return
	visual_clock+=delta
	active_time=maxf(0.0,active_time-delta)
	flare_cooldown=maxf(0.0,flare_cooldown-delta)
	_process_missiles(delta);_process_poison(delta);_process_delayed(delta)
	match item_id:
		"michaels_orb":queue_redraw()
		"skyblinder_staff":_process_skyblinder(delta)
		"dragonstaff_of_ahghairon":_process_dragonfire(delta)
		"arachne_staff":_process_web(delta)
		"solar_scepter":_process_solar(delta)
		"drumamus_bargain":_process_gravity(delta)
	queue_redraw()

func adjust_external_attack(target:Node2D,attack:Dictionary)->Dictionary:
	var result:=attack.duplicate(true)
	if item_id=="tome_of_toth" and active_time>0.0 and tome_stacks>0:
		result.damage=maxi(1,int(round(float(result.get("damage",1))*(1.0+0.10*tome_stacks))))
		result["tome_empowered"]=true
	if item_id=="arachne_staff" and web_active and not caught.is_empty():
		result.damage=maxi(1,int(round(float(result.get("damage",1))*(1.0+0.12*mini(6,caught.size())))))
	if item_id=="solar_scepter" and active_time>0.0 and String(result.get("damage_type",""))=="fire" and is_instance_valid(target):
		var stacks:=float(exposure.get(target.get_instance_id(),0.0))
		result.damage=maxi(1,int(round(float(result.get("damage",1))*(1.0+minf(1.0,stacks*0.12)))))
	return result

func on_external_hit(target:SlasherEnemy,attack:Dictionary,was_dead:bool)->void:
	if not is_instance_valid(target):return
	var killed:=not was_dead and target.dead
	match item_id:
		"michaels_orb":
			if active_time>0.0 and String(attack.get("damage_source",""))!="michaels_orb":
				orb_energy+=1
				if orb_energy>=3:orb_energy=0;_launch_orb(target)
		"gulthias_staff":
			if killed and String(attack.get("damage_source",""))=="gulthias_staff":_spawn_foliage(target.global_position)
		"dragonstaff_of_ahghairon":
			if killed and String(attack.get("damage_source",""))=="dragonstaff":dragon_fuel=minf(7.0,dragon_fuel+1.4);active_time=dragon_fuel
		"jade_serpent_staff":
			if String(attack.get("damage_source",""))=="jade_serpent":_mark_poison(target)
			if killed and marked.has(target.get_instance_id()):marked.erase(target.get_instance_id());_launch_snake(target.global_position)
		"tome_of_toth":
			if active_time>0.0:
				tome_stacks=mini(20,tome_stacks+1)
				if killed:tome_souls+=1
	queue_redraw()

func on_projectile_miss(_attack:Dictionary)->void:
	if item_id=="tome_of_toth" and active_time>0.0:tome_stacks=0;queue_redraw()

func on_owner_damaged(amount:int)->void:
	if item_id=="solar_scepter" and active_time>0.0 and amount>0 and flare_cooldown<=0.0:
		_damage_area(actor.global_position,135.0,1.8,"radiant",{"hit_stun_duration":0.55,"damage_source":"solar_flare"});flare_cooldown=0.9

func _base(multiplier:float=1.0)->int:
	return maxi(1,int(round(maxi(actor.spell_power,actor.attack_power)*multiplier)))

func _enemies()->Array[SlasherEnemy]:
	var result:Array[SlasherEnemy]=[]
	if not is_inside_tree():return result
	for node in get_tree().get_nodes_in_group("slasher_enemy"):
		if node is SlasherEnemy and is_instance_valid(node) and not node.dead:result.append(node)
	return result

func _nearest(point:Vector2,excluded:Dictionary={},range_value:float=99999.0)->SlasherEnemy:
	var best:SlasherEnemy;var distance:=range_value
	for foe in _enemies():
		if excluded.has(foe.get_instance_id()):continue
		var d:=point.distance_to(foe.global_position)
		if d<distance:distance=d;best=foe
	return best

func _hit(target:SlasherEnemy,damage:int,kind:String,extra:Dictionary={})->void:
	if not is_instance_valid(target) or target.dead:return
	var data:=actor._attack_data(damage,kind,extra);target.receive_attack(data,actor)

func _damage_area(point:Vector2,radius:float,multiplier:float,kind:String,extra:Dictionary={})->int:
	var count:=0
	for foe in _enemies():
		if point.distance_to(foe.global_position)<=radius:_hit(foe,_base(multiplier),kind,extra);count+=1
	return count

func _launch_orb(first:SlasherEnemy)->void:
	missiles.append({"kind":"orb","position":actor.global_position-Vector2(0,30),"target":first,"speed":620.0,"hits":{},"bounces":5,"element":["fire","ice","lightning"][randi()%3]})

func _fire_gulthias_bolt()->void:
	var target:=_nearest(actor.global_position+actor.aim_direction*150.0,{},520.0)
	if target==null:return
	_hit(target,_base(2.0),"aether",{"damage_source":"gulthias_staff","hit_stun_duration":0.25})

func _fire_jade_dart()->void:
	var target:=_nearest(actor.global_position+actor.aim_direction*160.0,{},520.0)
	if target==null:return
	_hit(target,_base(1.25),"poison",{"damage_source":"jade_serpent","status":"slow","status_strength":0.58,"status_duration":4.0})
	_mark_poison(target)

func _mark_poison(target:SlasherEnemy)->void:
	if not is_instance_valid(target):return
	var id:=target.get_instance_id();marked[id]=target;poison[id]={"target":target,"time":6.0,"tick":0.5}
	target.movement_slow=minf(target.movement_slow,0.58);target.status_time=maxf(target.status_time,4.0)

func _process_poison(delta:float)->void:
	for id in poison.keys().duplicate():
		var state:Dictionary=poison[id];var target:SlasherEnemy=state.get("target")
		if not is_instance_valid(target) or target.dead:poison.erase(id);continue
		state.time=float(state.time)-delta;state.tick=float(state.tick)-delta
		if float(state.tick)<=0.0:state.tick=0.7;_hit(target,_base(0.28),"poison",{"damage_source":"jade_serpent","status":"slow","status_strength":0.58,"status_duration":1.0})
		if float(state.time)<=0.0:poison.erase(id);marked.erase(id)
		else:poison[id]=state

func _launch_snake(point:Vector2)->void:
	var target:=_nearest(point,{},700.0)
	if target!=null:missiles.append({"kind":"snake","position":point,"target":target,"speed":520.0,"hits":{},"bounces":maxi(1,marked.size()+1)})

func _process_missiles(delta:float)->void:
	for index in range(missiles.size()-1,-1,-1):
		var shot:Dictionary=missiles[index];var target:SlasherEnemy=shot.get("target")
		if not is_instance_valid(target) or target.dead:
			target=_nearest(Vector2(shot.position),Dictionary(shot.hits),500.0);shot.target=target
		if target==null:missiles.remove_at(index);continue
		var pos:=Vector2(shot.position);pos=pos.move_toward(target.global_position,float(shot.speed)*delta);shot.position=pos
		if pos.distance_to(target.global_position)<18.0:
			var kind:=String(shot.kind);var hits:Dictionary=shot.hits;hits[target.get_instance_id()]=true
			if kind=="orb":_hit(target,_base(1.8),String(shot.element),{"damage_source":"michaels_orb","area_radius":50.0});_damage_area(pos,48.0,0.65,String(shot.element),{"damage_source":"michaels_orb"})
			else:_hit(target,_base(1.1),"poison",{"damage_source":"spectral_snake","status":"slow","status_strength":0.55,"status_duration":2.0})
			shot.bounces=int(shot.bounces)-1;shot.hits=hits;shot.target=_nearest(pos,hits,360.0)
			if int(shot.bounces)<=0 or shot.target==null:missiles.remove_at(index);continue
		missiles[index]=shot
	queue_redraw()

func _spawn_foliage(point:Vector2)->void:
	var plant:=MageFoliage.new();plant.runtime=self;plant.top_level=true;get_parent().add_child(plant);plant.global_position=point

func spawn_treant(point:Vector2)->void:
	var treant:=MageTreant.new();treant.runtime=self;treant.life=12.0;treant.top_level=true;get_parent().add_child(treant);treant.global_position=point

func _process_skyblinder(delta:float)->void:
	if charge_time<=0.0:return
	charge_time=minf(2.0,charge_time+delta)
	var held:=Input.is_action_pressed("slasher_special")
	if (not held and _last_space_down) or active_time<=0.0:_release_skyblinder()
	_last_space_down=held

func _release_skyblinder()->void:
	var ratio:=clampf(charge_time/2.0,0.15,1.0);var point:=actor.global_position+actor.aim_direction*360.0
	var target:=_nearest(point,{},500.0)
	if target!=null:point=target.global_position
	var radius:=42.0+58.0*ratio;var stun:=0.25+1.35*ratio
	_damage_area(point,radius,1.0+2.4*ratio,"radiant",{"damage_source":"skyblinder","hit_stun_duration":stun})
	# Ordinary enemy tuning caps hit-stun from attacks to a short flinch. This is
	# an authored control spell, so pay out the charged stun explicitly after the
	# damage lands. Bosses retain resistance without making the charge cosmetic.
	for foe in _enemies():
		if point.distance_to(foe.global_position)<=radius:
			var resolved_stun:=stun*0.35 if foe.boss or foe.mini_boss else stun
			foe.hit_stun_timer=maxf(foe.hit_stun_timer,resolved_stun)
	charge_time=0.0;active_time=0.0;actor.add_impact_shake(5.0+7.0*ratio,0.25);queue_redraw()

func _process_dragonfire(delta:float)->void:
	if active_time<=0.0 or dragon_fuel<=0.0:return
	dragon_fuel=maxf(0.0,dragon_fuel-delta);active_time=dragon_fuel;tick_time-=delta
	if tick_time>0.0:return
	tick_time=0.16
	for foe in _enemies():
		var offset:=foe.global_position-actor.global_position
		if offset.length()<=245.0 and actor.aim_direction.dot(offset.normalized())>0.67:_hit(foe,_base(0.42),"fire",{"damage_source":"dragonstaff","hit_stun_duration":0.05})
	queue_redraw()

func _process_web(delta:float)->void:
	if not web_active:return
	if active_time<=0.0:_end_web();return
	if web_points.is_empty() or web_points.back().distance_to(actor.global_position)>24.0:web_points.append(actor.global_position);if web_points.size()>80:web_points.pop_front()
	caught.clear()
	for foe in _enemies():
		for point in web_points:
			if foe.global_position.distance_to(point)<=30.0:caught[foe.get_instance_id()]=foe;foe.movement_slow=minf(foe.movement_slow,0.45);foe.status_time=maxf(foe.status_time,0.25);break
	if is_instance_valid(actor.kit_buffs):actor.kit_buffs.grant_speed("arachne_web",1.0+0.08*mini(6,caught.size()),0.3)
	queue_redraw()

func _end_web()->void:
	web_active=false;active_time=0.0;caught.clear();web_points.clear();queue_redraw()

func _cast_shango()->void:
	var direction:=actor.aim_direction.normalized() if not actor.aim_direction.is_zero_approx() else Vector2.RIGHT
	for index in 6:
		var point:=actor.global_position+direction*(70.0+index*58.0)
		_damage_area(point,40.0,0.42,"lightning",{"damage_source":"shango_lightning"})
		delayed_bursts.append({"time":0.65+index*0.11,"point":point,"radius":62.0+index*3.0})

func _process_delayed(delta:float)->void:
	for index in range(delayed_bursts.size()-1,-1,-1):
		var burst:Dictionary=delayed_bursts[index];burst.time=float(burst.time)-delta
		if float(burst.time)<=0.0:_damage_area(Vector2(burst.point),float(burst.radius),1.45,"thunder",{"damage_source":"shango_thunder","hit_stun_duration":0.35});delayed_bursts.remove_at(index);actor.add_impact_shake(5.0,0.12)
		else:delayed_bursts[index]=burst

func _process_solar(delta:float)->void:
	if active_time<=0.0:return
	tick_time-=delta
	for foe in _enemies():
		if actor.global_position.distance_to(foe.global_position)<=150.0:
			var id:=foe.get_instance_id();exposure[id]=minf(8.0,float(exposure.get(id,0.0))+delta)
			foe.movement_slow=minf(foe.movement_slow,0.72);foe.status_time=maxf(foe.status_time,0.25)
	if tick_time<=0.0:tick_time=0.45;_damage_area(actor.global_position,150.0,0.38,"radiant",{"damage_source":"solar_aura"})
	queue_redraw()

func _process_gravity(delta:float)->void:
	if active_time<=0.0:
		if actor.input_locked:actor.input_locked=false
		charge_time=0.0;return
	actor.global_position=anchor;actor.velocity=Vector2.ZERO;charge_time=minf(4.5,charge_time+delta)
	var radius:=110.0+charge_time*42.0;tick_time-=delta
	for foe in _enemies():
		var offset:=anchor-foe.global_position
		if offset.length()<=radius and offset.length()>15.0:
			var swirl:=offset.normalized().orthogonal()*45.0*delta;foe.move_and_collide(offset.normalized()*minf(95.0*delta,offset.length()-12.0)+swirl)
	if tick_time<=0.0:tick_time=0.3;_damage_area(anchor,radius,0.48,"aether",{"damage_source":"drumamu_gravity","hit_stun_duration":0.08})
	if not Input.is_action_pressed("slasher_special") and _last_space_down:active_time=0.0;actor.input_locked=false
	_last_space_down=Input.is_action_pressed("slasher_special");queue_redraw()

func _draw()->void:
	if not is_instance_valid(actor):return
	if item_id=="michaels_orb" and active_time>0.0:
		var angle:=visual_clock*3.0;var p:=Vector2(cos(angle)*30.0,-30.0+sin(angle)*12.0)
		var prism:=PackedVector2Array();for i in 6:prism.append(p+Vector2.from_angle(TAU*i/6.0-angle)*9.0)
		draw_colored_polygon(prism,Color(0.75,0.4,1.0,0.55));draw_polyline(prism+PackedVector2Array([prism[0]]),Color("#7eeeff"),2.0,true)
		for i in orb_energy:draw_circle(p+Vector2(-7+i*7,-14),2.5,Color("#fff59b"))
	for shot in missiles:
		var p:Vector2=Vector2(shot.position)-actor.global_position;var c:=Color("#83f0ff") if String(shot.kind)=="orb" else Color("#67e68a")
		draw_circle(p,7.0,c)
		var target:SlasherEnemy=shot.get("target");var heading:=p.direction_to(target.global_position-actor.global_position) if is_instance_valid(target) else actor.aim_direction
		for i in 4:draw_circle(p-heading*(i+1)*7.0,4.5-i,Color(c,0.5-float(i)*0.1))
		if String(shot.kind)=="snake":
			var snake:=PackedVector2Array();for i in 7:snake.append(p-heading*i*6.0+heading.orthogonal()*sin(i*1.7-visual_clock*13.0)*5.0)
			draw_polyline(snake,Color("#50d574"),4.0,true)
	if item_id=="skyblinder_staff" and charge_time>0.0:
		var ratio:=charge_time/2.0;var focus:=actor.aim_direction*lerpf(45.0,120.0,ratio)
		draw_line(Vector2.ZERO,focus,Color(1.0,0.96,0.6,0.75),2.0+ratio*5.0,true)
		for i in 10:draw_line(Vector2.from_angle(TAU*i/10.0+visual_clock)*lerpf(34.0,15.0,ratio),Vector2.from_angle(TAU*i/10.0+visual_clock)*45.0,Color("#fffbd0"),2.0,true)
	if item_id=="dragonstaff_of_ahghairon" and active_time>0.0:
		for i in 18:
			var distance:=30.0+float(i%6)*35.0;var spread:=(float(i/6)-1.0)*0.22;var p:=actor.aim_direction.rotated(spread)*distance+actor.aim_direction.orthogonal()*sin(visual_clock*12.0+i)*8.0
			draw_circle(p,5.0+float(i%4),Color("#ffb13b") if i%2==0 else Color("#f04c27"))
	for state in poison.values():
		var target:SlasherEnemy=state.get("target")
		if is_instance_valid(target):
			var p:=target.global_position-actor.global_position;draw_arc(p,22.0+sin(visual_clock*6.0)*3.0,visual_clock,visual_clock+5.2,22,Color("#55d879"),3.0,true)
	if item_id=="arachne_staff" and web_active and web_points.size()>1:
		var local:=PackedVector2Array();for p in web_points:local.append(p-actor.global_position)
		draw_polyline(local,Color(0.88,0.9,1.0,0.75),6.0,true)
		for i in range(0,local.size(),4):draw_circle(local[i],5.0+sin(visual_clock*7.0+i)*2.0,Color(0.72,0.6,0.95,0.7))
		for enemy in caught.values():if is_instance_valid(enemy):draw_arc(enemy.global_position-actor.global_position,27.0,0,TAU,18,Color("#f2eaff"),3.0,true)
	if item_id=="tome_of_toth" and active_time>0.0:
		for side in [-1.0,1.0]:draw_arc(Vector2(side*15.0,-28.0),18.0,-1.4,1.4,16,Color(0.4,0.9,0.8,0.65),3.0,true)
		for i in mini(tome_stacks,12):draw_circle(Vector2.from_angle(TAU*i/maxf(1.0,mini(tome_stacks,12))+visual_clock)*42.0,2.5,Color("#ad7be8"))
	for burst in delayed_bursts:
		var p:=Vector2(burst.point)-actor.global_position;var urgency:=1.0-clampf(float(burst.time),0.0,1.0)
		draw_arc(p,float(burst.radius)*(0.65+urgency*0.35),visual_clock*3.0,visual_clock*3.0+5.2,32,Color(0.45,0.7,1.0,0.7),2.0+urgency*3.0,true)
		for i in 4:draw_line(p,p+Vector2.from_angle(TAU*i/4.0+visual_clock)*float(burst.radius)*0.7,Color(1.0,0.82,0.3,0.5),2.0,true)
	if item_id=="solar_scepter" and active_time>0.0:
		draw_arc(Vector2.ZERO,150.0,0,TAU,64,Color(1.0,0.75,0.2,0.6),5.0,true)
		for i in 12:draw_line(Vector2.from_angle(TAU*i/12.0+visual_clock*0.5)*118.0,Vector2.from_angle(TAU*i/12.0+visual_clock*0.5)*153.0,Color(1.0,0.9,0.45,0.65),3.0,true)
	if item_id=="drumamus_bargain" and active_time>0.0:
		var center:=anchor-actor.global_position;var radius:=110.0+charge_time*42.0
		for i in 4:draw_arc(center,radius*(0.35+i*0.2),visual_clock*(i+1),visual_clock*(i+1)+4.8,48,Color(0.55+0.08*i,0.25,0.9,0.7),5.0-i*0.7,true)
		for foe in _enemies():if foe.global_position.distance_to(anchor)<=radius:draw_line(foe.global_position-actor.global_position,center,Color(0.7,0.35,1.0,0.22),2.0,true)

class MageFoliage extends Node2D:
	var runtime:SlasherMageActiveArsenal
	var health:=1
	func _ready()->void:add_to_group("slasher_damageable");queue_redraw()
	func receive_attack(_attack:Dictionary,_attacker:SlasherPlayer=null)->int:
		if is_instance_valid(runtime):runtime.spawn_treant(global_position)
		remove_from_group("slasher_damageable");queue_free();return 1
	func _draw()->void:
		var sway:=sin(Time.get_ticks_msec()/280.0)*3.0;draw_rect(Rect2(-4,-20,8,22),Color("#6d4d2d"));draw_circle(Vector2(-7+sway,-20),12.0,Color("#4f9a4b"));draw_circle(Vector2(8+sway,-17),11.0,Color("#67b85b"));draw_arc(Vector2.ZERO,24.0,0,TAU,20,Color(0.45,0.9,0.4,0.3),2.0,true)

class MageTreant extends Node2D:
	var runtime:SlasherMageActiveArsenal
	var life:=12.0
	var cooldown:=0.0
	func _process(delta:float)->void:
		life-=delta;cooldown=maxf(0.0,cooldown-delta)
		if life<=0.0 or not is_instance_valid(runtime):queue_free();return
		var target:=runtime._nearest(global_position,{},500.0)
		if target==null:return
		global_position=global_position.move_toward(target.global_position,70.0*delta)
		if global_position.distance_to(target.global_position)<55.0 and cooldown<=0.0:cooldown=1.1;runtime._damage_area(global_position,65.0,0.9,"physical",{"damage_source":"gulthias_treant","hit_stun_duration":0.25,"knockback":45.0})
		queue_redraw()
	func _draw()->void:
		var stomp:=sin(Time.get_ticks_msec()/120.0)*3.0;draw_rect(Rect2(-12,-20,24,34),Color("#725033"));draw_circle(Vector2.ZERO,8.0,Color("#a8d36d"));draw_line(Vector2(-10,4),Vector2(-20,18+stomp),Color("#725033"),6.0);draw_line(Vector2(10,4),Vector2(20,18-stomp),Color("#725033"),6.0);draw_arc(Vector2.ZERO,28.0+absf(stomp)*3.0,0,TAU,24,Color(0.55,0.75,0.3,0.35),3.0,true)
