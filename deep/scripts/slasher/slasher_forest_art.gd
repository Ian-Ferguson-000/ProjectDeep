extends RefCounted
class_name SlasherForestArt

const TX_GRASS:=preload("res://assets/pixel_art/TX Tileset Grass.png")
const TX_PLANTS:=preload("res://assets/pixel_art/TX Plant.png")
const TX_PROPS:=preload("res://assets/pixel_art/TX Props.png")
const CAMPFIRE:=preload("res://assets/pixel_art/Campfire.png")
const MERCHANT:=preload("res://assets/merchants/forest_thistle.png")
const GOLD:=preload("res://assets/pixel_art/Gold.png")
const POTION:=preload("res://assets/pixel_art/potion.png")
const KEY:=preload("res://assets/pixel_art/key.png")

const TX_TILE_SIZE:=32
const TX_GROUND_VARIANTS:=3
const TX_PROP_REGIONS:Dictionary={
	"mossy_rock":Rect2(66,487,28,18),
	"rock":Rect2(2,429,61,55),
	"barrel":Rect2(162,153,31,55),
	"chest":Rect2(96,30,33,32),
	"chest_open":Rect2(96,78,33,68),
	"exit":Rect2(28,104,41,49),
	"crate":Rect2(161,17,31,31),
	"bench":Rect2(292,18,60,47),
	"pillar":Rect2(354,158,33,99),
	"well":Rect2(353,270,128,80),
	# Crypt props (same sheet).
	"coffin":Rect2(288,158,32,57),
	"sarcophagus":Rect2(288,87,64,36),
	"urn":Rect2(165,217,21,34),
	"urn_b":Rect2(165,348,21,32),
	"tombstone":Rect2(225,239,30,41),
	"grave_cross":Rect2(227,303,26,40),
	"grave_small":Rect2(289,251,30,29),
	"statue":Rect2(445,20,37,73),
	"pillar_broken":Rect2(416,194,32,57),
	"rubble":Rect2(289,486,31,19),
}
const TX_STRUCT:=preload("res://assets/pixel_art/TX Struct.png")
## Stone archway over the stairs down (crypt gate).
const STAIRS_ARCH:=Rect2(416,128,64,64)
static var _stairs_texture:Texture2D

static func ground_texture(_cell:Vector2i)->Texture2D:
	return TX_GRASS

static func make_ground_sprite(cell:Vector2i,cell_size:int=48)->Sprite2D:
	var sprite:=Sprite2D.new()
	sprite.texture=TX_GRASS
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.region_enabled=true
	var rng:=RandomNumberGenerator.new();rng.seed=cell.x*73856093^cell.y*19349663^83492791
	var variant:int=rng.randi_range(0,TX_GROUND_VARIANTS-1)
	sprite.region_rect=Rect2(variant*TX_TILE_SIZE,0,TX_TILE_SIZE,TX_TILE_SIZE)
	sprite.flip_h=rng.randi_range(0,1)==1;sprite.flip_v=rng.randi_range(0,1)==1
	sprite.scale=Vector2.ONE*(float(cell_size)/float(TX_TILE_SIZE))
	return sprite

static func ground_base_texture(_cell:Vector2i)->Texture2D:
	return TX_GRASS

