extends ColorRect
class_name RecruitmentDialogue

signal recruit_requested(candidate_id:String)
signal conversation_closed
signal capacity_error(message:String)

var candidate_id:=""
var title_label:Label
var detail_label:Label
var error_label:Label
var recruit_button:Button
var portrait:TextureRect
var dialogue_panel:PanelContainer

func _ready()->void:
	name="RecruitmentDialogue";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);color=Color(0.01,0.008,0.006,0.82);mouse_filter=Control.MOUSE_FILTER_STOP;visible=false
	dialogue_panel=PanelContainer.new();dialogue_panel.set_anchors_preset(Control.PRESET_TOP_LEFT);add_child(dialogue_panel);_layout_panel();get_viewport().size_changed.connect(_layout_panel)
	var margin:=MarginContainer.new()
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_%s"%side,22)
	dialogue_panel.add_child(margin)
	var body:=VBoxContainer.new();body.add_theme_constant_override("separation",14);margin.add_child(body)
	title_label=Label.new();title_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title_label.add_theme_font_size_override("font_size",28);body.add_child(title_label)
	var profile:=HBoxContainer.new();profile.size_flags_vertical=Control.SIZE_EXPAND_FILL;profile.add_theme_constant_override("separation",20);body.add_child(profile)
	portrait=TextureRect.new();portrait.custom_minimum_size=Vector2(180,220);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;profile.add_child(portrait)
	detail_label=Label.new();detail_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_label.size_flags_vertical=Control.SIZE_EXPAND_FILL;detail_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;detail_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;detail_label.add_theme_font_size_override("font_size",17);profile.add_child(detail_label)
	error_label=Label.new();error_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;error_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;error_label.add_theme_color_override("font_color",Color(1.0,0.48,0.4));body.add_child(error_label)
	var buttons:=HBoxContainer.new();buttons.alignment=BoxContainer.ALIGNMENT_CENTER;buttons.add_theme_constant_override("separation",16);body.add_child(buttons)
	var later:=Button.new();later.text="Not Yet";later.pressed.connect(close);FantasyButton.apply_dark(later,16,Vector2(220,48));buttons.add_child(later)
	recruit_button=Button.new();recruit_button.text="Recruit — Free";recruit_button.pressed.connect(func():recruit_requested.emit(candidate_id));FantasyButton.apply_light(recruit_button,16,Vector2(220,48));buttons.add_child(recruit_button)

func _layout_panel()->void:
	if dialogue_panel==null:return
	var viewport_size:=get_viewport_rect().size;var available:=viewport_size-Vector2(36,36);dialogue_panel.size=Vector2(minf(700,available.x),minf(480,available.y));dialogue_panel.position=(viewport_size-dialogue_panel.size)/2.0

func open(candidate:CandidateRecord)->void:
	candidate_id=candidate.id;error_label.text="";var member:=candidate.adventurer
	var weapon:=member.gear_id.replace("_"," ").capitalize()
	var portrait_path:="res://assets/roster_portraits/%s_%d.png"%[member.class_id,member.portrait_variant];portrait.texture=load(portrait_path) if ResourceLoader.exists(portrait_path) else null
	title_label.text="%s · %s"%[member.display_name,member.class_id.capitalize()]
	detail_label.text="Level %d     %s\nBasic weapon: %s\n\n%s\n\n“%s”"%[member.level,member.trait_name,weapon,member.trait_description,candidate.motivation]
	visible=true;move_to_front();recruit_button.grab_focus()

func show_capacity_error(message:String)->void:
	error_label.text=message;capacity_error.emit(message);recruit_button.grab_focus()

func close()->void:
	visible=false;conversation_closed.emit()

func _unhandled_input(event:InputEvent)->void:
	if visible and event.is_action_pressed("ui_cancel"):get_viewport().set_input_as_handled();close()
