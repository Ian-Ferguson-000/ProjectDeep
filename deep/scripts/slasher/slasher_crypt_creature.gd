extends SlasherForestCreature
class_name SlasherCryptCreature

## The Stone Crypt's newer foes. Several borrow another enemy's sprites under
## their own name until they get art of their own ("art" and "tint" in
## slasher_balance.json enemy_visuals; see docs/Crypt.md).
##
## grave_rat    Hides under bone piles in nests of three. Wakes when you come
##              close (waking its nest), then swarms and bites. (sporeling behaviour)
## ghoul        Circles you, then lunges through with its claws. (cutthroat behaviour)
## gravedigger  Keeps its distance and lobs bones; three at once deeper down.
##              (knife-thrower behaviour)
## tomb_guard   "shieldbearer": its shield blocks every hit from the front and it
##              turns slowly to keep it on you. Get round behind it, or bait its
##              shield bash: after the bash the shield is down for a moment.
## revenant     When killed it collapses into a pile of bones and rises again a
##              few seconds later at half health, unless you smash the pile.
##
## Numbers live in data/slasher_balance.json under enemies.<id>.

const CRYPT_IDS := ["grave_rat","ghoul","gravedigger","tomb_guard","revenant"]

var facing_vector := Vector2.DOWN
var shield_up := true
var block_flash := 0.0
var has_risen := false

func _process_kind(delta: float) -> void:
	block_flash = maxf(0.0,block_flash - delta)
	match kind:
		"shieldbearer": _process_shieldbearer(delta)
		"revenant": _process_revenant(delta)
		_: super._process_kind(delta)

# ------------------------------------------------------------------ tomb guard

func _process_shieldbearer(delta: float) -> void:
	var to_target := global_position.direction_to(target.global_position)
	if ai_state == "bash_windup":
		velocity = Vector2.ZERO
		if state_timer <= 0.0:
			charge_direction = facing_vector
			_begin_dash(float(behavior_tuning.get("bash_distance",110.0)))
		return
	if ai_state == "dash":
		_process_dash(delta,float(behavior_tuning.get("bash_speed",420.0)),float(behavior_tuning.get("bash_damage_multiplier",1.4)),float(behavior_tuning.get("bash_recovery",1.3)))
		if ai_state == "recovery": shield_up = false
		return
	if ai_state == "recovery" and state_timer > 0.0:
		# Shield lowered after a bash: open from every side.
		shield_up = false
		velocity = Vector2.ZERO
		_play_animation("idle")
		return
	shield_up = true
	ai_state = "pursue"
	# Turns slowly, so you can get round it.
	var turn := float(behavior_tuning.get("turn_rate",2.0)) * delta
	facing_vector = facing_vector.rotated(clampf(facing_vector.angle_to(to_target),-turn,turn)).normalized()
	var distance := global_position.distance_to(target.global_position)
	if distance <= float(behavior_tuning.get("bash_range",120.0)) and attack_cooldown <= 0.0 and facing_vector.dot(to_target) > 0.85:
		ai_state = "bash_windup"
		state_timer = float(behavior_tuning.get("bash_windup",0.55))
		attack_cooldown = float(behavior_tuning.get("cooldown",2.6))
		facing_name = SlasherSpriteLibrary.direction_name(facing_vector,facing_name)
		_play_animation("attack",true)
		if sprite: sprite.pause()
		return
	if distance > attack_range * 0.8: _move_toward(target.global_position)
	else:
		velocity = Vector2.ZERO
		_play_animation("idle")
	facing_name = SlasherSpriteLibrary.direction_name(facing_vector,facing_name)

## True when a hit from `from` lands on the shield.
func blocks_from(from: Vector2) -> bool:
	if kind != "shieldbearer" or not shield_up: return false
	var arc := deg_to_rad(float(behavior_tuning.get("shield_arc_degrees",110.0))) * 0.5
	return absf(facing_vector.angle_to(global_position.direction_to(from))) <= arc

func receive_attack(attack: Dictionary, attacker: SlasherPlayer = null) -> int:
	if kind == "shieldbearer" and not dead:
		var from: Vector2 = attack.get("origin",attacker.global_position if is_instance_valid(attacker) else global_position + facing_vector)
		if blocks_from(from):
			block_flash = 0.2
			AudioCue.play_from(self,"block")
			# A blocked hit still nudges it round a little toward the attacker.
			facing_vector = facing_vector.rotated(clampf(facing_vector.angle_to(global_position.direction_to(from)),-0.15,0.15))
			queue_redraw()
			return 0
	return super.receive_attack(attack,attacker)

