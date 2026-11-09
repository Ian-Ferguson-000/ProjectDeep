extends RefCounted
class_name PlaceholderArt

## Stand-in art for characters that haven't been drawn yet: a dark silhouette
## (head and shoulders, or a full standing figure) with a rim in the
## character's accent colour and a question mark, so it's obvious in game
## where art is still needed. Used by visitors of merit (data/visitors.json):
## set art.portrait / art.sprite to real files and these stop being used.

static var _cache: Dictionary = {}

## A 3x5 pixel "?" mark.
const QUESTION := [".X.","X.X","..X",".X.","...",".X."]

## A head-and-shoulders portrait silhouette.
static func portrait(accent: Color, size: Vector2i = Vector2i(120,150)) -> ImageTexture:
	var key := "portrait:%s:%s" % [accent.to_html(),size]
	if _cache.has(key): return _cache[key]
	var image := Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
	# A warm lit backdrop so the dark figure reads clearly against it.
	for y in size.y:
		var glow := Color("4a3626").lerp(Color("231910"),float(y) / size.y)
		for x in size.x: image.set_pixel(x,y,glow.lerp(Color("231910"),clampf(absf(x - size.x * 0.5) / (size.x * 0.6),0.0,1.0)))
	var body := Color("0b0806"); var rim := accent.darkened(0.25)
	var cx := size.x * 0.5
	var head_r := size.x * 0.2
	var head_c := Vector2(cx,size.y * 0.36)
	for y in size.y:
		for x in size.x:
			var p := Vector2(x,y)
			var inside := p.distance_to(head_c) <= head_r
			# Shoulders: a wide rounded trapezoid under the head.
			var shoulder_top := size.y * 0.6
			if y >= shoulder_top:
				var t := (y - shoulder_top) / (size.y - shoulder_top)
				var half := size.x * (0.26 + 0.2 * sqrt(t))
				if absf(x - cx) <= half: inside = true
			# Neck.
			if y > head_c.y + head_r * 0.6 and y < shoulder_top + 2 and absf(x - cx) < head_r * 0.45: inside = true
			if inside: image.set_pixel(x,y,body)
	_rim(image,body,rim)
	_question(image,Vector2i(int(cx),int(head_c.y)),int(size.x / 22.0),accent.lightened(0.15))
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

## A full standing figure for the tavern floor (transparent background).
static func figure(accent: Color, size: Vector2i = Vector2i(44,74)) -> ImageTexture:
	var key := "figure:%s:%s" % [accent.to_html(),size]
	if _cache.has(key): return _cache[key]
	var image := Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
	image.fill(Color(0,0,0,0))
	var body := Color("140f0b"); var rim := accent.darkened(0.1)
	var cx := size.x * 0.5
	var head_c := Vector2(cx,size.y * 0.15); var head_r := size.x * 0.17
	for y in size.y:
		for x in size.x:
			var inside := Vector2(x,y).distance_to(head_c) <= head_r
			var top := size.y * 0.27
			if y >= top:
				# A cloaked body: widening to the hem.
				var t := (y - top) / (size.y - top)
				if absf(x - cx) <= size.x * (0.22 + 0.2 * t): inside = true
			if inside: image.set_pixel(x,y,body)
	_rim(image,body,rim)
	_question(image,Vector2i(int(cx),int(size.y * 0.5)),2,accent.lightened(0.2))
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

## SpriteFrames for a TavernActor: the standing figure for every animation.
static func figure_frames(accent: Color) -> SpriteFrames:
	var key := "frames:%s" % accent.to_html()
	if _cache.has(key): return _cache[key]
	var texture := figure(accent)
	var frames := SpriteFrames.new(); frames.remove_animation("default")
	for direction in SlasherSpriteLibrary.DIRECTIONS:
		for state in ["idle","run","attack"]:
			var animation := StringName("%s_%s" % [state,direction])
			frames.add_animation(animation); frames.set_animation_loop(animation,state != "attack"); frames.set_animation_speed(animation,4.0)
			frames.add_frame(animation,texture)
	_cache[key] = frames
	return frames

## Outlines the silhouette's edge in the rim colour.
static func _rim(image: Image, body: Color, rim: Color) -> void:
	var edges: Array[Vector2i] = []
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y) != body: continue
			for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var n: Vector2i = Vector2i(x,y) + offset
				if n.x < 0 or n.y < 0 or n.x >= image.get_width() or n.y >= image.get_height() or image.get_pixelv(n) != body:
					edges.append(Vector2i(x,y)); break
	for p in edges: image.set_pixelv(p,rim)

static func _question(image: Image, centre: Vector2i, scale_value: int, colour: Color) -> void:
	var s := maxi(1,scale_value)
	var origin := centre - Vector2i(int(1.5 * s),3 * s)
	for row in QUESTION.size():
		for col in 3:
			if String(QUESTION[row])[col] != "X": continue
			for dy in s:
				for dx in s:
					var p := origin + Vector2i(col * s + dx,row * s + dy)
					if p.x >= 0 and p.y >= 0 and p.x < image.get_width() and p.y < image.get_height(): image.set_pixelv(p,colour)

## A visitor's portrait: their art if it exists, otherwise the silhouette.
static func visitor_portrait(visitor: Dictionary) -> Texture2D:
	var path := String(Dictionary(visitor.get("art",{})).get("portrait",""))
	if not path.is_empty() and ResourceLoader.exists(path): return load(path)
	return portrait(Color("#" + String(visitor.get("accent","c9a36a"))))

## A visitor's tavern sprite frames: their art if it exists, otherwise the figure.
static func visitor_frames(visitor: Dictionary) -> SpriteFrames:
	var path := String(Dictionary(visitor.get("art",{})).get("sprite",""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var frames := SlasherSpriteLibrary.static_enemy_frames(path)
		if frames != null: return frames
	return figure_frames(Color("#" + String(visitor.get("accent","c9a36a"))))
