extends SceneTree

const IDS:=["michaels_orb","gulthias_staff","skyblinder_staff","dragonstaff_of_ahghairon","jade_serpent_staff","arachne_staff","tome_of_toth","shangos_shatterer","solar_scepter","drumamus_bargain"]
var failures:Array[String]=[]
var world:Node2D
var player:SlasherPlayer
var state:RunState
var runtime:SlasherMageActiveArsenal
var checks:=0

func _initialize()->void:_run.call_deferred()
func _expect(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);printerr("FAIL: "+message)

func _fixture()->void:
	world=Node2D.new()
	root.add_child(world)
	state=RunState.new()
	state.start_new_run(GearData.create("mage_test","Mage Tester",3,false,0,"","","mage"),"forest")
	player=SlasherPlayer.new()
	player.setup(state)
	world.add_child(player)
	player.set_physics_process(false)
	player.aim_direction=Vector2.RIGHT
	player.spell_power=10
	player.attack_power=10
	player.invulnerable=0
	player.position=Vector2(400,400)
	player.sprite.hide()

func _equip(id:String)->SlasherMageActiveArsenal:
	ActiveItems.give(state,id)
	runtime=SlasherActiveEffects.ensure_runtime(player,id)
	runtime.set_physics_process(false)
	runtime.set_process(false)
	runtime._refresh_targets()
	return runtime

func _enemy(offset:Vector2,hp:int=10000)->SlasherEnemy:
	var foe:=SlasherEnemy.new()
	foe.configure(1,false,"bandit_cutthroat")
	foe.target=player
	foe.position=player.position+offset
	world.add_child(foe)
	foe.set_physics_process(false)
	foe.sprite.hide()
	foe.health=hp
	foe.max_health=hp
	foe.collision_layer=2
	return foe

func _advance(seconds:float)->void:
	for i in ceili(seconds*60.0):runtime._step(1.0/60.0)

func _clear()->void:
	world.queue_free()
	await process_frame
	await process_frame

