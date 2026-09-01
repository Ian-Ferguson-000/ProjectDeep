extends RefCounted
class_name SlasherSpriteLibrary

const NORMALIZED_FRAME_SIZE := Vector2(96,80)
const DIRECTIONS := ["down","left","right","up"]
static var _generated_cache: Dictionary = {}

static func player_frames(class_id: String) -> SpriteFrames:
	if class_id == "warrior":
		return load("res://assets/sprite_packs/Player/player_frames.tres") as SpriteFrames
	return animation_board_frames("res://assets/classes/%s/slasher_sheet.png" % class_id)

static func companion_frames() -> SpriteFrames:
	return normalized_sheet_frames("res://assets/classes/wolf_companion/sheet.png")

static func enemy_frames(enemy_id: String) -> SpriteFrames:
	var generated_path:="res://assets/enemies/%s/generated_source.png"%enemy_id
	if ResourceLoader.exists(generated_path):return generated_enemy_frames(generated_path)
	if enemy_id.begins_with("wolf_"):
		enemy_id="feral_wolf"
	var path := "res://assets/enemies/%s/frames.tres" % enemy_id
	return load(path) as SpriteFrames if ResourceLoader.exists(path) else null

static func generated_enemy_frames(path:String)->SpriteFrames:
	if _generated_cache.has(path):return _generated_cache[path] as SpriteFrames
	var texture:=load(path) as Texture2D
	if texture==null:return null
	var source:=texture.get_image();var frames:=SpriteFrames.new();frames.remove_animation("default")
	for row:int in DIRECTIONS.size():
		for state_index:int in 3:
			var animation:=StringName("%s_%s"%[["idle","run","attack"][state_index],DIRECTIONS[row]])
			frames.add_animation(animation);frames.set_animation_loop(animation,state_index<2);frames.set_animation_speed(animation,6.0 if state_index==0 else 10.0)
			for offset:int in 2:
				var column:int=state_index*2+offset;var left:=roundi(float(column)*source.get_width()/6.0);var right:=roundi(float(column+1)*source.get_width()/6.0);var top:=roundi(float(row)*source.get_height()/4.0);var bottom:=roundi(float(row+1)*source.get_height()/4.0)
				var cell:=source.get_region(Rect2i(left,top,right-left,bottom-top));_remove_generated_background(cell)
				var bounds:=_alpha_bounds(cell);var isolated:=cell.get_region(bounds);var scale_factor:=minf(88.0/isolated.get_width(),74.0/isolated.get_height());isolated.resize(maxi(1,roundi(isolated.get_width()*scale_factor)),maxi(1,roundi(isolated.get_height()*scale_factor)),Image.INTERPOLATE_NEAREST)
				var canvas:=Image.create(96,80,false,Image.FORMAT_RGBA8);canvas.fill(Color.TRANSPARENT);canvas.blit_rect(isolated,Rect2i(Vector2i.ZERO,isolated.get_size()),Vector2i((96-isolated.get_width())/2,80-isolated.get_height()));frames.add_frame(animation,ImageTexture.create_from_image(canvas))
	_generated_cache[path]=frames;return frames

static func _remove_generated_background(image:Image)->void:
	image.convert(Image.FORMAT_RGBA8)
	var corner:=image.get_pixel(0,0)
	if corner.a<0.1:return
	if corner.get_luminance()<0.55:_remove_connected_background(image);return
	for y:int in image.get_height():
		for x:int in image.get_width():
			var color:=image.get_pixel(x,y);var spread:=maxf(color.r,maxf(color.g,color.b))-minf(color.r,minf(color.g,color.b))
			if color.get_luminance()>0.72 and spread<0.16:image.set_pixel(x,y,Color.TRANSPARENT)

static func _remove_connected_background(image:Image)->void:
	var queue:Array[Vector2i]=[];var visited:Dictionary={}
	for x:int in image.get_width():queue.append(Vector2i(x,0));queue.append(Vector2i(x,image.get_height()-1))
	for y:int in image.get_height():queue.append(Vector2i(0,y));queue.append(Vector2i(image.get_width()-1,y))
	while not queue.is_empty():
		var point:Vector2i=queue.pop_back()
		if visited.has(point):continue
		visited[point]=true;var color:=image.get_pixelv(point);image.set_pixelv(point,Color.TRANSPARENT)
		for direction:Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next:=point+direction
			if next.x<0 or next.y<0 or next.x>=image.get_width() or next.y>=image.get_height() or visited.has(next):continue
			var candidate:=image.get_pixelv(next);var delta:=absf(candidate.r-color.r)+absf(candidate.g-color.g)+absf(candidate.b-color.b)
			if delta<0.04:queue.append(next)

static func _alpha_bounds(image:Image)->Rect2i:
	var minimum:=Vector2i(image.get_width(),image.get_height());var maximum:=Vector2i(-1,-1)
	for y:int in image.get_height():
		for x:int in image.get_width():
			if image.get_pixel(x,y).a>0.05:minimum.x=mini(minimum.x,x);minimum.y=mini(minimum.y,y);maximum.x=maxi(maximum.x,x);maximum.y=maxi(maximum.y,y)
	return Rect2i(0,0,1,1) if maximum.x<0 else Rect2i(minimum,maximum-minimum+Vector2i.ONE)

