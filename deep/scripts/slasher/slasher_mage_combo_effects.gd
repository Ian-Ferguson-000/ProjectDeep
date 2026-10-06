extends "res://scripts/slasher/slasher_mage_kit_base.gd"

var school := "arcane"
var kit_name := "standard"
var fields: Array[Dictionary]=[]
var pending: Array[Dictionary]=[]
var barrier := 0
var barrier_left := 0.0
var barrier_shards := 0
var departure := Vector2.ZERO
var previous_mirror: Dictionary={}
var previous_recording: Dictionary={}
var last_result: Dictionary={}

func element() -> String:return school
func visual_element() -> String:return "gravity" if kit_name=="grimoire_of_gravity" else school
func kit_id() -> String:return "mage_combo"

func configure(player: SlasherPlayer, id: String) -> void:
	setup(player);kit_name=id;departure=actor.global_position
	match id:
		"tome_of_the_pyromancer":school="fire"
		"winterglass_codex":school="ice"
		"stormbringers_grimoire":school="lightning"

func capture() -> Dictionary:
	var result := {"origin":actor.global_position}
	if kit_name=="mirrorbound_manuscript":
		result.mirror=actor.mage_kit.mirror.duplicate(true);result.recording=actor.mage_kit.recording.duplicate(true)
	return result

func accept_action(slot: String, before: Dictionary) -> void:
	if slot=="movement":departure=before.origin
	previous_mirror=before.get("mirror",{});previous_recording=before.get("recording",{})

func damage(multiplier: float) -> int:
	# Combo payloads inherit the current Basic's numerical progression ratio.
	var baseline := GameBalance.get_slasher_ability_tuning("mage","basic")
	var progressed := actor.run_state.get_effective_slasher_ability_tuning("basic")
	return maxi(1,int(round(actor.spell_power*multiplier*float(progressed.damage_coefficient)/float(baseline.damage_coefficient))))

func bolt(origin: Vector2, direction: Vector2, multiplier: float, label: String, resolved_damage: int=0) -> void:
	var attack := secondary_damage(damage(multiplier),label)
	if resolved_damage>0:attack.damage=resolved_damage
	attack.merge({"mage_visual_kit":kit_name,"range":420.0,"speed":900.0,"hit_radius":24.0,"piercing":true,"visual":"fireball" if school=="fire" else "aether","visual_scale":0.9,"tint":VISUALS.color_for(visual_element()).to_html()})
	actor._spawn_projectile(attack,false,direction,origin);flash(origin,24)
	last_result.projectiles=int(last_result.get("projectiles",0))+1

func fan(origin: Vector2, count: int, spread: float, multiplier: float, label: String, aim: Vector2=Vector2.ZERO) -> void:
	var direction := actor.aim_direction if aim.is_zero_approx() else aim
	for index in count:bolt(origin,direction.rotated(deg_to_rad(-spread/2+spread*index/maxi(1,count-1))),multiplier,label)

func radial(origin: Vector2, count: int, multiplier: float, label: String) -> void:
	for index in count:bolt(origin,Vector2.RIGHT.rotated(TAU*index/count),multiplier,label)

func burst(origin: Vector2, radius: float, multiplier: float, label: String, slow: float=1.0, push: float=0.0) -> void:
	flash(origin,radius,"collapse" if visual_element()=="gravity" else "burst",0.55)
	for enemy in enemies():
		if origin.distance_to(enemy.global_position)>radius or not clear_line(origin,enemy.global_position):continue
		var attack := secondary_damage(damage(multiplier),label)
		attack.knockback=0.0
		hit(enemy,attack)
		if not enemy.dead and push>0 and not enemy.boss and not enemy.mini_boss:enemy.move_and_collide(origin.direction_to(enemy.global_position)*push)
		if not enemy.dead and not enemy.boss and not enemy.mini_boss and slow<1:
			enemy.movement_slow=minf(enemy.movement_slow,slow);enemy.status_time=maxf(enemy.status_time,0.5)
		last_result.hits=int(last_result.get("hits",0))+1
	last_result.bursts=int(last_result.get("bursts",0))+1

func field(origin: Vector2, radius: float, duration: float, multiplier: float, mode: String, label: String, finish: float=0.0) -> void:
	fields.append({"center":origin,"radius":radius,"left":duration,"duration":duration,"tick":0.0,"power":multiplier,"mode":mode,"label":label,"direction":actor.aim_direction,"finish":finish,"blocked":0})
	# Overlapping repeats replace oldest effects rather than accumulating forever.
	while fields.size()>8:fields.pop_front()
	last_result.fields=int(last_result.get("fields",0))+1

func ward(fraction: float, shards: int) -> void:
	barrier=maxi(1,int(round(actor.max_health*fraction)));barrier_left=3;barrier_shards=shards
	last_result.ward=barrier;flash(actor.global_position,50)

