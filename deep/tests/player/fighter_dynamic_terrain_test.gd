extends "res://legacy/tests/fighter_production_test.gd"

func _run()->void:
	fixture("storm_trident");player.warrior_kit=kit
	kit.perform("special",{"started":true})
	kit.trident.destination=player.position+Vector2(300,0)
	var aiming_wall:=StaticBody2D.new();aiming_wall.position=player.position+Vector2(180,0)
	var aiming_shape:=CollisionShape2D.new();var aiming_box:=RectangleShape2D.new();aiming_box.size=Vector2(16,400)
	aiming_shape.shape=aiming_box;aiming_wall.add_child(aiming_shape);world.add_child(aiming_wall)
	await physics_frame
	kit._tick_trident_aim(0.01)
	var updated_preview:Vector2=kit.trident.destination
	expect(updated_preview.x<aiming_wall.position.x-8,"Trident preview reacts to terrain inserted during anticipation")
	kit._tick_trident_aim(0.3)
	expect(Vector2(kit.missiles[0].destination)==updated_preview,"Release uses the updated safe landing preview")
	kit._tick_trident(kit.missiles[0],1)
	expect(Vector2(kit.trident.position)==updated_preview,"Landing matches the terrain-corrected preview")
	player.position_sanitizer=func(_point:Vector2)->Vector2:return player.position+Vector2(300,0)
	expect(kit._safe_trident_destination(player.position+Vector2(50,0))==player.position,"Sanitizer cannot move landing behind solid terrain")
	player.position_sanitizer=func(_point:Vector2)->Vector2:return player.position+Vector2(0,900)
	expect(kit._safe_trident_destination(player.position+Vector2(0,50))==player.position,"Sanitizer cannot move landing beyond throw range")
	player.position_sanitizer=func(_point:Vector2)->Vector2:return Vector2.INF
	expect(kit._safe_trident_destination(player.position+Vector2(0,50))==player.position,"Invalid sanitizer result falls back to a recoverable position")
	player.pathfinder=SlasherGridPathfinder.new().configure({Vector2i.ZERO:true},[],player.position-Vector2(24,24),48)
	expect(kit._safe_trident_destination(player.position+Vector2(0,50))==player.position,"Invalid sanitizer result is rejected before navigation conversion")
	await clear()
	for id in ["storm_trident","archon_crossbow","umbral_bow","valkyrian_sling"]:
		fixture(id);player.warrior_kit=kit
		var victim:=foe();victim.position=player.position+Vector2(280,0)
		var attack:Dictionary={"damage":10,"warrior_cast":1}
		match id:
			"storm_trident":kit._throw_trident(attack,victim.position)
			"archon_crossbow":kit._launch_archon(attack,false)
			"umbral_bow":kit._launch_umbral(attack,false)
			"valkyrian_sling":kit._launch_sling(attack,false)
		kit._physics_process(0.08)
		expect(not kit.missiles.is_empty(),id+": terrain test begins with an airborne projectile")
		var wall:=StaticBody2D.new();wall.position=player.position+Vector2(160,0)
		var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(16,400)
		shape.shape=box;wall.add_child(shape);world.add_child(wall)
		await physics_frame
		for step in 240:kit._physics_process(1.0/120)
		expect(victim.health==victim.max_health,id+": newly inserted wall prevents damage beyond it")
		expect(kit.missiles.is_empty(),id+": obstructed projectile terminates or returns without looping")
		if id=="storm_trident":
			expect(not kit.trident.is_empty() and kit.trident.state=="deployed","Blocked Trident remains deployed for retrieval")
			expect(Vector2(kit.trident.position).x<wall.position.x-8,"Trident fallback stays on the reachable side of the new wall")
			player.position=kit.trident.position;kit._physics_process(0.01)
			expect(kit.trident.is_empty(),"Blocked-flight fallback permits physical Trident retrieval")
		await clear()
	fixture("archon_crossbow")
	var carried:=foe();carried.position=player.position+Vector2(60,0)
	kit._launch_archon({"damage":1,"warrior_cast":1},false);kit._physics_process(0.12)
	expect(carried.has_meta("fighter_archon_carrier"),"Dynamic carry test establishes live attachment")
	var barrier:=StaticBody2D.new();barrier.position=player.position+Vector2(130,0)
	var barrier_shape:=CollisionShape2D.new();var barrier_box:=RectangleShape2D.new();barrier_box.size=Vector2(16,400)
	barrier_shape.shape=barrier_box;barrier.add_child(barrier_shape);world.add_child(barrier)
	await physics_frame
	kit._physics_process(0.2)
	expect(carried.position.x<barrier.position.x-8,"Carried body cannot cross a newly inserted wall")
	expect(not carried.has_meta("fighter_archon_carrier") and carried.mage_stun_remaining()==0,"Dynamic terrain termination releases carry restrictions immediately")
	await clear()
	print("Fighter dynamic terrain: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
