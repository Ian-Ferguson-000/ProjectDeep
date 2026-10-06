extends SceneTree
const GROUND := preload("res://scenes/slasher/TestingGround.tscn")
var ground: Node
func _initialize() -> void:call_deferred("capture")
func shot(name_value: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/combo_practice_"+name_value+".png")
func capture() -> void:
	root.size=Vector2i(1280,720);ground=GROUND.instantiate();root.add_child(ground);await process_frame
	ground.class_picker.select(1);ground._refresh_class();ground.gear_picker.select(6);ground.apply_build();ground.set_editor_visible(false)
	await physics_frame;ground.player.set_physics_process(false)
	ground.toggle_combo_panel();ground.player.aim_direction=Vector2.RIGHT
	ground.player.use_action("special");ground.player.use_action("basic")
	await shot("progress_1280")
	root.size=Vector2i(960,540);await process_frame;await process_frame
	await shot("progress_960")
	ground.player.cooldowns.special=0;ground.state.class_resource=3;ground.player.use_action("special")
	await shot("success_960")
	ground.class_picker.select(1);ground._refresh_class();ground.gear_picker.select(4);ground.apply_build();ground.set_editor_visible(false)
	await process_frame;await physics_frame
	ground.player.set_physics_process(false);ground.player.use_action("movement");ground.player.use_action("basic");ground.player.use_action("special")
	await shot("fire_960")
	ground.queue_free();await process_frame;await process_frame;quit()
