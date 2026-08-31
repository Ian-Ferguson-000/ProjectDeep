extends SceneTree
const ROOT := "res://assets/sprite_packs/Kobold/Sprites/with_outline"
const OUTPUT := "res://assets/sprite_packs/Kobold/kobold_frames.tres"
const FRAME_SIZE := Vector2(148,96)
## Builds the Kobold idle, run, and attack SpriteFrames resource from its horizontal source strips.
func _init() -> void:
	var frames:=SpriteFrames.new(); frames.remove_animation("default")
	for spec in [["idle","IDLE.png",6,7.0,true],["run","RUN.png",8,11.0,true],["attack","ATTACK 1.png",5,10.0,false]]:
		var animation:String=spec[0]; frames.add_animation(animation); frames.set_animation_speed(animation,spec[3]); frames.set_animation_loop(animation,spec[4])
		var texture:Texture2D=load(ROOT+"/"+spec[1])
		for i in int(spec[2]):
			var atlas:=AtlasTexture.new(); atlas.atlas=texture; atlas.region=Rect2(i*FRAME_SIZE.x,0,FRAME_SIZE.x,FRAME_SIZE.y); frames.add_frame(animation,atlas)
	var error:=ResourceSaver.save(frames,OUTPUT); print("Created Kobold animations: ",OUTPUT); quit(0 if error==OK else 1)
