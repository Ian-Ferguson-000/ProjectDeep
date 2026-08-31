extends SceneTree

const SOURCE_PATH:="res://assets/generated_vfx/fireball/fireball_generated_source.png"
const OUTPUT_ROOT:="res://assets/generated_vfx/fireball/"
const X_SPANS:Array[Vector2i]=[
	Vector2i(48,98),Vector2i(143,220),Vector2i(263,337),Vector2i(376,458),Vector2i(493,574),
	Vector2i(609,693),Vector2i(730,815),Vector2i(862,948),Vector2i(988,1074),Vector2i(1122,1207),
	Vector2i(1247,1333),Vector2i(1366,1453),Vector2i(1494,1578),Vector2i(1609,1691),Vector2i(1725,1809),
	Vector2i(1838,1918),Vector2i(1951,2025),Vector2i(2073,2120),Vector2i(2136,2139)
]

## Normalizes the generated source into engine-ready 48×32 startup, flight, and impact strips.
func _init() -> void:
	var source:=Image.load_from_file(SOURCE_PATH)
	_build_sheet(source,[0,1,2],"fireball_start.png")
	_build_sheet(source,[3,4,5,6,7,8,9,10,11,12],"fireball_flight.png")
	_build_sheet(source,[13,14,15,16,17,17,17,-1],"fireball_impact.png")
	quit()

## Centers selected source frames inside a transparent horizontal strip and writes it as PNG.
func _build_sheet(source: Image, indices: Array, filename: String) -> void:
	var sheet:=Image.create(indices.size()*48,32,false,Image.FORMAT_RGBA8)
	sheet.fill(Color.TRANSPARENT)
	for destination_index in indices.size():
		if int(indices[destination_index])<0: continue
		var frame:=_frame_image(source,int(indices[destination_index]))
		var target:=Vector2i(destination_index*48+(48-frame.get_width())/2,(32-frame.get_height())/2)
		sheet.blit_rect(frame,Rect2i(Vector2i.ZERO,frame.get_size()),target)
	sheet.save_png(OUTPUT_ROOT+filename)

## Crops one generated frame to visible alpha and nearest-neighbor scales it into a 44×28 cell budget.
func _frame_image(source: Image, index: int) -> Image:
	var span:=X_SPANS[index]
	var rough:=source.get_region(Rect2i(span.x,0,span.y-span.x+1,source.get_height()))
	var bounds:=_alpha_bounds(rough)
	var frame:=rough.get_region(bounds)
	var scale_factor:=minf(44.0/frame.get_width(),28.0/frame.get_height())
	frame.resize(maxi(1,roundi(frame.get_width()*scale_factor)),maxi(1,roundi(frame.get_height()*scale_factor)),Image.INTERPOLATE_NEAREST)
	return frame

## Finds the smallest rectangle containing nontransparent pixels in a generated frame crop.
func _alpha_bounds(image: Image) -> Rect2i:
	var minimum:=Vector2i(image.get_width(),image.get_height()); var maximum:=Vector2i.ZERO
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).a>0.05:
				minimum.x=mini(minimum.x,x); minimum.y=mini(minimum.y,y)
				maximum.x=maxi(maximum.x,x); maximum.y=maxi(maximum.y,y)
	if minimum.x>maximum.x: return Rect2i(0,0,1,1)
	return Rect2i(minimum,maximum-minimum+Vector2i.ONE)
