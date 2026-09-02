extends SceneTree

const START := preload("res://scenes/start/StartScreen.tscn")

class VisualController extends Node:
	func get_save_slot_summaries()->Array[Dictionary]:
		return [
			{"slot":1,"exists":true,"recoverable":true,"tutorial_phase":"complete","roster_count":6,"completed_dungeons":4,"banked_gold":138,"last_saved_unix":1700000000},
			{"slot":2,"exists":false,"recoverable":false},
			{"slot":3,"exists":true,"recoverable":true,"tutorial_phase":"last_stand","roster_count":1,"completed_dungeons":0,"banked_gold":0,"last_saved_unix":1710000000},
		]

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var scene:=START.instantiate()
	var controller:=VisualController.new();root.add_child(controller);scene.setup(controller)
	root.add_child(scene)
	await process_frame;await process_frame
	var start_error:=root.get_texture().get_image().save_png("res://build/start_multi_save.png")
	if start_error!=OK:push_error("Unable to save start-screen capture: %s"%start_error);quit(1);return
	scene._open_slot_picker(false);await process_frame;await process_frame
	var picker_error:=root.get_texture().get_image().save_png("res://build/continue_slot_picker.png")
	if picker_error!=OK:push_error("Unable to save slot-picker capture: %s"%picker_error);quit(1);return
	scene.get_node("SlotPickerOverlay").queue_free();await process_frame
	scene._open_options()
	root.content_scale_factor=1.5
	await process_frame
	await process_frame
	await process_frame
	var image:=root.get_texture().get_image()
	var error:=image.save_png("res://build/options_150_percent.png")
	if error==OK:
		for node in scene.get_node("OptionsOverlay").find_children("*","ScrollContainer",true,false):
			(node as ScrollContainer).scroll_vertical=100000
		await process_frame;await process_frame
		error=root.get_texture().get_image().save_png("res://build/options_150_percent_bottom.png")
	if error==OK:print("RELEASE_VISUAL_CAPTURE_PASSED");quit(0);return
	push_error("Unable to save release visual capture: %s"%error);quit(1)
