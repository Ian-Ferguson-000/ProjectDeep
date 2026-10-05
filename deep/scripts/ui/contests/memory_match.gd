extends VisitorContest

var tiles:Array[Button]=[]
var pattern:Array[int]=[]
var selections:Array[int]=[]
var visitor_selections:Array[int]=[]
var round_number:=0
var stage:=""
var stage_time:=0.0
var submit:Button
var round_review:Label
var next_round:Button
var tile_tweens:Array[Tween]=[]
var visitor_marks:Array[Panel]=[]

func _init()->void:
	contest_id="memory_match"
	instructions="Remember the numbered tiles that light up. Select them after they fade, then Submit. Wrong selections lose points. Five rounds!"

func _build_game()->void:
	var box:=VBoxContainer.new();box.anchor_left=0.5;box.anchor_right=0.5;box.anchor_bottom=1;box.offset_left=-190;box.offset_right=190;box.offset_top=12;box.offset_bottom=-8;arena.add_child(box)
	var grid:=GridContainer.new();grid.columns=4;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);grid.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;box.add_child(grid)
	for i in 16:
		var tile:=button(str(i+1),grid,_select.bind(i));tile.custom_minimum_size=Vector2(84,42);tile.add_theme_font_size_override("font_size",16);tiles.append(tile);tile_tweens.append(null)
		var mark:=Panel.new();mark.mouse_filter=Control.MOUSE_FILTER_IGNORE;mark.anchor_left=1;mark.anchor_right=1;mark.offset_left=-13;mark.offset_right=-6;mark.offset_top=6;mark.offset_bottom=13;mark.add_theme_stylebox_override("panel",THEME.panel(Color("#90b8eb"),Color("#90b8eb"),4,0));tile.add_child(mark);mark.hide();visitor_marks.append(mark)
	round_review=Label.new();round_review.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;round_review.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;round_review.add_theme_font_size_override("font_size",12);box.add_child(round_review);round_review.hide()
	var row:=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER;box.add_child(row)
	submit=button("Submit",row,_submit);next_round=button("Next round",row,_advance)

func _reset_game()->void:
	round_review.hide();round_number=0;stage="";pattern.clear();selections.clear();visitor_selections.clear();submit.visible=false;next_round.visible=false;_paint()

func _begin_game()->void:_advance()

func _advance()->void:
	if phase!="playing":return
	round_review.hide();round_number+=1;stage="show";stage_time=0;pattern.clear();selections.clear();visitor_selections.clear();feedback.text="";next_round.visible=false;submit.visible=false
	var pool:Array[int]=[]
	for i in 16:pool.append(i)
	for i in range(round_number+2):
		var index:=rng.randi_range(0,pool.size()-1);pattern.append(pool[index]);pool.remove_at(index)
	_paint()

func _select(index:int)->void:
	if phase!="playing" or stage!="select":return
	if selections.has(index):selections.erase(index)
	else:selections.append(index)
	_paint()
	var tile:Button=tiles[index]
	stage_art.pulse((tile.global_position-arena.global_position+tile.size/2)*Vector2(1000.0/arena.size.x,300.0/arena.size.y),"",Color("#69d6c3"))

func _paint()->void:
	for i in tiles.size():
		var tile:=tiles[i]
		tile.disabled=phase!="playing" or stage!="select"
		var reveal:bool=stage=="review"
		var lit:bool=(stage=="show" and pattern.has(i)) or selections.has(i) or (reveal and pattern.has(i))
		var tint:Color=THEME.GOLD if lit else Color("#5a6b62")
		var fill:Color=Color("#3a4b42") if not lit else Color("#70582e")
		var mark:String=""
		if reveal and selections.has(i):
			tint=Color("#69d6c3") if pattern.has(i) else Color("#ef8572")
			fill=Color("#28504a") if pattern.has(i) else Color("#603931")
			mark=" ◇" if pattern.has(i) else " ×"
		elif stage=="show" and pattern.has(i):mark=" ✦"
		elif selections.has(i):mark=" ◇"
		visitor_marks[i].visible=reveal and visitor_selections.has(i)
		tile.text="%02d%s"%[i+1,mark]
		for state in ["normal","disabled"]:tile.add_theme_stylebox_override(state,THEME.panel(fill,tint,6,2 if lit else 1))
		tile.add_theme_stylebox_override("hover",THEME.panel(Color("#355b53"),Color("#69d6c3"),6,2))
		tile.add_theme_color_override("font_color",THEME.IVORY);tile.add_theme_color_override("font_disabled_color",THEME.HIGHLIGHT_GOLD if lit else THEME.MUTED)
		if tile_tweens[i]!=null:tile_tweens[i].kill()
		tile.modulate=Color.WHITE;tile.scale=Vector2.ONE;tile.pivot_offset=tile.size/2
		if lit:
			tile.scale=Vector2(0.95,0.95);tile.modulate=Color(1,1,1,0.65)
			var tween:=create_tween().set_parallel(true);tile_tweens[i]=tween
			tween.tween_property(tile,"scale",Vector2.ONE,0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(tile,"modulate",Color.WHITE,0.18)

func _tick_game(delta:float)->void:
	stage_time+=delta
	status.text="Round %d/5 · You %d / Visitor %d · %s"%[round_number,player_score,visitor_score,"Watch" if stage=="show" else ("Select · %.1fs"%maxf(0,float(RULES.TUNING.memory_select)-stage_time) if stage=="select" else "Round revealed")]
	if stage=="show" and stage_time>=float(RULES.TUNING.memory_show):stage="select";stage_time=0;submit.visible=true;_paint()
	elif stage=="select" and stage_time>=float(RULES.TUNING.memory_select):_submit()

func _submit()->void:
	if phase!="playing" or stage!="select":return
	var score:=0
	for i in selections:score+=1 if pattern.has(i) else -1
	for i in pattern:
		if rng.randf()<float(RULES.TUNING.memory_recall_base)+float(RULES.TUNING.memory_recall_scale)*ability:visitor_selections.append(i)
	player_score+=maxi(0,score);visitor_score+=visitor_selections.size();stage="review";submit.visible=false;_paint()
	round_review.show()
	round_review.text="You +%d · Visitor +%d\nGold: pattern · ◇ correct · × wrong · • visitor"%[maxi(0,score),visitor_selections.size()]
	if round_number>=int(RULES.TUNING.memory_rounds):finish({"rounds":round_number,"last_pattern":pattern.duplicate(),"visitor_tiles":visitor_selections.duplicate()})
	else:next_round.visible=true

func _numbers(values:Array[int])->String:
	var labels:PackedStringArray=[]
	for i in values:labels.append(str(i+1))
	return ", ".join(labels) if not labels.is_empty() else "none"
