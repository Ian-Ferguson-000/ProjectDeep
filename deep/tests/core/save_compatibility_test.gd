extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var source := CampaignState.new()
	source.ensure_roster()
	source.first_company_recruited = true
	var party := source.default_party("forest")
	for id in party:
		source.character(id).status = CharacterRecord.STATUS_EXPEDITION
	var save_data := source.to_dict()
	var expedition: Dictionary = save_data.get("expedition", {}).duplicate(true)
	expedition.merge(
		{
			"active": true,
			"expedition_id": 12,
			"dungeon_id": "forest",
			"play_mode": "strategy",
			"party_ids": party,
			"floor": 3,
			"deployment_type": "manual",
			"due_day": 8
		},
		true
	)
	save_data["expedition"] = expedition
	save_data["completed_dungeon_modes"] = {"forest": ["strategy"]}
	var migrated := CampaignState._migrate_dict(save_data)
	_expect(
		bool(migrated.get("completed_dungeons", {}).get("forest", false)),
		"Prior Forest clear was not preserved",
		failures
	)
	var loaded := CampaignState.new()
	loaded._load_dict(migrated)
	_expect(
		CampaignState._settle_removed_mode_run(loaded, migrated),
		"Removed-runtime expedition was not settled",
		failures
	)
	_expect(
		not loaded.expedition.active and loaded.settled_expeditions.has("12"),
		"Defeat settlement did not close and record the expedition",
		failures
	)
	_expect(
		loaded.memorial.size() == party.size(),
		"Defeated expedition members were not recorded in the memorial",
		failures
	)
	_expect(
		(
			loaded.unlocked_classes.has("warrior")
			and loaded.unlocked_classes.has("mage")
			and loaded.unlocked_classes.size() == 2
		),
		"Loaded save did not keep exactly the Fighter and Mage unlocks",
		failures
	)
	# Old saves with shelved classes: unlocks dropped, members retrained.
	var shelved := CampaignState.new()
	shelved.apply_post_tutorial_state("victory")
	for candidate in shelved.get_candidates():
		shelved.recruit_candidate(candidate.id)
	var shelved_data := shelved.to_dict()
	shelved_data["unlocked_classes"] = ["warrior", "mage", "tank", "phantom", "healer"]
	var shelved_roster: Array = shelved_data.get("roster", [])
	_expect(shelved_roster.size() >= 2, "Shelved-class fixture needs two members", failures)
	if shelved_roster.size() >= 2:
		shelved_roster[0]["class_id"] = "tank"
		shelved_roster[1]["class_id"] = "summoner"
	var shelved_loaded := CampaignState.new()
	shelved_loaded._load_dict(CampaignState._migrate_dict(shelved_data))
	_expect(
		shelved_loaded.unlocked_classes.all(func(id): return GameBalance.is_playable_class(id)),
		"Shelved class unlocks survived loading an old save",
		failures
	)
	var classes_now: Array = shelved_loaded.roster.values().map(func(m): return m.class_id)
	_expect(
		(
			classes_now.has("warrior")
			and classes_now.has("mage")
			and classes_now.all(func(id): return GameBalance.is_playable_class(id))
		),
		"Shelved-class members were not retrained to Fighter/Mage: %s" % [classes_now],
		failures
	)
	var memorial_count := loaded.memorial.size()
	_expect(
		not CampaignState._settle_removed_mode_run(loaded, migrated),
		"Legacy expedition settled more than once",
		failures
	)
	var reloaded := CampaignState.new()
	reloaded._load_dict(CampaignState._migrate_dict(loaded.to_dict()))
	_expect(
		(
			not reloaded.expedition.active
			and reloaded.memorial.size() == memorial_count
			and reloaded.settled_expeditions.has("12")
		),
		"Saved defeat did not survive reload",
		failures
	)
	if failures.is_empty():
		print("SAVE_COMPATIBILITY_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
