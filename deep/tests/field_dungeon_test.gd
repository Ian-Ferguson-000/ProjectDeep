extends SceneTree


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
	_expect(not GameBalance.are_all_dungeons_unlocked_for_testing(), "Normal play must not enable the dungeon testing override", failures)
	_expect(state.is_dungeon_unlocked("crypt"), "Forest clear should unlock Crypt", failures)
	state.campaign.tutorial_phase = CampaignState.TUTORIAL_COMPLETE
	state.campaign.ensure_roster()
	_expect(ResourceLoader.exists("res://scenes/slasher/SlasherFarmstead.tscn"), "Slasher Farmstead scene is missing", failures)

	if failures.is_empty():
		print("FIELD_DUNGEON_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition: failures.append(message)
