extends "res://scripts/slasher/slasher_warrior_kit.gd"
var departure := Vector2.ZERO
var previous_banner: Dictionary={}
var previous_tether: Dictionary={}
var last_result: Dictionary={}
var combo_lane: Dictionary={}

func capture() -> Dictionary:
	var result := {"origin":actor.global_position}
	if is_instance_valid(actor.warrior_kit):
		result.banner=actor.warrior_kit.banner.duplicate(true)
		var target: SlasherEnemy=actor.warrior_kit.tether_target()
		if target!=null:result.tether={"point":target.global_position}
	return result
func accept_action(slot: String, before: Dictionary) -> void:
	if slot=="movement":departure=before.origin
	previous_banner=before.get("banner",{});previous_tether=before.get("tether",{})
func damage(power: float) -> int:
	var base := GameBalance.get_slasher_ability_tuning("warrior","basic")
	var current := actor.run_state.get_effective_slasher_ability_tuning("basic")
	return maxi(1,int(round(actor.attack_power*power*float(current.damage_coefficient)/float(base.damage_coefficient))))
func strike(origin: Vector2, direction: Vector2, reach: float, degrees: float, power: float, label: String, line: bool=false, stagger: bool=false, push: float=0.0, slow: float=1.0) -> void:
	var attack := secondary_damage(damage(power),label);attack.stagger=stagger
	var count := slash(origin,direction,reach,degrees,attack,false,line)
	for reference in last_targets:
		var enemy := reference.get_ref() as SlasherEnemy
		if is_instance_valid(enemy) and not enemy.dead and enemy.global_position.distance_to(origin)<=reach and clear_line(origin,enemy.global_position):
			if not enemy.boss and not enemy.mini_boss and slow<1:enemy.movement_slow=minf(enemy.movement_slow,slow);enemy.status_time=maxf(enemy.status_time,0.5)
			if not enemy.boss and not enemy.mini_boss and push>0:enemy.move_and_collide(origin.direction_to(enemy.global_position)*push)
	last_result.strikes=int(last_result.get("strikes",0))+1;last_result.hits=int(last_result.get("hits",0))+count
func ward(fraction: float, duration: float=3.0, share: bool=false, center: Vector2=Vector2.INF) -> void:
	actor.kit_buffs.grant_ward(source_id(),maxi(1,int(round(actor.max_health*fraction))),duration);remember(actor)
	if share:
		var best: SlasherPlayer;var distance := 151.0
		var point := actor.global_position if center==Vector2.INF else center
		for ally in deployed_allies():
			if ally!=actor and point.distance_to(ally.global_position)<distance:best=ally;distance=point.distance_to(ally.global_position)
		if best!=null:best.kit_buffs.grant_ward(source_id(),maxi(1,int(round(best.max_health*fraction))),duration);remember(best);flash(best.global_position,45)
	last_result.ward=true;flash(actor.global_position,45)
func schedule(origin: Vector2, direction: Vector2, reach: float, degrees: float, power: float, label: String, delay: float, line: bool=false) -> void:
	pending.append({"origin":origin,"direction":direction,"reach":reach,"degrees":degrees,"attack":secondary_damage(damage(power),label),"left":delay,"line":line,"secondary":true})
	last_result.scheduled=int(last_result.get("scheduled",0))+1
