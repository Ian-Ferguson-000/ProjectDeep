extends Control

var controller: Node

func setup(game_controller: Node) -> void:
	controller = game_controller

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.055, 0.065, 0.05)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 50
	scroll.offset_right = -50
	scroll.offset_top = 30
	scroll.offset_bottom = -30
	add_child(scroll)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 18)
	scroll.add_child(root)
	var title := Label.new()
	title.text = "Choose Your Class"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.94, 0.83, 0.58))
	root.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	root.add_child(grid)
	for class_id in ["warrior", "mage", "healer", "tank", "phantom", "summoner"]:
		grid.add_child(_make_class_card(class_id, GameBalance.get_base_class(class_id)))

func _make_class_card(class_id: String, data: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(310, 385)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(Color.html(String(data.get("color", "78694f")))))
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 8)
	card.add_child(content)
	var portrait := TextureRect.new()
	var source: Texture2D = load(String(data.get("sprite", "")))
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(0, 0, 96, 80)
	portrait.texture = atlas
	portrait.custom_minimum_size = Vector2(150, 135)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(portrait)
	var name_label := Label.new()
	name_label.text = String(data.get("name", class_id.capitalize()))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 25)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.65))
	content.add_child(name_label)
	var desc := Label.new()
	desc.text = String(data.get("description", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.custom_minimum_size = Vector2(270, 48)
	desc.add_theme_font_size_override("font_size", 14)
	content.add_child(desc)
	var actions: Dictionary = data.get("actions", {})
	var kit := Label.new()
	kit.text = "%s 0/3\n%s  •  %s  •  %s  •  %s" % [String(data.get("resource", "Power")), _action_name(actions, "basic"), _action_name(actions, "special"), _action_name(actions, "defensive"), _action_name(actions, "movement")]
	kit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kit.add_theme_font_size_override("font_size", 13)
	kit.add_theme_color_override("font_color", Color(0.82, 0.88, 0.76))
	content.add_child(kit)
	var button := Button.new()
	button.text = "Choose %s" % String(data.get("name", class_id.capitalize()))
	button.custom_minimum_size = Vector2(220, 42)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_choose_class.bind(class_id))
	FantasyButton.apply_light(button, 16)
	content.add_child(button)
	return card

func _action_name(actions: Dictionary, slot: String) -> String:
	var value: Variant = actions.get(slot, {})
	return String(value.get("name", slot.capitalize())) if value is Dictionary else slot.capitalize()

func _choose_class(class_id: String) -> void:
	if controller != null and controller.has_method("choose_class"):
		controller.choose_class(class_id)

func _panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.14, 0.10)
	style.border_color = accent.darkened(0.15)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16.0)
	return style
