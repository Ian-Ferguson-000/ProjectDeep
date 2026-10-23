extends Control
class_name ForestRoomMinimap

## Isaac-style map of the current forest floor. Visited rooms are filled, rooms
## next to them show as faint outlines until entered, and rooms with a known
## purpose carry a small marker. The map stays centred on the party's room.

const CELL := Vector2(26,18)
const GAP := 4.0
const COLORS := {"current":Color("#f3e3b4"),"cleared":Color("#6f9b67"),"visited":Color("#a9875a"),"unknown":Color("#5d4a35"),"line":Color("#3d2d1f")}
const MARKERS := {"shop":["$",Color("#f0c552")],"treasure":["♦",Color("#e08af0")],"boss":["▼",Color("#e86a4a")],"elite":["!",Color("#ff9e5a")],"start":["•",Color("#d9cfb7")]}

var run_state: RunState

func setup(state: RunState) -> void:
	run_state = state
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	queue_redraw()

func _draw() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#0c120fd9"); panel.border_color = Color("#795238"); panel.set_border_width_all(2); panel.set_corner_radius_all(7)
	draw_style_box(panel,Rect2(Vector2.ZERO,size))
	if run_state == null: return
	var rooms: Array = run_state.field_run.get("rooms",[])
	if rooms.is_empty(): return
	var current := int(run_state.field_run.get("current_room",0))
	var origin := Vector2(Dictionary(rooms[current]).get("position",Vector2i.ZERO))
	var center := size * 0.5
	var known := {}
	for value in rooms:
		var room: Dictionary = value
		if bool(room.get("visited",false)) or int(room.id) == current:
			known[int(room.id)] = true
			for neighbor in Dictionary(room.get("neighbors",{})).values(): if not known.has(int(neighbor)): known[int(neighbor)] = false
	for id in known:
		if not known[id]: continue
		var room: Dictionary = rooms[id]
		var a := _point(room,origin,center)
		for neighbor in Dictionary(room.get("neighbors",{})).values():
			draw_line(a,_point(rooms[int(neighbor)],origin,center),COLORS.line,3.0)
	for id in known:
		var room: Dictionary = rooms[id]
		var rect := Rect2(_point(room,origin,center) - CELL*0.5,CELL)
		if not Rect2(Vector2.ZERO,size).grow(-2).encloses(rect): continue
		if not known[id]:
			draw_rect(rect,COLORS.unknown,false,1.5)
			continue
		var fill: Color = COLORS.current if id == current else (COLORS.cleared if bool(room.get("cleared",false)) else COLORS.visited)
		draw_rect(rect,fill)
		if id == current: draw_rect(rect.grow(2),Color.WHITE,false,1.5)
		var marker: Array = MARKERS.get(String(room.get("role","")),[])
		if not marker.is_empty() and not (String(room.role) == "treasure" and bool(room.get("reward_claimed",false))):
			var font := get_theme_default_font()
			draw_string(font,rect.position+Vector2(0,13),String(marker[0]),HORIZONTAL_ALIGNMENT_CENTER,CELL.x,13,Color(0.08,0.06,0.04) if id == current else marker[1])

func _point(room: Dictionary, origin: Vector2, center: Vector2) -> Vector2:
	var offset := Vector2(room.get("position",Vector2i.ZERO)) - origin
	return center + offset * (CELL + Vector2(GAP,GAP))
