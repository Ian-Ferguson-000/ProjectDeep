extends SceneTree

const KEEPER_SCENE := preload("res://scenes/components/TavernKeeper.tscn")
const ACTOR_SCENE := preload("res://scenes/components/TavernActor.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var frames := SlasherSpriteLibrary.tavern_keeper_frames()
	assert(frames != null)
	for direction in SlasherSpriteLibrary.DIRECTIONS:
		for state in ["idle", "run"]:
			var animation := "%s_%s" % [state, direction]
			assert(frames.has_animation(animation))
			assert(frames.get_frame_count(animation) == 8)
			assert(frames.get_frame_texture(animation, 0).get_size() == Vector2(96, 80))
	var keeper := KEEPER_SCENE.instantiate() as TavernKeeperController
	root.add_child(keeper)
	await process_frame
	keeper.sprite.play("run_left")
	keeper.facing = "left"
	keeper.set_modal_paused(true)
	assert(keeper.velocity == Vector2.ZERO)
	assert(keeper.sprite.animation == "idle_left")
	var actor := ACTOR_SCENE.instantiate() as TavernActor
	root.add_child(actor)
	actor.configure("roster", "test", "Test Adventurer", frames)
	actor.sprite.play("run_right")
	actor._last_direction = "right"
	actor.set_world_paused(true)
	assert(actor.sprite.animation == "idle_right")
	actor.set_world_paused(false)
	assert(actor.sprite.animation == "idle_right")
	print("TAVERN_ANIMATION_STATE_TESTS_PASSED")
	quit(0)
