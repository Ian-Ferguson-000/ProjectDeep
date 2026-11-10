extends SceneTree


## Dash, special and block are switched off in progression.json; this checks them anyway.
func _init() -> void:
	GameBalance.set_actions_override(GameBalance.ALL_ACTIONS)


## Item effects in real-time combat: attack speed, move speed, crescent waves,
## chain lightning, burning, chilling, kill bursts, elite bonuses and periodic relics.

var failures: Array[String] = []
var player: SlasherPlayer
var state: RunState


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# No champions: their bonus damage would muddle the exact damage checks.
	SlasherEnemy.champion_override = 0
	# Every proc in the item file uses a known type and trigger.
	for item_id in GameBalance.get_items():
		for proc in Array(GameBalance.get_slasher_item_effects(String(item_id)).get("procs", [])):
			_expect(
				(
					String(proc.get("type", ""))
					in [
						"wave",
						"chain_lightning",
						"burn",
						"chill",
						"nova",
						"heal",
						"drop_potion",
						"drop_gold"
					]
				),
				"%s has an unknown proc type %s" % [item_id, proc.get("type", "")]
			)
			_expect(
				String(proc.get("on", "hit")) in ["swing", "special", "dash", "hit", "kill"],
				"%s has an unknown proc trigger %s" % [item_id, proc.get("on", "")]
			)

	# Attack speed shortens basic cooldowns; move speed raises the speed multiplier.
	await _fresh_player("warrior", [])
	player.use_action("basic")
	var plain := float(player.cooldowns.basic)
	await _fresh_player("warrior", ["duelists_whetstone"])
	player.use_action("basic")
	_expect(
		is_equal_approx(float(player.cooldowns.basic), plain / 1.15),
		(
			"Attack speed did not shorten the basic cooldown (%.3f vs %.3f)"
			% [player.cooldowns.basic, plain]
		)
	)
	# Dexterity is walking speed for everyone; speed items add Dexterity.
	await _fresh_player("warrior", [])
	var base_dex: int = int(state.get_stats().get("dex", 10))
	_expect(
		(
			player.dexterity == base_dex
			and is_equal_approx(player.speed, SimpleCombat.move_speed(base_dex))
		),
		"Walking speed doesn't come from Dexterity (%s at DEX %d)" % [player.speed, base_dex]
	)
	_expect(
		(
			SimpleCombat.move_speed(16) > SimpleCombat.move_speed(12)
			and SimpleCombat.move_speed(12) > SimpleCombat.move_speed(8)
		),
		"More Dexterity should be faster"
	)
	await _fresh_player("warrior", ["windrunner_boots", "quicksilver_locket"])
	_expect(
		(
			player.dexterity == base_dex + 2
			and is_equal_approx(player.speed, SimpleCombat.move_speed(base_dex + 2))
		),
		"Speed items didn't add Dexterity (DEX %d, speed %s)" % [player.dexterity, player.speed]
	)
	_expect(
		is_equal_approx(player.item_runtime.attack_speed_multiplier(), 1.12),
		"Quicksilver attack speed missing"
	)
	state.add_inventory_item("boots_of_the_hare", 1)
	player.item_runtime.refresh()
	_expect(
		player.dexterity == base_dex + 4,
		"Picking up Boots of the Hare mid-run didn't add 2 Dexterity"
	)

	# Emberwind Edge: the third swing throws a fire crescent that burns.
	await _fresh_player("warrior", ["emberwind_edge"])
	var far := _enemy(Vector2(200, 0))
	for swing in 3:
		player.cooldowns.basic = 0.0
		player.use_action("basic")
	var waves := get_nodes_in_group("slasher_item_wave")
	_expect(
		waves.size() == 1, "Every third swing should launch one crescent (got %d)" % waves.size()
	)
	var before := far.health
	for frame in 40:
		await physics_frame
	_expect(far.health < before, "The fire crescent did not hit the distant enemy")
	_expect(
		player.item_procs.burns.has(far.get_instance_id()) or far.dead,
		"The fire crescent did not set the enemy burning"
	)
	var burning_health := far.health
	await create_timer(1.2).timeout
	_expect(far.health < burning_health or far.dead, "Burning did no damage over time")

	# Tempest Brand: a fan of three lightning crescents on the fourth swing.
	await _fresh_player("warrior", ["tempest_brand"])
	for swing in 4:
		player.cooldowns.basic = 0.0
		player.use_action("basic")
	_expect(
		get_nodes_in_group("slasher_item_wave").size() == 3,
		(
			"Tempest Brand should fire three crescents (got %d)"
			% get_nodes_in_group("slasher_item_wave").size()
		)
	)

	# Chain lightning leaps between enemies.
	await _fresh_player("warrior", [])
	var chain := {
		"type": "chain_lightning",
		"on": "hit",
		"chance": 1.0,
		"damage_percent": 100,
		"jumps": 3,
		"jump_range": 200,
		"_key": "test:0"
	}
	var a := _enemy(Vector2(40, 0))
	var b := _enemy(Vector2(140, 0))
	var c := _enemy(Vector2(240, 0))
	var d := _enemy(Vector2(900, 0))
	var health := [b.health, c.health, d.health]
	player.item_procs._fire(chain, 4, a, a.global_position)
	_expect(
		b.health < int(health[0]) and c.health < int(health[1]),
		"Chain lightning did not leap along the line"
	)
	_expect(d.health == int(health[2]), "Chain lightning leapt further than its range")
	_expect(not player.item_procs.bolts.is_empty(), "Chain lightning drew no bolt")

	# Chill slows; nova hits everything in range.
	var chilled := _enemy(Vector2(60, 60))
	player.item_procs.apply_chill(chilled, {"slow": 0.4, "duration": 2.0})
	_expect(
		is_equal_approx(chilled.movement_slow, 0.4) and chilled.status_time >= 2.0,
		"Chill did not slow the enemy"
	)
	var near := _enemy(Vector2(500, 500))
	var out := _enemy(Vector2(700, 500))
	var near_health := near.health
	var out_health := out.health
	player.item_procs._fire(
		{"type": "nova", "damage_percent": 100, "radius": 80, "element": "fire", "_key": "t:1"},
		3,
		null,
		Vector2(500, 500) + player.global_position
	)
	_expect(near.health < near_health and out.health == out_health, "Nova hit the wrong enemies")

	# Kill procs fire when a melee hit kills, but procs never chain into themselves.
	await _fresh_player("warrior", ["bursting_spore_sac"])
	var victim := _enemy(Vector2(40, 0))
	victim.health = 1
	var bystander := _enemy(Vector2(70, 40))
	var bystander_health := bystander.health
	player.aim_direction = Vector2.RIGHT
	player.use_action("basic")
	_expect(victim.dead, "The test victim survived a basic attack")
	_expect(bystander.health < bystander_health, "Bursting Spore Sac did not burst on kill")
	var proc_attack := player.item_procs.proc_attack(1, "fire")
	var lone := _enemy(Vector2(0, 300))
	player.on_item_enemy_hit(lone, proc_attack)
	_expect(player.item_procs.rings.size() <= 1, "A proc attack triggered more procs")

	# Elite bonus damage now applies (Giant-Bane Grip).
	await _fresh_player("warrior", ["giant_bane_grip"])
	var elite := _enemy(Vector2(40, 0))
	elite.elite = true
	var plain_foe := _enemy(Vector2(-40, 0))
	_expect(
		(
			player.item_runtime.flat_bonus(elite, {}) == 2
			and player.item_runtime.flat_bonus(plain_foe, {}) == 1
		),
		"Giant-Bane Grip should add +1 damage, +2 against elites"
	)
	_expect(
		player.item_runtime.flat_bonus(elite, {"item_proc": true}) == 0,
		"Item procs shouldn't get flat item damage"
	)
	_expect(
		(
			int(
				(
					player
					. item_runtime
					. adjust_for_target({"damage": 100}, _enemy(Vector2(0, 200)))
					. damage
				)
			)
			== 100
		),
		"Elite bonus applied to a normal enemy"
	)

	# Periodic relics now tick (Chronomancer's Pin).
	await _fresh_player("mage", ["chronomancers_pin"])
	player.item_runtime._process(0.0)
	player.cooldowns.special = 5.0
	player.item_runtime._process(8.1)
	player.item_runtime._process(0.0)
	_expect(float(player.cooldowns.special) < 5.0, "Chronomancer's Pin never shaved a cooldown")

	# Real hits: +damage items add to the 1-4 hit, block items stop whole hits,
	# Warding Draught soaks exactly one hit, True-Strike adds +1 to the next hit.
	await _fresh_player("warrior", [])
	var dummy := _enemy(Vector2(40, 0))
	dummy.max_health = 100
	dummy.health = 100
	dummy.receive_attack({"damage": player.simple_reference}, player)
	var plain_damage: int = 100 - dummy.health
	await _fresh_player("warrior", ["veterans_whetstone"])
	var dummy2 := _enemy(Vector2(40, 0))
	dummy2.max_health = 100
	dummy2.health = 100
	dummy2.receive_attack({"damage": player.simple_reference}, player)
	_expect(
		100 - dummy2.health == plain_damage + 1,
		(
			"Veteran's Whetstone didn't add +1 to a real hit (%d vs %d)"
			% [100 - dummy2.health, plain_damage]
		)
	)
	player.apply_consumable({"next_attack_accuracy": 8})
	var struck: Dictionary = player.item_runtime.transform_attack(
		{"damage": player.simple_reference}, "basic"
	)
	_expect(
		bool(struck.get("precision_hit", false)),
		"True-Strike Tonic didn't make the next attack a precision hit"
	)
	await _fresh_player("warrior", ["wyvernscale_mantle"])
	player.item_runtime.conversions["block_percent"] = 100.0  # capped at 50%
	player.dodge_chance = 0.0
	var blocked := 0
	for i in 200:
		player.health = 3
		player.invulnerable = 0
		player.receive_damage(5, Vector2.ZERO)
		if player.health == 3:
			blocked += 1
	_expect(
		blocked > 60 and blocked < 140,
		"Block chance should block about half the hits at the 50%% cap (%d of 200)" % blocked
	)
	await _fresh_player("warrior", [])
	player.dodge_chance = 0.0
	player.health = 3
	player.invulnerable = 0
	player.apply_consumable({"temporary_aegis": 1})
	player.receive_damage(5, Vector2.ZERO)
	player.invulnerable = 0
	_expect(player.health == 3, "Warding Draught didn't block the next hit")
	player.receive_damage(5, Vector2.ZERO)
	_expect(player.health == 2, "Warding Draught blocked more than one hit")
	# Chronomancer's Pin is +1 DEX; Wyvernscale Mantle is three heart containers.
	await _fresh_player("warrior", [])
	var plain_dex := player.dexterity
	await _fresh_player("warrior", ["chronomancers_pin"])
	_expect(player.dexterity == plain_dex + 1, "Chronomancer's Pin should add 1 Dexterity")
	await _fresh_player("warrior", [])
	var plain_max := player.max_health
	await _fresh_player("warrior", ["wyvernscale_mantle"])
	_expect(
		(
			player.max_health
			== mini(plain_max + 3 * SimpleCombat.units_per_heart(), SimpleCombat.max_health_units())
		),
		(
			"Wyvernscale Mantle should add 3 heart containers (%d vs %d)"
			% [player.max_health, plain_max]
		)
	)

	# Deft Hands: attacks recover 10% faster.
	await _fresh_player("warrior", ["deft_hands"])
	_expect(
		is_equal_approx(player.item_runtime.attack_speed_multiplier(), 1.10),
		"Deft Hands isn't 10% faster"
	)

	# Blackoak Ward: the first hit in a room is blocked, the next one isn't.
	await _fresh_player("warrior", ["blackoak_ward"])
	player.dodge_chance = 0.0
	player.health = 3
	player.invulnerable = 0
	player.receive_damage(1, Vector2.ZERO)
	_expect(player.health == 3, "Blackoak Ward didn't block the first hit (%d)" % player.health)
	player.invulnerable = 0
	player.receive_damage(1, Vector2.ZERO)
	_expect(
		player.health == 2, "Blackoak Ward blocked more than the first hit (%d)" % player.health
	)

	# Healer's Brooch and Cutpurse's Favor put loot on the floor.
	await _fresh_player("warrior", ["healers_brooch", "cutpurses_favor"])
	var dungeon := FakeDungeon.new()
	root.add_child(dungeon)
	player.reparent(dungeon)
	var brooch := {"type": "drop_potion", "on": "kill", "chance": 1.0, "_key": "brooch:0"}
	player.item_procs._fire(brooch, 1, null, Vector2(10, 10))
	var purse := {
		"type": "drop_gold",
		"on": "hit",
		"chance": 1.0,
		"amount_min": 2,
		"amount_max": 5,
		"_key": "purse:0"
	}
	player.item_procs._fire(purse, 1, null, Vector2(10, 10))
	_expect(dungeon.potions == 1, "Healer's Brooch didn't drop a potion")
	_expect(
		dungeon.gold >= 2 and dungeon.gold <= 5,
		"Cutpurse's Favor didn't drop 2-5 coins (%d)" % dungeon.gold
	)
	var brooch_rule: Dictionary = Array(
		GameBalance.get_slasher_item_effects("healers_brooch").get("procs", [])
	)[0]
	_expect(
		is_equal_approx(float(brooch_rule.chance), 0.05) and String(brooch_rule.on) == "kill",
		"Healer's Brooch should be 5% per kill"
	)
	dungeon.queue_free()

	if failures.is_empty():
		print("ITEM_EFFECTS_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


class FakeDungeon:
	extends Node2D
	var potions := 0
	var gold := 0

	func _spawn_pickup_drop(kind: String, _at: Vector2) -> void:
		if kind == "potion":
			potions += 1

	func _spawn_gold_drop(_at: Vector2, amount: int) -> void:
		gold += amount


func _fresh_player(class_id: String, items: Array) -> void:
	for child in root.get_children():
		if child is FakeDungeon:
			child.free()
			continue
		if (
			child is SlasherPlayer
			or child is SlasherEnemy
			or child.is_in_group("slasher_item_wave")
		):
			child.free()
	state = RunState.new()
	state.set_class(class_id)
	state.start_new_run(null, "forest")
	state.class_resource = state.get_class_resource_max()
	for item_id in items:
		state.add_inventory_item(String(item_id), 1)
	player = SlasherPlayer.new()
	player.setup(state)
	root.add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector2(400, 400)
	await process_frame
	player.item_runtime.refresh()
	player.aim_direction = Vector2.RIGHT


func _enemy(offset: Vector2) -> SlasherEnemy:
	var enemy := SlasherEnemy.new()
	enemy.configure(1)
	enemy.target = player
	root.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.global_position = player.global_position + offset
	enemy.health = 200
	enemy.max_health = 200
	return enemy


func _expect(value: bool, message: String) -> void:
	if not value and not failures.has(message):
		failures.append(message)
