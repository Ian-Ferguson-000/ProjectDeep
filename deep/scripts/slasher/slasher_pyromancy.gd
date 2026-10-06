extends Node2D

const GEAR_ID := "tome_of_the_pyromancer"
const ACTIONS := {"basic":"Ember Lance", "special":"Conflagration", "defensive":"Furnace Mantle", "movement":"Cinder Trail"}
const FIRE := preload("res://scripts/slasher/slasher_fire_visuals.gd")
const BLAST_DELAY := 0.28
const BURN_INTERVAL := 0.5
const PATCH_INTERVAL := 0.25
const TUNING := {
	"basic":{"cooldown":0.18,"resource_cost":0,"resource_gain":1,"power_stat":"spell_power","damage_coefficient":12.0,"projectile_range":360.0,"projectile_speed":800.0,"hit_radius":22.0,"piercing":true,"visual":"fireball","visual_scale":1.25,"animation_lock":0.12},
	"special":{"cooldown":0.9,"resource_cost":1,"power_stat":"spell_power","damage_coefficient":20.0,"animation_lock":0.15},
	"defensive":{"cooldown":0.6,"resource_cost":0,"effect_duration":0.6,"mitigation":0.6,"animation_lock":0.12},
	"movement":{"cooldown":0.65,"resource_cost":0,"movement_distance":300.0,"invulnerability":0.2,"animation_lock":0.1}
}
var actor: SlasherPlayer
var trails: Array[Dictionary] = []
var mantle_left := 0.0
const MANTLE_RADIUS := 130.0
var patches: Array[Dictionary] = []
var burns: Dictionary = {}
var detonations: Array[Dictionary] = []
var pulses: Array[Dictionary] = []
var cast_serial := 0
var trail_serial := 0
var rewarded_casts: Dictionary = {}
var visual_clock := 0.0

static func gear() -> GearData:
	return GearData.create(GEAR_ID,"Tome of the Pyromancer",3,false,0,"conflagration","Any fire ignites stacking Cinder Trails along their full paths. Conflagration ignites trails and consumes burning ground. Furnace Mantle burns all nearby enemies.","mage","furnace")

func setup(player: SlasherPlayer) -> void:
	actor = player

func tuning(slot: String) -> Dictionary:
	var result := Dictionary(TUNING.get(slot,{})).duplicate(true)
	if is_instance_valid(actor) and actor.run_state!=null:
		# Transfer numerical progression, never standard-kit mechanics such as Force Prism.
		var baseline := GameBalance.get_slasher_ability_tuning("mage",slot)
		var progressed := actor.run_state.get_effective_slasher_ability_tuning(slot)
		for key in ["damage_coefficient","cooldown"]:
			if result.has(key) and float(baseline.get(key,0.0))>0.0:
				result[key]=float(result[key])*float(progressed.get(key,baseline[key]))/float(baseline[key])
	return result

func perform(slot: String, result: Dictionary) -> Dictionary:
	match slot:
		"basic":
			cast_serial += 1
			var attack := actor._configured_attack(tuning(slot),"fire")
			attack["pyro_cast"] = cast_serial
			attack["pyro_burn"] = true
			attack["damage_source"] = "Lance"
			actor._spawn_projectile(attack,false)
		"special":
			var offset := actor.get_global_mouse_position()-actor.global_position
			if Input.get_vector("slasher_aim_left","slasher_aim_right","slasher_aim_up","slasher_aim_down").length()>0.2:
				offset = actor.aim_direction*240.0
			var center := actor._safe_destination(actor.global_position+offset.limit_length(240.0))
			var radius := 100.0
			var consumed := false
			for index in range(patches.size()-1,-1,-1):
				if center.distance_to(patches[index].center)<=radius+36.0:
					patches.remove_at(index)
					consumed = true
			if consumed: radius *= 1.2
			var blast := actor._configured_attack(tuning(slot),"fire")
			blast["damage_source"]="Blast"
			detonations.append({"center":center,"radius":radius,"left":BLAST_DELAY,"attack":blast})
		"defensive":
			actor.defense_kind = "furnace"
			actor.defense_window = float(tuning(slot).effect_duration)
			mantle_left = float(tuning(slot).effect_duration)
			furnace_counter()
		"movement":
			var start := actor.global_position
			var destination := actor._safe_destination(start+actor.aim_direction*float(tuning(slot).movement_distance))
			if start.distance_to(destination)<1.0:
				result.started = false
				result.failure = "Cinder Trail has no clear destination."
				return result
			actor.global_position = destination
			actor.invulnerable = maxf(actor.invulnerable,0.2)
			trail_serial+=1
			trails.append({"a":start,"b":destination,"left":4.0,"id":trail_serial})
			pulses.append({"center":start,"radius":42.0,"left":0.35,"duration":0.35})
			pulses.append({"center":destination,"radius":42.0,"left":0.35,"duration":0.35})
			result["invulnerability_granted"] = 0.2
	queue_redraw()
	return result

