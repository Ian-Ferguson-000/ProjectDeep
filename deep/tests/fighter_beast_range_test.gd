extends "res://tests/fighter_production_test.gd"

func _run()->void:
	fixture("eldritch_bowstaff")
	kit.rules.summon_search_range=60
	kit.rules.summon_search_interval=0.35
	kit.rules.summon_attack_range=20
	kit.rules.summon_engage_range=18
	var victim:=foe(1);strike(victim,1,10)
	var beasts:=get_nodes_in_group("corrupted_mini_beast")
	expect(beasts.size()==1,"One lethal staff strike spawns one test beast")
	var beast:CorruptedMiniBeast=beasts[0];beast.set_physics_process(false)
	expect(beast.search_range==60 and beast.search_interval==0.35 and beast.attack_range==20 and beast.engage_range==18,"Summon receives authored search and contact tuning")
	var target:=foe();target.position=beast.position+Vector2(80,0)
	beast._physics_process(0.01)
	expect(beast.target_reference==null and is_equal_approx(beast.search_left,0.35),"Out-of-range enemy is not acquired; search uses authored interval")
	target.position=beast.position+Vector2(30,0);beast.search_left=0;beast.age=1;beast.move_speed=0
	beast._physics_process(0.01)
	expect(beast.target_reference.get_ref()==target and beast.attack_windup==0,"Target inside search range but beyond engagement is tracked without attacking")
	target.position=beast.position+Vector2(16,0)
	beast._physics_process(0.01)
	expect(beast.attack_windup>0 and target.health==target.max_health,"Configured engagement distance starts windup without immediate damage")
	target.position=beast.position+Vector2(25,0)
	beast._physics_process(0.13)
	expect(target.health==target.max_health,"Target escaping configured contact range avoids the bite")
	target.position=beast.position+Vector2(16,0);beast.attack_cooldown=0
	beast._physics_process(0.01);beast._physics_process(0.13)
	expect(target.health<target.max_health,"Bite succeeds inside configured contact range")
	await clear()
	print("Fighter beast ranges: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
