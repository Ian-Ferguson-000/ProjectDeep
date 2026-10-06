extends ColorRect
class_name VisitorContest

signal completed(result:Dictionary)
signal cancelled

const THEME := preload("res://scripts/ui/tavern_ui_theme.gd")
const RULES := preload("res://scripts/game/visitor_contest_rules.gd")
const COUNTDOWN := preload("res://scripts/ui/contests/contest_countdown.gd")
const STAGE := preload("res://scripts/ui/contests/contest_stage.gd")
var context:Dictionary={}
var contest_id:=""
var instructions:=""
var phase:="instructions"
var elapsed:=0.0
var clock:=0.0
var rng:=RandomNumberGenerator.new()
var ability:=0.0
var player_score:=0
var visitor_score:=0
var body:VBoxContainer
var arena:Control
var status:Label
var feedback:Label
var start_button:Button
var replay_button:Button
var panel:PanelContainer
var attempt:=0
var countdown_art:Control
var stage_art:Control
var score_labels:Array[Label]=[]
var result_tween:Tween

func setup(value:Dictionary)->void:
	context=value.duplicate(true)
	ability=RULES.ability(int(context.get("attribute",10)))
	rng.seed=int(context.get("seed",Time.get_ticks_usec()))

func _ready()->void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color=Color("#080e10f7");mouse_filter=Control.MOUSE_FILTER_STOP
	panel=PanelContainer.new();panel.add_theme_stylebox_override("panel",THEME.panel(Color("#202525"),THEME.GOLD,12,2));add_child(panel)
	body=VBoxContainer.new();body.alignment=BoxContainer.ALIGNMENT_CENTER;body.add_theme_constant_override("separation",6);panel.add_child(body)
	var eyebrow:=Label.new();eyebrow.text="THE HEARTH  /  FRIENDLY RIVALRIES";eyebrow.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;eyebrow.add_theme_font_size_override("font_size",11);eyebrow.add_theme_color_override("font_color",THEME.MUTED);body.add_child(eyebrow)
	var title:=Label.new();title.text=RULES.CONTESTS[contest_id].name;title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",25);title.add_theme_color_override("font_color",THEME.HIGHLIGHT_GOLD);body.add_child(title)
	var people:=HBoxContainer.new();people.alignment=BoxContainer.ALIGNMENT_CENTER;people.add_theme_constant_override("separation",18);body.add_child(people)
	for person in [{"name":"You · Tavern Keeper","portrait":"res://assets/merchants/tavern_mara.png"},{"name":context.get("visitor_name","Visitor"),"portrait":context.get("portrait","")}]:
		if not score_labels.is_empty():
			var versus:=Label.new();versus.text="VS";versus.add_theme_color_override("font_color",THEME.GOLD);people.add_child(versus)
		var card:=PanelContainer.new();card.custom_minimum_size.x=240;card.add_theme_stylebox_override("panel",THEME.panel(Color("#172121"),Color("#50665f"),6));people.add_child(card)
		var row:=HBoxContainer.new();card.add_child(row)
		var portrait:=TextureRect.new();portrait.custom_minimum_size=Vector2(44,48);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(String(person.portrait)):portrait.texture=load(String(person.portrait))
		row.add_child(portrait)
		var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(column)
		var caption:=Label.new();caption.text=String(person.name);caption.add_theme_font_size_override("font_size",14);column.add_child(caption)
		var score:=Label.new();score.text="Ready to compete";score.add_theme_font_size_override("font_size",12);score.add_theme_color_override("font_color",Color("#69d6c3") if score_labels.is_empty() else Color("#90b8eb"));column.add_child(score);score_labels.append(score)
	var help:=Label.new();help.text=instructions;help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;help.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;help.add_theme_font_size_override("font_size",13);help.add_theme_color_override("font_color",THEME.IVORY);body.add_child(help)
	status=Label.new();status.text="A friendly test of %s · No stakes, just bragging rights"%String(RULES.CONTESTS[contest_id].stat).to_upper();status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;status.add_theme_font_size_override("font_size",14);status.add_theme_color_override("font_color",THEME.HIGHLIGHT_GOLD);body.add_child(status)
	arena=Control.new();arena.custom_minimum_size=Vector2(0,280);arena.size_flags_vertical=Control.SIZE_FILL;body.add_child(arena)
	stage_art=STAGE.new();stage_art.game=self;arena.add_child(stage_art)
	feedback=Label.new();feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;feedback.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;feedback.add_theme_font_size_override("font_size",13);feedback.add_theme_color_override("font_color",THEME.IVORY);body.add_child(feedback)
	var buttons:=HBoxContainer.new();buttons.alignment=BoxContainer.ALIGNMENT_CENTER;body.add_child(buttons)
	start_button=button("Start",buttons,start)
	replay_button=button("Replay",buttons,start);replay_button.visible=false
	button("Return to Visitor",buttons,leave)
	_build_game()
	countdown_art=COUNTDOWN.new();countdown_art.game=self;arena.add_child(countdown_art)
	get_viewport().size_changed.connect(_layout);body.minimum_size_changed.connect(_layout);_layout();start_button.grab_focus()

