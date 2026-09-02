extends CharacterBody2D

var owner_player: SlasherPlayer
var attack_cooldown := 0.0
var sprite: AnimatedSprite2D
var facing_name := "right"
var animation_lock := 0.0
var tuning:Dictionary={}
var pathfinder:SlasherGridPathfinder
var owner_character_id:=""
var owner_attack_power:=1
var owner_spell_power:=1
var owner_resource_max:=1

func setup(value:SlasherPlayer,character_id:String="")->void:
	owner_player=value;owner_character_id=character_id;pathfinder=value.pathfinder;tuning=value.run_state.get_effective_slasher_companion_tuning("wolf") if value.run_state!=null else GameBalance.get_slasher_companion_tuning("wolf");owner_attack_power=value.attack_power;owner_spell_power=value.spell_power;owner_resource_max=value.run_state.get_class_resource_max() if value.run_state!=null else 1;queue_redraw()
func _ready() -> void:
	if tuning.is_empty():tuning=GameBalance.get_slasher_companion_tuning("wolf")
	var shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=float(tuning.get("collision_radius",10.0));shape.shape=circle;add_child(shape)
	sprite=AnimatedSprite2D.new();sprite.name="AnimatedSprite2D";sprite.sprite_frames=SlasherSpriteLibrary.companion_frames();sprite.position=Vector2(0,-23);sprite.scale=Vector2(0.58,0.58);add_child(sprite);_play_animation("idle")
func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_player):queue_free();return
	attack_cooldown=maxf(0,attack_cooldown-delta)
	animation_lock=maxf(0,animation_lock-delta)
	var target:SlasherEnemy=get_meta("marked",null) as SlasherEnemy
	if not is_instance_valid(target):
		var follow:Array=tuning.get("follow_offset",[-24,18]);var follow_position:=owner_player.global_position+Vector2(float(follow[0]),float(follow[1]))
		var command_position:Vector2=get_meta("command_position",follow_position)
		var commanded:=global_position.distance_to(command_position)>float(tuning.get("command_distance",24.0));var destination:=command_position if commanded else follow_position
		var follow_waypoint:=pathfinder.next_waypoint(global_position,destination) if pathfinder!=null else destination
		velocity=global_position.direction_to(follow_waypoint)*float(tuning.get("command_speed" if commanded else "follow_speed",120.0)) if global_position.distance_to(destination)>float(tuning.get("follow_distance",40.0)) else Vector2.ZERO
		if not commanded and has_meta("command_position") and attack_cooldown<=0.0:
			var prop:SlasherBreakableProp=_breakable_near(command_position,float(tuning.get("pounce_range",30.0)))
			if is_instance_valid(prop):_attack_damageable(prop)
	else:
		var combat_waypoint:=pathfinder.next_waypoint(global_position,target.global_position) if pathfinder!=null else target.global_position
		velocity=global_position.direction_to(combat_waypoint)*float(tuning.get("pounce_speed",260.0) if get_meta("pounce",false) else tuning.get("combat_speed",145.0))
		if global_position.distance_to(target.global_position)<float(tuning.get("pounce_range",30.0)) and attack_cooldown<=0:
			_attack_damageable(target);_grant_owner_resource(int(tuning.get("resource_gain",1)));set_meta("pounce",false)
	if velocity.length()>0.1:facing_name=SlasherSpriteLibrary.direction_name(velocity,facing_name)
	if animation_lock<=0.0:_play_animation("run" if velocity.length()>0.1 else "idle")
	move_and_slide()
func _attack_damageable(target:Node2D)->void:
	var power:int=owner_spell_power if String(tuning.get("power_stat","attack_power"))=="spell_power" else owner_attack_power
	var damage:int=maxi(1,int(round(power*float(tuning.get("damage_coefficient",1.0))))+int(tuning.get("flat_damage",0)));target.call("receive_attack",{"damage":damage,"damage_type":"physical","knockback":0.0},owner_player);attack_cooldown=float(tuning.get("attack_cooldown",0.8));_play_animation("attack");animation_lock=float(tuning.get("animation_lock",0.3))

func _grant_owner_resource(amount:int)->void:
	if amount<=0 or not is_instance_valid(owner_player) or owner_player.run_state==null:return
	var state:=owner_player.run_state
	if state.active_character_id==owner_character_id:
		state.gain_class_resource(amount);owner_player.resource_changed.emit(state.class_resource,state.get_class_resource_max());return
	if state.campaign==null or not state.campaign.expedition.active:return
	var runtime:Dictionary=state.campaign.expedition.member_runtime.get(owner_character_id,{});runtime["resource"]=mini(owner_resource_max,int(runtime.get("resource",0))+amount);state.campaign.expedition.member_runtime[owner_character_id]=runtime
func _breakable_near(center:Vector2,radius:float)->SlasherBreakableProp:
	for node_value:Variant in get_tree().get_nodes_in_group("slasher_damageable"):
		var prop:SlasherBreakableProp=node_value as SlasherBreakableProp
		if is_instance_valid(prop) and center.distance_to(prop.global_position)<=radius:return prop
	return null
func _draw()->void:
	if sprite==null or sprite.sprite_frames==null:draw_circle(Vector2.ZERO,10,Color("#8ca86a"))
func _play_animation(state:String)->void:
	if sprite==null or sprite.sprite_frames==null:return
	var animation:=SlasherSpriteLibrary.resolved_animation(sprite.sprite_frames,state,facing_name)
	if not animation.is_empty() and sprite.animation!=animation:sprite.play(animation)
