extends Control

const UI_BACKGROUND := preload("res://assets/ui/Eros.png")

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

func _begin() -> void:
	if controller != null and controller.has_method("show_class_selection"):
		controller.show_class_selection()

func _style_button(button: Button) -> void:
	FantasyButton.apply_light(button, 22)
