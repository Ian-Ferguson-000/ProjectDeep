extends SceneTree

const SOURCE_PATH := "res://assets/generated_vfx/flamethrower/flamethrower_generated_source.png"
const OUTPUT_ROOT := "res://assets/generated_vfx/flamethrower/"
const FRAME_COUNT := 18
const FRAME_SIZE := Vector2i(128,96)

## Extracts the generated effect row, removes its neutral preview backdrop, and writes three engine strips.
func _init() -> void:
	var source := Image.load_from_file(SOURCE_PATH)
	if source.is_empty():
		push_error("Could not load Flamethrower source image")
		quit(1)
		return
	var frames: Array[Image] = []
	for index in FRAME_COUNT:
		frames.append(_extract_frame(source,index))
	_write_strip(frames.slice(0,3),"flamethrower_start.png")
	_write_strip(frames.slice(3,12),"flamethrower_active.png")
	_write_strip(frames.slice(12,18),"flamethrower_end.png")
	quit()

## Crops one equally spaced source cell, keys out grayscale checker pixels, and scales it for gameplay.
func _extract_frame(source: Image, index: int) -> Image:
	var left := roundi(float(index)*source.get_width()/FRAME_COUNT)
	var right := roundi(float(index+1)*source.get_width()/FRAME_COUNT)
	var crop := source.get_region(Rect2i(left,300,right-left,144))
	crop.convert(Image.FORMAT_RGBA8)
	for y in crop.get_height():
		for x in crop.get_width():
			var color := crop.get_pixel(x,y)
			var spread := maxf(color.r,maxf(color.g,color.b))-minf(color.r,minf(color.g,color.b))
			if spread < 0.075 and color.get_luminance() > 0.62:
				crop.set_pixel(x,y,Color(0,0,0,0))
	crop.resize(FRAME_SIZE.x,FRAME_SIZE.y,Image.INTERPOLATE_NEAREST)
	return crop

## Packs a frame subset into a transparent horizontal strip and saves it beside the generated source.
func _write_strip(frames: Array[Image], file_name: String) -> void:
	var strip := Image.create_empty(FRAME_SIZE.x*frames.size(),FRAME_SIZE.y,false,Image.FORMAT_RGBA8)
	strip.fill(Color(0,0,0,0))
	for index in frames.size():
		strip.blit_rect(frames[index],Rect2i(Vector2i.ZERO,FRAME_SIZE),Vector2i(index*FRAME_SIZE.x,0))
	var error := strip.save_png(OUTPUT_ROOT+file_name)
	if error != OK: push_error("Could not save "+file_name)
