extends SceneTree

const CLASS_IDS:Array[String]=["mage","healer","phantom","tank","summoner"]
const DIRECTIONS:Array[String]=["down","left","right","up"]
const FRAME_SIZE:=Vector2i(104,88)
const SPECIFICATIONS:Array[Dictionary]=[
	{"name":"idle","column":0,"count":4,"fps":6.0,"loop":true},
	{"name":"run","column":4,"count":4,"fps":10.0,"loop":true},
	{"name":"basic","column":8,"count":1,"fps":12.0,"loop":false},
	{"name":"special","column":9,"count":1,"fps":10.0,"loop":false},
	{"name":"defensive","column":10,"count":1,"fps":6.0,"loop":false},
	{"name":"movement","column":11,"count":1,"fps":12.0,"loop":false}
]

func _init()->void:
	var requested:=OS.get_cmdline_user_args()
	var selected:=CLASS_IDS if requested.is_empty() else CLASS_IDS.filter(func(class_id:String)->bool:return class_id in requested)
	for class_id:String in selected:_build_class(class_id)
	quit()

func _build_class(class_id:String)->void:
	var texture:=load("res://assets/classes/%s/padded_sheet.png"%class_id) as Texture2D
	var frames:=SpriteFrames.new();frames.remove_animation("default")
	for row:int in DIRECTIONS.size():
		for specification:Dictionary in SPECIFICATIONS:
			var animation:=StringName("%s_%s"%[String(specification.name),DIRECTIONS[row]])
			frames.add_animation(animation);frames.set_animation_speed(animation,float(specification.fps));frames.set_animation_loop(animation,bool(specification.loop))
			var frame_count:=int(specification.count)
			for frame_index:int in maxi(2,frame_count):
				var source_offset:=mini(frame_index,frame_count-1)
				var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.region=Rect2(Vector2i((int(specification.column)+source_offset)*FRAME_SIZE.x,row*FRAME_SIZE.y),FRAME_SIZE);frames.add_frame(animation,atlas)
	var error:=ResourceSaver.save(frames,"res://assets/classes/%s/player_frames.tres"%class_id)
	if error!=OK:push_error("Could not save %s class frames: %s"%[class_id,error_string(error)])
