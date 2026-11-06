extends "res://tests/fighter_production_test.gd"

func _run()->void:
	for hz in [30,120]:
		fixture("valkyrian_sling");kit.rules.impacts=2
		var targets:Array[SlasherEnemy]=[]
		for distance in [100,160,220]:
			var target:=foe();target.position=player.position+Vector2(distance,0);targets.append(target)
		kit._launch_sling({"damage":10,"warrior_cast":1},false)
		var returned:=false
		for step in hz*5:
			kit._physics_process(1.0/hz)
			if not kit.missiles.is_empty() and kit.missiles[0].returning:
				returned=true;break
		expect(returned and kit.missiles[0].bounces==2,"Configured two-hit quota starts return at %dHz"%hz)
		expect(targets[0].health==9990 and targets[1].health==9990 and targets[2].health==10000,"Quota return skips a still-valid third target")
		var health_before:=player.health
		for step in hz*5:kit._physics_process(1.0/hz)
		expect(kit.missiles.is_empty() and player.health==health_before,"Unparried quota return catches harmlessly")
		await clear()
		fixture("valkyrian_sling")
		var vanishing:=foe();vanishing.position=player.position+Vector2(300,0)
		kit._launch_sling({"damage":10,"warrior_cast":1},false);kit._physics_process(0.02)
		vanishing.queue_free();await process_frame
		kit._physics_process(1.0/hz)
		expect(not kit.missiles.is_empty() and kit.missiles[0].returning,"Losing the last target starts return without a stale reference")
		for step in hz*5:kit._physics_process(1.0/hz)
		expect(kit.missiles.is_empty(),"Target-loss return finishes without an accidental loop")
		await clear()
	print("Fighter Sling returns: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
