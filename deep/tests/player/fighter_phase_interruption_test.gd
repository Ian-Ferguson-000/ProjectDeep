extends "res://legacy/tests/fighter_production_test.gd"

func reached_phase(phase:String)->bool:
	if not kit.swing.is_empty():
		var state:Dictionary=kit.swing
		var threshold:=float(state.windup)+float(state.active)*(0.15 if phase=="active" else 1.1)
		return float(state.elapsed)/float(state.duration)>=threshold
	if kit.weapon_id in ["archon_crossbow","umbral_bow","valkyrian_sling"]:
		return not kit.missiles.is_empty() if phase=="active" else (not kit.ranged_attack.is_empty() and float(kit.ranged_attack.elapsed)>=float(kit.ranged_attack.duration)*0.9)
	if kit.weapon_id=="storm_trident":
		return not kit.trident.is_empty() and kit.trident.state==("flying" if phase=="active" else "deployed")
	if not kit.impact_recovery.is_empty():
		return phase=="active" or float(kit.impact_recovery.left)<=float(kit.impact_recovery.duration)*0.5
	return false

func _run()->void:
	GameBalance.set_actions_override(GameBalance.ALL_ACTIONS)
	for id in ARSENAL.WEAPON_IDS:
		for phase in ["active","recovery"]:
			for interruption in ["focus","escape","input_lock","swap","death"]:
				fixture(id);player.warrior_kit=kit
				player.run_state.selected_gear=GearData.create(id,id,3,false,0,"","","warrior")
				player.run_state.class_resource=player.run_state.get_class_resource_max()
				var target:=foe();target.position=player.position+Vector2(90,0)
				var label:="%s/%s/%s"%[id,phase,interruption]
				expect(bool(player.use_action("special").get("started",false)),label+": native action begins")
				if id=="storm_trident":kit.trident.destination=player.position+Vector2(200,0)
				var reached:=false
				for tick in 360:
					kit._physics_process(1.0/120.0)
					if reached_phase(phase):reached=true;break
				expect(reached,label+": intended interruption phase is actually reached")
				match interruption:
					"focus":kit._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
					"escape":
						var event:=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=true;kit._unhandled_input(event)
					"input_lock":player.input_locked=true
					"swap":kit.on_unequipped()
					"death":player.health=0
				kit._physics_process(0)
				expect(kit.swing.is_empty() and kit.ranged_attack.is_empty() and kit.hammer_chain.is_empty() and kit.shield_bash.is_empty() and kit.impact_recovery.is_empty(),label+": pending contact/recovery states clear immediately")
				var fresh:=foe();fresh.position=player.position+Vector2(80,0)
				for tick in 1560:kit._physics_process(1.0/120.0)
				if id not in ["storm_trident","archon_crossbow","umbral_bow","valkyrian_sling"] or interruption=="death" or (interruption=="swap" and id!="storm_trident"):
					expect(fresh.health==fresh.max_health,label+": cancelled attack cannot hit a newly arriving enemy")
				expect(kit.missiles.is_empty(),label+": committed projectiles finish without duplicates or endless flight")
				expect(not target.has_meta("fighter_archon_carrier"),label+": no carried restriction survives termination")
				if id=="storm_trident" and interruption!="death":
					expect(not kit.trident.is_empty() and kit.trident.state=="deployed",label+": committed trident remains recoverable")
					player.position=kit.trident.position;kit._physics_process(0.01)
					expect(kit.trident.is_empty(),label+": physical retrieval still works")
				await clear()
	print("Fighter phase interruptions: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
