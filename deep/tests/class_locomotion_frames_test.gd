extends SceneTree

const CLASSES := {"rogue":"phantom", "tank":"tank", "healer":"healer"}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for class_id in CLASSES:
		var frames := SlasherSpriteLibrary.player_frames(class_id)
		assert(frames != null)
		var combat_size := frames.get_frame_texture("basic_down", 0).get_size()
		for direction in SlasherSpriteLibrary.DIRECTIONS:
			for state in ["idle", "run"]:
				var animation := "%s_%s" % [state, direction]
				assert(frames.get_frame_count(animation) == 8)
				for index in 8:
					var texture := frames.get_frame_texture(animation, index)
					assert(not texture is AtlasTexture)
					assert(texture.get_size() == combat_size)
			assert(frames.get_frame_count("basic_%s" % direction) == 3)
			assert(frames.get_frame_count("special_%s" % direction) == 2)
			assert(frames.get_frame_count("defensive_%s" % direction) == 1)
			assert(frames.get_frame_count("movement_%s" % direction) == 2)
	print("CLASS_LOCOMOTION_FRAMES_TESTS_PASSED")
	quit(0)
