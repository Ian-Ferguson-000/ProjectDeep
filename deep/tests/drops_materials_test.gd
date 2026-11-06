extends SceneTree

## Enemy drops: basic enemies drop only crafting/quest materials, mini bosses drop
## their trophy and sometimes a relic (never an active item), bosses drop their
## trophy. Materials are carried, picked up, banked on a safe return, lost on a
## death, saved, and can be handed to visitors.

const FOREST := preload("res://scenes/slasher/SlasherForest.tscn")
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _frames(count: int) -> void:
	for i in count: await process_frame

func _drops(forest) -> Array:
	var found: Array = []
	for node in forest.loot_nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion(): found.append(node)
	return found

func _clear_drops(forest) -> void:
	for node in _drops(forest): node.free()
	forest.loot_nodes.clear()

func _run() -> void:
	# ---- data
	_expect(Materials.for_enemy("sporeling","sporeling",false) == "spore_sac","Sporelings should drop spore sacs")
	_expect(Materials.for_enemy("skeleton","",false) == "grave_dust","Skeletons should drop grave dust")
	_expect(Materials.for_enemy("wolf_vanguard","",false) == "wolf_pelt","Wolves should drop pelts")
	_expect(Materials.for_enemy("briar_guardian","elite_guardian",true) == "briar_heart","The briar guardian's trophy is wrong")
	for id in Dictionary(Materials.data().get("materials",{})):
		_expect(not Materials.material_name(id).is_empty(),"Material %s has no name" % id)

	var state := RunState.new()
	state.start_new_run(GearData.create("t","Tester",3,false,0,"","","warrior"),"forest")
	state.current_floor = 3
	var forest = FOREST.instantiate(); forest._ensure_designer_controls(); forest.run_state = state; root.add_child(forest)
	await _frames(4)
	for node in root.find_children("*","",true,false):
		if node.get_script() and String(node.get_script().resource_path).contains("relic_choice_modal"): node.queue_free()
	paused = false
	for enemy in get_nodes_in_group("slasher_enemy"): enemy.free()
	_clear_drops(forest)
	var table: Dictionary = forest.drop_table()
	var saved_basic := float(table.get("basic_material_chance",0.3)); var saved_mini := float(table.get("mini_boss_item_chance",0.3))
	var here: Vector2 = forest.player.global_position + Vector2(400,0)

	# ---- basic enemies: materials only (even "elite" floor-3 ones)
	table["basic_material_chance"] = 1.0
	for id in ["sporeling","wolf_vanguard","feral_wolf","bandit_knifethrower"]:
		var enemy = forest._spawn_enemy(here,id,id if id in ["sporeling","bandit_knifethrower"] else "")
		forest._roll_enemy_drop(enemy); enemy.free()
	var kinds: Array = _drops(forest).map(func(n): return String(n.get_meta("kind","gold")))
	_expect(kinds.size() == 4 and kinds.all(func(k): return k == "material"),"Basic enemies should drop exactly one material each, got %s" % [kinds])
	var ids: Array = _drops(forest).map(func(n): return String(n.get_meta("material_id","")))
	_expect(ids == ["spore_sac","wolf_pelt","wolf_pelt","kobold_fang"],"Basic drops were the wrong materials: %s" % [ids])
	_clear_drops(forest)
	table["basic_material_chance"] = 0.0
	var quiet = forest._spawn_enemy(here,"sporeling","sporeling"); forest._roll_enemy_drop(quiet); quiet.free()
	_expect(_drops(forest).is_empty(),"A basic enemy dropped something when the chance was 0")

	# ---- mini boss: trophy x2, relic only by chance, never an active item
	for chance in [0.0,1.0]:
		table["mini_boss_item_chance"] = chance
		for i in 6:
			var guardian = forest._spawn_enemy(here,"briar_guardian","elite_guardian",false,true)
			forest._roll_enemy_drop(guardian); guardian.free()
		var mini_kinds: Array = _drops(forest).map(func(n): return String(n.get_meta("kind","gold")))
		_expect(mini_kinds.count("material") == 12,"Mini bosses should always drop two trophies (chance %s): %s" % [chance,mini_kinds])
		_expect(not mini_kinds.has("active_item") and not mini_kinds.has("active"),"A mini boss dropped an active item")
		if chance == 0.0: _expect(mini_kinds.size() == 12,"A mini boss dropped a relic with a 0 chance: %s" % [mini_kinds])
		else: _expect(mini_kinds.size() > 12,"A mini boss never dropped a relic with a 100%% chance: %s" % [mini_kinds])
		_clear_drops(forest)

	# ---- boss: the trophy only
	var boss = forest._spawn_enemy(here,"heartwood_colossus","colossus",true)
	forest._roll_enemy_drop(boss); boss.free()
	var boss_ids: Array = _drops(forest).map(func(n): return String(n.get_meta("material_id","")))
	var boss_kinds: Array = _drops(forest).map(func(n): return String(n.get_meta("kind","")))
	_expect(boss_ids.has("heartwood_seed") and boss_kinds.has("relic") and boss_kinds.size() == 2,"The colossus should drop its seed and an item (Isaac boss item): %s %s" % [boss_ids,boss_kinds])
	_clear_drops(forest)
	table["basic_material_chance"] = saved_basic; table["mini_boss_item_chance"] = saved_mini

	# ---- picking one up
	forest._spawn_material_drop(here,"wolf_pelt")
	forest._collect_loot(_drops(forest)[0])
	_expect(int(state.materials.get("wolf_pelt",0)) == 1,"Picking up a pelt didn't carry it: %s" % [state.materials])
	var snapshot: Dictionary = state.run_snapshot()
	var restored := RunState.new(); restored.current_floor = state.current_floor; restored.restore_run_snapshot(snapshot)
	_expect(int(restored.materials.get("wolf_pelt",0)) == 1,"Carried materials weren't in the run save")
	forest.queue_free(); await _frames(2)

	# ---- banking: home safe keeps them, death loses them
	for outcome in ["victory","death"]:
		var c := CampaignState.new(); c.apply_post_tutorial_state("victory")
		for candidate in c.get_candidates(): c.recruit_candidate(candidate.id)
		var hero: CharacterRecord = c.living_roster()[0]
		c.begin_expedition([hero.id],"forest")
		HearthExpeditions.settle(c,c.expedition,outcome,{"materials":{"spore_sac":3}})
		var report: Dictionary = c.return_reports.back() if not c.return_reports.is_empty() else {}
		if outcome == "victory":
			_expect(int(c.materials.get("spore_sac",0)) == 3 and int(Dictionary(report.get("materials",{})).get("spore_sac",0)) == 3,"Materials weren't banked on a safe return: %s" % [c.materials])
			var loaded := CampaignState.new(); loaded._load_dict(CampaignState._migrate_dict(c.to_dict()))
			_expect(int(loaded.materials.get("spore_sac",0)) == 3,"Banked materials didn't save")
			# ---- visitors take them
			c.calendar_day = 4
			var accepted: Dictionary = VisitorService.accept(c,"calden_ashwick","spore_samples")
			_expect(bool(accepted.get("ok",false)),"Couldn't accept the spore samples job: %s" % [accepted])
			_expect(not VisitorService.can_deliver(c,"calden_ashwick","spore_samples"),"Delivered 5 sacs with only 3")
			Materials.add(c.materials,"spore_sac",2)
			_expect(VisitorService.can_deliver(c,"calden_ashwick","spore_samples"),"Couldn't deliver 5 sacs")
			var delivered: Dictionary = VisitorService.deliver(c,"calden_ashwick","spore_samples")
			_expect(bool(delivered.get("ok",false)) and int(c.materials.get("spore_sac",0)) == 0,"Delivering sacs didn't take them: %s %s" % [delivered,c.materials])
		else:
			_expect(c.materials.is_empty(),"Materials were banked after a death: %s" % [c.materials])

	if failures.is_empty():
		print("DROPS_MATERIALS_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures: printerr("FAIL: " + failure)
		quit(1)
