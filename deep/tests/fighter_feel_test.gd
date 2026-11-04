extends SceneTree

## The Fighter's swing chain feels fluid: early presses are buffered, holding
## chains at full speed, swings step forward, the third swing lands heavier
## with a short reset, and no "swing 2/3" or cooldown text appears.
## The sidearm (secondary slot, F): a spear thrust that hits a line of foes.

func _init() -> void: GameBalance.set_actions_override(GameBalance.ALL_ACTIONS)

const FOREST := preload("res://scenes/slasher/SlasherForest.tscn")
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _frames(count: int) -> void:
	for i in count: await physics_frame

func _scene(secondary: String = ""):
	var state := RunState.new()
	state.start_new_run(GearData.create("sword_shield","Sword and Shield",1,true,2,"charge","","warrior","block"),"forest")
	state.secondary_override = secondary
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
	# ---- no sidearm equipped: F does nothing, slot hidden
	_expect(not player.has_secondary() and not bool(player.use_secondary().started),"F did something without a sidearm")
	await _frames(2)
	_expect(not scene.dungeon_hud.secondary_slot.visible,"The sidearm slot shows with nothing equipped")
	scene.queue_free(); await _frames(2)

	# ---- the Hunting Spear
	scene = await _scene("hunting_spear")
	player = scene.player
	_expect(player.has_secondary() and float(player.secondary.reach) >= 200.0,"The Hunting Spear didn't load as the sidearm")
	player.aim_direction = Vector2.RIGHT
	var origin: Vector2 = player.global_position
	var near := _dummy(scene,origin + Vector2(90,0))
	var far := _dummy(scene,origin + Vector2(190,0))
	var aside := _dummy(scene,origin + Vector2(120,140))
	await _frames(1)
	player.aim_direction = Vector2.RIGHT
	var thrust := player.use_secondary("keyboard")
	_expect(bool(thrust.started) and int(thrust.targets_hit) == 2,"The thrust should hit both foes in line (hit %d)" % int(thrust.targets_hit))
	_expect(near.health < 99 and far.health < 99 and aside.health == aside.max_health,"Thrust hits: near %d far %d aside %d/%d" % [near.health,far.health,aside.health,aside.max_health])
	_expect(99 - near.health == player.simple_base,"The spear should hit for the STR damage (%d, expected %d)" % [99 - near.health,player.simple_base])
	_expect(float(player.cooldowns.secondary) > 0.5,"The thrust has no cooldown")
	_expect(not bool(player.use_secondary().started) and player.buffered_slot == "","A thrust long before it's ready shouldn't be buffered")
	await _frames(2)
	_expect(scene.dungeon_hud.secondary_slot.visible,"The sidearm slot isn't on the HUD")
	scene.queue_free(); await _frames(2)

	# ---- the Hearth: every company gets a Hunting Spear; only Fighters can carry it
	var c := CampaignState.new(); c.apply_post_tutorial_state("victory")
	for candidate in c.get_candidates(): c.recruit_candidate(candidate.id)
	var spears: Array = c.armory.keys().filter(func(k): return String(c.armory[k].item_id) == "hunting_spear")
	_expect(spears.size() == 1,"The company should start with one Hunting Spear (%d)" % spears.size())
	var fighter: CharacterRecord = null
	var other: CharacterRecord = null
	for member in c.living_roster():
		if member.class_id == "warrior" and fighter == null: fighter = member
		elif member.class_id != "warrior" and other == null: other = member
	if fighter == null:
		fighter = c.create_character("warrior"); fighter.status = CharacterRecord.STATUS_AVAILABLE; c.roster[fighter.id] = fighter
	_expect(bool(HearthArmory.equip(c,fighter.id,String(spears[0])).ok) and fighter.equipment.get("secondary","") == spears[0],"A Fighter couldn't equip the spear")
	if other != null:
		HearthArmory.unequip(c,fighter.id,"secondary")
		_expect(not bool(HearthArmory.equip(c,other.id,String(spears[0])).ok),"A non-Fighter equipped the spear")
		HearthArmory.equip(c,fighter.id,String(spears[0]))
	var run := RunState.new(); run.attach_campaign(c); run.active_character_id = fighter.id
	_expect(run.secondary_weapon_id() == "hunting_spear","The run doesn't see the equipped sidearm")
	var again := CampaignState.new(); again._load_dict(c.to_dict())
	_expect(again.armory.keys().filter(func(k): return String(again.armory[k].item_id) == "hunting_spear").size() == 1,"Loading granted another spear")

	if failures.is_empty():
		print("FIGHTER_FEEL_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures: printerr("FAIL: " + failure)
		quit(1)
