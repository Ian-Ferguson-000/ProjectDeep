extends PanelContainer
class_name PlayerCharacterMenu

# Art handoff: all menu chrome lives in assets/ui/character_menu/.
# Artists can replace those PNGs at the same paths to reskin the character
# sheet without changing progression, combat, or inventory logic.

const MENU_FRAME := preload("res://assets/ui/character_menu/menu_frame.png")
const SECTION_PANEL := preload("res://assets/ui/character_menu/section_panel.png")
const PORTRAIT_FRAME := preload("res://assets/ui/character_menu/portrait_frame.png")
const RELIC_SLOT_EMPTY := preload("res://assets/ui/character_menu/relic_slot_empty.png")
const RELIC_SLOT_SELECTED := preload("res://assets/ui/character_menu/relic_slot_selected.png")
const SIDE_PANEL := preload("res://assets/ui/character_menu/side_panel.png")
const TIP_PANEL := preload("res://assets/ui/character_menu/tip_panel.png")
const CLOSE_BUTTON := preload("res://assets/ui/character_menu/close_button.png")

const ICON_ATTACK := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/2 Icons/2.png")
const ICON_SPECIAL := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/2 Icons/10.png")
const ICON_DEFEND := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/2 Icons/12.png")
const ICON_MOVE := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/2 Icons/1.png")
const ICON_MODE := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/2 Icons/7.png")
const ICON_INIT := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/2 Icons/26.png")
const ICON_GOLD := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/1 Items/1.png")
const ICON_KEY := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/1 Items/10.png")
const ICON_POTION := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/1 Items/15.png")
const ICON_HEALTH := preload("res://assets/pixel_art/potion.png")
const ICON_SPELL := preload("res://assets/pixel_art/spellnode.png")

var close_callback: Callable

func setup(callback: Callable) -> void:
	close_callback = callback
	name = "CharacterMenu"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -500
	offset_top = -315
	offset_right = 500
	offset_bottom = 315
	custom_minimum_size = Vector2(940, 580)
	add_theme_stylebox_override("panel", _texture_style(MENU_FRAME, 44.0, 24.0))

func sync(run_state: RunState, portrait: Texture2D, gear_name: String, derived_stats: Dictionary, relic_entries: Array[Dictionary]) -> void:
	_clear_children_now(self)
	if run_state == null:
		return

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)

	body.add_child(_make_header(run_state, portrait, gear_name))

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	body.add_child(content)

	var main_column := VBoxContainer.new()
	main_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_column.add_theme_constant_override("separation", 10)
	content.add_child(main_column)

	main_column.add_child(_make_stats_section(run_state, derived_stats))
	main_column.add_child(_make_relics_section(relic_entries))
	main_column.add_child(_make_tip_panel())

	var side_column := VBoxContainer.new()
	side_column.custom_minimum_size = Vector2(245, 0)
	side_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_column.add_theme_constant_override("separation", 10)
	content.add_child(side_column)

	side_column.add_child(_make_class_panel(run_state))
	side_column.add_child(_make_resistance_panel())
	side_column.add_child(_make_info_panel(run_state))
	side_column.add_child(_make_actions_panel())