func on_direct_hit(target: Node2D, attack: Dictionary) -> void:
	if not bool(attack.get("pyro_burn",false)) or not (target is SlasherEnemy): return
	apply_burn(target as SlasherEnemy)
	var cast := int(attack.get("pyro_cast",-1))
	if not rewarded_casts.has(cast):
		rewarded_casts[cast] = 4.0
		actor._award_resource(1)
		actor.resource_changed.emit(actor.run_state.class_resource,actor.run_state.get_class_resource_max())

func apply_burn(enemy: SlasherEnemy) -> void:
	if enemy.dead: return
	var id := enemy.get_instance_id()
	var tick_left := float(Dictionary(burns.get(id,{})).get("tick",BURN_INTERVAL))
	# Refresh duration without restarting the next tick or adding potency.
	burns[id] = {"enemy":weakref(enemy),"left":4.0,"tick":tick_left,"damage":maxi(1,int(round(actor.spell_power*1.2)))}

func furnace_counter() -> void:
	if pulses.is_empty():pulses.append({"center":actor.global_position,"radius":MANTLE_RADIUS,"left":0.45,"duration":0.45})
	for node in get_tree().get_nodes_in_group("slasher_enemy"):
		if node is SlasherEnemy and actor.global_position.distance_to(node.global_position)<=MANTLE_RADIUS and actor.get_parent().is_ancestor_of(node):
			apply_burn(node)
	queue_redraw()

func ignite_trail(index: int = 0) -> void:
	if index<0 or index>=trails.size():return
	var trail: Dictionary=trails[index]
	# Overlapping flame tiles form continuous coverage; one trail ticks once per enemy.
	var count := maxi(1,int(ceil(Vector2(trail.a).distance_to(trail.b)/40.0)))
	for step in count+1:
		patches.append({"center":Vector2(trail.a).lerp(trail.b,float(step)/count),"left":2.0,"tick":0.0,"trail_id":trail.get("id",trail.a)})
	trails.remove_at(index)
	queue_redraw()

func ignite_at(center: Vector2, radius: float) -> void:
	for index in range(trails.size()-1,-1,-1):
		var trail: Dictionary=trails[index]
		if Geometry2D.get_closest_point_to_segment(center,trail.a,trail.b).distance_to(center)<=radius+18:
			ignite_trail(index)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor): queue_free(); return
	visual_clock+=delta
	mantle_left=maxf(0,mantle_left-delta)
	if mantle_left>0:
		furnace_counter()
		ignite_at(actor.global_position,MANTLE_RADIUS)
	for index in range(trails.size()-1,-1,-1):
		trails[index].left-=delta
		if float(trails[index].left)<=0:trails.remove_at(index)
	# Any fire projectile, impact, burning enemy, or burning floor can light a trail.
	for node in actor.get_parent().get_children():
		if node is SlasherProjectile and String(node.attack.get("damage_type",""))=="fire":
			var end: Vector2=node.global_position+node.direction*node.speed*delta if not node.impacted else node.global_position
			for index in range(trails.size()-1,-1,-1):
				var trail: Dictionary=trails[index]
				var closest := Geometry2D.get_closest_point_to_segment(node.global_position,trail.a,trail.b)
				if Geometry2D.segment_intersects_segment(node.global_position,end,trail.a,trail.b)!=null or (closest.distance_to(node.global_position)<=28 and (node.impacted or node.direction.dot(closest-node.global_position)>=0)):
					ignite_trail(index)
	for patch in patches.duplicate():ignite_at(patch.center,36)
	for burn in burns.values():
		var burning := (burn.enemy as WeakRef).get_ref() as SlasherEnemy
		if is_instance_valid(burning) and not burning.dead:ignite_at(burning.global_position,20)
	for id in rewarded_casts.keys():
		rewarded_casts[id] -= delta
		if float(rewarded_casts[id])<=0.0: rewarded_casts.erase(id)
	for id in burns.keys():
		var burn: Dictionary = burns[id]
		var enemy := (burn.enemy as WeakRef).get_ref() as SlasherEnemy
		if not is_instance_valid(enemy) or enemy.dead:
			burns.erase(id)
			continue
		burn.left -= delta
		burn.tick -= delta
		if float(burn.tick)<=0.0:
			burn.tick += BURN_INTERVAL
			# Secondary damage uses normal boss durability, never hit procs/resource.
			enemy.receive_attack({"damage":int(burn.damage),"damage_type":"fire","damage_source":"Burn","hit_stun_duration":0.0,"screen_shake_multiplier":0.0},actor)
		if float(burn.left)<=0.0: burns.erase(id)
	var ground_hits: Dictionary = {}
	for index in range(patches.size()-1,-1,-1):
		var patch: Dictionary = patches[index]
		patch.left -= delta
		patch.tick -= delta
		if float(patch.tick)<=0.0:
			patch.tick = PATCH_INTERVAL
			for node in get_tree().get_nodes_in_group("slasher_enemy"):
				if node is SlasherEnemy and not node.dead and actor.get_parent().is_ancestor_of(node) and node.global_position.distance_to(patch.center)<=36.0:
					var key := "%s:%s"%[patch.trail_id,node.get_instance_id()]
					if ground_hits.has(key):continue
					ground_hits[key]=true
					node.receive_attack({"damage":maxi(1,int(round(actor.spell_power*2.5))),"damage_type":"fire","damage_source":"Ground","hit_stun_duration":0.0,"screen_shake_multiplier":0.0},actor)
		if float(patch.left)<=0.0: patches.remove_at(index)
	for index in range(detonations.size()-1,-1,-1):
		var explosion: Dictionary = detonations[index]
		explosion.left -= delta
		if float(explosion.left)>0.0: continue
		ignite_at(explosion.center,float(explosion.radius))
		for node in get_tree().get_nodes_in_group("slasher_damageable"):
			if node is Node2D and node.has_method("receive_attack") and node.global_position.distance_to(explosion.center)<=float(explosion.radius):
				var attack: Dictionary = Dictionary(explosion.attack).duplicate(true)
				if burns.has(node.get_instance_id()):
					attack.damage = maxi(1,int(round(float(attack.damage)*1.3)))
					burns.erase(node.get_instance_id())
				node.call("receive_attack",attack,actor)
		pulses.append({"center":explosion.center,"radius":explosion.radius,"left":0.55,"duration":0.55})
		detonations.remove_at(index)
	for index in range(pulses.size()-1,-1,-1):
		pulses[index].left -= delta
		if float(pulses[index].left)<=0.0: pulses.remove_at(index)
	queue_redraw()