static func make_sprite(kind:String)->Sprite2D:
	var sprite:=Sprite2D.new();sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	match kind:
		"tree_large":_atlas(sprite,TX_PLANTS,Rect2(23,16,105,138),0.36,Vector2(0,-14))
		"tree_wide":_atlas(sprite,TX_PLANTS,Rect2(161,18,83,137),0.34,Vector2(0,-13))
		"tree_small":_atlas(sprite,TX_PLANTS,Rect2(295,30,74,122),0.36,Vector2(0,-12))
		"low_bush_a":_atlas(sprite,TX_PLANTS,Rect2(96,196,32,29),0.72,Vector2(0,7))
		"low_bush_b":_atlas(sprite,TX_PLANTS,Rect2(155,187,41,38),0.64,Vector2(0,7))
		"rounded_bush":_atlas(sprite,TX_PLANTS,Rect2(216,184,49,42),0.58,Vector2(0,7))
		"grass_tuft_a":_atlas(sprite,TX_PLANTS,Rect2(8,337,15,15),1.18,Vector2(0,8))
		"grass_tuft_b":_atlas(sprite,TX_PLANTS,Rect2(28,337,16,15),1.12,Vector2(0,8))
		"grass_tuft_c":_atlas(sprite,TX_PLANTS,Rect2(47,337,17,15),1.12,Vector2(0,8))
		"mossy_rock":_atlas(sprite,TX_PROPS,TX_PROP_REGIONS.mossy_rock,1.0,Vector2(0,7))
		"rock":_atlas(sprite,TX_PROPS,TX_PROP_REGIONS.rock,0.72,Vector2(0,-7))
		"barrel":_atlas(sprite,TX_PROPS,TX_PROP_REGIONS.barrel,0.82,Vector2(0,-9))
		"chest":_atlas(sprite,TX_PROPS,TX_PROP_REGIONS.chest,1.25,Vector2(0,-8))
		"chest_open":_atlas(sprite,TX_PROPS,TX_PROP_REGIONS.chest_open,1.25,Vector2(0,-24))
		"campfire":sprite.texture=CAMPFIRE;sprite.scale=Vector2.ONE*0.07
		"exit":_atlas(sprite,TX_PROPS,TX_PROP_REGIONS.exit,1.18,Vector2(0,-8))
		"crate":_atlas(sprite,TX_PROPS,TX_PROP_REGIONS.crate,1.25,Vector2(0,-8))
		"bench":_atlas(sprite,TX_PROPS,TX_PROP_REGIONS.bench,0.9,Vector2(0,-8))
		"pillar":_atlas(sprite,TX_PROPS,TX_PROP_REGIONS.pillar,0.55,Vector2(0,-18))
		"well":_atlas(sprite,TX_PROPS,TX_PROP_REGIONS.well,0.55,Vector2(0,-12))
		"coffin":_atlas(sprite,TX_PROPS,TX_PROP_REGIONS.coffin,0.82,Vector2(0,-14))
		"sarcophagus":_atlas(sprite,TX_PROPS,TX_PROP_REGIONS.sarcophagus,0.78,Vector2(0,-6))
		"urn":_atlas(sprite,TX_PROPS,TX_PROP_REGIONS.urn,0.85,Vector2(0,-6))
		"urn_b":_atlas(sprite,TX_PROPS,TX_PROP_REGIONS.urn_b,0.85,Vector2(0,-6))
		"tombstone":_atlas(sprite,TX_PROPS,TX_PROP_REGIONS.tombstone,0.78,Vector2(0,-8))
		"grave_cross":_atlas(sprite,TX_PROPS,TX_PROP_REGIONS.grave_cross,0.78,Vector2(0,-8))
		"grave_small":_atlas(sprite,TX_PROPS,TX_PROP_REGIONS.grave_small,0.8,Vector2(0,-4))
		"statue":_atlas(sprite,TX_PROPS,TX_PROP_REGIONS.statue,0.75,Vector2(0,-26))
		"pillar_broken":_atlas(sprite,TX_PROPS,TX_PROP_REGIONS.pillar_broken,0.7,Vector2(0,-18))
		"rubble":_atlas(sprite,TX_PROPS,TX_PROP_REGIONS.rubble,0.95,Vector2(0,4))
		"stairs_down":sprite.texture=_stairs();sprite.scale=Vector2.ONE*1.1;sprite.offset=Vector2(0,-18)
		"merchant":sprite.texture=MERCHANT;_fit_to_pixels(sprite,74.0)
		"gold":sprite.texture=GOLD;_fit_to_pixels(sprite,30.0)
		"potion":sprite.texture=POTION;_fit_to_pixels(sprite,32.0)
		"key":sprite.texture=KEY;_fit_to_pixels(sprite,26.0)
	return sprite

## An archway with dark steps going down inside it, built once from TX Struct.
static func _stairs()->Texture2D:
	if _stairs_texture!=null:return _stairs_texture
	var arch:=TX_STRUCT.get_image().get_region(Rect2i(STAIRS_ARCH))
	arch.convert(Image.FORMAT_RGBA8)
	var image:=Image.create_empty(64,64,false,Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(12,18,40,46),Color("#0b0812"))
	for step in 5:
		var y:=24+step*8;var inset:=step*3
		image.fill_rect(Rect2i(14+inset,y,36-inset*2,3),Color(0.32,0.29,0.36).darkened(step*0.15))
	image.blend_rect(arch,Rect2i(0,0,64,64),Vector2i.ZERO)
	_stairs_texture=ImageTexture.create_from_image(image)
	return _stairs_texture

static func _atlas(sprite:Sprite2D,texture:Texture2D,region:Rect2,scale_value:float,offset:Vector2)->void:
	sprite.texture=_texture_region(texture,region);sprite.scale=Vector2.ONE*scale_value;sprite.offset=offset

static func _fit_to_pixels(sprite:Sprite2D,target_maximum:float)->void:
	if sprite.texture==null:return
	var source_maximum:float=maxf(float(sprite.texture.get_width()),float(sprite.texture.get_height()))
	sprite.scale=Vector2.ONE*(target_maximum/source_maximum)

static func _texture_region(texture:Texture2D,region:Rect2)->AtlasTexture:
	var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.region=region;return atlas
