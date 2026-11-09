extends Control
class_name PartyHealthPortrait

var character_id:=""
var health:=1
var maximum:=1
var controlled:=false
var portrait:TextureRect
var name_label:Label

func setup(id_value:String,display_name:String,texture:Texture2D)->void:
	character_id=id_value;custom_minimum_size=Vector2(72,76);mouse_filter=Control.MOUSE_FILTER_IGNORE
	portrait=TextureRect.new();portrait.position=Vector2(10,4);portrait.size=Vector2(52,52);portrait.texture=texture;portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(portrait)
	name_label=Label.new();name_label.position=Vector2(0,58);name_label.size=Vector2(72,18);name_label.text=display_name;name_label.clip_text=true;name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name_label.add_theme_font_size_override("font_size",10);name_label.add_theme_color_override("font_color",Color("e9ddbf"));name_label.add_theme_color_override("font_outline_color",Color.BLACK);name_label.add_theme_constant_override("outline_size",3);name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(name_label)
	queue_redraw()

func update_state(current:int,max_value:int,is_controlled:bool)->void:
	health=maxi(0,current);maximum=maxi(1,max_value);controlled=is_controlled;tooltip_text="%s  ·  HP %d/%d%s"%[name_label.text if name_label else "Recruit",health,maximum,"  ·  Controlled" if controlled else ""];queue_redraw()

func _process(_delta:float)->void:
	if controlled:queue_redraw()

func _draw()->void:
	var center:=Vector2(36,30);var ratio:=clampf(float(health)/float(maximum),0.0,1.0);var hp_color:=Color("5bd66f") if ratio>0.5 else (Color("e1aa3f") if ratio>0.25 else Color("e05252"))
	draw_circle(center,31,Color(0.025,0.035,0.03,0.92));draw_arc(center,28,-PI/2.0,-PI/2.0+TAU,48,Color(0.18,0.16,0.13,0.95),5.0)
	if ratio>0.0:draw_arc(center,28,-PI/2.0,-PI/2.0+TAU*ratio,48,hp_color,5.0)
	if controlled:
		var pulse:=0.72+sin(float(Time.get_ticks_msec())*0.008)*0.2;draw_arc(center,33,0,TAU,52,Color(1.0,0.73,0.24,pulse),3.0)
