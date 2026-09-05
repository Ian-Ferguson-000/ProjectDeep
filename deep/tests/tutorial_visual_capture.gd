extends SceneTree

const DIALOGUE_CHAT := preload("res://scripts/ui/dialogue_chat.gd")
const TUTORIAL_SEQUENCE := preload("res://scripts/slasher/forest_tutorial_sequence.gd")

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var backdrop := ColorRect.new()
	backdrop.color = Color("17251d")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var canopy := Label.new()
	canopy.text = "THE BRIARWAY"
	canopy.position = Vector2(48, 42)
	canopy.add_theme_font_size_override("font_size", 28)
	canopy.add_theme_color_override("font_color", Color("77966e"))
	backdrop.add_child(canopy)

	var sequence: ForestTutorialSequence = TUTORIAL_SEQUENCE.new()
	root.add_child(sequence)
	await process_frame
	sequence.begin(0, Vector2.ZERO)
	await process_frame
	var card_error := root.get_texture().get_image().save_png("res://build/tutorial_control_card_1280x720.png")
	if card_error != OK:
		push_error("Unable to save tutorial control-card capture: %s" % card_error)
		quit(1)
		return
	sequence.visible = false

	var chat: DialogueChat = DIALOGUE_CHAT.new()
	root.add_child(chat)
	await process_frame
	chat.play([
		{"speaker":"Mara Vell", "text":"The Briarway has swallowed another road, Alden. Learn quickly, and remember: the forest keeps every careless name.", "portrait":"res://assets/merchants/tavern_mara.png", "side":"left"},
		{"speaker":"Alden", "text":"Three heartbeats of strength and a borrowed sword? I have worked with less.", "portrait":"res://assets/roster_portraits/warrior_0.png", "side":"right"},
	])
	# Dialogue intentionally pauses gameplay. The visual harness briefly resumes the
	# tree so the headless renderer can draw the paused overlay for inspection.
	paused = false
	await process_frame
	await process_frame
	var dialogue_error := root.get_texture().get_image().save_png("res://build/tutorial_dialogue_1280x720.png")
	root.content_scale_factor = 1.5
	await process_frame
	await process_frame
	var scaled_error := root.get_texture().get_image().save_png("res://build/tutorial_dialogue_150_percent.png")
	chat._finish()
	if dialogue_error != OK:
		push_error("Unable to save tutorial dialogue capture: %s" % dialogue_error)
		quit(1)
		return
	if scaled_error != OK:
		push_error("Unable to save scaled tutorial dialogue capture: %s" % scaled_error)
		quit(1)
		return
	print("TUTORIAL_VISUAL_CAPTURE_PASSED")
	quit(0)
