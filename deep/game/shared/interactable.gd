class_name WorldInteractable
extends Node2D

enum Kind { NPC, PICKUP, WORKBENCH, EXIT }
@export var kind := Kind.NPC
@export var item_id := ""
@export var display_name := "Interact"
@export var color := Color.WHITE
@export var draw_placeholder := true
var consumed := false

## Adds the node to interactable and queues placeholder drawing.
func _ready() -> void:
	add_to_group("interactable")
	queue_redraw()

## Runtime builder that assigns fields and returns self. Scene-authored nodes normally use exported properties
## instead.
func configure(p_kind: Kind, p_name: String, p_color: Color, p_item := "") -> WorldInteractable:
	kind=p_kind; display_name=p_name; color=p_color; item_id=p_item
	queue_redraw(); return self

## Returns context-sensitive prompt text, including the locked northern-exit message before objective
## completion.
func prompt() -> String:
	if kind == Kind.EXIT and GameState.objective_stage < 4: return "Northern path sealed by corruption"
	return "[E] " + display_name

## Executes behavior by kind: advances tutorial, awards/consumes pickups, provides workbench guidance, or
## reports exit state. Returns text for the HUD message area.
func interact(_actor: Node) -> String:
	if consumed: return ""
	match kind:
		Kind.NPC:
			GameState.mark_tutorial_seen(); return "Mira: Two resonant materials can shape a cleansing rune. Search west and east."
		Kind.PICKUP:
			GameState.add_item(item_id); consumed=true; visible=false
			return "Collected " + display_name + "."
		Kind.WORKBENCH:
			return "The rune bench hums. Press [R] to enter your Soul Space."
		Kind.EXIT:
			return "The road beyond is ready for a future map." if GameState.objective_stage >= 4 else "The corruption seals this road."
	return ""

## Draws kind-specific fallback visuals when enabled; imported pixel-art instances set draw_placeholder=false.
func _draw() -> void:
	if not draw_placeholder: return
	if kind == Kind.NPC:
		draw_circle(Vector2.ZERO,22,color); draw_circle(Vector2(0,-8),8,Color("#f4d3a1"))
	elif kind == Kind.WORKBENCH:
		draw_rect(Rect2(-28,-16,56,32),color); draw_line(Vector2(-20,16),Vector2(-20,30),color,5); draw_line(Vector2(20,16),Vector2(20,30),color,5)
	elif kind == Kind.EXIT:
		draw_rect(Rect2(-65,-10,130,20),color); draw_string(ThemeDB.fallback_font,Vector2(-52,-18),"NORTH ROAD",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
	else:
		var pts := PackedVector2Array([Vector2(0,-20),Vector2(16,0),Vector2(0,20),Vector2(-16,0)])
		draw_colored_polygon(pts,color); draw_polyline(PackedVector2Array([pts[0],pts[1],pts[2],pts[3],pts[0]]),Color.WHITE,2)