func execute(recipe: Dictionary) -> void:
	var id: String=recipe.id;var label: String=recipe.name;var here := actor.global_position;var aim := actor.aim_direction
	var kit: Node=actor.warrior_kit;last_result={"id":id}
	match id:
		"shield_drum":strike(here,aim,180,360,8,label,false,true)
		"marching_edge":strike(departure,aim,300,35,8,label,true)
		"red_sentence":
			for entry in kit.pending:
				if entry.attack.get("damage_source","")=="Sentence":entry.degrees=80;entry.attack.damage=int(round(int(entry.attack.damage)*1.6))
			last_result.kit_changes=true
		"quarry_breaker":
			for side in [-1,1]:strike(here+aim.orthogonal()*side*55,aim,260,35,7,label,true)
		"reaping_advance":strike(departure,aim,190,360,12,label)
		"iron_rebuttal":ward(0.25);strike(here,aim,180,150,6,label)
		"execution_wheel":strike(here,aim,220,360,12,label,false,true)
		"last_word":schedule(departure,aim,300,40,14,label,0.25,true)
		"crossing_points":
			for angle in [-15,15]:strike(here,aim.rotated(deg_to_rad(angle)),300,22,6,label,true)
		"long_watch":
			if not kit.lane.is_empty():kit.lane.reach=420;kit.lane.width=50;kit.lane.left=4
			last_result.kit_changes=true
		"second_rank":
			combo_lane={"origin":here+aim.orthogonal()*70,"direction":aim,"reach":320.0,"width":32.0,"left":3.0,"arm":0.12,"attack":secondary_damage(damage(10),label)};last_result.lane=true
		"mobile_redoubt":
			if not kit.lane.is_empty():kit.lane.origin=here;kit.lane.direction=aim;kit.lane.arm=0.12
			last_result.kit_changes=true
		"rearward_fence":strike(departure,aim,280,30,8,label,true,false,65)
		"needle_gate":
			for side in [-1,0,1]:strike(here+aim.orthogonal()*side*45,aim,300,22,6,label,true)
		"vanguard_crash":strike(here,aim,150,360,10,label);ward(0.15,2,true)
		"unbroken_standard":
			var point := here
			if not kit.banner.is_empty():
				point=kit.banner.center
				if not kit.banner.get("combo_extended",false):kit.banner.left+=2;kit.banner.combo_extended=true
			strike(point,aim,150,360,8,label)
		"captains_oath":ward(0.25,3,true,here if kit.banner.is_empty() else Vector2(kit.banner.center))
		"covering_colors":ward(0.25);strike(here,-aim,160,140,7,label)
		"rally_march":
			for ally in deployed_allies():
				if ally.global_position.distance_to(here)<=150:ally.kit_buffs.grant_speed(source_id(),1.25,2);remember(ally)
			strike(here,aim,130,360,7,label)
		"standard_relay":strike(here if previous_banner.is_empty() else Vector2(previous_banner.center),aim,150,360,12,label)
		"answered_challenge":
			for angle in [-20,20]:strike(here,aim.rotated(deg_to_rad(angle)),130,90,5,label)
		"steel_verdict":
			for angle in [-25,25]:strike(here,aim.rotated(deg_to_rad(angle)),180,22,8,label,true)
		"circling_blades":strike(departure,aim,170,140,8,label);strike(here,-aim,170,140,8,label)
		"duelists_resolve":ward(0.2);strike(here,aim,100,360,6,label,false,false,0,0.5)
		"phantom_flurry":
			for index in 3:schedule(departure,aim.rotated((index-1)*0.18),150,110,5,label,index*0.08)
		"perfect_measure":kit.special_bonus={"multiplier":1.5,"left":2.0};last_result.kit_changes=true;flash(here,60)
		"breach_run":
			var direction := departure.direction_to(here)
			strike(departure,aim if direction.is_zero_approx() else direction,maxf(100,departure.distance_to(here)),45,10,label,true)
		"wrecking_ball":strike(kit.last_slam_center,aim,150,360,12,label)
		"iron_net":
			for angle in [-30,0,30]:strike(here,aim.rotated(deg_to_rad(angle)),280,25,7,label,true)
		"anchor_crash":strike(here if previous_tether.is_empty() else Vector2(previous_tether.point),aim,120,360,10,label,false,false,0,0.5)
		"siege_wheel":strike(here,aim,180,360,12,label,false,false,90)
		"linked_weights":
			var target: SlasherEnemy=kit.tether_target();var origin := here if target==null else target.global_position;var visited: Dictionary={}
			if target!=null:visited[target.get_instance_id()]=true
			var candidates := enemies();candidates.sort_custom(func(a: SlasherEnemy,b: SlasherEnemy):return a.global_position.distance_to(origin)<b.global_position.distance_to(origin))
			var count := 0
			for enemy in candidates:
				if count>=2:break
				if not visited.has(enemy.get_instance_id()) and enemy.global_position.distance_to(origin)<=180 and clear_line(origin,enemy.global_position):
					visited[enemy.get_instance_id()]=true;hit(enemy,secondary_damage(damage(8),label));arc(origin,enemy.global_position);count+=1
			last_result.links=count;flash(origin,180)
func _physics_process(delta: float) -> void:
	super(delta)
	if not combo_lane.is_empty():
		combo_lane.left-=delta;combo_lane.arm-=delta
		if float(combo_lane.left)<=0:combo_lane.clear()
		elif float(combo_lane.arm)<=0:
			if slash(combo_lane.origin,combo_lane.direction,combo_lane.reach,combo_lane.width,combo_lane.attack,false,true,1)>0:combo_lane.clear()
func _draw() -> void:
	super()
	if not combo_lane.is_empty():draw_swing(self,{"origin":combo_lane.origin,"direction":combo_lane.direction,"reach":combo_lane.reach,"degrees":combo_lane.width,"line":true},0.8)
func draw_foreground(canvas: Node2D) -> void:
	super(canvas)
	for effect in effects:
		if effect.kind=="arc":
			var start := to_local(effect.a);var end := to_local(effect.b)
			canvas.draw_line(start,end,Color("#7d746b"),7);canvas.draw_line(start,end,TINT,2)
