extends Control
class_name SlasherEndlessPrompt

signal decision_made(continue_endless:bool)

var previous_pause:=false
var description_label:Label

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS;position=Vector2.ZERO;size=get_viewport_rect().size;mouse_filter=Control.MOUSE_FILTER_STOP;get_viewport().size_changed.connect(_fit_viewport);previous_pause=get_tree().paused;get_tree().paused=true
	var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color("#030907e8");add_child(shade)
	var panel:=PanelContainer.new();panel.anchor_left=0.5;panel.anchor_top=0.5;panel.anchor_right=0.5;panel.anchor_bottom=0.5;panel.offset_left=-390;panel.offset_top=-220;panel.offset_right=390;panel.offset_bottom=220;var style:=StyleBoxFlat.new();style.bg_color=Color("#101914f5");style.border_color=Color("#d6a536");style.set_border_width_all(3);style.set_corner_radius_all(10);style.set_content_margin_all(28);panel.add_theme_stylebox_override("panel",style);add_child(panel)
	var body:=VBoxContainer.new();body.alignment=BoxContainer.ALIGNMENT_CENTER;body.add_theme_constant_override("separation",18);panel.add_child(body)
	var title:=Label.new();title.text="THE FOREST YIELDS";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",32);title.add_theme_color_override("font_color",Color("#f4d178"));body.add_child(title)
	description_label=Label.new();description_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;description_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;description_label.add_theme_font_size_override("font_size",18);body.add_child(description_label);setup(float(GameBalance.get_slasher_balance("rewards").get("endless_xp_multiplier",0.35)))
	var buttons:=HBoxContainer.new();buttons.alignment=BoxContainer.ALIGNMENT_CENTER;buttons.add_theme_constant_override("separation",18);body.add_child(buttons)
	var return_button:=Button.new();return_button.text="Return to the Hearth";return_button.custom_minimum_size=Vector2(270,58);return_button.pressed.connect(_choose.bind(false));buttons.add_child(return_button)
	var continue_button:=Button.new();continue_button.text="Continue Endless";continue_button.custom_minimum_size=Vector2(270,58);continue_button.pressed.connect(_choose.bind(true));buttons.add_child(continue_button);continue_button.grab_focus()

func _fit_viewport()->void:position=Vector2.ZERO;size=get_viewport_rect().size

func setup(xp_multiplier:float)->void:
	# TUNING: The displayed rate reads rewards.endless_xp_multiplier from slasher_balance.json.
	if description_label!=null:description_label.text="The guardian has fallen and the campaign clear is secured.\nReturn to the Hearth, or descend into an Endless Forest cycle.\nEndless enemies continue scaling while experience is reduced to %d%%."%int(round(xp_multiplier*100.0))

func _choose(continue_endless:bool)->void:
	get_tree().paused=previous_pause;decision_made.emit(continue_endless);queue_free()
