extends VisitorContest

var target:Button
var target_number:=0
var stage:=""
var stage_time:=0.0
var wait_time:=0.0
var visitor_reaction:=0.0
var visitor_misses:=false
var visitor_scored:=false
var hit:=false
var reaction_total:=0.0
var hits:=0
var last_reaction:=0.0

func _init()->void:
	contest_id="quick_draw"
	instructions="Click each appearing target as quickly as you can. Twelve targets; each stays for one second. Your visitor takes a separate shot."

func _build_game()->void:
	target=button("HIT!",arena,_hit);target.custom_minimum_size=Vector2(76,54);target.size=Vector2(76,76);target.visible=false;target.focus_mode=Control.FOCUS_NONE
	for state in ["normal","hover","pressed","disabled","focus"]:target.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for state in ["font_color","font_hover_color","font_pressed_color","font_disabled_color"]:target.add_theme_color_override(state,Color.TRANSPARENT)

func _reset_game()->void:
	target_number=0;hits=0;reaction_total=0;last_reaction=0;stage="";target.visible=false

func _begin_game()->void:_next_target()

func _next_target()->void:
	if target_number>=int(RULES.TUNING.reaction_targets):finish({"hits":hits,"average_reaction":reaction_total/hits if hits>0 else 0.0});return
	target.text="HIT!"
	target_number+=1;stage="wait";stage_time=0;hit=false;target.visible=false;visitor_scored=false
	wait_time=rng.randf_range(float(RULES.TUNING.reaction_wait_min),float(RULES.TUNING.reaction_wait_max))
	visitor_reaction=clampf(float(RULES.TUNING.reaction_base)-float(RULES.TUNING.reaction_scale)*ability+rng.randf_range(-float(RULES.TUNING.reaction_jitter),float(RULES.TUNING.reaction_jitter)),0,1)
	visitor_misses=rng.randf()<float(RULES.TUNING.reaction_miss)*(1-ability)

func _tick_game(delta:float)->void:
	stage_time+=delta;status.text="Target %d/12 · You %d / Visitor %d"%[target_number,player_score,visitor_score]
	if stage=="wait" and stage_time>=wait_time:
		stage="target";stage_time=0;target.position=Vector2(rng.randf_range(42,maxf(42,arena.size.x-target.size.x-42)),rng.randf_range(42,maxf(42,arena.size.y-target.size.y-70)));target.disabled=false;target.visible=true
	elif stage=="target":
		if not visitor_scored and stage_time>=visitor_reaction:
			visitor_scored=true
			if not visitor_misses:visitor_score+=roundi(100*(1-visitor_reaction))
			feedback.text="Visitor: miss" if visitor_misses else "Visitor: %.0f ms"%(visitor_reaction*1000)
		if stage_time>=float(RULES.TUNING.reaction_lifetime):
			if not hit:stage_art.pulse((target.position+target.size/2)*Vector2(1000.0/arena.size.x,300.0/arena.size.y),"MISS",Color("#ef8572"))
			_next_target()

func _hit()->void:
	if phase!="playing" or stage!="target" or hit or stage_time>float(RULES.TUNING.reaction_lifetime):return
	last_reaction=stage_time
	stage_art.pulse((target.position+target.size/2)*Vector2(1000.0/arena.size.x,300.0/arena.size.y),"+%d"%roundi(100*(1-stage_time)),Color("#69d6c3"))
	hit=true;hits+=1;reaction_total+=stage_time;player_score+=roundi(100*(1-stage_time));target.text="%.0f ms"%(stage_time*1000);target.disabled=true

