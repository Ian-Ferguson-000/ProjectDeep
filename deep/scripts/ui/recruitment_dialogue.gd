extends ColorRect
class_name RecruitmentDialogue

const TAVERN_THEME:=preload("res://scripts/ui/tavern_ui_theme.gd")
const COMPATIBILITY:=preload("res://scripts/game/party_compatibility.gd")
const STAT_GRID:=preload("res://scripts/ui/adventurer_stat_grid.gd")
const SECTION_COLOR:=Color("#d8a642")
const BODY_COLOR:=Color("#ead9b8")
const MUTED_COLOR:=Color("#a99678")
const FIT_COLORS:=STAT_GRID.FIT_COLORS

signal recruit_requested(candidate_id:String)
signal contest_requested(candidate_id:String,contest_id:String)
signal conversation_closed
signal capacity_error(message:String)
signal assessment_requested(candidate_id:String,action:String,stat_id:String)

var candidate_id:=""
var current_candidate:CandidateRecord
## Classes the keeper may assign. Set by the tavern before opening.
var allowed_classes:Array[String]=[]
## The class the keeper has chosen for this candidate; read when recruiting.
var selected_class_id:=""

var dialogue_panel:PanelContainer
var title_label:Label
var tags_row:HBoxContainer
var fee_label:Label
var portrait:TextureRect
var identity_box:VBoxContainer
var stat_grid:AdventurerStatGrid
var knowledge_label:Label
var build_label:Label
var motivation_label:Label
var story_label:Label
var preference_label:Label
var detail_label:Label
var result_panel:PanelContainer
var result_label:Label
var error_label:Label
var observe_button:Button
var talk_button:Button
var compete_button:Button
var contest_choices:HBoxContainer
var appraisal_picker:OptionButton
var class_picker:OptionButton
var class_fit_label:Label
var recruit_button:Button

func _ready()->void:
	name="RecruitmentDialogue";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);color=Color(0.01,0.008,0.006,0.82);mouse_filter=Control.MOUSE_FILTER_STOP;visible=false
	dialogue_panel=PanelContainer.new();dialogue_panel.set_anchors_preset(Control.PRESET_TOP_LEFT);dialogue_panel.add_theme_stylebox_override("panel",TAVERN_THEME.panel(Color("#21160ffb"),TAVERN_THEME.GOLD,6,2));add_child(dialogue_panel);_layout_panel();get_viewport().size_changed.connect(_layout_panel)
	var margin:=MarginContainer.new()
	for side in ["left","right"]:margin.add_theme_constant_override("margin_%s"%side,22)
	for side in ["top","bottom"]:margin.add_theme_constant_override("margin_%s"%side,16)
	dialogue_panel.add_child(margin)
	var body:=VBoxContainer.new();body.add_theme_constant_override("separation",10);margin.add_child(body)
	_build_header(body)
	body.add_child(_divider())
	var main:=HBoxContainer.new();main.size_flags_vertical=Control.SIZE_EXPAND_FILL;main.add_theme_constant_override("separation",20);body.add_child(main)
	_build_identity_column(main)
	_build_detail_column(main)
	body.add_child(_divider())
	error_label=Label.new();error_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;error_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;error_label.add_theme_color_override("font_color",Color(1.0,0.48,0.4));error_label.hide();body.add_child(error_label)
	_build_scouting_row(body)
	_build_signing_row(body)

