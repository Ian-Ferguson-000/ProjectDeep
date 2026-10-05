extends ColorRect
class_name RecruitmentDialogue

const TAVERN_THEME:=preload("res://scripts/ui/tavern_ui_theme.gd")
const COMPATIBILITY:=preload("res://scripts/game/party_compatibility.gd")

signal recruit_requested(candidate_id:String)
signal contest_requested(candidate_id:String,contest_id:String)
signal conversation_closed
signal capacity_error(message:String)
signal assessment_requested(candidate_id:String,action:String,stat_id:String)

var candidate_id:=""
var title_label:Label
var detail_label:Label
var error_label:Label
var recruit_button:Button
var portrait:TextureRect
var dialogue_panel:PanelContainer
var current_candidate:CandidateRecord
var observe_button:Button
var talk_button:Button
var compete_button:Button
var contest_choices:HBoxContainer
var appraisal_picker:OptionButton

func _ready()->void:
	name="RecruitmentDialogue";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);color=Color(0.01,0.008,0.006,0.82);mouse_filter=Control.MOUSE_FILTER_STOP;visible=false
	dialogue_panel=PanelContainer.new();dialogue_panel.set_anchors_preset(Control.PRESET_TOP_LEFT);dialogue_panel.add_theme_stylebox_override("panel",TAVERN_THEME.panel(Color("#21160ffb"),TAVERN_THEME.GOLD,6,2));add_child(dialogue_panel);_layout_panel();get_viewport().size_changed.connect(_layout_panel)
	var margin:=MarginContainer.new()
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_%s"%side,22)
	dialogue_panel.add_child(margin)
	var body:=VBoxContainer.new();body.add_theme_constant_override("separation",14);margin.add_child(body)
	title_label=Label.new();title_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title_label.add_theme_font_size_override("font_size",28);title_label.add_theme_color_override("font_color",TAVERN_THEME.HIGHLIGHT_GOLD);body.add_child(title_label)
	var profile:=HBoxContainer.new();profile.size_flags_vertical=Control.SIZE_EXPAND_FILL;profile.add_theme_constant_override("separation",20);body.add_child(profile)
	portrait=TextureRect.new();portrait.custom_minimum_size=Vector2(160,180);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;profile.add_child(portrait)
	var detail_scroll:=ScrollContainer.new();detail_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;profile.add_child(detail_scroll)
	detail_label=Label.new();detail_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_label.size_flags_vertical=Control.SIZE_EXPAND_FILL;detail_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;detail_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;detail_label.add_theme_font_size_override("font_size",17);detail_scroll.add_child(detail_label)
	error_label=Label.new();error_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;error_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;error_label.add_theme_color_override("font_color",Color(1.0,0.48,0.4));body.add_child(error_label)
	var assessment:=HBoxContainer.new();assessment.alignment=BoxContainer.ALIGNMENT_CENTER;assessment.add_theme_constant_override("separation",8);body.add_child(assessment)
	observe_button=_action_button("Observe",assessment,"observe");talk_button=_action_button("Talk",assessment,"talk")
	compete_button=Button.new();compete_button.text="Compete";TAVERN_THEME.apply_button(compete_button,false,13,Vector2(105,40));assessment.add_child(compete_button)
	contest_choices=HBoxContainer.new();contest_choices.alignment=BoxContainer.ALIGNMENT_CENTER;body.add_child(contest_choices);contest_choices.visible=false
	compete_button.pressed.connect(func():contest_choices.visible=not contest_choices.visible)
	for id in VisitorContestRules.CONTESTS:
		var definition:Dictionary=VisitorContestRules.CONTESTS[id];var choice:=Button.new();choice.text="%s · %s"%[definition.name,String(definition.stat).to_upper()];TAVERN_THEME.apply_button(choice,false,12,Vector2(0,38));contest_choices.add_child(choice);choice.pressed.connect(func():contest_requested.emit(candidate_id,id))
	appraisal_picker=OptionButton.new();for stat in ["str","dex","con","int","wis","cha"]:appraisal_picker.add_item(stat.to_upper());appraisal_picker.set_item_metadata(appraisal_picker.item_count-1,stat)
	appraisal_picker.tooltip_text="Choose an attribute for exact appraisal (12 gold).";assessment.add_child(appraisal_picker)
	var appraise:=Button.new();appraise.text="Appraise · 12g";appraise.pressed.connect(func():assessment_requested.emit(candidate_id,"appraise",String(appraisal_picker.get_selected_metadata())));TAVERN_THEME.apply_button(appraise,false,13,Vector2(130,40));assessment.add_child(appraise)
	var buttons:=HBoxContainer.new();buttons.alignment=BoxContainer.ALIGNMENT_CENTER;buttons.add_theme_constant_override("separation",16);body.add_child(buttons)
	var later:=Button.new();later.text="Not Yet";later.pressed.connect(close);TAVERN_THEME.apply_button(later,false,16,Vector2(220,48));buttons.add_child(later)
	recruit_button=Button.new();recruit_button.text="Recruit — Free";recruit_button.pressed.connect(func():recruit_requested.emit(candidate_id));TAVERN_THEME.apply_button(recruit_button,true,16,Vector2(220,48));buttons.add_child(recruit_button)