func _make_header(run_state: RunState, portrait: Texture2D, gear_name: String) -> PanelContainer:
	var panel := _make_texture_panel(SECTION_PANEL, Vector2(0, 120), 42.0, 14.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var portrait_panel := _make_fixed_texture_panel(PORTRAIT_FRAME, Vector2(98, 98))
	row.add_child(portrait_panel)

	var portrait_center := CenterContainer.new()
	portrait_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_panel.add_child(portrait_center)

	var portrait_image := TextureRect.new()
	portrait_image.texture = portrait
	portrait_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_image.custom_minimum_size = Vector2(78, 78)
	portrait_center.add_child(portrait_image)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 5)
	row.add_child(details)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	details.add_child(title_row)
	title_row.add_child(_make_label(run_state.selected_class_name, 30, Color(1.0, 0.87, 0.57), HORIZONTAL_ALIGNMENT_LEFT))
	title_row.add_child(_make_label("Level %d" % run_state.get_level(), 15, Color(0.95, 0.78, 0.44), HORIZONTAL_ALIGNMENT_LEFT))
	title_row.add_child(_make_label(_xp_header_text(run_state), 15, Color(0.95, 0.78, 0.44), HORIZONTAL_ALIGNMENT_LEFT))

	var xp_bar := ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 12)
	xp_bar.show_percentage = false
	xp_bar.max_value = float(_xp_next_value(run_state))
	xp_bar.value = float(_xp_current_value(run_state))
	xp_bar.add_theme_stylebox_override("background", _flat_style(Color(0.08, 0.055, 0.035, 0.96), 3, Color(0.35, 0.23, 0.11)))
	xp_bar.add_theme_stylebox_override("fill", _flat_style(Color(0.72, 0.46, 0.17, 0.96), 3, Color(1.0, 0.78, 0.36)))
	details.add_child(xp_bar)

	var resource_row := HBoxContainer.new()
	resource_row.add_theme_constant_override("separation", 16)
	details.add_child(resource_row)
	resource_row.add_child(_make_icon_text(ICON_HEALTH, "HP %d/%d" % [run_state.current_health, run_state.max_health]))
	resource_row.add_child(_make_icon_text(ICON_GOLD, "Gold %d" % run_state.gold))
	resource_row.add_child(_make_icon_text(ICON_KEY, "Keys %d" % run_state.keys))
	resource_row.add_child(_make_icon_text(ICON_POTION, "Potions %d" % run_state.potions))

	var gear_label := _make_label("Gear: %s" % gear_name, 15, Color(0.58, 0.87, 0.95), HORIZONTAL_ALIGNMENT_LEFT)
	details.add_child(gear_label)

	var close_button := Button.new()
	close_button.text = "M  Close"
	close_button.custom_minimum_size = Vector2(122, 46)
	close_button.icon = CLOSE_BUTTON
	close_button.expand_icon = true
	close_button.pressed.connect(_request_close)
	close_button.tooltip_text = "Close character menu"
	_style_close_button(close_button)
	row.add_child(close_button)
	return panel

func _make_stats_section(run_state: RunState, derived_stats: Dictionary) -> PanelContainer:
	var panel := _make_texture_panel(SECTION_PANEL, Vector2(0, 242), 42.0, 14.0)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	body.add_child(_make_section_title("ATTRIBUTES"))

	var stats_grid := GridContainer.new()
	stats_grid.columns = 3
	stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_grid.add_theme_constant_override("h_separation", 8)
	stats_grid.add_theme_constant_override("v_separation", 7)
	body.add_child(stats_grid)

	var stats: Dictionary = run_state.get_stats()
	stats_grid.add_child(_make_stat_tile(ICON_ATTACK, "STR %d" % int(stats.get("str", 0)), "Strength"))
	stats_grid.add_child(_make_stat_tile(ICON_MOVE, "DEX %d" % int(stats.get("dex", 0)), "Dexterity"))
	stats_grid.add_child(_make_stat_tile(ICON_DEFEND, "CON %d" % int(stats.get("con", 0)), "Constitution"))
	stats_grid.add_child(_make_stat_tile(ICON_SPELL, "INT %d" % int(stats.get("int", 0)), "Intelligence"))
	stats_grid.add_child(_make_stat_tile(ICON_MODE, "WIS %d" % int(stats.get("wis", 0)), "Wisdom"))
	stats_grid.add_child(_make_stat_tile(ICON_SPECIAL, "CHA %d" % int(stats.get("cha", 0)), "Charisma"))

	var damage_bonus: int = int(derived_stats.get("spell_power", 0)) if run_state.selected_class_id == "mage" else int(derived_stats.get("attack_bonus", 0))
	var damage_label: String = "Spell Power" if run_state.selected_class_id == "mage" else "Attack Bonus"
	stats_grid.add_child(_make_stat_tile(ICON_ATTACK, "Damage +%d" % damage_bonus, damage_label))
	stats_grid.add_child(_make_stat_tile(ICON_DEFEND, "Defense +%d" % int(derived_stats.get("defense", 0)), "Defense"))
	stats_grid.add_child(_make_stat_tile(ICON_INIT, "Init +%d" % int(derived_stats.get("initiative_modifier", 0)), "Initiative"))
	stats_grid.add_child(_make_stat_tile(ICON_POTION, "Potion +%d" % int(derived_stats.get("potion_heal_bonus", 0)), "Potion Effect"))
	stats_grid.add_child(_make_stat_tile(ICON_MOVE, "Move +%d" % int(derived_stats.get("movement", 0)), "Movement"))
	stats_grid.add_child(_make_stat_tile(ICON_DEFEND, "Block +%d" % int(derived_stats.get("block_bonus", 0)), "Block Chance"))
	return panel

