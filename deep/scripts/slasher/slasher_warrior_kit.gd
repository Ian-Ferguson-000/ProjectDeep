extends "res://scripts/slasher/slasher_mage_kit_base.gd"

var weapon_id := ""
var action_names: Dictionary={}
var pending: Array[Dictionary]=[]
var lane: Dictionary={}
var banner: Dictionary={}
var tether: Dictionary={}
var strokes: Dictionary={}
var sabre_side := -1
var exposure: Dictionary={}
var special_bonus: Dictionary={}
var ready_hew := 0.0
var guard_left := 0.0
var guard_blocks := 0
var guard_rewarded := false
var recipients: Array[WeakRef]=[]
var history: Array[Dictionary]=[]
var last_slam_center := Vector2.ZERO
var last_hits := 0
var last_targets: Array[WeakRef]=[]
const TINT := Color("#ffdc93")
const BANNER_RADIUS := 150.0

func configure(player: SlasherPlayer, id: String, names: Dictionary) -> void:
	weapon_id=id;action_names=names;setup(player)
func kit_id() -> String:return weapon_id
func element() -> String:return "physical"
func action_name(slot: String) -> String:return action_names.get(slot,slot.capitalize())
func source_id() -> String:return "banner:"+str(get_instance_id())

func tuning(slot: String) -> Dictionary:
	var basic_cd := 0.18;var coefficient := 3.6
	match weapon_id:
		"headsmans_greatsword":basic_cd=0.24;coefficient=4.8
		"borderkeepers_spear":coefficient=3.2
		"duelists_paired_sabres":basic_cd=0.14;coefficient=3.0
		"chain_of_the_siege_breaker":basic_cd=0.22;coefficient=4.2
	var result: Dictionary={}
	match slot:
		"basic":result={"cooldown":basic_cd,"resource_cost":0,"power_stat":"attack_power","damage_coefficient":coefficient,"animation_lock":0.1}
		"special":result={"cooldown":0.9,"resource_cost":2,"power_stat":"attack_power","damage_coefficient":10.0,"animation_lock":0.12}
		"defensive":result={"cooldown":0.7,"resource_cost":0,"mitigation":0.6,"effect_duration":0.6,"animation_lock":0.1}
		"movement":result={"cooldown":0.65,"resource_cost":0,"animation_lock":0.1}
	var base := GameBalance.get_slasher_ability_tuning("warrior",slot)
	var progressed := actor.run_state.get_effective_slasher_ability_tuning(slot)
	for key in ["damage_coefficient","cooldown"]:
		if result.has(key) and float(base.get(key,0))>0:result[key]=float(result[key])*float(progressed.get(key,base[key]))/float(base[key])
	return result

func attack_for(slot: String, source: String, resource_hit: bool=false) -> Dictionary:
	cast_serial+=1
	var attack := actor._configured_attack(tuning(slot),"physical")
	attack.hit_stun_duration=0.08
	attack.merge({"warrior_kit":weapon_id,"warrior_cast":cast_serial,"warrior_resource":resource_hit,"damage_source":source},true)
	return attack

func secondary_copy(attack: Dictionary) -> Dictionary:
	var result := super(attack)
	for key in ["warrior_kit","warrior_cast","warrior_resource"]:result.erase(key)
	return result

func on_direct_hit(target: Node2D, attack: Dictionary) -> void:
	if not target is SlasherEnemy or String(attack.get("warrior_kit",""))!=weapon_id or not attack.get("warrior_resource",false):return
	var serial := int(attack.get("warrior_cast",-1))
	if rewarded_casts.has(serial):return
	var gain := 2
	if weapon_id=="borderkeepers_spear":gain=2 if bool(attack.get("tip",false)) else 0
	if weapon_id=="duelists_paired_sabres":
		var id := target.get_instance_id()
		gain=2 if int(strokes.get("target",0))==id and float(strokes.get("left",0))>0 else 0
		strokes={} if gain>0 else {"target":id,"left":2.0}
	if weapon_id=="borderkeepers_spear" and gain==0:return
	rewarded_casts[serial]=4.0
	if gain>0:actor._award_resource(gain);actor.resource_changed.emit(actor.run_state.class_resource,actor.run_state.get_class_resource_max())

