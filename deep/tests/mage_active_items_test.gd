extends SceneTree

const FOREST:=preload("res://scenes/slasher/SlasherForest.tscn")
const IDS:=["michaels_orb","gulthias_staff","skyblinder_staff","dragonstaff_of_ahghairon","jade_serpent_staff","arachne_staff","tome_of_toth","shangos_shatterer","solar_scepter","drumamus_bargain"]
var failures:Array[String]=[]

func _initialize()->void:_run.call_deferred()
func _expect(ok:bool,message:String)->void:
	if not ok:failures.append(message)
func _frames(count:int)->void:
	for i in count:await process_frame
func _dummy(scene,offset:Vector2)->SlasherEnemy:
	var foe:SlasherEnemy=scene._spawn_enemy(scene.player.global_position+offset,"bandit_cutthroat","bandit_cutthroat");foe.activation_delay=999.0;foe.max_health=200;foe.health=200;return foe
func _runtime(player:SlasherPlayer,id:String)->Node:
	for child in player.get_children():
		if child.get_meta("active_item_runtime_id","")==id:return child
	return null

func _run()->void:
	var state:=RunState.new();state.start_new_run(GearData.create("mage_test","Mage Tester",3,false,0,"","","mage"),"forest")
	var scene=FOREST.instantiate();scene._ensure_designer_controls();scene.run_state=state;root.add_child(scene);await _frames(4);paused=false
	scene.player.invulnerable=9999.0;scene.player.aim_direction=Vector2.RIGHT
	for id in IDS:
		ActiveItems.give(state,id)
		_expect(scene.use_active_item(),"%s did not activate"%id)
		_expect(_runtime(scene.player,id)!=null,"%s created no persistent runtime"%id)
		if id=="arachne_staff":
			_expect(ActiveItems.is_ready(state),"Arachne's first toggle spent the item before the trail could be closed")
			_expect(scene.use_active_item() and not ActiveItems.is_ready(state),"Arachne's second toggle did not close and spend the item")

	# Michael's Orb stores basic-hit energy and releases a seeking pinball bolt.
	var foe:=_dummy(scene,Vector2(100,0));var orb=_runtime(scene.player,"michaels_orb");orb.active_time=20.0
	for i in 3:orb.on_external_hit(foe,{"damage":1,"damage_source":"basic"},false)
	_expect(orb.orb_energy==0 and orb.missiles.size()==1,"Michael's Orb did not fire after absorbing three basic hits")

	# Gulthias converts a bolt kill into shootable foliage, then that foliage
	# becomes an autonomous treant when deliberately attacked.
	var gulthias=_runtime(scene.player,"gulthias_staff");var seed_target:=_dummy(scene,Vector2(120,30));seed_target.dead=true;var children_before:int=scene.player.get_child_count();gulthias.on_external_hit(seed_target,{"damage_source":"gulthias_staff"},false)
	var foliage:Node
	for node in get_nodes_in_group("slasher_damageable"):
		if not node is SlasherEnemy and node.has_method("receive_attack") and "runtime" in node and node.get("runtime")==gulthias:foliage=node
	_expect(foliage!=null,"Gulthias Staff bolt kill produced no shootable foliage")
	if foliage!=null:foliage.receive_attack({},scene.player)
	var treant_found:=false
	for node in scene.player.get_children():
		if node!=foliage and "runtime" in node and node.get("runtime")==gulthias and not node.is_in_group("slasher_damageable"):treant_found=true
	_expect(treant_found and scene.player.get_child_count()>=children_before+1,"Shooting Gulthias foliage produced no treant")

	# Skyblinder charge must materially scale into a radiant stun explosion.
	var sky_target:=_dummy(scene,Vector2(360,0));var sky=_runtime(scene.player,"skyblinder_staff");sky.charge_time=2.0;sky.active_time=1.0;var sky_health:=sky_target.health;sky._release_skyblinder()
	_expect(sky_target.health<sky_health and sky_target.hit_stun_timer>=1.0,"Fully charged Skyblinder shot produced neither heavy damage nor a long stun")

	# Dragonfire is a live cone with a fuel economy: it spends fuel while active
	# and charred kills extend the channel.
	var fire_target:=_dummy(scene,Vector2(120,0));var dragon=_runtime(scene.player,"dragonstaff_of_ahghairon");dragon.dragon_fuel=2.5;dragon.active_time=2.5;dragon.tick_time=0.0;var fuel_before:float=dragon.dragon_fuel;var fire_health:=fire_target.health;dragon._process_dragonfire(0.2);var spent_fuel:float=dragon.dragon_fuel;fire_target.dead=true;dragon.on_external_hit(fire_target,{"damage_source":"dragonstaff"},false)
	_expect(fire_target.health<fire_health and spent_fuel<fuel_before and dragon.dragon_fuel>spent_fuel,"Dragonstaff cone or corpse-fuel loop is nonfunctional")

	# Jade marks and poisons a victim; executing a mark releases a seeking snake.
	var jade_target:=_dummy(scene,Vector2(130,-30));var snake_target:=_dummy(scene,Vector2(220,-30));var jade=_runtime(scene.player,"jade_serpent_staff");jade._fire_jade_dart();var jade_id:=jade_target.get_instance_id();jade_target.dead=true;var snake_count:int=jade.missiles.size();jade.on_external_hit(jade_target,{"damage_source":"jade_serpent"},false)
	_expect(jade.poison.has(jade_id) and jade.missiles.size()>snake_count and is_instance_valid(snake_target),"Jade Serpent mark death released no spectral snake")

	# Tome stacks damage on hits and loses its record on a miss.
	var tome=_runtime(scene.player,"tome_of_toth");tome.active_time=20.0;tome.tome_stacks=0;tome.on_external_hit(foe,{"damage":2},false)
	_expect(tome.tome_stacks==1 and int(tome.adjust_external_attack(foe,{"damage":10}).damage)>10,"Tome of Toth did not stack damage")
	tome.on_projectile_miss({});_expect(tome.tome_stacks==0,"Tome of Toth did not reset on a miss")

	# Persistent field and channel state is actually initialized.
	var web=_runtime(scene.player,"arachne_staff");web.activate();scene.player.global_position+=Vector2(40,0);web._process_web(0.1)
	_expect(web.web_active and web.web_points.size()>=2,"Arachne Staff did not trail a web")
	var solar=_runtime(scene.player,"solar_scepter");solar.active_time=3.0;var before:=foe.health;solar._process_solar(0.5)
	_expect(foe.health<before and solar.exposure.has(foe.get_instance_id()),"Solar Scepter produced no damaging exposure aura")
	var gravity=_runtime(scene.player,"drumamus_bargain");gravity.active_time=2.0;gravity.anchor=scene.player.global_position;gravity._process_gravity(0.5)
	_expect(gravity.charge_time>0.0,"Drumamu's Bargain did not grow while channeled")

	# Shango's vector establishes delayed danger, then each marker pays out as
	# thunder rather than being visual-only.
	var shango_target:=_dummy(scene,Vector2(70,0));var shango=_runtime(scene.player,"shangos_shatterer");shango.delayed_bursts.clear();var shango_health:=shango_target.health;shango._cast_shango();_expect(shango.delayed_bursts.size()==6,"Shango created no delayed thunder vector")
	for burst in shango.delayed_bursts:burst.time=0.0
	shango._process_delayed(0.01);_expect(shango_target.health<shango_health and shango.delayed_bursts.is_empty(),"Shango delayed thunder dealt no damage")

	# Taking damage inside Solar Scepter's window must retaliate immediately.
	var flare_target:=_dummy(scene,Vector2(80,20));var solar_flare=_runtime(scene.player,"solar_scepter");solar_flare.active_time=3.0;solar_flare.flare_cooldown=0.0;var flare_health:=flare_target.health;solar_flare.on_owner_damaged(1)
	_expect(flare_target.health<flare_health and solar_flare.flare_cooldown>0.0,"Solar Scepter did not answer incoming damage with a flare")

	scene.queue_free();await _frames(3)
	if failures.is_empty():print("MAGE_ACTIVE_ITEMS_TESTS_PASSED");quit(0)
	else:
		for failure in failures:printerr("FAIL: "+failure)
		quit(1)