func absorb_damage(amount: int) -> int:
	var absorbed := mini(amount,barrier) if barrier_left>0 else 0
	barrier-=absorbed
	if absorbed>0 and barrier==0 and barrier_shards>0:
		radial(actor.global_position,barrier_shards,12,"Ward shards");barrier_shards=0
	return absorbed

func execute(recipe: Dictionary) -> void:
	var id: String=recipe.id;var label: String=recipe.name
	last_result={"id":id}
	var kit: Node=actor.mage_kit
	var here := actor.global_position
	match id:
		"arcane_crossfire":
			bolt(departure,actor.aim_direction.rotated(-0.25),15,label);bolt(here,actor.aim_direction.rotated(0.25),15,label)
		"repulsion_well":field(departure,120,2,5,"pull",label)
		"astral_bulwark":ward(0.25,6)
		"backdraft":
			for index in range(kit.trails.size()-1,-1,-1):kit.ignite_trail(index)
			var origins: Dictionary={}
			for patch in kit.patches:
				var key: String=str(patch.trail_id)
				if not origins.has(key):origins[key]=[]
				origins[key].append(patch.center)
			for points in origins.values():burst(points[int(points.size()/2)],90,20,label)
			if origins.is_empty():burst(here,90,20,label)
		"furnace_wake":
			kit.mantle_left=maxf(kit.mantle_left,1.5);kit.furnace_counter()
			for index in range(kit.trails.size()-1,-1,-1):kit.ignite_trail(index)
			last_result.kit_changes=true
		"wildfire_braid":fan(here,5,50,12,label)
		"flashover":
			var marked: Array=kit.burns.keys()
			for key in marked:
				if not kit.burns.has(key):continue
				var enemy := (kit.burns[key].enemy as WeakRef).get_ref() as SlasherEnemy
				if is_instance_valid(enemy) and not enemy.dead and here.distance_to(enemy.global_position)<=300 and clear_line(here,enemy.global_position):
					kit.burns.erase(key);burst(enemy.global_position,80,30,label)
			flash(here,300);last_result.kit_changes=true
		"ember_orbit":field(here,85,3,4,"follow",label)
		"ashen_return":field(departure,120,2,5,"slow",label)
		"whiteout":
			freeze(here);radial(here,8,12,label)
		"glacial_crosscut":
			for lane in [-1,0,1]:bolt(here+actor.aim_direction.orthogonal()*lane*55,actor.aim_direction,12,label)
		"cold_front":
			var origin := here
			if not kit.wall.is_empty():kit.wall.left=maxf(kit.wall.left,5);origin=kit.wall.center
			fan(origin,5,70,12,label)
		"icebreaker":
			for key in kit.chills.keys():
				var mark: Dictionary=kit.chills[key];var enemy := (mark.enemy as WeakRef).get_ref() as SlasherEnemy
				if is_instance_valid(enemy) and not enemy.dead and here.distance_to(enemy.global_position)<=300 and clear_line(here,enemy.global_position):
					kit.release_chill(key);burst(enemy.global_position,80,8*int(mark.stacks),label)
			flash(here,300);last_result.kit_changes=true
		"permafrost":freeze(departure);burst(departure,140,20,label)
		"diamond_guard":ward(0.25,8)
		"closed_circuit":
			var visited: Dictionary={}
			for a in kit.rods.size():
				for b in range(a+1,kit.rods.size()):
					var start: Vector2=kit.rods[a].center;var end: Vector2=kit.rods[b].center
					if not clear_line(start,end):continue
					arc(start,end)
					for enemy in enemies():
						if not visited.has(enemy.get_instance_id()) and Geometry2D.get_closest_point_to_segment(enemy.global_position,start,end).distance_to(enemy.global_position)<=24:
							visited[enemy.get_instance_id()]=true;hit(enemy,secondary_damage(damage(20),label));last_result.hits=int(last_result.get("hits",0))+1
			last_result.links=kit.rods.size()*(kit.rods.size()-1)/2
		"thunderstep":burst(here,130,20,label);radial(here,8,12,label)
		"overcharge":
			for rod in kit.rods:rod.charged=true;rod.pulse_bonus=2.0;rod.tick=0
			last_result.kit_changes=true
		"forked_horizon":
			for rod in kit.rods:
				var nearby := enemies();nearby.sort_custom(func(a: SlasherEnemy,b: SlasherEnemy):return a.global_position.distance_to(rod.center)<b.global_position.distance_to(rod.center))
				var count := 0
				for enemy in nearby:
					if count>=2:break
					if enemy.global_position.distance_to(rod.center)<=180 and clear_line(rod.center,enemy.global_position):hit(enemy,secondary_damage(damage(12),label));arc(rod.center,enemy.global_position);count+=1
			# A standalone pair still makes the combo useful before the first rod.
			if kit.rods.is_empty():fan(here,2,25,12,label)
			last_result.kit_changes=true
		"rolling_thunder":field(here,90,2,5,"travel",label)
		"storm_cage":burst(here,140,20,label,0)
		"orbital_slingshot":radial(here if kit.well.is_empty() else Vector2(kit.well.center),6,12,label)
		"event_horizon":field(aimed_point(300) if kit.well.is_empty() else Vector2(kit.well.center),170,2,5,"pull",label)
		"singularity_step":field(departure,140,1,0,"pull",label,25)
		"satellite_guard":field(here,95,2,0,"screen",label)
		"tidal_inversion":burst(here if kit.anchor.is_empty() else Vector2(kit.anchor.center),140,25,label,1,100)
		"return_trajectory":
			for index in 3:pending.append({"origin":departure,"direction":departure.direction_to(here),"left":index*0.12,"power":12,"label":label})
			last_result.scheduled=3
		"palimpsest":
			var origin := here if previous_mirror.is_empty() else Vector2(previous_mirror.center)
			var direction: Vector2=actor.aim_direction if previous_recording.is_empty() else Vector2(previous_recording.direction)
			var power: int=damage(6) if previous_recording.is_empty() else maxi(1,int(round(int(previous_recording.attack.damage)*0.5)))
			for angle in [-18,18]:bolt(origin,direction.rotated(deg_to_rad(angle)),6,label,power)
		"hall_of_mirrors":
			for side in [-1,1]:
				var origin := actor._safe_destination(departure+actor.aim_direction.orthogonal()*side*75)
				field(origin,30,0.5,0,"illusion",label);bolt(origin,actor.aim_direction,12,label)
		"silver_crossfire":
			var origin := here if kit.mirror.is_empty() else Vector2(kit.mirror.center)
			fan(origin,3,30,12,label,origin.direction_to(actor.get_global_mouse_position()))
		"blank_verdict":ward(0.2,0);bolt(here if kit.mirror.is_empty() else Vector2(kit.mirror.center),actor.aim_direction,25,label)
		"echo_passage":
			bolt(departure if previous_mirror.is_empty() else Vector2(previous_mirror.center),actor.aim_direction,15,label)
			bolt(departure,actor.aim_direction,15,label)
		"prismatic_chorus":fan(here if kit.mirror.is_empty() else Vector2(kit.mirror.center),4,60,10,label)

