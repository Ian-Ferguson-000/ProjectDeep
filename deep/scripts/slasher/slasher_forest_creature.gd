extends SlasherEnemy
class_name SlasherForestCreature

## Forest enemies built on the shroomie and Kobold sprite sheets.
##
## sporeling            Mini mushrooms that lie dormant as caps, wake when you
##                      come close (waking their neighbours), then swarm and hop
##                      in to nibble. Melee only, weak alone, dangerous in packs.
## bandit_cutthroat     Kobold bandit that circles at a distance, then telegraphs
##                      and lunges through you with a dagger slash.
## bandit_knifethrower  Kobold bandit that keeps its distance and throws spinning
##                      knives; a fan of three from floor 3.
##
## Numbers live in data/slasher_balance.json under enemies.<id>.
##
## Other dungeons reuse these behaviours under their own names: an enemy with
## "behaves_like": "bandit_cutthroat" in its tuning fights like a cutthroat
## (the crypt's ghoul, gravedigger and grave rats; see slasher_crypt_creature.gd).

const IDS := ["sporeling","bandit_cutthroat","bandit_knifethrower"]
const ART := ForestCreatureArt.CREATURES

var creature_floor := 1
## Which behaviour this creature uses: its own id, or tuning "behaves_like".
var kind := ""
var strafe_sign := 1.0
var throws := 0
var hop_origin := Vector2.ZERO

func configure(floor_number:int,is_boss:bool=false,enemy_visual_id:String="sporeling",is_mini_boss:bool=false,enemy_behavior_id:String="")->void:
	var id := enemy_behavior_id if not enemy_behavior_id.is_empty() else enemy_visual_id
	super.configure(floor_number,is_boss,enemy_visual_id,is_mini_boss,id)
	creature_floor = floor_number
	behavior_id = id
	visual_id = id
	behavior_tuning = GameBalance.get_slasher_enemy_tuning(id)
	visual_tuning = GameBalance.get_slasher_enemy_visual_tuning(id)
	kind = String(behavior_tuning.get("behaves_like",id))
	elite = false
	max_health = int(behavior_tuning.get("health_base",10)) + floor_number * int(behavior_tuning.get("health_per_floor",2))
	health = max_health
	damage = int(behavior_tuning.get("damage_base",2)) + int(floor_number * float(behavior_tuning.get("damage_per_floor",0.5)))
	speed = float(behavior_tuning.get("speed",80.0)) + floor_number * float(behavior_tuning.get("speed_per_floor",2.0))
	attack_range = float(behavior_tuning.get("attack_range",30.0))
	attack_knockback = float(behavior_tuning.get("knockback",90.0))
	reward = int(behavior_tuning.get("reward",2))
	if is_mini_boss:
		# Champion version (crypt elite rooms): the same multipliers as other elites.
		var elite_tuning := GameBalance.get_slasher_enemy_tuning("forest_elite")
		max_health = maxi(1,int(round(max_health * float(elite_tuning.get("mini_boss_health_multiplier",2.5))))); health = max_health
		damage = maxi(1,int(round(damage * float(elite_tuning.get("mini_boss_damage_multiplier",1.5)))))
		reward = int(elite_tuning.get("mini_boss_reward",12))
	strafe_sign = 1.0 if randf() < 0.5 else -1.0
	if kind == "sporeling": ai_state = "dormant"

func _ready() -> void:
	var art_id: String = ART.get(behavior_id,"")
	var scale_value := float(visual_tuning.get("sprite_scale",1.0))
	sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		sprite = AnimatedSprite2D.new()
		sprite.name = "AnimatedSprite2D"
		add_child(sprite)
	# Forest creatures are cut from shared sheets; others use their enemy frames (or borrowed "art").
	sprite.sprite_frames = ForestCreatureArt.frames_for(art_id) if not art_id.is_empty() else SlasherSpriteLibrary.enemy_frames(behavior_id)
	super._ready()
	if mini_boss: scale_value *= 1.25
	sprite.scale = Vector2.ONE * scale_value
	if not art_id.is_empty(): sprite.position = Vector2(0.0,ForestCreatureArt.feet_offset(art_id,scale_value))
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape and shape.shape is CircleShape2D: (shape.shape as CircleShape2D).radius = float(behavior_tuning.get("collision_radius",14.0))
	if kind == "sporeling":
		# Creatures without a dormant pose (grave rats) hide under a bone pile until woken.
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("dormant"): sprite.play("dormant")
		else: sprite.visible = false