func _build_header(parent:VBoxContainer)->void:
	var header:=HBoxContainer.new();header.add_theme_constant_override("separation",16);parent.add_child(header)
	var titles:=VBoxContainer.new();titles.size_flags_horizontal=Control.SIZE_EXPAND_FILL;titles.add_theme_constant_override("separation",6);header.add_child(titles)
	title_label=Label.new();title_label.add_theme_font_size_override("font_size",28);title_label.add_theme_color_override("font_color",TAVERN_THEME.HIGHLIGHT_GOLD);titles.add_child(title_label)
	tags_row=HBoxContainer.new();tags_row.add_theme_constant_override("separation",8);titles.add_child(tags_row)
	var fee_box:=VBoxContainer.new();fee_box.alignment=BoxContainer.ALIGNMENT_CENTER;header.add_child(fee_box)
	var fee_caption:=_text("Signing fee",13,MUTED_COLOR);fee_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;fee_box.add_child(fee_caption)
	fee_label=_text("",24,TAVERN_THEME.HIGHLIGHT_GOLD);fee_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;fee_label.tooltip_text="Paid once on signing. The party also shares 20% of the gold it brings home.";fee_label.mouse_filter=Control.MOUSE_FILTER_PASS;fee_box.add_child(fee_label)

func _build_identity_column(parent:HBoxContainer)->void:
	var column:=VBoxContainer.new();column.custom_minimum_size=Vector2(190,0);column.add_theme_constant_override("separation",8);parent.add_child(column)
	portrait=TextureRect.new();portrait.custom_minimum_size=Vector2(190,190);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;column.add_child(portrait)
	identity_box=VBoxContainer.new();identity_box.add_theme_constant_override("separation",3);column.add_child(identity_box)

func _build_detail_column(parent:HBoxContainer)->void:
	var scroll:=ScrollContainer.new();scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;parent.add_child(scroll)
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",8);scroll.add_child(column)
	var stats_heading:=HBoxContainer.new();column.add_child(stats_heading)
	var heading:=_section("Attributes");heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;stats_heading.add_child(heading)
	knowledge_label=_text("",13,MUTED_COLOR);knowledge_label.size_flags_vertical=Control.SIZE_SHRINK_END;stats_heading.add_child(knowledge_label)
	stat_grid=STAT_GRID.new(false);stat_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_child(stat_grid)
	column.add_child(_text("Gold bars are appraised. Faint bars are estimates. Observe, compete, or appraise to learn more.",12,MUTED_COLOR,true))
	build_label=_text("",15,BODY_COLOR,true);column.add_child(build_label)
	column.add_child(_section("In their words"))
	motivation_label=_text("",16,BODY_COLOR,true);column.add_child(motivation_label)
	column.add_child(_section("Story"))
	story_label=_text("",15,BODY_COLOR,true);column.add_child(story_label)
	preference_label=_text("",14,MUTED_COLOR,true);column.add_child(preference_label)
	# Kept for callers that read the full dossier as text.
	detail_label=_text("",1,BODY_COLOR,true);detail_label.visible=false;column.add_child(detail_label)
	result_panel=PanelContainer.new();result_panel.add_theme_stylebox_override("panel",TAVERN_THEME.panel(Color("#2b1d12"),Color("#6b4a26"),4,1));column.add_child(result_panel)
	result_label=_text("",14,BODY_COLOR,true);result_panel.add_child(result_label)

