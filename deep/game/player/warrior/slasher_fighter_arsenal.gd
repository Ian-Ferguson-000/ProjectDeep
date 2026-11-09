extends "res://game/player/warrior/slasher_warrior_kit.gd"

const MINI_BEAST := preload("res://game/enemies/corrupted_mini_beast.gd")
const WEAPON_IDS := ["eldritch_bowstaff","demon_blade","storm_trident","valkyrian_sling","dragonbone_dagger","archon_crossbow","divine_hammer","grim_reaver","sentinel_shield","umbral_bow"]
const PURPLE := Color("#a956d8")
const STORM := Color("#75dcff")
const GOLD := Color("#ffe28a")
const SHADOW := Color("#69518f")
static var next_carry_source:int=-1000000

var curses: Dictionary={}
var wounds: Dictionary={}
var pins: Dictionary={}
var leashes: Dictionary={}
var missiles: Array[Dictionary]=[]
var frenzy_left:float:
	get:return actor.fighter_frenzy_left if is_instance_valid(actor) and weapon_id=="demon_blade" else 0.0
var rampage_left:=0.0
var rampage_stacks:=0
var trident: Dictionary={}
var sling_damage_stacks:=0
var last_proc_count:=0
var spawned_beasts:=0
var repeat_smashes:=0
var visual_clock:=0.0
var rules: Dictionary={}
var resolved_strikes: Dictionary={}
var resolving_curse: Dictionary={}
var hammer_chain:Dictionary={}
var shield_bash:Dictionary={}
var impact_recovery:Dictionary={}
var swing:Dictionary={}
var ranged_attack:Dictionary={}
var target_cache:Array[WeakRef]=[]
var part_cache:Array[WeakRef]=[]
var target_cache_left:=0.0
var trident_preview:=Vector2.ZERO
var missile_pool:Array[Dictionary]=[]
var effect_pool:Array[Dictionary]=[]

func _append_missile(data:Dictionary)->void:
	var record:Dictionary=missile_pool.pop_back() if not missile_pool.is_empty() else {}
	record.clear();record.merge(data);missiles.append(record)

func _retire_missile(index:int)->void:
	var record:=missiles[index]
	_release_carried(record);missiles.remove_at(index)
	if missile_pool.size()<8:missile_pool.append(record)

func _append_effect(data:Dictionary)->void:
	var record:Dictionary
	if effects.size()>=32:record=effects.pop_front()
	elif not effect_pool.is_empty():record=effect_pool.pop_back()
	else:record={}
	record.clear();record.merge(data);effects.append(record)
	queue_redraw()
	if is_instance_valid(foreground):foreground.queue_redraw()

func flash(center:Vector2,radius:float,kind:String="burst",duration:float=0.4)->void:
	_append_effect({"kind":kind,"center":center,"radius":radius,"left":duration,"duration":duration})

func arc(start:Vector2,end:Vector2)->void:
	_append_effect({"kind":"arc","a":start,"b":end,"left":0.2,"duration":0.2})

func _ready()->void:
	_refresh_target_cache()
	get_tree().node_added.connect(_observe_target)

func _observe_target(node:Node)->void:
	if node is SlasherEnemy and is_instance_valid(actor) and actor.get_parent().is_ancestor_of(node):target_cache.append(weakref(node))
	if node is SlasherColossusWeakPoint and is_instance_valid(actor) and actor.get_parent().is_ancestor_of(node):part_cache.append(weakref(node))

func _refresh_target_cache()->void:
	target_cache.clear();part_cache.clear();target_cache_left=0.1
	for node in get_tree().get_nodes_in_group("slasher_enemy"):
		if node is SlasherEnemy and not node.dead and actor.get_parent().is_ancestor_of(node):target_cache.append(weakref(node))
		elif node is SlasherColossusWeakPoint and actor.get_parent().is_ancestor_of(node):part_cache.append(weakref(node))

func _combat_body(target:Node2D)->SlasherEnemy:
	if not is_instance_valid(target):return null
	return target.colossus if target is SlasherColossusWeakPoint else target as SlasherEnemy

func _combat_id(target:Node2D)->int:
	var body:=_combat_body(target)
	return body.get_instance_id() if is_instance_valid(body) else 0

func _valid_combat_target(target:Node2D)->bool:
	var body:=_combat_body(target)
	return is_instance_valid(body) and not body.dead and (not target is SlasherColossusWeakPoint or target.open)

func combat_targets()->Array[Node2D]:
	var result:Array[Node2D]=[]
	for enemy in enemies():result.append(enemy)
	for reference in part_cache:
		var part:Node2D=reference.get_ref()
		if _valid_combat_target(part):result.append(part)
	return result

func enemies()->Array[SlasherEnemy]:
	var result:Array[SlasherEnemy]=[]
	for reference in target_cache:
		var enemy:SlasherEnemy=reference.get_ref()
		if is_instance_valid(enemy) and not enemy.dead and enemy.is_in_group("slasher_enemy"):result.append(enemy)
	return result

func configure(player: SlasherPlayer, id: String, names: Dictionary) -> void:
	super(player,id,names)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/fighter_active_items.json"))
	rules=Dictionary(data.get("_shared",{})).duplicate(true)
	rules.merge(Dictionary(data.get(id,{})).duplicate(true),true)

func rule(key:String,fallback:float)->float:
	return float(rules.get(key,fallback))

func presentation_animation_state()->String:
	# Clean follow-through poses omit the generic special's baked-in white
	# crescent. This runtime alone supplies weapon contact silhouettes.
	return "slash"

func presentation_action_duration(fallback:float)->float:
	if not swing.is_empty():return float(swing.duration)
	if not ranged_attack.is_empty():return float(ranged_attack.duration)
	if not hammer_chain.is_empty():return float(hammer_chain.duration)
	if not shield_bash.is_empty():return float(shield_bash.duration)
	if not trident.is_empty() and trident.state=="aiming":return float(trident.left)
	return fallback

func on_unequipped()->void:
	impact_recovery.clear()
	# Keep world-owned curses and a thrown trident alive, but cancel attacks
	# which have not committed and release carried enemies immediately.
	ranged_attack.clear();hammer_chain.clear();shield_bash.clear();swing.clear()
	if not trident.is_empty() and trident.state=="aiming":trident.clear()
	for index in range(missiles.size()-1,-1,-1):
		if missiles[index].kind=="trident":continue
		_retire_missile(index)
	_clear_leashes()
	queue_redraw()
	if is_instance_valid(foreground):foreground.queue_redraw()

func tuning(slot: String) -> Dictionary:
	var result:=super(slot)
	var actions:Dictionary=rules.get("actions",{})
	var authored:Dictionary=actions.get(slot,{})
	var base:=GameBalance.get_slasher_ability_tuning("warrior",slot)
	var progressed:=actor.run_state.get_effective_slasher_ability_tuning(slot)
	for key in authored:
		result[key]=authored[key]
		if key in ["damage_coefficient","cooldown"] and float(base.get(key,0))>0:
			result[key]=float(authored[key])*float(progressed.get(key,base[key]))/float(base[key])
	return result

func attack_for(slot: String, source: String, resource_hit: bool=false) -> Dictionary:
	var attack:=super(slot,source,resource_hit)
	attack.damage_source=weapon_id
	return attack

func critical_chance()->float:
	return clampf(rule("base_critical",0.28)+rule("critical_per_stack",0.1)*rampage_stacks,0,rule("critical_cap",0.88))

func modify_incoming_damage(amount: int) -> int:
	return amount # Player-owned frenzy resolves once, after mitigation.

## Lets ordinary class attacks interact with an active weapon's persistent
## battlefield state (pins, opened armor and Reaver rampage).
func adjust_external_attack(_target:Node2D,attack:Dictionary)->Dictionary:
	# Armor and storm vulnerability resolve once on the recipient, including
	# hits from other players, summons, spells, and damage-over-time sources.
	return attack

func on_external_hit(target:SlasherEnemy,attack:Dictionary,was_dead:bool)->void:
	if String(attack.get("warrior_kit",""))==weapon_id or was_dead:return
	# Death attribution belongs to the curse's defeated subscription, not to
	# whichever weapon happens to observe a player's outgoing damage.

func can_active_parry()->bool:
	if weapon_id!="valkyrian_sling":return false
	for missile in missiles:
		if _sling_parry_available(missile):return true
	return false

func _sling_parry_available(missile:Dictionary)->bool:
	return missile.kind=="sling" and missile.returning and int(missile.damage_stacks)<int(rule("parry_cap",6)) and float(missile.get("parry_left",-1))!=0 and Vector2(missile.position).distance_to(actor.global_position)<=rule("parry_radius",105)

func hit(target: Node2D, attack: Dictionary, primary: bool=false) -> int:
	if not _valid_combat_target(target):return 0
	var strike:=attack.duplicate(true)
	var body:Node2D=target.colossus if target is SlasherColossusWeakPoint else target
	var id:=body.get_instance_id() if is_instance_valid(body) else 0
	var token:="%s:%s"%[str(attack.get("warrior_cast",-1)),str(id)]
	if primary and attack.has("warrior_cast"):
		if resolved_strikes.has(token):return 0
		resolved_strikes[token]=16.0
	if weapon_id=="grim_reaver":
		# Roll at each distinct contact, never once for the entire sweep.
		strike.critical=randf()<critical_chance()
		if strike.critical:strike.damage=maxi(1,int(round(int(strike.damage)*rule("critical_damage",1.75))))
	if bool(strike.get("critical",false)):strike.impact_sound="fighter_critical"
	elif weapon_id in ["sentinel_shield","archon_crossbow"]:strike.impact_sound="fighter_metal"
	if weapon_id=="sentinel_shield" and target is SlasherEnemy and (target.boss or target.mini_boss or target.is_storm_pinned() or target.displacement_multiplier()<0.5):strike.impact_sound="fighter_resisted"
	# Suppress conversion until this strike has contributed its own stack.
	if primary and weapon_id=="eldritch_bowstaff":resolving_curse[id]=true
	var dealt:=super(target,strike,false)
	if dealt>0 and bool(strike.get("critical",false)):flash(target.global_position,26,"critical",0.2)
	if dealt>0 and weapon_id=="sentinel_shield" and target is SlasherEnemy and not target.dead:
		var resistance:float=target.displacement_multiplier()
		if target.is_storm_pinned():resistance=0
		if target.boss or target.mini_boss:resistance*=rule("heavy_displacement_multiplier",0.15)
		var direction:=actor.global_position.direction_to(target.global_position)
		if direction.is_zero_approx():direction=actor.aim_direction
		var shove_origin:=target.global_position
		target.move_and_collide(direction*float(strike.get("shield_shove",rule("shove",280)))*resistance)
		_append_effect({"kind":"shield_shove","center":shove_origin,"endpoint":target.global_position,"radius":0.0,"resisted":resistance<0.5,"left":0.25,"duration":0.25})
	if primary and dealt>0:
		on_direct_hit(target,strike)
		if target is SlasherEnemy:actor.on_item_enemy_hit(target,strike,false)
	resolving_curse.erase(id)
	return dealt

