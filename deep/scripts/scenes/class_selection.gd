extends Control

const CLASS_IDS := ["warrior", "mage", "healer", "tank", "rogue", "summoner"]
const STAT_IDS := ["str", "dex", "con", "int", "wis", "cha"]

var controller: Node
var class_grid: GridContainer
var detail_text: RichTextLabel
var cards: Array[Button] = []

func setup(game_controller: Node) -> void: controller = game_controller

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.055, 0.065, 0.05)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 36; scroll.offset_right = -36; scroll.offset_top = 24; scroll.offset_bottom = -24
	add_child(scroll)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 14)
	scroll.add_child(root)
	var title := Label.new()
	title.text = "Choose Your Class"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38); title.add_theme_color_override("font_color", Color(0.94, 0.83, 0.58))
	root.add_child(title)
	var browser := HBoxContainer.new()
	browser.size_flags_horizontal = Control.SIZE_EXPAND_FILL; browser.add_theme_constant_override("separation", 18)
	root.add_child(browser)
	class_grid = GridContainer.new()
	class_grid.columns = 3; class_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_grid.add_theme_constant_override("h_separation", 12); class_grid.add_theme_constant_override("v_separation", 12)
	browser.add_child(class_grid)
	var available_ids: Array = CLASS_IDS
	if controller != null and controller.has_method("get_selectable_class_ids"): available_ids = controller.get_selectable_class_ids()
	for class_id in available_ids:
		var card := _make_class_card(class_id, GameBalance.get_base_class(class_id))
		cards.append(card); class_grid.add_child(card)
	var detail_panel := PanelContainer.new()
	detail_panel.name = "ClassDetailPanel"; detail_panel.custom_minimum_size = Vector2(390, 590)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.72, 0.55, 0.27)))
	browser.add_child(detail_panel)
	detail_text = RichTextLabel.new()
	detail_text.name = "ClassDetailText"; detail_text.bbcode_enabled = true; detail_text.fit_content = true
	detail_text.scroll_active = true; detail_text.custom_minimum_size = Vector2(350, 550)
	detail_text.add_theme_font_size_override("normal_font_size", 14)
	detail_panel.add_child(detail_text)
	resized.connect(_update_responsive_layout)
	_show_details("warrior")
	call_deferred("_update_responsive_layout")

func _make_class_card(class_id: String, data: Dictionary) -> Button:
	var card := Button.new()
	card.name = "%sCard" % class_id.capitalize(); card.custom_minimum_size = Vector2(215, 285)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_ALL
	card.tooltip_text = "Select %s" % String(data.get("name", class_id.capitalize()))
	var accent := Color.html(String(data.get("color", "78694f")))
	card.add_theme_stylebox_override("normal", _card_style(accent, false))
	card.add_theme_stylebox_override("hover", _card_style(accent, true))
	card.add_theme_stylebox_override("focus", _card_style(accent.lightened(0.18), true))
	card.add_theme_stylebox_override("pressed", _card_style(accent.lightened(0.10), true))
	card.mouse_entered.connect(_show_details.bind(class_id))
	card.focus_entered.connect(_show_details.bind(class_id))
	card.pressed.connect(_choose_class.bind(class_id))
	var content := VBoxContainer.new(); content.alignment = BoxContainer.ALIGNMENT_CENTER; content.add_theme_constant_override("separation", 4)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	var portrait := TextureRect.new()
	portrait.name = "%sCardArt" % class_id.capitalize()
	var card_asset_id := "phantom" if class_id == "rogue" else class_id
	portrait.texture = load("res://assets/ui/class_cards/%s.png" % card_asset_id)
	portrait.custom_minimum_size = Vector2(185, 185); portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(portrait)
	var label := Label.new(); label.text = String(data.get("name", class_id.capitalize())); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22); label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.65)); label.mouse_filter = Control.MOUSE_FILTER_IGNORE; content.add_child(label)
	var role := Label.new(); role.text = String(data.get("role", "Adventurer")); role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.add_theme_color_override("font_color", Color(0.72, 0.82, 0.70)); role.mouse_filter = Control.MOUSE_FILTER_IGNORE; content.add_child(role)
	var resource := Label.new(); resource.text = "%s · Click to select" % String(data.get("resource", "Power")); resource.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resource.add_theme_font_size_override("font_size", 12); resource.add_theme_color_override("font_color", accent.lightened(0.28)); resource.mouse_filter = Control.MOUSE_FILTER_IGNORE; content.add_child(resource)
	return card

