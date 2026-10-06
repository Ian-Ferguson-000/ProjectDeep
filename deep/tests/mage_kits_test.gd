extends SceneTree

const GROUND := preload("res://scenes/slasher/TestingGround.tscn")
const KITS := preload("res://scripts/slasher/slasher_mage_kits.gd")
const HOSTILE := preload("res://scripts/slasher/slasher_hostile_projectile.gd")
var failures: Array[String] = []
var ground: Node

func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:failures.append(message)

func equip(id: String, mode: String = "cluster", level: int = 1, branch: int = 0, variant: int = 0, foundation: int = 1) -> void:
	ground.class_picker.select(1);ground._refresh_class()
	for index in ground.gear_options.size():
		if ground.gear_options[index].id==id:ground.gear_picker.select(index)
	ground.level_picker.value=level;ground.foundation_picker.select(foundation if level==20 else 0);ground.branch_picker.select(branch)
	for picker in ground.upgrade_pickers:picker.select(variant)
	for checkbox in ground.loot_checks.values():checkbox.button_pressed=false
	ground.dummy_mode=mode;ground.apply_build();ground.set_editor_visible(false)
	check(ground.details.text.contains(KITS.description(id)),"Build editor must describe the selected Mage kit")
	await physics_frame;await process_frame
	ground.player.set_physics_process(false);ground.player.mage_kit.set_physics_process(false)
	# This suite measures standalone spells; combo payloads are covered separately.
	ground.player.combo_runtime.recipes.clear();ground.player.combo_runtime.states.clear()

func targets() -> Array[SlasherEnemy]:
	var result: Array[SlasherEnemy]=[]
	for child in ground.combat_root.get_children():
		if child is SlasherEnemy:result.append(child)
	return result

func primary_hit(target: SlasherEnemy) -> void:
	for child in ground.combat_root.get_children():
		if child is SlasherProjectile:
			child.global_position=target.global_position
			child._damage_impact(target);ground.combat_root.remove_child(child);child.queue_free()

func shot_at(point: Vector2, direction: Vector2) -> SlasherHostileProjectile:
	var shot := HOSTILE.new().setup(targets()[0],ground.player,point,direction,3,{"projectile_speed":300,"projectile_range":800})
	ground.combat_root.add_child(shot);shot.set_physics_process(false)
	return shot

func run() -> void:
	ground=GROUND.instantiate();root.add_child(ground);await process_frame
	check(ground.class_picker.item_count==6,"Class roster changed")
	for script in KITS.SCRIPTS:
		for level in [1,20]:
			for branch in ([0] if level==1 else [1,2,3]):
				for variant in ([0] if level==1 else [1,2]):
					for foundation in ([0] if level==1 else [1,2,3]):
						await equip(script.GEAR_ID,"single",level,branch,variant,foundation)
						var standard: Dictionary=ground.state.get_effective_slasher_ability_tuning("basic")
						var alternate: Dictionary=ground.player._ability_tuning("basic")
						var rate := float(ground.player._scaled_damage(alternate))/float(alternate.cooldown)
						var baseline := float(ground.player._scaled_damage(standard))/float(standard.cooldown)
						check(rate>=baseline if script.GEAR_ID!=KITS.WINTERGLASS.GEAR_ID else float(alternate.damage_coefficient)<float(standard.damage_coefficient)*0.5,"%s loses standard direct damage pace at level %d, branch %d variant %d"%[script.GEAR_ID,level,branch,variant])
						check(float(ground.player._ability_tuning("special").cooldown)<=1.2,"Slow special: "+script.GEAR_ID)
						check(float(ground.player._ability_tuning("movement").cooldown)<=0.8,"Slow movement: "+script.GEAR_ID)
						for slot in ["basic","special","defensive","movement"]:check(not ground.player._action_name(slot).is_empty(),"Missing action name")
	print("Mage tuning retains progression scaling, including deliberately reduced Winterglass primary damage")
	await test_storm()
	await test_winter()
	await test_gravity()
	await test_mirror()
	await test_revisions()
	await test_editor_pause()
	ground.queue_free();await process_frame;await process_frame
	if failures.is_empty():print("Mage kits: PASS")
	else:
		for message in failures:push_error(message)
	quit(0 if failures.is_empty() else 1)

