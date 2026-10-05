extends VisitorContest

var meter:ProgressBar
var pull:=0.0
var last_key:=0
var last_press:=-100.0

func _init()->void:
	contest_id="arm_wrestling"
	instructions="Alternate Q and E, or the two buttons, to pin your opponent. Keep pressing for up to 20 seconds!"

func _build_game()->void:
	meter=ProgressBar.new();meter.min_value=-1;meter.max_value=1;meter.visible=false;arena.add_child(meter)
	var row:=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER;row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);row.offset_top=-42;row.offset_bottom=-8;arena.add_child(row)
	button("Q · Left push",row,_game_key.bind(KEY_Q));button("E · Right push",row,_game_key.bind(KEY_E))

func _reset_game()->void:
	pull=0;last_key=0;last_press=-100;meter.value=0

func _game_key(key:int)->void:
	if phase!="playing" or key not in [KEY_Q,KEY_E] or key==last_key or clock-last_press<float(RULES.TUNING.arm_cooldown):return
	stage_art.pulse(Vector2(500+pull*175,100+absf(pull)*85),"",Color("#69d6c3"),0.23)
	last_key=key;last_press=clock;pull=minf(1,pull+float(RULES.TUNING.arm_push));meter.value=pull
	if pull>=1:_resolve()

func _tick_game(delta:float)->void:
	pull=maxf(-1,pull-delta*(float(RULES.TUNING.arm_pull_base)+float(RULES.TUNING.arm_pull_scale)*ability));meter.value=pull
	status.text="Keep alternating! · %.1fs left"%maxf(0,float(RULES.TUNING.arm_duration)-elapsed)
	if pull<=-1 or elapsed>=float(RULES.TUNING.arm_duration):_resolve()

func _resolve()->void:
	player_score=1 if pull>0.001 else 0;visitor_score=1 if pull< -0.001 else 0
	finish({"balance":pull,"duration":elapsed})
