extends SceneTree

func _initialize()->void:
	call_deferred("_run")

func _run()->void:
	var failures:Array[String]=[]
	await _test_basic_deflection("warrior",failures)
	await _test_basic_deflection("rogue",failures)
	await _test_rogue_kit(failures)
	if failures.is_empty():print("ROGUE_ABILITIES_TESTS_PASSED");quit(0)
	else:
		for failure:String in failures:push_error(failure)
		quit(1)

func _test_basic_deflection(class_id:String,failures:Array[String])->void:
	var state:=_state_for(class_id)
	var player:=SlasherPlayer.new();player.setup(state);root.add_child(player);player.set_physics_process(false);player.global_position=Vector2.ZERO;player.aim_direction=Vector2.RIGHT
	var projectile:=SlasherHostileProjectile.new().setup(null,player,Vector2(60.0,0.0),Vector2.LEFT,3,{"projectile_range":300.0,"projectile_speed":280.0});projectile.process_mode=Node.PROCESS_MODE_DISABLED;root.add_child(projectile);await process_frame
	var result:Dictionary=player.use_action("basic")
	_expect(int(result.get("projectiles_deflected",0))==1,"%s basic did not deflect a projectile in its attack arc."%class_id,failures)
	_expect(projectile.deflected_by==player and projectile.direction.x>0.9,"%s basic did not reflect the projectile along its aim direction."%class_id,failures)
	var enemy:=_enemy_at(Vector2(92.0,0.0));await process_frame;var health_before:=enemy.health;projectile._physics_process(0.12)
	_expect(enemy.health<health_before,"%s reflected projectile did not damage an enemy."%class_id,failures)
	player.free();enemy.free()
	if is_instance_valid(projectile):projectile.free()
	await process_frame

func _test_rogue_kit(failures:Array[String])->void:
	var state:=_state_for("rogue")
	var player:=SlasherPlayer.new();player.setup(state);root.add_child(player);player.set_physics_process(false);player.global_position=Vector2.ZERO;player.aim_direction=Vector2.RIGHT
	var front:=_enemy_at(Vector2(45.0,0.0));var rear:=_enemy_at(Vector2(90.0,0.0));await process_frame;var front_health:=front.health;var rear_health:=rear.health
	var pierce:Dictionary=player.use_action("basic")
	_expect(int(pierce.get("targets_hit",0))==2 and front.health<front_health and rear.health<rear_health,"Pierce did not strike aligned front and rear targets.",failures)
	front.free();rear.free();await process_frame

	var shadow_target:=_enemy_at(Vector2(70.0,0.0));await process_frame;player.cooldowns.movement=0.0;player.global_position=Vector2.ZERO
	var shadowstep:Dictionary=player.use_action("movement")
	_expect(bool(shadowstep.get("passed_through_target",false)) and player.global_position.x>shadow_target.global_position.x and player.is_hidden,"Shadowstep did not pass through its aimed target and grant Hidden.",failures)
	shadow_target.free();await process_frame

	player.global_position=Vector2(-10000.0,-10000.0);player.cooldowns.special=0.0;state.class_resource=state.get_class_resource_max();var edge_before:=state.class_resource
	var missed_assassinate:Dictionary=player.use_action("special")
	_expect(not bool(missed_assassinate.get("started",true)) and state.class_resource==edge_before and is_zero_approx(float(player.cooldowns.special)),"A targetless Assassinate consumed Edge or started its cooldown.",failures)

	player.global_position=Vector2.ZERO;player.aim_direction=Vector2.RIGHT;player.cooldowns.special=0.0;player.is_hidden=true;player.hidden_time=1.0;state.class_resource=state.get_class_resource_max()
	var victim:=_enemy_at(Vector2(65.0,0.0));await process_frame;var victim_health:=victim.health;var assassinate:Dictionary=player.use_action("special")
	_expect(bool(assassinate.get("started",false)) and victim.health<victim_health and not player.is_hidden,"Assassinate did not damage its target and consume Hidden.",failures)
	victim.free();await process_frame

	state.class_resource=0;player.cooldowns.defensive=0.0;player.global_position=Vector2.ZERO;player.aim_direction=Vector2.RIGHT
	player.use_action("defensive");player.receive_damage(2,Vector2.ZERO);player.receive_damage(2,Vector2.ZERO)
	_expect(state.class_resource==1,"Evade awarded Edge more than once during one defensive window.",failures)
	player.free();await process_frame

func _state_for(class_id:String)->RunState:
	var state:=RunState.new();state.set_class(class_id);state.start_new_run(GearData.create("test_"+class_id,"Test",2,false,0,"","",class_id),"forest","slasher");return state

func _enemy_at(position_value:Vector2)->SlasherEnemy:
	var enemy:=SlasherEnemy.new();enemy.configure(1,false,"feral_wolf");root.add_child(enemy);enemy.set_physics_process(false);enemy.global_position=position_value;return enemy

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
