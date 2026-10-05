extends Control
## Presentation only: every position and timing indicator reads the contest's real state.

const GOLD := Color("#f6c66a")
const IVORY := Color("#f3e2c3")
const MUTED := Color("#b69b76")
const TEAL := Color("#69d6c3")
const RED := Color("#ef8572")
const BLUE := Color("#90b8eb")
var game:Node
var visual_time:=0.0
var shown_pull:=0.0
var mug_angles:=Vector2.ZERO
var effects:Array[Dictionary]=[]
var font:Font=ThemeDB.fallback_font

func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func pulse(at:Vector2,message:String,tint:Color=GOLD,duration:float=0.7)->void:
	effects.append({"at":at,"message":message,"color":tint,"age":0.0,"duration":duration})
	if effects.size()>12:effects.pop_front()

func reset()->void:
	effects.clear();shown_pull=0.0;mug_angles=Vector2.ZERO

func _process(delta:float)->void:
	visual_time+=delta
	for effect in effects:effect.age+=delta
	effects=effects.filter(func(effect:Dictionary)->bool:return float(effect.age)<float(effect.duration))
	if game!=null and game.contest_id=="arm_wrestling":shown_pull=lerpf(shown_pull,float(game.pull),1.0-exp(-delta*18.0))
	if game!=null and game.contest_id=="drinking":
		var player_angle:float=1.25 if game.tipped else sin(visual_time*3)*int(game.mistakes)*0.045
		var visitor_angle:float=1.25 if game.visitor_tipped else sin(visual_time*3)*int(game.visitor_mistakes)*0.045
		mug_angles=mug_angles.lerp(Vector2(player_angle,visitor_angle),1.0-exp(-delta*9.0))
	queue_redraw()

func _draw()->void:
	if game==null or size.x<=0 or size.y<=0:return
	draw_set_transform(Vector2.ZERO,0,Vector2(size.x/1000.0,size.y/300.0))
	_plate(Rect2(0,0,1000,300),Color("#151b1b"),Color("#685334"),12)
	# Inlaid timber, fine grain, and corner brass give every board a shared material.
	for i in 12:
		var y:float=12+i*25
		draw_line(Vector2(8,y),Vector2(992,y),Color(0.46,0.34,0.2,0.07),1)
	for point in [Vector2(12,12),Vector2(988,12),Vector2(12,288),Vector2(988,288)]:
		draw_circle(point,3,Color("#a68145"));draw_line(point-Vector2(1.5,0),point+Vector2(1.5,0),Color("#322a20"),1)
	match String(game.contest_id):
		"arm_wrestling":_arms()
		"memory_match":_memory()
		"quick_draw":_range()
		"drinking":_drinking()
	for effect in effects:_effect(effect)
	if game.phase=="results" and game.contest_id!="memory_match":
		var outcome:String="VICTORY" if game.player_score>game.visitor_score else ("DEFEAT" if game.player_score<game.visitor_score else "HONORS EVEN")
		_plate(Rect2(360,8,280,32),Color("#172629"),GOLD)
		_text(outcome,Vector2(500,30),17,GOLD)

func _plate(rect:Rect2,fill:Color,border:Color,radius:int=6)->void:
	var style:=StyleBoxFlat.new();style.bg_color=fill;style.border_color=border
	style.set_border_width_all(1);style.set_corner_radius_all(radius);style.draw(get_canvas_item(),rect)

func _text(value:String,at:Vector2,px:int=15,tint:Color=IVORY)->void:
	draw_string(font,at-Vector2(font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x/2,0),value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,tint)