func on_direct_hit(target: Node2D, attack: Dictionary) -> void:
	super(target,attack)
	var enemy:SlasherEnemy=target.colossus if target is SlasherColossusWeakPoint else target as SlasherEnemy
	if not is_instance_valid(enemy):return
	var id:=enemy.get_instance_id()
	match weapon_id:
		"eldritch_bowstaff":
			var stacks:=mini(int(rule("curse_cap",6)),int(curses.get(id,{}).get("stacks",0))+1)
			curses[id]={"target":weakref(enemy),"stacks":stacks,"left":rule("curse_duration",8)}
			flash(enemy.global_position,18,"curse_glyph",0.24)
			if not enemy.defeated.is_connected(_on_cursed_death):enemy.defeated.connect(_on_cursed_death)
			if enemy.dead:_resolve_curse(enemy)
		"demon_blade":
			actor.activate_fighter_frenzy(rule("frenzy_duration",4),rule("damage_multiplier",1.45),rule("haste_multiplier",1.45),rule("incoming_multiplier",2))
		"dragonbone_dagger":
			enemy.apply_dragonbone_wound(rule("duration",4),int(rule("stack_cap",6)),rule("armor_per_stack",12),rule("armor_floor",-60))
			flash(enemy.global_position+Vector2(0,-20),14,"dagger_puncture",0.16)
			wounds[id]={"target":weakref(enemy),"stacks":enemy.dragonbone_wounds.stacks,"left":rule("duration",4)}
		"grim_reaver":
			if enemy.dead:
				if rampage_left<=0:flash(actor.global_position,40,"rampage_start",0.5)
				rampage_stacks=mini(int(rule("stack_cap",6)),rampage_stacks+1);rampage_left=rule("duration",6)

func _spawn_corrupted(origin: Vector2, count: int) -> void:
	var available:=maxi(0,int(rule("summon_cap",24))-get_tree().get_nodes_in_group("corrupted_mini_beast").size())
	var requested:=mini(count,available)
	last_proc_count=0
	for index in requested:
		var desired:=origin+Vector2.RIGHT.rotated(TAU*float(index)/maxf(1.0,float(count)))*18.0
		var spawn_point:Variant=_corrupted_spawn_point(origin,desired)
		if spawn_point==null:continue
		var beast:CorruptedMiniBeast
		for candidate in get_tree().get_nodes_in_group("corrupted_mini_beast_pool"):
			if candidate is CorruptedMiniBeast and not candidate.active and candidate.get_parent()==actor.get_parent():beast=candidate;break
		if beast==null:
			beast=MINI_BEAST.new();beast.pooled=true
			actor.get_parent().add_child(beast);beast.add_to_group("corrupted_mini_beast_pool")
		beast.setup(actor,spawn_point,index)
		beast.lifetime=rule("summon_lifetime",12)
		beast.emergence_duration=rule("summon_emergence",0.18)
		beast.windup_duration=rule("summon_windup",0.12)
		beast.dissolve_duration=rule("summon_dissolve",0.4)
		beast.damage_coefficient=rule("summon_damage_coefficient",0.45)
		beast.attack_interval=rule("summon_attack_interval",0.7)
		beast.move_speed=rule("summon_speed",190)
		beast.search_range=maxf(0,rule("summon_search_range",600))
		beast.search_interval=maxf(0.01,rule("summon_search_interval",0.2))
		beast.attack_range=maxf(0,rule("summon_attack_range",48))
		beast.engage_range=maxf(0,rule("summon_engage_range",42))
		beast.add_to_group("corrupted_mini_beast");spawned_beasts+=1;last_proc_count+=1
	if count>last_proc_count:flash(origin,24+count*3,"curse_overflow",0.65)
	_append_effect({"kind":"curse_conversion","center":origin,"radius":35+count*4,"left":0.5,"duration":0.5,"count":last_proc_count})

func _corrupted_spawn_point(origin:Vector2,desired:Vector2)->Variant:
	if not origin.is_finite() or not desired.is_finite():return null
	# Search locally around the corpse, not along a ray from the player.
	# The full beast footprint must fit before a pooled collider is enabled.
	var footprint:=CircleShape2D.new();footprint.radius=8
	var query:=PhysicsShapeQueryParameters2D.new();query.shape=footprint;query.collision_mask=1
	query.exclude=[actor.get_rid()]
	var candidates:Array[Vector2]=[desired,origin]
	for ring in [16.0,32.0,48.0]:
		for i in 8:candidates.append(origin+Vector2.from_angle(i*TAU/8)*ring)
	for point in candidates:
		if actor.position_sanitizer.is_valid():
			var sanitized:Variant=actor.position_sanitizer.call(point)
			if not sanitized is Vector2 or not sanitized.is_finite():continue
			point=sanitized
		if point.distance_to(origin)>64 or not _solid_intersection(origin,point).is_empty():continue
		if is_instance_valid(actor.pathfinder) and not actor.pathfinder.cells.is_empty():
			var cell:=actor.pathfinder.world_to_cell(point)
			if not actor.pathfinder.is_walkable_cell(cell):continue
			var start:=actor.pathfinder.nearest_walkable_cell(actor.pathfinder.world_to_cell(actor.global_position))
			if actor.pathfinder.find_cell_path(start,cell).is_empty():continue
		query.transform=Transform2D(0,point)
		var overlaps:=get_world_2d().direct_space_state.intersect_shape(query,128)
		if overlaps.size()>=128:continue
		var blocked:=false
		for overlap in overlaps:
			if overlap.collider is StaticBody2D:blocked=true;break
		if not blocked:return point
	return null

func _on_cursed_death(enemy:SlasherEnemy,_reward:int)->void:
	if not resolving_curse.has(enemy.get_instance_id()):_resolve_curse(enemy)

func _resolve_curse(enemy:SlasherEnemy)->void:
	var id:=enemy.get_instance_id()
	if not curses.has(id):return
	var count:=int(curses[id].stacks)
	_remove_curse(id) # Remove before spawning: callbacks cannot resolve twice.
	if is_instance_valid(actor) and actor.health>0:_spawn_corrupted(enemy.global_position,count)

func _remove_curse(id:int)->void:
	if not curses.has(id):return
	var enemy:SlasherEnemy=(curses[id].target as WeakRef).get_ref()
	if is_instance_valid(enemy) and enemy.defeated.is_connected(_on_cursed_death):enemy.defeated.disconnect(_on_cursed_death)
	curses.erase(id)

func _clear_curses()->void:
	for id in curses.keys():_remove_curse(id)

func _tick_curses(delta:float)->void:
	for id in curses.keys():
		curses[id].left-=delta
		var enemy:SlasherEnemy=(curses[id].target as WeakRef).get_ref()
		if float(curses[id].left)<=0 or not is_instance_valid(enemy) or enemy.dead:_remove_curse(id)

func _hammer_target(initial:bool=false)->Node2D:
	var nearest:Node2D;var best:=rule("chain_range",190)*rule("chain_range",190)
	for enemy in combat_targets():
		if initial and not SlasherHitGeometry.overlaps_sector(actor.global_position,actor.aim_direction,rule("contact_reach",145),rule("initial_arc",160),enemy):continue
		var distance:=actor.global_position.distance_squared_to(enemy.global_position)
		if distance<best and _solid_intersection(actor.global_position,enemy.global_position).is_empty():best=distance;nearest=enemy
	return nearest

func _queue_hammer(attack:Dictionary,depth:int,target:Node2D)->void:
	impact_recovery.clear()
	cast_serial=maxi(cast_serial,int(attack.get("warrior_cast",0)))
	var duration:=rule("repeat_windup",0.12) if depth>0 else rule("windup",0.18)
	var haste_scale:=actor.effective_attack_interval("basic",0.3)/0.3
	duration*=maxf(0.1,haste_scale)
	var point:=target.global_position if is_instance_valid(target) else actor.global_position+actor.aim_direction*rule("empty_impact_distance",75)
	var obstruction:=_solid_intersection(actor.global_position,point)
	if not obstruction.is_empty():point=Vector2(obstruction.position)-actor.global_position.direction_to(point)*2.0
	hammer_chain={"attack":attack.duplicate(true),"depth":depth,"target":weakref(target) if is_instance_valid(target) else null,"point":point,"left":duration,"duration":duration}
	if depth>0:
		actor.aim_direction=actor.global_position.direction_to(point)
		actor.facing_name=SlasherSpriteLibrary.direction_name(actor.aim_direction,actor.facing_name)
		actor._play_action_animation(presentation_animation_state(),duration,duration)
		actor.animation_lock=duration

func _tick_hammer(delta:float)->void:
	if hammer_chain.is_empty():return
	var state:=hammer_chain
	var target:Node2D=state.target.get_ref() as Node2D if state.target!=null else null
	var allowed_range:=rule("chain_range",190) if int(state.depth)>0 else rule("contact_reach",145)
	if not _valid_combat_target(target) or actor.global_position.distance_to(target.global_position)>allowed_range or not _solid_intersection(actor.global_position,target.global_position).is_empty():
		target=_hammer_target(int(state.depth)==0)
		state.target=weakref(target) if is_instance_valid(target) else null
	if int(state.depth)>0 and not is_instance_valid(target):hammer_chain.clear();actor.cooldowns.basic=0;return
	if is_instance_valid(target):
		actor.retarget_action_facing(actor.global_position.direction_to(target.global_position))
		if int(state.depth)>0:
			var offset:=target.global_position-actor.global_position
			# Traverse the same bounded lunge over the authored windup at every
			# haste level; a faster animation must not lose its reachable target.
			var elapsed:=minf(delta,maxf(0,float(state.left)))
			var travel:=rule("chain_lunge",105)*elapsed/maxf(0.001,float(state.duration))
			actor.move_and_collide(offset.normalized()*minf(maxf(0,offset.length()-rule("chain_stop_distance",85)),travel))
		state.point=target.global_position
	else:
		state.point=actor.global_position+actor.aim_direction*rule("empty_impact_distance",75)
	var obstruction:=_solid_intersection(actor.global_position,Vector2(state.point))
	if not obstruction.is_empty():state.point=Vector2(obstruction.position)-actor.global_position.direction_to(Vector2(state.point))*2.0
	state.left-=delta
	if float(state.left)>0:return
	hammer_chain={}
	if is_instance_valid(target) and actor.global_position.distance_to(target.global_position)>rule("contact_reach",145):return
	_hammer_impact(target,Vector2(state.point),state.attack,int(state.depth))

