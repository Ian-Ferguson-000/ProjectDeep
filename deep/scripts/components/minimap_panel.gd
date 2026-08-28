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
	if String(map_state.get("mode", "tiles")) == "field":
		_render_field_map()
		return

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

func _render_field_map() -> void:
	title_label.text = "FIELD MAP"
	var rooms: Array = map_state.get("rooms", [])
	if rooms.is_empty(): return
	var min_x := 999; var min_y := 999; var max_x := -999; var max_y := -999
	for room in rooms:
		var pos := Vector2i(room.get("position", Vector2i.ZERO)); min_x = mini(min_x,pos.x); min_y = mini(min_y,pos.y); max_x = maxi(max_x,pos.x); max_y = maxi(max_y,pos.y)
	var span := Vector2i(max_x-min_x+1,max_y-min_y+1)
	var scale := minf(26.0, minf((background.size.x-24.0)/float(maxi(1,span.x)),(background.size.y-28.0)/float(maxi(1,span.y))))
	var origin := (background.size-Vector2(span)*scale)*0.5-Vector2(min_x,min_y)*scale
	for room in rooms:
		if not bool(room.get("visited",false)): continue
		var id := int(room.get("id",-1)); var pos := Vector2i(room.get("position",Vector2i.ZERO)); var center := origin+(Vector2(pos)+Vector2(0.5,0.5))*scale
		for neighbor in Dictionary(room.get("neighbors",{})).values():
			if int(neighbor) <= id or int(neighbor) >= rooms.size() or not bool(rooms[int(neighbor)].get("visited",false)): continue
			var other := Vector2i(rooms[int(neighbor)].get("position",Vector2i.ZERO)); var line := ColorRect.new(); var other_center := origin+(Vector2(other)+Vector2(0.5,0.5))*scale
			line.position = Vector2(minf(center.x,other_center.x),minf(center.y,other_center.y))-Vector2(2,2); line.size = Vector2(abs(center.x-other_center.x)+4,abs(center.y-other_center.y)+4); line.color=Color(0.48,0.34,0.20); cells_root.add_child(line)
	for room in rooms:
		if not bool(room.get("visited",false)): continue
		var role := String(room.get("role","combat")); var color := Color(0.34,0.30,0.24)
		if bool(room.get("cleared",false)): color=Color(0.32,0.58,0.34)
		match role:
			"shop": color=Color(0.88,0.68,0.22)
			"treasure": color=Color(0.78,0.45,0.16)
			"elite": color=Color(0.72,0.22,0.18)
			"boss": color=Color(0.58,0.12,0.12)
		if int(room.get("id",-1)) == int(map_state.get("current_room",-2)): color=Color(0.28,0.62,1.0) if not bool(map_state.get("doors_locked",false)) else Color(0.95,0.32,0.16)
		_add_marker(Vector2i(room.get("position",Vector2i.ZERO)),origin,scale,color,12.0)

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
