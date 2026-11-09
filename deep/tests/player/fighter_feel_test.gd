extends SceneTree

## The Fighter's swing chain feels fluid: early presses are buffered, holding
## chains at full speed, swings step forward, the third swing lands heavier
## with a short reset, and no "swing 2/3" or cooldown text appears.
## The spear is a Fighter weapon of its own (Borderkeeper's Spear moveset):
## recruits arrive with a sword or a spear, never both.

func _init() -> void: GameBalance.set_actions_override(GameBalance.ALL_ACTIONS)

const FOREST := preload("res://game/dungeons/forest/SlasherForest.tscn")
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _frames(count: int) -> void:
	for i in count: await physics_frame

func _scene(weapon: String = "sword_shield"):
	var state := RunState.new()
	state.start_new_run(HearthCatalog.gear(weapon),"forest")
	var scene = FOREST.instantiate(); scene._ensure_designer_controls(); scene.run_state = state; root.add_child(scene)
	await _frames(4)
	for node in root.find_children("*","",true,false):
		if node.get_script() and String(node.get_script().resource_path).contains("relic_choice_modal"): node.queue_free()
	paused = false
	for enemy in scene.actor_layer.get_children().filter(func(n): return n is SlasherEnemy): enemy.queue_free()
	await _frames(2)
	return scene

func _dummy(scene, at: Vector2) -> SlasherEnemy:
	var foe: SlasherEnemy = scene._spawn_enemy(at,"bandit_cutthroat","bandit_cutthroat")
	foe.max_health = 99; foe.health = 99
	foe.set_physics_process(false)
	return foe

func _run() -> void:
	root.size = Vector2i(1280,720)
	var scene = await _scene()
	var player: SlasherPlayer = scene.player
	player.aim_direction = Vector2.RIGHT
	# ---- buffered presses
	var first := player.use_action("basic","mouse")
	_expect(bool(first.started) and player.warrior_slash_chain == 1,"The first swing didn't start")
	var early := player.use_action("basic","mouse")
	_expect(not bool(early.started) and player.buffered_slot == "basic","A press during the swing wasn't buffered")
	await _frames(20)
	_expect(player.warrior_slash_chain == 2 and player.buffered_slot == "","The buffered swing didn't fire when ready")
	# A press long before the action is ready isn't buffered.
	player.cooldowns["basic"] = 2.0; player.buffered_slot = ""
	player.use_action("basic","mouse")
	_expect(player.buffered_slot == "","A press 2 seconds early shouldn't be remembered")
	player.cooldowns["basic"] = 0.0
	# ---- third swing: heavier, short reset, lunge forward
	player.aim_direction = Vector2.RIGHT
	var start_x := player.global_position.x
	var third := player.use_action("basic","mouse")
	_expect(bool(third.get("basic_chain_complete",false)),"The third swing didn't finish the chain")
	_expect(float(player.cooldowns.basic) <= 0.45,"The reset after the third swing is too long (%.2f)" % float(player.cooldowns.basic))
	await _frames(8)
	_expect(player.global_position.x > start_x + 8.0,"Swings should step forward (moved %.1f)" % (player.global_position.x - start_x))
	# ---- holding the button chains at full speed for the Fighter
	_expect(float(Dictionary(GameBalance.get_slasher_balance("input").get("held_basic_cooldown_multiplier_by_class",{})).get("warrior",2.25)) == 1.0,"Holding attack should chain at full speed for the Fighter")
	# ---- no swing-count or cooldown text
	_expect(scene.combo_label.text.is_empty() or scene.combo_label.text.begins_with("✦"),"Swing progress text is still shown: %s" % scene.combo_label.text)
	_expect(not String(scene.message_label.text).contains("cooling down"),"Cooldown messages are still shown")
	scene.queue_free(); await _frames(2)

	# ---- the spear: its own moveset, reaching far down a line
	scene = await _scene("borderkeepers_spear")
	player = scene.player
	_expect(player.uses_warrior_kit() and player.warrior_kit.weapon_id == "borderkeepers_spear","The spear didn't load its own moveset")
	_expect(player.weapon_stat == "str","The spear should hit with Strength")
	var origin: Vector2 = player.global_position
	var far := _dummy(scene,origin + Vector2(200,0))
	await _frames(1)
	player.aim_direction = Vector2.RIGHT
	var thrust := player.use_action("basic","mouse")
	_expect(bool(thrust.started) and far.health < far.max_health,"A spear thrust should reach a foe 200 px away")
	_expect(far.max_health - far.health >= 1 and far.max_health - far.health <= 4,"The thrust should land on the 1-4 scale (did %d)" % (far.max_health - far.health))
	scene.queue_free(); await _frames(2)
	# A sword swing doesn't reach that far.
	scene = await _scene("sword_shield")
	player = scene.player
	var out_of_reach := _dummy(scene,player.global_position + Vector2(200,0))
	await _frames(1)
	player.aim_direction = Vector2.RIGHT
	player.use_action("basic","mouse")
	_expect(out_of_reach.health == out_of_reach.max_health,"A sword swing shouldn't reach 200 px")
	scene.queue_free(); await _frames(2)

	# ---- recruits arrive with a sword or a spear, never both
	var c := CampaignState.new(); c.apply_post_tutorial_state("victory")
	var weapons := {}
	for i in 30:
		var fighter := c.create_character("warrior")
		weapons[fighter.gear_id] = int(weapons.get(fighter.gear_id,0)) + 1
		_expect(not fighter.equipment.has("secondary"),"A recruit has two weapons")
	_expect(weapons.has("sword_shield") and weapons.has("borderkeepers_spear") and weapons.size() == 2,"Fighters should arrive with a sword or a spear: %s" % [weapons])
	for candidate in c.get_candidates(): c.recruit_candidate(candidate.id)
	for member in c.living_roster():
		if member.class_id != "warrior": continue
		var held: Dictionary = c.armory.get(String(member.equipment.get("weapon","")),{})
		_expect(String(held.get("item_id","")) == member.gear_id and member.gear_id in ["sword_shield","borderkeepers_spear"],"%s isn't holding their own weapon" % member.display_name)
	# A save holding one of the old sidearm spears loads without it.
	var data := c.to_dict()
	var armory: Dictionary = data.armory
	armory["old_sidearm"] = {"item_id":"hunting_spear","owner":"","bound":false}
	var loaded := CampaignState.new(); loaded._load_dict(data)
	_expect(not loaded.armory.has("old_sidearm"),"An old sidearm spear survived loading")

	if failures.is_empty():
		print("FIGHTER_FEEL_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures: printerr("FAIL: " + failure)
		quit(1)
