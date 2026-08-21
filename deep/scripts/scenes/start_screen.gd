extends Control

const UI_BUTTON_NORMAL := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/4 Buttons/1.png")
const UI_BUTTON_HOVER := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/4 Buttons/2.png")
const UI_BUTTON_PRESSED := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/4 Buttons/3.png")

var controller: Node

func setup(game_controller: Node) -> void:
	controller = game_controller

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.06, 0.07, 0.05)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 18)
	root.offset_left = 120
	root.offset_right = -120
	root.offset_top = 90
	root.offset_bottom = -90
	add_child(root)

	var title := Label.new()
	title.text = "Eros"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color(0.94, 0.83, 0.58))
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A tactical forest dungeon crawl"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.78, 0.86, 0.72))
	root.add_child(subtitle)

	var start_button := Button.new()
	start_button.text = "Begin"
	start_button.custom_minimum_size = Vector2(260, 54)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.pressed.connect(_begin)
	_style_button(start_button)
	root.add_child(start_button)

func _begin() -> void:
	if controller != null and controller.has_method("show_class_selection"):
		controller.show_class_selection()

func _style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _button_style(UI_BUTTON_NORMAL))
	button.add_theme_stylebox_override("hover", _button_style(UI_BUTTON_HOVER))
	button.add_theme_stylebox_override("pressed", _button_style(UI_BUTTON_PRESSED))
	button.add_theme_stylebox_override("focus", _button_style(UI_BUTTON_HOVER))
	button.add_theme_color_override("font_color", Color(0.20, 0.12, 0.07))
	button.add_theme_color_override("font_hover_color", Color(0.10, 0.07, 0.04))
	button.add_theme_color_override("font_pressed_color", Color(0.08, 0.05, 0.03))
	button.add_theme_font_size_override("font_size", 22)

func _button_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 8.0)
		style.set_content_margin(side, 12.0)
	return style