func _hammer_impact(primary:Node2D,point:Vector2,attack:Dictionary,depth:int)->void:
	_start_impact_recovery(point)
	impact_recovery.depth=depth
	var killed:=false
	var harvest_point:=point
	var struck:Dictionary={}
	if is_instance_valid(primary) and not primary.dead:
		if hit(primary,attack,true)>0:killed=primary.dead;struck[_combat_id(primary)]=true
	# Direct target is explicitly excluded from splash: one damage award per body.
	for enemy in combat_targets():
		if struck.has(_combat_id(enemy)) or not SlasherHitGeometry.overlaps_circle(point,rule("splash_radius",105),enemy):continue
		if not _solid_intersection(point,enemy.global_position).is_empty():continue
		var splash:=secondary_copy(attack)
		splash.damage=maxi(1,roundi(int(attack.damage)*rule("splash_multiplier",0.45)))
		splash.damage_type="aether";splash.damage_source="Radiant Splash"
		if hit(enemy,splash,false)>0:
			struck[_combat_id(enemy)]=true
			if enemy.dead:
				if not killed:harvest_point=enemy.global_position
				killed=true
	flash(point,rule("splash_radius",105),"burst",0.3)
	if not killed:return
	_append_effect({"kind":"hammer_return","center":harvest_point,"radius":0.0,"left":0.2,"duration":0.2})
	actor.cooldowns.basic=0
	if depth>=int(rule("chain_cap",8)):return
	var next:=_hammer_target()
	if next==null:return
	var follow:=attack.duplicate(true);cast_serial=maxi(cast_serial,int(attack.get("warrior_cast",0)))+1;follow.warrior_cast=cast_serial
	follow.damage_type="aether";follow.damage_source="Divine Repeat"
	repeat_smashes+=1
	_queue_hammer(follow,depth+1,next)

func perform(slot: String, result: Dictionary) -> Dictionary:
	# Recovery is a visible settle, not an extra cooldown: a kill-refreshed
	# hammer may immediately begin its next windup.
	impact_recovery.clear()
	if slot in ["defensive","movement"]:ranged_attack.clear()
	if slot in ["basic","special"] and not ranged_attack.is_empty():
		result.started=false;result.failure="Weapon recovering.";return result
	if weapon_id=="valkyrian_sling" and slot in ["basic","special"]:
		for missile in missiles:
			if missile.kind=="sling":result.started=false;result.failure="Catch or parry the returning shot.";return result
	if slot in ["defensive","movement"]:hammer_chain.clear();shield_bash.clear();swing.clear()
	if not swing.is_empty() and slot in ["basic","special"]:
		result.started=false;result.failure="Attack recovering.";return result
	if not shield_bash.is_empty() and slot in ["basic","special"]:
		result.started=false;result.failure="Shield bash in progress.";return result
	if weapon_id=="divine_hammer" and not hammer_chain.is_empty() and slot in ["basic","special"]:
		result.started=false;result.failure="Hammer smash in progress.";return result
	if slot=="defensive" and weapon_id=="valkyrian_sling":
		for missile in missiles:
			if _sling_parry_available(missile):
				AudioCue.play_from(actor,"fighter_metal")
				sling_damage_stacks+=1;missile.damage_stacks=sling_damage_stacks;missile.returning=false;missile.hit_ids={};missile.bounces=0;missile.remaining=rule("range",560)
				missile.parry_left=-1.0;missile.target=null
				cast_serial=maxi(cast_serial,int(missile.attack.get("warrior_cast",0)))+1;missile.attack.warrior_cast=cast_serial
				missile.direction=actor.aim_direction;flash(Vector2(missile.position),48,"burst",0.3);result.projectiles_deflected=1;return result
	if slot in ["defensive","movement"]:return super(slot,result)
	var attack:=attack_for(slot,action_name(slot),slot=="basic")
	if slot=="special":attack.damage=maxi(1,int(round(int(attack.damage)*rule("special_damage_multiplier",1.1))))
	match weapon_id:
		"eldritch_bowstaff":_queue_swing(slot,attack,175 if slot=="basic" else 225,150 if slot=="basic" else 260)
		"demon_blade":_queue_swing(slot,attack,155 if slot=="basic" else 205,120 if slot=="basic" else 210)
		"storm_trident":
			if not trident.is_empty():result.started=false;result.failure="Retrieve the Storm Trident before attacking."
			elif slot=="basic":_queue_swing(slot,attack,235,24)
			else:
				trident_preview=_safe_trident_destination(aimed_point(rule("range",410)))
				var duration:=rule("windup",0.22)*maxf(0.1,actor.effective_attack_interval("basic",0.2)/0.2)
				trident={"state":"aiming","position":actor.global_position,"destination":trident_preview,"attack":attack,"left":duration}
		"valkyrian_sling":_queue_ranged(slot,attack)
		"dragonbone_dagger":
			_queue_swing(slot,attack,115,105 if slot=="basic" else 190,2 if slot=="special" else 1)
		"archon_crossbow":_queue_ranged(slot,attack)
		"divine_hammer":_queue_hammer(attack,0,_hammer_target(true))
		"grim_reaver":_queue_swing(slot,attack,205 if slot=="basic" else 250,245 if slot=="basic" else 360)
		"sentinel_shield":
			attack.knockback=0.0;attack.shield_shove=rule("basic_shove",95) if slot=="basic" else rule("shove",280);attack.hit_stun_duration=rule("stagger_duration",0.12)
			var duration:=rule("windup",0.12)*maxf(0.1,actor.effective_attack_interval("basic",0.2)/0.2)
			shield_bash={"attack":attack,"left":duration,"duration":duration,"direction":actor.aim_direction,"reach":rule("basic_reach",110) if slot=="basic" else rule("reach",150),"arc":rule("basic_arc",100) if slot=="basic" else rule("arc",130)}
		"umbral_bow":_queue_ranged(slot,attack)
	return result

func _queue_ranged(slot:String,attack:Dictionary)->void:
	var duration:=maxf(0.001,actor.effective_attack_interval(slot,float(tuning(slot).cooldown)))
	ranged_attack={"attack":attack.duplicate(true),"empowered":slot=="special","duration":duration,"elapsed":0.0,"release":rule("release_fraction",0.35),"released":false,"direction":actor.aim_direction}

func ranged_presentation()->Dictionary:
	if ranged_attack.is_empty():return {}
	var duration:=maxf(0.001,float(ranged_attack.duration))
	var release:=float(ranged_attack.release)
	return {"loaded":not bool(ranged_attack.released),"charge":clampf(float(ranged_attack.elapsed)/maxf(0.001,duration*release),0,1),"recovery":clampf((float(ranged_attack.elapsed)-duration*release)/maxf(0.001,duration*(1-release)),0,1)}

func _tick_ranged(delta:float)->void:
	if ranged_attack.is_empty():return
	var state:=ranged_attack
	var before:=float(state.elapsed)
	state.elapsed+=delta
	if not bool(state.released) and float(state.elapsed)>=float(state.duration)*float(state.release):
		state.released=true
		var current_aim:=actor.aim_direction
		var previous_count:=missiles.size()
		actor.aim_direction=state.direction
		match weapon_id:
			"archon_crossbow":_launch_archon(state.attack,bool(state.empowered))
			"umbral_bow":_launch_umbral(state.attack,bool(state.empowered))
			"valkyrian_sling":_launch_sling(state.attack,bool(state.empowered))
		actor.aim_direction=current_aim
		if missiles.size()>previous_count:missiles.back()["spawn_delay"]=maxf(0,float(state.duration)*float(state.release)-before)
		flash(actor.global_position+Vector2(state.direction)*24,18,"burst",0.12)
	if float(state.elapsed)>=float(state.duration):ranged_attack={}

func _queue_swing(slot:String,attack:Dictionary,reach:float,degrees:float,count:int=1)->void:
	var duration:=maxf(0.001,actor.effective_attack_interval(slot,float(tuning(slot).cooldown)))
	var attacks:Array[Dictionary]=[attack.duplicate(true)]
	if count>1:
		cast_serial+=1
		var follow:=attack.duplicate(true);follow.warrior_cast=cast_serial;follow.damage=maxi(1,roundi(int(attack.damage)*rule("followup_damage_multiplier",0.55)));attacks.append(follow)
	swing={"elapsed":0.0,"duration":duration,"direction":actor.aim_direction,"reach":rule(slot+"_reach",reach),"degrees":rule(slot+"_arc",degrees),"attacks":attacks,"windup":rule("windup_fraction",0.25),"active":rule("active_fraction",0.5)}

func _swing_angle(state:Dictionary,index:int,progress:float)->float:
	var phase:=1-progress if index%2==1 else progress
	return Vector2(state.direction).angle()+deg_to_rad(lerpf(-float(state.degrees)/2,float(state.degrees)/2,phase))

func swing_presentation()->Dictionary:
	if swing.is_empty():return {}
	var progress:=float(swing.elapsed)/float(swing.duration)
	var active:=clampf((progress-float(swing.windup))/float(swing.active),0,1)
	var count:int=swing.attacks.size()
	var index:=mini(count-1,int(active*count))
	return {"angle":_swing_angle(swing,index,clampf(active*count-index,0,1)),"turn":-1.0 if index%2==1 else 1.0,"active":progress>=float(swing.windup) and progress<=float(swing.windup)+float(swing.active)}

