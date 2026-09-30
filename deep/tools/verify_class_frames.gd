extends SceneTree

const CLASS_IDS:Array[String]=["warrior","mage","healer","rogue","tank","summoner"]
const ASSET_IDS:Dictionary={"warrior":"","mage":"mage","healer":"healer","rogue":"phantom","tank":"tank","summoner":"summoner"}
const STATES:Array[String]=["idle","run","basic","special","defensive","movement"]
const DIRECTIONS:Array[String]=["down","left","right","up"]
var failures:Array[String]=[]

func _init()->void:
	for class_id:String in CLASS_IDS:_verify_class(class_id)
	if failures.is_empty():
		print("Verified animation coverage and padded cells for all %d playable classes."%CLASS_IDS.size());quit()
	else:
		for failure:String in failures:push_error(failure)
		quit(1)

func _verify_class(class_id:String)->void:
	var frames:=SlasherSpriteLibrary.player_frames(class_id)
	if frames==null:failures.append("Missing player frames: "+class_id);return
	for direction:String in DIRECTIONS:
		for state:String in STATES:
			var animation:=StringName("%s_%s"%[state,direction])
			if class_id=="warrior" and state not in ["idle","run"]:
				animation=StringName("attack2_"+direction)
			if not frames.has_animation(animation):failures.append("Missing %s: %s"%[animation,class_id]);continue
			var minimum_count:=8 if class_id=="warrior" else (4 if state in ["idle","run"] else 2)
			if frames.get_frame_count(animation)<minimum_count:failures.append("Too few frames in %s: %s"%[animation,class_id])
	if class_id=="warrior":return
	var asset_id:=String(ASSET_IDS[class_id]);var texture:=load("res://assets/classes/%s/padded_sheet.png"%asset_id) as Texture2D
	var image:Image=texture.get_image() if texture!=null else null
	if image==null:failures.append("Missing normalized sheet: "+class_id);return
	var cell_size:=Vector2i(image.get_width()/12,image.get_height()/4)
	for row:int in 4:
		for column:int in 12:
			var origin:=Vector2i(column*cell_size.x,row*cell_size.y)
			for x:int in cell_size.x:
				if image.get_pixelv(origin+Vector2i(x,0)).a>0.05 or image.get_pixelv(origin+Vector2i(x,cell_size.y-1)).a>0.05:failures.append("Vertical clipping risk in %s cell %d,%d"%[class_id,column,row]);return
			for y:int in cell_size.y:
				if image.get_pixelv(origin+Vector2i(0,y)).a>0.05 or image.get_pixelv(origin+Vector2i(cell_size.x-1,y)).a>0.05:failures.append("Horizontal clipping risk in %s cell %d,%d"%[class_id,column,row]);return
