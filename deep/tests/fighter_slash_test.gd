extends SceneTree

class Target extends Node2D:
	var hits:=0
	func receive_attack(_data:Dictionary,_source:Node)->void:hits+=1

var failures:Array[String]=[]
func _initialize()->void:call_deferred("_run")
func _expect(condition:bool,message:String)->void:
	if not condition:failures.append(message)
func _run()->void:
	var state:=RunState.new();state.set_class("warrior");state.start_new_run(GearData.create("slash_test","Slash Test",2,false,0,"","","warrior"),"forest")
	var player:=SlasherPlayer.new();player.setup(state);root.add_child(player);player.set_physics_process(false);player.weapon_trails.set_physics_process(false)
	var tuning:Dictionary=player._ability_tuning("basic")
	var reach:=float(tuning.reach);var half:=deg_to_rad(float(tuning.arc_degrees)*0.5)
	for angle in [0.0,PI*0.25,PI*0.5,PI,PI*1.5]:
		player.global_position=Vector2(200,200);player.aim_direction=Vector2.from_angle(angle)
		var targets:Array[Target]=[]
		for sample in [Vector2(reach-0.1,0),Vector2(reach+0.1,0),Vector2.from_angle(half-0.001)*reach*0.8,Vector2.from_angle(half+0.001)*reach*0.8,Vector2(-30,0)]:
			var target:=Target.new();root.add_child(target);target.add_to_group("slasher_damageable");target.global_position=player.global_position+sample.rotated(angle);targets.append(target)
		player._melee_attack(player._configured_attack(tuning,"physical"))
		for index in targets.size():
			_expect(targets[index].hits==(1 if index in [0,2] else 0),"Slash boundary mismatch at angle %s, sample %s"%[angle,index]);targets[index].free()
		var strike:Dictionary=player.weapon_trails.history.back()
		_expect(strike.origin==player.global_position and strike.direction.is_equal_approx(player.aim_direction) and strike.reach==reach and strike.degrees==tuning.arc_degrees,"Visual footprint diverged from damage geometry")
		player.global_position+=Vector2(50,30);player.aim_direction=Vector2.LEFT
		_expect(strike.origin==Vector2(200,200),"Movement dragged the resolved slash")
	player.weapon_trails.history.clear()
	for direction in SlasherSpriteLibrary.DIRECTIONS:
		player.facing_name=direction
		player.cooldowns.basic=0.0
		player.use_action("basic")
		_expect(player.sprite.animation==StringName("slash_%s"%direction),"Missing directional slash pose")
		for index in player.sprite.sprite_frames.get_frame_count(player.sprite.animation):
			_expect(player.sprite.sprite_frames.get_frame_texture(player.sprite.animation,index)!=null,"Missing slash sprite frame")
		var strike:Dictionary=player.weapon_trails.history.back()
		_expect(float(strike.duration)<=0.18,"Finisher recovery stretched slash feedback")
		player.weapon_trails._physics_process(float(strike.duration)+0.001)
		_expect(player.weapon_trails.history.is_empty(),"Old slash survives into next attack")
	player.active_buff_time=2.0;player.active_buff_haste=3.0;player.warrior_slash_chain=0;player.cooldowns.basic=0.0;player.use_action("basic")
	_expect(is_equal_approx(float(player.weapon_trails.history.back().duration),float(player.cooldowns.basic)),"Haste desynchronizes sprite and slash")
	player.free()
	if failures.is_empty():print("FIGHTER_SLASH_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)
