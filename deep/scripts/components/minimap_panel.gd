extends Control
class_name MinimapPanel

var map_state: Dictionary = {}

@onready var background: Panel = $Background
@onready var cells_root: Control = $Background/Cells
@onready var markers_root: Control = $Background/Markers
@onready var title_label: Label = $Background/TitleLabel

func _ready() -> void:
	custom_minimum_size = Vector2(176, 136)
	size = custom_minimum_size
	_style_background()
	title_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.78))

func set_map_state(state: Dictionary) -> void:
	map_state = state
	_render_map()

func _style_background() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.05, 0.86)
	style.border_color = Color(0.36, 0.43, 0.34)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	background.add_theme_stylebox_override("panel", style)

func _render_map() -> void:
	if not is_inside_tree() or map_state.is_empty():
		return
	_clear_children(cells_root)
	_clear_children(markers_root)

	var width := int(map_state.get("width", 1))
	var height := int(map_state.get("height", 1))
	var scale := minf(background.size.x / float(width), background.size.y / float(height))
	var map_size := Vector2(width, height) * scale
	var origin := (background.size - map_size) * 0.5

	for tile in map_state.get("floor_cells", []):
		_add_cell(Vector2i(tile), origin, scale, Color(0.17, 0.33, 0.17))
	for tile in map_state.get("props", []):
		_add_marker(Vector2i(tile), origin, scale, Color(0.48, 0.40, 0.28), 4.0)
	for tile in map_state.get("loot", []):
		_add_marker(Vector2i(tile), origin, scale, Color(0.93, 0.75, 0.28), 4.4)
	for tile in map_state.get("traps", []):
		_add_marker(Vector2i(tile), origin, scale, Color(0.70, 0.18, 0.13), 4.8)
	for tile in map_state.get("enemies", []):
		_add_marker(Vector2i(tile), origin, scale, Color(0.88, 0.20, 0.22), 5.2)

	_add_marker(Vector2i(map_state.get("chest", Vector2i.ZERO)), origin, scale, Color(0.75, 0.43, 0.15), 5.2)
	if bool(map_state.get("secret_found", false)):
		_add_marker(Vector2i(map_state.get("secret", Vector2i.ZERO)), origin, scale, Color(0.84, 0.77, 0.43), 5.2)
	_add_marker(Vector2i(map_state.get("exit", Vector2i.ZERO)), origin, scale, Color(0.30, 0.90, 0.42), 6.0)
	_add_marker(Vector2i(map_state.get("player", Vector2i.ZERO)), origin, scale, Color(0.30, 0.64, 1.0), 6.4)

func _add_cell(tile: Vector2i, origin: Vector2, scale: float, color: Color) -> void:
	var rect := ColorRect.new()
	rect.name = "Cell_%d_%d" % [tile.x, tile.y]
	rect.position = origin + Vector2(tile) * scale
	rect.size = Vector2(scale, scale)
	rect.color = color
	cells_root.add_child(rect)

func _add_marker(tile: Vector2i, origin: Vector2, scale: float, color: Color, marker_size: float) -> void:
	var marker := Panel.new()
	marker.name = "Marker_%d_%d" % [tile.x, tile.y]
	var center := origin + (Vector2(tile) + Vector2(0.5, 0.5)) * scale
	marker.position = center - Vector2(marker_size, marker_size) * 0.5
	marker.size = Vector2(marker_size, marker_size)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(marker_size * 0.5))
	marker.add_theme_stylebox_override("panel", style)
	markers_root.add_child(marker)

func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()
