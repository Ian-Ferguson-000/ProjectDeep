extends SceneTree

const COMBOS:=preload("res://scripts/slasher/slasher_combo_runtime.gd")
const CODEX:=preload("res://scripts/slasher/slasher_codex_menu.gd")

func _initialize()->void:call_deferred("_run")

func _run()->void:
	var failures:Array[String]=[]
	var mage:Array[Dictionary]=GameBalance.get_slasher_combos("mage");var warrior:Array[Dictionary]=GameBalance.get_slasher_combos("warrior")
	_expect(mage.size()==3 and warrior.size()==4,"Mage must expose three combos and Warrior must expose four",failures)
	_expect(String(GameBalance.get_class_action("mage","special").get("name",""))=="Fireball","Mage special was not renamed to Fireball",failures)

	var runtime=COMBOS.new();runtime.setup("mage")
	runtime.record_action("basic");runtime.record_action("basic");runtime.record_action("movement");var volley:Dictionary=runtime.record_action("special")
	_expect(String(Dictionary(volley.triggered).get("id",""))=="spellstorm_volley","Spellstorm Volley recipe did not resolve",failures)
	runtime.setup("mage");runtime.record_confirmation("repel_hit");runtime.record_action("basic");var prism:Dictionary=runtime.record_action("special")
	_expect(String(Dictionary(prism.triggered).get("id",""))=="force_prism","Force Prism recipe did not resolve",failures)
	runtime.setup("mage");runtime.record_action("special");runtime.tick(2.6);var expired:Dictionary=runtime.record_action("movement")
	_expect(Dictionary(expired.triggered).is_empty(),"Expired combo progress still triggered",failures)
	runtime.setup("mage");runtime.record_action("basic");runtime.record_action("defensive")
	_expect(int(runtime.states.spellstorm_volley.index)==0,"A wrong successful action did not reset Spellstorm progress",failures)

	runtime.setup("warrior");runtime.record_confirmation("parry_success");runtime.record_action("movement");runtime.record_confirmation("movement_hit");var priority:Dictionary=runtime.record_action("special")
	_expect(String(Dictionary(priority.triggered).get("id",""))=="vengeful_spiral","Vengeful Spiral did not override Break the Line",failures)
	runtime.setup("warrior");runtime.record_action("basic");runtime.record_action("basic");runtime.record_action("basic");var flowing:Dictionary=runtime.record_action("movement")
	_expect(String(Dictionary(flowing.triggered).get("id",""))=="flowing_assault","Flowing Assault recipe did not resolve",failures)
	runtime.setup("warrior");runtime.record_action("basic");var saved:Dictionary=runtime.snapshot();var restored=COMBOS.new();restored.setup("warrior");restored.restore(saved);restored.tick(1.0)
	_expect(int(restored.feedback().get("index",0))==1 and float(restored.feedback().get("remaining",0.0))<2.5,"Combo snapshot or benched countdown failed",failures)

	var state:=RunState.new();state.set_class("mage");state.start_new_run(GearData.create("combo_test","Combo Test",2,false,0,"","","mage"),"forest");state.class_resource=state.get_class_resource_max()
	var player:=SlasherPlayer.new();player.setup(state);root.add_child(player);player.set_physics_process(false);player.aim_direction=Vector2.RIGHT;await process_frame
	for slot in ["basic","basic","movement"]:
		player.cooldowns[slot]=0.0;state.class_resource=state.get_class_resource_max();player.use_action(slot)
	player.cooldowns.special=0.0;state.class_resource=state.get_class_resource_max();var cast:Dictionary=player.use_action("special")
	var fireballs:Array[Node]=[]
	for node in root.get_children():
		if node is SlasherProjectile and String((node as SlasherProjectile).attack.get("visual",""))=="fireball":fireballs.append(node)
	_expect(String(cast.get("combo_id",""))=="spellstorm_volley" and fireballs.size()==3,"Spellstorm Volley did not create exactly three fireballs",failures)
	if fireballs.size()==3:
		var base_damage:=player._scaled_damage(player._ability_tuning("special"));_expect(int((fireballs[0] as SlasherProjectile).attack.damage)==maxi(1,int(round(base_damage*0.45))),"Spellstorm Volley damage multiplier is incorrect",failures)
	for node in root.get_children():
		if node is SlasherProjectile:node.queue_free()
	await process_frame
	player.combo_runtime.setup("mage");player.cooldowns={"basic":0.0,"special":0.0,"defensive":0.0,"movement":0.0};state.class_resource=state.get_class_resource_max()
	var prism_target:=SlasherEnemy.new();prism_target.configure(1,false,"feral_wolf");root.add_child(prism_target);prism_target.set_physics_process(false);prism_target.global_position=player.global_position+Vector2(40,0);await process_frame
	player.use_action("defensive");player.cooldowns.basic=0.0;player.use_action("basic");player.cooldowns.special=0.0;state.class_resource=state.get_class_resource_max();var prism_cast:Dictionary=player.use_action("special");await process_frame
	var prism_projectile:SlasherProjectile
	for node in root.get_children():
		if node is SlasherProjectile and bool((node as SlasherProjectile).attack.get("force_prism",false)):prism_projectile=node as SlasherProjectile;break
	_expect(String(prism_cast.get("combo_id",""))=="force_prism" and prism_projectile!=null,"Force Prism did not arm its Fireball",failures)
	if prism_projectile!=null:
		var cast_id:=String(prism_projectile.attack.get("combo_cast_id",""));prism_projectile._impact(true);var prism_parts:=0
		for node in root.get_children():
			if node is SlasherProjectile and String((node as SlasherProjectile).attack.get("combo_cast_id",""))==cast_id:prism_parts+=1
		_expect(prism_parts==7,"Force Prism did not create six secondary bolts",failures)
	var codex:=CODEX.new();root.add_child(codex);await process_frame;codex.open(state,player);var codex_copy:=""
	for label in codex.content.find_children("*","RichTextLabel",true,false):codex_copy+=(label as RichTextLabel).text
	_expect("Spellstorm Volley" in codex_copy and "Fireball" in codex_copy,"Codex does not document the Mage combo recipes",failures)
	codex.close();codex.queue_free()
	player.queue_free()
	prism_target.queue_free()
	for node in root.get_children():
		if node is SlasherProjectile:node.queue_free()
	await process_frame

	var warrior_state:=RunState.new();warrior_state.set_class("warrior");warrior_state.start_new_run(GearData.create("combo_blade","Combo Blade",2,false,0,"","","warrior"),"forest");warrior_state.class_resource=warrior_state.get_class_resource_max()
	var warrior_player:=SlasherPlayer.new();warrior_player.setup(warrior_state);root.add_child(warrior_player);warrior_player.set_physics_process(false);warrior_player.aim_direction=Vector2.RIGHT;await process_frame
	warrior_player.cooldowns.defensive=0.0;warrior_player.use_action("defensive")
	_expect(String(warrior_player.sprite.animation).begins_with("defensive_"),"Warrior Parry did not select its dedicated animation",failures)
	warrior_player.cooldowns.special=0.0;warrior_state.class_resource=warrior_state.get_class_resource_max();warrior_player.use_action("special")
	_expect(String(warrior_player.sprite.animation).begins_with("special_"),"Warrior Cleave did not select its dedicated animation",failures)
	warrior_player.combo_runtime.setup("warrior")
	var warrior_basic:=GameBalance.get_slasher_ability_tuning("warrior","basic");_expect(float(warrior_basic.get("deflect_reach",999))==82.0 and float(warrior_basic.get("deflect_arc_degrees",999))==56.0,"Warrior Slash deflection area was not reduced",failures)
	var deflect_source:=SlasherEnemy.new();deflect_source.configure(1,false,"feral_wolf");root.add_child(deflect_source);deflect_source.set_physics_process(false)
	var near_projectile:=SlasherHostileProjectile.new().setup(deflect_source,warrior_player,warrior_player.global_position+Vector2(70,0),Vector2.LEFT,1,{});root.add_child(near_projectile);near_projectile.set_physics_process(false)
	var far_projectile:=SlasherHostileProjectile.new().setup(deflect_source,warrior_player,warrior_player.global_position+Vector2(100,0),Vector2.LEFT,1,{});root.add_child(far_projectile);far_projectile.set_physics_process(false);await process_frame
	_expect(warrior_player._deflect_projectiles(float(warrior_basic.deflect_reach),float(warrior_basic.deflect_arc_degrees))==1 and near_projectile.deflected_by==warrior_player and far_projectile.deflected_by==null,"Slash deflection did not reject a projectile outside the tighter area",failures)
	warrior_player.use_action("basic");warrior_player.cooldowns.movement=0.0;warrior_state.class_resource=warrior_state.get_class_resource_max();warrior_player.use_action("movement")
	while warrior_player.warrior_dash_active:warrior_player._process_warrior_dash(0.05)
	var crosscut_target:=SlasherEnemy.new();crosscut_target.configure(1,false,"feral_wolf");root.add_child(crosscut_target);crosscut_target.set_physics_process(false);crosscut_target.global_position=warrior_player.global_position+Vector2(60,0);await process_frame
	var health_before:=crosscut_target.health;warrior_player.cooldowns.basic=0.0;var crosscut:Dictionary=warrior_player.use_action("basic")
	_expect(String(crosscut.get("combo_id",""))=="crosscut" and bool(crosscut.get("critical",false)) and crosscut_target.health<health_before,"Crosscut did not resolve as a damaging critical Slash",failures)
	warrior_player.combo_runtime.setup("warrior");warrior_player.warrior_slash_chain=0;warrior_player.warrior_slash_chain_time=0.0
	var slash_cooldowns:Array[float]=[]
	for index in 3:
		warrior_player.cooldowns.basic=0.0;warrior_player.use_action("basic");slash_cooldowns.append(float(warrior_player.cooldowns.basic))
	_expect(is_equal_approx(slash_cooldowns[0],0.18) and is_equal_approx(slash_cooldowns[1],0.18) and is_equal_approx(slash_cooldowns[2],0.90),"Slash did not use the two-fast-hits then long-recovery cadence",failures)
	warrior_state.class_resource=0;warrior_player.cooldowns.movement=0.0;var free_charge:Dictionary=warrior_player.use_action("movement")
	_expect(String(free_charge.get("combo_id",""))=="flowing_assault" and int(free_charge.get("resource_spent",-1))==0 and warrior_state.class_resource==0 and is_zero_approx(float(warrior_player.cooldowns.basic)),"Flowing Assault did not waive Charge cost and reset Slash cooldown",failures)
	warrior_player.queue_free();crosscut_target.queue_free();deflect_source.queue_free();near_projectile.queue_free();far_projectile.queue_free();await process_frame

	if failures.is_empty():print("SLASHER_COMBO_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