func _arms()->void:
	var p:=shown_pull
	var grip:=Vector2(500+p*175,100+absf(p)*85)
	# A bowed pressure gauge moves with the actual struggle, rather than a generic progress bar.
	draw_arc(Vector2(500,218),164,PI,TAU,64,Color("#463e32"),8,true)
	for i in 21:
		var angle:float=PI+i*PI/20
		draw_line(Vector2(500,218)+Vector2.from_angle(angle)*155,Vector2(500,218)+Vector2.from_angle(angle)*170,GOLD if i==10 else MUTED,1)
	var needle:float=PI+(p+1.0)*PI/2
	draw_circle(Vector2(500,218)+Vector2.from_angle(needle)*164,6,GOLD)
	_text("VISITOR'S PIN",Vector2(126,55),12,BLUE);_text("YOUR PIN",Vector2(874,55),12,TEAL)
	_text("PRESSURE",Vector2(500,54),12,MUTED)
	# Tabletop, elbow pads, and interlocked hands.
	_plate(Rect2(90,220,820,30),Color("#593b29"),Color("#a67846"),8)
	for i in 5:draw_line(Vector2(100,224+i*5),Vector2(900,224+i*5),Color(0.1,0.05,0.02,0.22),1)
	_plate(Rect2(213,209,110,16),Color("#213f3d"),TEAL,5)
	_plate(Rect2(677,209,110,16),Color("#34334c"),BLUE,5)
	_arm(Vector2(262,213),grip+Vector2(-12,4),Color("#347e78"),Color("#d39a68"))
	_arm(Vector2(738,213),grip+Vector2(12,-4),Color("#57598e"),Color("#b87853"))
	draw_circle(grip,22,Color("#e4b181"));draw_circle(grip+Vector2(10,-8),12,Color("#d69a70"))
	for i in 3:draw_line(grip+Vector2(-11,-7+i*7),grip+Vector2(9,-12+i*7),Color("#9d6046"),2,true)
	var strain:float=absf(p)
	if game.phase=="playing":
		for i in 3:
			var offset:=Vector2(sin(visual_time*14+i)*3,cos(visual_time*12+i)*3)*(0.4+strain)
			draw_line(grip+Vector2(-34,-16+i*12)+offset,grip+Vector2(-43,-19+i*12)+offset,GOLD,2,true)
	var seconds:float=maxf(0,float(game.RULES.TUNING.arm_duration)-float(game.elapsed))
	_text("%.1fs"%seconds,Vector2(500,208),15,IVORY)

func _arm(elbow:Vector2,wrist:Vector2,sleeve:Color,skin:Color)->void:
	var normal:Vector2=(wrist-elbow).normalized().orthogonal()
	var hand_base:Vector2=elbow.lerp(wrist,0.45)
	draw_colored_polygon(PackedVector2Array([elbow-normal*23,elbow+normal*23,hand_base+normal*19,hand_base-normal*19]),sleeve)
	draw_colored_polygon(PackedVector2Array([hand_base-normal*18,hand_base+normal*18,wrist+normal*12,wrist-normal*12]),skin)
	draw_line(elbow+normal*12,hand_base+normal*11,Color(sleeve.lightened(0.3),0.7),3,true)
	draw_line(hand_base+normal*10,wrist+normal*7,skin.lightened(0.2),3,true)
	draw_circle(elbow,22,sleeve)

func _memory()->void:
	var stage:String=game.stage
	var tint:Color=GOLD if stage=="show" else TEAL
	var mode:String="WATCH" if stage=="show" else ("RECALL" if stage=="select" else "REVEAL")
	_plate(Rect2(28,55,195,185),Color("#1c2727"),Color("#45645d"),8)
	_text("THE KEEPER'S TABLE",Vector2(125,85),11,MUTED)
	_text(mode if game.phase!="instructions" else "RUNE MEMORY",Vector2(125,124),21,tint)
	_text("Round %d / 5"%maxi(1,int(game.round_number)),Vector2(125,151),14,IVORY)
	var duration:float=float(game.RULES.TUNING.memory_show) if stage=="show" else float(game.RULES.TUNING.memory_select)
	var fraction:float=clampf(1-float(game.stage_time)/duration,0,1) if stage in ["show","select"] else 1.0
	draw_arc(Vector2(125,191),23,-PI/2,-PI/2+TAU*fraction,48,tint,3,true)
	_text("%.1f"%maxf(0,duration-float(game.stage_time)) if stage in ["show","select"] else "•",Vector2(125,196),14,tint)
	_plate(Rect2(777,55,195,185),Color("#1c2727"),Color("#45645d"),8)
	_text("MARKS ON THE BOARD",Vector2(875,85),11,MUTED)
	_text("YOU  %02d"%int(game.player_score),Vector2(875,120),19,TEAL)
	_text("VISITOR  %02d"%int(game.visitor_score),Vector2(875,150),19,BLUE)
	_text("◇ correct   × wrong" if stage=="review" else "◇ selected tiles",Vector2(875,187),12,IVORY)
	_text("• visitor remembered",Vector2(875,211),12,BLUE)

