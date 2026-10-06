extends PanelContainer
## Presentation only. Settlement remains authoritative in the campaign.
const UI := preload("res://scripts/ui/tavern_ui_theme.gd")
const CREST := preload("res://scripts/ui/expedition_crest.gd")
var details: RichTextLabel
var continue_button: Button
var title_label: Label
var subtitle: Label
var crest: Control
var party_cards: HFlowContainer
var report_scroll: ScrollContainer
var reward_labels: Array[Label] = []
var reward_totals: Array[int] = [0, 0, 0]
var animation_time := 0.0
var victorious := false

func _ready() -> void:
	name = "ExpeditionResults"
	set_meta("preferred_size", Vector2(900, 640))
	add_theme_stylebox_override("panel", UI.panel(Color("#17130ffb"), UI.GOLD, 8, 2))
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var body := VBoxContainer.new(); body.add_theme_constant_override("separation", 14); margin.add_child(body)
	var header := HBoxContainer.new(); header.custom_minimum_size.y = 112; body.add_child(header)
	crest = CREST.new(); crest.custom_minimum_size = Vector2(140, 112); header.add_child(crest)
	var heading := VBoxContainer.new(); heading.alignment = BoxContainer.ALIGNMENT_CENTER; heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(heading)
	heading.add_child(_label("THE HEARTH  /  EXPEDITION REPORT", 12, UI.MUTED))
	title_label = _label("Dungeon Cleared", 36, UI.HIGHLIGHT_GOLD); title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; title_label.max_lines_visible = 2; heading.add_child(title_label)
	subtitle = _label("", 16, UI.IVORY); subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; subtitle.max_lines_visible = 2; heading.add_child(subtitle)
	var rewards := HBoxContainer.new(); rewards.add_theme_constant_override("separation", 12); body.add_child(rewards)
	for caption in ["GOLD RECOVERED", "COMPANY SHARE", "BANKED AT THE HEARTH"]:
		var card := PanelContainer.new(); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var banked: bool = caption == "BANKED AT THE HEARTH"
		card.add_theme_stylebox_override("panel", UI.panel(Color("#23281c") if banked else Color("#292015"), Color("#8c965f") if banked else UI.BRONZE, 5, 1)); rewards.add_child(card)
		var box := VBoxContainer.new(); card.add_child(box)
		var count_row := HBoxContainer.new(); count_row.add_theme_constant_override("separation", 10); box.add_child(count_row)
		var coin := TextureRect.new(); coin.texture = UI.icon("bank"); coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; coin.custom_minimum_size = Vector2(24,24); count_row.add_child(coin)
		var number := _label("0", 30, Color("#d3e6a9") if banked else UI.HIGHLIGHT_GOLD); count_row.add_child(number); reward_labels.append(number)
		box.add_child(_label(caption, 11, UI.MUTED))
	report_scroll = ScrollContainer.new(); report_scroll.name = "ReportScroll"; report_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; report_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; body.add_child(report_scroll)
	var content := VBoxContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation", 12); report_scroll.add_child(content)
	party_cards = HFlowContainer.new(); party_cards.add_theme_constant_override("h_separation", 10); party_cards.add_theme_constant_override("v_separation", 10); content.add_child(party_cards)
	details = RichTextLabel.new(); details.name = "ReportDetails"; details.bbcode_enabled = true; details.fit_content = true; details.scroll_active = false; details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_font_size_override("normal_font_size", 15); details.add_theme_color_override("default_color", UI.IVORY); content.add_child(details)
	continue_button = Button.new(); continue_button.name = "ContinueButton"; continue_button.text = "Continue in Tavern"; UI.apply_button(continue_button, true, 16, Vector2(0, 44)); body.add_child(continue_button)

func _label(copy: String, font_size: int, color: Color) -> Label:
	var label := Label.new(); label.text = copy; label.add_theme_font_size_override("font_size", font_size); label.add_theme_color_override("font_color", color); return label

