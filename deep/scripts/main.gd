extends Node

const TavernScene := preload("res://scenes/tavern/Tavern.tscn")
const ForestScene := preload("res://scenes/forest/Forest.tscn")

var run_state := RunState.new()
var gear_options: Array[GearData] = []
var current_scene: Node

func _ready() -> void:
	_ensure_input_actions()
	_build_gear_options()
	show_tavern("The hearth is warm. The bartender gestures toward three old weapons.")

func _build_gear_options() -> void:
	gear_options = [
		GearData.create(
			"sword_shield",
			"Sword and Shield",
			1,
			true,
			2,
			"charge",
			"Reliable defense. Special: Charge in your facing direction and strike the first enemy."
		),
		GearData.create(
			"greatsword",
			"Greatsword",
			3,
			false,
			0,
			"sweep",
			"Heavy damage with no shield. Special: Sweep all adjacent enemies."
		),
		GearData.create(
			"spear_shield",
			"Spear and Shield",
			2,
			true,
			1,
			"brace",
			"Defensive reach. Special: Brace to hit the next enemy that approaches."
		),
	]

func show_tavern(message: String = "") -> void:
	_clear_scene()
	var tavern := TavernScene.instantiate()
	current_scene = tavern
	tavern.setup(self, run_state, gear_options, message)
	add_child(tavern)

func start_forest(gear: GearData) -> void:
	run_state.start_new_run(gear)
	_clear_scene()
	var forest := ForestScene.instantiate()
	current_scene = forest
	forest.setup(self, run_state)
	add_child(forest)

func return_to_tavern(outcome: String, message: String) -> void:
	run_state.finish_run(outcome, message)
	show_tavern(message)

func _clear_scene() -> void:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null

func _ensure_input_actions() -> void:
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("interact", [KEY_E, KEY_SPACE])
	_add_key_action("special", [KEY_F])
	_add_key_action("drink_potion", [KEY_Q])

func _add_key_action(action: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		if not _action_has_key(action, key):
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _action_has_key(action: StringName, key: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == key:
			return true
	return false
