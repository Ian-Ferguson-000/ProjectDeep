extends GridContainer
class_name AdventurerStatGrid

## Six attribute rows (name, bar, value) shared by the recruitment dialogue and the
## Company page. Bars show what the keeper knows: a solid fill for an exact value,
## a faint span for an estimate or band, and an empty track for an unknown.

const THEME := preload("res://scripts/ui/tavern_ui_theme.gd")
const STAT_NAMES := {"str":"Strength","dex":"Dexterity","con":"Constitution","int":"Intelligence","wis":"Wisdom","cha":"Charisma"}
const STAT_HINTS := {"str":"Melee power and weapon accuracy.","dex":"Accuracy, dodging, and acting first.","con":"Maximum health and toughness.","int":"Arcane spell power and lore.","wis":"Healing, binding, and judgment.","cha":"Presence, bonds, and bargaining."}
const RANGES := {"Frail":Vector2i(4,7),"Average":Vector2i(8,11),"Strong":Vector2i(12,15),"Exceptional":Vector2i(16,20)}
const MIN_VALUE := 4
const MAX_VALUE := 20
const EXACT_COLOR := Color("#e2b04f")
const ESTIMATE_COLOR := Color("#e2b04f80")
const TRACK_COLOR := Color("#120c08")
const UNKNOWN_TEXT := Color("#7d6f5c")
const FIT_COLORS := {"Exceptional":Color("#9fe08a"),"Strong":Color("#c8dc7a"),"Good":Color("#e8cf72"),"Fair":Color("#e0a35e"),"Poor":Color("#e07a62")}

var compact := false

func _init(compact_layout: bool = false) -> void:
	compact = compact_layout
	columns = 6 if compact else 3
	add_theme_constant_override("h_separation", 10 if not compact else 6)
	add_theme_constant_override("v_separation", 6)

## Shows a roster member, whose stats are fully known.
func show_attributes(attributes: Dictionary) -> void:
	_clear()
	for stat in AdventurerBuilds.ATTRIBUTE_IDS:
		var value := int(attributes.get(stat,10))
		_add_row(stat, Vector2i(value,value), str(value), true)

## Shows a candidate as far as the keeper has learned them.
func show_candidate(candidate: CandidateRecord) -> void:
	_clear()
	var member := candidate.adventurer
	var lead := AdventurerBuilds.lead_stat(member.attributes, member.stat_build_id)
	for stat in AdventurerBuilds.ATTRIBUTE_IDS:
		var value := int(member.attributes.get(stat,10))
		var state := String(candidate.knowledge.get(stat, candidate.knowledge.get("primary_stat","unknown") if stat == lead else "unknown"))
		var contested := false
		for contest_id in VisitorContestRules.CONTESTS:
			if String(VisitorContestRules.CONTESTS[contest_id].stat) == stat and candidate.completed_interactions.has("contest:%s" % contest_id): contested = true
		if state == "exact": _add_row(stat, Vector2i(value,value), str(value), true)
		elif contested or state == "band" or stat == lead:
			var band := VisitorContestRules.band(value)
			var span: Vector2i = RANGES.get(band, Vector2i(8,11))
			_add_row(stat, span, VisitorContestRules.stat_range(value) if contested else band, false)
		else: _add_row(stat, Vector2i.ZERO, "?", false)

func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

func _add_row(stat: String, span: Vector2i, value_text: String, exact: bool) -> void:
	var tooltip := "%s — %s\nMost useful for: %s" % [STAT_NAMES[stat], STAT_HINTS[stat], _classes_using(stat)]
	var name_label := Label.new()
	name_label.text = stat.to_upper() if compact else STAT_NAMES[stat]
	name_label.tooltip_text = tooltip
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	name_label.custom_minimum_size = Vector2(0 if compact else 104, 0)
	name_label.add_theme_font_size_override("font_size", 13 if compact else 15)
	name_label.add_theme_color_override("font_color", THEME.MUTED if compact else THEME.IVORY)
	if compact:
		# Compact chips: "STR 17" with a thin bar underneath.
		var chip := VBoxContainer.new()
		chip.tooltip_text = tooltip
		chip.add_theme_constant_override("separation", 2)
		chip.custom_minimum_size = Vector2(62, 0)
		var line := HBoxContainer.new()
		line.add_child(name_label)
		var value_label := _value_label(value_text, exact, 15)
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(value_label)
		chip.add_child(line)
		chip.add_child(_bar(span, exact, 4))
		add_child(chip)
		return
	add_child(name_label)
	var bar := _bar(span, exact, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.tooltip_text = tooltip
	add_child(bar)
	var value_label := _value_label(value_text, exact, 15)
	value_label.custom_minimum_size = Vector2(92, 0)
	add_child(value_label)

func _value_label(text_value: String, exact: bool, size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", THEME.HIGHLIGHT_GOLD if exact else (UNKNOWN_TEXT if text_value == "?" else THEME.IVORY))
	return label

func _bar(span: Vector2i, exact: bool, height: int) -> Control:
	var track := Panel.new()
	track.custom_minimum_size = Vector2(0, height)
	track.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = TRACK_COLOR
	style.border_color = Color("#4a3522")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	track.add_theme_stylebox_override("panel", style)
	if span == Vector2i.ZERO: return track
	var fill := ColorRect.new()
	fill.color = EXACT_COLOR if exact else ESTIMATE_COLOR
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var full := float(MAX_VALUE - MIN_VALUE + 1)
	fill.anchor_left = 0.0 if exact else clampf(float(span.x - MIN_VALUE) / full, 0.0, 1.0)
	fill.anchor_right = clampf(float(span.y - MIN_VALUE + 1) / full, 0.0, 1.0)
	fill.anchor_top = 0.0
	fill.anchor_bottom = 1.0
	fill.offset_left = 1; fill.offset_right = -1; fill.offset_top = 1; fill.offset_bottom = -1
	track.add_child(fill)
	return track

func _classes_using(stat: String) -> String:
	var names := PackedStringArray()
	for class_id in AdventurerBuilds.CLASS_IDS:
		if int(AdventurerBuilds.class_weights(class_id).get(stat,0)) >= 4: names.append(class_id.capitalize())
	return ", ".join(names) if not names.is_empty() else "Every class a little"