func _draw() -> void:
	if is_instance_valid(actor) and mantle_left>0.0:
		draw_circle(Vector2.ZERO,MANTLE_RADIUS,Color(1,0.35,0.05,0.18))
		draw_arc(Vector2.ZERO,MANTLE_RADIUS,0.0,TAU,48,Color("#ffe38c"),4.0)
		for index in 4:
			FIRE.flame(self,Vector2.RIGHT.rotated(visual_clock*3+index*PI/2)*MANTLE_RADIUS,0.8,visual_clock,index*2)
	for trail in trails:
		var start := to_local(trail.a)
		var end := to_local(trail.b)
		draw_line(start,end,Color("#21150e"),28.0)
		draw_line(start,end,Color(1,0.45,0.05,0.55),18.0)
		for index in 12:
			var point := start.lerp(end,float(index)/11.0)
			draw_circle(point,3.0+sin(visual_clock*8+index),Color("#ffca66"))
			FIRE.embers(self,point,5.0,visual_clock+index*0.2,2,0.6)
	for patch in patches:
		var center := to_local(patch.center)
		draw_circle(center,36.0,Color(1,0.3,0.03,0.35))
		draw_texture_rect(FIRE.GROUND,Rect2(center-Vector2(40,38),Vector2(80,76)),false)
		draw_arc(center,36.0,0.0,TAU,32,Color("#ffc36a"),2.0)
		for index in 4:
			FIRE.flame(self,center+Vector2((index-1.5)*16,-10+sin(index*2)*9),0.9,visual_clock,index*2)
		FIRE.embers(self,center,30.0,visual_clock)
	for explosion in detonations:
		var center := to_local(explosion.center)
		var radius := float(explosion.radius)
		var progress := clampf(1.0-float(explosion.left)/BLAST_DELAY,0,1)
		draw_circle(center,radius,Color(1,0.22,0.02,0.15+progress*0.2))
		draw_arc(center,radius,0.0,TAU,48,Color("#ff9442"),3.0)
		draw_arc(center,radius,0.0,TAU*progress,48,Color("#fff2b1"),6.0)
		for index in 8:
			var direction := Vector2.RIGHT.rotated(index*PI/4)
			draw_line(center+direction*radius*0.3,center+direction*radius*0.85,Color(1,0.65,0.12,0.8),2.0)
			FIRE.flame(self,center+direction*radius*0.6,0.5+progress,visual_clock,index)
	for pulse in pulses:
		FIRE.explosion(self,to_local(pulse.center),float(pulse.radius),clampf(1.0-float(pulse.left)/float(pulse.get("duration",0.55)),0,1))
	for burn in burns.values():
		var enemy := (burn.enemy as WeakRef).get_ref() as SlasherEnemy
		if is_instance_valid(enemy):
			var point := to_local(enemy.global_position)
			FIRE.flame(self,point+Vector2(-14,-20),0.75,visual_clock,1)
			FIRE.flame(self,point+Vector2(12,-27),0.9,visual_clock,5)
			FIRE.embers(self,point,18.0,visual_clock)
