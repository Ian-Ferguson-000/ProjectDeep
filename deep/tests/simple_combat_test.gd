extends SceneTree

## Simple combat numbers for balancing the Fighter (SimpleCombat):
## hearts from CON (20 = 5), damage from STR (20 = 4, never above 4), every
## enemy hit costs one heart, enemy health rescaled, old saves migrated once.

func _init() -> void: GameBalance.set_actions_override(GameBalance.ALL_ACTIONS)

const FOREST := preload("res://scenes/slasher/SlasherForest.tscn")
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _frames(count: int) -> void:
	for i in count: await process_frame

func _fighter(strength: int, constitution: int):
	var state := RunState.new()
	state.start_new_run(GearData.create("sword_shield","Sword and Shield",1,true,2,"charge","","warrior","block"),"forest")
	var profile: Dictionary = state._active_profile()
	profile["base_stats"]["str"] = strength; profile["base_stats"]["con"] = constitution
	state._recalculate_profile(profile); state._sync_health_from_profile(true)
	var scene = FOREST.instantiate(); scene._ensure_designer_controls(); scene.run_state = state; root.add_child(scene)
	await _frames(4)
	for node in root.find_children("*","",true,false):
		if node.get_script() and String(node.get_script().resource_path).contains("relic_choice_modal"): node.queue_free()
	paused = false
	await _frames(1)
	return scene

func _dummy(scene, health: int = 50) -> SlasherEnemy:
	var foe: SlasherEnemy = scene._spawn_enemy(scene.player.global_position + Vector2(400,0),"bandit_cutthroat","bandit_cutthroat")
	foe.max_health = health; foe.health = health
	foe.set_physics_process(false)
	return foe

func _run() -> void:
	_expect(SimpleCombat.enabled(),"Simple combat should be on")
	# ---- formulas
	for pair in [[20,5],[16,4],[12,3],[8,2],[2,1]]:
		_expect(SimpleCombat.hearts_for(pair[0]) == pair[1],"CON %d should give %d hearts, got %d" % [pair[0],pair[1],SimpleCombat.hearts_for(pair[0])])
	for pair in [[20,4],[15,3],[10,2],[5,1],[1,1],[30,4]]:
		_expect(SimpleCombat.damage_for(pair[0]) == pair[1],"STR %d should hit for %d, got %d" % [pair[0],pair[1],SimpleCombat.damage_for(pair[0])])
	_expect(SimpleCombat.player_hit(60,6,4) == 4,"Hits must never go above 4")
	_expect(SimpleCombat.damage_stat("warrior") == "str","The Fighter's damage should come from Strength")

	# ---- a real Fighter: health in hearts, hits from STR
	for pair in [[20,20,4,5],[10,12,2,3]]:
		var scene = await _fighter(pair[0],pair[1])
		var player: SlasherPlayer = scene.player
		_expect(player.max_health == pair[3] and player.health == pair[3],"CON %d: %d hearts, expected %d" % [pair[1],player.max_health,pair[3]])
		var hud: DungeonHud = scene.dungeon_hud
		_expect(hud.heart_count() == pair[3],"The HUD shows %d hearts, expected %d" % [hud.heart_count(),pair[3]])
		var foe := _dummy(scene)
		var dealt := foe.receive_attack(player._configured_attack(player._ability_tuning("basic"),"physical"),player)
		_expect(dealt == pair[2],"STR %d: a basic swing did %d, expected %d" % [pair[0],dealt,pair[2]])
		# Specials and everything else stay within 1..4.
		for slot in ["special","movement","defensive"]:
			var tuning: Dictionary = player._ability_tuning(slot)
			if tuning.is_empty(): continue
			var amount := foe.receive_attack(player._configured_attack(tuning,"physical"),player)
			_expect(amount >= 1 and amount <= 4,"STR %d %s hit for %d" % [pair[0],slot,amount])
		# Enemy hits cost one heart, however hard they were.
		var before := player.health
		player.invulnerable = 0.0; player.defense_window = 0.0
		player.receive_damage(9,Vector2.ZERO,foe)
		_expect(player.health == before - 1,"An enemy hit for 9 should cost exactly one heart (%d -> %d)" % [before,player.health])
		# A fully blocked hit costs nothing.
		player.invulnerable = 0.0; player.defense_kind = "guard"; player.defense_window = 1.0
		var guarded := player.health
		player.receive_damage(1,Vector2.ZERO,foe)
		_expect(player.health == guarded,"A guarded hit still cost a heart")
		scene.queue_free(); await _frames(2)

	# ---- enemy health is rescaled once on spawn
	var scene = await _fighter(15,15)
	var plain := SlasherEnemy.new()
	plain.configure(1,false,"bandit_cutthroat",false,"bandit_cutthroat")
	var raw := plain.max_health
	plain.free()
	var spawned: SlasherEnemy = scene._spawn_enemy(scene.player.global_position + Vector2(300,0),"bandit_cutthroat","bandit_cutthroat")
	await _frames(1)
	_expect(spawned.max_health == SimpleCombat.enemy_health(raw) and spawned.health == spawned.max_health,"Enemy health wasn't rescaled (%d -> %d)" % [raw,spawned.max_health])
	scene.queue_free(); await _frames(2)

	# ---- old saves: health migrated to hearts once
	var c := CampaignState.new()
	c.apply_post_tutorial_state("victory")
	for candidate in c.get_candidates(): c.recruit_candidate(candidate.id)
	var data := c.to_dict()
	data.erase("simple_hearts")
	var member_id := String(c.living_roster()[0].id)
	var encoded: Array = data.roster if data.roster is Array else Array(Dictionary(data.roster).values())
	for entry in encoded:
		if String(entry.get("id","")) == member_id: entry["max_health"] = 16; entry["current_health"] = 8
	var old := CampaignState.new(); old._load_dict(data)
	var migrated := old.character(member_id)
	var hearts := SimpleCombat.hearts_for(int(migrated.attributes.get("con",10)))
	_expect(migrated.max_health == hearts and migrated.current_health == int(ceil(hearts * 0.5)),"Old health 8/16 should become %d/%d, got %d/%d" % [int(ceil(hearts * 0.5)),hearts,migrated.current_health,migrated.max_health])
	# A save made with hearts isn't touched again (bonus hearts survive).
	migrated.max_health = hearts + 1; migrated.current_health = hearts + 1
	var again := CampaignState.new(); again._load_dict(old.to_dict())
	_expect(again.character(member_id).max_health == hearts + 1,"A hearts-era save was migrated again")

	if failures.is_empty():
		print("SIMPLE_COMBAT_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures: printerr("FAIL: " + failure)
		quit(1)
