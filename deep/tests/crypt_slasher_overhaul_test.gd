extends SceneTree

const CRYPT:=preload("res://scenes/slasher/SlasherCrypt.tscn")
const CRYPT_ENEMY:=preload("res://scripts/slasher/slasher_crypt_enemy.gd")
const CRYPT_HAZARD:=preload("res://scripts/slasher/slasher_crypt_hazard.gd")

func _initialize()->void:call_deferred("_run")
func _run()->void:
	var failures:Array[String]=[];var state:=RunState.new();state.set_class("warrior");state.start_new_run(GearData.create("crypt_test","Crypt Test",3,true,1,"","","warrior"),"crypt","slasher")
	var floor_seven:=SlasherForestGenerator.generate(7717,7,"crypt");var floor_seven_copy:=SlasherForestGenerator.generate(7717,7,"crypt");_expect(bool(floor_seven.is_boss_floor) and not bool(floor_seven.is_elite_floor) and floor_seven==floor_seven_copy,"Crypt floor seven is not a deterministic boss floor",failures)
	var floor_four:=SlasherForestGenerator.generate(4404,4,"crypt");_expect(bool(floor_four.is_elite_floor) and not bool(floor_four.is_boss_floor),"Crypt floor four is not the elite gauntlet",failures)
	var scene:=CRYPT.instantiate();scene.setup(null,state);root.add_child(scene);await process_frame;await process_frame
	_expect(scene.get_script().resource_path.ends_with("slasher_crypt.gd"),"Crypt did not use its dedicated runtime",failures)
	_expect(scene.ground_layer.get_child_count()==Dictionary(scene.layout.cells).size(),"Stone floor did not cover every walkable Crypt cell",failures)
	_expect(not scene.crypt_hazards.is_empty() and scene.crypt_hazards[0] is SlasherCryptHazard,"Crypt hazards were not installed",failures)
	var archer:=CRYPT_ENEMY.new();archer.configure(4,false,"skeletal_archer",false,"skeletal_archer");scene.actor_layer.add_child(archer);archer.global_position=scene.player.global_position+Vector2(220,0);archer.target=scene.player;archer.pathfinder=scene.pathfinder;archer.activation_delay=0.0;archer.attack_cooldown=0.0;archer._begin_ranged_windup(float(archer.behavior_tuning.telegraph));_expect(archer.ai_state=="ranged_windup" and archer.state_timer>0.0,"Skeletal archer did not expose a telegraphed ranged attack",failures)
	var boss:=CRYPT_ENEMY.new();boss.configure(7,true,"crypt_boss",false,"crypt_lord");scene.actor_layer.add_child(boss);boss.target=scene.player;boss.pathfinder=scene.pathfinder;boss.activation_delay=0.0;boss.health=roundi(boss.max_health*0.69);boss._process_crypt_lord();_expect(boss.boss_phase==1 and boss.transition_time>0.0,"Crypt Lord phase two transition failed",failures);boss.transition_time=0.0;boss.health=roundi(boss.max_health*0.34);boss._process_crypt_lord();_expect(boss.boss_phase==2,"Crypt Lord phase three transition failed",failures)
	boss.transition_time=0.0;boss.pattern_cooldown=0.0;boss._process_crypt_lord();_expect(boss.ai_state=="boss_windup" and boss.state_timer>0.0,"Crypt Lord pattern lacked a readable windup",failures);boss.state_timer=0.0;boss._process_crypt_lord();for ignored:int in 8:boss._radial_ring(14,0.0,180.0,0.2,true);_expect(get_nodes_in_group("crypt_projectile").size()<=boss.projectile_cap,"Crypt projectile cap was exceeded",failures)
	var projectile:=SlasherHostileProjectile.new().setup(boss,scene.player,boss.global_position,Vector2.RIGHT,2,{"movement_pattern":"curve","angular_velocity":1.0,"visual_type":"soul","lifetime":2.0});scene.actor_layer.add_child(projectile);var original:=projectile.direction;projectile._physics_process(0.1);_expect(projectile.direction!=original,"Curved hostile projectile did not rotate",failures)
	var hazard:SlasherCryptHazard=scene.crypt_hazards[0];hazard.telegraph();_expect(hazard.phase==SlasherCryptHazard.Phase.TELEGRAPH,"Crypt hazard did not enter its warning state",failures);hazard.activate();_expect(hazard.phase==SlasherCryptHazard.Phase.ACTIVE,"Crypt hazard did not activate",failures);hazard.disable();_expect(hazard.phase==SlasherCryptHazard.Phase.DISABLED and not hazard.visible,"Cleared Crypt hazard remained dangerous",failures)
	state.class_resource=0;scene.player.suppress_resource_gain(1.0);var result:Dictionary={"resource_gained":0};scene.player._gain_resource(result,2);_expect(state.class_resource==0 and int(result.resource_gained)==0,"Curse resource suppression granted resource",failures)
	scene.queue_free();await process_frame
	if failures.is_empty():print("CRYPT_SLASHER_OVERHAUL_TESTS_PASSED");quit(0)
	else:
		for failure:String in failures:push_error(failure)
		quit(1)
func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