func _build_scouting_row(parent:VBoxContainer)->void:
	var row:=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER;row.add_theme_constant_override("separation",8);parent.add_child(row)
	var caption:=_text("Learn more",15,SECTION_COLOR);caption.custom_minimum_size=Vector2(110,0);row.add_child(caption)
	observe_button=_action_button("Observe",row,"observe");observe_button.tooltip_text="Watch them work. Reveals their gear and temperament."
	talk_button=_action_button("Talk",row,"talk");talk_button.tooltip_text="Share a drink. Reveals where they come from and their story."
	compete_button=Button.new();compete_button.text="Compete";compete_button.tooltip_text="Play a tavern game against them to estimate one attribute.";TAVERN_THEME.apply_button(compete_button,false,13,Vector2(105,40));row.add_child(compete_button)
	appraisal_picker=OptionButton.new();appraisal_picker.custom_minimum_size=Vector2(150,40)
	for stat in AdventurerBuilds.ATTRIBUTE_IDS:appraisal_picker.add_item(String(STAT_GRID.STAT_NAMES[stat]));appraisal_picker.set_item_metadata(appraisal_picker.item_count-1,stat)
	appraisal_picker.tooltip_text="Choose an attribute for an exact appraisal.";row.add_child(appraisal_picker)
	var appraise:=Button.new();appraise.text="Appraise · 12g";appraise.tooltip_text="Pay a specialist to learn this attribute exactly.";appraise.pressed.connect(func():assessment_requested.emit(candidate_id,"appraise",String(appraisal_picker.get_selected_metadata())));TAVERN_THEME.apply_button(appraise,false,13,Vector2(130,40));row.add_child(appraise)
	contest_choices=HBoxContainer.new();contest_choices.alignment=BoxContainer.ALIGNMENT_CENTER;parent.add_child(contest_choices);contest_choices.visible=false
	compete_button.pressed.connect(func():contest_choices.visible=not contest_choices.visible)
	for id in VisitorContestRules.CONTESTS:
		var definition:Dictionary=VisitorContestRules.CONTESTS[id];var choice:=Button.new();choice.text="%s · %s"%[definition.name,String(STAT_GRID.STAT_NAMES.get(String(definition.stat),String(definition.stat).to_upper()))];TAVERN_THEME.apply_button(choice,false,12,Vector2(0,38));contest_choices.add_child(choice);choice.pressed.connect(func():contest_requested.emit(candidate_id,id))

func _build_signing_row(parent:VBoxContainer)->void:
	var row:=HBoxContainer.new();row.name="ClassAssignment";row.alignment=BoxContainer.ALIGNMENT_CENTER;row.add_theme_constant_override("separation",10);parent.add_child(row)
	var caption:=_text("Train as",15,SECTION_COLOR);caption.custom_minimum_size=Vector2(110,0);row.add_child(caption)
	class_picker=OptionButton.new();class_picker.name="ClassPicker";class_picker.custom_minimum_size=Vector2(260,44);class_picker.tooltip_text="Choose the class this adventurer will train as. Fit is estimated from what you have learned about them.";class_picker.item_selected.connect(_on_class_selected);row.add_child(class_picker)
	class_fit_label=_text("",16,BODY_COLOR);class_fit_label.custom_minimum_size=Vector2(150,0);row.add_child(class_fit_label)
	var later:=Button.new();later.text="Not Yet";later.pressed.connect(close);TAVERN_THEME.apply_button(later,false,15,Vector2(120,44));row.add_child(later)
	recruit_button=Button.new();recruit_button.text="Sign";recruit_button.pressed.connect(func():recruit_requested.emit(candidate_id));TAVERN_THEME.apply_button(recruit_button,true,15,Vector2(190,44));row.add_child(recruit_button)

func _layout_panel()->void:
	if dialogue_panel==null:return
	var viewport_size:=get_viewport_rect().size;var available:=viewport_size-Vector2(36,36);dialogue_panel.size=Vector2(minf(1000,available.x),minf(670,available.y));dialogue_panel.position=(viewport_size-dialogue_panel.size)/2.0

