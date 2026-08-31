extends Control

const UI_BACKGROUND := preload("res://assets/ui/Eros.png")
const OPTIONS_PANEL:=preload("res://scripts/ui/game_options_panel.gd")

var controller: Node

func setup(game_controller: Node) -> void:
	controller = game_controller

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	var background := TextureRect.new()
	background.texture = UI_BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.018, 0.014, 0.22)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 16)
	root.offset_left = 120
	root.offset_right = -120
	root.offset_top = 310
	root.offset_bottom = -90
	add_child(root)

	var start_button := Button.new()
	start_button.text = "Begin"
	start_button.custom_minimum_size = Vector2(320, 58)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.pressed.connect(_begin)
	_style_button(start_button)
	root.add_child(start_button)

	var options_button:=Button.new()
	options_button.text="Options";options_button.custom_minimum_size=Vector2(320,52);options_button.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;options_button.pressed.connect(_open_options);_style_button(options_button);root.add_child(options_button)

func _begin() -> void:
	if controller != null and controller.has_method("show_class_selection"):
		controller.show_class_selection()

func _open_options()->void:
	var overlay:=Control.new();overlay.name="OptionsOverlay";overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(overlay)
	var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0.01,0.01,0.01,0.82);overlay.add_child(shade)
	var panel:GameOptionsPanel=OPTIONS_PANEL.new();panel.set_anchors_preset(Control.PRESET_CENTER);panel.position=Vector2(-320,-270);panel.setup(true);panel.close_requested.connect(overlay.queue_free);overlay.add_child(panel)

func _style_button(button: Button) -> void:
	FantasyButton.apply_light(button, 22)
