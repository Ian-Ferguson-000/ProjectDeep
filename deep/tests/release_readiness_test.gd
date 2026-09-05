extends SceneTree

const MAIN_SCRIPT := preload("res://scripts/main.gd")
const OPTIONS := preload("res://scripts/ui/game_options_panel.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var main:Node=MAIN_SCRIPT.new()
	main._ensure_input_actions()
	for action in ["move_up","move_down","move_left","move_right","interact","character_menu","cycle_party","slasher_controller_basic","slasher_mobility","slasher_special","slasher_defend","slasher_potion"]:
		_expect(InputMap.has_action(action),"Missing required input action: %s"%action,failures)
	_expect(_has_button("character_menu",JOY_BUTTON_START),"Controller menu must use Start",failures)
	_expect(_has_button("cycle_party",JOY_BUTTON_LEFT_SHOULDER),"Controller party cycling must use LB",failures)
	_expect(_has_key("character_menu",KEY_M),"Strategy/Slasher menu must use M",failures)
	_expect(_has_key("cycle_party",KEY_TAB),"Party cycling must use Tab",failures)
	_expect(_has_button("slasher_potion",JOY_BUTTON_LEFT_STICK),"Controller potion use must use L3",failures)
	_expect(not InputMap.has_action("extract_expedition") and not InputMap.has_action("slasher_abandon"),"Expedition exit actions must not be exposed",failures)
	var panel: GameOptionsPanel = OPTIONS.new()
	root.add_child(panel)
	panel.setup(true)
	await process_frame
	_expect(panel.custom_minimum_size.x*1.5<=1280 and panel.custom_minimum_size.y*1.5<=720,"Options panel must fit the 720p viewport at 150% UI scale",failures)
	_expect(panel._descendants(panel).any(func(node:Node)->bool:return node is ScrollContainer),"Options must scroll at large UI scales",failures)
	var settings := panel._settings()
	for key in ["ui_scale","screen_shake_intensity","master_volume","music_volume","sfx_volume","master_mute","music_mute","sfx_mute"]:
		_expect(settings.DEFAULTS.has(key),"Options omit accessibility/audio setting: %s"%key,failures)
	var labels: Array[String] = []
	for node in panel._descendants(panel):
		if node is Label: labels.append(node.text)
	_expect(" ".join(labels).contains("LB party") and not " ".join(labels).contains("extract"),"Options must teach party controls without an extraction shortcut",failures)
	main.free();panel.queue_free();await process_frame
	if failures.is_empty():print("RELEASE_READINESS_TESTS_PASSED");quit(0);return
	for failure in failures:push_error(failure)
	quit(1)

func _has_button(action:StringName,button:JoyButton)->bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index==button:return true
	return false

func _has_key(action:StringName,key:Key)->bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode==key:return true
	return false

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
