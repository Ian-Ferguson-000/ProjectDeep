extends Node2D
const VISUALS := preload("res://game/player/slasher_weapon_visuals.gd")
var history: Array[Dictionary]=[]
var alternate := false

func play_strike(origin: Vector2, direction: Vector2, reach: float, degrees: float, line: bool, fighter: bool=false) -> void:
	alternate=not alternate
	var duration := 0.18 if fighter else 0.28
	history.append({"origin":origin,"direction":direction.normalized(),"reach":reach,"degrees":degrees,"line":line,"left":duration,"duration":duration,"fighter":fighter,"reverse":alternate})
	while history.size()>20:history.pop_front()
	queue_redraw()

func sync_fighter_duration(duration: float) -> void:
	if history.is_empty() or not bool(history.back().get("fighter",false)):return
	history.back().duration=duration
	history.back().left=duration

func _physics_process(delta: float) -> void:
	for index in range(history.size()-1,-1,-1):
		history[index].left-=delta
		if float(history[index].left)<=0:history.remove_at(index)
	queue_redraw()

func _draw() -> void:
	for strike in history:
		var origin := to_local(strike.origin)
		var progress := clampf(1-float(strike.left)/float(strike.duration),0,1)
		if strike.line:VISUALS.thrust(self,origin,strike.direction,strike.reach,strike.degrees,Color("#f4dba9"),progress,false,false)
		elif strike.fighter:VISUALS.fighter_slash(self,origin,strike.direction,strike.reach,strike.degrees,progress)
		else:VISUALS.slash(self,origin,strike.direction,strike.reach,strike.degrees,Color("#f4dba9"),progress,bool(strike.reverse),false)
