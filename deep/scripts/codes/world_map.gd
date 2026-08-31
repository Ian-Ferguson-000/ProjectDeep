class_name StarterWorld
extends Node2D

## Names the generated map, builds boundaries, and requests drawing.
func _ready() -> void:
	name = "StarterMap"
	_build_boundaries()
	queue_redraw()

## Creates outer walls and several hard-coded obstacle rectangles.
func _build_boundaries() -> void:
	_add_wall(Vector2(640, 16), Vector2(1280, 32))
	_add_wall(Vector2(16, 448), Vector2(32, 896))
	_add_wall(Vector2(1264, 448), Vector2(32, 896))
	_add_wall(Vector2(430, 880), Vector2(860, 32))
	_add_wall(Vector2(1110, 880), Vector2(308, 32))
	# Grove, creek, and building obstacles leave broad natural paths.
	for item in [[Vector2(185,300),Vector2(170,55)],[Vector2(1050,330),Vector2(250,46)],
		[Vector2(420,550),Vector2(150,72)],[Vector2(850,560),Vector2(170,72)]]:
		_add_wall(item[0], item[1])

## Adds a rectangular StaticBody2D collision at a supplied center/size.
func _add_wall(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new(); body.position = pos; body.collision_layer = 1
	var shape := CollisionShape2D.new(); var rect := RectangleShape2D.new(); rect.size = size
	shape.shape = rect; body.add_child(shape); add_child(body)

## Draws the old terrain, zones, landmarks, creek, and placeholder props.
func _draw() -> void:
	draw_rect(Rect2(0,0,1280,896), Color("#4f7942"))
	# Paths and five readable zones.
	draw_colored_polygon(PackedVector2Array([Vector2(540,896),Vector2(740,896),Vector2(730,620),Vector2(840,430),Vector2(770,310),Vector2(700,0),Vector2(580,0),Vector2(520,330),Vector2(430,470),Vector2(540,620)]), Color("#c4a66a"))
	draw_circle(Vector2(640,540), 230, Color("#79a85c"))
	draw_circle(Vector2(250,390), 170, Color("#35643b"))
	draw_circle(Vector2(1040,410), 175, Color("#557e58"))
	draw_circle(Vector2(640,145), 175, Color("#394d37"))
	# Creek.
	draw_colored_polygon(PackedVector2Array([Vector2(950,260),Vector2(1010,270),Vector2(1130,520),Vector2(1080,560)]), Color("#4d9fb3"))
	# Village houses and workbench landmark.
	for rect in [Rect2(330,500,150,90),Rect2(800,510,170,95)]:
		draw_rect(rect, Color("#855b3f")); draw_rect(Rect2(rect.position+Vector2(10,10),rect.size-Vector2(20,20)),Color("#bd8b57"))
	# Trees/rocks as visual counterparts to colliders.
	for p in [Vector2(185,300),Vector2(420,550),Vector2(850,560)]: draw_circle(p,42,Color("#214b31"))
	draw_rect(Rect2(925,307,250,46),Color("#52605d"))
	# Zone labels keep placeholder layout legible.
	_draw_label(Vector2(570,850),"SOUTHERN ARRIVAL")
	_draw_label(Vector2(555,700),"VILLAGE CLEARING")
	_draw_label(Vector2(120,220),"WESTERN GROVE")
	_draw_label(Vector2(930,225),"EASTERN CREEK")
	_draw_label(Vector2(535,55),"CORRUPTED GLADE")

## Draws a fallback map-zone label using the fallback font.
func _draw_label(pos: Vector2, text: String) -> void:
	draw_string(ThemeDB.fallback_font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(1,1,1,0.72))