func _range()->void:
	# Tavern archery range: slatted wall, pinned targets, and twine.
	for i in 10:
		_plate(Rect2(8+i*99,8,97,284),Color("#24302d") if i%2==0 else Color("#202b2a"),Color("#303d36"),2)
	for i in 3:
		var center:=Vector2(220+i*280,140)
		for radius in [44,33,22,11]:draw_arc(center,radius,0,TAU,48,Color(0.5,0.45,0.33,0.13),1,true)
	_text("REACT TO THE GOLD TARGET",Vector2(500,28),12,MUTED)
	for i in 12:
		draw_circle(Vector2(423+i*14,281),3,TEAL if i<int(game.hits) else (MUTED if i<int(game.target_number)-1 else Color("#38463e")))
	if game.stage=="wait" and game.phase=="playing":
		_text("STEADY…",Vector2(500,149),20,Color(IVORY,0.5+0.2*sin(visual_time*3)))
	if game.stage=="target" and game.phase=="playing":
		var target:Button=game.target
		var center:Vector2=(target.position+target.size/2)*Vector2(1000.0/size.x,300.0/size.y)
		var life:float=clampf(1-float(game.stage_time)/float(game.RULES.TUNING.reaction_lifetime),0,1)
		var tint:Color=TEAL if game.hit else GOLD
		for radius in [35,25,15]:draw_circle(center,radius,Color("#29362c") if radius==35 else (Color("#deb577") if radius==25 else Color("#7c4534")))
		draw_circle(center,5,GOLD)
		draw_arc(center,40,-PI/2,-PI/2+TAU*life,64,tint,3,true)
		draw_line(center-Vector2(12,0),center+Vector2(12,0),Color("#f5e5bc"),1,true)
		draw_line(center-Vector2(0,12),center+Vector2(0,12),Color("#f5e5bc"),1,true)
		if game.visitor_scored and not game.visitor_misses:
			draw_line(center+Vector2(14,-6),center+Vector2(47,-33),BLUE,3,true)
			draw_circle(center+Vector2(47,-33),4,BLUE)
		if game.hit:_text("%.0f ms"%(float(game.last_reaction)*1000),center+Vector2(0,62),12,TEAL)