# ------------------------------------------------------------------ revenant

func _process_revenant(_delta: float) -> void:
	if ai_state == "bones":
		velocity = Vector2.ZERO
		if state_timer <= 0.0: _rise()
		return
	var distance := global_position.distance_to(target.global_position)
	if ai_state == "swing_windup":
		velocity = Vector2.ZERO
		if state_timer <= 0.0:
			if distance <= attack_range + 16.0: _bite(1.0,false)
			else: _play_animation("attack",true)
			ai_state = "pursue"
		return
	ai_state = "pursue"
	if distance <= attack_range and attack_cooldown <= 0.0:
		ai_state = "swing_windup"
		state_timer = float(behavior_tuning.get("swing_windup",0.35))
		attack_cooldown = float(behavior_tuning.get("cooldown",1.2))
		facing_name = SlasherSpriteLibrary.direction_name(global_position.direction_to(target.global_position),facing_name)
		_play_animation("idle",true)
		return
	if distance > attack_range * 0.8: _move_toward(target.global_position)
	else:
		velocity = Vector2.ZERO
		if animation_lock <= 0.0: _play_animation("idle")

func receive_hit(amount:int,knockback:Vector2=Vector2.ZERO,attacker:SlasherPlayer=null,stun_duration:float=-1.0,shake_multiplier:float=1.0,sound_event:String="impact")->int:
	if kind == "revenant" and not dead and not has_risen and ai_state != "bones" and amount >= health:
		# Collapses instead of dying. Hitting the pile now finishes it for good.
		var dealt := 0
		if health > 1: dealt = super.receive_hit(health - 1,Vector2.ZERO,attacker,0.0,shake_multiplier,sound_event)
		_collapse()
		return dealt
	return super.receive_hit(amount,knockback,attacker,stun_duration,shake_multiplier,sound_event)

func _collapse() -> void:
	ai_state = "bones"
	health = 1
	state_timer = float(behavior_tuning.get("rise_time",3.5))
	velocity = Vector2.ZERO
	AudioCue.play_from(self,"prop_break")
	if sprite:
		sprite.stop()
		var tween := create_tween()
		tween.tween_property(sprite,"scale:y",sprite.scale.x * 0.35,0.18)
		tween.parallel().tween_property(sprite,"modulate",Color(0.55,0.55,0.6,0.85),0.18)
	queue_redraw()

func _rise() -> void:
	has_risen = true
	ai_state = "pursue"
	health = maxi(1,int(round(max_health * float(behavior_tuning.get("rise_health",0.5)))))
	activation_delay = 0.35
	AudioCue.play_from(self,"enemy_attack")
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite,"scale:y",sprite.scale.x,0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(sprite,"modulate",Color.WHITE,0.3)
	queue_redraw()

# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if kind == "revenant" and ai_state == "bones":
		# A rising ring shows how long until it gets up.
		var left := clampf(state_timer / maxf(0.01,float(behavior_tuning.get("rise_time",3.5))),0.0,1.0)
		draw_arc(Vector2(0,-4),20.0,-PI * 0.5,-PI * 0.5 + TAU * (1.0 - left),32,Color(0.55,1.0,0.6,0.85),3.0)
		return
	super._draw()
	if kind == "shieldbearer":
		# The shield: a bright arc on the guarded side, dim while lowered.
		var arc := deg_to_rad(float(behavior_tuning.get("shield_arc_degrees",110.0))) * 0.5
		var colour := Color(0.75,0.85,1.0,0.9) if shield_up else Color(0.5,0.5,0.55,0.35)
		if block_flash > 0.0: colour = Color(1,1,1,1)
		var facing := facing_vector.angle()
		draw_arc(Vector2(0,-10),24.0,facing - arc,facing + arc,20,colour,5.0 if shield_up else 3.0)
		if ai_state == "bash_windup": draw_line(Vector2(0,-10),facing_vector * float(behavior_tuning.get("bash_distance",110.0)),Color(1,0.5,0.3,0.7),4.0)
