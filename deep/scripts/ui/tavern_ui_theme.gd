extends RefCounted
class_name TavernUITheme

const CHARCOAL := Color("#0b0d0d")
const DARK_WALNUT := Color("#21160f")
const WALNUT := Color("#352116")
const BRONZE := Color("#8c5a26")
const GOLD := Color("#d8a642")
const HIGHLIGHT_GOLD := Color("#ffd36a")
const IVORY := Color("#ead9b8")
const MUTED := Color("#a99678")

const ICON_ROOT := "res://assets/ui/tavern/icons/"
const CHROME_ROOT := "res://assets/ui/tavern/chrome/"

static func icon(id: String) -> Texture2D:
	var path := ICON_ROOT + id + ".svg"
	return load(path) if ResourceLoader.exists(path) else null

static func class_icon(class_id: String) -> Texture2D:
	return icon("class_" + class_id if class_id in ["warrior", "mage", "healer", "tank", "rogue", "summoner"] else "class_warrior")

static func panel(fill := Color(DARK_WALNUT, 0.96), border := BRONZE, radius := 4, width := 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(8)
	return style

static func nine_patch(id:String, tint:=Color.WHITE) -> StyleBoxTexture:
	var style:=StyleBoxTexture.new();style.texture=load(CHROME_ROOT+id+".svg");style.modulate_color=tint
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:style.set_texture_margin(side,12);style.set_content_margin(side,8)
	return style

static func apply_button(button: Button, primary := false, font_size := 14, minimum := Vector2.ZERO) -> void:
	button.custom_minimum_size = minimum
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_constant_override("icon_max_width", 27)
	button.add_theme_constant_override("h_separation", 8)
	button.add_theme_color_override("font_color", HIGHLIGHT_GOLD if primary else IVORY)
	button.add_theme_color_override("font_hover_color", HIGHLIGHT_GOLD)
	button.add_theme_color_override("font_focus_color", HIGHLIGHT_GOLD)
	button.add_theme_color_override("font_pressed_color", IVORY)
	button.add_theme_color_override("font_disabled_color", Color(MUTED, 0.48))
	button.add_theme_stylebox_override("normal",nine_patch("button_primary" if primary else "button"))
	button.add_theme_stylebox_override("hover",nine_patch("button_primary",Color("#fff3cf")))
	button.add_theme_stylebox_override("focus",nine_patch("button_primary"))
	button.add_theme_stylebox_override("pressed",nine_patch("button_primary",Color("#c99739")))
	button.add_theme_stylebox_override("disabled",nine_patch("button",Color(0.45,0.45,0.45,0.55)))

static func apply_nameplate(button: Button, class_id := "", recruited := false, compact := false) -> void:
	button.icon = class_icon(class_id) if not class_id.is_empty() else null
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 34 if not compact else 0)
	button.add_theme_constant_override("h_separation", 7)
	apply_button(button, false, 12 if not compact else 13, Vector2(176 if not compact else 132, 48 if not compact else 32))
	for state in ["normal","disabled"]:button.add_theme_stylebox_override(state,nine_patch("nameplate",Color.WHITE if state=="normal" else Color(0.45,0.45,0.45,0.6)))
	if recruited:
		button.add_theme_color_override("font_color", Color("#c9d9b0"))

static func style_modal_tree(root: Node) -> void:
	for child in root.get_children():
		if child is Button and not child is CheckButton:
			apply_button(child, false, 14, child.custom_minimum_size)
		elif child is PanelContainer:
			child.add_theme_stylebox_override("panel", panel(Color("#21160ff7"), BRONZE, 5, 2))
		style_modal_tree(child)
