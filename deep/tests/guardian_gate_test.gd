extends SceneTree

## The gate room: killing the guardian always opens the Root Gate (its pack
## scatters), and the way in is flagged like Isaac's boss door.

const FOREST := preload("res://scenes/slasher/SlasherForest.tscn")
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var state := RunState.new()
	state.start_new_run(GearData.create("gate","Gate",3,false,0,"","","warrior"),"forest")
	state.current_floor = state.get_slasher_cycle_length()
	_expect(state.is_slasher_boss_floor(),"Test should be on a boss floor")
	var scene = FOREST.instantiate(); scene._ensure_designer_controls(); scene.run_state = state; root.add_child(scene)
	for i in 4: await process_frame
	for n in root.find_children("*","",true,false):
		if n.get_script() and String(n.get_script().resource_path).contains("relic_choice_modal"): n.queue_free()
	paused = false
	var rooms: Array = state.field_run.rooms
	var gate_id := -1
	for r in rooms:
		if String(r.role) == "boss": gate_id = int(r.id)
	_expect(gate_id > 0,"No gate room on the floor")
	var next_to_gate := int(Dictionary(rooms[gate_id].neighbors).values()[0])
	var toward_gate := ""
	for direction in Dictionary(rooms[next_to_gate].neighbors):
		if int(rooms[next_to_gate].neighbors[direction]) == gate_id: toward_gate = direction

	# The door into the guardian's room is marked and labelled even while barred.
	state.update_field_room(next_to_gate,{"cleared":false,"role":"combat"})
	state.field_run["current_room"] = next_to_gate; state.field_run["previous_room"] = -1
	scene._build_floor(); await process_frame
	var door: Node2D = scene.door_nodes.get(toward_gate)
	_expect(door != null and door.get_node_or_null("GateMark") != null and bool(door.get_node("GateMark").guarded),"Door to the guardian is not marked")
	var hint: Label = door.get_node("Hint")
	_expect(hint.text == "Guardian" and hint.visible,"Guardian door label missing while barred (%s, %s)" % [hint.text,hint.visible])
	var other_doors: Array = scene.door_nodes.keys().filter(func(d): return d != toward_gate)
	for d in other_doors: _expect(scene.door_nodes[d].get_node_or_null("GateMark") == null,"An ordinary door was marked as the gate")

	# Entering the guardian's room shows the banner.
	state.field_run["current_room"] = gate_id; state.field_run["previous_room"] = next_to_gate; state.field_run["arrival_direction"] = "north"
	scene._build_floor(); await process_frame
	_expect(scene.get_node("HUD").get_node_or_null("GuardianBanner") != null,"No guardian banner on entering the gate room")
	var boss: SlasherEnemy = null
	for node in scene.actor_layer.get_children():
		if node is SlasherEnemy and node.boss: boss = node
	_expect(boss != null,"No guardian spawned")
	if boss == null:
		scene.queue_free(); await process_frame
		for failure in failures: push_error(failure)
		quit(1); return
	# Reinforcements are still alive when the guardian dies.
	scene._spawn_enemy(scene.player.global_position + Vector2(200,0),"wolf_vanguard","wolf_vanguard")
	scene._spawn_enemy(scene.player.global_position + Vector2(-200,0),"wolf_charger","wolf_charger")
	_expect(scene.enemies_remaining >= 3,"Expected the pack plus the guardian")
	boss.health = 1
	if boss is SlasherColossus: boss.heart.open_for(3.0); boss.heart.receive_attack({"damage":5},scene.player)
	else: boss.receive_hit(5)
	await process_frame
	_expect(scene.enemies_remaining == 0 and scene.exit_open,"The guardian's death did not open the gate (foes left %d)" % scene.enemies_remaining)
	_expect(get_nodes_in_group("slasher_enemy").is_empty(),"The guardian's pack did not scatter")
	_expect(bool(state.get_field_room(gate_id).cleared),"Gate room not marked cleared")
	await create_timer(0.6).timeout
	scene.queue_free(); await process_frame
	if failures.is_empty(): print("GUARDIAN_GATE_TESTS_PASSED"); quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(value: bool, message: String) -> void:
	if not value and not failures.has(message): failures.append(message)
