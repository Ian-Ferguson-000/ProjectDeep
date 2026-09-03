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
const OPTIONS_PANEL := preload("res://scripts/ui/game_options_panel.gd")

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
var active_tab := 0
var previous_pause := false

func setup(callback: Callable) -> void:
	close_callback = callback
	name = "CharacterMenu"
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -500
	offset_top = -315
	offset_right = 500
	offset_bottom = 315
	custom_minimum_size = Vector2(940, 580)
	add_theme_stylebox_override("panel", _texture_style(MENU_FRAME, 44.0, 24.0))

func set_open(open: bool) -> void:
	if visible == open: return
	if open:
		previous_pause = get_tree().paused
		visible = true
		move_to_front()
		get_tree().paused = true
	else:
		visible = false
		get_tree().paused = previous_pause

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("character_menu") or event.is_action_pressed("ui_cancel")):
		_request_close()
		get_viewport().set_input_as_handled()

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

	var tabs := TabContainer.new()
	tabs.name = "StrategyCodexTabs"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 16)
	body.add_child(tabs)

	var stats_body := _add_tab(tabs, "Stats")
	var stats_columns := HBoxContainer.new()
	stats_columns.add_theme_constant_override("separation", 12)
	stats_body.add_child(stats_columns)
	var main_column := VBoxContainer.new()
	main_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_column.add_theme_constant_override("separation", 10)
	stats_columns.add_child(main_column)
	main_column.add_child(_make_stats_section(run_state, derived_stats))
	main_column.add_child(_make_tip_panel())
	var side_column := VBoxContainer.new()
	side_column.custom_minimum_size = Vector2(245, 0)
	side_column.add_theme_constant_override("separation", 10)
	stats_columns.add_child(side_column)
	side_column.add_child(_make_class_panel(run_state))
	side_column.add_child(_make_resistance_panel())
	side_column.add_child(_make_info_panel(run_state))

	var progression_body := _add_tab(tabs, "Progression")
	progression_body.add_child(_make_progression_section(run_state))

	var items_body := _add_tab(tabs, "Items")
	items_body.add_child(_make_carried_resources_section(run_state, gear_name))
	items_body.add_child(_make_relics_section(relic_entries))

	var journal_body := _add_tab(tabs, "Journal")
	journal_body.add_child(_make_journal_section(run_state))

	var options_body := _add_tab(tabs, "Options")
	var options: GameOptionsPanel = OPTIONS_PANEL.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_body.add_child(options)
	options.setup(false)
	tabs.current_tab = clampi(active_tab, 0, tabs.get_tab_count() - 1)
	tabs.tab_changed.connect(func(index: int): active_tab = index)

	var hint := _make_label("M / Start: Close menu   ·   Tab / LB: Cycle party outside the menu", 12, Color(0.75, 0.60, 0.36), HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(hint)

func _add_tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	return body

func _make_progression_section(run_state: RunState) -> PanelContainer:
	var panel := _make_texture_panel(SECTION_PANEL, Vector2(0, 390), 42.0, 18.0)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)
	body.add_child(_make_section_title("STRATEGY PROGRESSION"))
	body.add_child(_make_wrapped_label("%s · Level %d\n%s" % [run_state.selected_class_name, run_state.get_level(), run_state.get_profile_summary()], 18, Color(1.0, 0.86, 0.58)))
	body.add_child(_make_wrapped_label(run_state.get_progression_summary(), 16, Color(0.58, 0.87, 0.95)))
	var class_data := GameBalance.get_base_class(run_state.selected_class_id)
	var actions: Dictionary = class_data.get("actions", {})
	for slot in ["basic", "movement", "special", "defensive"]:
		var action_name := _menu_action_name(actions, slot)
		body.add_child(_make_wrapped_label("%s · %s\n%s" % [slot.capitalize(), action_name, GameBalance.get_action_tooltip(run_state.selected_class_id, slot)], 14, Color(0.88, 0.78, 0.62)))
	if run_state.has_pending_progression_choice():
		body.add_child(_make_wrapped_label("A progression choice is waiting and will be presented at the next reward checkpoint.", 14, Color(0.98, 0.76, 0.30)))
	return panel

