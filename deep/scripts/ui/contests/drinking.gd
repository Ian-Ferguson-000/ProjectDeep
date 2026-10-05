extends VisitorContest

const KEYS:=[KEY_Q,KEY_W,KEY_E,KEY_R]
var cues:Array[int]=[]
var resolved:Array[bool]=[]
var round_number:=0
var round_time:=0.0
var mistakes:=0
var visitor_mistakes:=0
var accurate:=0
var visitor_accurate:=0
var survived:=0
var visitor_survived:=0
var tipped:=false
var visitor_tipped:=false
var cue_label:Label

func _init()->void:
	contest_id="drinking"
	instructions="Press Q / W / E / R as its token crosses the gold hit window. Three spills tip you over. Survive five rounds!"

func _build_game()->void:
	cue_label=Label.new();cue_label.visible=false;arena.add_child(cue_label)
	var row:=Control.new();row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);row.offset_top=-38;row.offset_bottom=-4;arena.add_child(row)
	for i in KEYS.size():
		var key:int=KEYS[i]
		var control:=button(OS.get_keycode_string(key),row,_game_key.bind(key));control.custom_minimum_size.x=80
		control.anchor_left=0.32+i*0.12;control.anchor_right=control.anchor_left;control.anchor_bottom=1;control.offset_left=-43;control.offset_right=43;control.offset_top=0;control.offset_bottom=0

func _reset_game()->void:
	visitor_cue_index=0;round_number=0;accurate=0;visitor_accurate=0;survived=0;visitor_survived=0;tipped=false;visitor_tipped=false;cue_label.text="Ready your tankard"

func _begin_game()->void:_next_round()

func _next_round()->void:
	round_number+=1;round_time=0;mistakes=0;visitor_mistakes=0;cues.clear();resolved.clear()
	for i in int(RULES.TUNING.drink_cues):cues.append(KEYS[rng.randi_range(0,3)]);resolved.append(false)

func _game_key(key:int)->void:
	if phase!="playing" or tipped or key not in KEYS:return
	for i in cues.size():
		if not resolved[i] and absf(round_time-_cue_time(i))<=float(RULES.TUNING.drink_window):
			resolved[i]=true
			if key==cues[i]:
				accurate+=1;stage_art.pulse(Vector2(320+KEYS.find(key)*120,218),"PERFECT" if absf(round_time-_cue_time(i))<0.07 else "GOOD",Color("#69d6c3"))
			else:
				mistakes+=1;stage_art.pulse(Vector2(125,115),"WRONG KEY",Color("#ef8572"))
			_check_tip();return
	mistakes+=1;stage_art.pulse(Vector2(125,115),"OFF BEAT",Color("#ef8572"));_check_tip()

func _cue_time(index:int)->float:return (index+1)*float(RULES.TUNING.drink_spacing)

func _check_tip()->void:
	if mistakes>=int(RULES.TUNING.drink_failures):tipped=true
	if visitor_mistakes>=int(RULES.TUNING.drink_failures):visitor_tipped=true

func _tick_game(delta:float)->void:
	round_time+=delta
	var pending:=-1
	for i in cues.size():
		if not resolved[i]:
			if round_time>_cue_time(i)+float(RULES.TUNING.drink_window):
				resolved[i]=true
				if not tipped:
					mistakes+=1;stage_art.pulse(Vector2(320+KEYS.find(cues[i])*120,218),"MISS",Color("#ef8572"))
			elif pending<0:pending=i
	_check_tip()
	# Visitor samples each cue once when its timing window closes.
	while visitor_cue_index<cues.size() and round_time>_cue_time(visitor_cue_index)+float(RULES.TUNING.drink_window):
		visitor_cue_index+=1
		if not visitor_tipped:
			if rng.randf()<float(RULES.TUNING.drink_success_base)+float(RULES.TUNING.drink_success_scale)*ability:visitor_accurate+=1
			else:visitor_mistakes+=1
		_check_tip()
	status.text="Round %d/5 · You: %s · Visitor: %s"%[round_number,"Tipped!" if tipped else "%d mistakes"%mistakes,"Tipped!" if visitor_tipped else "%d mistakes"%visitor_mistakes]
	if pending>=0:
		var remaining:=_cue_time(pending)-round_time
		cue_label.text="%s · %s"%[OS.get_keycode_string(cues[pending]),"NOW!" if absf(remaining)<=float(RULES.TUNING.drink_window) else "in %.2fs"%maxf(0,remaining)]
	if round_time>_cue_time(cues.size()-1)+float(RULES.TUNING.drink_window):
		if not tipped:survived+=1
		if not visitor_tipped:visitor_survived+=1
		if (tipped and visitor_tipped) or round_number>=int(RULES.TUNING.drink_rounds):
			player_score=survived*100+accurate;visitor_score=visitor_survived*100+visitor_accurate;finish({"rounds_survived":survived,"visitor_rounds_survived":visitor_survived,"accurate":accurate,"visitor_accurate":visitor_accurate});cue_label.text="You survived %d rounds · Visitor survived %d"%[survived,visitor_survived]
		else:visitor_cue_index=0;_next_round()

var visitor_cue_index:=0
