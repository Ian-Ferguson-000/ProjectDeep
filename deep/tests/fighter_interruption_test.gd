extends "res://tests/fighter_production_test.gd"

func _run()->void:
	for id in ARSENAL.WEAPON_IDS:
		for interruption in ["focus","escape","input_lock","swap"]:
			fixture(id);player.warrior_kit=kit
			var target:=foe()
			kit.perform("special",{"started":true})
			kit._physics_process(0.01)
			match interruption:
				"focus":kit._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
				"escape":
					var event:=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=true
					kit._unhandled_input(event)
				"input_lock":player.input_locked=true
				"swap":kit.on_unequipped()
			for step in 180:kit._physics_process(1.0/120)
			var label:String=id+" / "+interruption
			expect(target.health==target.max_health,label+": interrupted anticipation cannot deal delayed damage")
			expect(kit.swing.is_empty() and kit.ranged_attack.is_empty() and kit.hammer_chain.is_empty() and kit.shield_bash.is_empty() and kit.trident.is_empty(),label+": no pending attack or unlaunched possession remains")
			await clear()
	for id in ["storm_trident","valkyrian_sling","archon_crossbow","umbral_bow"]:
		fixture(id);player.warrior_kit=kit
		var target:=foe();target.position=player.position+Vector2(350,0)
		kit.perform("special",{"started":true})
		for step in 240:
			kit._physics_process(1.0/120)
			if not kit.missiles.is_empty():break
		expect(not kit.missiles.is_empty(),id+": target-death test reaches actual flight")
		target.queue_free();await process_frame
		for step in 480:kit._physics_process(1.0/120)
		expect(kit.missiles.is_empty(),id+": committed shot terminates safely after target disappears")
		if id=="storm_trident":
			expect(not kit.trident.is_empty() and kit.trident.state=="deployed","Trident remains recoverable after its target disappears")
		else:expect(kit.leashes.is_empty(),id+": no tether to a freed target survives")
		await clear()
	# Removing a live runtime must release controls owned by its in-flight bolt
	# or tether, without requiring another physics update from the removed node.
	for id in ["archon_crossbow","umbral_bow"]:
		fixture(id)
		var target:=foe()
		if id=="archon_crossbow":
			kit._launch_archon({"damage":1,"warrior_cast":1},false)
			kit._tick_archon(kit.missiles[0],0.15)
			expect(target.has_meta("fighter_archon_carrier"),"Scene-exit fixture establishes actual bolt attachment")
		else:
			kit._add_leash(target)
			expect(player.kit_buffs.speed_multiplier()>1,"Scene-exit fixture establishes actual stolen speed")
		kit.queue_free();await process_frame
		expect(not target.has_meta("fighter_archon_carrier") and target.mage_stun_remaining()==0 and target.mage_slow_multiplier==1,id+": runtime exit releases target controls")
		expect(player.kit_buffs.speed_multiplier()==1,id+": runtime exit leaves no stolen-speed contribution")
		await clear()
	print("Fighter interruptions: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
