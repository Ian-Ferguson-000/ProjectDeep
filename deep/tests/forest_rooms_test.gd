extends SceneTree

## Verdant Forest interconnected rooms: authored maps, door combinations, and a
## live walk through a floor's room graph.

const FOREST := preload("res://scenes/slasher/SlasherForest.tscn")
const ROOMS := preload("res://scripts/slasher/forest_room_library.gd")

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_expect(ROOMS.validate().is_empty(),"Forest room data is invalid: %s" % "; ".join(ROOMS.validate()))
	_expect(ROOMS.templates().size() >= 18,"Expected at least a dozen authored forest rooms")
	# Every map must work with any combination of open doors.
	var directions: Array = ROOMS.DIRECTIONS.keys()
	for template_value in ROOMS.templates():
		var template: Dictionary = template_value
		for mask in range(1,16):
			var open: Array = []
			for index in 4:
				if mask & (1 << index): open.append(directions[index])
			var layout := ROOMS.build_layout(template,open,mask)
			for direction in directions:
				var slot: Vector2i = layout.door_slots[direction]
				_expect(layout.cells.has(slot) == open.has(direction),"%s: %s door should be %s" % [template.id,direction,"open" if open.has(direction) else "sealed"])
			var blocked := {}
			for prop in layout.solid_props: blocked[Vector2i(prop.cell)] = true
			var reach := ROOMS._reachable(layout.cells,blocked,Vector2i(layout.doors[open[0]]))
			for direction in open: _expect(reach.has(Vector2i(layout.doors[direction])),"%s: %s door unreachable with doors %s" % [template.id,direction,open])
			var arrival := ROOMS.arrival_cell(layout,open[0])
			_expect(layout.cells.has(arrival) and not blocked.has(arrival),"%s: arrival through %s lands in a wall" % [template.id,open[0]])
			for path in layout.path_cells: _expect(layout.cells.has(path),"%s: trail leaves the walkable floor" % template.id)
	# Live floor: build the graph, walk through every door of the start room, and
	# make sure the gate room exists and leads deeper.
	var scene = FOREST.instantiate()
	scene._ensure_designer_controls()
	var state := RunState.new()
	state.start_new_run(GearData.create("rooms_test","Rooms Test",3,false,0,"","","warrior"),"forest")
	state.current_floor = 2
	scene.run_state = state
	root.add_child(scene)
	await process_frame
	_expect(scene.rooms_active,"Forest expedition did not use interconnected rooms")
	var graph: Dictionary = state.field_run
	var rooms: Array = graph.get("rooms",[])
	_expect(rooms.size() >= 8,"Floor 2 should have at least 8 rooms, has %d" % rooms.size())
	var roles := {}
	for room in rooms: roles[String(room.role)] = true
	for role in ["start","boss","treasure","shop","rest"]: _expect(roles.has(role),"Floor graph is missing a %s room" % role)
	_expect(scene.room_role == "start" and scene.exit_open,"The start room should be safe with open doors")
	_expect(scene.ground_layer.get_child(0).texture == preload("res://scripts/slasher/slasher_forest_terrain_art.gd").SHEET,"Rooms are not drawn with the new forest tile sheet")
	_expect(scene.door_nodes.size() == Dictionary(rooms[0].neighbors).size(),"Start room doors do not match its neighbours")
	var start_neighbors: Dictionary = rooms[0].neighbors
	for direction in start_neighbors:
		if scene.room_id != 0:
			_expect(false,"Lost the start room before trying the %s door" % direction)
			break
		scene.transition_cooldown = 0.0
		scene.player.global_position = scene.door_nodes[direction].global_position
		scene._check_doors()
		await process_frame
		await process_frame
		_expect(scene.room_id == int(start_neighbors[direction]),"Walking through the %s door did not enter the neighbour" % direction)
		var arrival: String = ROOMS.OPPOSITE[direction]
		_expect(scene.door_nodes.has(arrival),"Arrived through a door that does not exist on the other side")
		_expect(scene.player.global_position.distance_to(scene.door_nodes[arrival].global_position) < 150.0,"Player did not appear beside the door they came through")
		if scene.room_role in ["combat","elite","boss"] and not bool(state.get_field_room(scene.room_id).get("cleared",false)):
			_expect(not scene.exit_open and scene.enemies_remaining > 0,"A combat room opened its doors before it was cleared")
			var before: int = int(state.field_run.current_room)
			scene.player.global_position = scene.door_nodes[arrival].global_position
			scene.transition_cooldown = 0.0
			scene._check_doors()
			await process_frame
			_expect(int(state.field_run.current_room) == before,"Left a room while its doors were barred")
			scene.player.global_position = scene._world(Vector2i(scene.layout.width/2,scene.layout.height/2))
			for enemy in get_nodes_in_group("slasher_enemy"):
				if enemy is SlasherEnemy and not enemy.dead: scene._on_enemy_defeated(enemy,0); enemy.queue_free()
			await process_frame
			_expect(scene.exit_open and bool(state.get_field_room(scene.room_id).cleared),"Clearing the room did not open its doors")
		# Walk back to the start room.
		scene.transition_cooldown = 0.0
		scene.player.global_position = scene.door_nodes[arrival].global_position
		scene._check_doors()
		await process_frame
		await process_frame
		_expect(scene.room_id == 0,"Could not walk back to the start room from %s (exit_open=%s, foes=%d, doors=%s)" % [scene.room_role,scene.exit_open,scene.enemies_remaining,scene.door_nodes.keys()])
	# Revisiting keeps the same map.
	var first_template := String(state.get_field_room(int(start_neighbors.values()[0])).get("template_id",""))
	_expect(not first_template.is_empty(),"Visited rooms should remember their map")
	# Camps are peaceful: the rest room has a campfire at prop size and no foes,
	# and resting heals once.
	for room in rooms:
		if String(room.role) != "rest": continue
		state.enter_field_room(int(room.id),-1)
		scene._build_floor()
		await process_frame
		_expect(scene.enemies_remaining == 0 and scene.exit_open,"The campfire room should hold no enemies")
		var fire := scene.actor_layer.get_node_or_null("Campfire/Flames") as Sprite2D
		_expect(fire != null and fire.get_rect().size.y * fire.scale.y <= 70.0,"Campfire is missing or drawn oversized")
		scene.player.health = 1
		_expect(scene.rest_at_campfire() and scene.player.health > 1,"Resting at the campfire did not heal")
		_expect(not scene.rest_at_campfire(),"Rested twice at the same campfire")
	for template_value in ROOMS.templates():
		var roles_here: Array = Array(Dictionary(template_value).roles)
		for row in Array(Dictionary(template_value).map):
			if String(row).contains("F"): _expect(roles_here.all(func(r): return r in ["shop","rest"]),"%s has a campfire outside a camp room" % template_value.id)
			if String(row).contains("M"): _expect(roles_here == ["shop"],"%s has a merchant outside the trader camp" % template_value.id)
	# The gate room carries the root gate.
	var gate_id := -1
	for room in rooms:
		if String(room.role) == "boss": gate_id = int(room.id)
	state.enter_field_room(gate_id,-1)
	state.update_field_room(gate_id,{"cleared":true})
	scene._build_floor()
	await process_frame
	_expect(Vector2i(scene.layout.exit).x >= 0 and scene.exit_open,"The gate room has no open root gate after being cleared")
	# A new floor gets a new graph; the tutorial keeps the original single floor.
	var old_key := String(state.field_run.forest_floor_key)
	state.advance_slasher_floor()
	scene._build_floor()
	await process_frame
	_expect(String(state.field_run.forest_floor_key) != old_key and scene.room_id == 0,"Descending did not generate a fresh floor of rooms")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("FOREST_ROOMS_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(value: bool, message: String) -> void:
	if not value and not message.is_empty() and not failures.has(message): failures.append(message)