func test_storm() -> void:
	await equip(KITS.STORMBRINGER.GEAR_ID)
	var player: SlasherPlayer=ground.player;var kit: Node=player.mage_kit
	var enemy := targets()[0]
	player.aim_direction=player.global_position.direction_to(enemy.global_position);ground.state.class_resource=0
	check(player.use_action("basic").started,"Unconducted Spark failed")
	check(kit.last_chain.size()==3,"Spark must bounce without a conductor")
	check(kit.last_chain[1].damage<kit.last_chain[0].damage and kit.last_chain[2].damage<kit.last_chain[1].damage,"Unconducted bounces must lose damage")
	check(ground.state.class_resource==1,"Chain must award Mana only once")
	ground.state.class_resource=3;check(player.use_action("special").started,"Grounding Rod failed")
	check(ground.state.class_resource==2 and not kit.conductor.is_empty(),"Rod must cost one Mana")
	player.cooldowns.basic=0;player.use_action("basic")
	check(kit.last_chain.size()==3 and kit.last_chain[0].damage==kit.last_chain[1].damage and kit.last_chain[1].damage==kit.last_chain[2].damage,"An active conductor must remove bounce falloff")
	var remaining: float=kit.conductor.left
	player.cooldowns.movement=0;check(player.use_action("movement").started,"Flash Circuit failed")
	check(is_equal_approx(kit.conductor.left,remaining),"Circuit movement must not refresh the conductor lifetime")
	player.aim_direction=Vector2.RIGHT;player.cooldowns.defensive=0;player.use_action("defensive");ground.state.class_resource=0
	var blocked: Array[SlasherHostileProjectile]=[]
	for index in 4:blocked.append(shot_at(player.global_position+Vector2(50+index*8,0),Vector2.LEFT))
	kit._physics_process(0.01)
	var count := 0
	for shot in blocked:count+=int(shot.impacted)
	check(count==3 and ground.state.class_resource==1 and kit.conductor.charged,"Screen must block three shots, award once, and charge a live rod")
	player.invulnerable=0;player.receive_damage(2,Vector2.ZERO)
	check(ground.state.class_resource==1,"Screen mitigation must not duplicate its resource award")
	kit.conductor.center=enemy.global_position
	var pulse_before: int=enemy.total_damage
	var charged_damage: int=int(round(int(kit.conductor.attack.damage)*1.5))
	kit._physics_process(0.2)
	check(enemy.total_damage-pulse_before==charged_damage and not kit.conductor.charged and ground.state.class_resource==1,"Charged conductor must pay out once without secondary Mana")
	for shot in blocked:
		if not shot.impacted:shot._finish()
	player.cooldowns.defensive=0;player.use_action("defensive");ground.state.class_resource=0;player.invulnerable=0;player.receive_damage(2,Vector2.ZERO)
	shot_at(player.global_position+Vector2(50,0),Vector2.LEFT);kit._physics_process(0.01)
	check(kit.conductor.charged and ground.state.class_resource==1,"The first shot must still charge the rod after mitigation already awarded Mana")
	kit._physics_process(5.1)
	check(kit.conductor.is_empty(),"Rod must expire")
	player.global_position=Vector2(-180,100);player.aim_direction=player.global_position.direction_to(enemy.global_position);player.cooldowns.basic=0;player.use_action("basic")
	check(kit.last_chain[1].damage<kit.last_chain[0].damage,"Falloff must return after conductor expiry")
	for point in [Vector2(310,65),Vector2(370,-25)]:
		var extra: SlasherEnemy=ground.DUMMY.new();extra.configure(1);extra.position=point;extra.max_health=1000;extra.health=1000;ground.combat_root.add_child(extra)
	player.cooldowns.basic=0;player.use_action("basic")
	check(kit.last_chain.size()==4,"Chains must stop after four distinct targets")
	var visited: Dictionary = {}
	for link in kit.last_chain:visited[link.enemy.get_ref().get_instance_id()]=true
	check(visited.size()==kit.last_chain.size(),"Chains must not revisit targets")
	await equip(KITS.STORMBRINGER.GEAR_ID,"single")
	player=ground.player;kit=player.mage_kit;enemy=targets()[0]
	player.global_position=Vector2(-100,0);player.aim_direction=Vector2.RIGHT
	var extra: SlasherEnemy=ground.DUMMY.new();extra.configure(1);extra.position=Vector2(280,0);extra.max_health=1000;extra.health=1000;ground.combat_root.add_child(extra)
	var obstacle := StaticBody2D.new();var shape := CollisionShape2D.new();var rectangle := RectangleShape2D.new();rectangle.size=Vector2(10,180);shape.shape=rectangle;obstacle.add_child(shape);obstacle.position=Vector2(200,0);ground.combat_root.add_child(obstacle)
	await physics_frame;await process_frame
	player.use_action("basic")
	check(kit.last_chain.size()==1,"Lightning must not bounce through a solid wall")
	ground.combat_root.remove_child(obstacle);obstacle.queue_free()
	await physics_frame;await process_frame
	var boundary: Vector2=kit.get_canvas_transform().affine_inverse()*Vector2(kit.get_viewport_rect().size.x,kit.get_viewport_rect().size.y/2)
	player.global_position=boundary-Vector2(300,0);enemy.global_position=boundary-Vector2(80,0);extra.global_position=boundary+Vector2(60,0)
	player.cooldowns.basic=0;player.use_action("basic")
	check(kit.last_chain.size()==1,"Lightning must not target an offscreen bounce recipient")