func present(summary: Dictionary, state: RunState, fallback: String) -> void:
	animation_time = 0.0
	for child in party_cards.get_children(): child.free()
	var reports: Array = summary.get("reports", []).duplicate(true)
	if reports.is_empty() and not summary.is_empty(): reports.append(summary)
	victorious = not reports.is_empty()
	var all_dead := not reports.is_empty()
	reward_totals = [0, 0, 0]
	var lines: Array[String] = []
	var seen: Array[String] = []
	for report in reports:
		var outcome := String(report.get("outcome", "return"))
		victorious = victorious and outcome == "victory"
		all_dead = all_dead and outcome == "death"
		var gross := int(report.get("gold", 0)); var share := int(report.get("share", 0))
		reward_totals[0] += gross; reward_totals[1] += share; reward_totals[2] += int(report.get("net", gross - share))
		var headline := String(report.get("headline", "Expedition return"))
		lines.append("[b][color=#ffd36a]%s[/color][/b]  ·  %s%s" % [headline, String(report.get("deployment_type", "manual")).capitalize(), "  ·  Depth %d" % int(report.depth) if report.has("depth") else ""])
		if reports.size() > 1: lines.append("Gold %d  ·  Company share %d  ·  Banked %d" % [gross, share, int(report.get("net", gross-share))])
		for field in ["returned", "retired", "lost"]:
			var names: Array = report.get(field, [])
			if field != "returned" and not names.is_empty(): lines.append("[color=%s]%s: %s[/color]" % ["#e49c8e" if field == "lost" else "#c9d9b0", field.capitalize(), ", ".join(names)])
			for hero_name in names:
				var key := "%s:%s" % [field, hero_name]
				if not seen.has(key): _hero_card(String(hero_name), field, state); seen.append(key)
		if int(report.get("essence", 0)) > 0: lines.append("[color=#c9d9b0]Relic essence recovered: +%d[/color]" % int(report.essence))
		var items: Array = report.get("items", [])
		if not items.is_empty(): lines.append("Recovered items: %s" % ", ".join(items.map(func(item): return str(item))))
		lines.append("")
	crest.victorious = victorious; crest.elapsed = 0.0
	title_label.text = "Dungeon Cleared" if victorious else ("The Fallen Remembered" if all_dead else "Return to the Hearth")
	title_label.add_theme_color_override("font_color", UI.HIGHLIGHT_GOLD if victorious else UI.IVORY)
	var headline := String(summary.get("headline", fallback if not fallback.is_empty() else "Welcome home, adventurers."))
	subtitle.text = headline
	if reports.size() == 1 and not String(reports[0].get("dungeon", "")).is_empty():
		var dungeon_id := String(reports[0].dungeon)
		subtitle.text = String(GameBalance.get_dungeon(dungeon_id).get("name", dungeon_id.capitalize()))
		if reports[0].has("depth"): subtitle.text += "  ·  Depth %d" % int(reports[0].depth)
	if reports.is_empty(): lines.append(headline)
	if not String(summary.get("slasher_progression", "")).is_empty(): lines.append("[b][color=#ffd36a]SLASHER PATH[/color][/b]\n%s\n" % String(summary.slasher_progression))
	var changes: Array = summary.get("changes", [])
	if not changes.is_empty(): lines.append("[b][color=#ffd36a]THE WORLD REMEMBERS[/color][/b]\n• " + "\n• ".join(changes))
	details.text = "\n".join(lines)
	report_scroll.scroll_vertical = 0
	_update_numbers(0.0)

func _hero_card(hero_name: String, status: String, state: RunState) -> void:
	var card := PanelContainer.new(); card.custom_minimum_size = Vector2(190, 70)
	card.add_theme_stylebox_override("panel", UI.panel(Color("#201d17"), Color("#756741") if status != "lost" else Color("#81534b"), 4, 1)); party_cards.add_child(card)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); card.add_child(row)
	var member: CharacterRecord = null
	if state != null and state.campaign != null:
		for candidate in state.campaign.roster.values():
			if candidate.display_name == hero_name: member = candidate; break
	var portrait := TextureRect.new(); portrait.custom_minimum_size = Vector2(48, 52); portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path := "res://assets/roster_portraits/%s_%d.png" % [member.class_id, member.portrait_variant] if member != null else ""
	portrait.texture = load(path) if not path.is_empty() and ResourceLoader.exists(path) else UI.icon("roster"); row.add_child(portrait)
	var copy := VBoxContainer.new(); copy.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_child(copy)
	copy.add_child(_label(hero_name, 17, UI.IVORY))
	copy.add_child(_label("%s · Lv %d" % [member.class_id.capitalize(), member.level] if member != null else "Adventurer", 12, UI.MUTED))
	copy.add_child(_label("RETURNED" if status == "returned" else status.to_upper(), 10, Color("#c9d9b0") if status != "lost" else Color("#e49c8e")))

func _process(delta: float) -> void:
	if not is_visible_in_tree() or animation_time >= 1.2: return
	animation_time = minf(animation_time + delta, 1.2)
	_update_numbers(1.0 - pow(1.0 - animation_time / 1.2, 3))

func _update_numbers(progress: float) -> void:
	for i in reward_labels.size(): reward_labels[i].text = str(roundi(reward_totals[i] * progress))
