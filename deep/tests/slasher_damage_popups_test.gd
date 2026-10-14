extends SceneTree

const ENEMY := preload("res://scripts/slasher/slasher_enemy.gd")
const CRYPT_ENEMY := preload("res://scripts/slasher/slasher_crypt_enemy.gd")
const PROP := preload("res://scripts/slasher/slasher_breakable_prop.gd")
const FOREST := preload("res://scenes/slasher/SlasherForest.tscn")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var enemy := ENEMY.new()
	enemy.configure(2, false, "feral_wolf")
	enemy.health = 1000
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	var dealt := enemy.receive_attack({"damage": 7, "damage_type": "fire", "damage_source": "Burn", "critical": true})
	var layer := arena.get_node("DamagePopups")
	var popup := _latest(layer, enemy)
	assert(popup.amount == dealt and popup.damage_type == "fire" and popup.source_label == "Burn" and popup.critical, "Dungeon hit lost resolved damage or attack metadata")
	assert(layer.target_popups[enemy.get_instance_id()].size() == 1, "One hit created duplicate popups")
	enemy.receive_hit(3)
	popup = _latest(layer, enemy)
	assert(popup.amount == 3 and popup.damage_type == "physical" and not popup.critical and popup.source_label.is_empty(), "Direct hit inherited previous attack metadata")
	var boss := ENEMY.new()
	boss.configure(8, true, "dark_druid")
	arena.add_child(boss)
	boss.set_physics_process(false)
	dealt = boss.receive_attack({"damage": 99999, "damage_type": "ice"})
	assert(dealt < 99999 and _latest(layer, boss).amount == dealt, "Boss popup displays raw damage instead of capped damage")
	var crypt := CRYPT_ENEMY.new()
	crypt.configure(2, false, "skeleton")
	arena.add_child(crypt)
	crypt.set_physics_process(false)
	crypt.transition_time = 1.0
	assert(crypt.receive_attack({"damage": 9}) == 0 and not layer.target_popups.has(crypt.get_instance_id()), "Immune crypt enemy produced a damage popup")
	crypt.transition_time = 0.0
	crypt.receive_attack({"damage": 2, "damage_type": "arcane"})
	assert(_latest(layer, crypt).damage_type == "arcane", "Crypt enemy is missing feedback")
	for index in 20: enemy.receive_attack({"damage": 1})
	assert(layer.target_popups[enemy.get_instance_id()].size() == 6, "Rapid damage creates unbounded overlapping popups")
	var barrel := PROP.new()
	barrel.setup("barrel", Vector2i.ZERO)
	arena.add_child(barrel)
	dealt = barrel.receive_attack({"damage": 999, "damage_type": "lightning"})
	popup = _latest(layer, barrel)
	assert(barrel.destroyed and popup.amount == dealt and popup.damage_type == "lightning", "Breaking hit has no popup")
	assert(barrel.receive_attack({"damage": 1}) == 0 and layer.target_popups[barrel.get_instance_id()].size() == 1, "Destroyed prop produced another popup")
	var chest := PROP.new()
	chest.setup("chest", Vector2i.ONE)
	arena.add_child(chest)
	chest.open_chest()
	assert(chest.receive_attack({"damage": 5}) == 0 and not layer.target_popups.has(chest.get_instance_id()), "Open chest produced a damage popup")
	enemy.health = 1
	enemy.receive_attack({"damage": 4})
	var finishing_popup := _latest(layer, enemy)
	await process_frame
	assert(not is_instance_valid(enemy) and is_instance_valid(finishing_popup), "Lethal damage number disappeared with its target")
	await create_timer(1.0).timeout
	assert(layer.target_popups.is_empty() and layer.popup_counts.is_empty() and layer.get_child_count() == 0, "Expired feedback leaks nodes or bookkeeping")
	arena.queue_free()
	await process_frame
	if "--capture" in OS.get_cmdline_user_args(): await _capture()
	print("Slasher damage popups: resolved damage, critical/type/source, props, crypt immunity, lethal hits, overlap limit and cleanup passed.")
	quit()

func _latest(layer: Node, target: Node) -> Node:
	return layer.target_popups[target.get_instance_id()].back().get_ref()

func _capture() -> void:
	var scene = FOREST.instantiate()
	scene._ensure_designer_controls()
	var state := RunState.new()
	state.start_new_run(GearData.create("popup_test", "Popup Test", 3, false, 0, "", "", "warrior"), "forest")
	state.current_floor = 2
	state.floor_seed = 83492791 - state.current_floor * 997
	scene.run_state = state
	root.add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	await create_timer(1.0).timeout
	var origin: Vector2 = scene.player.global_position
	var enemy: SlasherEnemy = scene._spawn_enemy(origin + Vector2(120, -35), "feral_wolf")
	enemy.receive_attack({"damage": 7, "damage_type": "fire", "damage_source": "Burn"})
	enemy.receive_attack({"damage": 5, "damage_type": "physical", "critical": true})
	var barrel := PROP.new()
	barrel.setup("barrel", Vector2i.ZERO)
	scene.actor_layer.add_child(barrel)
	barrel.global_position = origin + Vector2(-80, 95)
	barrel.receive_attack({"damage": 3, "damage_type": "arcane"})
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/dungeon_damage_popups.png")
	scene.queue_free()
	await process_frame
