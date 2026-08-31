extends SceneTree

const IDS:=["ice_mage","fire_mage","poison_ranger","feral_wolf"]
const DIRECTIONS:=["down","left","right","up"]

## Builds reusable directional Idle, Run, and Attack SpriteFrames from normalized 4×6 atlases.
func _init() -> void:
	var requested:=OS.get_cmdline_user_args()
	var selected:=IDS if requested.is_empty() else IDS.filter(func(enemy_id): return enemy_id in requested)
	for enemy_id in selected:
		var texture:Texture2D=load("res://assets/enemies/%s/normalized_sheet.png"%enemy_id)
		var frames:=SpriteFrames.new(); frames.remove_animation("default")
		for row in 4:
			for state_index in 3:
				var animation:String=["idle_","run_","attack_"][state_index]+DIRECTIONS[row]
				frames.add_animation(animation); frames.set_animation_loop(animation,state_index<2); frames.set_animation_speed(animation,6.0 if state_index==0 else 10.0)
				for offset in 2:
					var atlas:=AtlasTexture.new(); atlas.atlas=texture; atlas.region=Rect2((state_index*2+offset)*96,row*80,96,80); frames.add_frame(animation,atlas)
		ResourceSaver.save(frames,"res://assets/enemies/%s/frames.tres"%enemy_id)
	if requested.is_empty():
		_build_local_frames("dark_druid",load("res://assets/pixel_art/voodoo-guy-walk anim.png"),load("res://assets/pixel_art/voodoo-guy-behaviour.png"),Vector2(44,37),Vector2(32,37))
		_build_local_frames("spore_beast",load("res://assets/pixel_art/shroomie.png"),load("res://assets/pixel_art/shroomie - wakeup.png"),Vector2(32,32),Vector2(32,32))
	quit()

## Builds compact side-facing local-art animations for Dark Druid and Spore Beast source atlases.
func _build_local_frames(enemy_id:String,move_texture:Texture2D,attack_texture:Texture2D,move_size:Vector2,attack_size:Vector2) -> void:
	var frames:=SpriteFrames.new(); frames.remove_animation("default")
	for animation in ["idle","run","attack"]:
		frames.add_animation(animation); frames.set_animation_loop(animation,animation!="attack"); frames.set_animation_speed(animation,7.0)
		for index in 2:
			var atlas:=AtlasTexture.new(); atlas.atlas=attack_texture if animation=="attack" else move_texture
			var size:=attack_size if animation=="attack" else move_size; atlas.region=Rect2(index*size.x,0,size.x,size.y); frames.add_frame(animation,atlas)
	ResourceSaver.save(frames,"res://assets/enemies/%s/frames.tres"%enemy_id)
