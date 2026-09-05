extends Control
class_name ForestTutorialSequence

signal step_changed(step: int)
signal tutorial_completed

const STEP_COUNT := 9
const STEP_DATA := [
	{"title":"MOVE", "input":"W  A  S  D", "detail":"Move at least a short distance through the clearing."},
	{"title":"BASIC ATTACK", "input":"LEFT MOUSE", "detail":"Swing the Sword and Shield's basic attack."},
	{"title":"DASH", "input":"RIGHT MOUSE", "detail":"Use Mobility to burst in the aimed direction."},
	{"title":"SPECIAL", "input":"SPACE", "detail":"Spend Resolve on your stronger class action."},
	{"title":"DEFEND", "input":"SHIFT + LEFT MOUSE", "detail":"Raise your defensive reaction before the next blow."},
	{"title":"HEALING POTION", "input":"Q", "detail":"Drink the supplied potion."},
	{"title":"CONSUMABLE SLOT", "input":"1", "detail":"Use the supplied item in slot one."},
	{"title":"ROOM REWARD", "input":"COLLECT THE GLOWING CACHE", "detail":"Walk over the reward to claim it."},
	{"title":"CHARACTER & JOURNAL", "input":"M", "detail":"Open the menu to review Alden and the journal."},
]

var current_step := 0
var last_observed_position := Vector2.ZERO
var keyboard_movement_distance := 0.0
var card: PanelContainer
var step_label: Label
var title_label: Label
var input_label: Label
var detail_label: Label
var transitioning := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_card()

func begin(step: int, player_position: Vector2) -> void:
	current_step = clampi(step, 0, STEP_COUNT)
	last_observed_position = player_position
	keyboard_movement_distance = 0.0
	visible = current_step < STEP_COUNT
	transitioning = false
	_refresh()

func observe_movement(player_position: Vector2, keyboard_active: bool) -> void:
	if current_step != 0: return
	if keyboard_active: keyboard_movement_distance += player_position.distance_to(last_observed_position)
	last_observed_position = player_position
	if keyboard_movement_distance >= 32.0: _complete_step()

func observe_ability(result: Dictionary) -> void:
	if not bool(result.get("started", false)): return
	var slot := String(result.get("slot", ""))
	var source := String(result.get("input_source", ""))
	if current_step == 1 and slot == "basic" and source == "mouse": _complete_step()
	elif current_step == 2 and slot == "movement" and source == "mouse": _complete_step()
	elif current_step == 3 and slot == "special" and source == "keyboard": _complete_step()
	elif current_step == 4 and slot == "defensive" and source == "mouse_shift": _complete_step()

func observe_consumable(kind: String, source: String) -> void:
	if source != "keyboard": return
	if current_step == 5 and kind == "potion": _complete_step()
	elif current_step == 6 and kind == "slot": _complete_step()

func observe_reward() -> void:
	if current_step == 7: _complete_step()

func observe_menu_opened(source: String) -> void:
	if current_step == 8 and source == "keyboard": _complete_step()

func _complete_step() -> void:
	if transitioning or current_step >= STEP_COUNT: return
	current_step += 1
	step_changed.emit(current_step)
	if current_step >= STEP_COUNT:
		visible = false
		tutorial_completed.emit()
		return
	transitioning = true
	var tween := create_tween()
	tween.tween_property(card, "modulate:a", 0.0, 0.14)
	tween.tween_callback(func():
		_refresh()
		card.modulate.a = 0.0
	)
	tween.tween_property(card, "modulate:a", 1.0, 0.18)
	tween.tween_callback(func(): transitioning = false)

func _refresh() -> void:
	if current_step >= STEP_COUNT: return
	var data: Dictionary = STEP_DATA[current_step]
	step_label.text = "FOREST TUTORIAL  ·  %d / %d" % [current_step + 1, STEP_COUNT]
	title_label.text = String(data.get("title", ""))
	input_label.text = String(data.get("input", ""))
	detail_label.text = String(data.get("detail", ""))

func _build_card() -> void:
	card = PanelContainer.new()
	card.name = "TutorialControlCard"
	card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	card.position = Vector2(-235, 92)
	card.size = Vector2(470, 150)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0b1712ee")
	style.border_color = Color("73a65f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 10
	card.add_theme_stylebox_override("panel", style)
	add_child(card)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_%s" % side, 12)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)
	step_label = _label(12, Color("9abb8d"))
	title_label = _label(21, Color("f3d579"))
	input_label = _label(24, Color("f5f0db"))
	detail_label = _label(13, Color("c7d5c2"))
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for label in [step_label, title_label, input_label, detail_label]: box.add_child(label)

func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
