extends Node
# Short-lived source-owned support effects, deliberately absent from saved inventory.
var actor: SlasherPlayer
var wards: Dictionary={}
var speeds: Dictionary={}
func grant_ward(source: String, amount: int, duration: float) -> void:
	wards[source]={"amount":maxi(0,amount),"left":duration}
func grant_speed(source: String, multiplier: float, duration: float) -> void:
	speeds[source]={"multiplier":multiplier,"left":duration}
func clear_source(source: String) -> void:wards.erase(source);speeds.erase(source)
func speed_multiplier() -> float:
	var result := 1.0
	for effect in speeds.values():result=maxf(result,float(effect.multiplier))
	return result
func ward_amount() -> int:
	var result := 0
	for effect in wards.values():result=maxi(result,int(effect.amount))
	return result
func absorb_damage(amount: int) -> int:
	var key := "";var available := 0
	for source in wards:
		if int(wards[source].amount)>available:key=source;available=int(wards[source].amount)
	var absorbed := mini(amount,available)
	# Shared barriers do not add together; an absorbed amount consumes all layers.
	for effect in wards.values():effect.amount=maxi(0,int(effect.amount)-absorbed)
	return absorbed
func _physics_process(delta: float) -> void:
	for effects in [wards,speeds]:
		for source in effects.keys():
			effects[source].left-=delta
			if float(effects[source].left)<=0:effects.erase(source)
