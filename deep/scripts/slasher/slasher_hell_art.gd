extends RefCounted
class_name SlasherHellArt

const FLOOR_A:=preload("res://assets/pixel_art/TX tileset Hellfloor.png")
const FLOOR_B:=preload("res://assets/pixel_art/TX tileset Hellfloor2.png")
const WALL:=preload("res://assets/pixel_art/TX tileset Hellwall.png")

static func make_ground_sprite(cell:Vector2i,tile_size:int)->Sprite2D:
	var source:Texture2D=FLOOR_A if (cell.x*7+cell.y*11)%5 else FLOOR_B
	# Both Hell sheets are large hand-painted atlases. These regions select stable,
	# seamless slabs rather than scaling the entire atlas into every floor cell.
	var regions:Array[Rect2]=[
		Rect2(34,34,184,184),Rect2(250,34,184,184),Rect2(466,34,184,184),
		Rect2(34,250,184,184),Rect2(250,250,184,184),Rect2(466,250,184,184)
	]
	var atlas:=AtlasTexture.new();atlas.atlas=source;atlas.region=regions[absi(cell.x*19+cell.y*37)%regions.size()]
	var sprite:=Sprite2D.new();sprite.texture=atlas;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;sprite.scale=Vector2.ONE*float(tile_size+1)/184.0
	sprite.modulate=Color("#d8a09a") if (cell.x+cell.y)%7 else Color("#efb18d")
	return sprite

static func make_wall_panel(variant:int)->Sprite2D:
	var regions:Array[Rect2]=[
		Rect2(382,70,360,365),Rect2(36,69,300,430),Rect2(36,574,430,217),
		Rect2(1031,180,225,330),Rect2(552,574,110,216)
	]
	var atlas:=AtlasTexture.new();atlas.atlas=WALL;atlas.region=regions[absi(variant)%regions.size()]
	var sprite:=Sprite2D.new();sprite.texture=atlas;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var max_side:=maxf(atlas.region.size.x,atlas.region.size.y);sprite.scale=Vector2.ONE*minf(1.0,92.0/max_side);sprite.modulate=Color("#e9a19a")
	return sprite

static func make_decoration(kind:String)->Node2D:
	var decor:=HellDecoration.new();decor.kind=kind;return decor

class HellDecoration:
	extends Node2D
	var kind:="brazier"
	func _ready()->void:z_index=1;queue_redraw()
	func _draw()->void:
		match kind:
			"brazier":
				draw_rect(Rect2(-12,4,24,9),Color("#3c1717"));draw_colored_polygon(PackedVector2Array([Vector2(-9,4),Vector2(-4,-15),Vector2(0,-7),Vector2(6,-21),Vector2(10,4)]),Color("#ff5b19"));draw_circle(Vector2(2,-5),6,Color("#ffd45d"))
			"skull":
				draw_circle(Vector2.ZERO,11,Color("#c8aa8b"));draw_circle(Vector2(-4,-2),2.5,Color("#261014"));draw_circle(Vector2(4,-2),2.5,Color("#261014"));draw_rect(Rect2(-7,7,14,7),Color("#9b806d"))
			"chain":
				for index:int in 5:draw_arc(Vector2(0,index*7-18),6,0,TAU,12,Color("#6e4038"),3)
			_:
				draw_colored_polygon(PackedVector2Array([Vector2(-13,10),Vector2(-7,-8),Vector2(0,-17),Vector2(8,-6),Vector2(14,10)]),Color("#4b1b1d"));draw_line(Vector2(-8,4),Vector2(8,-4),Color("#e34220"),3)