func _tick_swing(delta:float)->void:
	if swing.is_empty():return
	var state:=swing
	var old:=float(state.elapsed)/float(state.duration)
	state.elapsed=minf(float(state.duration),float(state.elapsed)+delta)
	var now:=float(state.elapsed)/float(state.duration)
	var count:int=state.attacks.size()
	for index in count:
		var start:=float(state.windup)+float(state.active)*float(index)/count
		var end:=start+float(state.active)/count
		if now<=start or old>=end:continue
		var from:=clampf((old-start)/(end-start),0,1)
		var to:=clampf((now-start)/(end-start),0,1)
		var a:=_swing_angle(state,index,from)
		var b:=_swing_angle(state,index,to)
		var direction:=Vector2.from_angle((a+b)/2)
		for target in combat_targets():
			if not SlasherHitGeometry.overlaps_sector(actor.global_position,direction,float(state.reach),rad_to_deg(absf(b-a))+rule("melee_contact_padding_degrees",4),target):continue
			if not _solid_intersection(actor.global_position,target.global_position).is_empty():continue
			if hit(target,state.attacks[index],true)>0:flash(target.global_position,16,"burst",0.13)
	if now>=1:swing={}

func _tick_shield(delta:float)->void:
	if shield_bash.is_empty():return
	var state:=shield_bash
	var elapsed:=minf(delta,float(state.left))
	# Continuous collision sweep; never grants invulnerability or input locks.
	actor.move_and_collide(Vector2(state.direction)*rule("lunge",35)*elapsed/float(state.duration))
	state.left-=delta
	if float(state.left)>0:return
	shield_bash={}
	slash(actor.global_position,state.direction,float(state.reach),float(state.arc),state.attack,true,false,0,false)
	_append_effect({"kind":"shield_impact","center":actor.global_position,"direction":state.direction,"radius":state.reach,"degrees":state.arc,"left":0.18,"duration":0.18})
	_start_impact_recovery(actor.global_position+Vector2(state.direction)*42)

func _start_impact_recovery(point:Vector2)->void:
	var duration:=rule("recovery",0.18)*maxf(0.1,actor.effective_attack_interval("basic",0.3)/0.3)
	impact_recovery={"point":point-actor.global_position,"direction":actor.aim_direction,"left":duration,"duration":duration}

func _tick_impact_recovery(delta:float)->void:
	if impact_recovery.is_empty():return
	impact_recovery.left-=delta
	if float(impact_recovery.left)<=0:impact_recovery.clear()

func _safe_trident_destination(desired:Vector2)->Vector2:
	var destination:=actor.global_position+(desired-actor.global_position).limit_length(rule("range",410))
	var wall:=_solid_intersection(actor.global_position,destination)
	if not wall.is_empty():destination=Vector2(wall.position)-actor.global_position.direction_to(destination)*24
	if actor.position_sanitizer.is_valid():destination=actor.position_sanitizer.call(destination)
	if not destination.is_finite():return actor.global_position
	if is_instance_valid(actor.pathfinder) and not actor.pathfinder.cells.is_empty():
		var start:=actor.pathfinder.nearest_walkable_cell(actor.pathfinder.world_to_cell(actor.global_position))
		var end:=actor.pathfinder.nearest_walkable_cell(actor.pathfinder.world_to_cell(destination))
		if actor.pathfinder.find_cell_path(start,end).is_empty():return actor.global_position
		if not actor.pathfinder.is_walkable_cell(actor.pathfinder.world_to_cell(destination)):destination=actor.pathfinder.cell_to_world(end)
	# Sanitizers and navigation snapping may move an otherwise safe point.
	# Validate their final result, not only the initial ray-clamped candidate.
	if not destination.is_finite() or actor.global_position.distance_to(destination)>rule("range",410)+0.01:return actor.global_position
	if not _solid_intersection(actor.global_position,destination).is_empty():return actor.global_position
	return destination

func _throw_trident(attack: Dictionary,destination:Vector2=Vector2.INF) -> void:
	if destination==Vector2.INF:destination=aimed_point(rule("range",410))
	destination=_safe_trident_destination(destination)
	trident={"state":"flying","position":actor.global_position,"destination":destination}
	_append_missile({"kind":"trident","origin":actor.global_position,"position":actor.global_position,"destination":destination,"attack":attack,"speed":rule("flight_speed",720)})

func trident_flight_pose(missile:Dictionary)->Dictionary:
	var origin:=Vector2(missile.get("origin",actor.global_position))
	var travel:=Vector2(missile.destination)-origin
	var progress:=clampf(origin.distance_to(Vector2(missile.position))/maxf(0.001,travel.length()),0,1)
	var height:=rule("flight_arc_height",55)
	var point:=Vector2(missile.position)+Vector2(0,-sin(PI*progress)*height)
	var tangent:=travel+Vector2(0,-PI*cos(PI*progress)*height)
	if tangent.length_squared()<0.0001:tangent=travel if not travel.is_zero_approx() else Vector2.DOWN
	return {"position":point,"heading":tangent.normalized()}

func _tick_trident_aim(delta:float)->void:
	if trident.is_empty():
		if weapon_id=="storm_trident":trident_preview=_safe_trident_destination(aimed_point(rule("range",410)))
		return
	if trident.state!="aiming":return
	if actor.input_locked:trident.clear();return
	trident.destination=_safe_trident_destination(Vector2(trident.destination))
	var before:=float(trident.left)
	trident.left-=delta
	if float(trident.left)<=0:
		_throw_trident(trident.attack,Vector2(trident.destination))
		# Flight begins at release, not at the beginning of the caller's frame.
		missiles.back()["spawn_delay"]=maxf(0,before)

func _launch_sling(attack: Dictionary, empowered: bool) -> void:
	for missile in missiles:
		if missile.kind=="sling":return
	sling_damage_stacks=0
	_append_missile({"kind":"sling","position":actor.global_position,"direction":actor.aim_direction,"attack":attack.duplicate(true),"speed":rule("speed",660),"remaining":rule("range",560),"returning":false,"hit_ids":{},"bounces":0,"max_bounces":int(rule("empowered_impacts",6) if empowered else rule("impacts",4)),"damage_stacks":0,"life":rule("lifetime",12)})

func _launch_archon(attack: Dictionary, empowered: bool) -> void:
	if missiles.size()>=int(rule("projectile_cap",4)):return
	next_carry_source-=1
	_append_missile({"kind":"archon","position":actor.global_position,"direction":actor.aim_direction.normalized(),"attack":attack.duplicate(true),"speed":rule("speed",760),"remaining":rule("empowered_range",650) if empowered else rule("range",510),"hit_ids":{},"speared":0,"dragged":[],"carry_source":next_carry_source})

func _launch_umbral(attack: Dictionary, empowered: bool) -> void:
	if missiles.size()>=int(rule("projectile_cap",4)):return
	_append_missile({"kind":"umbral","position":actor.global_position,"direction":actor.aim_direction,"attack":attack,"speed":rule("speed",700),"remaining":rule("empowered_range",620) if empowered else rule("range",480),"hit_ids":{},"pierces":int(rule("empowered_pierces",3) if empowered else rule("pierces",1))})

func _physics_process(delta: float) -> void:
	_tick_impact_recovery(delta)
	# The base runtime removes these expired records before executing new effects.
	for effect in effects:
		if actor.health>0 and float(effect.left)<=delta and effect_pool.size()<32:effect_pool.append(effect)
	target_cache_left-=delta
	if target_cache_left<=0:_refresh_target_cache()
	super(delta)
	if actor.health<=0:
		rampage_left=0.0;rampage_stacks=0
		impact_recovery.clear()
		ranged_attack.clear()
		hammer_chain.clear();shield_bash.clear();swing.clear()
		for missile in missiles:_release_carried(missile)
		_clear_leashes()
		_clear_curses();wounds.clear();pins.clear();leashes.clear();missiles.clear();trident.clear()
		return
	if actor.input_locked:hammer_chain.clear();shield_bash.clear();swing.clear()
	if actor.input_locked:ranged_attack.clear();impact_recovery.clear()
	if has_meta("active_item_runtime_id") and actor.warrior_kit!=self and ActiveItems.held(actor.run_state)!=weapon_id:
		impact_recovery.clear()
		ranged_attack.clear()
		swing.clear()
		if not trident.is_empty() and trident.state=="aiming":trident.clear()
	if weapon_id in ["archon_crossbow","umbral_bow","divine_hammer","sentinel_shield"] and has_meta("active_item_runtime_id") and actor.warrior_kit!=self and ActiveItems.held(actor.run_state)!=weapon_id:
		hammer_chain.clear();shield_bash.clear()
		for missile in missiles:_release_carried(missile)
		missiles.clear();_clear_leashes()
	for key in resolved_strikes.keys():
		resolved_strikes[key]-=delta
		if float(resolved_strikes[key])<=0:resolved_strikes.erase(key)
	visual_clock+=delta
	_tick_hammer(delta)
	_tick_shield(delta)
	_tick_swing(delta)
	_tick_ranged(delta)
	_tick_trident_aim(delta)
	rampage_left=maxf(0.0,rampage_left-delta)
	if rampage_left<=0.0 and rampage_stacks>0:
		flash(actor.global_position,58,"rampage_end",0.4);rampage_stacks=0
	_tick_curses(delta);_tick_statuses(wounds,delta);_tick_statuses(pins,delta)
	for id in pins:
		var enemy:SlasherEnemy=(pins[id].target as WeakRef).get_ref()
		if is_instance_valid(enemy):pins[id].left=enemy.storm_vulnerability_left
	_update_leashes(delta)
	for index in range(missiles.size()-1,-1,-1):
		var missile:=missiles[index]
		var finished:=_tick_missile(missile,delta)
		if finished:_retire_missile(index)
	if not trident.is_empty() and trident.state=="deployed" and actor.global_position.distance_to(Vector2(trident.position))<=rule("retrieve_radius",44) and _solid_intersection(actor.global_position,Vector2(trident.position)).is_empty():
		flash(Vector2(trident.position),38);trident.clear();actor.cooldowns["special"]=0.0
	queue_redraw()

func _tick_statuses(statuses: Dictionary, delta: float) -> void:
	for id in statuses.keys():
		var record:Dictionary=statuses[id];record.left-=delta
		var target:Node=(record.target as WeakRef).get_ref()
		if float(record.left)<=0.0 or not is_instance_valid(target) or ("dead" in target and target.dead):statuses.erase(id)

