extends SceneTree

## The Heartwood Colossus: guardian floor uses the arena, only open weak points
## take damage, patterns telegraph then attack, phases speed up, and its death
## opens the Root Gate and leaves a stump.

const FOREST := preload("res://scenes/slasher/SlasherForest.tscn")
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	_expect(ForestRoomLibrary.validate().is_empty(),"Room validation: %s" % "; ".join(ForestRoomLibrary.validate()))
	var arena := ForestRoomLibrary.template("heartwood_throne")
	_expect(Array(arena.get("roles",[])) == ["guardian"],"Arena should be a guardian room")
	var built := ForestRoomLibrary.build_layout(arena,["north","south","east","west"])
	_expect(Dictionary(built.colossus_cells).size() == 35 and not Dictionary(built.cells).has(Vector2i(built.colossus)),"Colossus body should block a 7x5 block")
	_expect(Vector2i(built.exit).x >= 0,"Arena has no gate")

	var state := RunState.new()
	state.start_new_run(GearData.create("c","C",3,false,0,"","","warrior"),"forest")
	state.current_floor = state.get_slasher_cycle_length()
	_expect(state.get_slasher_cycle_length() == 5 and int(GameBalance.get_dungeon("forest").floors) == 5,"Forest should have 5 floors to its guardian")
	var scene = FOREST.instantiate(); scene._ensure_designer_controls(); scene.run_state = state; root.add_child(scene)
	for i in 4: await process_frame
	for n in root.find_children("*","",true,false):
		if n.get_script() and String(n.get_script().resource_path).contains("relic_choice_modal"): n.queue_free()
	paused = false
	var gate_id := -1
	for r in state.field_run.rooms:
		if String(r.role) == "boss": gate_id = int(r.id)
	state.field_run["current_room"] = gate_id; state.field_run["previous_room"] = 0; state.field_run["arrival_direction"] = String(Dictionary(state.field_run.rooms[gate_id].neighbors).keys()[0])
	scene._build_floor(); await process_frame
	_expect(String(scene.layout.template_id) == "heartwood_throne","Guardian floor did not use the arena (got %s)" % scene.layout.template_id)
	var colossus: SlasherColossus = null
	for node in scene.actor_layer.get_children():
		if node is SlasherColossus: colossus = node
	_expect(colossus != null,"No colossus spawned")
	if colossus == null: _finish(); return
	_expect(scene.enemies_remaining == 1,"The colossus should be the only foe at the start")
	_expect(not colossus.is_in_group("slasher_damageable") and colossus.heart.is_in_group("slasher_damageable"),"Only weak points should be damageable")
	var player: SlasherPlayer = scene.player
	player.invulnerable = 999.0

	# Closed weak points shrug off hits.
	var health := colossus.health
	_expect(colossus.heart.receive_attack({"damage":50},player) == 0 and colossus.health == health,"A closed heart took damage")

	# First pattern is always a slam: telegraph at the player, then an open fist.
	player.global_position = scene._world(Vector2i(8,9))
	var saw_telegraph := false
	var fist: SlasherColossusWeakPoint = null
	for frame in 300:
		await physics_frame
		if colossus.state == "telegraph" and not colossus.telegraphs.is_empty() and String(colossus.telegraphs[0].kind) == "slam": saw_telegraph = true
		if not colossus.fists.is_empty(): fist = colossus.fists[0]; break
	_expect(saw_telegraph,"Slam was not telegraphed")
	_expect(fist != null and fist.open and fist.global_position.distance_to(player.global_position) < 90.0,"No open fist where the slam landed")
	_expect(not get_nodes_in_group("colossus_projectile").is_empty(),"Slam threw no splinters")
	if fist != null:
		var before := colossus.health
		var dealt := fist.receive_attack({"damage":10,"damage_type":"physical"},player)
		_expect(dealt > 0 and colossus.health < before,"An open fist did not pass damage to the colossus")
	# Window closes, fist goes.
	for frame in 260:
		await physics_frame
		if colossus.fists.is_empty() and colossus.state != "window": break
	_expect(colossus.fists.is_empty(),"Fist stayed after its window")

	# Bullets never spawn inside the body.
	colossus.state = "attack"; colossus.pattern = "spore_bloom"; colossus.pattern_step = 0; colossus.fire_timer = 0.0
	for frame in 3: await physics_frame
	var bullets := get_nodes_in_group("colossus_projectile")
	_expect(bullets.size() >= 16,"Spore bloom fired too few spores (%d)" % bullets.size())
	var body := Rect2(colossus.global_position - colossus.half,colossus.half * 2.0)
	_expect(not bullets.any(func(b): return body.has_point(b.global_position)),"A spore spawned inside the body")

	# Phase two at 66%: roar, bullets cleared, faster.
	colossus.heart.open_for(5.0)
	colossus.health = int(colossus.max_health * 0.67)
	colossus.receive_hit(int(colossus.max_health * 0.05))
	_expect(colossus.phase == 2 and colossus.state == "roar","No phase change at 66%% (phase %d, %s)" % [colossus.phase,colossus.state])
	await process_frame
	_expect(get_nodes_in_group("colossus_projectile").is_empty(),"Bullets not cleared on the roar")
	_expect(colossus._pace() > 1.0,"Phase two is not faster")

	# Death: gate opens, stump left behind.
	colossus.heart.open_for(5.0)
	colossus.health = 1
	colossus.heart.receive_attack({"damage":5},player)
	await process_frame
	_expect(scene.exit_open and scene.enemies_remaining == 0,"The colossus's death did not open the gate")
	_expect(scene.actor_layer.get_node_or_null("ColossusRemains") != null,"No stump left behind")
	_finish()

func _finish() -> void:
	await create_timer(0.2).timeout
	for n in root.get_children():
		if n.name.begins_with("SlasherForest") or n is Node2D: n.queue_free()
	await process_frame
	if failures.is_empty(): print("COLOSSUS_TESTS_PASSED"); quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(value: bool, message: String) -> void:
	if not value and not failures.has(message): failures.append(message)