func _make_carried_resources_section(run_state: RunState, gear_name: String) -> PanelContainer:
	var panel := _make_texture_panel(SECTION_PANEL, Vector2(0, 125), 42.0, 14.0)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 9)
	panel.add_child(body)
	body.add_child(_make_section_title("CARRIED RESOURCES"))
	body.add_child(_make_wrapped_label("%s\nGear: %s" % [run_state.get_resource_summary(), gear_name], 16, Color(0.94, 0.83, 0.60)))
	var consumable_names: Array[String] = []
	for consumable_id in run_state.get_consumables(): consumable_names.append(String(GameBalance.get_consumable(consumable_id).get("name", consumable_id.capitalize())))
	body.add_child(_make_wrapped_label("Consumables: %s" % (", ".join(consumable_names) if not consumable_names.is_empty() else "None"), 13, Color(0.82, 0.68, 0.45)))
	return panel

func _make_journal_section(run_state: RunState) -> PanelContainer:
	var panel := _make_texture_panel(SECTION_PANEL, Vector2(0, 390), 42.0, 18.0)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 9)
	panel.add_child(body)
	body.add_child(_make_section_title("CREATURE JOURNAL"))
	var journal := GameBalance.get_slasher_journal()
	var discovered_count := 0
	for enemy_value in journal.get("order", []):
		var enemy_id := String(enemy_value)
		if not run_state.is_enemy_discovered(enemy_id): continue
		discovered_count += 1
		var entry := GameBalance.get_slasher_journal_entry(enemy_id)
		body.add_child(_make_wrapped_label("%s · %d defeated\n%s\nTraits: %s" % [String(entry.get("name", enemy_id.capitalize())), run_state.get_enemy_defeat_count(enemy_id), String(entry.get("description", "")), ", ".join(entry.get("traits", []))], 14, Color(0.88, 0.78, 0.62)))
	if discovered_count == 0: body.add_child(_make_wrapped_label("Defeat a creature to add its identity and field notes here.", 16, Color(0.75, 0.60, 0.36)))
	return panel

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
	resource_row.add_child(_make_icon_text(ICON_POTION, "Consumables %d/%d" % [run_state.get_consumables().size(), run_state.get_consumable_capacity()]))

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
	stats_grid.add_child(_make_stat_tile(ICON_ATTACK, "STR %d" % int(stats.get("str", 0)), "Strength", run_state.get_attribute_growth_explanation("str")))
	stats_grid.add_child(_make_stat_tile(ICON_MOVE, "DEX %d" % int(stats.get("dex", 0)), "Dexterity", run_state.get_attribute_growth_explanation("dex")))
	stats_grid.add_child(_make_stat_tile(ICON_DEFEND, "CON %d" % int(stats.get("con", 0)), "Constitution", run_state.get_attribute_growth_explanation("con")))
	stats_grid.add_child(_make_stat_tile(ICON_SPELL, "INT %d" % int(stats.get("int", 0)), "Intelligence", run_state.get_attribute_growth_explanation("int")))
	stats_grid.add_child(_make_stat_tile(ICON_MODE, "WIS %d" % int(stats.get("wis", 0)), "Wisdom", run_state.get_attribute_growth_explanation("wis")))
	stats_grid.add_child(_make_stat_tile(ICON_SPECIAL, "CHA %d" % int(stats.get("cha", 0)), "Charisma", run_state.get_attribute_growth_explanation("cha")))

	stats_grid.add_child(_make_stat_tile(ICON_ATTACK, "Accuracy +%d" % int(derived_stats.get("accuracy", 0)), "Attack rolls", _breakdown_tooltip(run_state, "accuracy")))
	stats_grid.add_child(_make_stat_tile(ICON_ATTACK, "Pen +%d" % int(derived_stats.get("penetration", 0)), "Penetration", _breakdown_tooltip(run_state, "penetration")))
	stats_grid.add_child(_make_stat_tile(ICON_ATTACK, "Power +%d" % int(derived_stats.get("attack_power", 0)), "Martial damage"))
	stats_grid.add_child(_make_stat_tile(ICON_SPELL, "Potency +%d" % int(derived_stats.get("spell_potency", 0)), "Spell damage"))
	stats_grid.add_child(_make_stat_tile(ICON_DEFEND, "AC %d" % int(derived_stats.get("armor_class", 10)), "Reaction window"))
	stats_grid.add_child(_make_stat_tile(ICON_MOVE, "Evasion %d" % int(derived_stats.get("evasion", 10)), "Hit avoidance"))
	stats_grid.add_child(_make_stat_tile(ICON_DEFEND, "Threshold %d" % int(derived_stats.get("threshold", 0)), "Minimum damaging hit"))
	stats_grid.add_child(_make_stat_tile(ICON_DEFEND, "Aegis %d" % int(derived_stats.get("aegis_all", 0)), "All damage reduction"))
	stats_grid.add_child(_make_stat_tile(ICON_SPELL, "Range +%d" % int(derived_stats.get("range", 0)), "Attack reach"))
	stats_grid.add_child(_make_stat_tile(ICON_INIT, "Init +%d" % int(derived_stats.get("initiative_modifier", 0)), "Initiative"))
	stats_grid.add_child(_make_stat_tile(ICON_POTION, "Potion +%d" % int(derived_stats.get("potion_heal_bonus", 0)), "Potion Effect"))
	stats_grid.add_child(_make_stat_tile(ICON_MOVE, "Move +%d" % int(derived_stats.get("movement", 0)), "Movement"))
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
	var class_data := GameBalance.get_base_class(run_state.selected_class_id)
	var class_line: String = String(class_data.get("description", "A hero with a distinct combat discipline."))
	body.add_child(_make_label(run_state.selected_class_name, 18, Color(1.0, 0.86, 0.58), HORIZONTAL_ALIGNMENT_CENTER))
	body.add_child(_make_wrapped_label(class_line, 13, Color(0.84, 0.70, 0.45)))
	var resource_rules := _make_wrapped_label(run_state.get_class_resource_explanation(), 11, Color(0.91, 0.76, 0.42))
	resource_rules.tooltip_text = run_state.get_class_resource_explanation()
	body.add_child(resource_rules)
	body.add_child(_make_wrapped_label(run_state.get_progression_summary(), 10, Color(0.58, 0.87, 0.95)))
	body.add_child(_make_label("Starting Kit", 13, Color(0.91, 0.60, 0.26), HORIZONTAL_ALIGNMENT_CENTER))
	var actions: Dictionary = class_data.get("actions", {})
	var starter_text: String = "%s\n%s\n%s\n%s" % [_menu_action_name(actions, "basic"), _menu_action_name(actions, "special"), _menu_action_name(actions, "defensive"), _menu_action_name(actions, "movement")]
	var kit_label := _make_wrapped_label(starter_text, 12, Color(0.86, 0.78, 0.64))
	var action_tips: Array[String] = []
	for slot in ["basic", "special", "defensive", "movement"]: action_tips.append("%s\n%s" % [_menu_action_name(actions, slot), GameBalance.get_action_tooltip(run_state.selected_class_id, slot)])
	kit_label.tooltip_text = "\n\n".join(action_tips)
	body.add_child(kit_label)
	return panel