func open(candidate:CandidateRecord)->void:
	var reopening:=candidate_id==candidate.id and not selected_class_id.is_empty()
	current_candidate=candidate;candidate_id=candidate.id;error_label.text="";error_label.hide();var member:=candidate.adventurer
	if not reopening:selected_class_id=member.class_id
	var known:=candidate.knowledge
	title_label.text="%s %s"%[member.display_name,member.family_name]
	_fill_tags(member)
	fee_label.text="%dg"%member.signing_fee if member.signing_fee>0 else "Free"
	_fill_identity(candidate)
	stat_grid.show_candidate(candidate)
	var exact:=AdventurerBuilds.ATTRIBUTE_IDS.filter(func(stat):return String(known.get(stat,""))=="exact").size()
	knowledge_label.text="%d of 6 appraised"%exact
	var build:=AdventurerBuilds.build(member.stat_build_id)
	build_label.text="%s: %s"%[String(build.get("name","")),String(build.get("description",""))] if not build.is_empty() else ""
	build_label.visible=not build.is_empty()
	motivation_label.text="“%s”"%candidate.motivation
	story_label.text=member.biography if String(known.get("biography","unknown"))=="exact" else "Unknown. Talk with them to hear it."
	story_label.add_theme_color_override("font_color",BODY_COLOR if String(known.get("biography","unknown"))=="exact" else MUTED_COLOR)
	preference_label.text="Prefers %s."%member.preference if String(known.get("preference","unknown"))=="exact" else ""
	preference_label.visible=not preference_label.text.is_empty()
	result_label.text=candidate.last_result;result_panel.visible=not candidate.last_result.is_empty()
	detail_label.text="%s\n%s\n%s\n%s"%[build_label.text,motivation_label.text,story_label.text,candidate.last_result]
	observe_button.disabled=candidate.completed_interactions.has("observe");talk_button.disabled=candidate.completed_interactions.has("talk");contest_choices.visible=false
	_populate_class_picker()
	visible=true;move_to_front();recruit_button.grab_focus()

func _fill_tags(member:CharacterRecord)->void:
	for child in tags_row.get_children():tags_row.remove_child(child);child.queue_free()
	if not member.stat_build_id.is_empty():_tag(AdventurerBuilds.build_name(member.stat_build_id),String(AdventurerBuilds.build(member.stat_build_id).get("description","")),true)
	_tag("Level %d"%member.level,"Experience they bring to the company.")
	_tag(member.trait_name,member.trait_description)
	_tag("Hopes to be a %s"%member.calling_class_id.capitalize(),"Their calling. You can train them as any class you have unlocked.")

func _tag(text_value:String,tooltip:String,highlight:=false)->void:
	var panel:=PanelContainer.new();panel.tooltip_text=tooltip;panel.mouse_filter=Control.MOUSE_FILTER_PASS
	var style:=TAVERN_THEME.panel(Color("#3a2716") if highlight else Color("#2a1c12"),Color("#a87a35") if highlight else Color("#5a4129"),10,1);style.set_content_margin(SIDE_LEFT,10);style.set_content_margin(SIDE_RIGHT,10);style.set_content_margin(SIDE_TOP,3);style.set_content_margin(SIDE_BOTTOM,3)
	panel.add_theme_stylebox_override("panel",style)
	panel.add_child(_text(text_value,14,TAVERN_THEME.HIGHLIGHT_GOLD if highlight else BODY_COLOR));tags_row.add_child(panel)

func _fill_identity(candidate:CandidateRecord)->void:
	for child in identity_box.get_children():identity_box.remove_child(child);child.queue_free()
	var member:=candidate.adventurer;var known:=candidate.knowledge
	var talked:=String(known.get("origin","unknown"))=="exact"
	var weapon:=member.gear_id.replace("_"," ").capitalize()
	_fact("From",member.origin if talked else "?")
	_fact("Nation",NarrativeContent.nation_name(member.nation_id) if talked else "?")
	_fact("Doctrine",COMPATIBILITY.doctrine_name(member.doctrine_id) if talked else "?")
	_fact("Pronouns",member.pronouns if talked else "?")
	_fact("Carrying",weapon if String(known.get("equipment","hint"))=="exact" else "%s?"%weapon)
	_fact("Learning",VisitorContestRules.learning_name(member.learning_potential) if member.learning_potential_known else "?")
	if member.generation>1:_fact("Lineage","Generation %d"%member.generation)

func _fact(label_text:String,value:String)->void:
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",6);identity_box.add_child(row)
	var label:=_text(label_text,13,MUTED_COLOR);label.custom_minimum_size=Vector2(70,0);row.add_child(label)
	var value_label:=_text(value,13,BODY_COLOR if value!="?" else MUTED_COLOR,true);value_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(value_label)

