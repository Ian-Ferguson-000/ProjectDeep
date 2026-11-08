extends SceneTree
## Binding of Isaac rules: half hearts (half-heart hits, full-heart hits from
## bosses and champions), soul hearts, room-clear pickups, hearts staying on the
## floor at full health, champions, key-locked treasure rooms, no campfires,
## coins banked at 10 gold, and the HUD's stat line.
const FOREST := preload("res://scenes/slasher/SlasherForest.tscn")
class MemoryCampaign extends CampaignState:
	func save_atomic() -> bool: return true
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _frames(n: int) -> void:
	for i in n: await process_frame

func _run() -> void:
	root.size = Vector2i(1280,720)
	SimpleCombat.dodge_override = 0.0
	var state := RunState.new()
	state.campaign = MemoryCampaign.new()
	state.requested_seed = 2468
	state.start_new_run(GearData.create("isaac","Isaac",3,false,0,"","","warrior"),"forest")
	state.current_floor = 2
	var scene = FOREST.instantiate(); scene._ensure_designer_controls(); scene.run_state = state; root.add_child(scene)
	await _frames(5)
	for node in root.find_children("*","",true,false):
		if node.get_script() and String(node.get_script().resource_path).contains("relic_choice_modal"): node.queue_free()
	paused = false
	var player: SlasherPlayer = scene.player
	expect(player.max_health % 2 == 0 and player.max_health == SimpleCombat.health_for(int(state.get_stats().con)),"Health should be whole hearts counted in halves")
	# Floors: no campfire; the treasure room is locked from floor 2.
	var roles: Array = Array(state.field_run.rooms).map(func(r): return String(r.role))
	expect(not roles.has("rest") and roles.has("treasure") and roles.has("shop") and roles.has("boss"),"Isaac floor rooms wrong: %s" % [roles])
	var treasure: Dictionary = Array(state.field_run.rooms).filter(func(r): return String(r.role) == "treasure")[0]
	expect(bool(treasure.get("locked",false)),"The floor-2 treasure room isn't locked")
	# Hits: half a heart from an ordinary foe, a full heart from a champion or boss.
	for enemy in get_nodes_in_group("slasher_enemy"): enemy.free()
	var foe: SlasherEnemy = scene._spawn_enemy(player.global_position + Vector2(400,0),"feral_wolf","")
	var champion: SlasherEnemy = scene._spawn_enemy(player.global_position + Vector2(-400,0),"feral_wolf","")
	champion.champion = true; champion.elite = true
	await _frames(1)
	player.health = player.max_health; player.invulnerable = 0
	player.receive_damage(9,Vector2.ZERO,foe)
	expect(player.health == player.max_health - 1,"An ordinary hit should take half a heart")
	player.invulnerable = 0
	player.receive_damage(9,Vector2.ZERO,champion)
	expect(player.health == player.max_health - 3,"A champion's hit should take a full heart")
	# Soul hearts take damage first and show on the HUD.
	state.add_soul_hearts(1.0); scene._refresh_hud(); player.invulnerable = 0
	expect(scene.dungeon_hud.soul_count() == 1,"The HUD doesn't show the soul heart")
	player.receive_damage(9,Vector2.ZERO,foe)
	expect(state.soul_health == 1 and player.health == player.max_health - 3,"A soul heart should soak the hit")
	# Champions: double health and a pickup.
	EnemyHelper.check_champion(self,scene)
	await _frames(1)
	# Pickups: hearts stay on the floor at full health.
	scene.loot_nodes.clear()
	player.health = player.max_health
	scene.spawn_isaac_pickup(player.global_position,"heart")
	var heart: Area2D = scene.loot_nodes.back()
	expect(not scene._can_collect(heart),"A red heart was collectable at full health")
	player.health = player.max_health - 3
	expect(scene._can_collect(heart),"A red heart wasn't collectable while hurt")
	var hurt := player.health
	scene._collect_loot(heart)
	expect(player.health == hurt + 2,"A red heart should heal a whole heart")
	scene.spawn_isaac_pickup(player.global_position,"soul_heart")
	var souls := state.soul_health
	scene._collect_loot(scene.loot_nodes.back())
	expect(state.soul_health == souls + 2,"A soul heart pickup should add a soul heart")
	# Room clears: a pickup at least sometimes, and kills give no coins.
	var drops := 0
	for i in 60:
		var before: int = scene.loot_nodes.size()
		scene.roll_room_clear_pickup(player.global_position)
		if scene.loot_nodes.size() > before: drops += 1
	expect(drops > 20 and drops < 55,"Room clears should drop a pickup about 60%% of the time (%d of 60)" % drops)
	var gold_before := state.gold
	scene._on_enemy_defeated(foe,9)
	expect(state.gold == gold_before,"A kill gave coins")
	# The locked treasure room: no key, no entry; a key opens it.
	state.keys = 0
	var path: Array = []
	for direction in scene.room.neighbors: path.append(direction)
	var into := -1
	for record in state.field_run.rooms:
		if String(record.role) == "treasure": into = int(record.id)
	state.update_field_room(into,{"locked":true})
	var direction := ""
	for d in scene.room.neighbors:
		if int(scene.room.neighbors[d]) == into: direction = d
	if direction.is_empty():
		var first: String = scene.room.neighbors.keys()[0]
		scene.room.neighbors[first] = into; direction = first
	scene.transition_cooldown = 0; scene.exit_open = true
	expect(scene.door_nodes.has(direction),"No door to the treasure room to test the lock with")
	if scene.door_nodes.has(direction):
		player.global_position = scene.door_nodes[direction].global_position
		scene._check_doors()
		expect(scene.room_id != into and bool(state.get_field_room(into).get("locked",false)),"A locked room let you in without a key")
		state.keys = 1; scene.transition_cooldown = 0
		scene._check_doors()
		expect(state.keys == 0 and not bool(state.get_field_room(into).get("locked",true)),"A key didn't open the locked room")
	# Coins bank at 10 gold each; the stat line is there.
	expect(RunState.coin_value() == 10,"A coin should bank as 10 gold")
	var stats: Array = player.stat_line()
	expect(stats.map(func(s): return s[0]) == ["Speed","Attack speed","Damage","Range","Luck"],"The stat line is wrong: %s" % [stats])
	scene.queue_free(); await _frames(2)
	if failures.is_empty(): print("ISAAC_RULES_TESTS_PASSED"); quit(0)
	else:
		for f in failures: printerr("FAIL: " + f)
		quit(1)

class EnemyHelper:
	static func check_champion(test, scene) -> void:
		var champ: SlasherEnemy = scene._instantiate_enemy("feral_wolf")
		champ.champion_roll = 0.0
		champ.configure(1,false,"feral_wolf")
		var normal: SlasherEnemy = scene._instantiate_enemy("feral_wolf")
		normal.champion_roll = 0.99
		normal.configure(1,false,"feral_wolf")
		scene.actor_layer.add_child(champ); scene.actor_layer.add_child(normal)
		test.expect(champ.champion and champ.elite and not normal.champion,"Champion roll didn't decide champions")
		test.expect(champ.max_health == normal.max_health * 2,"A champion should have double health (%d vs %d)" % [champ.max_health,normal.max_health])
		var before: int = scene.loot_nodes.size()
		scene._on_enemy_defeated(champ,0)
		test.expect(scene.loot_nodes.size() > before,"A champion didn't drop a pickup")
		normal.queue_free()
