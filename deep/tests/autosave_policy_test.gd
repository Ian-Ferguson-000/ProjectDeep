extends SceneTree

const SCRIPTS_ROOT := "res://scripts"
const MAIN_PATH := "res://scripts/main.gd"
const RUN_STATE_PATH := "res://scripts/game/run_state.gd"
const CAMPAIGN_STATE_PATH := "res://scripts/game/campaign_state.gd"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var script_paths: Array[String] = []
	_collect_gd_scripts(SCRIPTS_ROOT, script_paths)
	for path in script_paths:
		var source := FileAccess.get_file_as_string(path)
		_expect(not source.contains("autosave_campaign"), "%s still uses the retired general autosave API." % path, failures)
		if path == MAIN_PATH:
			_expect(source.count(".autosave_on_floor_entry()") == 7, "Main must save at exactly its seven dungeon-floor entry paths.", failures)
			_expect(not source.contains("save_atomic()"), "Main must not bypass the floor-entry autosave API.", failures)
		elif path == RUN_STATE_PATH:
			_expect(source.count("autosave_on_floor_entry()") == 2, "RunState must contain one floor-entry API and one connected-dungeon call.", failures)
			_expect(source.count(".save_atomic()") == 1, "RunState may persist only through the floor-entry autosave API.", failures)
		elif path == CAMPAIGN_STATE_PATH:
			_expect(source.count("func save_atomic() -> bool:") == 1, "CampaignState must retain one atomic-save implementation.", failures)
			_expect(source.count(".save_atomic()") == 1, "CampaignState may call atomic save only for one-time legacy migration.", failures)
		else:
			_expect(not source.contains("autosave_on_floor_entry()"), "%s introduces a save outside the approved floor-entry paths." % path, failures)
			_expect(not source.contains("save_atomic()"), "%s bypasses the floor-entry autosave policy." % path, failures)
	if failures.is_empty():
		print("AUTOSAVE_POLICY_TESTS_PASSED")
		quit(0)
		return
	for failure in failures: push_error(failure)
	quit(1)

func _collect_gd_scripts(directory_path: String, paths: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null: return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var path := directory_path.path_join(entry)
		if directory.current_is_dir():
			_collect_gd_scripts(path, paths)
		elif entry.ends_with(".gd"):
			paths.append(path)
		entry = directory.get_next()
	directory.list_dir_end()

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition: failures.append(message)
