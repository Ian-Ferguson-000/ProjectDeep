extends "res://tests/active_items_test.gd"

var checks:=0

func check(value:bool,message:String)->void:
	checks+=1;_expect(value,message)
	if not value:printerr("FAIL: "+message)

func _run()->void:
	root.get_node("GameSettings").values.dev_mode=false
	var state:=RunState.new()
	state.start_new_run(GearData.create("transition_test","Tester",3,false,0,"","","warrior"),"forest")
	state.starter_reward_claimed=true
	var scene=FOREST.instantiate();scene._ensure_designer_controls();scene.run_state=state;root.add_child(scene)
	await _frames(4)
	for id in FIGHTER_ACTIVE_IDS:
		paused=false;scene.player.set_physics_process(false);scene.player.invulnerable=9999
		scene.player.aim_direction=Vector2.RIGHT
		for enemy in get_nodes_in_group("slasher_enemy"):enemy.set_physics_process(false)
		var victim:=_dummy(scene,Vector2(90,0));victim.health=100000;victim.max_health=100000;victim.set_physics_process(false)
		ActiveItems.give(state,id)
		check(scene.use_active_item(),id+": real dungeon active slot starts")
		var runtime:Node
		for child in scene.player.get_children():
			if child.get_meta("fighter_active_weapon_id","")==id:runtime=child;break
		check(is_instance_valid(runtime),id+": room owns actual combat runtime")
		if not is_instance_valid(runtime):quit(1);return
		runtime.set_physics_process(false)
		if id=="storm_trident":runtime.trident.destination=victim.global_position
		for tick in 360:
			runtime._physics_process(1.0/120.0)
			if victim.health<victim.max_health:break
		check(victim.health<victim.max_health,id+": room transition begins after real weapon contact")
		if id=="archon_crossbow":check(victim.has_meta("fighter_archon_carrier"),id+": carry is live before transition")
		if id=="umbral_bow":check(not runtime.leashes.is_empty(),id+": tether is live before transition")
		if id=="eldritch_bowstaff":
			victim.receive_attack({"damage":1000000},null)
			check(runtime.spawned_beasts>0,id+": conversion creates room-owned summons before transition")
		var old_refs:Array[WeakRef]=[weakref(scene.player),weakref(runtime),weakref(victim)]
		for beast in get_nodes_in_group("corrupted_mini_beast"):old_refs.append(weakref(beast))
		var old_room:int=scene.room_id
		var neighbors:Dictionary=scene.room.neighbors
		var direction:String=String(neighbors.keys()[0])
		state.field_run.current_room=int(neighbors[direction]);state.field_run.previous_room=old_room
		state.field_run.arrival_direction={"north":"south","south":"north","east":"west","west":"east"}.get(direction,"")
		scene._build_floor()
		scene.player.set_physics_process(false);scene.player.invulnerable=9999
		await _frames(2)
		check(scene.room_id!=old_room,id+": actual dungeon changes room")
		for reference in old_refs:check(reference.get_ref()==null,id+": previous room combat object is freed")
		check(ActiveItems.held(state)==id,id+": item ownership survives room change")
		check(not ActiveItems.is_ready(state),id+": changing rooms does not silently refill the spent item")
		check(get_nodes_in_group("corrupted_mini_beast").is_empty(),id+": old summons do not leak into new room")
		check(is_equal_approx(scene.player.kit_buffs.speed_multiplier(),1.0),id+": new player inherits no stale tether haste")
		if id=="demon_blade":
			check(scene.player.fighter_frenzy_left>0 and scene.player.fighter_frenzy_incoming==2,id+": actual-hit frenzy keeps commitment across room change")
		# Recharging is deliberate test setup; the new room must be able to
		# create a fresh runtime without inheriting a lost projectile/possession.
		ActiveItems.give(state,id)
		check(scene.use_active_item(),id+": fresh room can activate item without a stale lock")
		for child in scene.player.get_children():
			if child.get_meta("fighter_active_weapon_id","")==id:child.on_unequipped()
		scene.player.tick_fighter_frenzy(30)
	scene.queue_free();await _frames(2)
	print("Fighter room transitions: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
