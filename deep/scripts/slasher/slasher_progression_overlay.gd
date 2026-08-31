extends Control
class_name SlasherProgressionOverlay

signal all_choices_resolved

var run_state:RunState
var previous_pause:=false
var title:Label
var subtitle:Label
var cards:HBoxContainer
var detail:RichTextLabel
var confirm_button:Button
var selected_choice_id:=""

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS;position=Vector2.ZERO;size=get_viewport_rect().size;mouse_filter=Control.MOUSE_FILTER_STOP;get_viewport().size_changed.connect(_fit_viewport)
	var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color("#060a0dea");add_child(shade)
	var frame:=PanelContainer.new();frame.anchor_left=0.5;frame.anchor_top=0.5;frame.anchor_right=0.5;frame.anchor_bottom=0.5;frame.offset_left=-510;frame.offset_top=-300;frame.offset_right=510;frame.offset_bottom=300;var style:=StyleBoxFlat.new();style.bg_color=Color("#15100bea");style.border_color=Color("#d6a536");style.set_border_width_all(3);style.set_corner_radius_all(10);style.set_content_margin_all(24);frame.add_theme_stylebox_override("panel",style);add_child(frame)
	var body:=VBoxContainer.new();body.add_theme_constant_override("separation",14);frame.add_child(body)
	title=Label.new();title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",30);title.add_theme_color_override("font_color",Color("#f4d178"));body.add_child(title)
	subtitle=Label.new();subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;subtitle.add_theme_font_size_override("font_size",17);subtitle.add_theme_color_override("font_color",Color("#b7c9d7"));body.add_child(subtitle)
	cards=HBoxContainer.new();cards.alignment=BoxContainer.ALIGNMENT_CENTER;cards.size_flags_vertical=Control.SIZE_EXPAND_FILL;cards.add_theme_constant_override("separation",14);body.add_child(cards)
	detail=RichTextLabel.new();detail.bbcode_enabled=true;detail.fit_content=true;detail.custom_minimum_size.y=96;detail.add_theme_font_size_override("normal_font_size",16);body.add_child(detail)
	confirm_button=Button.new();confirm_button.text="Select an upgrade";confirm_button.disabled=true;confirm_button.custom_minimum_size=Vector2(280,48);confirm_button.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;confirm_button.pressed.connect(_confirm);body.add_child(confirm_button)

func _fit_viewport()->void:position=Vector2.ZERO;size=get_viewport_rect().size

func open(state:RunState)->void:
	run_state=state;previous_pause=get_tree().paused;run_state.reconcile_slasher_progression();get_tree().paused=true;_refresh()

func _refresh()->void:
	selected_choice_id="";confirm_button.disabled=true;confirm_button.text="Select an upgrade"
	for child:Node in cards.get_children():child.free()
	if not run_state.has_pending_slasher_progression_choice():
		get_tree().paused=previous_pause;all_choices_resolved.emit();queue_free();return
	var pending:Dictionary=run_state.get_pending_slasher_progression_choice();var level:int=int(pending.get("level",run_state.get_level()));title.text="LEVEL %d · SLASHER EVOLUTION"%level;subtitle.text="%s · %s"%[run_state.selected_class_name,run_state.get_slasher_specialization_name()]
	for value:Variant in pending.get("choices",[]):
		if not (value is Dictionary):continue
		var choice:Dictionary=value;var button:=Button.new();button.text="%s\n\n%s"%[String(choice.get("name","Upgrade")),String(choice.get("description",""))];button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.custom_minimum_size=Vector2(280,260);button.toggle_mode=true;button.pressed.connect(_select.bind(String(choice.get("id","")),button));cards.add_child(button)
	detail.text="Choose a permanent Slasher upgrade. Strategy abilities and progression are unaffected."

func _select(choice_id:String,pressed_button:Button)->void:
	selected_choice_id=choice_id
	for child:Node in cards.get_children():
		if child is Button:(child as Button).button_pressed=child==pressed_button
	var choice:Dictionary=GameBalance.get_slasher_progression_choice(run_state.selected_class_id,choice_id);var operations:Array[String]=[]
	for key_value:Variant in Dictionary(choice.get("operations",{})):
		var key:String=String(key_value).replace("_"," ").capitalize();operations.append(key)
	detail.text="[font_size=21][b]%s[/b][/font_size]\n%s\nAffected: %s%s"%[String(choice.get("name","Upgrade")),String(choice.get("description","")),String(choice.get("slot","Specialization")).capitalize()," · "+", ".join(operations) if not operations.is_empty() else ""]
	confirm_button.disabled=false;confirm_button.text="Confirm permanent choice"

func _confirm()->void:
	if selected_choice_id.is_empty():return
	run_state.choose_slasher_progression_choice(selected_choice_id);_refresh()
