extends "res://legacy/tests/fighter_production_test.gd"

func _run()->void:
	for id in ARSENAL.WEAPON_IDS:
		fixture(id)
		expect(is_equal_approx(float(kit.rules.special_damage_multiplier),1.1),id+": shared tuning is inherited")
		for slot in ["basic","special"]:
			expect(float(kit.rules.actions[slot].damage_coefficient)>0 and float(kit.rules.actions[slot].cooldown)>0,id+": damage and cooldown are authored for "+slot)
		await clear()
	fixture("dragonbone_dagger")
	kit.rules.special_damage_multiplier=2.0;kit.rules.followup_damage_multiplier=0.35
	var base_damage:int=kit.attack_for("special","Configured dagger").damage
	kit.perform("special",{"started":true})
	expect(int(kit.swing.attacks[0].damage)==base_damage*2,"Configured special multiplier changes authoritative first-strike damage")
	expect(int(kit.swing.attacks[1].damage)==roundi(base_damage*2*0.35),"Configured dagger follow-up multiplier changes its distinct second strike")
	await clear()
	fixture("storm_trident")
	kit.rules.basic_reach=90;kit.rules.basic_arc=80;kit.rules.windup_fraction=0.4;kit.rules.active_fraction=0.3
	kit.perform("basic",{"started":true})
	expect(kit.swing.reach==90 and kit.swing.degrees==80 and kit.swing.windup==0.4 and kit.swing.active==0.3,"Trident basic geometry and phases follow authored values")
	await clear()
	for id in ["archon_crossbow","umbral_bow"]:
		for radius in [0,40]:
			fixture(id)
			kit.rules.projectile_radius=radius
			var target:=foe();target.position=player.position+Vector2(100,40)
			if id=="archon_crossbow":kit._launch_archon({"damage":10,"warrior_cast":1},false)
			else:kit._launch_umbral({"damage":10,"warrior_cast":1},false)
			kit._physics_process(0.3)
			expect((target.health<target.max_health)==(radius==40),id+": configurable swept projectile radius changes actual contact")
			await clear()
	print("Fighter configuration: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