func _make_relics_section(relic_entries: Array[Dictionary]) -> PanelContainer:
	var panel := _make_texture_panel(SECTION_PANEL, Vector2(0, 126), 42.0, 14.0)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	body.add_child(_make_section_title("RELICS"))

	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 11)
	body.add_child(slots)
	for i in range(8):
		var entry: Dictionary = relic_entries[i] if i < relic_entries.size() else {}
		slots.add_child(_make_relic_slot(entry))

	var note := _make_label("Relics grant powerful bonuses. Collect and equip them to grow stronger.", 12, Color(0.75, 0.60, 0.36), HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(note)
	return panel

func _make_tip_panel() -> PanelContainer:
	var panel := _make_texture_panel(TIP_PANEL, Vector2(0, 50), 28.0, 9.0)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = ICON_MODE
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	row.add_child(_make_label("Tip: Increase your stats by finding relics and leveling up.", 13, Color(0.88, 0.70, 0.42), HORIZONTAL_ALIGNMENT_LEFT))
	return panel

func _make_class_panel(run_state: RunState) -> PanelContainer:
	var panel := _make_side_panel("CLASS", 140)
	var body: VBoxContainer = panel.get_child(0) as VBoxContainer
	var class_line: String = "Master of elemental flames and arcane knowledge." if run_state.selected_class_id == "mage" else "Front-line survivor with strong arms and stronger resolve."
	body.add_child(_make_label(run_state.selected_class_name, 18, Color(1.0, 0.86, 0.58), HORIZONTAL_ALIGNMENT_CENTER))
	body.add_child(_make_wrapped_label(class_line, 13, Color(0.84, 0.70, 0.45)))
	body.add_child(_make_wrapped_label(run_state.get_progression_summary(), 10, Color(0.58, 0.87, 0.95)))
	body.add_child(_make_label("Starting Kit", 13, Color(0.91, 0.60, 0.26), HORIZONTAL_ALIGNMENT_CENTER))
	var starter_text: String = "Fireball\nFlame Shield" if run_state.selected_class_id == "mage" else "Sword\nShield Brace"
	body.add_child(_make_wrapped_label(starter_text, 12, Color(0.86, 0.78, 0.64)))
	return panel

func _make_resistance_panel() -> PanelContainer:
	var panel := _make_side_panel("RESISTANCES", 108)
	var body: VBoxContainer = panel.get_child(0) as VBoxContainer
	body.add_child(_make_resistance_row("Fire", "0%"))
	body.add_child(_make_resistance_row("Frost", "0%"))
	body.add_child(_make_resistance_row("Arcane", "0%"))
	return panel

func _make_info_panel(run_state: RunState) -> PanelContainer:
	var panel := _make_side_panel("INFO", 105)
	var body: VBoxContainer = panel.get_child(0) as VBoxContainer
	var next_level_text: String = "Max"
	if run_state.get_xp_to_next_level() > 0:
		next_level_text = "%d XP" % run_state.get_xp_to_next_level()
	body.add_child(_make_info_row("Level", str(run_state.get_level())))
	body.add_child(_make_info_row("XP", _xp_header_text(run_state)))
	body.add_child(_make_info_row("Next Level", next_level_text))
	return panel

func _make_actions_panel() -> PanelContainer:
	var panel := _make_texture_panel(TIP_PANEL, Vector2(0, 52), 28.0, 7.0)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	var button := Button.new()
	button.text = "Actions   A"
	button.disabled = true
	button.custom_minimum_size = Vector2(170, 38)
	_style_close_button(button)
	row.add_child(button)
	return panel

func _make_side_panel(title: String, height: int) -> PanelContainer:
	var panel := _make_texture_panel(SIDE_PANEL, Vector2(0, height), 42.0, 14.0)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	panel.add_child(body)
	body.add_child(_make_section_title(title))
	return panel

func _make_stat_tile(icon: Texture2D, title: String, subtitle: String) -> PanelContainer:
	# Visual handoff: stat rows intentionally use a flat style so future artists
	# can replace only the section frame without fighting nested textures.
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(190, 48)
	tile.add_theme_stylebox_override("panel", _flat_panel_style(
		Color(0.07, 0.055, 0.04, 0.76),
		5,
		Color(0.43, 0.29, 0.12, 0.86),
		1,
		6
	))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	tile.add_child(row)
	var image := TextureRect.new()
	image.texture = icon
	image.custom_minimum_size = Vector2(30, 30)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(image)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(_make_label(title, 16, Color(1.0, 0.91, 0.72), HORIZONTAL_ALIGNMENT_LEFT))
	text.add_child(_make_label(subtitle, 11, Color(0.82, 0.62, 0.36), HORIZONTAL_ALIGNMENT_LEFT))
	return tile

func _make_relic_slot(entry: Dictionary) -> PanelContainer:
	var occupied: bool = not entry.is_empty()
	var texture: Texture2D = RELIC_SLOT_SELECTED if occupied else RELIC_SLOT_EMPTY
	var slot := _make_fixed_texture_panel(texture, Vector2(62, 62))
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(center)
	if not occupied:
		var plus := _make_label("+", 30, Color(0.47, 0.34, 0.17), HORIZONTAL_ALIGNMENT_CENTER)
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(plus)
		slot.tooltip_text = "Empty relic slot\nClaim relics from chests and dungeon rewards."
		return slot

	var item: Dictionary = GameBalance.get_item(String(entry.get("id", "")))
	var rarity: String = String(item.get("rarity", "common"))
	slot.add_theme_stylebox_override("panel", _flat_panel_style(
		_rarity_color(rarity).darkened(0.72),
		31,
		_rarity_color(rarity).lightened(0.05),
		1,
		2
	))
	var icon := TextureRect.new()
	icon.texture = _item_icon_texture(String(item.get("icon_key", "special")))
	icon.custom_minimum_size = Vector2(38, 38)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(icon)
	slot.tooltip_text = _relic_tooltip_text(entry, item, rarity)
	return slot

func _make_icon_text(icon: Texture2D, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var image := TextureRect.new()
	image.texture = icon
	image.custom_minimum_size = Vector2(21, 21)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(image)
	row.add_child(_make_label(text, 15, Color(0.94, 0.83, 0.60), HORIZONTAL_ALIGNMENT_LEFT))
	return row

func _make_resistance_row(label_text: String, value_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_make_label(label_text, 13, Color(0.88, 0.78, 0.62), HORIZONTAL_ALIGNMENT_LEFT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_make_label(value_text, 13, Color(0.94, 0.86, 0.68), HORIZONTAL_ALIGNMENT_RIGHT))
	return row

func _make_info_row(label_text: String, value_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_make_label(label_text, 12, Color(0.82, 0.63, 0.36), HORIZONTAL_ALIGNMENT_LEFT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_make_label(value_text, 12, Color(0.94, 0.86, 0.68), HORIZONTAL_ALIGNMENT_RIGHT))
	return row

func _make_section_title(text: String) -> Label:
	var label := _make_label(text, 16, Color(0.92, 0.62, 0.28), HORIZONTAL_ALIGNMENT_CENTER)
	label.add_theme_color_override("font_shadow_color", Color(0.06, 0.03, 0.01, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _make_label(text: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.clip_text = true
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _make_wrapped_label(text: String, font_size: int, color: Color) -> Label:
	var label := _make_label(text, font_size, color, HORIZONTAL_ALIGNMENT_CENTER)
	label.clip_text = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _request_close() -> void:
	if close_callback.is_valid():
		close_callback.call()
	else:
		visible = false

func _xp_current_value(run_state: RunState) -> int:
	var profile: Dictionary = _active_profile(run_state)
	return int(profile.get("xp", 0))

func _xp_next_value(run_state: RunState) -> int:
	if run_state.get_level() >= RunState.MAX_HERO_LEVEL:
		return maxi(1, _xp_current_value(run_state))
	return _xp_current_value(run_state) + run_state.get_xp_to_next_level()

func _xp_header_text(run_state: RunState) -> String:
	if run_state.get_level() >= RunState.MAX_HERO_LEVEL:
		return "XP Max"
	return "XP %d / %d" % [_xp_current_value(run_state), _xp_next_value(run_state)]

func _active_profile(run_state: RunState) -> Dictionary:
	var profile_value: Variant = run_state.hero_profiles.get(run_state.selected_class_id, {})
	if profile_value is Dictionary:
		return profile_value
	return {}

func _duration_text(entry: Dictionary) -> String:
	var duration_type: String = String(entry.get("duration_type", "dungeon_bound"))
	match duration_type:
		"temporary":
			var remaining_floors: int = int(entry.get("remaining_floors", 0))
			return "%d Floor%s" % [remaining_floors, "" if remaining_floors == 1 else "s"]
		"dungeon_bound":
			return "This Run"
		"permanent":
			return "Permanent"
	return duration_type.capitalize()

func _modifier_text(item: Dictionary) -> String:
	var modifiers_value: Variant = item.get("modifiers", {})
	if not (modifiers_value is Dictionary):
		return "No visible effect"
	var modifiers: Dictionary = modifiers_value
	var parts: Array[String] = []
	for key in modifiers.keys():
		var value: int = int(modifiers[key])
		var prefix: String = "+" if value >= 0 else ""
		parts.append("%s%s %s" % [prefix, value, _modifier_label(String(key))])
	if parts.is_empty():
		return "No visible effect"
	return ", ".join(parts)

func _relic_tooltip_text(entry: Dictionary, item: Dictionary, rarity: String) -> String:
	var lines: Array[String] = []
	lines.append(String(item.get("name", entry.get("id", "Relic"))))
	lines.append("%s | %s" % [_rarity_name(rarity), _duration_text(entry)])
	lines.append("Grants: %s" % _modifier_text(item))
	var source_floor: int = int(entry.get("source_floor", 0))
	if source_floor > 0:
		lines.append("Found on Floor %d" % source_floor)
	var description: String = String(item.get("description", ""))
	if not description.is_empty():
		lines.append("")
		lines.append(description)
	return "\n".join(lines)

func _modifier_label(stat_id: String) -> String:
	match stat_id:
		"max_health":
			return "Max HP"
		"attack_bonus":
			return "Attack"
		"spell_power":
			return "Spell"
		"defense":
			return "Defense"
		"initiative_modifier":
			return "Initiative"
		"potion_heal_bonus":
			return "Potion Heal"
		"movement":
			return "Move"
		"block_bonus":
			return "Block"
		"gold_bonus_percent":
			return "Gold%"
		"xp_bonus_percent":
			return "XP%"
	return stat_id.capitalize()

func _item_icon_texture(icon_key: String) -> Texture2D:
	match icon_key:
		"attack":
			return ICON_ATTACK
		"defense":
			return ICON_DEFEND
		"potion", "health":
			return ICON_POTION
		"move":
			return ICON_MOVE
		"gold":
			return ICON_GOLD
		"spell":
			return ICON_SPELL
		"mode":
			return ICON_MODE
	return ICON_SPECIAL

func _rarity_name(rarity: String) -> String:
	var rarities: Dictionary = GameBalance.get_item_rarities()
	var rarity_value: Variant = rarities.get(rarity, {})
	if rarity_value is Dictionary:
		return String(rarity_value.get("name", rarity.capitalize()))
	if rarity == "very_rare":
		return "Very Rare"
	return rarity.capitalize()

func _rarity_color(rarity: String) -> Color:
	var rarities: Dictionary = GameBalance.get_item_rarities()
	var rarity_value: Variant = rarities.get(rarity, {})
	var color_string: String = ""
	if rarity_value is Dictionary:
		color_string = String(rarity_value.get("color", ""))
	if not color_string.is_empty():
		return Color.html(color_string)
	match rarity:
		"uncommon":
			return Color(0.44, 0.82, 0.51)
		"rare":
			return Color(0.40, 0.65, 1.0)
		"very_rare":
			return Color(0.76, 0.49, 1.0)
		"legendary":
			return Color(1.0, 0.70, 0.30)
	return Color(0.79, 0.76, 0.67)

func _make_texture_panel(texture: Texture2D, minimum_size: Vector2, texture_margin: float, content_margin: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum_size
	panel.add_theme_stylebox_override("panel", _texture_style(texture, texture_margin, content_margin))
	return panel

func _make_fixed_texture_panel(texture: Texture2D, minimum_size: Vector2) -> PanelContainer:
	# Round and medallion-shaped art should be drawn as a whole image. Do not
	# nine-slice these frames, or their center ornaments stretch vertically.
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum_size
	panel.add_theme_stylebox_override("panel", _flat_panel_style(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, 0))
	var image := TextureRect.new()
	image.texture = texture
	image.set_anchors_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(image)
	return panel

func _texture_style(texture: Texture2D, texture_margin: float, content_margin: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, texture_margin)
		style.set_content_margin(side, content_margin)
	return style

func _flat_style(color: Color, corner_radius: int, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(corner_radius)
	return style

func _flat_panel_style(color: Color, corner_radius: int, border_color: Color, border_width: int, content_margin: int) -> StyleBoxFlat:
	var style := _flat_style(color, corner_radius, border_color)
	style.set_border_width_all(border_width)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, content_margin)
	return style

func _style_close_button(button: Button) -> void:
	FantasyButton.apply_dark(button, 17)

func _clear_children_now(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
