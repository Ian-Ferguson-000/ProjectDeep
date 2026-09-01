extends RefCounted
class_name FantasyButton

# UI art handoff: default button chrome lives in assets/ui/buttons/.
# Replace these PNGs to reskin ordinary buttons across start, class, tavern,
# dungeon actions, relic rewards, and character menus without touching scenes.

const DARK_BUTTON := preload("res://assets/ui/buttons/fantasy_button_dark_clean.png")
const LIGHT_BUTTON := preload("res://assets/ui/buttons/fantasy_button_light_clean.png")
const COMPACT_DARK_BUTTON := preload("res://assets/ui/buttons/fantasy_button_compact_dark_clean.png")

static func apply_dark(button: Button, font_size: int = 15, minimum_size: Vector2 = Vector2.ZERO) -> void:
	_apply(button, DARK_BUTTON, font_size, minimum_size, Color(1.0, 0.88, 0.62), Color(1.0, 0.95, 0.74), Color(0.82, 0.68, 0.42))

static func apply_light(button: Button, font_size: int = 15, minimum_size: Vector2 = Vector2.ZERO) -> void:
	_apply(button, LIGHT_BUTTON, font_size, minimum_size, Color(0.20, 0.12, 0.055), Color(0.10, 0.065, 0.035), Color(0.28, 0.16, 0.07))

static func apply_compact_dark(button: Button, font_size: int = 13, minimum_size: Vector2 = Vector2.ZERO) -> void:
	_apply_compact(button, COMPACT_DARK_BUTTON, font_size, minimum_size, Color(1.0, 0.88, 0.62), Color(1.0, 0.95, 0.74), Color(0.82, 0.68, 0.42))

static func style(texture: Texture2D, content_margin: float = 18.0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	box.set_texture_margin(SIDE_LEFT, 44.0)
	box.set_texture_margin(SIDE_RIGHT, 44.0)
	box.set_texture_margin(SIDE_TOP, 14.0)
	box.set_texture_margin(SIDE_BOTTOM, 14.0)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, content_margin)
	return box

static func compact_style(texture: Texture2D, content_margin: float = 10.0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	box.set_texture_margin(SIDE_LEFT, 44.0)
	box.set_texture_margin(SIDE_RIGHT, 44.0)
	box.set_texture_margin(SIDE_TOP, 24.0)
	box.set_texture_margin(SIDE_BOTTOM, 24.0)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, content_margin)
	return box

static func _apply(button: Button, texture: Texture2D, font_size: int, minimum_size: Vector2, font_color: Color, hover_color: Color, pressed_color: Color) -> void:
	if minimum_size != Vector2.ZERO:
		button.custom_minimum_size = minimum_size
	button.add_theme_stylebox_override("normal", style(texture))
	button.add_theme_stylebox_override("hover", style(texture))
	button.add_theme_stylebox_override("pressed", style(texture, 20.0))
	button.add_theme_stylebox_override("focus", style(texture))
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", hover_color)
	button.add_theme_color_override("font_pressed_color", pressed_color)
	button.add_theme_color_override("font_disabled_color", Color(font_color.r, font_color.g, font_color.b, 0.45))
	button.add_theme_font_size_override("font_size", font_size)

static func _apply_compact(button: Button, texture: Texture2D, font_size: int, minimum_size: Vector2, font_color: Color, hover_color: Color, pressed_color: Color) -> void:
	if minimum_size != Vector2.ZERO:
		button.custom_minimum_size = minimum_size
	button.add_theme_stylebox_override("normal", compact_style(texture))
	button.add_theme_stylebox_override("hover", compact_style(texture))
	button.add_theme_stylebox_override("pressed", compact_style(texture, 11.0))
	button.add_theme_stylebox_override("focus", compact_style(texture))
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", hover_color)
	button.add_theme_color_override("font_pressed_color", pressed_color)
	button.add_theme_color_override("font_disabled_color", Color(font_color.r, font_color.g, font_color.b, 0.45))
	button.add_theme_font_size_override("font_size", font_size)