func _tick_missile(missile: Dictionary, delta: float) -> bool:
	if missile.has("spawn_delay"):
		delta=maxf(0,delta-float(missile.spawn_delay));missile.erase("spawn_delay")
	if delta<=0:return false
	match String(missile.kind):
		"trident":return _tick_trident(missile,delta)
		"sling":return _tick_sling(missile,delta)
		"archon":return _tick_archon(missile,delta)
		"umbral":return _tick_umbral(missile,delta)
	return true

func _tick_trident(missile: Dictionary, delta: float) -> bool:
	var next:=Vector2(missile.position).move_toward(Vector2(missile.destination),float(missile.speed)*delta)
	var wall:=_solid_intersection(Vector2(missile.position),next)
	if not wall.is_empty():
		missile.destination=_safe_trident_destination(Vector2(wall.position));next=missile.destination
	missile.position=next;trident.position=missile.position
	if not Vector2(missile.position).is_equal_approx(Vector2(missile.destination)):return false
	trident={"state":"deployed","position":Vector2(missile.destination)};last_proc_count=0
	var struck:Dictionary={}
	for target in combat_targets():
		var enemy:=_combat_body(target)
		if struck.has(enemy.get_instance_id()):continue
		if target.global_position.distance_to(Vector2(missile.destination))<=rule("radius",115) and _solid_intersection(Vector2(missile.destination),target.global_position).is_empty():
			if hit(target,missile.attack,true)<=0 or enemy.dead:continue
			struck[enemy.get_instance_id()]=true
			enemy.apply_storm_pin(rule("pin_duration",2.6),rule("boss_control_multiplier",0.3),rule("immune_slow_multiplier",0.65))
			pins[enemy.get_instance_id()]={"target":weakref(enemy),"left":enemy.storm_vulnerability_left};last_proc_count+=1
	flash(Vector2(missile.destination),rule("radius",115),"burst",0.5);return true

func _tick_sling(missile: Dictionary, delta: float) -> bool:
	# Deterministic fixed flight steps preserve turning and parry timing across
	# caller frame sizes. No gameplay queries depend on trail particle counts.
	missile.accumulator=float(missile.get("accumulator",0))+delta
	while float(missile.accumulator)+0.000001>=1.0/120.0:
		missile.accumulator-=1.0/120.0
		if _step_sling(missile,1.0/120.0):return true
	return false

func _step_sling(missile:Dictionary,delta:float)->bool:
	missile.life=float(missile.get("life",rule("lifetime",12)))-delta
	if float(missile.life)<=0:return true
	var position:=Vector2(missile.position)
	if missile.returning:
		var distance:=position.distance_to(actor.global_position)
		var parry_left:=float(missile.get("parry_left",-1))
		if distance<=rule("parry_radius",105) and parry_left<0:
			parry_left=rule("parry_window",0.18);AudioCue.play_from(actor,"block")
		elif parry_left>=0:parry_left=maxf(0,parry_left-delta)
		missile.parry_left=parry_left
		if distance<=rule("catch_radius",16):return parry_left==0
		var heading:=Vector2(missile.direction).angle()
		var angle:=rotate_toward(heading,position.direction_to(actor.global_position).angle(),rule("turn_rate",12)*delta)
		missile.direction=Vector2.from_angle(angle)
		# Slow the final curve so its turning radius cannot orbit around the
		# catch point forever when the player stands inside the original turn.
		var return_speed:=minf(float(missile.speed),distance*rule("turn_rate",12)*rule("return_approach_factor",0.5))
		var next:=position+Vector2(missile.direction)*minf(distance,return_speed*delta)
		if not _solid_intersection(position,next).is_empty():return true
		missile.position=next
		return false
	var target:Node2D=null
	if missile.get("target") is WeakRef:target=missile.target.get_ref() as Node2D
	if not _valid_combat_target(target) or missile.hit_ids.has(_combat_id(target)):
		target=_nearest_unhit(position,missile.hit_ids,rule("bounce_range",320))
		missile.target=weakref(target) if is_instance_valid(target) else null
	if target==null:missile.returning=true;return false
	var angle:=rotate_toward(Vector2(missile.direction).angle(),position.direction_to(target.global_position).angle(),rule("turn_rate",12)*delta)
	var direction:=Vector2.from_angle(angle)
	# A fixed fast speed can orbit a nearby ricochet target forever: its turn
	# radius exceeds the remaining distance. Tighten the curve by slowing the
	# approach, without snapping direction or moving the collision point.
	var approach_speed:=minf(float(missile.speed),position.distance_to(target.global_position)*rule("turn_rate",12)*rule("approach_factor",0.5))
	var movement:=direction*approach_speed*delta
	var end:=position+movement
	if not _solid_intersection(position,end).is_empty():missile.returning=true;return false
	missile.position=end;missile.remaining-=movement.length();missile.direction=direction
	var contact:=SlasherHitGeometry.sweep(position,end,target,rule("projectile_radius",8))
	if contact!=INF:
		missile.position=position.lerp(end,contact)
		var strike:Dictionary=Dictionary(missile.attack).duplicate(true)
		strike.damage=maxi(1,int(strike.damage)*(1+int(missile.damage_stacks)))
		hit(target,strike,true);missile.hit_ids[_combat_id(target)]=true;missile.bounces+=1;missile.target=null;flash(Vector2(missile.position),18,"burst",0.15)
	if int(missile.bounces)>=int(missile.max_bounces) or float(missile.remaining)<=0.0 or target==null:missile.returning=true
	return false

func _tick_archon(missile: Dictionary, delta: float) -> bool:
	_prune_carried(missile)
	var start:=Vector2(missile.position)
	var distance:=minf(float(missile.remaining),float(missile.speed)*delta)
	var end:=start+Vector2(missile.direction)*distance
	var wall:=_solid_intersection(start,end)
	if not wall.is_empty():end=Vector2(wall.position)-Vector2(missile.direction)*2.0
	var contacts:Array[Dictionary]=[]
	for enemy in combat_targets():
		if missile.hit_ids.has(_combat_id(enemy)):continue
		var contact:=SlasherHitGeometry.sweep(start,end,enemy,rule("projectile_radius",7))
		if contact!=INF and _solid_intersection(start,enemy.global_position).is_empty():contacts.append({"target":enemy,"time":contact})
	contacts.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return float(a.time)<float(b.time))
	for contact in contacts:
		var target:Node2D=contact.target
		if not _valid_combat_target(target) or missile.hit_ids.has(_combat_id(target)):continue
		var enemy:=_combat_body(target)
		var strike:Dictionary=Dictionary(missile.attack).duplicate(true)
		strike.damage=maxi(1,int(round(int(strike.damage)*(1.0+rule("pierce_bonus",0.35)*int(missile.speared)))))
		strike.knockback=0.0
		missile.hit_ids[enemy.get_instance_id()]=true
		if hit(target,strike,true)<=0:continue
		missile.speared+=1;last_proc_count=int(missile.speared)
		flash(enemy.global_position,22,"burst",0.18)
		if target is SlasherEnemy and _archon_carry_eligible(enemy) and missile.dragged.size()<int(rule("carry_cap",6)) and not enemy.has_meta("fighter_archon_carrier"):
			enemy.set_archon_carried(int(missile.carry_source),Vector2(missile.direction))
			missile.dragged.append(weakref(enemy))
	missile.position=end;missile.remaining-=distance
	for index in missile.dragged.size():
		var enemy:SlasherEnemy=(missile.dragged[index] as WeakRef).get_ref()
		if not is_instance_valid(enemy) or enemy.dead:continue
		var destination:Vector2=end-Vector2(missile.direction)*(rule("carry_offset",20)+index*rule("carry_spacing",18))
		# Body sweeps stop each carried enemy at terrain, independently of the
		# bolt's much smaller hitbox. Never assign a carried body's position.
		enemy.move_and_collide(destination-enemy.global_position)
		enemy.apply_mage_stun(int(missile.carry_source),0.15)
	var finished:=not wall.is_empty() or float(missile.remaining)<=0
	if finished:
		_release_carried(missile);flash(end,35,"burst",0.25)
	return finished

func _solid_intersection(start:Vector2,end:Vector2)->Dictionary:
	if start.is_equal_approx(end):return {}
	var query:=PhysicsRayQueryParameters2D.create(start,end,1)
	query.exclude=[actor.get_rid()]
	# A dynamic body on the ray must not hide a wall behind it.
	for i in 128:
		var result:=get_world_2d().direct_space_state.intersect_ray(query)
		if result.is_empty() or result.collider is StaticBody2D:return result
		var exclusions:=query.exclude;exclusions.append(result.rid);query.exclude=exclusions
	return {"position":start} # Conservative fallback in exceptionally dense rays.

func _archon_carry_eligible(enemy:SlasherEnemy)->bool:
	return not enemy.dead and not enemy.boss and not enemy.mini_boss and not enemy.is_storm_pinned() and enemy.displacement_multiplier()>0 and enemy.displacement_multiplier()>=rule("carry_resistance_threshold",0.5)

func _prune_carried(missile:Dictionary)->void:
	var source:=int(missile.get("carry_source",get_instance_id()))
	for index in range(missile.dragged.size()-1,-1,-1):
		var enemy:SlasherEnemy=(missile.dragged[index] as WeakRef).get_ref()
		if is_instance_valid(enemy) and enemy.is_inside_tree() and _archon_carry_eligible(enemy) and int(enemy.get_meta("fighter_archon_carrier",0))==source:continue
		if is_instance_valid(enemy):
			enemy.clear_archon_carried(source)
		missile.dragged.remove_at(index)

func _release_carried(missile:Dictionary)->void:
	for reference in missile.get("dragged",[]):
		var enemy:SlasherEnemy=(reference as WeakRef).get_ref()
		if is_instance_valid(enemy):
			var source:=int(missile.get("carry_source",get_instance_id()))
			enemy.clear_archon_carried(source)
	if missile.has("dragged"):missile.dragged.clear()

func _exit_tree()->void:
	for missile in missiles:_release_carried(missile)
	_clear_leashes()
	_clear_curses()
	super()

func _notification(what:int)->void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_PAUSED]:impact_recovery.clear()
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_PAUSED]:ranged_attack.clear()
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_PAUSED]:hammer_chain.clear();shield_bash.clear();swing.clear()
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_PAUSED] and not trident.is_empty() and trident.state=="aiming":trident.clear()

