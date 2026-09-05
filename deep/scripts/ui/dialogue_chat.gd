extends Control
class_name DialogueChat

signal line_changed(index: int, line: Dictionary)
signal conversation_finished

var lines: Array[Dictionary] = []
var line_index := -1
var previous_tree_paused := false
var panel: PanelContainer
var left_portrait: TextureRect
var right_portrait: TextureRect
var speaker_label: Label
var dialogue_label: Label
var continue_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()

func play(dialogue_lines: Array) -> void:
	lines.clear()
	for value in dialogue_lines:
		if value is Dictionary: lines.append(Dictionary(value).duplicate(true))
	if lines.is_empty():
		conversation_finished.emit()
		return
	previous_tree_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	move_to_front()
	line_index = -1
	_cache_portraits()
	_advance()

func is_playing() -> bool:
	return visible and line_index >= 0 and line_index < lines.size()

func _input(event: InputEvent) -> void:
	if not is_playing(): return
	var advance := false
	if event is InputEventMouseButton:
		advance = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	elif event is InputEventKey and event.pressed and not event.echo:
		advance = event.physical_keycode in [KEY_E, KEY_SPACE, KEY_ENTER]
	if advance:
		get_viewport().set_input_as_handled()
		_advance()

func _advance() -> void:
	line_index += 1
	if line_index >= lines.size():
		_finish()
		return
	var line := lines[line_index]
	speaker_label.text = String(line.get("speaker", ""))
	dialogue_label.text = String(line.get("text", ""))
	var side := String(line.get("side", "left"))
	left_portrait.modulate = Color.WHITE if side == "left" else Color(0.48, 0.48, 0.48, 0.72)
	right_portrait.modulate = Color.WHITE if side == "right" else Color(0.48, 0.48, 0.48, 0.72)
	continue_label.text = "CLICK · E · SPACE    %d / %d" % [line_index + 1, lines.size()]
	line_changed.emit(line_index, line)

func _finish() -> void:
	visible = false
	line_index = -1
	get_tree().paused = previous_tree_paused
	conversation_finished.emit()

func _cache_portraits() -> void:
	left_portrait.texture = null
	right_portrait.texture = null
	for line in lines:
		var path := String(line.get("portrait", ""))
		if path.is_empty() or not ResourceLoader.exists(path): continue
		var target := right_portrait if String(line.get("side", "left")) == "right" else left_portrait
		if target.texture == null: target.texture = load(path)

func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.01, 0.015, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	panel = PanelContainer.new()
	panel.name = "DialogueChatPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 28
	panel.offset_right = -28
	panel.offset_top = -224
	panel.offset_bottom = -18
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_%s" % side, 14)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	left_portrait = _portrait("LeftPortrait")
	row.add_child(left_portrait)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 7)
	row.add_child(copy)
	speaker_label = Label.new()
	speaker_label.name = "SpeakerLabel"
	speaker_label.add_theme_font_size_override("font_size", 22)
	speaker_label.add_theme_color_override("font_color", Color("f2c96d"))
	copy.add_child(speaker_label)
	dialogue_label = Label.new()
	dialogue_label.name = "DialogueLabel"
	dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.add_theme_font_size_override("font_size", 18)
	dialogue_label.add_theme_color_override("font_color", Color("f4ead2"))
	copy.add_child(dialogue_label)
	continue_label = Label.new()
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	continue_label.add_theme_font_size_override("font_size", 12)
	continue_label.add_theme_color_override("font_color", Color("a9c792"))
	copy.add_child(continue_label)
	right_portrait = _portrait("RightPortrait")
	row.add_child(right_portrait)

func _portrait(node_name: String) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.name = node_name
	portrait.custom_minimum_size = Vector2(142, 174)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return portrait

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("120d08f2")
	style.border_color = Color("b98335")
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.62)
	style.shadow_size = 12
	return style