func slash(origin: Vector2, direction: Vector2, reach: float, degrees: float, attack: Dictionary, primary: bool=true, line: bool=false, maximum: int=0) -> int:
	var count := 0
	last_targets.clear()
	history.append({"origin":origin,"direction":direction,"reach":reach,"degrees":degrees,"line":line,"left":0.28,"duration":0.28,"side":sabre_side if weapon_id=="duelists_paired_sabres" else 0})
	while history.size()>20:history.pop_front()
	for enemy in enemies():
		if maximum>0 and count>=maximum:break
		var offset := enemy.global_position-origin
		var forward := offset.dot(direction)
		if line:
			if forward<0 or forward>reach or absf(offset.cross(direction))>degrees:continue
		elif offset.length()>reach or (not offset.is_zero_approx() and offset.normalized().dot(direction)<cos(deg_to_rad(degrees/2))):continue
		if not clear_line(origin,enemy.global_position):continue
		var strike: Dictionary=attack.duplicate(true)
		if enemy.boss or enemy.mini_boss:strike.hit_stun_duration=0.0
		if weapon_id=="borderkeepers_spear" and strike.get("warrior_resource",false):
			strike.tip=forward>=reach*0.75
			if strike.tip:strike.damage=int(round(int(strike.damage)*1.35))
		if weapon_id=="duelists_paired_sabres" and strike.get("warrior_resource",false) and not exposure.is_empty() and int(exposure.get("id",0))==enemy.get_instance_id():
			strike.damage=int(round(int(strike.damage)*1.35));exposure.clear()
		if bool(strike.get("stagger",false)):
			if enemy.boss or enemy.mini_boss:strike.hit_stun_duration=0.0
			elif enemy.hit_stun_timer>0:strike.damage=int(round(int(strike.damage)*1.25));strike.hit_stun_duration=0.0
			else:strike.hit_stun_duration=0.15
		hit(enemy,strike,primary);count+=1;last_targets.append(weakref(enemy))
		if weapon_id=="banner_of_the_vanguard" and strike.get("warrior_resource",false) and primary and not banner.is_empty() and origin.distance_to(banner.center)<=BANNER_RADIUS:
			var added := minf(0.5,2-float(banner.added));banner.left+=added;banner.added+=added
	last_hits=count
	return count