func _unhandled_input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:impact_recovery.clear()
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:ranged_attack.clear()
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:hammer_chain.clear();shield_bash.clear();swing.clear()
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE and not trident.is_empty() and trident.state=="aiming":trident.clear()

func _tick_umbral(missile: Dictionary, delta: float) -> bool:
	var start:=Vector2(missile.position)
	var distance:=minf(float(missile.remaining),float(missile.speed)*delta)
	var end:=start+Vector2(missile.direction)*distance
	var wall:=_solid_intersection(start,end)
	if not wall.is_empty():end=wall.position
	var contacts:Array[Dictionary]=[]
	for enemy in combat_targets():
		if missile.hit_ids.has(_combat_id(enemy)):continue
		var contact:=SlasherHitGeometry.sweep(start,end,enemy,rule("projectile_radius",5))
		if contact!=INF and _solid_intersection(start,enemy.global_position).is_empty():contacts.append({"target":enemy,"time":contact})
	contacts.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return float(a.time)<float(b.time))
	missile.position=end;missile.remaining-=distance
	for contact in contacts:
		var target:Node2D=contact.target
		if not _valid_combat_target(target) or missile.hit_ids.has(_combat_id(target)):continue
		var enemy:=_combat_body(target)
		missile.hit_ids[enemy.get_instance_id()]=true
		if hit(target,missile.attack,true)>0 and not enemy.dead:_add_leash(enemy,target is SlasherColossusWeakPoint)
		missile.pierces-=1
		if int(missile.pierces)<=0:return true
	return not wall.is_empty() or float(missile.remaining)<=0.0

func _add_leash(enemy:SlasherEnemy,immobile:bool=false)->void:
	var id:=enemy.get_instance_id()
	var normal_speed:=0.0 if immobile else maxf(0,enemy.speed)
	if leashes.has(id):normal_speed=float(leashes[id].normal_speed)
	leashes[id]={"target":weakref(enemy),"left":rule("duration",4),"normal_speed":normal_speed,"last_position":enemy.global_position}
	var removal:=_remove_leash.bind(id)
	if not enemy.tree_exiting.is_connected(removal):enemy.tree_exiting.connect(removal)
	if not enemy.defeated.is_connected(_leashed_death):enemy.defeated.connect(_leashed_death)
	last_proc_count=leashes.size();arc(actor.global_position,enemy.global_position)
	_update_leashes(0)

func _leashed_death(enemy:SlasherEnemy,_reward:int)->void:
	_remove_leash(enemy.get_instance_id())

func _remove_leash(id:int,show_break:bool=true)->void:
	if leashes.has(id):
		var enemy:SlasherEnemy=(leashes[id].target as WeakRef).get_ref()
		var endpoint:=Vector2(leashes[id].get("last_position",actor.global_position))
		if is_instance_valid(enemy):endpoint=enemy.global_position
		if show_break and is_inside_tree() and is_instance_valid(actor) and actor.health>0:
			_append_effect({"kind":"tether_break","center":actor.global_position,"endpoint":endpoint,"radius":0.0,"left":0.25,"duration":0.25})
		if is_instance_valid(enemy):
			enemy.clear_mage_control(get_instance_id())
			var removal:=_remove_leash.bind(id)
			if enemy.tree_exiting.is_connected(removal):enemy.tree_exiting.disconnect(removal)
			if enemy.defeated.is_connected(_leashed_death):enemy.defeated.disconnect(_leashed_death)
		leashes.erase(id)
	_refresh_stolen_speed()

func _refresh_stolen_speed()->void:
	if not is_instance_valid(actor) or not is_instance_valid(actor.kit_buffs):return
	var stolen:=0.0
	for record in leashes.values():stolen+=float(record.normal_speed)*rule("steal_fraction",0.45)
	actor.kit_buffs.clear_source(source_id())
	if stolen>0:actor.kit_buffs.grant_speed(source_id(),1.0+minf(rule("haste_cap",0.6),stolen/maxf(1,actor.speed)),0.15)

func _update_leashes(delta:float)->void:
	for id in leashes.keys():
		var record:Dictionary=leashes[id];record.left-=delta
		var enemy:SlasherEnemy=(record.target as WeakRef).get_ref()
		if is_instance_valid(enemy):record.last_position=enemy.global_position
		if not is_instance_valid(enemy) or enemy.dead or float(record.left)<=0 or actor.global_position.distance_to(enemy.global_position)>rule("break_distance",750):
			_remove_leash(id);continue
		enemy.apply_mage_slow(get_instance_id(),rule("slow_multiplier",0.55),0.15)
	_refresh_stolen_speed()

func _clear_leashes()->void:
	# Scene/owner cleanup must not manufacture a new effect while shutting down.
	for id in leashes.keys():_remove_leash(id,false)

func _nearest_unhit(origin: Vector2, hit_ids: Dictionary, radius: float) -> Node2D:
	var nearest:Node2D;var best:=radius*radius
	for enemy in combat_targets():
		if hit_ids.has(_combat_id(enemy)):continue
		var distance:=origin.distance_squared_to(enemy.global_position)
		if distance<best and _solid_intersection(origin,enemy.global_position).is_empty():best=distance;nearest=enemy
	return nearest

func _draw()->void:
	var settings:Node=get_node_or_null("/root/GameSettings")
	var reduced:bool=settings!=null and settings.get_bool("reduced_effects",false)
	var tint:=GOLD if weapon_id in ["divine_hammer","sentinel_shield","valkyrian_sling","archon_crossbow"] else STORM if weapon_id=="storm_trident" else PURPLE
	for effect in effects:
		if effect.kind=="arc":continue
		var progress:=clampf(1-float(effect.left)/float(effect.duration),0,1)
		var center:=to_local(Vector2(effect.center));var radius:=float(effect.radius)
		if effect.kind=="shield_impact":
			var heading:=Vector2(effect.direction).angle()
			var half:=deg_to_rad(float(effect.degrees))*0.5
			draw_arc(center,radius,heading-half,heading+half,24,Color(GOLD,(1-progress)*0.65),2,true)
			draw_arc(center,radius*(0.9+0.1*progress),heading-half,heading+half,24,Color(0.85,0.94,1.0,1-progress),3,true)
			continue
		if effect.kind=="shield_shove":
			var endpoint:=to_local(Vector2(effect.endpoint))
			var fade:=1-progress
			if bool(effect.resisted):
				for side in [-1,1]:draw_arc(endpoint,18+progress*8,side*PI/2-0.45,side*PI/2+0.45,8,Color(GOLD,fade),2,true)
			else:
				var direction:=(endpoint-center).normalized()
				var skid:=minf(36,center.distance_to(endpoint))
				for side in [-1,1]:
					var offset:Vector2=direction.orthogonal()*side*7
					draw_line(endpoint+offset-direction*skid,endpoint+offset,Color(0.7,0.65,0.5,fade*0.55),2,true)
				for i in (1 if reduced else 3):draw_circle(endpoint-direction*(i*8+progress*10)+Vector2(0,-progress*8),2+progress*2,Color(0.7,0.65,0.5,fade*0.35))
			continue
		if effect.kind=="hammer_return":
			var point:=center.lerp(Vector2.ZERO,progress)
			var tail:=center.lerp(Vector2.ZERO,maxf(0,progress-0.18))
			draw_line(tail,point,Color(GOLD,1-progress*0.6),2,true)
			draw_circle(point,3*(1-progress)+1,GOLD)
			if not reduced:draw_circle(point,7,Color(GOLD,0.12*(1-progress)))
			continue
		if effect.kind=="tether_break":
			var endpoint:=to_local(Vector2(effect.endpoint))
			var midpoint:=center.lerp(endpoint,0.5)
			var tint_break:=Color("#c6a7f0",(1-progress)*0.7)
			draw_line(center,center.lerp(midpoint,1-progress),tint_break,2,true)
			draw_line(endpoint,endpoint.lerp(midpoint,1-progress),tint_break,2,true)
			for i in (2 if reduced else 4):
				var point:=midpoint+Vector2.from_angle(i*TAU/4)*progress*18
				draw_circle(point,2*(1-progress),tint_break)
			continue
		if effect.kind=="dagger_puncture":
			for side in [-1,1]:
				var root:=center+Vector2(side*5,-radius*0.5)
				var fang:=PackedVector2Array([root+Vector2(-3,0),root+Vector2(3,0),center+Vector2(side*2,radius*0.6)])
				draw_colored_polygon(fang,Color(1,0.9,0.75,1-progress))
				draw_line(root,center+Vector2(side*2,radius*0.6),Color(0.85,0.25,0.3,1-progress),1.5,true)
			continue
		if effect.kind in ["curse_glyph","curse_conversion","curse_overflow","rampage_start","rampage_end"]:
			_draw_status_transition(effect,center,radius,progress,reduced)
			continue
		canvas_effect_ring(center,radius,progress,tint,reduced)
		if effect.kind=="critical":
			for i in 4:
				var direction:=Vector2.from_angle(PI*0.25+i*PI*0.5)
				draw_line(center+direction*radius*0.25,center+direction*radius,Color(1,0.95,0.8,1-progress),2,true)

