extends SceneTree

const IDS:=["ice_mage","fire_mage","poison_ranger","feral_wolf"]

## Normalizes generated 4×6 sheets into transparent fixed 96×80 cells while preserving all directional poses.
func _init() -> void:
	var requested:=OS.get_cmdline_user_args()
	var selected:=IDS if requested.is_empty() else IDS.filter(func(enemy_id): return enemy_id in requested)
	for enemy_id in selected:
		var source:=Image.load_from_file("res://assets/enemies/%s/generated_source.png"%enemy_id)
		var output:=Image.create(576,320,false,Image.FORMAT_RGBA8); output.fill(Color.TRANSPARENT)
		var cell_size:=Vector2i(source.get_width()/6,source.get_height()/4)
		for row in 4:
			for column in 6:
				var cell:=source.get_region(Rect2i(column*cell_size.x,row*cell_size.y,cell_size.x,cell_size.y))
				if not _has_transparent_pixels(cell): _remove_baked_light_background(cell)
				var bounds:=_alpha_bounds(cell); var frame:=cell.get_region(bounds)
				var scale_factor:=minf(88.0/frame.get_width(),74.0/frame.get_height())
				frame.resize(maxi(1,roundi(frame.get_width()*scale_factor)),maxi(1,roundi(frame.get_height()*scale_factor)),Image.INTERPOLATE_NEAREST)
				frame.convert(Image.FORMAT_RGBA8)
				output.blit_rect(frame,Rect2i(Vector2i.ZERO,frame.get_size()),Vector2i(column*96+(96-frame.get_width())/2,row*80+80-frame.get_height()))
		output.save_png("res://assets/enemies/%s/normalized_sheet.png"%enemy_id)
	quit()

## Detects whether a manually cleaned source cell already contains useful alpha that must be preserved.
func _has_transparent_pixels(image: Image) -> bool:
	for y in range(0,image.get_height(),8):
		for x in range(0,image.get_width(),8):
			if image.get_pixel(x,y).a<0.1:return true
	return false

## Removes the neutral white/checker backdrop from legacy generated cells without touching dark sprite pixels.
func _remove_baked_light_background(image: Image) -> void:
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var color:=image.get_pixel(x,y)
			var spread:=maxf(color.r,maxf(color.g,color.b))-minf(color.r,minf(color.g,color.b))
			if color.get_luminance()>0.78 and spread<0.12:image.set_pixel(x,y,Color.TRANSPARENT)

## Flood-fills smooth or checkerboard-connected backdrop pixels from every cell edge into transparency.
func _remove_connected_background(image:Image) -> void:
	var queue:Array[Vector2i]=[]; var visited:Dictionary={}
	for x in image.get_width(): queue.append(Vector2i(x,0)); queue.append(Vector2i(x,image.get_height()-1))
	for y in image.get_height(): queue.append(Vector2i(0,y)); queue.append(Vector2i(image.get_width()-1,y))
	while not queue.is_empty():
		var point:Vector2i=queue.pop_back()
		if visited.has(point):continue
		visited[point]=true; var color:=image.get_pixelv(point)
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next:Vector2i=point+direction
			if next.x<0 or next.y<0 or next.x>=image.get_width() or next.y>=image.get_height() or visited.has(next):continue
			var candidate:=image.get_pixelv(next)
			var delta:float=abs(candidate.r-color.r)+abs(candidate.g-color.g)+abs(candidate.b-color.b)
			if delta<0.035 or (candidate.r>0.82 and candidate.g>0.82 and candidate.b>0.82):queue.append(next)
		image.set_pixelv(point,Color.TRANSPARENT)

## Returns the smallest nontransparent rectangle and a safe one-pixel fallback for empty cells.
func _alpha_bounds(image:Image) -> Rect2i:
	var minimum:=Vector2i(image.get_width(),image.get_height()); var maximum:=Vector2i.ZERO
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).a>0.05:
				minimum.x=mini(minimum.x,x); minimum.y=mini(minimum.y,y); maximum.x=maxi(maximum.x,x); maximum.y=maxi(maximum.y,y)
	if minimum.x>maximum.x:return Rect2i(0,0,1,1)
	return Rect2i(minimum,maximum-minimum+Vector2i.ONE)
