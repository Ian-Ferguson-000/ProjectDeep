extends CanvasLayer
class_name GamePauseMenu

## The in-game menu, opened with Esc (or the controller's Back/Select button)
## in the dungeon and at the tavern: Resume, Codex (dungeon), Options, Controls,
## Return to Title Screen (to switch saves) and Quit Game.
##
## Nothing is lost by leaving: the dungeon saves at every floor and room, and
## the tavern saves through its own helper before leaving.

const THEME := preload("res://scripts/ui/tavern_ui_theme.gd")
const OPTIONS_PANEL := preload("res://scripts/ui/game_options_panel.gd")
const ACTION := "pause_menu"

signal closed

## "dungeon" or "tavern".
var context := "dungeon"
## Returns false only while the scene can't be paused (e.g. mid scene change).
var can_open: Callable = func() -> bool: return true
## Called before returning to the title (the tavern saves here).
var before_leave: Callable = func() -> void: pass
## Opens the codex (dungeon only).
var open_codex: Callable
## Replays the tavern guide (tavern only).
var guide: Callable
## Leaves the run and goes home to the tavern (dungeon only, not the tutorial).
var abandon_run: Callable
var controller: Node
var run_state: RunState

var shade: ColorRect
var frame: PanelContainer
var body: VBoxContainer
var previous_pause := false
var page := "main"

const CONTROLS := [
	["Move","WASD / Arrow keys","D-pad / Left stick"],
	["Attack (hold to keep swinging)","Left click","A"],
	["Defend","Shift + Left click","Y"],
	["Dodge / class movement","Right click","B"],
	["Active item (or class special if none)","Space","X"],
	["Drink potion","Q","L3"],
	["Use packed consumable","1 – 4",""],
	["Interact / talk","E","A"],
	["Codex (stats, items, journal)","M","Start"],
	["This menu","Esc","Back / Select"],
]

static func ensure_action() -> void:
	if not InputMap.has_action(ACTION): InputMap.add_action(ACTION)
	var has_key := false; var has_pad := false
	for event in InputMap.action_get_events(ACTION):
		if event is InputEventKey and event.physical_keycode == KEY_ESCAPE: has_key = true
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_BACK: has_pad = true
	if not has_key:
		var key := InputEventKey.new(); key.physical_keycode = KEY_ESCAPE; InputMap.action_add_event(ACTION,key)
	if not has_pad:
		var pad := InputEventJoypadButton.new(); pad.button_index = JOY_BUTTON_BACK; InputMap.action_add_event(ACTION,pad)

func setup(game_controller: Node, state: RunState, menu_context: String) -> GamePauseMenu:
	controller = game_controller; run_state = state; context = menu_context
	name = "PauseMenu"
	return self

func _ready() -> void:
	ensure_action()
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	shade = ColorRect.new(); shade.name = "Shade"; shade.color = Color(0.03,0.02,0.01,0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var centre := CenterContainer.new(); centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(centre)
	frame = PanelContainer.new(); frame.name = "Frame"
	var style := THEME.panel(Color("1f160f"),Color("8a6430"),10,2); style.set_content_margin_all(26)
	frame.add_theme_stylebox_override("panel",style)
	centre.add_child(frame)
	body = VBoxContainer.new(); body.add_theme_constant_override("separation",10)
	frame.add_child(body)

func is_open() -> bool:
	return visible

func open() -> void:
	if visible: return
	previous_pause = get_tree().paused
	visible = true
	get_tree().paused = true
	AudioCue.play_from(self,"ui_open",false)
	show_page("main")

func close() -> void:
	if not visible: return
	visible = false
	get_tree().paused = previous_pause
	AudioCue.play_from(self,"ui_close",false)
	closed.emit()

## Esc closes whatever window is open first; the menu only opens when nothing
## else is up (can_open). Whether it may open is decided in _input, before any
## window handles the key, so the press that closes a window doesn't also open
## the menu.
var _may_open_on_this_press := false

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(ACTION): return
	if visible:
		# Esc steps back out of a sub-page, then closes.
		if page == "main": close()
		else: show_page("main")
		get_viewport().set_input_as_handled()
		return
	_may_open_on_this_press = can_open.call()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(ACTION) or visible: return
	if _may_open_on_this_press:
		_may_open_on_this_press = false
		open()
		get_viewport().set_input_as_handled()

func show_page(id: String) -> void:
	page = id
	for child in body.get_children():
		body.remove_child(child); child.queue_free()
	match id:
		"options": _options_page()
		"controls": _controls_page()
		"confirm_title": _confirm_page("title")
		"confirm_quit": _confirm_page("quit")
		"confirm_abandon": _abandon_page()
		_: _main_page()

# ---------------------------------------------------------------- pages

func _title(text_value: String, subtitle: String = "") -> void:
	var title := _label(text_value,30,THEME.HIGHLIGHT_GOLD); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(title)
	if not subtitle.is_empty():
		var sub := _label(subtitle,14,THEME.MUTED); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(sub)

func _main_page() -> void:
	_title("Paused",_where())
	if context == "dungeon" and run_state != null: _seed_row()
	body.add_child(_spacer(6))
	var first := _button("Resume",close,true)
	if context == "dungeon" and open_codex.is_valid():
		_button("Codex",func(): close(); open_codex.call())
	if context == "tavern" and guide.is_valid():
		_button("Tavern Guide",func(): close(); guide.call())
	_button("Options",show_page.bind("options"))
	_button("Controls",show_page.bind("controls"))
	body.add_child(_spacer(4))
	if context == "dungeon" and abandon_run.is_valid(): _button("Abandon Run",show_page.bind("confirm_abandon"))
	_button("Return to Title Screen",show_page.bind("confirm_title"))
	if not OS.has_feature("web"): _button("Quit Game",show_page.bind("confirm_quit"))
	first.call_deferred("grab_focus")

## The run's seed, with buttons to copy it or keep it for testing.
func _seed_row() -> void:
	var code := run_state.seed_code()
	var row := HBoxContainer.new(); row.name = "SeedRow"; row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",8)
	body.add_child(row)
	var seed_label := _label("Seed  %s%s" % [code,"  (chosen)" if run_state.run_seeded else ""],15,THEME.IVORY)
	seed_label.name = "SeedLabel"
	row.add_child(seed_label)
	var copy := Button.new(); copy.name = "CopySeed"; copy.text = "Copy"
	THEME.apply_button(copy,false,13,Vector2(64,30))
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(code)
		copy.text = "Copied")
	row.add_child(copy)
	var keep := Button.new(); keep.name = "SaveSeed"
	keep.text = "Saved" if RunSeed.is_saved(code) else "Save"
	keep.disabled = RunSeed.is_saved(code)
	keep.tooltip_text = "Keep this seed in the saved list on the Set Out screen."
	THEME.apply_button(keep,false,13,Vector2(64,30))
	keep.pressed.connect(func():
		if RunSeed.save_seed(code,_where()):
			keep.text = "Saved"; keep.disabled = true)
	row.add_child(keep)