func _draw_status_transition(effect:Dictionary,center:Vector2,radius:float,progress:float,reduced:bool)->void:
	var alpha:=1-progress
	if effect.kind=="curse_glyph":
		var size:=radius*(1-0.5*progress)
		var glyph:=PackedVector2Array([center+Vector2(0,-size),center+Vector2(size,0),center+Vector2(0,size),center+Vector2(-size,0),center+Vector2(0,-size)])
		draw_polyline(glyph,Color("#70edbd",alpha),2,true)
		draw_line(center-Vector2(0,size),center+Vector2(0,size),Color(PURPLE,alpha),2,true)
	elif effect.kind=="curse_conversion":
		draw_circle(center,radius*(0.4+progress*0.3),Color("#23102e",alpha*0.65))
		for i in int(effect.get("count",0)):
			var direction:=Vector2.from_angle(TAU*i/maxf(1,int(effect.count)))
			draw_line(center+direction*5,center+direction*radius*progress,Color("#70edbd",alpha),2,true)
			draw_circle(center+direction*radius*progress,5*alpha,Color(PURPLE,alpha))
	elif effect.kind=="rampage_start":
		var top:=center+Vector2(0,-24-progress*25)
		var mantle:=PackedVector2Array([top+Vector2(-radius,35),top+Vector2(-20,-12),top+Vector2(0,-22),top+Vector2(20,-12),top+Vector2(radius,35)])
		draw_polyline(mantle,Color(PURPLE,alpha),3,true)
		for side in [-1,1]:draw_line(top+Vector2(side*5,-4),top+Vector2(side*12,-8),Color("#b6ffbf",alpha),3,true)
	elif effect.kind=="curse_overflow":
		# Broken rune corners distinguish discarded curse energy from emerging
		# bodies. Keep the same readable silhouette at both effect qualities.
		for i in 4:
			var direction:=Vector2.from_angle(i*PI/2-PI/2)
			var point:=center+direction*radius*(0.3+progress*0.7)+Vector2(0,-progress*15)
			var size:=8*alpha
			var corner:=PackedVector2Array([point-direction*size+direction.orthogonal()*size,point,point-direction*size-direction.orthogonal()*size])
			draw_polyline(corner,Color(PURPLE,alpha),2,true)
	else:
		var count:=4 if reduced else 8
		for i in count:
			var direction:=Vector2.from_angle(TAU*i/count+progress)
			var point:=center+direction*radius*(0.5+progress*0.5)+Vector2(0,-progress*15)
			draw_circle(point,3*alpha,Color(PURPLE,alpha))

func canvas_effect_ring(center:Vector2,radius:float,progress:float,tint:Color,reduced:bool)->void:
	var segments:=20 if reduced else 40
	draw_arc(center,radius,0,TAU,segments,Color(tint,(1-progress)*0.45),1.5,true)
	draw_arc(center,radius*(0.25+0.75*progress),0,TAU,segments,Color(tint,1-progress),3,true)
	if not reduced:draw_circle(center,radius*(0.15+0.25*progress),Color(tint,(1-progress)*0.18))

func draw_foreground(canvas: Node2D) -> void:
	super(canvas)
	if not impact_recovery.is_empty():
		var progress:=clampf(1-float(impact_recovery.left)/float(impact_recovery.duration),0,1)
		var direction:=Vector2(impact_recovery.direction)
		var point:=Vector2(impact_recovery.point).lerp(direction*25,progress)
		if weapon_id=="divine_hammer":
			point.y-=sin(progress*PI)*20
			canvas.draw_line(Vector2.ZERO,point,GOLD,4,true)
			_draw_hammer_head(canvas,point,int(impact_recovery.get("depth",0)))
		elif weapon_id=="sentinel_shield":
			canvas.draw_set_transform(point,direction.angle())
			canvas.draw_arc(Vector2.ZERO,23,-PI/2,PI/2,16,Color("#d8e7ee"),6,true)
			canvas.draw_line(Vector2(0,-23),Vector2(0,23),GOLD,2,true)
			canvas.draw_set_transform(Vector2.ZERO)
	if not ranged_attack.is_empty():
		var direction:=Vector2(ranged_attack.direction)
		var pose:=ranged_presentation()
		var progress:float=float(pose.charge) if pose.loaded else 0.0
		var tint:=SHADOW if weapon_id=="umbral_bow" else GOLD
		var center:Vector2=direction*(23-8*progress-(5*(1-float(pose.recovery)) if not pose.loaded else 0))
		if weapon_id=="valkyrian_sling":
			var pocket:Vector2=center+Vector2.from_angle(visual_clock*18 if pose.loaded else direction.angle()+0.6*float(pose.recovery))*18
			canvas.draw_line(Vector2.ZERO,pocket,Color("#bfa574"),2,true)
			canvas.draw_circle(pocket,5 if pose.loaded else 3,tint if pose.loaded else Color("#806747"))
		else:
			canvas.draw_arc(center,24,direction.angle()-1.2,direction.angle()+1.2,18,tint,3,true)
			var pull:=center-direction*(10*progress)
			canvas.draw_polyline(PackedVector2Array([center+direction.rotated(-1.2)*24,pull,center+direction.rotated(1.2)*24]),Color(tint,0.7),1.5,true)
			if pose.loaded:canvas.draw_line(pull,center+direction*32,tint,3,true)
			if weapon_id=="archon_crossbow":canvas.draw_line(center-direction*20,center+direction*20,Color("#bccbd4"),7,true)
		if not bool(ranged_attack.released):canvas.draw_arc(center,8+8*progress,0,TAU,20,Color(tint,0.65),2,true)
	if weapon_id=="storm_trident" and swing.is_empty() and (actor.warrior_kit==self or ActiveItems.held(actor.run_state)==weapon_id) and (trident.is_empty() or trident.state=="aiming"):
		var endpoint:=to_local(trident_preview if trident.is_empty() else Vector2(trident.destination))
		canvas.draw_arc(endpoint,rule("radius",115),0,TAU,32,Color(STORM,0.65),2,true)
		var path:=PackedVector2Array()
		for i in 17:
			var t:=float(i)/16;path.append(endpoint*t+Vector2(0,-sin(PI*t)*rule("flight_arc_height",55)))
		canvas.draw_polyline(path,Color(STORM,0.55),1.5,true)
	var settings:Node=get_node_or_null("/root/GameSettings")
	var reduced:bool=settings!=null and settings.get_bool("reduced_effects",false)
	if not swing.is_empty():
		var pose:=swing_presentation()
		var angle:=float(pose.angle)
		var tint:=PURPLE if weapon_id in ["eldritch_bowstaff","grim_reaver"] else Color("#eb6558") if weapon_id=="demon_blade" else Color("#f1dcc3")
		if weapon_id=="storm_trident":tint=STORM
		_draw_melee_silhouette(canvas,angle,float(swing.reach),tint)
		if not reduced and bool(pose.active):
			var trail_angle:=0.3 if weapon_id=="demon_blade" and actor.fighter_frenzy_left>0 else 0.18
			var tail:=angle-trail_angle*float(pose.turn)
			canvas.draw_arc(Vector2.ZERO,float(swing.reach),minf(tail,angle),maxf(tail,angle),12,Color(tint,0.55),5,true)
	if not shield_bash.is_empty():
		var direction:=Vector2(shield_bash.direction)
		var angle:=direction.angle()
		canvas.draw_set_transform(direction*28,angle)
		var plate:=PackedVector2Array([Vector2(-8,-23),Vector2(12,-17),Vector2(19,0),Vector2(12,17),Vector2(-8,23),Vector2(-3,0)])
		canvas.draw_colored_polygon(plate,Color("#344c65"));plate.append(plate[0]);canvas.draw_polyline(plate,Color("#d8e7ee"),3,true)
		canvas.draw_line(Vector2(0,-12),Vector2(10,0),GOLD,2,true);canvas.draw_line(Vector2(10,0),Vector2(0,12),GOLD,2,true)
		canvas.draw_set_transform(Vector2.ZERO)
		canvas.draw_arc(Vector2.ZERO,float(shield_bash.reach),angle-deg_to_rad(float(shield_bash.arc)/2),angle+deg_to_rad(float(shield_bash.arc)/2),20,Color(GOLD,0.35),1.5,true)
	if not hammer_chain.is_empty():
		var point:=to_local(Vector2(hammer_chain.point))
		var progress:=1.0-float(hammer_chain.left)/float(hammer_chain.duration)
		canvas.draw_arc(point,rule("splash_radius",105),0,TAU,32,Color(GOLD,0.4),1.5,true)
		canvas.draw_line(Vector2.ZERO,point+Vector2(0,-60*(1-progress)),GOLD,4,true)
		var head:=point+Vector2(0,-60*(1-progress))
		_draw_hammer_head(canvas,head,int(hammer_chain.depth))
		canvas.draw_arc(point,24*(1-progress)+8,0,TAU,20,Color(GOLD,0.8),3,true)
	for missile in missiles:
		var point:=to_local(Vector2(missile.position));var color:=STORM if missile.kind=="trident" else GOLD if missile.kind in ["sling","archon"] else SHADOW
		var heading:=Vector2(missile.get("direction",actor.aim_direction)).normalized()
		if missile.kind=="trident":
			var pose:=trident_flight_pose(missile)
			point=to_local(Vector2(pose.position));heading=Vector2(pose.heading)
		if missile.kind=="sling" and missile.returning:color=Color("#72f0df")
		for trail in (2 if reduced else 4):canvas.draw_circle(point-heading*(trail+1)*9.0,maxf(1.0,6.0-trail),Color(color,0.42-float(trail)*0.08))
		if missile.kind=="sling":
			canvas.draw_circle(point,7.0,color);canvas.draw_arc(point,11.0,0,TAU,18,Color(color,0.7),2.0)
		if missile.kind=="trident":
			canvas.draw_line(point-heading*32,point+heading*15,STORM,4,true)
			for side in [-1,1]:
				canvas.draw_polyline(PackedVector2Array([point-heading*3,point+heading*5+heading.orthogonal()*side*11,point+heading*17+heading.orthogonal()*side*11]),STORM,3,true)
			if not reduced:_draw_lightning(canvas,point,28.0)
		elif missile.kind=="sling":
			var window:=float(missile.get("parry_left",-1))
			if missile.returning and window>0:
				canvas.draw_arc(point,10+24*window/rule("parry_window",0.18),0,TAU,24,Color("#72f0df"),2.5,true)
			for tier in int(missile.damage_stacks):canvas.draw_circle(point+Vector2.from_angle(TAU*tier/maxf(1,int(missile.damage_stacks))+visual_clock)*20,2.5,GOLD)
			canvas.draw_arc(point-heading.orthogonal()*8.0,12.0,-1.1,1.1,10,Color(GOLD,0.7),2.0)
			canvas.draw_arc(point+heading.orthogonal()*8.0,12.0,PI-1.1,PI+1.1,10,Color(GOLD,0.7),2.0)
		elif missile.kind in ["archon","umbral"]:
			var metal:=Color("#d9e4ea") if missile.kind=="archon" else Color("#c6a7f0")
			var core_width:=4.0 if missile.kind=="archon" else 2.0
			if missile.kind=="archon":
				var buildup:=clampf(float(missile.speared)/6.0,0,1)
				metal=metal.lerp(Color("#fff2a0"),buildup);core_width+=buildup*2
			canvas.draw_line(point-heading*34,point,metal,core_width,true)
			var head:=PackedVector2Array([point+heading*13,point-heading*5+heading.orthogonal()*7,point-heading*2,point-heading*5-heading.orthogonal()*7])
			canvas.draw_colored_polygon(head,metal)
			canvas.draw_polyline(PackedVector2Array([point-heading*24+heading.orthogonal()*6,point-heading*30,point-heading*24-heading.orthogonal()*6]),color,2,true)
			if missile.kind=="archon" and not reduced:
				for ring in mini(3,int(missile.speared)):canvas.draw_arc(point-heading*(18+ring*13),12+ring*2,heading.angle()-1.4,heading.angle()+1.4,12,Color(GOLD,0.5),2,true)
	if not trident.is_empty() and trident.state=="deployed":
		var point:=to_local(Vector2(trident.position));canvas.draw_line(point+Vector2(0,25),point-Vector2(0,25),STORM,5);canvas.draw_line(point-Vector2(0,25),point+Vector2(-10,-12),STORM,4);canvas.draw_line(point-Vector2(0,25),point+Vector2(10,-12),STORM,4);_draw_lightning(canvas,point,44.0)
	for id in curses:
		var state:Dictionary=curses[id];var enemy:SlasherEnemy=(state.target as WeakRef).get_ref()
		if is_instance_valid(enemy):
			var point:=to_local(enemy.global_position)+Vector2(19,-39);var stacks:=int(state.stacks)
			var alpha:=clampf(float(state.left)/0.4,0,1)
			canvas.draw_arc(point,8,0,TAU,16,Color(PURPLE,alpha),1.5,true)
			if stacks>=int(rule("curse_cap",6)):
				canvas.draw_polyline(PackedVector2Array([point+Vector2(0,-6),point+Vector2(5,0),point+Vector2(0,6),point+Vector2(-5,0),point+Vector2(0,-6)]),Color(0.44,0.93,0.74,alpha),2,true)
			else:
				for i in mini(stacks,6):canvas.draw_circle(point+Vector2.from_angle(TAU*i/maxf(1.0,stacks)-PI/2)*11,2,Color(0.44,0.93,0.74,alpha))
	for id in wounds:
		var state:Dictionary=wounds[id];var enemy:SlasherEnemy=(state.target as WeakRef).get_ref()
		if is_instance_valid(enemy):
			var point:=to_local(enemy.global_position);var stacks:=int(state.stacks)
			for i in stacks:canvas.draw_line(point+Vector2(-12+i*4,-13),point+Vector2(-18+i*4,12),Color("#d54c45"),2.5,true)
	# Pin/slow indicators are enemy-owned and remain truthful after retrieval
	# or weapon swaps; do not add an identical cage to stun-immune targets here.
	for id in leashes:
		var enemy:SlasherEnemy=(leashes[id].target as WeakRef).get_ref()
		if is_instance_valid(enemy):
			var endpoint:=to_local(enemy.global_position);var points:=PackedVector2Array()
			for i in 12:
				var ratio:=float(i)/11.0;points.append(Vector2.ZERO.lerp(endpoint,ratio)+endpoint.orthogonal().normalized()*sin(ratio*18.0-visual_clock*8.0)*6.0)
			canvas.draw_polyline(points,Color("#b29bdd88"),4.0,true)
			canvas.draw_polyline(points,Color(SHADOW,0.9),2.0,true)
			canvas.draw_circle(endpoint*(1-fmod(visual_clock,1.0)),2.5,Color("#cfb9f1"))
			canvas.draw_arc(endpoint,16,0,PI,12,Color("#b29bdd"),2,true)
	if not leashes.is_empty() and actor.velocity.length_squared()>100:
		var stolen:=0.0
		for record in leashes.values():stolen+=float(record.normal_speed)*rule("steal_fraction",0.45)
		var haste:=minf(rule("haste_cap",0.6),stolen/maxf(1,actor.speed))
		if haste>0:
			var behind:=-actor.velocity.normalized()
			for i in (2 if reduced else 3):
				var point:=behind*(14+i*14)*(1+haste)
				canvas.draw_set_transform(point,behind.angle(),Vector2(1+haste,0.45))
				canvas.draw_circle(Vector2.ZERO,12-i*2,Color("#80659e",0.3-float(i)*0.07))
			canvas.draw_set_transform(Vector2.ZERO)
	if frenzy_left>0 and not reduced:
		canvas.draw_arc(Vector2.ZERO,42+sin(visual_clock*12.0)*4.0,0,TAU,36,Color("#e44232"),4)
		for i in 6:canvas.draw_line(Vector2.from_angle(TAU*i/6.0+visual_clock*3.0)*32.0,Vector2.from_angle(TAU*i/6.0+visual_clock*3.0)*54.0,Color("#ff8e45"),3.0,true)
	if rampage_left>0:
		canvas.draw_arc(Vector2.ZERO,48,visual_clock*2.0,visual_clock*2.0+TAU*clampf(rampage_left/maxf(0.01,rule("duration",6)),0,1),36,Color("#bd3349"),3+rampage_stacks)
		for i in rampage_stacks:canvas.draw_circle(Vector2.from_angle(TAU*i/maxf(1.0,rampage_stacks)-visual_clock)*58.0,3.0,Color("#a66cff"))

