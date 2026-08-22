extends Control

const PLAYER_IDLE_DOWN := preload("res://assets/sprite_packs/Player/IDLE/idle_down.png")
const FIRE_MAGE_SHEET := preload("res://assets/enemies/fire_mage/normalized_sheet.png")

var controller: Node

func setup(game_controller: Node) -> void:
	controller = game_controller

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.055, 0.065, 0.05)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 18)
	root.offset_left = 80
	root.offset_right = -80
	root.offset_top = 58
	root.offset_bottom = -58
	add_child(root)

	var title := Label.new()
	title.text = "Choose Your Class"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.94, 0.83, 0.58))
	root.add_child(title)

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 24)
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(cards)

	cards.add_child(_make_class_card(
		"Fighter",
		"Hold the line with blades, shields, and close-range specials.",
		PLAYER_IDLE_DOWN,
		Rect2(0, 0, 96, 80),
		"fighter"
	))
	cards.add_child(_make_class_card(
		"Mage",
		"Control space with missiles, flame, lightning, shields, and blink magic.",
		FIRE_MAGE_SHEET,
		Rect2(0, 0, 96, 80),
		"mage"
	))

func _make_class_card(class_type: String, description: String, texture: Texture2D, region: Rect2, class_id: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(330, 370)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style())

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(content)

	var portrait := Sprite2D.new()
	portrait.texture = texture
	portrait.region_enabled = true
	portrait.region_rect = region
	portrait.scale = Vector2(1.7, 1.7)
	var portrait_holder := Control.new()
	portrait_holder.custom_minimum_size = Vector2(170, 150)
	portrait_holder.add_child(portrait)
	portrait.position = Vector2(85, 80)
	content.add_child(portrait_holder)

	var name_label := Label.new()
	name_label.text = class_type
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.65))
	content.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.custom_minimum_size = Vector2(260, 78)
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.76))
	content.add_child(desc_label)

	var choose_button := Button.new()
	choose_button.text = "Choose %s" % class_type
	choose_button.custom_minimum_size = Vector2(220, 46)
	choose_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	choose_button.pressed.connect(_choose_class.bind(class_id))
	_style_button(choose_button)
	content.add_child(choose_button)
	return card

func _choose_class(class_id: String) -> void:
	if controller != null and controller.has_method("choose_class"):
		controller.choose_class(class_id)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.14, 0.10)
	style.border_color = Color(0.44, 0.50, 0.34)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 18.0)
	return style

func _style_button(button: Button) -> void:
	FantasyButton.apply_light(button, 17)
