extends SceneTree

func _init() -> void:GameBalance.set_actions_override(GameBalance.ALL_ACTIONS)
const GROUND:=preload("res://scenes/slasher/TestingGround.tscn")
const KITS:=preload("res://scripts/slasher/slasher_warrior_kits.gd")
const IDS:=preload("res://scripts/slasher/slasher_fighter_arsenal.gd").WEAPON_IDS
var ground:Node
var failures:Array[String]=[]

func _initialize() -> void:call_deferred("run")
func check(value:bool,message:String)->void:
	if not value:failures.append(message)
func foes()->Array[SlasherEnemy]:
	var result:Array[SlasherEnemy]=[]
	for child in ground.combat_root.get_children():
		if child is SlasherEnemy and not child.dead:result.append(child)
	return result
func equip(id:String,mode:String="cluster")->void:
	ground.class_picker.select(0);ground._refresh_class()
	for index in ground.gear_options.size():
		if ground.gear_options[index].id==id:ground.gear_picker.select(index);break
	ground.dummy_mode=mode;ground.apply_build();ground.set_editor_visible(false)
	await physics_frame;await process_frame
	ground.player.set_physics_process(false);ground.player.warrior_combo_effects.set_physics_process(false);ground.player.warrior_kit.set_physics_process(false)
func clear_cooldowns()->void:ground.player.cooldowns={"basic":0.0,"special":0.0,"defensive":0.0,"movement":0.0}
func strike(kit:Node,enemy:SlasherEnemy,damage:int=5)->int:
	return kit.hit(enemy,{"damage":damage,"damage_type":"physical","damage_source":"Test","warrior_kit":kit.weapon_id,"warrior_cast":1,"warrior_resource":false},true)

func run()->void:
	ground=GROUND.instantiate();root.add_child(ground);await process_frame
	for id in IDS:
		check(KITS.has_kit(id),"Missing warrior kit registration: "+id)
		var entry:=HearthCatalog.item(id)
		check(not entry.is_empty() and entry.class_id=="warrior" and entry.slot=="weapon","Missing acquirable armory entry: "+id)
		check(entry.sources.has("merchant") and entry.sources.size()>1,"Weapon needs merchant and dungeon acquisition: "+id)
	await test_eldritch();await test_demon();await test_storm();await test_sling();await test_dagger()
	await test_archon();await test_hammer();await test_reaver();await test_shield();await test_umbral()
	ground.queue_free();await process_frame
	for failure in failures:push_error(failure)
	print("Fighter arsenal: PASS" if failures.is_empty() else "Fighter arsenal: FAIL")
	quit(0 if failures.is_empty() else 1)

func test_eldritch()->void:
	await equip("eldritch_bowstaff","single");var kit:Node=ground.player.warrior_kit;var enemy:SlasherEnemy=foes()[0]
	strike(kit,enemy,3);strike(kit,enemy,3);enemy.dead=true;kit.on_direct_hit(enemy,{"warrior_kit":"eldritch_bowstaff","warrior_resource":false})
	check(kit.last_proc_count==3 and kit.spawned_beasts==3,"Eldritch curse death must spawn one mini-beast per stack")

func test_demon()->void:
	await equip("demon_blade","single");var kit:Node=ground.player.warrior_kit;var enemy:SlasherEnemy=foes()[0];var normal_cd:float=kit.tuning("basic").cooldown
	strike(kit,enemy,2)
	check(kit.frenzy_left>0 and kit.tuning("basic").cooldown<normal_cd,"Demon Blade blood draw must grant attack speed")
	check(kit.modify_incoming_damage(7)==14 and kit.attack_for("basic","Test").damage>ground.player._configured_attack(kit.tuning("basic"),"physical").damage,"Demon frenzy must boost damage and double incoming damage")

func test_storm()->void:
	await equip("storm_trident","single");var player:SlasherPlayer=ground.player;var kit:Node=player.warrior_kit;var enemy:SlasherEnemy=foes()[0]
	enemy.global_position=player.global_position+Vector2(180,0);kit._throw_trident(kit.attack_for("special","Skyfall"));kit.missiles[0].destination=enemy.global_position;kit.trident.destination=enemy.global_position
	kit._physics_process(1.0)
	check(kit.pins.has(enemy.get_instance_id()) and not kit.trident.is_empty(),"Storm Trident must pin targets and remain deployed")
	var storm_dealt:=strike(kit,enemy,4);check(storm_dealt==8,"Pinned targets must take double damage")
	player.global_position=kit.trident.position;kit._physics_process(0.01);check(kit.trident.is_empty(),"Storm Trident must be retrievable")