func perform(slot: String, result: Dictionary) -> Dictionary:
	match slot:
		"basic":
			var attack := attack_for(slot,action_name(slot),true)
			match weapon_id:
				"headsmans_greatsword":
					pending.append({"origin":actor.global_position,"direction":actor.aim_direction,"left":0.0 if ready_hew>0 else 0.12,"reach":170.0,"degrees":155.0,"attack":attack,"line":false});ready_hew=0
				"borderkeepers_spear":result.targets_hit=slash(actor.global_position,actor.aim_direction,260,24,attack,true,true)
				"banner_of_the_vanguard":result.targets_hit=slash(actor.global_position,actor.aim_direction,135,110,attack)
				"duelists_paired_sabres":
					sabre_side=-sabre_side
					result.targets_hit=slash(actor.global_position+actor.aim_direction.orthogonal()*sabre_side*8,actor.aim_direction.rotated(sabre_side*0.12),125,145 if not exposure.is_empty() else 95,attack)
					if result.targets_hit==0:strokes.clear()
				"chain_of_the_siege_breaker":
					var target: SlasherEnemy;var distance := 301.0
					for enemy in enemies():
						var offset := enemy.global_position-actor.global_position
						if offset.dot(actor.aim_direction)>=0 and offset.dot(actor.aim_direction)<=300 and absf(offset.cross(actor.aim_direction))<=28 and offset.length()<distance and clear_line(actor.global_position,enemy.global_position):target=enemy;distance=offset.length()
					tether.clear()
					if target!=null:
						if target.boss or target.mini_boss:attack.hit_stun_duration=0.0
						hit(target,attack,true);tether={"enemy":weakref(target),"left":2.0};result.targets_hit=1
					history.append({"origin":actor.global_position,"direction":actor.aim_direction,"reach":300.0,"degrees":28.0,"line":true,"left":0.28,"duration":0.28})
		"special":
			var attack := attack_for(slot,action_name(slot))
			if not special_bonus.is_empty():attack.damage=int(round(int(attack.damage)*float(special_bonus.multiplier)));special_bonus.clear()
			match weapon_id:
				"headsmans_greatsword":
					attack.stagger=true;pending.append({"origin":actor.global_position,"direction":actor.aim_direction,"left":0.22,"reach":300.0,"degrees":42.0,"attack":attack,"line":true})
				"borderkeepers_spear":lane={"origin":actor.global_position,"direction":actor.aim_direction,"left":3.0,"arm":0.12,"reach":320.0,"width":32.0,"attack":attack}
				"banner_of_the_vanguard":
					clear_banner();banner={"center":aimed_point(250),"left":5.0,"added":0.0}
					slash(banner.center,actor.aim_direction,150,360,attack);flash(banner.center,150)
				"duelists_paired_sabres":
					attack.damage=maxi(1,int(round(int(attack.damage)*0.5)))
					pending.append({"origin":actor.global_position,"direction":actor.aim_direction.rotated(-0.25),"left":0.08,"reach":175.0,"degrees":85.0,"attack":attack,"line":false})
					pending.append({"origin":actor.global_position,"direction":actor.aim_direction.rotated(0.25),"left":0.16,"reach":175.0,"degrees":85.0,"attack":secondary_copy(attack),"line":false,"secondary":true})
				"chain_of_the_siege_breaker":
					var target := tether_target();var center := actor.global_position+actor.aim_direction*95
					if target!=null:
						if not target.boss and not target.mini_boss:target.move_and_collide((actor.global_position+actor.global_position.direction_to(target.global_position)*85-target.global_position).limit_length(180))
						center=target.global_position
					else:attack.damage=int(round(int(attack.damage)*0.75))
					last_slam_center=center
					slash(center,actor.aim_direction,100,360,attack);flash(center,100);tether.clear()
		"defensive":
			if weapon_id=="borderkeepers_spear":
				result=safe_move(actor.global_position-actor.aim_direction*110,result,0.1)
				if not result.started:return result
			guard_rewarded=false;guard_blocks=0;guard_left=0.7 if weapon_id=="chain_of_the_siege_breaker" else 0.6
			if weapon_id=="banner_of_the_vanguard":
				var allies := deployed_allies();var recipient: SlasherPlayer
				if not banner.is_empty() and actor.global_position.distance_to(banner.center)<=BANNER_RADIUS:
					var distance := INF
					for ally in allies:
						if ally!=actor and ally.global_position.distance_to(banner.center)<=BANNER_RADIUS and actor.global_position.distance_to(ally.global_position)<distance:recipient=ally;distance=actor.global_position.distance_to(ally.global_position)
				actor.kit_buffs.grant_ward(source_id(),maxi(1,int(round(actor.max_health*0.15))),3 if recipient==null else 2)
				if recipient!=null:recipient.kit_buffs.grant_ward(source_id(),maxi(1,int(round(recipient.max_health*0.15))),2);remember(recipient);flash(recipient.global_position,45)
				flash(actor.global_position,45)
			else:actor.defense_kind="warrior_kit";actor.defense_window=guard_left
		"movement":
			var destination := actor.global_position+actor.aim_direction*230
			match weapon_id:
				"headsmans_greatsword":destination=actor.global_position+actor.aim_direction*200
				"borderkeepers_spear","duelists_paired_sabres":
					var movement := Input.get_vector("slasher_left","slasher_right","slasher_up","slasher_down")
					var side := actor.aim_direction.orthogonal()
					if movement.dot(side)<-0.1:side=-side
					if weapon_id=="borderkeepers_spear" and movement.length()<0.1:side=-actor.aim_direction
					destination=actor.global_position+side*220
				"chain_of_the_siege_breaker":
					var target := tether_target()
					if target!=null:destination=target.global_position+target.global_position.direction_to(actor.global_position)*55
			result=safe_move(destination,result,0.15)
			if result.started:
				if weapon_id=="banner_of_the_vanguard" and not banner.is_empty():banner.center=actor.global_position
				if weapon_id=="chain_of_the_siege_breaker":tether.clear()
	return result

