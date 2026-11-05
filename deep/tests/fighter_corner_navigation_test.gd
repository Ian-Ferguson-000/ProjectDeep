extends "res://tests/fighter_narrow_terrain_test.gd"

func _run()->void:
	for hz in [30,120]:
		fixture("eldritch_bowstaff")
		var grid_origin:=player.position-Vector2(72,72)
		var cells:Dictionary={}
		for x in 6:
			for y in 6:
				if x==2 and y<4:continue
				cells[Vector2i(x,y)]=true
		player.pathfinder=SlasherGridPathfinder.new().configure(cells,[],grid_origin,48)
		barrier(grid_origin+Vector2(120,96),Vector2(48,192))
		var prey:=foe();prey.position=player.pathfinder.cell_to_world(Vector2i(3,1))
		await physics_frame
		kit._spawn_corrupted(player.position+Vector2(0,48),1)
		expect(kit.spawned_beasts==1,"Corner route has a valid corpse-local summon position")
		var beast:CorruptedMiniBeast=get_nodes_in_group("corrupted_mini_beast")[0]
		beast.set_physics_process(false)
		var reached_corner:=false
		var crossed_solid:=false
		var hit_through_cover:=false
		for tick in hz*8:
			var before:=prey.health
			var clear_before:bool=beast._clear_contact(prey)
			beast._physics_process(1.0/hz)
			if prey.health<before and not clear_before:hit_through_cover=true
			var local:=beast.position-grid_origin
			if local.y>=199:reached_corner=true
			if local.x>96 and local.x<144 and local.y<192:crossed_solid=true
		expect(reached_corner,"%dHz: beast follows the route around the wall end"%hz)
		if prey.health==prey.max_health:printerr("Corner diagnostic %dHz: beast=%s prey=%s remaining route=%s"%[hz,beast.position-grid_origin,prey.position-grid_origin,beast.route])
		expect(not crossed_solid and not hit_through_cover,"%dHz: corner navigation never crosses solid cover or bites through it"%hz)
		expect(prey.health<prey.max_health,"%dHz: beast completes corner route and reaches real combat contact"%hz)
		beast.setup(player,player.position,0)
		expect(beast.route.is_empty() and beast.route_revision==-1,"Pooled beast setup clears previous route and navigation revision")
		await clear()
	print("Fighter corner navigation: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
