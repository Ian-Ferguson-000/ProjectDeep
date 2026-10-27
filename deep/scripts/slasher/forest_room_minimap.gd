extends Control
class_name ForestRoomMinimap

## Isaac-style map of the current forest floor. Only rooms the party has entered
## are drawn; doors to unexplored rooms show as short blank passages. Rooms with a
## known purpose carry a small marker. The map stays centred on the party's room.

const CELL := Vector2(26,18)
const GAP := 4.0
const COLORS := {"current":Color("#f3e3b4"),"cleared":Color("#6f9b67"),"visited":Color("#a9875a"),"unknown":Color("#5d4a35"),"line":Color("#3d2d1f")}
const MARKERS := {"shop":["$",Color("#f0c552")],"treasure":["♦",Color("#e08af0")],"boss":["▼",Color("#e86a4a")],"elite":["!",Color("#ff9e5a")],"start":["•",Color("#d9cfb7")],"rest":["^",Color("#ff9a3d")]}

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
	# Only rooms the party has entered are drawn. A door leading somewhere new shows
	# as a short blank passage, so the shape of the floor is learned by exploring.
	for id in known:
		if not known[id]: continue
		var room: Dictionary = rooms[id]
		var a := _point(room,origin,center)
		for neighbor in Dictionary(room.get("neighbors",{})).values():
			var b := _point(rooms[int(neighbor)],origin,center)
			if bool(known.get(int(neighbor),false)): draw_line(a,b,COLORS.line,3.0)
			elif _is_gate(rooms[int(neighbor)]): draw_line(a,b,GATE_COLOR.darkened(0.3),3.0)
			else: draw_line(a,a.lerp(b,0.85),COLORS.unknown,3.0)
	# Like Isaac, the gate room shows up as soon as you're next to it.
	for id in known:
		if known[id] or not _is_gate(rooms[id]): continue
		var gate_rect := Rect2(_point(rooms[id],origin,center) - CELL*0.5,CELL)
		if not Rect2(Vector2.ZERO,size).grow(-2).encloses(gate_rect): continue
		draw_rect(gate_rect,Color("#3a1410"))
		draw_rect(gate_rect,GATE_COLOR,false,1.5)
		_draw_skull(gate_rect.get_center())
	for id in known:
		if not known[id]: continue
		var room: Dictionary = rooms[id]
		var rect := Rect2(_point(room,origin,center) - CELL*0.5,CELL)
		if not Rect2(Vector2.ZERO,size).grow(-2).encloses(rect): continue
		var fill: Color = COLORS.current if id == current else (COLORS.cleared if bool(room.get("cleared",false)) else COLORS.visited)
		draw_rect(rect,fill)
		if id == current: draw_rect(rect.grow(2),Color.WHITE,false,1.5)
		var marker: Array = MARKERS.get(String(room.get("role","")),[])
		if _is_gate(room) and not bool(room.get("cleared",false)):
			_draw_skull(rect.get_center())
			continue
		if not marker.is_empty() and not (String(room.role) == "treasure" and bool(room.get("reward_claimed",false))):
			var font := get_theme_default_font()
			draw_string(font,rect.position+Vector2(0,13),String(marker[0]),HORIZONTAL_ALIGNMENT_CENTER,CELL.x,13,Color(0.08,0.06,0.04) if id == current else marker[1])

const GATE_COLOR := Color("#e0503c")

func _is_gate(room: Dictionary) -> bool:
	return String(room.get("role","")) == "boss"

func _draw_skull(at: Vector2) -> void:
	var bone := Color("#f2e6d0"); var dark := Color("#1a0806")
	draw_circle(at + Vector2(0,-1),5.5,bone)
	draw_rect(Rect2(at + Vector2(-3,3),Vector2(6,3)),bone)
	draw_circle(at + Vector2(-2,-1),1.5,dark); draw_circle(at + Vector2(2,-1),1.5,dark)

func _point(room: Dictionary, origin: Vector2, center: Vector2) -> Vector2:
	var offset := Vector2(room.get("position",Vector2i.ZERO)) - origin
	return center + offset * (CELL + Vector2(GAP,GAP))
