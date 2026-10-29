extends SceneTree

## The Stone Crypt as rooms: painted 1.5x rooms, stone walls, gate guardians on
## every floor (and the forest's reflecting Elite Guardian on every forest
## floor), the new crypt foes, and the Charnel King.

func _init() -> void: GameBalance.set_actions_override(GameBalance.ALL_ACTIONS)

const CRYPT := preload("res://scenes/slasher/SlasherCrypt.tscn")
const FOREST := preload("res://scenes/slasher/SlasherForest.tscn")
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _frames(count: int) -> void:
	for i in count: await process_frame

func _scene(packed: PackedScene, dungeon: String, floor_number: int):
	var state := RunState.new()
	state.start_new_run(GearData.create("t","Tester",3,false,0,"","","warrior"),dungeon)
	state.current_floor = floor_number
	var scene = packed.instantiate(); scene._ensure_designer_controls(); scene.run_state = state; root.add_child(scene)
	await _frames(4)
	for node in root.find_children("*","",true,false):
		if node.get_script() and String(node.get_script().resource_path).contains("relic_choice_modal"): node.queue_free()
	paused = false
	scene.player.invulnerable = 9999.0
	return scene

func _enter_role(scene, role: String) -> void:
	var target := -1
	for value in scene.run_state.field_run.rooms:
		if String(value.role) == role: target = int(value.id)
	scene.run_state.field_run["current_room"] = target; scene.run_state.field_run["previous_room"] = -1
	scene._build_floor()
	await _frames(2)
	for node in root.find_children("GuardianBanner","",true,false): node.queue_free()

func _foes(scene) -> Array:
	return scene.actor_layer.get_children().filter(func(n): return n is SlasherEnemy and not n.dead)