func deployed_allies() -> Array[SlasherPlayer]:
	var result: Array[SlasherPlayer]=[]
	for node in get_tree().get_nodes_in_group("slasher_player"):
		if node is SlasherPlayer and node.get_parent()==actor.get_parent() and node.health>0 and node.visible and node.can_process():result.append(node)
	return result
func remember(player: SlasherPlayer) -> void:
	for reference in recipients:if reference.get_ref()==player:return
	recipients.append(weakref(player))
func clear_banner() -> void:
	banner.clear()
	for reference in recipients:
		var player := reference.get_ref() as SlasherPlayer
		if is_instance_valid(player) and is_instance_valid(player.kit_buffs):player.kit_buffs.clear_source(source_id())
	recipients.clear()
func _exit_tree() -> void:clear_banner()
func tether_target() -> SlasherEnemy:
	if tether.is_empty():return null
	var enemy := (tether.enemy as WeakRef).get_ref() as SlasherEnemy
	if not is_instance_valid(enemy) or enemy.dead or not clear_line(actor.global_position,enemy.global_position):tether.clear();return null
	return enemy
func mitigation_for(attacker: Node2D, knockback: Vector2) -> float:
	var direction := actor.global_position.direction_to(attacker.global_position) if is_instance_valid(attacker) else -knockback.normalized()
	if actor._receiving_projectile and not knockback.is_zero_approx():direction=-knockback.normalized()
	if not direction.is_zero_approx() and direction.dot(actor.aim_direction)<0.3:return 0
	if weapon_id=="duelists_paired_sabres":return 1.0 if not actor._receiving_projectile and is_instance_valid(attacker) and actor.global_position.distance_to(attacker.global_position)<=130 else 0.5
	return 0.5 if weapon_id=="chain_of_the_siege_breaker" else 0.6
func prevention(attacker: Node2D) -> void:
	if not guard_rewarded:actor._award_resource(1);guard_rewarded=true
	if weapon_id=="headsmans_greatsword":ready_hew=2
	if weapon_id=="duelists_paired_sabres" and not actor._receiving_projectile and attacker is SlasherEnemy and actor.global_position.distance_to(attacker.global_position)<=130:exposure={"id":attacker.get_instance_id(),"left":2.0}
	flash(actor.global_position,55)

func _physics_process(delta: float) -> void:
	if actor.health<=0:pending.clear();lane.clear();tether.clear();clear_banner();return
	super(delta);ready_hew=maxf(0,ready_hew-delta);guard_left=maxf(0,guard_left-delta)
	for value in [strokes,exposure,special_bonus]:
		if not value.is_empty():value.left-=delta
		if not value.is_empty() and float(value.left)<=0:value.clear()
	for index in range(history.size()-1,-1,-1):
		history[index].left-=delta
		if float(history[index].left)<=0:history.remove_at(index)
	for index in range(pending.size()-1,-1,-1):
		var strike: Dictionary=pending[index];strike.left-=delta
		if float(strike.left)<=0:
			slash(strike.origin,strike.direction,strike.reach,strike.degrees,strike.attack,not bool(strike.get("secondary",false)),strike.line);pending.remove_at(index)
	if not lane.is_empty():
		lane.left-=delta;lane.arm-=delta
		if float(lane.left)<=0:lane.clear()
		elif float(lane.arm)<=0:
			var attack: Dictionary=Dictionary(lane.attack).duplicate(true);attack.stagger=true
			if slash(lane.origin,lane.direction,lane.reach,lane.width,attack,true,true,1)>0:lane.clear()
	if not tether.is_empty():
		tether.left-=delta
		if float(tether.left)<=0:tether.clear()
		else:tether_target()
	if weapon_id=="chain_of_the_siege_breaker" and guard_left>0:
		for shot in hostile_shots():
			if guard_blocks>=3:break
			var offset := shot.global_position-actor.global_position
			if offset.length()<=130 and (offset.is_zero_approx() or offset.normalized().dot(actor.aim_direction)>=0.3) and clear_line(actor.global_position,shot.global_position):shot._finish();guard_blocks+=1;prevention(null)
	if not banner.is_empty():
		banner.left-=delta
		if float(banner.left)<=0:clear_banner()
		else:
			for player in deployed_allies():
				if player.global_position.distance_to(banner.center)<=BANNER_RADIUS:player.kit_buffs.grant_speed(source_id(),1.15,0.08);remember(player)

