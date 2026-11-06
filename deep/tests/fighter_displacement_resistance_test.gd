extends "res://tests/fighter_production_test.gd"

func _run()->void:
	for step_size in [0.2,1.0/30.0,1.0/120.0]:
		for heavy in [false,true]:
			fixture("sentinel_shield")
			var victim:=foe();victim.boss=heavy
			var origin:=victim.position
			kit.perform("special",{"started":true})
			for step in int(ceil(0.3/step_size)):kit._tick_shield(step_size)
			var expected:float=kit.rules.shove*(float(kit.rules.heavy_displacement_multiplier) if heavy else 1.0)
			expect(absf(victim.position.distance_to(origin)-expected)<0.01,"Shield shove distance matches resistance at every simulation step size")
			var after_contact:=victim.health
			kit._tick_shield(0.5)
			expect(victim.health==after_contact and absf(victim.position.distance_to(origin)-expected)<0.01,"Finished bash cannot damage or displace a victim a second time")
			await clear()
	for guardian in [false,true]:
		fixture("archon_crossbow")
		var heavy:=foe();heavy.position=player.position+Vector2(90,0)
		if guardian:
			heavy.behavior_id="elite_guardian";heavy.behavior_tuning={"received_knockback_multiplier":0.18}
		else:heavy.tuning=heavy.tuning.duplicate(true);heavy.tuning.received_knockback_multiplier=0.0
		var later:=foe();later.position=player.position+Vector2(180,0)
		var original:=heavy.position
		kit._launch_archon({"damage":100,"warrior_cast":1},false)
		kit._tick_archon(kit.missiles[0],0.3)
		expect(heavy.health==9900 and later.health==9865,"Resistant victim takes damage and increases subsequent piercing damage")
		expect(heavy.position==original and not heavy.has_meta("fighter_archon_carrier"),"Heavy/immovable non-boss cannot be forcibly carried")
		expect(later.has_meta("fighter_archon_carrier"),"Eligible later victim still attaches after resistant target")
		later.tuning=later.tuning.duplicate(true);later.tuning.received_knockback_multiplier=0
		var stopped:=later.position
		kit._tick_archon(kit.missiles[0],0.01)
		expect(later.position==stopped and not later.has_meta("fighter_archon_carrier") and later.mage_stun_remaining()==0,"Becoming immovable releases carry and its control before further displacement")
		await clear()
	fixture("sentinel_shield")
	var guardian:=foe();guardian.behavior_id="elite_guardian";guardian.behavior_tuning={"received_knockback_multiplier":0.18}
	var start:=guardian.position
	strike(guardian,1,1)
	expect(absf(guardian.position.distance_to(start)-float(kit.rules.shove)*0.18)<0.01,"Shield honors guardian-specific displacement resistance")
	var feedback:Array=kit.effects.filter(func(effect:Dictionary)->bool:return effect.kind=="shield_shove")
	expect(feedback.size()==1 and feedback[0].resisted,"Guardian resistance uses matching resistant impact feedback")
	await clear()
	print("Fighter displacement resistance: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
