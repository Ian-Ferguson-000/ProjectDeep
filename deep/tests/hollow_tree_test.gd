extends SceneTree

## Hollow trees: some rooms with breakable trees hide a keyless chest inside one
## tree, drawn a shade darker. It is remembered for the floor.

const FOREST := preload("res://scenes/slasher/SlasherForest.tscn")
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _enter(scene, state: RunState, id: int) -> void:
	state.field_run["current_room"] = id; state.field_run["previous_room"] = -1
	scene._build_floor(); await process_frame

func _run() -> void:
	var state := RunState.new(); state.start_new_run(GearData.create("h","H",3,false,0,"","","warrior"),"forest"); state.current_floor = 2
	var scene = FOREST.instantiate(); scene._ensure_designer_controls(); scene.run_state = state; root.add_child(scene)
	for i in 4: await process_frame
	for n in root.find_children("*","",true,false):
		if n.get_script() and String(n.get_script().resource_path).contains("relic_choice_modal"): n.queue_free()
	paused = false
	var rooms: Array = state.field_run.rooms
	var target := -1
	for r in rooms:
		if String(r.role) == "combat": target = int(r.id); break
	# Roughly 40% of tree rooms hide a chest, decided per floor and room.
	state.update_field_room(target,{"template_id":"old_grove","slasher":{},"cleared":true})
	await _enter(scene,state,target)
	var hits := 0
	var real_id: int = scene.room_id
	for sample in 200:
		scene.room = {"slasher":{}}
		scene.room_id = 1000 + sample
		if scene._hollow_cell().x >= 0: hits += 1
	scene.room_id = real_id
	_expect(hits > 50 and hits < 110,"Hollow trees should turn up in about 40%% of tree rooms (%d of 200)" % hits)

	# Force one and check it looks different and only one tree does.
	state.update_field_room(target,{"template_id":"old_grove","slasher":{},"cleared":true})
	await _enter(scene,state,target)
	var trees: Array = scene.actor_layer.get_children().filter(func(n): return n is SlasherBreakableProp and n.prop_kind == "tree_large")
	var pick: SlasherBreakableProp = trees[3]
	state.update_field_room(target,{"slasher":{"hollow_tree":pick.cell}})
	await _enter(scene,state,target)
	var darker: Array = scene.actor_layer.get_children().filter(func(n): return n is SlasherBreakableProp and n.prop_kind == "tree_large" and n.has_meta("hollow"))
	_expect(darker.size() == 1 and darker[0].modulate.v < 0.8,"Exactly one tree should be the darker hollow one")
	var hollow: SlasherBreakableProp = darker[0]
	var cell := hollow.cell
	# Hits flash the sprite but the tree stays dark.
	hollow.receive_attack({"damage":1})
	await create_timer(0.2).timeout
	_expect(hollow.modulate.v < 0.8,"The hollow tree lost its darker shade after a hit")
	while not hollow.destroyed: hollow.receive_attack({"damage":5})
	await process_frame
	var chest: SlasherBreakableProp = scene.actor_layer.get_node_or_null("HiddenChest")
	_expect(chest != null and chest.cell == cell and bool(chest.get_meta("no_key",false)),"Breaking the hollow tree did not reveal a keyless chest")
	# Leaving and coming back before opening keeps the chest.
	await _enter(scene,state,target)
	chest = scene.actor_layer.get_node_or_null("HiddenChest")
	_expect(chest != null,"The hidden chest vanished after leaving the room")
	# Opening it needs no key and gives a relic choice.
	state.keys = 0
	chest.open_chest()
	await process_frame
	_expect(scene.relic_modal.visible,"The hidden chest did not offer a relic")
	scene.relic_modal.hide()
	await _enter(scene,state,target)
	_expect(scene.actor_layer.get_node_or_null("HiddenChest") == null,"An opened hidden chest came back")
	_expect(not scene.actor_layer.get_children().any(func(n): return n is SlasherBreakableProp and n.cell == cell),"The broken hollow tree grew back")

	# Ordinary trees still drop nothing special.
	var plain: SlasherBreakableProp = scene.actor_layer.get_children().filter(func(n): return n is SlasherBreakableProp and n.prop_kind == "tree_large")[0]
	while not plain.destroyed: plain.receive_attack({"damage":5})
	await process_frame
	_expect(scene.actor_layer.get_children().filter(func(n): return n.name.begins_with("HiddenChest")).is_empty(),"An ordinary tree revealed a chest")

	scene.queue_free(); await process_frame
	if failures.is_empty(): print("HOLLOW_TREE_TESTS_PASSED"); quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(value: bool, message: String) -> void:
	if not value and not failures.has(message): failures.append(message)