func _run()->void:
	_fixture()
	var foe:=_enemy(Vector2(140,0))
	_equip("michaels_orb").activate()
	for i in 12:runtime.on_external_hit(foe,{"attack_id":"pierce","action_slot":"basic"},false)
	_expect(runtime.orb_energy==1,"Orb accepted more than one contribution from a piercing attack")
	runtime.on_external_hit(foe,{"attack_id":"special","action_slot":"special"},false)
	runtime.on_external_hit(foe,{"attack_id":"self","action_slot":"basic","mage_secondary":true},false)
	_expect(runtime.orb_energy==1,"Orb charged from a special or secondary explosion")
	for i in 2:runtime.on_external_hit(foe,{"attack_id":"basic%d"%i,"action_slot":"basic"},false)
	_expect(runtime.orb_energy==0 and runtime.missiles.size()==1,"Three distinct basic hits did not discharge")
	_advance(1.0)
	_expect(foe.health<10000 and runtime.orb_energy==0,"Orb did not impact or recursively recharged itself")
	runtime.cancel()
	foe.queue_free()
	await process_frame
	runtime.active_time=45
	runtime.orb_energy=3
	runtime._refresh_targets()
	runtime._try_orb()
	_expect(runtime.orb_energy==3 and runtime.missiles.is_empty(),"Empty room consumed a ready orb")
	foe=_enemy(Vector2(140,0))
	runtime._refresh_targets()
	runtime._try_orb()
	_expect(runtime.orb_energy==0 and runtime.missiles.size()==1,"Ready orb did not reacquire a newly available enemy")
	for i in 8:_enemy(Vector2(160+i*35,(i%2)*50))
	runtime._refresh_targets()
	runtime._launch_orb(foe)
	_advance(6)
	_expect(runtime.missiles.is_empty(),"Orb exceeded impact/lifespan limits")
	await _clear()

	_fixture()
	foe=_enemy(Vector2(140,0),1)
	_equip("gulthias_staff").activate()
	_expect(foe.health==1,"Gulthias dealt invisible instantaneous damage")
	_advance(0.6)
	_expect(runtime.plants.size()==1,"Gulthias bolt kill did not plant a seed")
	_advance(0.8)
	runtime.activate()
	_advance(0.6)
	_expect(runtime.plants.is_empty() and runtime.treants.size()==1,"Mature growth did not awaken from a second staff bolt")
	for i in 30:runtime._spawn_foliage(player.position+Vector2(200,i));runtime.spawn_treant(player.position+Vector2(100,i))
	_expect(runtime.plants.size()==12 and runtime.treants.size()==6,"Gulthias population caps failed")
	foe=_enemy(Vector2(110,0))
	runtime._refresh_targets()
	_advance(1.5)
	_expect(foe.health<10000,"Treants did not wind up and stomp")
	_advance(22)
	_expect(runtime.plants.is_empty() and runtime.treants.is_empty(),"Expired vegetation/summons persisted")
	await _clear()

	_fixture()
	foe=_enemy(Vector2(160,0))
	_equip("skyblinder_staff").activate()
	runtime.channel_held=true
	_advance(0.1)
	runtime.channel_held=false
	_advance(0.6)
	var quick_damage:=10000-foe.health
	_expect(quick_damage>0 and foe.disorient_time>0,"Quick Skyblinder shot did not disrupt tracking")
	foe.health=10000
	var adjacent:=_enemy(Vector2(160,65))
	runtime.activate()
	runtime.channel_held=true
	_advance(2.1)
	_expect(runtime.charge_time==2.0 and runtime._full_charge_cue,"Full charge did not reach a visible/audio-ready state")
	runtime.channel_held=false
	_advance(0.7)
	_expect(10000-foe.health>quick_damage and adjacent.health<10000 and adjacent.mage_stun_remaining()>=1,"Charged light did not scale damage, radius and stun")
	runtime.activate();runtime.channel_held=true;_advance(0.5);runtime.cancel()
	_expect(runtime.charge_time==0 and runtime.missiles.is_empty(),"Interrupted light retained a stored shot")
	await _clear()

	_fixture()
	foe=_enemy(Vector2(140,0))
	_equip("dragonstaff_of_ahghairon").activate()
	runtime.channel_held=true
	_advance(0.7)
	_expect(foe.health<10000 and float(runtime.heat[foe.get_instance_id()].burn)>0,"Dragonfire failed to build heat and ignite")
	var fuel:=runtime.dragon_fuel
	foe.receive_attack({"damage":100000,"damage_source":"basic"},player)
	_advance(0.5)
	_expect(runtime.dragon_fuel>fuel and runtime.remains.is_empty(),"Burning death did not produce one harvestable fuel source")
	fuel=runtime.dragon_fuel
	_advance(0.3)
	_expect(runtime.dragon_fuel<fuel,"Corpse was harvested repeatedly")
	runtime.channel_held=false;_advance(0.1)
	runtime.dragon_fuel=0
	_advance(2)
	_expect(runtime.dragon_fuel>0,"Empty fuel did not regenerate")
	await _clear()

	_fixture()
	foe=_enemy(Vector2(140,0))
	adjacent=_enemy(Vector2(220,45))
	var unmarked:=_enemy(Vector2(180,-50))
	_equip("jade_serpent_staff").activate()
	_advance(0.6)
	_expect(runtime.marked.has(foe.get_instance_id()) and foe.health<10000,"Jade dart did not mark and damage its target")
	runtime._mark_poison(adjacent)
	for i in 20:runtime._mark_poison(adjacent)
	_expect(int(runtime.poison[adjacent.get_instance_id()].stacks)==1,"Poison exceeded configured stack cap")
	foe.receive_attack({"damage":100000,"damage_source":"basic"},player)
	_expect(runtime.missiles.size()==1,"Marked death did not release one serpent")
	_advance(1.2)
	_expect(adjacent.health<10000 and unmarked.health==10000,"Serpent did not restrict bites to marked prey")
	_expect(runtime.missiles.is_empty(),"Serpent revisited a target")
	runtime._mark_poison(adjacent)
	var freed_id:=adjacent.get_instance_id()
	runtime._launch_snake(player.position)
	adjacent.queue_free()
	await process_frame
	await process_frame
	_advance(0.2)
	_expect(not runtime.poison.has(freed_id) and runtime.missiles.is_empty(),"Previously freed serpent target was not cleaned safely")
	foe=_enemy(Vector2(100,0),1)
	adjacent=_enemy(Vector2(200,0),1)
	runtime._refresh_targets();runtime._mark_poison(foe);runtime._mark_poison(adjacent)
	runtime._launch_snake(player.position)
	var snake_serial:=runtime._serial
	_advance(1)
	_expect(runtime._serial==snake_serial,"Spectral bites recursively spawned serpents")
	await _clear()

	_fixture()
	foe=_enemy(Vector2(40,0))
	_equip("arachne_staff").activate()
	player.position+=Vector2(100,0);_advance(0.02)
	_expect(runtime.web_segments.size()==5 and runtime.caught.size()==1,"Distance-based web coverage or unique capture count failed")
	_expect(player.kit_buffs.speed_multiplier()>1,"Web capture did not grant speed")
	runtime.activate()
	_expect(not runtime.web_active and not runtime.web_segments.is_empty(),"Cutting the web prematurely erased persistent silk")
	foe.position+=Vector2(0,200);_advance(0.02)
	_expect(runtime.caught.is_empty() and player.kit_buffs.speed_multiplier()==1,"Escaped enemy still granted web bonuses")
	_advance(6.2)
	_expect(runtime.web_segments.is_empty(),"Web failed to decay")
	runtime.activate()
	player.position+=Vector2(1000,0);_advance(0.02)
	_expect(runtime.web_segments.is_empty(),"Teleport created a map-spanning silk segment")
	await _clear()

	_fixture()
	foe=_enemy(Vector2(140,0))
	_equip("tome_of_toth").activate()
	_advance(0.6)
	_expect(runtime.tome_stacks==1 and runtime.tome_souls==0,"Tome did not separate initial capacity from souls")
	for i in 5:
		var soul:=_enemy(Vector2(100,80+i*20),1)
		soul.receive_attack({"damage":1000},player)
	_expect(runtime.tome_souls==5 and runtime.tome_capacity()==6,"Nearby deaths did not expand Tome capacity")
	for i in 5:
		runtime.on_external_hit(foe,{"attack_id":"hit%d"%i,"projectile_id":"p%d"%i},false)
		runtime.on_external_hit(foe,{"attack_id":"hit%d"%i,"projectile_id":"p%d"%i},false)
	_expect(runtime.tome_stacks==6,"Piercing/AOE awards did not resolve once per attack")
	runtime.on_projectile_miss({"attack_id":"hit0","projectile_id":"p0"})
	_expect(runtime.tome_stacks==6,"Successful piercing shot lost stacks at its later wall collision")
	runtime.on_projectile_miss({"attack_id":"miss","projectile_id":"miss"})
	runtime.on_projectile_miss({"attack_id":"miss","projectile_id":"miss"})
	_expect(runtime.tome_stacks==3,"Genuine miss penalty did not resolve once")
	player.cooldowns.basic=0
	var action:=player.use_action("basic")
	_expect(bool(action.started) and not runtime.missiles.is_empty(),"Tome was not integrated with actual basic attack input")
	await _clear()

	_fixture()
	foe=_enemy(Vector2(240,0))
	_equip("shangos_shatterer").activate()
	var planned:=runtime.preview.duplicate()
	_expect(planned.size()==6 and runtime.delayed_bursts.is_empty(),"Shango did not preview before commitment")
	runtime.channel_held=false;_advance(0.02)
	_expect(runtime.delayed_bursts.size()==6 and runtime.delayed_bursts[0].point==planned[0],"Shango preview/commit positions differed")
	var lightning_health:=foe.health
	_advance(0.4)
	_expect(foe.health==lightning_health,"Thunder ignored anticipation delay")
	_advance(1.5)
	_expect(lightning_health-foe.health==runtime._base(runtime.value("thunder_damage")),"Overlapping thunder detonations multiplied target damage")
	_expect(runtime.delayed_bursts.is_empty(),"Thunder sequence did not finish")
	runtime.activate()
	runtime.set_targeting_origin(player.position+Vector2(60,50))
	player.aim_direction=Vector2.DOWN
	runtime._update_preview()
	_expect(runtime.preview.front()==player.position+Vector2(60,50) and runtime.preview[1].x==runtime.preview[0].x,"Shango could not choose a start point independently of line direction")
	var escape:=InputEventKey.new()
	escape.keycode=KEY_ESCAPE;escape.pressed=true
	runtime._unhandled_input(escape)
	_expect(runtime.preview.is_empty() and runtime.delayed_bursts.is_empty(),"Cancelled targeting left a preview or committed damage")
	await _clear()

	_fixture()
	foe=_enemy(Vector2(100,0))
	_equip("solar_scepter").activate()
	_advance(2.2)
	var exposed:=float(runtime.exposure[foe.get_instance_id()])
	_expect(exposed>=2 and foe.disorient_time>0,"Solar exposure did not build and disorient")
	var hp:=foe.health
	foe.receive_attack({"damage":10,"damage_type":"fire"},player)
	_expect(hp-foe.health==roundi(10*(1+exposed*0.12)),"Fire vulnerability was not applied exactly once")
	runtime.on_owner_damaged(1,false)
	_expect(runtime.flare_pending==0,"Self/environment damage triggered Solar retaliation")
	runtime.on_owner_damaged(1,true)
	var cooldown:=runtime.flare_cooldown
	for i in 20:runtime.on_owner_damaged(1,true)
	_expect(runtime.flare_cooldown==cooldown,"Solar retaliation storm reset its internal cooldown")
	hp=foe.health
	_advance(0.15)
	_expect(foe.health<hp,"Scheduled Solar flare did no damage")
	runtime.flare_cooldown=0
	player.invulnerable=0
	var shot:=SlasherHostileProjectile.new().setup(null,player,player.position-Vector2(40,0),Vector2.RIGHT,1,{"projectile_speed":600,"projectile_range":200,"hit_radius":8})
	world.add_child(shot)
	shot.set_physics_process(false)
	shot._physics_process(0.1)
	_expect(runtime.flare_pending>0,"Enemy projectile lost its Solar retaliation attribution after its owner disappeared")
	foe.position+=Vector2(500,0);_advance(1)
	_expect(float(runtime.exposure.get(foe.get_instance_id(),0))<exposed,"Solar exposure did not decay outside the aura")
	await _clear()

	_fixture()
	foe=_enemy(Vector2(90,0))
	_equip("drumamus_bargain").activate()
	runtime.channel_held=true
	var initial:=foe.position
	_advance(1)
	_expect(runtime.gravity_radius()>110 and foe.position.distance_to(player.position)>20 and foe.position.y!=initial.y,"Gravity failed to grow into a spiral with an inner orbit")
	_expect(player.input_locked and foe.health<10000,"Gravity did not anchor the caster and damage enemies")
	runtime.channel_held=false;_advance(0.02)
	_expect(not player.input_locked and runtime.phase=="recovery","Releasing gravity failed to restore movement")
	_advance(0.3)
	runtime.activate()
	runtime._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_expect(not player.input_locked and runtime.phase=="idle","Focus-loss interruption retained gravity anchor")
	await _clear()

	await _wall_checks()
	await _enemy_family_checks()
	await _population_checks()
	await _frame_rate_check()
	await _matrix()
	print("Mage production checks: %d assertions, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _wall_checks()->void:
	_fixture()
	var wall:=StaticBody2D.new()
	wall.position=player.position+Vector2(90,0)
	var collision:=CollisionShape2D.new()
	var shape:=RectangleShape2D.new()
	shape.size=Vector2(20,400)
	collision.shape=shape;wall.add_child(collision);world.add_child(wall)
	await physics_frame
	var foe:=_enemy(Vector2(140,0))
	for id in ["dragonstaff_of_ahghairon","jade_serpent_staff","shangos_shatterer","drumamus_bargain"]:
		_equip(id).activate();runtime.channel_held=true
		_advance(1)
		runtime.channel_held=false;_advance(2)
		_expect(foe.health==10000,id+" damaged a target through solid cover")
	_equip("gulthias_staff")
	runtime._spawn_foliage(foe.position)
	_expect(runtime.plants.is_empty(),"Growth spawned on unreachable ground behind a wall")
	await _clear()

func _frame_rate_check()->void:
	var results:Array[int]=[]
	for hz in [30,60,144]:
		_fixture()
		var foe:=_enemy(Vector2(140,0))
		_equip("dragonstaff_of_ahghairon").activate()
		Input.action_press("slasher_special")
		for i in hz:runtime._physics_process(1.0/hz)
		Input.action_release("slasher_special")
		results.append(foe.health)
		await _clear()
	_expect(results[0]==results[1] and results[1]==results[2],"Dragon damage changed across 30/60/144 Hz: "+str(results))

func _enemy_family_checks()->void:
	_fixture()
	_equip("skyblinder_staff")
	for script in [preload("res://scripts/slasher/slasher_enemy.gd"),preload("res://scripts/slasher/slasher_forest_creature.gd"),preload("res://scripts/slasher/slasher_crypt_enemy.gd"),preload("res://scripts/slasher/slasher_hell_enemy.gd")]:
		var foe:SlasherEnemy=script.new()
		foe.configure(1)
		foe.target=player
		world.add_child(foe)
		foe.position=player.position+Vector2(150,0)
		foe.set_physics_process(false)
		foe.apply_mage_stun(runtime.get_instance_id(),0.5)
		foe.apply_mage_slow(runtime.get_instance_id(),0.5,1)
		var original:=foe.position
		foe._physics_process(0.1)
		_expect(foe.position==original and foe.mage_stun_remaining()<0.5,"Enemy family ignored or failed to advance mage stun: "+script.resource_path)
		runtime._refresh_targets()
		runtime.cancel()
		_expect(foe.mage_controls.is_empty() and foe.mage_slow_multiplier==1,"Swap left an invisible mage control effect")
		foe.queue_free()
	await process_frame
	var boss:=SlasherEnemy.new()
	boss.configure(1,true)
	boss.target=player
	world.add_child(boss)
	boss.position=player.position+Vector2(500,0)
	boss.set_physics_process(false)
	boss.remove_from_group("slasher_enemy")
	boss.remove_from_group("slasher_damageable")
	boss.health=1000;boss.max_health=1000
	var weak:=SlasherColossusWeakPoint.new().setup(boss,"heart",25)
	world.add_child(weak)
	weak.position=player.position+Vector2(140,0)
	weak.set_process(false)
	_equip("jade_serpent_staff").activate()
	_advance(0.7)
	_expect(boss.health==1000,"Jade ignored a closed colossus weak point")
	weak.open_for(5)
	runtime.activate()
	_advance(0.7)
	_expect(boss.health<1000 and runtime.marked.has(boss.get_instance_id()),"Jade could not hit/mark an exposed boss weak point")
	_equip("drumamus_bargain").activate()
	runtime.channel_held=true
	var boss_position:=boss.position
	var point_position:=weak.position
	_advance(1)
	_expect(boss.position==boss_position and weak.position==point_position,"Gravity displaced an immovable colossus or its weak point")
	await _clear()

func _population_checks()->void:
	_fixture()
	_equip("jade_serpent_staff")
	var victims:Array[SlasherEnemy]=[]
	for i in 24:
		var foe:=_enemy(Vector2(100+i*8,30),1)
		victims.append(foe)
		runtime._mark_poison(foe)
	runtime._refresh_targets()
	for i in 16:victims[i].receive_attack({"damage":100,"damage_source":"basic"},player)
	_expect(runtime.missiles.size()==8,"Simultaneous marked deaths exceeded the global serpent cap")
	_advance(6)
	_expect(runtime.missiles.is_empty(),"Capped serpent population failed to expire")
	await _clear()
	_fixture()
	_equip("gulthias_staff")
	var cells:Dictionary={}
	for x in 7:
		for y in 7:cells[Vector2i(x,y)]=true
	player.pathfinder=SlasherGridPathfinder.new().configure(cells,[],player.position,40)
	for y in 5:player.pathfinder.set_cell_blocked(Vector2i(2,y),true)
	var foe:=_enemy(Vector2.ZERO)
	foe.position=player.pathfinder.cell_to_world(Vector2i(4,2))
	var start:=player.pathfinder.cell_to_world(Vector2i(0,2))
	runtime._refresh_targets()
	runtime.spawn_treant(start)
	var stayed_walkable:=true
	for i in 540:
		runtime._step(1.0/60.0)
		for tree in runtime.treants:
			if not player.pathfinder.is_walkable_cell(player.pathfinder.world_to_cell(tree.point)):stayed_walkable=false
	_expect(stayed_walkable and foe.health<10000,"Treant failed to navigate around blocked terrain and reach its target")
	runtime.cancel()
	for cycle in 12:
		for i in 100:
			runtime._fire_gulthias_bolt()
			runtime._pulse(player.position,20,Color.WHITE)
		_expect(runtime.missiles.size()<=24 and runtime.impacts.size()<=48,"Repeated firing exceeded effect caps")
		_advance(6)
	_expect(runtime._pool.size()<=256 and runtime.missiles.is_empty() and runtime.get_child_count()==0,"Repeated firing leaked transient nodes or unbounded pooled records")
	await _clear()

func _matrix()->void:
	# Exercise every ability in empty/single/crowd encounters at both qualities,
	# then release, swap, kill the owner and remove the scene.
	var normal_results:Dictionary={}
	for reduced in [false,true]:
		for count in [0,1,48]:
			for id in IDS:
				_fixture()
				for i in count:_enemy(Vector2(90+(i%8)*32,(i/8)*25))
				_equip(id)
				runtime._reduced=reduced
				_expect(runtime.activate(),id+" did not activate in encounter matrix")
				runtime.channel_held=true
				for i in 40:
					if id=="arachne_staff":player.position+=Vector2(2,0)
					runtime._step(1.0/60.0)
				runtime.channel_held=false
				_advance(1)
				var healths:Array=[]
				for foe in runtime._enemies():healths.append(runtime._body(foe).health)
				var key:="%s:%d"%[id,count]
				if not reduced:normal_results[key]=healths
				else:_expect(healths==normal_results[key],id+" changed gameplay damage at reduced effects quality")
				_expect(runtime.missiles.size()<=24 and runtime.impacts.size()<=48,id+" exceeded bounded record limits")
				ActiveItems.give(state,"whirlwind")
				runtime._physics_process(0.02)
				_expect(runtime.missiles.is_empty() and runtime.poison.is_empty() and runtime.delayed_bursts.is_empty() and runtime.treants.is_empty() and runtime.web_segments.is_empty() and not player.input_locked,id+" leaked an effect/lock after swap")
				ActiveItems.give(state,id)
				runtime.activate()
				player.health=0
				runtime._physics_process(0.02)
				_expect(runtime.phase=="idle" and runtime.charge_time==0 and not player.input_locked,id+" did not clean up on owner death")
				await _clear()