func _drinking()->void:
	var keys:Array=[KEY_Q,KEY_W,KEY_E,KEY_R]
	var strike:=218.0
	var speed:=96.0
	var window:float=drink_hit_half_height()
	_text("YOU",Vector2(124,35),12,TEAL);_text("VISITOR",Vector2(876,35),12,BLUE)
	_mug(Vector2(125,88),mug_angles.x,TEAL)
	_mug(Vector2(875,88),mug_angles.y,BLUE)
	for side in 2:
		var fallen:bool=game.tipped if side==0 else game.visitor_tipped
		var count:int=3 if fallen else (int(game.mistakes) if side==0 else int(game.visitor_mistakes))
		for i in 3:
			var point:=Vector2(98+side*750+i*27,171)
			draw_circle(point,8,RED if i<count else Color("#2f5048"))
			if i<count:draw_line(point-Vector2(3,3),point+Vector2(3,3),IVORY,1.5,true);draw_line(point-Vector2(3,-3),point+Vector2(3,-3),IVORY,1.5,true)
		_text("TIPPED OVER" if (game.tipped if side==0 else game.visitor_tipped) else "KEEP YOUR BALANCE",Vector2(125+side*750,203),11,RED if count>=3 else MUTED)
	for i in 4:
		var x:float=320+i*120
		_plate(Rect2(x-43,14,86,238),Color("#202b2d"),Color("#3c5551"),6)
		draw_line(Vector2(x,22),Vector2(x,248),Color(0.6,0.75,0.7,0.10),1)
	# The band is exactly the scoring tolerance: ±0.15 seconds, mapped to pixels.
	draw_rect(Rect2(277,strike-window,446,window*2),Color(0.96,0.77,0.42,0.15))
	draw_line(Vector2(277,strike),Vector2(723,strike),GOLD,2,true)
	for x in [320,440,560,680]:draw_arc(Vector2(x,strike),25,0,TAU,40,Color(GOLD,0.45),2,true)
	var preview:bool=game.phase in ["instructions","countdown"]
	for i in game.cues.size() if not preview else 4:
		var key:int=keys[i] if preview else int(game.cues[i])
		if not preview and game.resolved[i]:continue
		var x:float=320+keys.find(key)*120
		var remaining:float=(i+1)*float(game.RULES.TUNING.drink_spacing)-float(game.round_time) if not preview else (i+1)*0.45
		var y:float=strike-remaining*speed if preview else drink_note_position(i).y
		if y<22 or y>247:continue
		var optimal:bool=absf(remaining)<=float(game.RULES.TUNING.drink_window) and game.phase=="playing"
		var tint:Color=GOLD if optimal else TEAL
		_plate(Rect2(x-28,y-15,56,30),Color("#315c54"),tint,7)
		_text(OS.get_keycode_string(key),Vector2(x,y+6),19,tint)
		if optimal:draw_arc(Vector2(x,y),33,0,TAU,40,Color(GOLD,0.5+0.3*sin(visual_time*22)),2,true)
	_text("HIT WINDOW",Vector2(500,245),10,GOLD)

func _mug(at:Vector2,rotation:float,tint:Color)->void:
	# Map the mug pivot from board coordinates to the actual responsive canvas.
	draw_set_transform(Vector2(at.x*size.x/1000.0,at.y*size.y/300.0),rotation,Vector2(size.x/1000.0,size.y/300.0))
	_plate(Rect2(-30,-37,60,73),Color("#ac793d"),GOLD,6)
	_plate(Rect2(29,-23,19,42),Color("#182324"),GOLD,6)
	draw_rect(Rect2(-22,-24,43,51),Color("#e9aa4a"))
	for x in [-15,0,15]:draw_line(Vector2(x,-22),Vector2(x,30),Color("#d3a456"),2,true)
	for i in 6:draw_circle(Vector2(-24+i*10,-31+sin(visual_time*2+i)*2),9,IVORY)
	for i in 3:
		var bubble_y:float=22-fposmod(visual_time*18+i*17,48)
		draw_circle(Vector2(-11+i*10,bubble_y),2,Color(IVORY,0.4))
	draw_line(Vector2(-23,33),Vector2(24,33),tint,3,true)
	draw_set_transform(Vector2.ZERO,0,Vector2(size.x/1000.0,size.y/300.0))

func _effect(effect:Dictionary)->void:
	var age:float=effect.age
	var at:Vector2=effect.at
	var tint:Color=effect.color
	var alpha:float=1-age/float(effect.duration)
	draw_arc(at,12+age*70,0,TAU,32,Color(tint,alpha),2,true)
	for i in 8:
		var vector:=Vector2.from_angle(i*TAU/8)
		draw_line(at+vector*(14+age*55),at+vector*(19+age*70),Color(tint,alpha),2,true)
	if not String(effect.message).is_empty():_text(effect.message,at+Vector2(0,-25-age*24),15,Color(tint,alpha))

func drink_hit_half_height()->float:
	return float(game.RULES.TUNING.drink_window)*96.0

func drink_note_position(index:int)->Vector2:
	var keys:Array=[KEY_Q,KEY_W,KEY_E,KEY_R]
	return Vector2(320+keys.find(int(game.cues[index]))*120,218-(float(game._cue_time(index))-float(game.round_time))*96.0)