func test_winter() -> void:
	await equip(KITS.WINTERGLASS.GEAR_ID)
	var player: SlasherPlayer=ground.player;var kit: Node=player.mage_kit;var enemy := targets()[0]
	for cast in 3:player.cooldowns.basic=0;player.use_action("basic");primary_hit(enemy)
	check(kit.chills[enemy.get_instance_id()].stacks==3 and is_equal_approx(enemy.movement_slow,0.7),"Needles must stack three Chill levels")
	player.global_position=enemy.global_position-Vector2(160,0);player.aim_direction=Vector2.RIGHT
	var before: int=enemy.total_damage;ground.state.class_resource=3
	player.use_action("special");kit._physics_process(0.17)
	check(enemy.total_damage-before==int(round(player._scaled_damage(kit.tuning("special"))*1.6)),"Three Chill stacks must add 60% to Fracture")
	check(not kit.chills.has(enemy.get_instance_id()) and is_equal_approx(enemy.movement_slow,1),"Fracture must consume owned Chill")
	player.global_position=Vector2(-180,100);player.aim_direction=Vector2.RIGHT
	var mask: int=enemy.collision_mask
	check(player.use_action("defensive").started and not kit.wall.is_empty(),"Icebook Wall failed")
	check(enemy.collision_mask==(mask|8) and (player.collision_mask&8)==0 and not kit.blocked_cells.is_empty(),"Wall must block enemies, update navigation, and allow friendly movement")
	var navigation: SlasherGridPathfinder=enemy.pathfinder
	var route := navigation.find_cell_path(navigation.world_to_cell(enemy.global_position),navigation.world_to_cell(player.global_position))
	check(not route.is_empty(),"Enemies must retain a navigable route around the wall")
	for cell in route:check(not kit.blocked_cells.has(cell),"Navigation must not route through the ice wall")
	ground.state.class_resource=0
	var shot := shot_at(Vector2(kit.wall.center)+Vector2(20,0),Vector2.LEFT)
	kit._physics_process(0.1);check(shot.impacted and ground.state.class_resource==1,"Wall must block a crossing shot and grant one Mana")
	var next := shot_at(Vector2(kit.wall.center)+Vector2(20,0),Vector2.LEFT)
	kit._physics_process(0.1);check(next.impacted and ground.state.class_resource==1,"Repeated blocks must not farm Mana")
	var friendly := SlasherProjectile.new().setup(player,Vector2(kit.wall.center)-Vector2(40,0),Vector2.RIGHT,{"damage":1,"range":360,"speed":500})
	ground.combat_root.add_child(friendly);friendly.set_physics_process(false);friendly._physics_process(0.15)
	check(not friendly.impacted,"The wall must allow friendly projectiles")
	kit._physics_process(2.1)
	check(kit.wall.is_empty() and enemy.collision_mask==mask,"Wall expiry must restore collision masks")
	player.cooldowns.defensive=0;player.use_action("defensive")
	await equip(KITS.WINTERGLASS.GEAR_ID,"boss")
	player=ground.player;kit=player.mage_kit;enemy=targets()[0]
	for cast in 3:player.cooldowns.basic=0;player.use_action("basic");primary_hit(enemy)
	check(kit.chills[enemy.get_instance_id()].stacks==3 and is_equal_approx(enemy.movement_slow,1),"Bosses retain Fracture stacks without movement slow")
	player.global_position=enemy.global_position-Vector2(160,0);player.aim_direction=Vector2.RIGHT
	before=enemy.total_damage;player.use_action("special");kit._physics_process(0.17)
	check(enemy.total_damage>before and enemy.hit_stun_timer==0 and not enemy.dead,"Boss Fracture must respect durability without stagger locking")