func _action_button(text_value:String,parent:HBoxContainer,action:String)->Button:
	var button:=Button.new();button.text=text_value;button.pressed.connect(func():assessment_requested.emit(candidate_id,action,""));TAVERN_THEME.apply_button(button,false,13,Vector2(105,40));parent.add_child(button);return button

func _populate_class_picker()->void:
	var member:=current_candidate.adventurer
	var options:Array[String]=allowed_classes.duplicate() if not allowed_classes.is_empty() else [member.class_id]
	if not options.has(member.class_id):options.push_front(member.class_id)
	if not options.has(selected_class_id):selected_class_id=member.class_id
	class_picker.clear()
	for class_id in options:
		var label:=class_id.capitalize()+("  ★ calling" if class_id==member.calling_class_id else "")
		class_picker.add_item(label);class_picker.set_item_metadata(class_picker.item_count-1,class_id)
		var icon:=TAVERN_THEME.class_icon(class_id);if icon!=null:class_picker.set_item_icon(class_picker.item_count-1,icon)
		if class_id==selected_class_id:class_picker.select(class_picker.item_count-1)
	class_picker.add_theme_constant_override("icon_max_width",24)
	_refresh_class_choice()

func _on_class_selected(index:int)->void:
	selected_class_id=String(class_picker.get_item_metadata(index));_refresh_class_choice()

func _refresh_class_choice()->void:
	var member:=current_candidate.adventurer
	var portrait_path:="res://assets/roster_portraits/%s_%d.png"%[selected_class_id,member.portrait_variant];portrait.texture=load(portrait_path) if ResourceLoader.exists(portrait_path) else null
	var grade:=AdventurerBuilds.class_fit(AdventurerBuilds.estimated_attributes(current_candidate),selected_class_id)
	class_fit_label.text="%s fit"%grade;class_fit_label.add_theme_color_override("font_color",FIT_COLORS.get(grade,BODY_COLOR))
	class_fit_label.tooltip_text="How well their known attributes suit a %s. Learn more about them to sharpen this estimate."%selected_class_id.capitalize();class_fit_label.mouse_filter=Control.MOUSE_FILTER_PASS
	recruit_button.text="Sign as %s"%selected_class_id.capitalize()

func _lead_stat(member:CharacterRecord)->String:return AdventurerBuilds.lead_stat(member.attributes,member.stat_build_id)
func _stat_display(candidate:CandidateRecord,stat:String)->String:
	var lead:=_lead_stat(candidate.adventurer)
	var state:=String(candidate.knowledge.get(stat,candidate.knowledge.get("primary_stat","unknown") if stat==lead else "unknown"));var value:=int(candidate.adventurer.attributes.get(stat,10))
	if state=="exact":return str(value)
	for contest_id in VisitorContestRules.CONTESTS:
		if String(VisitorContestRules.CONTESTS[contest_id].stat)==stat and candidate.completed_interactions.has("contest:%s"%contest_id):return VisitorContestRules.stat_range(value)+" est."
	if state=="band" or stat==lead:return VisitorContestRules.band(value)
	return "Unknown"

func _section(text_value:String)->Label:
	return _text(text_value.to_upper(),13,SECTION_COLOR)

func _text(text_value:String,size:int,color:Color,wrap:=false)->Label:
	var label:=Label.new();label.text=text_value;label.add_theme_font_size_override("font_size",size);label.add_theme_color_override("font_color",color)
	if wrap:label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return label

func _divider()->HSeparator:
	var line:=HSeparator.new();var style:=StyleBoxLine.new();style.color=Color("#5a412966");style.thickness=1;line.add_theme_stylebox_override("separator",style);return line

func show_capacity_error(message:String)->void:
	error_label.show();error_label.text=message;capacity_error.emit(message);recruit_button.grab_focus()

func close()->void:
	visible=false;conversation_closed.emit()

func _unhandled_input(event:InputEvent)->void:
	if visible and event.is_action_pressed("ui_cancel"):get_viewport().set_input_as_handled();close()