func _layout()->void:
	var available:=get_viewport_rect().size-Vector2(24,24)
	panel.size=Vector2(minf(1040,available.x),minf(680,available.y));panel.position=(get_viewport_rect().size-panel.size)/2.0
	# Preserve the drawn board's aspect instead of stretching circles and typography.
	if arena!=null:arena.custom_minimum_size.y=maxf(280,(panel.size.x-16)*0.3)

func button(text_value:String,parent:Node,callback:Callable)->Button:
	var node:=Button.new();node.text=text_value;THEME.apply_button(node,false,14,Vector2(120,34));node.pressed.connect(callback);parent.add_child(node);return node

func start()->void:
	attempt+=1;player_score=0;visitor_score=0;elapsed=0;clock=0;phase="countdown"
	start_button.visible=false;replay_button.visible=false;feedback.text="";_reset_game()
	stage_art.reset()
	if result_tween!=null:result_tween.kill()
	feedback.modulate=Color.WHITE
	# Remove keyboard focus from clickable controls during keyboard contests.
	var focused:=get_viewport().gui_get_focus_owner()
	if focused!=null:focused.release_focus()

func _process(delta:float)->void:
	clock+=delta
	_update_scores()
	if phase=="countdown":
		elapsed+=delta;status.text="Starting in %d…"%maxi(1,ceili(float(RULES.TUNING.countdown)-elapsed))
		if elapsed>=float(RULES.TUNING.countdown):phase="playing";elapsed=0;status.text="Go!";_begin_game()
	elif phase=="playing":elapsed+=delta;_tick_game(delta)

func finish(details:Dictionary={})->void:
	if phase!="playing":return
	phase="results"
	var outcome:="win" if player_score>visitor_score else ("loss" if player_score<visitor_score else "draw")
	status.text="%s · You %d / Visitor %d"%[outcome.capitalize(),player_score,visitor_score]
	feedback.text="%s: %s · Learning potential: %s"%[String(RULES.CONTESTS[contest_id].stat).to_upper(),RULES.stat_analysis(int(context.get("attribute",10)),bool(context.get("attribute_known_exact",false))),RULES.learning_name(String(context.get("learning_potential","steady")))]
	replay_button.visible=true;replay_button.grab_focus()
	_update_scores()
	feedback.modulate=Color(1,1,1,0)
	result_tween=create_tween();result_tween.tween_property(feedback,"modulate:a",1.0,0.35)
	stage_art.pulse(Vector2(500,130),"",Color("#69d6c3") if outcome=="win" else THEME.GOLD)
	AudioCue.play_from(self,"victory" if outcome=="win" else ("reward" if outcome=="draw" else "ui_error"),false)
	completed.emit({"contest_id":contest_id,"outcome":outcome,"player_score":player_score,"visitor_score":visitor_score,"details":details})

func _update_scores()->void:
	if score_labels.size()!=2:return
	var values:=[player_score,visitor_score]
	for i in 2:
		if contest_id=="drinking":
			var rounds:int=int(get("survived" if i==0 else "visitor_survived"))
			var hits:int=int(get("accurate" if i==0 else "visitor_accurate"))
			score_labels[i].text="%d rounds · %d clean hits"%[rounds,hits]
		elif contest_id=="arm_wrestling":score_labels[i].text="Testing strength" if phase!="results" else ("Winner" if values[i]==1 else "Contender")
		else:score_labels[i].text="%d points"%values[i]

func leave()->void:
	phase="closed";cancelled.emit()

func _input(event:InputEvent)->void:
	if phase=="closed":return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled();leave();return
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo:
			if phase=="playing":_game_key(event.physical_keycode)
			elif phase=="instructions" and event.physical_keycode==KEY_ENTER:start()
			elif phase=="results" and event.physical_keycode==KEY_ENTER:start()

func _build_game()->void:pass
func _reset_game()->void:pass
func _begin_game()->void:pass
func _tick_game(_delta:float)->void:pass
func _game_key(_key:int)->void:pass