static func normalized_sheet_frames(path: String) -> SpriteFrames:
	if _generated_cache.has(path): return _generated_cache[path] as SpriteFrames
	if not ResourceLoader.exists(path): return null
	var texture := load(path) as Texture2D
	if texture == null: return null
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row in DIRECTIONS.size():
		var direction: String = DIRECTIONS[row]
		for state_index in 3:
			var state: String = ["idle","run","attack"][state_index]
			var animation: StringName = StringName("%s_%s" % [state,direction])
			frames.add_animation(animation)
			frames.set_animation_loop(animation,state!="attack")
			frames.set_animation_speed(animation,6.0 if state=="idle" else 10.0)
			for offset in 2:
				var atlas := AtlasTexture.new()
				atlas.atlas=texture
				atlas.region=Rect2(Vector2((state_index*2+offset)*NORMALIZED_FRAME_SIZE.x,row*NORMALIZED_FRAME_SIZE.y),NORMALIZED_FRAME_SIZE)
				frames.add_frame(animation,atlas)
	_generated_cache[path]=frames
	return frames

static func animation_board_frames(path: String) -> SpriteFrames:
	if _generated_cache.has(path): return _generated_cache[path] as SpriteFrames
	if not ResourceLoader.exists(path): return null
	var texture := load(path) as Texture2D
	if texture == null: return null
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var source_image:Image=texture.get_image()
	var cell_size:=Vector2i(ceili(float(source_image.get_width())/16.0),ceili(float(source_image.get_height())/4.0))
	var specifications: Array[Dictionary] = [
		{"name":"idle","first":0,"count":4,"fps":6.0,"loop":true},
		{"name":"run","first":4,"count":4,"fps":10.0,"loop":true},
		{"name":"basic","first":8,"count":3,"fps":12.0,"loop":false},
		{"name":"special","first":11,"count":2,"fps":10.0,"loop":false},
		{"name":"defensive","first":13,"count":1,"fps":6.0,"loop":false},
		{"name":"movement","first":14,"count":2,"fps":12.0,"loop":false}
	]
	for row in DIRECTIONS.size():
		var direction: String = DIRECTIONS[row]
		for specification: Dictionary in specifications:
			var animation: StringName = StringName("%s_%s" % [String(specification["name"]),direction])
			frames.add_animation(animation)
			frames.set_animation_speed(animation,float(specification["fps"]))
			frames.set_animation_loop(animation,bool(specification["loop"]))
			for offset in int(specification["count"]):
				var column:int=int(specification["first"])+offset
				var left:int=roundi(float(column)*source_image.get_width()/16.0)
				var right:int=roundi(float(column+1)*source_image.get_width()/16.0)
				var top:int=roundi(float(row)*source_image.get_height()/4.0)
				var bottom:int=roundi(float(row+1)*source_image.get_height()/4.0)
				var bounds:=Rect2i(left,top,right-left,bottom-top)
				frames.add_frame(animation,_isolated_frame_texture(source_image,bounds,cell_size))
	_generated_cache[path]=frames
	return frames

static func _isolated_frame_texture(source:Image,bounds:Rect2i,canvas_size:Vector2i)->Texture2D:
	# Generated animation boards are visually gridded, but large VFX sometimes cross
	# their nominal gutters. Copying each cell prevents the atlas sampler from ever
	# displaying pixels belonging to a neighboring frame.
	var inset:=2
	var scan:=Rect2i(bounds.position+Vector2i(inset,inset),bounds.size-Vector2i(inset*2,inset*2))
	var min_point:=Vector2i(scan.end.x,scan.end.y)
	var max_point:=Vector2i(scan.position.x-1,scan.position.y-1)
	for y in range(scan.position.y,scan.end.y):
		for x in range(scan.position.x,scan.end.x):
			if source.get_pixel(x,y).a>0.04:
				min_point.x=mini(min_point.x,x);min_point.y=mini(min_point.y,y)
				max_point.x=maxi(max_point.x,x);max_point.y=maxi(max_point.y,y)
	var canvas:=Image.create(canvas_size.x,canvas_size.y,false,Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	if max_point.x>=min_point.x and max_point.y>=min_point.y:
		var content:=Rect2i(min_point,max_point-min_point+Vector2i.ONE)
		var destination:=Vector2i((canvas_size.x-content.size.x)/2,canvas_size.y-content.size.y-6)
		canvas.blit_rect(source,content,destination)
	return ImageTexture.create_from_image(canvas)

static func direction_name(vector: Vector2, fallback: String = "down") -> String:
	if vector.length_squared()<0.001:return fallback
	if absf(vector.x)>absf(vector.y):return "right" if vector.x>0 else "left"
	return "down" if vector.y>0 else "up"

static func resolved_animation(frames: SpriteFrames, state: String, direction: String) -> StringName:
	if frames==null:return &""
	var directional: StringName = StringName("%s_%s"%[state,direction])
	if frames.has_animation(directional):return directional
	var attack_two: StringName = StringName("attack2_%s"%direction)
	if state=="attack" and frames.has_animation(attack_two):return attack_two
	var simple: StringName = StringName(state)
	if frames.has_animation(simple):return simple
	return frames.get_animation_names()[0] if not frames.get_animation_names().is_empty() else &""
