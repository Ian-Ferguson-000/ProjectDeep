extends SceneTree

func _initialize()->void:call_deferred("_run")

func _run()->void:
	var frames:=SlasherSpriteLibrary.player_frames("warrior")
	assert(frames!=null)
	for direction:String in SlasherSpriteLibrary.DIRECTIONS:
		for state:String in ["special","defensive"]:
			var animation:=StringName("%s_%s"%[state,direction])
			assert(frames.has_animation(animation))
			assert(frames.get_frame_count(animation)==8)
			assert(not frames.get_animation_loop(animation))
			for frame_index:int in 8:
				assert(frames.get_frame_texture(animation,frame_index).get_size()==Vector2(96,80))
	print("WARRIOR_ACTION_FRAMES_TESTS_PASSED")
	quit(0)
