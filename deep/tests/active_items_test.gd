extends SceneTree

## Active items: the slot, charging, treasure-room pedestals, swapping, and what
## each warrior item does.

const FOREST := preload("res://scenes/slasher/SlasherForest.tscn")
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _frames(count: int) -> void:
	for i in count: await process_frame

func _dummy(scene, offset: Vector2) -> SlasherEnemy:
	var foe: SlasherEnemy = scene._spawn_enemy(scene.player.global_position + offset,"bandit_cutthroat","bandit_cutthroat")
	foe.activation_delay = 999.0
	return foe

func _run() -> void:
	# ---- data
	var warrior := ActiveItems.ids_for_class("warrior")
	_expect(warrior.size() >= 5,"Expected at least five warrior active items")
	for id in warrior:
		var record := ActiveItems.item(id)
		_expect(String(record.get("charge","")) in ["rooms","timer"],"%s has no charge type" % id)
		_expect(not String(record.get("name","")).is_empty() and not String(record.get("description","")).is_empty(),"%s lacks a name or description" % id)
		_expect(DungeonHud.item_icon(String(record.get("icon",""))) != null,"%s has no icon" % id)

	# ---- slot rules
	var state := RunState.new()
	state.start_new_run(GearData.create("t","Tester",3,false,0,"","","warrior"),"forest")
	_expect(ActiveItems.held(state).is_empty(),"A new run starts with an active item")
	_expect(ActiveItems.give(state,"whirlwind") == "" and ActiveItems.is_ready(state),"Picking up an item doesn't fill its charge")
	ActiveItems.spend(state)
	_expect(not ActiveItems.is_ready(state),"Spent item is still ready")
	ActiveItems.add_room_charge(state); _expect(not ActiveItems.is_ready(state),"Two-room item ready after one room")
	ActiveItems.add_room_charge(state); _expect(ActiveItems.is_ready(state),"Two-room item not ready after two rooms")
	_expect(ActiveItems.give(state,"shadow_step") == "whirlwind","Swapping didn't hand back the old item")
	ActiveItems.spend(state); ActiveItems.add_room_charge(state,5)
	_expect(not ActiveItems.is_ready(state),"Room clears charged a timer item")
	ActiveItems.tick(state,10.0); _expect(ActiveItems.is_ready(state),"Timer item didn't recharge over time")
	_expect(Dictionary(state.run_stats().get("active_item",{})).get("id","") == "shadow_step","The slot isn't kept in the run's stats")

	# ---- in a run
	state = RunState.new()
	state.start_new_run(GearData.create("t","Tester",3,false,0,"","","warrior"),"forest")
	var scene = FOREST.instantiate(); scene._ensure_designer_controls(); scene.run_state = state; root.add_child(scene)
	await _frames(4)
	for node in root.find_children("*","",true,false):
		if node.get_script() and String(node.get_script().resource_path).contains("relic_choice_modal"): node.queue_free()
	paused = false
	scene.player.invulnerable = 9999.0
	var slot: Control = scene.dungeon_hud.active_slot
	_expect(slot != null and slot.item_id == "" and slot.position.x < 60.0 and slot.position.y > root.get_visible_rect().size.y * 0.7,"The empty active slot isn't in the bottom-left corner")
	_expect(not scene.use_active_item(),"Space with an empty slot did something")
	# First treasure room of the run: an active item on the pedestal.
	var treasure := -1
	for value in state.field_run.rooms:
		if String(value.role) == "treasure": treasure = int(value.id)
	# Walk in through a door, as in play (arriving nowhere drops you on the pedestal).
	var neighbors: Dictionary = Dictionary(state.get_field_room(treasure).get("neighbors",{}))
	var door: String = String(neighbors.keys()[0])
	state.field_run["current_room"] = treasure; state.field_run["previous_room"] = int(neighbors[door]); state.field_run["arrival_direction"] = door
	scene._build_floor(); await _frames(2)
	_expect(is_instance_valid(scene.active_pedestal) and not String(scene.active_pedestal.item_id).is_empty(),"The first treasure room has no active item")
	_expect(scene.treasure_area == null,"The active item room also has a relic chest")
	if is_instance_valid(scene.active_pedestal):
		var offered := String(scene.active_pedestal.item_id)
		scene.player.global_position = scene.active_pedestal.global_position
		scene._pedestal_armed = true
		scene._check_active_pedestal()
		_expect(ActiveItems.held(state) == offered,"Walking onto the pedestal with an empty slot didn't pick it up")
		_expect(String(scene.active_pedestal.item_id).is_empty(),"The pedestal still shows the taken item")
		scene._refresh_active_hud()
		slot = scene.dungeon_hud.active_slot
		_expect(slot.item_id == offered and slot.is_ready(),"The HUD slot doesn't show the new, charged item")
		# Swap: the old item is left behind.
		scene.active_pedestal.item_id = "iron_skin"
		ActiveItems.give(state,"whirlwind")
		_expect(scene.take_active_item() == "whirlwind" and ActiveItems.held(state) == "iron_skin" and scene.active_pedestal.item_id == "whirlwind","Swapping didn't leave the old item on the pedestal")
		_expect(String(Dictionary(scene.room.slasher).get("active_pedestal","")) == "whirlwind","The swapped item isn't remembered by the room")

	# ---- the items
	scene.player.aim_direction = Vector2.RIGHT
	ActiveItems.give(state,"whirlwind")
	var near := _dummy(scene,Vector2(80,0)); var far := _dummy(scene,Vector2(400,0))
	var near_health := near.health; var far_health := far.health
	_expect(scene.use_active_item(),"Whirlwind didn't fire")
	_expect(near.health < near_health and far.health == far_health,"Whirlwind didn't hit only what was close")
	_expect(not ActiveItems.is_ready(state) and not scene.use_active_item(),"Whirlwind could be used again straight away")
	scene._mark_room_cleared(true); scene._mark_room_cleared(true)
	_expect(ActiveItems.is_ready(state),"Clearing two rooms didn't recharge Whirlwind")
	near.queue_free(); far.queue_free(); await _frames(1)

	ActiveItems.give(state,"earthsplitter")
	var ahead := _dummy(scene,Vector2(220,0)); var beside := _dummy(scene,Vector2(0,160))
	var ahead_health := ahead.health; var beside_health := beside.health
	scene.player.aim_direction = Vector2.RIGHT
	scene.use_active_item()
	_expect(ahead.health < ahead_health and beside.health == beside_health,"Earthsplitter didn't hit only along its line")
	ahead.queue_free(); beside.queue_free(); await _frames(1)

	ActiveItems.give(state,"war_horn")
	var plain: int = int(scene.player._attack_data(10,"physical").damage)
	scene.use_active_item()
	_expect(int(scene.player._attack_data(10,"physical").damage) > plain and scene.player.active_buff_time > 0.0,"War Horn didn't strengthen attacks")

	ActiveItems.give(state,"iron_skin")
	scene.use_active_item()
	_expect(scene.player.kit_buffs.ward_amount() >= 8,"Iron Skin gave no ward")

	ActiveItems.give(state,"shadow_step")
	scene.player.invulnerable = 0.0
	var start: Vector2 = scene.player.global_position
	scene.player.velocity = Vector2.LEFT * 200.0
	scene.use_active_item()
	_expect(scene.player.invulnerable > 0.0,"Shadow Step didn't make the hero untouchable")
	await _frames(20)
	_expect(scene.player.global_position.distance_to(start) > 60.0,"Shadow Step didn't move the hero")

	scene.queue_free(); await _frames(3)
	if failures.is_empty(): print("ACTIVE_ITEMS_TESTS_PASSED"); quit(0)
	else:
		for failure in failures: printerr("FAIL: " + failure)
		quit(1)
