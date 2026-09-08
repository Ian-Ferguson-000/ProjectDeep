extends Node2D
class_name SlasherHellHazard

enum Phase {TELEGRAPH,ACTIVE,COOLDOWN,DISABLED}

var phase:=Phase.TELEGRAPH
var timer:=0.8
var active_time:=2.5
var radius:=52.0
var damage:=2
var target:SlasherPlayer
var source:SlasherEnemy
var repeating:=true
var tick_cooldown:=0.0

func setup(owner:SlasherEnemy,player:SlasherPlayer,position_value:Vector2,config:Dictionary)->SlasherHellHazard:
	source=owner;target=player;global_position=position_value;timer=float(config.get("telegraph",0.8));active_time=float(config.get("lifetime",2.5));radius=float(config.get("radius",52.0));damage=maxi(1,int(config.get("damage",2)));repeating=bool(config.get("repeating",true));return self

func _ready()->void:add_to_group("hell_hazard");z_index=2;queue_redraw()

func _physics_process(delta:float)->void:
	if phase==Phase.DISABLED:return
	timer-=delta;tick_cooldown=maxf(0.0,tick_cooldown-delta)
	if phase==Phase.TELEGRAPH and timer<=0.0:phase=Phase.ACTIVE;timer=active_time;queue_redraw()
	elif phase==Phase.ACTIVE:
		if is_instance_valid(target) and global_position.distance_to(target.global_position)<=radius and tick_cooldown<=0.0:
			target.receive_damage(damage,global_position.direction_to(target.global_position)*115.0,source if is_instance_valid(source) else null);tick_cooldown=0.72
		if timer<=0.0:
			if repeating:phase=Phase.COOLDOWN;timer=2.8
			else:queue_free()
			queue_redraw()
	elif phase==Phase.COOLDOWN and timer<=0.0:phase=Phase.TELEGRAPH;timer=1.0;queue_redraw()

func disable()->void:phase=Phase.DISABLED;visible=false;set_physics_process(false)

func _draw()->void:
	if phase==Phase.DISABLED or phase==Phase.COOLDOWN:return
	var warning:=phase==Phase.TELEGRAPH;var fill:=Color(1.0,0.22,0.04,0.12 if warning else 0.34);var rim:=Color("#ffbb45") if warning else Color("#ff3b13")
	draw_circle(Vector2.ZERO,radius,fill);draw_arc(Vector2.ZERO,radius,0.0,TAU,40,rim,3.0 if warning else 5.0)
	if not warning:
		for index:int in 6:
			var angle:=TAU*float(index)/6.0+timer;draw_line(Vector2.RIGHT.rotated(angle)*10.0,Vector2.RIGHT.rotated(angle)*radius*0.85,Color("#ff8a21aa"),3.0)
