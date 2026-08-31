extends SceneTree

const ROOT := "res://assets/sprite_packs/Player"
const OUTPUT := ROOT + "/player_frames.tres"
const DIRECTIONS := ["down", "left", "right", "up"]
const FRAME_SIZE := Vector2(96, 80)
const FRAME_COUNT := 8

## Builds all directional player idle and run animations and saves the shared SpriteFrames resource.
func _init() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for state in ["idle", "run"]:
		for direction in DIRECTIONS:
			var animation: String = str(state) + "_" + str(direction)
			frames.add_animation(animation)
			frames.set_animation_loop(animation, true)
			frames.set_animation_speed(animation, 6.0 if state == "idle" else 10.0)
			var folder: String = "IDLE" if state == "idle" else "RUN"
			var texture: Texture2D = load(ROOT + "/" + folder + "/" + state + "_" + direction + ".png")
			for frame_index in FRAME_COUNT:
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(Vector2(frame_index * FRAME_SIZE.x, 0), FRAME_SIZE)
				frames.add_frame(animation, atlas)
	for direction in DIRECTIONS:
		var animation: String = "attack2_" + str(direction)
		frames.add_animation(animation)
		frames.set_animation_loop(animation, false)
		frames.set_animation_speed(animation, 28.0)
		var texture: Texture2D = load(ROOT + "/ATTACK 2/attack2_" + str(direction) + ".png")
		for frame_index in FRAME_COUNT:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(Vector2(frame_index * FRAME_SIZE.x, 0), FRAME_SIZE)
			frames.add_frame(animation, atlas)
	var error := ResourceSaver.save(frames, OUTPUT)
	if error != OK:
		push_error("Could not save player SpriteFrames: %s" % error)
		quit(1)
	else:
		print("Created %s with %d directional animations." % [OUTPUT, frames.get_animation_names().size()])
		quit(0)