func _physics_process(delta: float) -> void:
	retarget_timer -= delta
	if retarget_timer <= 0.0:
		_retarget_party()
		retarget_timer = 0.45
	if dead or not is_instance_valid(target): return
	activation_delay = maxf(0.0,activation_delay - delta)
	for timer in ["attack_cooldown","animation_lock","hit_stun_timer","status_time","special_cooldown","state_timer"]:
		set(timer,maxf(0.0,float(get(timer)) - delta))
	if status_time <= 0.0: movement_slow = 1.0
	if kind == "sporeling" and ai_state in ["dormant","waking"]:
		_process_sporeling_sleep()
		return
	if activation_delay > 0.0 or hit_stun_timer > 0.0 or (status_time > 0.0 and movement_slow <= 0.05):
		velocity = Vector2.ZERO
		if animation_lock <= 0.0: _play_animation("idle")
		queue_redraw()
		return
	_process_kind(delta)
	queue_redraw()

func _process_kind(delta: float) -> void:
	match kind:
		"sporeling": _process_sporeling(delta)
		"bandit_cutthroat": _process_cutthroat(delta)
		"bandit_knifethrower": _process_knifethrower()

# ------------------------------------------------------------------ sporelings

func _process_sporeling_sleep() -> void:
	velocity = Vector2.ZERO
	if ai_state == "dormant":
		if global_position.distance_to(target.global_position) <= float(behavior_tuning.get("wake_radius",140.0)): wake()
		return
	if state_timer <= 0.0:
		ai_state = "pursue"
		activation_delay = 0.0

## Pops up out of the ground and rouses dormant sporelings close by.
func wake() -> void:
	if ai_state != "dormant": return
	ai_state = "waking"
	state_timer = float(behavior_tuning.get("wake_time",0.65))
	if sprite: sprite.visible = true
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("wake"): sprite.play("wake")
	elif sprite: _play_animation("run",true)
	AudioCue.play_from(self,"enemy_attack")
	var radius := float(behavior_tuning.get("wake_chain_radius",130.0))
	for node in get_tree().get_nodes_in_group("slasher_enemy"):
		var other := node as SlasherForestCreature
		if is_instance_valid(other) and other != self and other.behavior_id == behavior_id and other.ai_state == "dormant" and other.global_position.distance_to(global_position) <= radius:
			other.call_deferred("wake")

func _process_sporeling(delta: float) -> void:
	var distance := global_position.distance_to(target.global_position)
	if ai_state == "hop_windup":
		velocity = Vector2.ZERO
		if state_timer <= 0.0:
			charge_direction = global_position.direction_to(target.global_position)
			_begin_dash(float(behavior_tuning.get("hop_distance",54.0)))
		return
	if ai_state == "dash":
		_process_dash(delta,float(behavior_tuning.get("hop_speed",300.0)),1.0,float(behavior_tuning.get("recovery",0.55)))
		return
	if ai_state == "recovery" and state_timer > 0.0:
		velocity = Vector2.ZERO
		_play_animation("idle")
		return
	ai_state = "pursue"
	if distance <= attack_range + float(behavior_tuning.get("hop_distance",54.0)) * 0.8 and attack_cooldown <= 0.0:
		ai_state = "hop_windup"
		state_timer = float(behavior_tuning.get("hop_windup",0.28))
		attack_cooldown = float(behavior_tuning.get("cooldown",1.1))
		facing_name = SlasherSpriteLibrary.direction_name(global_position.direction_to(target.global_position),facing_name)
		_play_animation("idle",true)
		return
	_move_toward(target.global_position)

# ------------------------------------------------------------------ bandits

func _face_target() -> void:
	facing_name = "left" if target.global_position.x < global_position.x else "right"

func _process_cutthroat(delta: float) -> void:
	var distance := global_position.distance_to(target.global_position)
	if ai_state == "windup":
		velocity = Vector2.ZERO
		_face_target()
		if state_timer <= 0.0: _begin_dash(float(behavior_tuning.get("lunge_distance",190.0)))
		return
	if ai_state == "dash":
		_process_dash(delta,float(behavior_tuning.get("lunge_speed",520.0)),float(behavior_tuning.get("damage_multiplier",1.3)),float(behavior_tuning.get("recovery",0.7)))
		return
	if ai_state == "recovery" and state_timer > 0.0:
		velocity = Vector2.ZERO
		_play_animation("idle")
		return
	ai_state = "pursue"
	var circle_range := float(behavior_tuning.get("circle_range",120.0))
	if special_cooldown <= 0.0 and distance <= float(behavior_tuning.get("lunge_range",200.0)) and _clear_shot():
		ai_state = "windup"
		state_timer = float(behavior_tuning.get("lunge_windup",0.42))
		captured_target = target.global_position
		charge_direction = global_position.direction_to(captured_target)
		_face_target()
		_play_animation("attack",true)
		sprite.pause()
		return
	if distance > circle_range * 1.2:
		_move_toward(target.global_position)
	elif distance < circle_range * 0.6:
		_move_toward(global_position + target.global_position.direction_to(global_position) * 80.0)
	else:
		# Circle the target while the lunge recharges.
		var around := (global_position - target.global_position).normalized().rotated(strafe_sign * 0.6) * circle_range
		_move_toward(target.global_position + around)
		if is_on_wall(): strafe_sign = -strafe_sign
	_face_target()

