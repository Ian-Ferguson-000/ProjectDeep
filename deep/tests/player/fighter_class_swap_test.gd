extends "res://tests/player/fighter_phase_interruption_test.gd"

func _run()->void:
	GameBalance.set_actions_override(GameBalance.ALL_ACTIONS)
	for id in ARSENAL.WEAPON_IDS:
		fixture(id)
		kit.free()
		var state:RunState=player.run_state
		var gear:=GearData.create(id,id,3,false,0,"","","warrior")
		state.selected_gear=gear;player.setup(state)
		kit=player.warrior_kit;kit.set_physics_process(false)
		var original:WeakRef=weakref(kit)
		var target:=foe();target.position=player.position+Vector2(90,0)
		state.class_resource=state.get_class_resource_max()
		expect(bool(player.use_action("special").get("started",false)),id+": native action begins")
		if id=="storm_trident":kit.trident.destination=player.position+Vector2(200,0)
		var reached:=false
		for tick in 360:
			kit._physics_process(1.0/120.0)
			if reached_phase("active"):reached=true;break
		expect(reached,id+": swap occurs during live combat state")
		if id=="demon_blade":
			for tick in 120:
				if player.fighter_frenzy_left>0:break
				kit._physics_process(1.0/120.0)
			expect(player.fighter_frenzy_left>0,id+": successful contact starts commitment before swap")
		# Use the same setup entry point as the armory class podiums.
		state.selected_class_id="mage"
		state.selected_gear=GearData.create("class_swap_mage","Mage",3,false,0,"","","mage")
		player.setup(state)
		expect(player.class_id=="mage" and player.warrior_kit==null,id+": native mage setup detaches equipped fighter kit")
		expect(kit.swing.is_empty() and kit.ranged_attack.is_empty() and kit.hammer_chain.is_empty() and kit.shield_bash.is_empty() and kit.impact_recovery.is_empty(),id+": class swap cancels pending contacts and recovery")
		expect(not target.has_meta("fighter_archon_carrier") and kit.leashes.is_empty(),id+": class swap releases carries and tethers")
		if id=="demon_blade":expect(player.fighter_frenzy_left>0,id+": vulnerability commitment survives changing class")
		for tick in 120:kit._physics_process(1.0/120.0)
		state.selected_class_id="warrior";state.selected_gear=gear
		player.setup(state)
		expect(player.warrior_kit==original.get_ref(),id+": returning to Fighter reuses original runtime")
		var count:=0
		for child in player.get_children():
			if child.get_meta("fighter_active_weapon_id","")==id:count+=1
		expect(count==1,id+": no duplicate item runtime after round trip")
		expect(kit.swing.is_empty() and kit.ranged_attack.is_empty() and kit.hammer_chain.is_empty() and kit.shield_bash.is_empty(),id+": returning does not restore cancelled attack")
		if id=="storm_trident":
			expect(not kit.trident.is_empty() and kit.trident.state=="deployed",id+": thrown trident retains possession rule across classes")
			player.position=kit.trident.position;kit._physics_process(0.01)
			expect(kit.trident.is_empty(),id+": original trident remains physically retrievable")
		var old_player:WeakRef=weakref(player)
		var old_target:WeakRef=weakref(target)
		await clear()
		expect(original.get_ref()==null and old_player.get_ref()==null and old_target.get_ref()==null,id+": unloading world frees runtime, owner, and targets")
	print("Fighter class swaps: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
