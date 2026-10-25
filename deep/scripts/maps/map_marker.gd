@tool
extends Node2D
class_name MapMarker

## A thing placed in a room: enemy spawn, loot, merchant, chest, rock...
## Drop it under the room's "Markers" node and pick its kind in the Inspector.
## It snaps to the centre of a 48px cell. Markers are only guides: the game
## replaces them with the real thing when the room loads.

const CELL := 48.0
## Kind -> [map symbol, label, colour]. The symbol is the room's internal code.
const KINDS := {
	"enemy":["e","Enemy","#e05a4f"],
	"elite":["E","Elite/Boss","#ff9e3d"],
	"loot":["$","Loot","#f0c552"],
	"treasure":["*","Treasure","#e08af0"],
	"merchant":["M","Merchant","#6fd0a0"],
	"gate":["X","Gate down","#c6a0ff"],
	"player_start":["P","Start","#ffffff"],
	"campfire":["F","Campfire","#ff7a2e"],
	"chest":["C","Chest","#b8814a"],
	"rock":["R","Rock","#a9a9a9"],
	"big_tree":["T","Big tree","#4f8f45"],
	"mossy_rock":["r","Mossy rock","#8fb18a"],
	"pebbles":["p","Pebbles","#cfcfc4"],
	"mushrooms":["m","Mushrooms","#e86a7a"],
	"bush":["b","Bush","#6fa34f"],
}

@export_enum("enemy","elite","loot","treasure","merchant","gate","player_start","campfire","chest","rock","big_tree","mossy_rock","pebbles","mushrooms","bush")
var kind: String = "enemy":
	set(value):
		kind = value
		if Engine.is_editor_hint(): name = String(KINDS.get(kind,["?","Marker"])[1]).replace("/","").replace(" ","")
		queue_redraw()

var _snapping := false

func _ready() -> void:
	if Engine.is_editor_hint(): set_notify_transform(true)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and not _snapping:
		_snapping = true
		position = snapped_position(position)
		_snapping = false

static func snapped_position(point: Vector2) -> Vector2:
	return (Vector2(floor(point.x / CELL),floor(point.y / CELL)) + Vector2.ONE * 0.5) * CELL

func cell() -> Vector2i:
	return Vector2i(floori(position.x / CELL),floori(position.y / CELL))

func symbol() -> String:
	return String(KINDS.get(kind,["?"])[0])

func _draw() -> void:
	var info: Array = KINDS.get(kind,["?","?","#ffffff"])
	var colour := Color(String(info[2]))
	draw_circle(Vector2.ZERO,15.0,Color(0,0,0,0.55))
	draw_circle(Vector2.ZERO,12.0,colour)
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(-12,6),String(info[0]),HORIZONTAL_ALIGNMENT_CENTER,24,16,Color(0.08,0.06,0.05))
	draw_string_outline(font,Vector2(-40,30),String(info[1]),HORIZONTAL_ALIGNMENT_CENTER,80,11,4,Color(0,0,0,0.8))
	draw_string(font,Vector2(-40,30),String(info[1]),HORIZONTAL_ALIGNMENT_CENTER,80,11,colour.lightened(0.3))