func test_gravity() -> void:
	await equip(KITS.GRAVITY.GEAR_ID,"single")
	var player: SlasherPlayer=ground.player;var kit: Node=player.mage_kit;var enemy := targets()[0]
	ground.state.class_resource=0;player.use_action("basic")
	check(kit.pending_stones.size()==1,"Stone must have a short launch delay")
	kit._physics_process(0.11);primary_hit(enemy)
	check(enemy.total_damage>0 and ground.state.class_resource==1,"Stone must damage and award Mana without a well")
	ground.state.class_resource=3;player.use_action("special");kit.well.center=enemy.global_position+Vector2(60,0)
	var distance: float=enemy.global_position.distance_to(kit.well.center)
	kit._physics_process(0.1)
	check(enemy.global_position.distance_to(kit.well.center)<distance,"Collapse must pull ordinary enemies")
	var damage: int=enemy.total_damage;kit._physics_process(0.4)
	check(kit.well.is_empty() and enemy.total_damage>damage,"Collapse must resolve its burst once")
	player.use_action("defensive");var shot := shot_at(player.global_position+Vector2(30,0),Vector2.LEFT)
	kit._physics_process(0.01);check(is_equal_approx(shot.speed,150),"Heavy Air must halve projectile speed")
	shot.global_position=player.global_position+Vector2(300,0);kit._physics_process(0.01)
	check(is_equal_approx(shot.speed,300),"Projectiles must recover speed outside Heavy Air")
	shot.global_position=player.global_position+Vector2(30,0);kit._physics_process(0.01);kit._physics_process(0.7)
	check(is_equal_approx(shot.speed,300),"Heavy Air expiry must restore projectile speed")
	player.cooldowns.defensive=0;player.use_action("defensive");kit._physics_process(0.01)
	var before := player.global_position;var mana: int=ground.state.class_resource
	player.aim_direction=Vector2.RIGHT;player.use_action("movement")
	check(not kit.anchor.is_empty(),"Anchor Exchange must leave a return point")
	player.cooldowns.movement=0;player.use_action("movement")
	check(player.global_position.is_equal_approx(before) and kit.anchor.is_empty() and ground.state.class_resource==mana,"Anchor return must be free, exact, and consume its anchor")
	ground.apply_build();check(is_equal_approx(shot.speed,300),"Reset must restore slowed projectiles before discarding the old scene")
	await equip(KITS.GRAVITY.GEAR_ID,"boss")
	player=ground.player;kit=player.mage_kit;enemy=targets()[0];before=enemy.global_position
	player.use_action("special");kit.well.center=enemy.global_position;kit._physics_process(0.5)
	check(enemy.global_position.is_equal_approx(before) and enemy.total_damage>0 and not enemy.dead,"Bosses must take Collapse damage without being pulled")

func test_mirror() -> void:
	await equip(KITS.MIRRORBOUND.GEAR_ID)
	var player: SlasherPlayer=ground.player;var kit: Node=player.mage_kit;var enemy := targets()[0]
	player.aim_direction=Vector2.RIGHT;var origin := player.global_position
	player.use_action("movement");player.use_action("basic")
	check(kit.mirror.center==origin and kit.recording.direction==Vector2.RIGHT,"Mirror must keep the departure origin and record aim")
	ground.state.class_resource=3;player.use_action("special")
	check(kit.recording.is_empty() and kit.pending_replays.size()==1 and ground.state.class_resource==2,"Read Again must consume one recording for one Mana")
	kit._physics_process(0.13)
	var replay: SlasherProjectile
	for child in ground.combat_root.get_children():
		if child is SlasherProjectile and child.attack.get("damage_source","")=="Replay":replay=child
	check(replay!=null and replay.global_position==origin and replay.direction==Vector2.RIGHT,"Replay must launch from the mirror along recorded aim")
	if replay!=null:
		replay._damage_impact(enemy)
		check(ground.state.class_resource==2 and kit.recording.is_empty(),"Replay must not award Mana or record another replay")
	player.cooldowns.basic=0;player.use_action("basic");player.invulnerable=0
	player.use_action("defensive");var health: int=player.health;player.receive_damage(1,Vector2.ZERO)
	check(kit.recording.is_empty() and kit.barrier==1 and player.health==health,"Blank Page must trade the recording for a bounded barrier without healing")
	player.receive_damage(3,Vector2.ZERO)
	check(kit.barrier==0 and player.health==health-2,"Barrier must absorb only its available amount")
	player.cooldowns.basic=0;player.use_action("basic");player.cooldowns.defensive=0;player.use_action("defensive");player.receive_damage(1,Vector2.ZERO)
	kit._physics_process(2.1);check(kit.barrier==0,"Mirror barriers must expire")
	kit._physics_process(5.1);check(kit.mirror.is_empty() and kit.recording.is_empty(),"Expired mirrors must clear recordings")
	player.cooldowns.special=0;player.use_action("special")
	var self_shot := false
	for child in ground.combat_root.get_children():
		if child is SlasherProjectile and child.attack.get("damage_source","")=="Read Again" and not child.attack.get("mage_secondary",false):self_shot=true
	check(kit.pending_replays.is_empty() and self_shot,"Read Again must remain a standalone self shot when no mirror exists")

