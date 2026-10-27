extends SceneTree

## Sporelings and Kobold bandits: art, waking, attacking and spawning in the forest.

const FOREST := preload("res://scenes/slasher/SlasherForest.tscn")

var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	# Art builds with every animation the enemy code asks for.
	var spore := ForestCreatureArt.frames_for("sporeling")
	var kobold := ForestCreatureArt.frames_for("kobold")
	for state in ["idle","run","attack"]:
		for direction in ["down","left","right","up"]:
			_expect(spore != null and spore.has_animation("%s_%s" % [state,direction]),"Sporeling art missing %s_%s" % [state,direction])
			_expect(kobold != null and kobold.has_animation("%s_%s" % [state,direction]),"Kobold art missing %s_%s" % [state,direction])
	_expect(spore.has_animation("dormant") and spore.get_frame_count("wake") == 8,"Sporeling wake-up animation missing")
	_expect(kobold.get_frame_count("run_right") == 8 and kobold.get_frame_count("attack_left") == 5,"Kobold frames sliced wrongly")
	_expect(SlasherSpriteLibrary.enemy_frames("bandit_knifethrower") == kobold,"The bestiary cannot find bandit art")
	for id in ["sporeling","bandit_cutthroat","bandit_knifethrower"]:
		_expect(not GameBalance.get_slasher_journal_entry(id).is_empty(),"%s has no bestiary entry" % id)
		var made := SlasherEnemySceneLibrary.create(id)
		_expect(made is SlasherForestCreature,"%s does not create a forest creature" % id)
		made.free()

	var state := RunState.new()
	state.start_new_run(GearData.create("creatures","Creatures",3,false,0,"","","warrior"),"forest")
	state.current_floor = 3
	var scene = FOREST.instantiate()
	scene._ensure_designer_controls()
	scene.run_state = state
	root.add_child(scene)
	for frame in 4: await process_frame
	paused = false
	var player: SlasherPlayer = scene.player
	player.invulnerable = 0.0
	for node in get_nodes_in_group("slasher_enemy"): node.free()
	var origin: Vector2 = player.global_position

	# Sporelings sleep, then wake together when the player comes near.
	var a: SlasherForestCreature = scene._spawn_enemy(origin + Vector2(400,0),"sporeling","sporeling")
	var b: SlasherForestCreature = scene._spawn_enemy(origin + Vector2(440,30),"sporeling","sporeling")
	var far: SlasherForestCreature = scene._spawn_enemy(origin + Vector2(400,400),"sporeling","sporeling")
	_expect(a.ai_state == "dormant" and a.max_health < 20 and not a.elite,"Sporeling should start dormant and frail")
	await _frames(10)
	_expect(a.ai_state == "dormant","Sporeling woke with nobody near")
	a.global_position = origin + Vector2(120,0)
	b.global_position = origin + Vector2(160,30)
	await _frames(4)
	_expect(a.ai_state != "dormant" and b.ai_state != "dormant","Sporelings did not wake as a group")
	_expect(far.ai_state == "dormant","A distant sporeling woke too")
	var health := player.health
	await _frames(150)
	_expect(player.health < health,"Woken sporelings never bit the player")
	far.receive_hit(1)
	_expect(far.ai_state == "waking","Hitting a dormant sporeling did not wake it")
	for node in get_nodes_in_group("slasher_enemy"): node.free()

	# Cutthroat lunges through the player.
	player.health = player.max_health; player.invulnerable = 0.0
	var cutthroat: SlasherForestCreature = scene._spawn_enemy(origin + Vector2(150,0),"bandit_cutthroat","bandit_cutthroat")
	cutthroat.activation_delay = 0.0
	var saw_windup := false
	health = player.health
	for frame in 200:
		await physics_frame
		player.invulnerable = 0.0
		if cutthroat.ai_state == "windup": saw_windup = true
		if player.health < health: break
	_expect(saw_windup,"Cutthroat never telegraphed its lunge")
	_expect(player.health < health,"Cutthroat lunge never connected")
	cutthroat.free()

	# Knife-thrower keeps range and throws knives (a fan on floor 3+).
	player.health = player.max_health
	var thrower: SlasherForestCreature = scene._spawn_enemy(origin + Vector2(220,0),"bandit_knifethrower","bandit_knifethrower")
	thrower.activation_delay = 0.0
	var most_knives := 0
	health = player.health
	for frame in 600:
		await physics_frame
		player.invulnerable = 0.0
		var knives := 0
		for node in get_nodes_in_group("slasher_hostile_projectile"):
			if node.visual_type == "knife": knives += 1
		most_knives = maxi(most_knives,knives)
	_expect(most_knives >= 1,"Knife-thrower never threw")
	_expect(most_knives >= 3,"Knife-thrower never threw a fan of three on floor 3")
	_expect(player.health < health,"No knife ever hit the player")
	_expect(thrower.global_position.distance_to(player.global_position) > 110.0,"Knife-thrower closed to melee range")
	thrower.free()

	# The forest spawns them, and sporelings come in clusters.
	var counts := {}
	for floor_number in range(1,6):
		state.current_floor = floor_number
		var room_counts := {}
		for index in 8:
			var spec: Dictionary = scene._normal_enemy_spec(index,room_counts)
			counts[String(spec.visual_id)] = int(counts.get(String(spec.visual_id),0)) + 1
	for id in ["sporeling","bandit_cutthroat","bandit_knifethrower"]: _expect(counts.has(id),"The forest never picks %s" % id)
	state.current_floor = 3
	var before := get_nodes_in_group("slasher_enemy").size()
	scene._spawn_sporeling_cluster(origin + Vector2(0,200))
	_expect(get_nodes_in_group("slasher_enemy").size() - before == 3,"A floor-3 sporeling cluster should add three more")

	scene.queue_free()
	await _frames(3)
	if failures.is_empty(): print("FOREST_CREATURES_TESTS_PASSED"); quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _frames(count: int) -> void:
	for index in count: await physics_frame

func _expect(value: bool, message: String) -> void:
	if not value and not failures.has(message): failures.append(message)
