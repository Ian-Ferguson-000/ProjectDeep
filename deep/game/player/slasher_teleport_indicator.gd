extends Node2D
class_name SlasherTeleportIndicator

var duration:=1.0
var timer:=1.0
var radius:=38.0

func setup(destination:Vector2,warning_time:float=1.0)->SlasherTeleportIndicator:
	global_position=destination;duration=maxf(0.1,warning_time);timer=duration;return self

func _ready()->void:
	add_to_group("teleport_indicator");z_index=5;queue_redraw()

func _process(delta:float)->void:
	timer-=delta
	if timer<=0.0:queue_free();return
	queue_redraw()

func _draw()->void:
	var progress:=clampf(1.0-timer/duration,0.0,1.0);var pulse:=0.5+0.5*sin(progress*TAU*4.0)
	draw_circle(Vector2.ZERO,radius,Color(0.28,0.02,0.36,0.16+progress*0.16))
	draw_arc(Vector2.ZERO,radius,0.0,TAU,40,Color(1.0,0.34+0.28*pulse,0.08,0.82),3.0+progress*2.0)
	draw_arc(Vector2.ZERO,radius*(0.72-0.24*progress),-progress*TAU,TAU-progress*TAU,32,Color(0.82,0.22,1.0,0.9),3.0)
	for index:int in 4:
		var direction:=Vector2.RIGHT.rotated(TAU*float(index)/4.0+progress*0.55)
		draw_line(direction*radius*0.45,direction*radius*(0.78+0.12*pulse),Color("#ffd36a"),3.0)
	draw_circle(Vector2.ZERO,4.0+progress*5.0,Color(1.0,0.78,0.25,0.7+0.3*pulse))