func draw_swing(canvas: Node2D, strike: Dictionary, opacity: float) -> void:
	var tint := Color("#9de8ff") if int(strike.get("side",0))<0 else TINT
	var origin := to_local(strike.origin);var direction := Vector2(strike.direction);var reach := float(strike.reach)
	if strike.line:
		var side := direction.orthogonal()*float(strike.degrees)
		var polygon := PackedVector2Array([origin-side,origin+side,origin+direction*reach+side,origin+direction*reach-side])
		canvas.draw_colored_polygon(polygon,Color(1,0.65,0.25,opacity*0.2));canvas.draw_line(origin,origin+direction*reach,Color(tint,opacity),5)
		canvas.draw_polyline(PackedVector2Array([polygon[0],polygon[3],polygon[2],polygon[1]]),Color(tint,opacity),2)
		if weapon_id=="borderkeepers_spear":canvas.draw_line(origin+direction*reach*0.75,origin+direction*reach,Color(0.7,1,1,opacity),10)
	elif float(strike.degrees)>=359:
		canvas.draw_circle(origin,reach,Color(1,0.65,0.25,opacity*0.12));canvas.draw_arc(origin,reach,0,TAU,60,Color(tint,opacity),4)
	else:
		var points := PackedVector2Array([origin])
		for index in 20:points.append(origin+direction.rotated(deg_to_rad(-float(strike.degrees)/2+float(strike.degrees)*index/19))*reach)
		canvas.draw_colored_polygon(points,Color(1,0.65,0.25,opacity*0.15));canvas.draw_polyline(points,Color(tint,opacity),4)

func _draw() -> void:
	for effect in effects:
		var progress := 1-float(effect.left)/float(effect.duration)
		var point := to_local(effect.get("center",actor.global_position))
		var radius := float(effect.get("radius",30))*progress
		draw_arc(point,radius,0,TAU,40,Color(1,0.85,0.5,1-progress),4)
	for strike in pending:draw_swing(self,strike,0.65)
	if not lane.is_empty():draw_swing(self,{"origin":lane.origin,"direction":lane.direction,"reach":lane.reach,"degrees":lane.width,"line":true},0.8)
	if not banner.is_empty():
		var point := to_local(banner.center)
		draw_circle(point,BANNER_RADIUS,Color(1,0.7,0.15,0.1));draw_arc(point,BANNER_RADIUS,0,TAU,60,TINT,2)
		draw_line(point,point-Vector2(0,70),TINT,6)
		var cloth := PackedVector2Array([point-Vector2(0,70),point+Vector2(48+sin(clock*5)*5,-62),point+Vector2(40,-30),point-Vector2(0,38)])
		draw_colored_polygon(cloth,Color("#be384c"));draw_polyline(cloth,TINT,2)
		draw_arc(point,160,0,TAU*clampf(float(banner.left)/(5+float(banner.added)+(2 if banner.get("combo_extended",false) else 0)),0,1),48,TINT,3)

func draw_foreground(canvas: Node2D) -> void:
	for strike in history:draw_swing(canvas,strike,float(strike.left)/float(strike.duration))
	var enemy := tether_target()
	if enemy!=null:
		var point := to_local(enemy.global_position)
		canvas.draw_line(Vector2.ZERO,point,Color("#665851"),7);canvas.draw_line(Vector2.ZERO,point,TINT,2)
		canvas.draw_circle(point,12,Color("#a69981"));canvas.draw_arc(point,17,0,TAU,24,TINT,3)
	if guard_left>0:
		canvas.draw_arc(Vector2.ZERO,55,actor.aim_direction.angle()-1.15,actor.aim_direction.angle()+1.15,30,TINT,5)
	if not exposure.is_empty():
		var exposed := instance_from_id(int(exposure.id)) as SlasherEnemy
		if is_instance_valid(exposed) and not exposed.dead:canvas.draw_arc(to_local(exposed.global_position),35,0,TAU,32,Color("#9de8ff"),3)
	if ready_hew>0:canvas.draw_string(ThemeDB.fallback_font,Vector2(-45,-76),"READY HEW",HORIZONTAL_ALIGNMENT_CENTER,90,12,TINT)
