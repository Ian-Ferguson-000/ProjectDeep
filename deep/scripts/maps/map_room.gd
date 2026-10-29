@tool
extends Node2D
class_name MapRoom

## The root of a room scene in maps/<dungeon>/rooms/. The game finds every
## room scene in that folder by itself.
##
## Layers (children, all TileMapLayers):
##   Ground   - base floor everywhere, including under walls
##   Terrain  - water and cobblestone (water blocks movement)
##   Paths    - dirt trails (draw with the Terrains tab for automatic edges)
##   Detail   - decoration only, never blocks
##   Thicket  - paint the wall: the game grows trees there. Hidden in game.
##   Canopy   - optional art drawn above characters
## Markers (Node2D) holds MapMarker nodes: spawns, loot, merchant, props.
##
## Doors are always at the middle of each edge: keep those cells open.
## Problems show as a warning triangle on this node in the Scene tree.
## Press F6 to play this room on its own.

const CELL := 48
const ROLE_NAMES := ["start","combat","elite","treasure","shop","rest","boss","guardian"]

@export var room_name := "New Room":
	set(value): room_name = value; queue_redraw()
## Which kinds of room this map can be used for.
@export_flags("start","combat","elite","treasure","shop","rest","boss","guardian") var roles := 2
## How often this map is picked compared with others of the same role (1 = normal).
@export_range(0.05,5.0,0.05) var weight := 1.0
## Size in 48px cells. Must be odd. Forest: standard 27x15, large 35x19.
## Crypt (1.5x): standard 41x23, large 53x29.
@export var size_cells := Vector2i(27,15):
	set(value): size_cells = value; queue_redraw(); update_configuration_warnings()

var _warning_timer := 0.0

func role_list() -> Array[String]:
	var result: Array[String] = []
	for index in ROLE_NAMES.size():
		if roles & (1 << index): result.append(ROLE_NAMES[index])
	return result

func door_cells() -> Dictionary:
	return {"north":Vector2i(size_cells.x / 2,0),"south":Vector2i(size_cells.x / 2,size_cells.y - 1),"west":Vector2i(0,size_cells.y / 2),"east":Vector2i(size_cells.x - 1,size_cells.y / 2)}

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)
		return
	# Played on its own with F6: start a test run in this room.
	if get_tree().current_scene == self:
		MapPlaytest.start.call_deferred(get_tree(),scene_file_path)

func _process(delta: float) -> void:
	if not Engine.is_editor_hint(): return
	_warning_timer -= delta
	if _warning_timer <= 0.0:
		_warning_timer = 1.5
		update_configuration_warnings()
		queue_redraw()

func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray(MapLibrary.problems(self))

func _draw() -> void:
	if not Engine.is_editor_hint(): return
	var area := Rect2(Vector2.ZERO,Vector2(size_cells * CELL))
	for x in range(1,size_cells.x): draw_line(Vector2(x * CELL,0),Vector2(x * CELL,area.size.y),Color(1,1,1,0.06))
	for y in range(1,size_cells.y): draw_line(Vector2(0,y * CELL),Vector2(area.size.x,y * CELL),Color(1,1,1,0.06))
	draw_rect(area,Color("#f0c552"),false,3.0)
	var font := ThemeDB.fallback_font
	var doors := door_cells()
	for direction in doors:
		var cell: Vector2i = doors[direction]
		var box := Rect2(Vector2(cell * CELL),Vector2(CELL,CELL))
		draw_rect(box,Color(0.3,1.0,0.5,0.25))
		draw_rect(box,Color(0.3,1.0,0.5,0.9),false,2.0)
		draw_string(font,box.position + Vector2(0,30),String(direction)[0].to_upper(),HORIZONTAL_ALIGNMENT_CENTER,CELL,18,Color.WHITE)
	draw_string(font,Vector2(0,-12),"%s  ·  %s  ·  %dx%d" % [room_name,", ".join(role_list()),size_cells.x,size_cells.y],HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("#f0c552"))