func freeze(origin: Vector2) -> void:
	actor.mage_kit.frozen_fields.append({"kind":"disk","a":origin,"radius":140.0,"left":5.0})
	last_result.terrain=true

func _physics_process(delta: float) -> void:
	super(delta)
	barrier_left=maxf(0,barrier_left-delta)
	if barrier_left<=0:barrier=0;barrier_shards=0
	for index in range(pending.size()-1,-1,-1):
		var shot: Dictionary=pending[index];shot.left-=delta
		if float(shot.left)<=0:bolt(shot.origin,shot.direction,shot.power,shot.label);pending.remove_at(index)
	for index in range(fields.size()-1,-1,-1):
		var zone: Dictionary=fields[index];zone.left-=delta;zone.tick-=delta
		if zone.mode in ["follow","screen"]:zone.center=actor.global_position
		if zone.mode=="travel":zone.center=actor._safe_destination(Vector2(zone.center)+Vector2(zone.direction)*160*delta)
		if zone.mode=="pull":
			for enemy in enemies():
				var offset := Vector2(zone.center)-enemy.global_position
				if not enemy.boss and not enemy.mini_boss and offset.length()<=float(zone.radius) and clear_line(enemy.global_position,zone.center):enemy.move_and_collide(offset.limit_length(180*delta))
		if zone.mode=="screen":
			for shot in hostile_shots():
				if int(zone.blocked)>=3:break
				if shot.global_position.distance_to(zone.center)<=float(zone.radius) and clear_line(zone.center,shot.global_position):
					shot._finish();zone.blocked+=1;bolt(zone.center,-shot.direction,12,zone.label)
		if float(zone.tick)<=0 and float(zone.power)>0:
			zone.tick+=0.4;burst(zone.center,zone.radius,zone.power,zone.label,0.6 if zone.mode=="slow" else 1.0)
		if float(zone.left)<=0:
			if float(zone.finish)>0:burst(zone.center,zone.radius,zone.finish,zone.label)
			fields.remove_at(index)

func _draw() -> void:
	super()
	for zone in fields:
		if zone.mode=="illusion":VISUALS.mirror(self,to_local(zone.center),clock,false,Vector2(zone.direction))
		else:VISUALS.sigil(self,to_local(zone.center),zone.radius,clock,VISUALS.color_for(visual_element()))
		if zone.mode=="screen":
			for index in 3:VISUALS.crystal(self,to_local(zone.center)+Vector2.RIGHT.rotated(clock*3+index*TAU/3)*float(zone.radius),10,VISUALS.color_for("gravity"))

func draw_foreground(canvas: Node2D) -> void:
	super(canvas)
	if barrier>0:
		canvas.draw_arc(Vector2.ZERO,49,0,TAU,48,VISUALS.color_for(visual_element()),3)
		canvas.draw_string(ThemeDB.fallback_font,Vector2(-45,-88),"COMBO WARD %d"%barrier,HORIZONTAL_ALIGNMENT_CENTER,90,12,Color.WHITE)
