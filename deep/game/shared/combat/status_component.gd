class_name StatusComponent
extends Node

signal status_changed(effect: String, active: bool)
var effects: Dictionary = {}
var health: HealthComponent
var burn_tick := 0.0
var poison_tick:=0.0
var generic_tick:=0.0

## Assigns the health target used by Burn ticks. Must be called before status processing.
func setup(component: HealthComponent) -> void: health=component

## Adds or refreshes a supported effect using the stronger power/longer remaining duration. Burn and Poison
## derive duration/tick strength from power; Shock blocks actions/movement; Root blocks movement only.
func apply(effect: String, power: int, duration_override:float=0.0) -> void:
	if effect.is_empty() or power<=0:return
	var duration:float=max(2.0,float(power))
	if effect in ["shock","stagger"]:duration=min(2.0,0.25*power)
	elif effect in ["root","slow"]:duration=min(4.0,0.5*power)
	elif effect in ["poison","scorch","phase_burn"]:duration=max(3.0,float(power)+1.0)
	if duration_override>0:duration=duration_override
	var old: Dictionary=effects.get(effect,{})
	effects[effect]={"time":max(duration,float(old.get("time",0.0))),"power":max(power,int(old.get("power",0)))}
	if effect=="burn": burn_tick=min(burn_tick,1.0)
	if effect=="poison":poison_tick=min(poison_tick,1.0)
	if effect in ["scorch","phase_burn","regeneration"]:generic_tick=min(generic_tick,1.0)
	status_changed.emit(effect,true)

## Counts down statuses, applies independent Fire and Poison tick packets, removes expired effects, and emits
## state changes. The component must remain processing for durations to advance.
func _process(delta: float) -> void:
	if effects.has("burn"):
		burn_tick-=delta
		if burn_tick<=0:
			burn_tick=1.0
			if health: health.receive_damage(DamagePacket.create(get_parent(),int(effects.burn.power),"fire"))
	if effects.has("poison"):
		poison_tick-=delta
		if poison_tick<=0:
			poison_tick=1.0
			if health:health.receive_damage(DamagePacket.create(get_parent(),int(effects.poison.power),"poison"))
	generic_tick-=delta
	if generic_tick<=0:
		generic_tick=1.0
		for effect in ["scorch","phase_burn"]:
			if effects.has(effect) and health:health.receive_damage(DamagePacket.create(get_parent(),int(effects[effect].power),"burn" if effect=="scorch" else "aether"))
		if effects.has("regeneration") and health and health.current_health>0:
			health.current_health=mini(health.max_health,health.current_health+int(effects.regeneration.power));health.health_changed.emit(health.current_health,health.max_health)
	var expired: Array[String]=[]
	for effect in effects:
		effects[effect].time=float(effects[effect].time)-delta
		if effects[effect].time<=0: expired.append(effect)
	for effect in expired: effects.erase(effect); status_changed.emit(effect,false)

## Returns true while Root or Shock is active. Movement controllers should query every frame.
func blocks_movement() -> bool:return effects.has("root") or effects.has("shock")
## Returns true while Shock is active. Casting/attacking controllers should query before acting.
func blocks_actions() -> bool:return effects.has("shock") or effects.has("stagger")
## Returns true while Silence prevents spell activation without blocking movement or ordinary interactions.
func blocks_spells() -> bool:return effects.has("silence")
## Returns the multiplicative movement modifier supplied by Slow and Haste effects.
func movement_multiplier() -> float:return 1.25 if effects.has("haste") else (0.6 if effects.has("slow") else 1.0)
## Returns the temporary defense bonus supplied by Fortify effects.
func defense_bonus() -> int:return int(effects.get("fortify",{}).get("power",0))
## Returns the incoming-damage multiplier supplied by Illuminate effects.
func vulnerability_multiplier() -> float:return 1.0+0.15*int(effects.get("illuminate",{}).get("power",0))
## Emits deactivation for all effects and clears timers. Use on respawn and encounter reset.
func clear() -> void:
	for effect in effects: status_changed.emit(effect,false)
	effects.clear(); burn_tick=0.0; poison_tick=0.0;generic_tick=0.0