func test_editor_pause() -> void:
	for script in [KITS.WINTERGLASS,KITS.STORMBRINGER,KITS.GRAVITY,KITS.MIRRORBOUND]:
		await equip(script.GEAR_ID)
		var player: SlasherPlayer=ground.player;var kit: Node=player.mage_kit
		player.use_action("special");player.use_action("movement")
		kit.set_physics_process(true)
		ground.set_editor_visible(true)
		var snapshot: float=kit.clock
		for frame in 3:await physics_frame
		check(is_equal_approx(kit.clock,snapshot),"Editor must pause every Mage kit's timers: "+script.GEAR_ID)
		ground.set_editor_visible(false)
		await physics_frame;await process_frame
		check(kit.clock>snapshot,"Closing the editor must resume kit timers: "+script.GEAR_ID)

func test_revisions() -> void:
	await equip(KITS.PYROMANCY.GEAR_ID,"single")
	var player: SlasherPlayer=ground.player;var kit: Node=player.mage_kit
	var start := player.global_position
	player.aim_direction=Vector2.RIGHT;player.use_action("movement")
	player.cooldowns.movement=0;player.aim_direction=Vector2.DOWN;player.use_action("movement")
	check(kit.trails.size()==2,"Multiple dashes must preserve both unlit Cinder Trails")
	kit.ignite_at(start,10)
	check(kit.patches.size()>=8,"Cinder flames must cover the whole first dash")
	kit.ignite_at(player.global_position,10)
	check(kit.patches.size()>8 and kit.trails.is_empty(),"Burning trails must stack instead of evicting previous flames")
	var first_flames: int=kit.patches.size()
	player.cooldowns.movement=0;player.aim_direction=Vector2.LEFT;player.use_action("movement")
	player.cooldowns.special=0;ground.state.class_resource=3;player.use_action("special")
	kit.detonations[0].center=player.global_position
	kit._physics_process(0.29)
	check(kit.trails.is_empty() and kit.patches.size()>first_flames,"Conflagration must ignite a new trail without removing remote flames")
	await equip(KITS.PYROMANCY.GEAR_ID,"single")
	player=ground.player;kit=player.mage_kit
	var enemy := targets()[0]
	player.global_position=enemy.global_position-Vector2(125,0)
	player.use_action("defensive")
	check(kit.burns.has(enemy.get_instance_id()),"Furnace must immediately burn nearby foes without an incoming hit")
	player.invulnerable=0;player.receive_damage(2,Vector2.ZERO)
	kit.burns.clear();kit._physics_process(0.1)
	check(kit.burns.has(enemy.get_instance_id()),"Furnace aura must persist after next-hit mitigation is consumed")
	# Generic fire hits with no caster must also ignite the full trail.
	kit.trails.append({"a":enemy.global_position-Vector2(90,0),"b":enemy.global_position+Vector2(90,0),"left":4.0,"id":99})
	enemy.receive_attack({"damage":1,"damage_type":"fire"})
	check(kit.trails.is_empty() and kit.patches.size()>=6,"Environmental fire must ignite trails without a Pyromancer projectile tag")
	kit.burns.clear();kit.mantle_left=0
	var damage_before: int=enemy.total_damage
	kit._physics_process(0.01)
	check(enemy.total_damage-damage_before==int(round(player.spell_power*2.5)),"Overlapping flame tiles of one trail must only deal one tick")
	await equip(KITS.STORMBRINGER.GEAR_ID,"single")
	player=ground.player;kit=player.mage_kit
	for index in 4:
		player.cooldowns.special=0;ground.state.class_resource=3;player.use_action("special")
		kit.rods.back().center=Vector2(50+index*80,20)
	check(kit.rods.size()==3 and kit.rods[0].center==Vector2(130,20),"Fourth rod must replace only the oldest of three")
	var click := player.get_global_mouse_position()
	var closest: Dictionary=kit.rods[0]
	for rod in kit.rods:
		if Vector2(rod.center).distance_to(click)<Vector2(closest.center).distance_to(click):closest=rod
	var destination: Vector2=closest.center
	var lifetime: float=closest.left
	player.use_action("movement")
	check(player.global_position.distance_to(destination)<1 and closest.left==lifetime and closest.center==destination,"Flash Circuit must arrive at the rod nearest the clicked point without shifting/refilling it")
	await equip(KITS.MIRRORBOUND.GEAR_ID,"single")
	player=ground.player;kit=player.mage_kit
	player.aim_direction=Vector2.RIGHT;player.use_action("movement");player.use_action("basic")
	var main: SlasherProjectile;var lesser: SlasherProjectile
	for child in ground.combat_root.get_children():
		if child is SlasherProjectile:
			if child.attack.get("damage_source","")=="Reflection":lesser=child
			if child.attack.get("damage_source","")=="Script":main=child
	check(main!=null and lesser!=null,"Silver Script must fire from both Mage and live reflection")
	if main!=null and lesser!=null:
		check(lesser.global_position==kit.mirror.center and lesser.direction==main.direction and lesser.attack.damage==int(round(main.attack.damage*0.5)),"Reflection must fire a half-strength basic along the same aim")
		ground.state.class_resource=0;lesser._damage_impact(targets()[0])
		check(ground.state.class_resource==0 and not kit.recording.is_empty(),"Lesser reflection shots must not grant Mana or consume/change recordings")
	await equip(KITS.WINTERGLASS.GEAR_ID,"single")
	player=ground.player;kit=player.mage_kit
	player.aim_direction=Vector2.RIGHT;var origin := player.global_position
	player.use_action("movement")
	check(kit.frozen_fields.size()==1 and kit.frozen_fields[0].left==5 and is_equal_approx(kit.movement_speed_multiplier(),1.4),"Retreat must leave five-second terrain and increase caster speed")
	player.global_position=origin;ground.state.class_resource=3;player.use_action("special");kit._physics_process(0.17)
	check(kit.frozen_fields.size()==2 and kit.frozen_fields[1].kind=="cone" and kit.frozen_fields[1].left==5,"Fracture must freeze its cone for five seconds")
	player.global_position=origin+Vector2(100,0)
	check(is_equal_approx(kit.movement_speed_multiplier(),1.4),"Caster must skate across the Fracture floor")
	player.global_position=origin+Vector2(0,200)
	check(is_equal_approx(kit.movement_speed_multiplier(),1),"Walking speed must return to normal off ice")
	kit._physics_process(5.1)
	check(kit.frozen_fields.is_empty(),"All frozen terrain must expire independently")
	var victim := SlasherEnemy.new();victim.configure(1);victim.health=1;ground.combat_root.add_child(victim);victim.global_position=origin;victim.set_physics_process(false)
	ground.state.class_resource=0
	victim.receive_attack({"damage":2,"damage_type":"ice"},player)
	var shards: Array[SlasherProjectile]=[]
	for child in ground.combat_root.get_children():
		if child is SlasherProjectile and child.attack.get("damage_source","")=="Shatter":shards.append(child)
	check(shards.size()==8 and ground.state.class_resource==0,"A cold killing blow must emit eight radial needles without Mana")
	victim.receive_attack({"damage":2,"damage_type":"ice"},player)
	var again := 0
	for child in ground.combat_root.get_children():
		if child is SlasherProjectile and child.attack.get("damage_source","")=="Shatter":again+=1
	check(again==8,"A corpse must shatter only once")
	var chained := SlasherEnemy.new();chained.configure(1);chained.health=1;ground.combat_root.add_child(chained);chained.global_position=origin+Vector2(80,0);chained.set_physics_process(false)
	if not shards.is_empty():shards[0]._damage_impact(chained)
	again=0
	for child in ground.combat_root.get_children():
		if child is SlasherProjectile and child.attack.get("damage_source","")=="Shatter":again+=1
	check(again==16 and ground.state.class_resource==0,"Cold shatter needles must propagate through cold kills without resource recursion")
