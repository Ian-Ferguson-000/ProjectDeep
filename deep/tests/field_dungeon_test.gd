extends SceneTree

const FIELD_SCENE := preload("res://scenes/field/AshenFarmstead.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var definition := GameBalance.get_dungeon("ashen_farmstead")
	_expect(String(definition.get("dungeon_type", "")) == "field", "Farmstead must use the field runtime", failures)
	_expect(String(GameBalance.get_base_class("mage").get("sprite","")) == "res://assets/classes/mage/sheet.png","Mage must use the supplied normalized class sheet",failures)
	var first := FieldDungeonGenerator.generate(424242, 10, 12)
	var second := FieldDungeonGenerator.generate(424242, 10, 12)
	_expect(first == second, "Field generation must be deterministic", failures)
	var rooms: Array = first.get("rooms", [])
	_expect(rooms.size() >= 10 and rooms.size() <= 12, "Field must contain 10-12 rooms", failures)
	var roles: Dictionary = {}
	var valid_backgrounds := ["crossroads", "farmyard", "barn", "cellar", "storehouse", "harvest_field"]
	for room in rooms:
		roles[String(room.get("role", ""))] = int(roles.get(String(room.get("role", "")), 0)) + 1
		_expect(String(room.get("door_signature", "")).length() == Dictionary(room.get("neighbors", {})).size(), "Door signature must match neighbors", failures)
		var authored := GameBalance.get_field_room_templates(String(room.get("door_signature", "")))
		_expect(not authored.is_empty(), "Every generated signature needs an authored template", failures)
		for template in authored:
			var background_id := String(template.get("background_id", ""))
			_expect(valid_backgrounds.has(background_id), "Field template %s needs a valid background_id" % template.get("id", "unknown"), failures)
			_expect(ResourceLoader.exists("res://assets/field/farmstead/backgrounds/%s.png" % background_id), "Field background %s must exist" % background_id, failures)
	for required in ["start", "boss", "treasure", "shop", "elite"]:
		_expect(int(roles.get(required, 0)) == 1, "Field must have exactly one %s room" % required, failures)
	var state := RunState.new()
	state.mark_forest_cleared()
	_expect(state.is_dungeon_unlocked("ashen_farmstead"), "Forest clear should unlock Farmstead", failures)
	_expect(GameBalance.are_all_dungeons_unlocked_for_testing(), "Dungeon testing unlock switch should be active", failures)
	_expect(state.is_dungeon_unlocked("crypt"), "Testing switch should unlock Crypt without progression", failures)
	state.start_new_run(GearData.create("field_test","Field Test Gear",2,false,0,"","","warrior","none"),"ashen_farmstead")
	state.enter_field_room(1,0); state.update_field_room(1,{"cleared":true,"reward_claimed":true})
	_expect(state.get_field_discovered_count() == 1 and state.get_field_cleared_count() >= 2,"Field discovery and clear counters must persist",failures)
	state.enter_field_room(0,1)
	var scene := FIELD_SCENE.instantiate(); scene.setup(null,state); root.add_child(scene)
	await process_frame
	_expect(scene.field_room_id == 0, "Field scene should begin in room zero", failures)
	_expect(scene.run_state.field_run.get("rooms",[]).size() >= 10, "Field scene lost generated graph", failures)
	var found_background := false
	for tile_node in scene.ground_layer.get_children():
		if tile_node is Sprite2D and String(tile_node.name) == "FarmsteadRoomBackground": found_background = true; break
	_expect(found_background,"Farmstead board must render an illustrated room background",failures)
	_expect(scene.ground_layer.get_node_or_null("DoorwayWallCap_north") != null or scene.ground_layer.get_node_or_null("DoorwayGlow_north") != null,"Farmstead backgrounds need a north doorway overlay",failures)
	var rendered_room: Dictionary = scene.field_room.duplicate(true)
	scene.field_room = {"role":"combat", "background_id":"missing_test_background", "neighbors":{}}
	scene._build_board_tiles()
	var found_fallback_grass := false
	for tile_node in scene.ground_layer.get_children():
		if tile_node is Sprite2D and String(tile_node.name).begins_with("FarmGrass_"): found_fallback_grass = true; break
	_expect(found_fallback_grass,"Missing Farmstead backgrounds must fall back to grass tiles",failures)
	scene.field_room = rendered_room
	scene.field_room = {"role":"elite","door_signature":"NS","cleared":false,"chest_opened":false}
	scene._reset_generated_state(); scene._build_field_floor(); scene._place_field_content()
	_expect(not scene.enemies.is_empty() and scene.enemies[0].has("max_health"),"Farmstead elites must use the canonical enemy health key",failures)
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("FIELD_DUNGEON_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition: failures.append(message)
