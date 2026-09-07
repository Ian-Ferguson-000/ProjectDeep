extends RefCounted
class_name SlasherCryptArt

const STONE:=preload("res://assets/pixel_art/TX Tileset Stone Ground.png")

static func make_ground_sprite(cell:Vector2i,tile_size:int)->Sprite2D:
	# The lower half of the source sheet contains transition/mask material rather
	# than repeatable floor. Restrict procedural floors to its two complete stones.
	var regions:=[Rect2(1,1,92,92),Rect2(162,1,92,92)]
	var atlas:=AtlasTexture.new();atlas.atlas=STONE;atlas.region=regions[absi(cell.x*17+cell.y*31)%regions.size()]
	var sprite:=Sprite2D.new();sprite.texture=atlas;sprite.scale=Vector2.ONE*float(tile_size+1)/92.0;sprite.modulate=Color("#777582") if (cell.x+cell.y)%5 else Color("#686674");return sprite

static func make_decoration(kind:String)->Node2D:
	var decor:=CryptDecoration.new();decor.kind=kind;return decor

class CryptDecoration:
	extends Node2D
	var kind:="bone_pile"
	func _ready()->void:z_index=1;queue_redraw()
	func _draw()->void:
		match kind:
			"pillar":
				draw_rect(Rect2(-13,-36,26,50),Color("#34343d"));draw_rect(Rect2(-17,-39,34,8),Color("#777682"));draw_rect(Rect2(-18,10,36,8),Color("#22232a"));draw_line(Vector2(-7,-29),Vector2(-7,8),Color("#555560"),3)
			"coffin","tomb":
				var points:=PackedVector2Array([Vector2(-17,-26),Vector2(17,-26),Vector2(22,-16),Vector2(18,25),Vector2(-18,25),Vector2(-22,-16)]);draw_colored_polygon(points,Color("#35333d"));draw_polyline(PackedVector2Array(Array(points)+[points[0]]),Color("#85818e"),3);draw_line(Vector2(0,-14),Vector2(0,15),Color("#635d70"),3);draw_line(Vector2(-8,-3),Vector2(8,-3),Color("#635d70"),3)
			"grave":
				draw_rect(Rect2(-16,-23,32,38),Color("#41414a"));draw_arc(Vector2(0,-22),16,PI,TAU,18,Color("#888692"),4);draw_line(Vector2(-9,-4),Vector2(9,-4),Color("#74717e"),2)
			"candles":
				for offset:Vector2 in [Vector2(-8,4),Vector2(0,0),Vector2(8,5)]:draw_rect(Rect2(offset+Vector2(-2,-10),Vector2(4,12)),Color("#ddd0a8"));draw_circle(offset+Vector2(0,-12),3,Color("#9cf4ff"))
			"rubble":
				for offset:Vector2 in [Vector2(-12,3),Vector2(-4,-5),Vector2(7,4),Vector2(14,-2)]:draw_circle(offset,5,Color("#55535e"));draw_arc(offset,5,0,TAU,10,Color("#292a31"),2)
			_:
				draw_line(Vector2(-15,4),Vector2(15,-3),Color("#d4cbbb"),4);draw_circle(Vector2(-14,4),5,Color("#c1b7a5"));draw_line(Vector2(-4,-8),Vector2(12,8),Color("#a9a18f"),3)
