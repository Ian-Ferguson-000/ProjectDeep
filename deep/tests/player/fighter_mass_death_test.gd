extends "res://legacy/tests/fighter_production_test.gd"

func _run()->void:
	GameBalance.set_actions_override(GameBalance.ALL_ACTIONS)
	var baseline:Dictionary={}
	for reduced in [false,true]:
		root.get_node("GameSettings").values["reduced_effects"]=reduced
		for id in ARSENAL.WEAPON_IDS:
			fixture(id);player.warrior_kit=kit
			player.run_state.selected_gear=GearData.create(id,id,3,false,0,"","","warrior")
			player.run_state.class_resource=player.run_state.get_class_resource_max()
			var deaths:Dictionary={};var references:Array[WeakRef]=[]
			for index in 32:
				var target:=foe(1);target.position=player.position+Vector2(75+(index%8)*23,-50+(index/8)*30)
				references.append(weakref(target))
				target.defeated.connect(func(enemy:SlasherEnemy,_reward:int)->void:
					var key:=enemy.get_instance_id();deaths[key]=int(deaths.get(key,0))+1)
			seed(42)
			expect(bool(player.use_action("special").get("started",false)),id+": native crowded lethal activation starts")
			if id=="storm_trident":kit.trident.destination=player.position+Vector2(130,0)
			var bounded:=true
			for tick in 360:
				player.tick_fighter_frenzy(1.0/120.0);kit._physics_process(1.0/120.0)
				for reference in references:
					var target:SlasherEnemy=reference.get_ref()
					if is_instance_valid(target) and not target.dead:target._process_mage_control(1.0/120.0)
				for beast in get_nodes_in_group("corrupted_mini_beast"):
					beast.set_physics_process(false);beast._physics_process(1.0/120.0)
				bounded=bounded and kit.effects.size()<=32 and kit.missiles.size()<=4 and get_nodes_in_group("corrupted_mini_beast").size()<=24
				if tick%30==0:await process_frame
			expect(not deaths.is_empty(),id+": lethal crowd produces real deaths")
			expect(deaths.values().all(func(count):return count==1),id+": each defeated body resolves once")
			expect(bounded,id+": lethal crowd preserves projectile/effect/summon caps")
			expect(kit.rampage_stacks<=int(kit.rule("stack_cap",6)) and kit.repeat_smashes<=int(kit.rule("chain_cap",8)),id+": death procs cannot branch beyond configured caps")
			var outcome:={"deaths":deaths.size(),"beasts":kit.spawned_beasts,"rampage":kit.rampage_stacks,"repeats":kit.repeat_smashes}
			if not reduced:baseline[id]=outcome
			else:expect(outcome==baseline[id],id+": reduced effects preserve kill and death-proc outcomes")
			await clear()
	print("Fighter mass deaths: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