func _run() -> void:
	# ---- rooms
	ForestRoomLibrary.use_dungeon("crypt")
	var templates := ForestRoomLibrary.templates()
	_expect(templates.size() >= 18,"Expected the crypt's painted rooms, found %d" % templates.size())
	_expect(ForestRoomLibrary.validate().is_empty(),"Crypt rooms invalid: %s" % "; ".join(ForestRoomLibrary.validate()))
	for template in templates:
		var size := ForestRoomLibrary.size_of(template)
		_expect(size in [Vector2i(41,23),Vector2i(53,29)],"%s is %s, not a 1.5x crypt size" % [template.id,size])
	ForestRoomLibrary.use_dungeon("forest")
	_expect(ForestRoomLibrary.templates().size() >= 18 and ForestRoomLibrary.size_of(ForestRoomLibrary.templates()[0]).x <= 35,"Switching back did not restore the forest's rooms")

	# ---- forest: the reflecting Elite Guardian holds the gate on floor 1
	var forest = await _scene(FOREST,"forest",1)
	await _enter_role(forest,"boss")
	var gate_foes: Array = _foes(forest).filter(func(e): return e.mini_boss and e.behavior_id == "elite_guardian")
	_expect(gate_foes.size() == 1,"Forest floor 1 gate room has no reflecting Elite Guardian")
	_expect(bool(forest.layout.is_guarded) and not forest.exit_open,"Forest floor 1 gate is not guarded")
	if gate_foes.size() == 1:
		var guardian: SlasherEnemy = gate_foes[0]
		guardian.receive_hit(1)
		_expect(not guardian.guardian_burst_queue.is_empty(),"Elite Guardian did not answer a hit with its burst")
		guardian.health = 1; guardian.damage_shield_remaining = 0.0
		guardian.receive_hit(5)
		await _frames(2)
		_expect(forest.exit_open,"Killing the forest gate guardian did not open the gate")
	forest.queue_free(); await _frames(2)

	# ---- crypt floor 1: stone rooms, the Crypt Lord at the stairs
	var crypt = await _scene(CRYPT,"crypt",1)
	_expect(crypt.rooms_active,"Crypt is not using rooms")
	_expect(crypt.get_node_or_null("StoneWalls") != null,"Crypt rooms have no stone walls")
	_expect(crypt.canopy_layer.get_children().filter(func(n): return String(n.name).begins_with("Thicket")).is_empty(),"Crypt rooms grew forest thicket")
	_expect(int(crypt.layout.width) in [41,53],"Crypt room is not crypt sized")
	await _enter_role(crypt,"combat")
	var allowed := ["skeleton","grave_rat","ghoul","skeletal_archer",""]
	for foe in _foes(crypt): _expect(String(foe.behavior_id) in allowed,"Floor 1 crypt spawned %s" % foe.behavior_id)
	_expect(not crypt.crypt_hazards.is_empty(),"Crypt fighting room has no hazards")
	await _enter_role(crypt,"boss")
	var lords: Array = _foes(crypt).filter(func(e): return e.mini_boss and e.visual_id == "crypt_boss")
	_expect(lords.size() == 1,"Crypt floor 1 stairs are not held by the Crypt Lord")
	_expect(String(crypt._door_hint({"role":"boss","visited":true,"cleared":true})) == "Stairs Down","Crypt gate is not called the stairs")
	crypt.queue_free(); await _frames(2)

	# ---- the new foes
	crypt = await _scene(CRYPT,"crypt",3)
	for foe in _foes(crypt): foe.receive_hit(99999)
	await _frames(1)
	var origin: Vector2 = crypt.player.global_position
	var made := {}
	for id in ["grave_rat","ghoul","gravedigger","tomb_guard","revenant"]:
		var enemy: SlasherEnemy = crypt._spawn_enemy(origin + Vector2(400,0),id,id)
		made[id] = enemy
		_expect(enemy is SlasherCryptCreature,"%s is not a crypt creature" % id)
		_expect(enemy.sprite != null and enemy.sprite.sprite_frames != null,"%s has no sprites" % id)
	var rats: Array = _foes(crypt).filter(func(e): return e.behavior_id == "grave_rat")
	_expect(rats.size() == 3,"Grave rats did not come as a nest of three")
	_expect(String(made.grave_rat.ai_state) == "dormant" and not made.grave_rat.sprite.visible,"A grave rat is not hiding under its bone pile")
	made.grave_rat.wake()
	await _frames(2)
	_expect(rats.all(func(r): return String(r.ai_state) != "dormant"),"Waking one grave rat did not wake its nest")
	var guard: SlasherCryptCreature = made.tomb_guard
	guard.activation_delay = 0.0
	var front: Vector2 = guard.global_position + guard.facing_vector * 60.0
	var behind: Vector2 = guard.global_position - guard.facing_vector * 60.0
	_expect(guard.blocks_from(front) and not guard.blocks_from(behind),"Tomb guard shield does not cover only its front")
	var before := guard.health
	crypt.player.global_position = front
	_expect(guard.receive_attack({"damage":5},crypt.player) == 0 and guard.health == before,"Tomb guard took a hit on its shield")
	crypt.player.global_position = behind
	_expect(guard.receive_attack({"damage":5},crypt.player) > 0,"Tomb guard blocked a hit from behind")
	guard.ai_state = "recovery"; guard.state_timer = 1.0; guard._process_shieldbearer(0.016)
	_expect(not guard.shield_up and not guard.blocks_from(front),"Tomb guard shield stays up after its bash")
	crypt.player.global_position = origin
	var revenant: SlasherCryptCreature = made.revenant
	revenant.receive_hit(99999)
	_expect(not revenant.dead and String(revenant.ai_state) == "bones","Revenant died instead of collapsing")
	revenant.state_timer = 0.0; revenant.activation_delay = 0.0; revenant.hit_stun_timer = 0.0
	revenant._process_revenant(0.016)
	_expect(revenant.has_risen and revenant.health == int(round(revenant.max_health * 0.5)),"Revenant did not rise at half health")
	revenant.receive_hit(99999)
	_expect(revenant.dead,"Revenant rose a second time")
	var digger: SlasherCryptCreature = made.gravedigger
	digger._throw_knives(3)
	await _frames(1)
	var bones: Array = crypt.actor_layer.get_children().filter(func(n): return n is SlasherHostileProjectile and n.visual_type == "bone")
	_expect(bones.size() == 3,"Gravedigger did not throw bones")
	_expect(String(made.ghoul.kind) == "bandit_cutthroat","Ghoul does not fight like a cutthroat")
	# The crypt's champion in elite rooms.
	await _enter_role(crypt,"elite")
	_expect(_foes(crypt).any(func(e): return e.mini_boss and e.behavior_id == "tomb_guard"),"Crypt elite room has no Tomb Guard champion")
	crypt.queue_free(); await _frames(2)

	# ---- floor 5: the Charnel King
	crypt = await _scene(CRYPT,"crypt",5)
	await _enter_role(crypt,"boss")
	_expect(String(crypt.layout.template_id) == "charnel_throne","Crypt guardian floor did not use the Charnel Throne")
	var kings: Array = crypt.actor_layer.get_children().filter(func(n): return n is SlasherCharnelKing)
	_expect(kings.size() == 1,"The Charnel King is missing")
	if kings.size() == 1:
		var king: SlasherCharnelKing = kings[0]
		_expect(king.arena.has_area() and king.arena.size.x > 2000.0,"The Charnel King was not given its arena")
		_expect(crypt.player.camera.zoom.x < 1.0,"The camera did not pull back in the guardian arena")
		_expect(not king.is_in_group("slasher_damageable"),"The King's body can be hit")
		king.set_physics_process(false)
		# Grave Sweep: the lane hurts, the hand opens at the end.
		king.cycle_count = 0; king.pattern = ""; king._start_next_pattern()
		_expect(king.pattern == "grave_sweep" and king.sweeps.size() == 1 and king.telegraphs.size() == 1,"The first attack was not a single telegraphed sweep")
		var lane: Rect2 = king.sweeps[0].rect
		crypt.player.invulnerable = 0.0
		crypt.player.global_position = Vector2(lane.get_center().x,lane.get_center().y)
		var health_before: int = crypt.player.health
		king._begin_attack()
		for step in 200:
			if king.state != "attack": break
			king._run_sweep(0.02)
			crypt.player.invulnerable = 0.0 if step < 1 else crypt.player.invulnerable
		_expect(crypt.player.health < health_before,"Standing in the sweep lane did no damage")
		crypt.player.invulnerable = 9999.0
		_expect(king.state == "window" and king.fists.size() == 1 and king.fists[0].open,"No hand opened after the sweep")
		var king_health := king.health
		king.fists[0].receive_attack({"damage":10},crypt.player)
		_expect(king.health < king_health,"Hitting the open hand did not hurt the King")
		king._end_window()
		# Soul Wail: rings with a gap, then the gem opens.
		king.state = "rest"; king.pattern = "grave_sweep"
		king.pattern = "soul_wail"; king.state = "telegraph"; king.timer = 0.0
		king._begin_attack()
		var before_bullets := get_nodes_count("colossus_projectile")
		king.fire_timer = 0.0; king._run_wail(0.016)
		var fired := get_nodes_count("colossus_projectile") - before_bullets
		_expect(fired > 0 and fired < int(king._t("wail_bullets",28)),"Soul wail did not leave a gap (%d bullets)" % fired)
		for wave in 4:
			if king.state == "window": break
			king.fire_timer = 0.0; king._run_wail(0.016)
		_expect(king.state == "window" and king.heart.open,"The soul gem did not open after the wail")
		king.heart.close(); king._clear_bullets()
		# Phase two: two lanes, and bone rain becomes possible.
		# Hits are capped per blow for bosses, so set health just above the line, then hit.
		king.health = int(king.max_health * 0.6) + 1; king.damage_shield_remaining = 0.0; king.receive_hit(5)
		_expect(king.phase >= 2,"The King did not reach phase two")
		king.state = "rest"; king.pattern = ""; king.cycle_count = 0; king._start_next_pattern()
		_expect(king.sweeps.size() == 2,"Phase two sweeps did not use two lanes")
		for sweep in king.sweeps:
			_expect(absf(Rect2(sweep.rect).get_center().y - king.global_position.y) >= king.half.y or sweep == king.sweeps[0],"A second lane crosses the King's body")
		king.sweeps.clear(); king.telegraphs.clear()
		king.pattern = "soul_wail"; king.state = "telegraph"
		for attempt in 12:
			if king.pattern == "bone_rain": break
			king._start_next_pattern()
		_expect(king.rain.size() == int(king._t("rain_count",7)),"Bone rain did not mark its circles")
		king._begin_attack()
		for step in 400:
			if king.state != "attack": break
			king._run_rain(0.02)
		_expect(king.state == "window","Bone rain never finished")
		# Death opens the stairs and leaves bones.
		king._clear_bullets()
		king.health = 1; king.damage_shield_remaining = 0.0; king.receive_hit(5)
		await _frames(3)
		_expect(crypt.exit_open,"The stairs did not open when the King fell")
		_expect(crypt.actor_layer.get_node_or_null("ColossusRemains") != null,"The King left nothing behind")
	crypt.queue_free(); await _frames(3)

	if failures.is_empty(): print("CRYPT_ROOMS_TESTS_PASSED"); quit(0)
	else:
		for failure in failures: printerr("FAIL: " + failure)
		quit(1)

func get_nodes_count(group: String) -> int:
	return get_nodes_in_group(group).size()
