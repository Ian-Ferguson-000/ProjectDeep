extends Control
## Kept above game controls so the countdown also covers the rune buttons.

var game:Node
var font:Font=ThemeDB.fallback_font

func _ready()->void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _process(_delta:float)->void:queue_redraw()

func _draw()->void:
	if game==null or game.phase!="countdown":return
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.02,0.04,0.04,0.87))
	var center:=size/2-Vector2(0,10)
	var remaining:float=maxf(0,float(game.RULES.TUNING.countdown)-float(game.elapsed))
	var gold:=Color("#f6c66a")
	draw_circle(center,62,Color("#182626"))
	draw_arc(center,62,0,TAU,64,Color("#526252"),1,true)
	draw_arc(center,57,-PI/2,-PI/2+TAU*fposmod(remaining,1.0),64,gold,4,true)
	var value:=str(maxi(1,ceili(remaining)))
	draw_string(font,center+Vector2(-font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,48).x/2,17),value,HORIZONTAL_ALIGNMENT_LEFT,-1,48,gold)
	var caption:="READY YOURSELF"
	draw_string(font,center+Vector2(-font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x/2,88),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#f3e2c3"))
