extends Node

const StartScreenScene := preload("res://scenes/start/StartScreen.tscn")
const ClassSelectionScene := preload("res://scenes/class_selection/ClassSelection.tscn")
const TavernScene := preload("res://scenes/tavern/Tavern.tscn")
const ForestScene := preload("res://scenes/forest/Forest.tscn")
const CryptScene := preload("res://scenes/crypt/Crypt.tscn")

var run_state := RunState.new()
var all_gear_options: Array[GearData] = []
var current_scene: Node

func _ready() -> void:
	_ensure_input_actions()
	_build_gear_options()
	show_start_screen()

func _build_gear_options() -> void:
	all_gear_options = [
		GearData.create(
			"sword_shield",
			"Sword and Shield",
			1,
			true,
			2,
			"charge",
			"Reliable defense. Special: Charge in your facing direction and strike the first enemy.",
			"warrior",
			"block"
		),
		GearData.create(
			"greatsword",
			"Greatsword",
			3,
			false,
			0,
			"sweep",
			"Heavy damage with no shield. Special: Sweep all adjacent enemies.",
			"warrior",
			"none"
		),
		GearData.create(
			"spear_shield",
			"Spear and Shield",
			2,
			true,
			1,
			"brace",
			"Defensive reach. Special: Brace to hit the next enemy that approaches.",
			"warrior",
			"block"
		),
		GearData.create(
			"magic_missile_shield",
			"Magic Missile and Shield",
			3,
			true,
			2,
			"force_blast",
			"Balanced spell book. Special: Force Blast damages a target, pushes it back, and splashes nearby foes.",
			"mage",
			"block"
		),
		GearData.create(
			"fireball_fire_shield",
			"Fireball and Fire Shield",
			5,
			false,
			0,
			"flamethrower",
			"Wide offense. Fire Shield retaliates when hit. Special: Flamethrower burns a line ahead.",
			"mage",
			"retaliate"
		),
		GearData.create(
			"lightning_flash_step",
			"Lightning Bolt and Flash Step",
			3,
			false,
			0,
			"shockwave",
			"Mobile control. Flash Step slips backward when struck. Special: Shockwave stuns adjacent enemies.",
			"mage",
			"flash_step"
		),
		GearData.create("sunwood_staff", "Sunwood Staff", 2, false, 0, "", "Wisdom focus. Your class kit supplies Binding Light, Empower, Recover, and Dash.", "healer", "none"),
		GearData.create("tower_shield", "Tower Shield and Mace", 2, true, 2, "", "Heavy protection for Shield Bash, Retribution, Guard, and Leap.", "tank", "block"),
		GearData.create("spectral_dagger", "Spectral Dagger", 3, false, 0, "", "A precise weapon for Pierce, Assassinate, Evade, and Shadowstep.", "phantom", "none"),
		GearData.create("bond_staff", "Bondkeeper Staff", 2, false, 0, "", "A ritual focus for commanding and protecting your bonded wolf.", "summoner", "none"),
	]

func show_start_screen() -> void:
	_clear_scene()
	var start_screen := StartScreenScene.instantiate()
	current_scene = start_screen
	start_screen.setup(self)
	add_child(start_screen)

func show_class_selection() -> void:
	_clear_scene()
	var class_selection := ClassSelectionScene.instantiate()
	current_scene = class_selection
	class_selection.setup(self)
	add_child(class_selection)

func choose_class(class_id: String) -> void:
	run_state.set_class(class_id)
	var class_type := run_state.selected_class_name
	show_tavern("The hearth is warm. The bartender lays out %s choices for the road ahead." % class_type)

func show_tavern(message: String = "") -> void:
	_clear_scene()
	var tavern := TavernScene.instantiate()
	current_scene = tavern
	tavern.setup(self, run_state, _gear_options_for_class(run_state.selected_class_id), message)
	add_child(tavern)

func start_forest(gear: GearData) -> void:
	run_state.start_new_run(gear, "forest")
	_load_forest_floor()

func start_crypt(gear: GearData) -> void:
	if not run_state.is_crypt_unlocked():
		show_tavern("The crypt door is sealed. Clear the Forest Dungeon and reach level 5.")
		return
	run_state.start_new_run(gear, "crypt")
	_load_crypt_floor()

func _load_forest_floor() -> void:
	_clear_scene()
	var forest := ForestScene.instantiate()
	current_scene = forest
	forest.setup(self, run_state)
	add_child(forest)

func _load_crypt_floor() -> void:
	_clear_scene()
	var crypt := CryptScene.instantiate()
	current_scene = crypt
	crypt.setup(self, run_state)
	add_child(crypt)

func complete_forest_floor() -> void:
	if run_state.advance_floor():
		_load_forest_floor()
	else:
		run_state.mark_forest_cleared()
		return_to_tavern("victory", "You escape the five-floor forest dungeon with %d gold. The bartender smiles like he expected it." % run_state.gold)

func complete_crypt_floor() -> void:
	if run_state.advance_floor():
		_load_crypt_floor()
	else:
		return_to_tavern("victory", "You emerge from the seven-floor Stone Crypt with %d gold. The tavern lanterns seem warmer now." % run_state.gold)

func return_to_tavern(outcome: String, message: String) -> void:
	run_state.finish_run(outcome, message)
	show_tavern(message)

func _gear_options_for_class(class_id: String) -> Array[GearData]:
	var options: Array[GearData] = []
	for gear in all_gear_options:
		if gear.class_id == class_id:
			options.append(gear)
	return options

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
	_add_key_action("character_menu", [KEY_M])

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
