extends Control
class_name ModeSelection

var controller: Node

func setup(game_controller: Node) -> void: controller = game_controller

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new(); background.color = Color("17110d"); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var panel := VBoxContainer.new(); panel.set_anchors_preset(Control.PRESET_CENTER); panel.position = Vector2(-330,-225); panel.size = Vector2(660,450); panel.add_theme_constant_override("separation",18); add_child(panel)
	var title := Label.new(); title.text = "Choose Your Approach"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size",34); title.add_theme_color_override("font_color",Color("f2ce77")); panel.add_child(title)
	var copy := Label.new(); copy.text = "The Briarway can be challenged as a deliberate tabletop expedition or a real-time action descent. This choice unlocks a different recruit class when the Forest is eventually cleared."; copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; copy.add_theme_font_size_override("font_size",17); panel.add_child(copy)
	_add_mode(panel, RunState.PLAY_MODE_STRATEGY, "STRATEGY", "Command every party member's movement and actions. Forest clear unlock: Tank.")
	_add_mode(panel, RunState.PLAY_MODE_SLASHER, "SLASHER", "Fight in real time and use Tab to cycle party members. Forest clear unlock: Rogue.")

func _add_mode(parent: VBoxContainer, mode: String, title: String, description: String) -> void:
	var button := Button.new(); button.custom_minimum_size = Vector2(0,90); button.text = "%s\n%s" % [title, description]; button.add_theme_font_size_override("font_size",18); button.pressed.connect(_choose.bind(mode)); parent.add_child(button)

func _choose(mode: String) -> void:
	if controller != null and controller.has_method("choose_tutorial_mode"): controller.choose_tutorial_mode(mode)