func _abandon_page() -> void:
	_title("Abandon this run?")
	var secured := 0
	if run_state != null and run_state.campaign != null: secured = run_state.campaign.expedition.secured_gold
	var carried := run_state.gold if run_state != null else 0
	var lost := maxi(0,carried - secured)
	var text_value := "Leave the dungeon and head home to the Hearth. Your adventurer returns safely, counted as a retreat.\n\nYou keep the %d gold secured at your last floor checkpoint" % secured
	text_value += (", and leave behind the %d gold picked up since." % lost) if lost > 0 else "."
	var note := _label(text_value,15,THEME.IVORY)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; note.custom_minimum_size = Vector2(440,0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(note)
	body.add_child(_spacer(6))
	var confirm := _button("Abandon Run",func():
		visible = false
		get_tree().paused = false
		abandon_run.call(),true)
	confirm.name = "Confirm"
	_button("Cancel",show_page.bind("main"))
	confirm.call_deferred("grab_focus")

func _where() -> String:
	if context == "tavern": return "The Hearth"
	if run_state == null: return ""
	var dungeon := String(GameBalance.get_dungeon(run_state.active_dungeon_id).get("name",run_state.active_dungeon_id.capitalize()))
	return "%s · Floor %d" % [dungeon,run_state.current_floor]

func _options_page() -> void:
	var options: GameOptionsPanel = OPTIONS_PANEL.new()
	options.custom_minimum_size = Vector2(640,480)
	body.add_child(options)
	options.setup(true)
	options.close_requested.connect(show_page.bind("main"))

func _controls_page() -> void:
	_title("Controls")
	var grid := GridContainer.new(); grid.name = "ControlsGrid"; grid.columns = 3
	grid.add_theme_constant_override("h_separation",28); grid.add_theme_constant_override("v_separation",8)
	body.add_child(grid)
	for heading in ["","KEYBOARD & MOUSE","CONTROLLER"]: grid.add_child(_label(heading,12,THEME.MUTED))
	for row in CONTROLS:
		grid.add_child(_label(String(row[0]),15,THEME.IVORY))
		grid.add_child(_label(String(row[1]),15,THEME.HIGHLIGHT_GOLD))
		grid.add_child(_label(String(row[2]),15,THEME.HIGHLIGHT_GOLD))
	body.add_child(_spacer(6))
	_button("Back",show_page.bind("main"),true).call_deferred("grab_focus")

func _confirm_page(kind: String) -> void:
	_title("Return to the title screen?" if kind == "title" else "Quit the game?")
	var note := _label(_leave_note(),15,THEME.IVORY)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; note.custom_minimum_size = Vector2(440,0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(note)
	body.add_child(_spacer(6))
	var confirm := _button("Return to Title" if kind == "title" else "Quit",return_to_title if kind == "title" else quit_game,true)
	confirm.name = "Confirm"
	_button("Cancel",show_page.bind("main"))
	confirm.call_deferred("grab_focus")

## What leaving keeps, in plain words.
func _leave_note() -> String:
	if context == "tavern": return "The Hearth is saved. You can pick this save, or another one, from the title screen."
	return "Your run is saved at every room. Continuing this save puts you back in the room you're in now, with what you're carrying. If foes are still standing here, the fight starts again."

# ---------------------------------------------------------------- actions

func return_to_title() -> void:
	before_leave.call()
	visible = false
	get_tree().paused = false
	if controller != null and controller.has_method("return_to_title"): controller.return_to_title()

func quit_game() -> void:
	before_leave.call()
	get_tree().quit()

# ---------------------------------------------------------------- widgets

func _button(text_value: String, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.name = text_value.replace(" ","")
	button.text = text_value
	THEME.apply_button(button,primary,17,Vector2(320,46))
	button.pressed.connect(action)
	body.add_child(button)
	return button

func _label(text_value: String, size_value: int, tint: Color) -> Label:
	var label := Label.new(); label.text = text_value
	label.add_theme_font_size_override("font_size",size_value); label.add_theme_color_override("font_color",tint)
	return label

func _spacer(height: float) -> Control:
	var spacer := Control.new(); spacer.custom_minimum_size = Vector2(0,height)
	return spacer