func test_sling()->void:
	await equip("valkyrian_sling","single");var player:SlasherPlayer=ground.player;var kit:Node=player.warrior_kit
	kit._launch_sling(kit.attack_for("basic","Flight"),false);kit.missiles[0].returning=true;kit.missiles[0].position=player.global_position+Vector2(50,0)
	clear_cooldowns();var result:=player.use_action("defensive")
	check(result.projectiles_deflected==1 and kit.sling_damage_stacks==1 and not kit.missiles[0].returning,"Return Parry must relaunch and stack sling damage")

func test_dagger()->void:
	await equip("dragonbone_dagger","single");var kit:Node=ground.player.warrior_kit;var enemy:SlasherEnemy=foes()[0];enemy.health=100
	var first:=strike(kit,enemy,10);var second:=strike(kit,enemy,10)
	check(first==10 and second>first and kit.wounds[enemy.get_instance_id()].stacks==2,"Dragonbone wounds must stack and reduce effective armor")

func test_archon()->void:
	await equip("archon_crossbow","cluster");var player:SlasherPlayer=ground.player;var kit:Node=player.warrior_kit;var enemies:Array[SlasherEnemy]=foes()
	player.global_position=Vector2(-160,0);player.aim_direction=Vector2.RIGHT
	for index in mini(3,enemies.size()):enemies[index].global_position=player.global_position+Vector2(90+index*70,0);enemies[index].health=100
	kit._launch_archon(kit.attack_for("basic","Bolt"),false)
	for step in 12:kit._physics_process(0.05)
	check(kit.last_proc_count>=2,"Archon bolt must pierce multiple creatures")
	check(enemies[1].total_damage>enemies[0].total_damage,"Archon bolt damage must grow for each creature speared")

func test_hammer()->void:
	await equip("divine_hammer","cluster");var kit:Node=ground.player.warrior_kit;var enemies:Array[SlasherEnemy]=foes();var primary:SlasherEnemy=enemies[0];var next:SlasherEnemy=enemies[1]
	primary.global_position=ground.player.global_position+Vector2(60,0);next.global_position=primary.global_position+Vector2(150,0);primary.dead=true
	kit.on_direct_hit(primary,{"damage":8,"damage_type":"physical","damage_source":"Test","warrior_kit":"divine_hammer","warrior_resource":false})
	check(kit.repeat_smashes==1 and next.total_damage>0 and ground.player.cooldowns.basic==0.0,"Divine kill must refresh and instantly repeat on nearest enemy")

func test_reaver()->void:
	await equip("grim_reaver","single");var kit:Node=ground.player.warrior_kit;var enemy:SlasherEnemy=foes()[0];enemy.dead=true;kit.on_direct_hit(enemy,{"warrior_kit":"grim_reaver","warrior_resource":false})
	check(kit.rampage_stacks==1 and kit.rampage_left>0,"Grim Reaver kill must begin stacking rampage")
	var criticals:=0
	for index in 80:
		if kit.attack_for("basic","Rate").get("critical",false):criticals+=1
	check(criticals>=12,"Grim Reaver must have a materially high critical rate")

func test_shield()->void:
	await equip("sentinel_shield","single");var player:SlasherPlayer=ground.player
	var enemy:=SlasherEnemy.new();enemy.configure(1);ground.combat_root.add_child(enemy);await process_frame;enemy.set_physics_process(false)
	player.aim_direction=Vector2.RIGHT;enemy.global_position=player.global_position+Vector2(70,0);var before:=enemy.global_position.x;clear_cooldowns();ground.state.class_resource=3;player.use_action("special")
	check(enemy.global_position.x>before+100,"Sentinel Bash must shove enemies a meaningful distance");enemy.queue_free()

func test_umbral()->void:
	await equip("umbral_bow","single");var player:SlasherPlayer=ground.player;var kit:Node=player.warrior_kit;var enemy:SlasherEnemy=foes()[0]
	player.aim_direction=Vector2.RIGHT;enemy.global_position=player.global_position+Vector2(100,0);kit._launch_umbral(kit.attack_for("basic","Shadow"),false)
	for step in 5:kit._physics_process(0.04)
	check(kit.leashes.has(enemy.get_instance_id()),"Umbral arrow must leash the enemy shadow")
	kit._physics_process(0.02);check(enemy.movement_slow<=0.55 and player.kit_buffs.speed_multiplier()>1.0,"Umbral leash must slow the enemy and hasten the fighter")
