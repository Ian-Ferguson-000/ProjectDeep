extends RefCounted
class_name SlasherForestArt

const VERDANT:=preload("res://assets/slasher/forest/verdant_tileset.png")
const CAMPFIRE:=preload("res://assets/pixel_art/Campfire.png")
const EXIT:=preload("res://assets/generated_ui/wooden_exit_door.png")
const MERCHANT:=preload("res://assets/merchants/forest_thistle.png")
const GOLD:=preload("res://assets/pixel_art/Gold.png")
const POTION:=preload("res://assets/pixel_art/potion.png")
const KEY:=preload("res://assets/pixel_art/key.png")

const VERDANT_GROUND_REGIONS=[
	Rect2(14,14,97,97),Rect2(131,14,97,97),Rect2(246,14,97,97),
	Rect2(361,14,97,97),Rect2(476,14,97,97),Rect2(592,14,97,97),Rect2(707,14,97,97)
]
const VERDANT_DETAIL_REGIONS=[
	Rect2(14,130,97,93),Rect2(131,130,97,93),Rect2(246,130,97,93),Rect2(361,130,97,93),
	Rect2(476,130,97,93),Rect2(592,130,97,93),Rect2(707,130,97,93),
	Rect2(14,245,97,93),Rect2(131,245,97,93),Rect2(246,245,97,93),Rect2(361,245,97,93)
]

static func ground_texture(cell:Vector2i)->Texture2D:
	return ground_base_texture(cell)

static func ground_base_texture(_cell:Vector2i)->Texture2D:
	var region:Rect2=Rect2(VERDANT_GROUND_REGIONS[0])
	return _texture_region(VERDANT,region)

static func ground_detail_texture(cell:Vector2i)->Texture2D:
	var index:int=absi(cell.x*17+cell.y*23)%VERDANT_DETAIL_REGIONS.size()
	var region:Rect2=Rect2(VERDANT_DETAIL_REGIONS[index])
	return _texture_region(VERDANT,region)

static func make_boundary_sprite(direction:Vector2i,variant:int)->Sprite2D:
	var sprite:=Sprite2D.new();sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	if direction.x!=0:
		var side_regions:Array[Rect2]=[]
		side_regions.append(Rect2(20,594,36,110));side_regions.append(Rect2(279,595,36,110));side_regions.append(Rect2(357,607,32,99))
		_atlas_scaled(sprite,VERDANT,side_regions[absi(variant)%side_regions.size()],Vector2(0.50,0.46),Vector2(0,-12))
	else:
		var wall_regions:Array[Rect2]=[]
		wall_regions.append(Rect2(57,620,84,68));wall_regions.append(Rect2(190,620,88,68));wall_regions.append(Rect2(390,622,70,68));wall_regions.append(Rect2(546,622,92,68));wall_regions.append(Rect2(701,620,96,68))
		_atlas_scaled(sprite,VERDANT,wall_regions[absi(variant)%wall_regions.size()],Vector2(0.59,0.60),Vector2(0,-25 if direction.y<0 else -7))
	return sprite

static func make_corner_pillar(variant:int)->Sprite2D:
	var sprite:=Sprite2D.new();sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	var regions:Array[Rect2]=[];regions.append(Rect2(873,748,67,118));regions.append(Rect2(967,746,69,122));regions.append(Rect2(1060,746,68,122));regions.append(Rect2(1150,744,77,126))
	_atlas(sprite,VERDANT,regions[absi(variant)%regions.size()],0.36,Vector2(0,-30));return sprite

static func make_sprite(kind:String)->Sprite2D:
	var sprite:=Sprite2D.new();sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	match kind:
		"tree_large":_atlas(sprite,VERDANT,Rect2(27,905,88,128),0.60,Vector2(0,-26))
		"tree_wide":_atlas(sprite,VERDANT,Rect2(124,912,94,99),0.68,Vector2(0,-16))
		"tree_small":_atlas(sprite,VERDANT,Rect2(27,905,88,128),0.48,Vector2(0,-20))
		"low_bush_a":_atlas(sprite,VERDANT,Rect2(124,912,94,99),0.38,Vector2(0,8))
		"low_bush_b":_atlas(sprite,VERDANT,Rect2(1090,1078,45,34),0.72,Vector2(0,8))
		"rounded_bush":_atlas(sprite,VERDANT,Rect2(1170,1074,63,39),0.70,Vector2(0,8))
		"grass_tuft_a":_atlas(sprite,VERDANT,Rect2(234,906,84,111),0.42,Vector2(0,8))
		"grass_tuft_b":_atlas(sprite,VERDANT,Rect2(330,914,65,93),0.43,Vector2(0,8))
		"grass_tuft_c":_atlas(sprite,VERDANT,Rect2(330,1155,68,54),0.44,Vector2(0,8))
		"mossy_rock":_atlas(sprite,VERDANT,Rect2(796,1071,53,45),0.62,Vector2(0,7))
		"rock":_atlas(sprite,VERDANT,Rect2(521,903,89,113),0.48,Vector2(0,-8))
		"barrel":_atlas(sprite,VERDANT,Rect2(835,918,80,94),0.55,Vector2(0,-10))
		"chest":_atlas(sprite,VERDANT,Rect2(1127,918,104,87),0.50,Vector2(0,-10))
		"campfire":sprite.texture=CAMPFIRE;sprite.scale=Vector2.ONE*0.07
		"exit":sprite.texture=EXIT;_fit_to_pixels(sprite,58.0)
		"merchant":sprite.texture=MERCHANT;_fit_to_pixels(sprite,74.0)
		"gold":sprite.texture=GOLD;_fit_to_pixels(sprite,30.0)
		"potion":sprite.texture=POTION;_fit_to_pixels(sprite,32.0)
		"key":sprite.texture=KEY;_fit_to_pixels(sprite,26.0)
	return sprite

static func _atlas(sprite:Sprite2D,texture:Texture2D,region:Rect2,scale_value:float,offset:Vector2)->void:
	sprite.texture=_texture_region(texture,region);sprite.scale=Vector2.ONE*scale_value;sprite.offset=offset

static func _atlas_scaled(sprite:Sprite2D,texture:Texture2D,region:Rect2,scale_value:Vector2,offset:Vector2)->void:
	sprite.texture=_texture_region(texture,region);sprite.scale=scale_value;sprite.offset=offset

static func _fit_to_pixels(sprite:Sprite2D,target_maximum:float)->void:
	if sprite.texture==null:return
	var source_maximum:float=maxf(float(sprite.texture.get_width()),float(sprite.texture.get_height()))
	sprite.scale=Vector2.ONE*(target_maximum/source_maximum)

static func _texture_region(texture:Texture2D,region:Rect2)->AtlasTexture:
	var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.region=region;return atlas
