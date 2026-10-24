extends RefCounted
class_name ForestCreatureArt

## Builds SpriteFrames for the forest's Sporelings (shroomie sheets) and bandits
## (Kobold sheets) at runtime. Animations follow the enemy naming used by
## SlasherSpriteLibrary: idle_<dir>, run_<dir>, attack_<dir>, plus "dormant" and
## "wake" for Sporelings.

const SHROOMIE_WALK := "res://assets/pixel_art/shroomie.png"
const SHROOMIE_WAKE := "res://assets/pixel_art/shroomie - wakeup.png"
const KOBOLD_ROOT := "res://assets/sprite_packs/Kobold/Sprites/with_outline/"
const DIRECTIONS := ["down","left","right","up"]
## Enemy id -> which sheet it is drawn from.
const CREATURES := {"sporeling":"sporeling","bandit_cutthroat":"kobold","bandit_knifethrower":"kobold"}
## Kobold frames are 148x96 with the body centred near x=52; frames are re-centred
## on a wider canvas so a mirrored copy lines up.
const KOBOLD_FRAME := Vector2i(148,96)
const KOBOLD_BODY_X := 52
const KOBOLD_CANVAS := Vector2i(200,96)
const KOBOLD_FEET_Y := 91

static var _cache: Dictionary = {}

static func frames_for(art_id: String) -> SpriteFrames:
	if _cache.has(art_id): return _cache[art_id]
	var frames: SpriteFrames = null
	match art_id:
		"sporeling": frames = _sporeling()
		"kobold": frames = _kobold()
	if frames != null: _cache[art_id] = frames
	return frames

## Vertical offset that stands the sprite's feet on the enemy's position.
static func feet_offset(art_id: String, scale: float) -> float:
	match art_id:
		"sporeling": return -(30.0 - 16.0) * scale
		"kobold": return -(KOBOLD_FEET_Y - KOBOLD_CANVAS.y * 0.5) * scale
	return -18.0

static func _sporeling() -> SpriteFrames:
	var walk := load(SHROOMIE_WALK) as Texture2D
	var wake := load(SHROOMIE_WAKE) as Texture2D
	if walk == null or wake == null: return null
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row in DIRECTIONS.size():
		var direction: String = DIRECTIONS[row]
		_add(frames,"idle_" + direction,5.0,true,[_atlas(walk,Rect2(0,row * 32,32,32)),_atlas(walk,Rect2(64,row * 32,32,32))])
		var cells: Array[Texture2D] = []
		for column in 4: cells.append(_atlas(walk,Rect2(column * 32,row * 32,32,32)))
		_add(frames,"run_" + direction,11.0,true,cells)
		_add(frames,"attack_" + direction,16.0,false,cells)
	var dormant: Array[Texture2D] = []
	for column in 4: dormant.append(_atlas(wake,Rect2(column * 32,0,32,32)))
	_add(frames,"dormant",3.0,true,dormant)
	var waking: Array[Texture2D] = []
	for row in [1,2]:
		for column in 4: waking.append(_atlas(wake,Rect2(column * 32,row * 32,32,32)))
	_add(frames,"wake",12.0,false,waking)
	return frames

static func _kobold() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for spec in [["idle","IDLE.png",6,8.0,true],["run","RUN.png",8,12.0,true],["attack","ATTACK 1.png",5,14.0,false]]:
		var texture := load(KOBOLD_ROOT + String(spec[1])) as Texture2D
		if texture == null: return null
		var sheet := texture.get_image()
		var right: Array[Texture2D] = []
		var left: Array[Texture2D] = []
		for index in int(spec[2]):
			var canvas := Image.create_empty(KOBOLD_CANVAS.x,KOBOLD_CANVAS.y,false,Image.FORMAT_RGBA8)
			canvas.blit_rect(sheet,Rect2i(index * KOBOLD_FRAME.x,0,KOBOLD_FRAME.x,KOBOLD_FRAME.y),Vector2i(KOBOLD_CANVAS.x / 2 - KOBOLD_BODY_X,0))
			right.append(ImageTexture.create_from_image(canvas))
			var mirrored := canvas.duplicate() as Image
			mirrored.flip_x()
			left.append(ImageTexture.create_from_image(mirrored))
		# Side-view art: facing down reads as right, facing up as left.
		_add(frames,"%s_right" % spec[0],float(spec[3]),bool(spec[4]),right)
		_add(frames,"%s_down" % spec[0],float(spec[3]),bool(spec[4]),right)
		_add(frames,"%s_left" % spec[0],float(spec[3]),bool(spec[4]),left)
		_add(frames,"%s_up" % spec[0],float(spec[3]),bool(spec[4]),left)
	return frames

static func _atlas(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return atlas

static func _add(frames: SpriteFrames, animation: String, fps: float, loop: bool, textures: Array) -> void:
	frames.add_animation(animation)
	frames.set_animation_speed(animation,fps)
	frames.set_animation_loop(animation,loop)
	for texture in textures: frames.add_frame(animation,texture)