func _menu_action_name(actions: Dictionary, slot: String) -> String:
	var value: Variant = actions.get(slot, {})
	return String(value.get("name", slot.capitalize())) if value is Dictionary else slot.capitalize()

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

func _make_stat_tile(icon: Texture2D, title: String, subtitle: String, detail: String = "") -> PanelContainer:
	# Visual handoff: stat rows intentionally use a flat style so future artists
	# can replace only the section frame without fighting nested textures.
	var tile := PanelContainer.new()
	tile.tooltip_text = detail if not detail.is_empty() else subtitle
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

func _breakdown_tooltip(run_state: RunState, stat_id: String) -> String:
	var value := run_state.get_stat_breakdown(stat_id)
	var attribute := String(value.get("attribute", ""))
	var source := ""
	if not attribute.is_empty(): source = "\n%s %d gives modifier %+d." % [attribute.to_upper(), int(value.get("attribute_value", 0)), int(value.get("attribute_modifier", 0))]
	return "%s%s\nClass/level: %+d · Progression: %+d · Items: %+d\nFinal: %d" % [String(value.get("formula", "")), source, int(value.get("base_and_level", 0)), int(value.get("progression", 0)), int(value.get("item", 0)), int(value.get("final", 0))]

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
	var rules_text := String(item.get("rules_text", ""))
	if not rules_text.is_empty():
		lines.append("")
		lines.append(rules_text)
	return "\n".join(lines)

func _modifier_label(stat_id: String) -> String:
	match stat_id:
		"max_health":
			return "Max HP"
		"attack_bonus":
			return "Attack"
		"accuracy":
			return "Accuracy"
		"penetration":
			return "Penetration"
		"attack_power":
			return "Attack Power"
		"spell_potency":
			return "Spell Potency"
		"armor_class":
			return "Armor Class"
		"evasion":
			return "Evasion"
		"threshold":
			return "Threshold"
		"aegis_all":
			return "Aegis"
		"range":
			return "Range"
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