func _process_knifethrower() -> void:
	var distance := global_position.distance_to(target.global_position)
	var preferred := float(behavior_tuning.get("preferred_range",230.0))
	if ai_state == "throw_windup" and is_instance_valid(target):
		velocity = Vector2.ZERO
		_face_target()
		if state_timer <= 0.0:
			throws += 1
			var fan := creature_floor >= int(behavior_tuning.get("fan_floor",3)) and throws % 3 == 0
			_throw_knives(3 if fan else 1)
			ai_state = "pursue"
			attack_cooldown = float(behavior_tuning.get("cooldown",1.8))
		return
	if distance < float(behavior_tuning.get("retreat_range",130.0)):
		_move_toward(global_position + target.global_position.direction_to(global_position) * preferred)
	elif distance > preferred * 1.3 or not _clear_shot():
		_move_toward(target.global_position)
	elif attack_cooldown <= 0.0:
		ai_state = "throw_windup"
		state_timer = float(behavior_tuning.get("telegraph",0.45))
		_face_target()
		_play_animation("attack",true)
	else:
		velocity = Vector2.ZERO
		if animation_lock <= 0.0: _play_animation("idle")
	_face_target()

func _throw_knives(count: int) -> void:
	var aim := global_position.direction_to(target.global_position + target.velocity * 0.25)
	for index in count:
		var offset := (float(index) - float(count - 1) * 0.5) * 0.22
		var config := {"projectile_speed":float(behavior_tuning.get("knife_speed",330.0)),"projectile_range":float(behavior_tuning.get("knife_range",430.0)),"hit_radius":12.0,"color":String(behavior_tuning.get("projectile_color","#dfe6ee")),"visual_type":String(behavior_tuning.get("projectile_visual","knife"))}
		var knife := HOSTILE_PROJECTILE.new().setup(self,target,global_position + aim * 18.0,aim.rotated(offset),damage,config)
		get_parent().add_child(knife)
	AudioCue.play_from(self,"sword_swing")

func _clear_shot() -> bool:
	if not is_inside_tree(): return false
	var query := PhysicsRayQueryParameters2D.create(global_position,target.global_position,1)
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == target

func receive_hit(amount:int,knockback:Vector2=Vector2.ZERO,attacker:SlasherPlayer=null,stun_duration:float=-1.0,shake_multiplier:float=1.0,sound_event:String="impact")->int:
	if kind == "sporeling" and ai_state == "dormant": wake()
	return super.receive_hit(amount,knockback,attacker,stun_duration,shake_multiplier,sound_event)

func _draw() -> void:
	if kind == "sporeling" and ai_state == "dormant":
		# Dormant caps look like ordinary forest mushrooms: no health bar. Hidden
		# creatures (grave rats) lie under a pile of bones.
		if sprite != null and not sprite.visible: _draw_bone_pile()
		return
	# Lift the shared health bar above the head of taller sprites.
	var lift := float(visual_tuning.get("bar_lift",0.0))
	draw_set_transform(Vector2(0,-lift))
	super._draw()
	draw_set_transform(Vector2.ZERO)
	if ai_state == "hop_windup":
		draw_arc(Vector2.ZERO,16.0,0.0,TAU,20,Color(0.85,0.82,0.62,0.7),2.0)
	if ai_state == "throw_windup":
		draw_line(Vector2.ZERO,to_local(target.global_position).limit_length(60.0),Color(0.95,0.95,1.0,0.6),2.0)

func _draw_bone_pile() -> void:
	var bone := Color("#b9b1a0"); var dark := Color("#3c3740")
	draw_set_transform(Vector2(0,4),0.0,Vector2(1.0,0.45)); draw_circle(Vector2.ZERO,16,Color(0,0,0,0.3)); draw_set_transform(Vector2.ZERO)
	for spec in [[Vector2(-9,-2),0.4],[Vector2(6,-4),-0.6],[Vector2(-2,3),1.2],[Vector2(9,3),0.1]]:
		var tip := Vector2.RIGHT.rotated(float(spec[1])) * 8.0
		draw_line(Vector2(spec[0]) - tip,Vector2(spec[0]) + tip,dark,5.0); draw_line(Vector2(spec[0]) - tip,Vector2(spec[0]) + tip,bone,3.0)
	draw_circle(Vector2(0,-6),6,bone); draw_circle(Vector2(-2,-7),1.5,dark); draw_circle(Vector2(2,-7),1.5,dark)