func _show_details(class_id: String) -> void:
	if detail_text == null: return
	var data := GameBalance.get_base_class(class_id)
	var stats: Dictionary = data.get("base_stats", {})
	var stat_parts: Array[String] = []
	for stat_id in STAT_IDS: stat_parts.append("%s %d" % [stat_id.to_upper(), int(stats.get(stat_id, 0))])
	var growth_parts: Array[String] = []
	for rule in data.get("stat_growth", []):
		if rule is Dictionary: growth_parts.append("%s +%d every %d levels" % [String(rule.get("stat", "")).to_upper(), int(rule.get("amount", 1)), int(rule.get("every", 1))])
	var rules: Dictionary = data.get("resource_rules", {})
	var preview := RunState.new(); preview.set_class(class_id)
	var derived_parts: Array[String] = []
	for stat_id in ["max_health", "accuracy", "attack_power", "spell_potency", "armor_class", "evasion", "threshold", "initiative_modifier"]:
		derived_parts.append("%s %d" % [stat_id.replace("_", " ").capitalize(), preview.get_derived_stat(stat_id)])
	var primary: Dictionary = data.get("primary", {})
	var gains: Array[String] = []
	for gain in rules.get("gain", []): gains.append(String(gain))
	var lines: Array[String] = ["[font_size=26][color=#f3d597]%s[/color][/font_size]  [color=#a9cba5]%s[/color]" % [data.get("name", class_id.capitalize()), data.get("role", "")], String(data.get("description", "")), "", "[b]Level 1 Attributes[/b]", "  ".join(stat_parts), "Primary Accuracy: %s · Power: %s" % [" / ".join(primary.get("accuracy", [])).to_upper(), String(primary.get("power", "")).to_upper()], "", "[b]Level 1 Combat Stats[/b]", " · ".join(derived_parts), "", "[b]Growth[/b]", "\n".join(growth_parts), "", "[b]%s 0/%d[/b]" % [data.get("resource", "Power"), int(rules.get("max", 3))], "Gain: %s" % "; ".join(gains), "Special cost: %d" % int(rules.get("special_cost", 2)), ""]
	for slot in ["basic", "special", "defensive", "movement"]:
		var action := GameBalance.get_class_action(class_id, slot)
		lines.append("[b][color=#e4b862]%s · %s[/color][/b]" % [slot.capitalize(), action.get("name", slot.capitalize())])
		lines.append(GameBalance.get_action_tooltip(class_id, slot)); lines.append("")
	detail_text.text = "\n".join(lines)

func _update_responsive_layout() -> void:
	if class_grid == null: return
	class_grid.columns = 3 if size.x >= 1180 else (2 if size.x >= 760 else 1)
	for card in cards: card.custom_minimum_size.x = 215 if class_grid.columns == 3 else 280

func _choose_class(class_id: String) -> void:
	if controller != null and controller.has_method("choose_class"): controller.choose_class(class_id)

func _panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color = Color(0.10, 0.14, 0.10); style.border_color = accent.darkened(0.15)
	style.set_border_width_all(2); style.set_corner_radius_all(6); style.set_content_margin_all(14.0)
	return style

func _card_style(accent: Color, highlighted: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.16, 0.12) if highlighted else Color(0.085, 0.11, 0.08)
	style.border_color = accent.lightened(0.18) if highlighted else accent.darkened(0.22)
	style.set_border_width_all(3 if highlighted else 2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10.0)
	style.shadow_color = Color(accent, 0.22 if highlighted else 0.08)
	style.shadow_size = 8 if highlighted else 3
	return style