func _draw_hammer_head(canvas:Node2D,point:Vector2,depth:int)->void:
	# Chain escalation stays local to the weapon, including at reduced quality.
	var strength:=clampf(float(depth)/maxf(1,rule("chain_cap",8)),0,1)
	canvas.draw_rect(Rect2(point-Vector2(20,10),Vector2(40,20)),Color("#b5a264").lerp(Color("#fff1b2"),strength))
	canvas.draw_rect(Rect2(point-Vector2(20,10),Vector2(40,20)),Color("#fff1c1"),false,2)
	var runes:=1+mini(3,maxi(0,depth))
	for index in runes:
		var center:=point+Vector2((index-(runes-1)*0.5)*8,0)
		canvas.draw_line(center-Vector2(0,6),center+Vector2(0,6),Color.WHITE,2)
		canvas.draw_line(center-Vector2(2,2),center+Vector2(2,0),Color.WHITE,1.5,true)

func _draw_melee_silhouette(canvas:Node2D,angle:float,reach:float,tint:Color)->void:
	canvas.draw_set_transform(Vector2.ZERO,angle)
	match weapon_id:
		"storm_trident":
			canvas.draw_line(Vector2(15,0),Vector2(reach-12,0),Color("#426978"),5,true)
			canvas.draw_line(Vector2(reach-45,0),Vector2(reach,0),STORM,3,true)
			for side in [-1,1]:
				canvas.draw_polyline(PackedVector2Array([Vector2(reach-35,0),Vector2(reach-24,side*10),Vector2(reach,side*10)]),STORM,3,true)
		"eldritch_bowstaff":
			canvas.draw_line(Vector2(15,0),Vector2(reach,0),Color("#332c42"),8,true)
			canvas.draw_line(Vector2(15,-2),Vector2(reach,-2),tint,2,true)
			for i in 5:
				var x:=lerpf(30,reach-12,float(i)/4)
				canvas.draw_line(Vector2(x,-5),Vector2(x+3,5),Color("#8ee6b5"),2,true)
			canvas.draw_circle(Vector2(reach,0),7,Color("#91f3c5"))
		"grim_reaver":
			canvas.draw_line(Vector2(15,0),Vector2(reach-14,0),Color("#5a486f"),6,true)
			var blade:=PackedVector2Array([Vector2(reach-26,0),Vector2(reach-10,-9),Vector2(reach,-27),Vector2(reach-8,-49),Vector2(reach-32,-67),Vector2(reach-12,-27),Vector2(reach-31,8)])
			canvas.draw_colored_polygon(blade,Color("#cec6e3"));canvas.draw_polyline(blade,tint,2,true)
			var soul_points:=PackedVector2Array([Vector2(reach-24,0),Vector2(reach-15,-10),Vector2(reach-8,-22),Vector2(reach-7,-33),Vector2(reach-12,-45),Vector2(reach-21,-56)])
			var soul_alpha:=clampf(rampage_left,0,1)
			for index in mini(rampage_stacks,soul_points.size()):
				var point:=soul_points[index]
				canvas.draw_circle(point,3,Color("#593176",soul_alpha))
				canvas.draw_circle(point,1.8+sin(visual_clock*5+index)*0.3,Color("#b6ffbf",soul_alpha))
		"dragonbone_dagger","demon_blade":
			var grip:=reach*0.35
			canvas.draw_line(Vector2(15,0),Vector2(grip,0),Color("#483647"),6,true)
			var blade:=PackedVector2Array([Vector2(grip,-7),Vector2(reach-18,-5),Vector2(reach,0),Vector2(reach-18,7),Vector2(grip,7)])
			canvas.draw_colored_polygon(blade,Color("#eee1c6") if weapon_id=="dragonbone_dagger" else Color("#682e3c"))
			canvas.draw_line(Vector2(grip,-7),Vector2(reach,0),tint,2,true)
			canvas.draw_line(Vector2(grip,-12),Vector2(grip,12),Color("#c2a66e"),4,true)
			if weapon_id=="demon_blade" and actor.fighter_frenzy_left>0:
				var glow:=clampf(actor.fighter_frenzy_left,0,1)
				for index in 3:
					var x:=lerpf(grip+10,reach-22,float(index)/2)
					canvas.draw_polyline(PackedVector2Array([Vector2(x-3,-5),Vector2(x+2,-1),Vector2(x-2,2),Vector2(x+3,5)]),Color(1,0.35,0.2,glow),2,true)
		_:
			canvas.draw_line(Vector2(15,0),Vector2(reach,0),tint,4,true)
			canvas.draw_polyline(PackedVector2Array([Vector2(reach-16,-9),Vector2(reach,0),Vector2(reach-16,9)]),tint,3,true)
	canvas.draw_set_transform(Vector2.ZERO)

func _draw_lightning(canvas:Node2D,center:Vector2,radius:float)->void:
	for branch in 3:
		var points:=PackedVector2Array([center]);var ray:=Vector2.from_angle(TAU*branch/3.0+visual_clock*2.4)
		for step in range(1,5):points.append(center+ray*radius*step/4.0+ray.orthogonal()*sin(step*5.1+visual_clock*18.0+branch)*5.0)
		canvas.draw_polyline(points,Color(STORM,0.8),2.0,true)
