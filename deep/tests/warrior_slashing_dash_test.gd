extends SceneTree

func _initialize()->void:
	call_deferred("_run")

func _run()->void:
	var failures:Array[String]=[]
	var input_tuning:Dictionary=GameBalance.get_slasher_balance("input")
	_expect(float(input_tuning.get("held_basic_cooldown_multiplier",0.0))>=2.0,"Held basic attacks are not meaningfully slower than clicked attacks.",failures)

	var state:=RunState.new();state.set_class("warrior");state.start_new_run(GearData.create("dash_test","Dash Test",2,false,0,"","","warrior"),"forest","slasher")
	var player:=SlasherPlayer.new();player.setup(state);root.add_child(player);player.set_physics_process(false);player.global_position=Vector2.ZERO;player.aim_direction=Vector2.RIGHT
	var first:=_enemy_at(Vector2(105.0,0.0));var second:=_enemy_at(Vector2(245.0,0.0));await process_frame
	var first_health:=first.health;var second_health:=second.health;var player_health:=player.health
	var result:Dictionary=player.use_action("movement")
	_expect(player.global_position==Vector2.ZERO and player.warrior_dash_active,"Warrior movement still teleports instead of beginning a dash.",failures)
	_expect(float(result.get("dash_duration",0.0))>0.2 and player.invulnerable>=float(result.get("dash_duration",0.0)),"Slashing dash does not expose a visible, invulnerable travel window.",failures)
	var frames:=0
	while player.warrior_dash_active and frames<30:
		player._process_warrior_dash(0.04);frames+=1
		if frames==2:player.receive_damage(3,Vector2.ZERO)
	_expect(not player.warrior_dash_active and frames>1 and player.global_position.x>300.0,"Slashing dash did not move rapidly across its full path over multiple frames.",failures)
	_expect(first.health<first_health and second.health<second_health,"Slashing dash did not damage every enemy along its path.",failures)
	_expect(player.health==player_health,"Warrior took damage during the invulnerable slashing dash.",failures)

	player.free();first.free();second.free();await process_frame
	if failures.is_empty():print("WARRIOR_SLASHING_DASH_TESTS_PASSED");quit(0)
	else:
		for failure:String in failures:push_error(failure)
		quit(1)

func _enemy_at(position_value:Vector2)->SlasherEnemy:
	var enemy:=SlasherEnemy.new();enemy.configure(1,false,"feral_wolf");root.add_child(enemy);enemy.set_physics_process(false);enemy.global_position=position_value;return enemy

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