func _layout_panel()->void:
	if dialogue_panel==null:return
	var viewport_size:=get_viewport_rect().size;var available:=viewport_size-Vector2(36,36);dialogue_panel.size=Vector2(minf(900,available.x),minf(650,available.y));dialogue_panel.position=(viewport_size-dialogue_panel.size)/2.0

func open(candidate:CandidateRecord)->void:
	current_candidate=candidate;candidate_id=candidate.id;error_label.text="";error_label.hide();var member:=candidate.adventurer
	var weapon:=member.gear_id.replace("_"," ").capitalize()
	var portrait_path:="res://assets/roster_portraits/%s_%d.png"%[member.class_id,member.portrait_variant];portrait.texture=load(portrait_path) if ResourceLoader.exists(portrait_path) else null
	title_label.text="%s %s · %s"%[member.display_name,member.family_name,member.class_id.capitalize()]
	var known:=candidate.knowledge
	var identity_known:=String(known.get("origin","unknown"))=="exact"
	var identity:="%s · %s · %s · %s · Generation %d"%[member.pronouns if identity_known else "Pronouns unknown",NarrativeContent.nation_name(member.nation_id) if identity_known else "Nation unknown",COMPATIBILITY.doctrine_name(member.doctrine_id) if identity_known else "Doctrine unknown",member.origin if identity_known else "Origin unknown",member.generation]
	var aptitude:=""
	for stat in ["str","int","dex","con","wis","cha"]:
		aptitude+="%s %s   "%[stat.to_upper(),_stat_display(candidate,stat)]
		if stat=="dex":aptitude+="\n"
	aptitude+="\nLearning potential: "+(VisitorContestRules.learning_name(member.learning_potential) if member.learning_potential_known else "Unknown — try a contest.")
	var story:=member.biography if String(known.get("biography","unknown"))=="exact" else "Backstory unknown — talk with this adventurer."
	var preference:=member.preference if String(known.get("preference","unknown"))=="exact" else "Preference unknown"
	detail_label.text="Level %d     %s\n%s\nBasic weapon: %s\n%s\n\n%s\nPrefers: %s\n\n“%s”\n\n%s"%[member.level,member.trait_name,identity,weapon if String(known.get("equipment","hint"))=="exact" else "Visible %s"%weapon,aptitude,story,preference,candidate.motivation,candidate.last_result]
	observe_button.disabled=candidate.completed_interactions.has("observe");talk_button.disabled=candidate.completed_interactions.has("talk");contest_choices.visible=false
	recruit_button.text="Sign · %dg" % member.signing_fee
	detail_label.text += "\n\nContract: %dg signing fee; party shares 20%% of returned gold." % member.signing_fee
	visible=true;move_to_front();recruit_button.grab_focus()

func _action_button(text_value:String,parent:HBoxContainer,action:String)->Button:
	var button:=Button.new();button.text=text_value;button.pressed.connect(func():assessment_requested.emit(candidate_id,action,""));TAVERN_THEME.apply_button(button,false,13,Vector2(105,40));parent.add_child(button);return button
func _primary_stat(class_id:String)->String:return {"warrior":"str","tank":"con","rogue":"dex","mage":"int","healer":"wis","summoner":"wis"}.get(class_id,"str")
func _stat_display(candidate:CandidateRecord,stat:String)->String:
	var state:=String(candidate.knowledge.get(stat,candidate.knowledge.get("primary_stat","unknown") if stat==_primary_stat(candidate.adventurer.class_id) else "unknown"));var value:=int(candidate.adventurer.attributes.get(stat,10))
	if state=="exact":return str(value)
	for contest_id in VisitorContestRules.CONTESTS:
		if String(VisitorContestRules.CONTESTS[contest_id].stat)==stat and candidate.completed_interactions.has("contest:%s"%contest_id):return VisitorContestRules.stat_range(value)+" est."
	if state=="band" or stat==_primary_stat(candidate.adventurer.class_id):return VisitorContestRules.band(value)
	return "Unknown"

func show_capacity_error(message:String)->void:
	error_label.show();error_label.text=message;capacity_error.emit(message);recruit_button.grab_focus()

func close()->void:
	visible=false;conversation_closed.emit()

func _unhandled_input(event:InputEvent)->void:
	if visible and event.is_action_pressed("ui_cancel"):get_viewport().set_input_as_handled();close()
