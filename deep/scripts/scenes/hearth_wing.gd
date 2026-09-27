extends Node2D

signal station_requested(page: String)
@export var wing_title: String = "Lodging & Armory"
@export var station_page: String = "Armory"
@export var furnishing: Texture2D

func _ready() -> void:
	queue_redraw()
	var title := Label.new()
	title.position = Vector2(24,24)
	title.text = wing_title.to_upper()
	title.add_theme_font_size_override("font_size",22)
	title.add_theme_color_override("font_color",Color("e0b870"))
	add_child(title)
	var button := Button.new()
	button.position = Vector2(350,220)
	button.text = "Visit "+station_page
	TavernUITheme.apply_button(button,false,18,Vector2(210,48))
	button.pressed.connect(func(): station_requested.emit(station_page))
	add_child(button)
	if furnishing != null:
		for i in 3:
			var sprite := Sprite2D.new()
			sprite.texture = furnishing
			sprite.position = Vector2(110+i*175,145)
			var side := maxf(furnishing.get_width(),furnishing.get_height())
			sprite.scale = Vector2.ONE*(130.0/side)
			add_child(sprite)

func _draw() -> void:
	draw_rect(Rect2(0,0,620,300),Color("17110e"))
	var floor_texture: Texture2D=preload("res://assets/pixel_art/Tavern Floor Revised.png")
	for row in 9:
		for col in 19:
			draw_texture_rect_region(floor_texture,Rect2(8+col*32,8+row*32,32,32),Rect2(0,0,32,32))
	draw_rect(Rect2(4,4,612,292),Color("8c5a26"),false,8)
	draw_rect(Rect2(-70,112,82,70),Color("392819"))
	# Timber lintels and side posts echo the existing room's authored wall kit.
	var wall: Texture2D=preload("res://assets/tavern/wall_kit/wall_straight.png")
	for col in 5: draw_texture_rect(wall,Rect2(col*124,-25,124,72),false)
	var post: Texture2D=preload("res://assets/tavern/wall_kit/support_pillar.png")
	draw_texture_rect(post,Rect2(-8,-20,32,325),false)
	draw_texture_rect(post,Rect2(600,-20,32,325),false)
