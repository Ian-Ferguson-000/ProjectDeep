extends Node2D
const VISUALS := preload("res://scripts/slasher/slasher_weapon_visuals.gd")
var history: Array[Dictionary]=[]
var alternate := false

func play_strike(origin: Vector2, direction: Vector2, reach: float, degrees: float, line: bool) -> void:
	alternate=not alternate
	history.append({"origin":origin,"direction":direction,"reach":reach,"degrees":degrees,"line":line,"left":0.28,"reverse":alternate})
	while history.size()>20:history.pop_front()
	queue_redraw()

func _physics_process(delta: float) -> void:
	for index in range(history.size()-1,-1,-1):
		history[index].left-=delta
		if float(history[index].left)<=0:history.remove_at(index)
	queue_redraw()

func _draw() -> void:
	for strike in history:
		var origin := to_local(strike.origin)
		var progress := clampf(1-float(strike.left)/0.28,0,1)
		if strike.line:VISUALS.thrust(self,origin,strike.direction,strike.reach,strike.degrees,Color("#f4dba9"),progress,false,false)
		else:VISUALS.slash(self,origin,strike.direction,strike.reach,strike.degrees,Color("#f4dba9"),progress,bool(strike.reverse),false)
