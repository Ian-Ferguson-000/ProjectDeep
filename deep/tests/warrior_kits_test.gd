extends SceneTree
const GROUND := preload("res://scenes/slasher/TestingGround.tscn")
const KITS := preload("res://scripts/slasher/slasher_warrior_kits.gd")
const CATALOG := preload("res://scripts/slasher/slasher_warrior_combos.gd")
var failures: Array[String]=[]
var ground: Node
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:failures.append(message)
func enemies() -> Array[SlasherEnemy]:
	var result: Array[SlasherEnemy]=[]
	for child in ground.combat_root.get_children():
		if child is SlasherEnemy:result.append(child)
	return result
func equip(id: String, mode: String="cluster", level: int=1, branch: int=0, variant: int=0, foundation: int=0, combos: bool=true) -> void:
	ground.class_picker.select(0);ground._refresh_class()
	for index in ground.gear_options.size():
		if (id=="standard" and index==0) or ground.gear_options[index].id==id:ground.gear_picker.select(index);break
	ground.level_picker.value=level;ground.foundation_picker.select(foundation);ground.branch_picker.select(branch)
	for picker in ground.upgrade_pickers:picker.select(variant)
	ground.dummy_mode=mode;ground.apply_build();ground.set_editor_visible(false)
	await physics_frame;await process_frame
	ground.player.set_physics_process(false)
	ground.player.warrior_combo_effects.set_physics_process(false)
	if is_instance_valid(ground.player.warrior_kit):ground.player.warrior_kit.set_physics_process(false)
	if not combos:ground.player.combo_runtime.recipes.clear();ground.player.combo_runtime.states.clear()
func clear_cooldowns() -> void:ground.player.cooldowns={"basic":0.0,"special":0.0,"defensive":0.0,"movement":0.0}
func run() -> void:
	ground=GROUND.instantiate();root.add_child(ground);await process_frame
	for id in KITS.DATA:
		for level in [1,20]:
			for branch in ([0] if level==1 else [1,2,3]):
				for variant in ([0] if level==1 else [1,2]):
					for foundation in ([0] if level==1 else [1,2,3]):
						await equip(id,"single",level,branch,variant,foundation,false)
						var player: SlasherPlayer=ground.player
						var standard: Dictionary=ground.state.get_effective_slasher_ability_tuning("basic")
						var tuned: Dictionary=player._ability_tuning("basic")
						check(float(player._scaled_damage(tuned))/float(tuned.cooldown)>=float(player._scaled_damage(standard))/float(standard.cooldown),"Warrior kit lost baseline pace: "+id)
						check(player._ability_tuning("special").cooldown<=1.2 and player._ability_tuning("movement").cooldown<=0.9,"Slow Warrior alternate: "+id)
	print("95 Warrior progression configurations verified")
	await test_native_kits()
	await test_combos()
	await test_support()
	await test_edge_cases()
	ground.queue_free();await process_frame;await process_frame
	for message in failures:push_error(message)
	print("Warrior kits: PASS" if failures.is_empty() else "Warrior kits: FAIL")
	quit(0 if failures.is_empty() else 1)
func test_native_kits() -> void:
	await equip("headsmans_greatsword","single",1,0,0,0,false)
	var player: SlasherPlayer=ground.player;var kit: Node=player.warrior_kit;var enemy := enemies()[0]
	player.global_position=Vector2(-100,0);player.aim_direction=Vector2.RIGHT;enemy.global_position=Vector2(40,0)
	var before: int=enemy.total_damage;ground.state.class_resource=0
	player.use_action("basic");check(enemy.total_damage==before and kit.pending.size()==1,"Hew must telegraph before landing")
	kit._physics_process(0.13);check(enemy.total_damage>before and ground.state.class_resource==2,"Hew must hit hard and award Momentum once")
	player.invulnerable=0;player.use_action("defensive");var health: int=player.health
	player.receive_damage(10,Vector2.ZERO,enemy)
	check(player.health==health-4 and kit.ready_hew>0,"Frontal Shoulder must mitigate and ready instant Hew")
	clear_cooldowns();player.use_action("basic");check(kit.pending.back().left==0,"Counter Hew must eliminate its windup")
	kit._physics_process(0.01);clear_cooldowns();player.use_action("defensive");enemy.global_position=player.global_position-Vector2(70,0);health=player.health
	player.receive_damage(3,Vector2.ZERO,enemy);check(player.health==health-3,"Rear attacks must bypass Shoulder")
	await equip("borderkeepers_spear","single",1,0,0,0,false)
	player=ground.player;kit=player.warrior_kit;enemy=enemies()[0];player.aim_direction=Vector2.RIGHT
	enemy.global_position=player.global_position+Vector2(220,0);ground.state.class_resource=0
	before=enemy.total_damage;player.use_action("basic")
	check(ground.state.class_resource==2 and enemy.total_damage-before==int(round(player._scaled_damage(kit.tuning("basic"))*1.35)),"Spear tip must reward spacing")
	clear_cooldowns();enemy.global_position=player.global_position+Vector2(80,0);ground.state.class_resource=0;player.use_action("basic")
	check(ground.state.class_resource==0,"Close spear hits must not grant tip Momentum")
	ground.state.class_resource=3;clear_cooldowns();player.use_action("special");before=enemy.total_damage
	kit._physics_process(0.1);check(enemy.total_damage==before,"Lane must respect arming delay")
	kit._physics_process(0.03);check(enemy.total_damage>before and kit.lane.is_empty(),"Stationary enemies must trigger a single-use spear lane")
	await equip("duelists_paired_sabres","single",1,0,0,0,false)
	player=ground.player;kit=player.warrior_kit;enemy=enemies()[0];player.aim_direction=Vector2.RIGHT
	enemy.global_position=player.global_position+Vector2(85,0);ground.state.class_resource=0
	player.use_action("basic");check(ground.state.class_resource==0 and not kit.strokes.is_empty(),"First sabre stroke must store the pair")
	clear_cooldowns();player.use_action("basic");check(ground.state.class_resource==2 and kit.strokes.is_empty(),"Second connected same-target stroke must grant Momentum")
	player.invulnerable=0;clear_cooldowns();player.use_action("defensive");health=player.health;player.receive_damage(3,Vector2.ZERO,enemy)
	check(player.health==health and kit.exposure.id==enemy.get_instance_id(),"Bind Steel must parry and expose a frontal melee attacker")
	await equip("chain_of_the_siege_breaker","single",1,0,0,0,false)
	player=ground.player;kit=player.warrior_kit;enemy=enemies()[0];player.aim_direction=Vector2.RIGHT
	enemy.global_position=player.global_position+Vector2(240,0);player.use_action("basic")
	check(kit.tether_target()==enemy,"Weight must tether first line target")
	ground.state.class_resource=3;before=enemy.total_damage;player.use_action("special")
	check(enemy.total_damage>before and enemy.global_position.distance_to(player.global_position)<100 and kit.tether.is_empty(),"Chain must pull ordinary prey into a slam and sever the tether")
	await equip("chain_of_the_siege_breaker","boss",1,0,0,0,false)
	player=ground.player;kit=player.warrior_kit;enemy=enemies()[0];player.aim_direction=Vector2.RIGHT;enemy.global_position=player.global_position+Vector2(240,0)
	player.use_action("basic");var position := enemy.global_position;before=enemy.total_damage;player.use_action("special")
	check(enemy.global_position==position and enemy.total_damage>before,"Boss chain slam must deal damage without displacement")
	clear_cooldowns();player.use_action("basic")
	var wall := StaticBody2D.new();var shape := CollisionShape2D.new();var box := RectangleShape2D.new();box.size=Vector2(10,150);shape.shape=box;wall.add_child(shape);ground.combat_root.add_child(wall);wall.global_position=player.global_position+Vector2(100,0)
	await physics_frame;check(kit.tether_target()==null,"A wall must sever the tether")
	ground.combat_root.remove_child(wall);wall.queue_free()
func test_combos() -> void:
	var seen: Dictionary={};var completed := 0
	ground.combo_panel.visible=true
	for id in CATALOG.ENTRIES:
		await equip(id)
		check(ground.player.combo_runtime.recipes.size()==6,"Warrior build must offer six combos: "+id)
		var recipes: Array=ground.player.combo_runtime.recipes.duplicate(true)
		for recipe in recipes:
			await equip(id)
			var player: SlasherPlayer=ground.player;var enemy := enemies()[0]
			player.aim_direction=Vector2.RIGHT
			check(not seen.has(recipe.id),"Duplicate Warrior combo ID");seen[recipe.id]=true
			var result: Dictionary={}
			ground.state.class_resource=3
			for token in recipe.steps:
				clear_cooldowns();player.invulnerable=0
				player.combo_runtime.tick(0.65)
				enemy.global_position=player.global_position+Vector2(65 if id=="standard" else 215 if id=="borderkeepers_spear" else 90,0)
				if token=="confirm:parry_success":player.use_action("defensive");player.receive_damage(1,Vector2.ZERO,enemy);continue
				if token=="confirm:movement_hit":
					player.use_action("movement")
					while player.warrior_dash_active:player._process_warrior_dash(0.05)
					continue
				var slot: String=String(token).trim_prefix("action:");result=player.use_action(slot)
				if id=="standard" and slot=="movement":
					while player.warrior_dash_active:player._process_warrior_dash(0.05)
				elif is_instance_valid(player.warrior_kit) and slot=="basic":player.warrior_kit._physics_process(0.13)
				check(result.get("started",false),"Failed combo action: "+String(recipe.id))
			check(result.get("combo_id","")==recipe.id,"Warrior combo failed to trigger: "+String(recipe.id))
			if recipe.effect.get("warrior_combo",false):
				check(player.warrior_combo_effects.last_result.get("id","")==recipe.id and player.warrior_combo_effects.last_result.size()>1,"Warrior combo needs a mechanical payoff: "+String(recipe.id))
				player.warrior_combo_effects._physics_process(0.3)
			check(ground.combo_panel.counts.get(recipe.id,0)>0,"Practice panel missed Warrior success: "+String(recipe.id))
			completed+=1
	check(completed==36,"Expected all 36 Warrior combos")
	print("36 Warrior combos exercised through actual actions")
func test_support() -> void:
	await equip("banner_of_the_vanguard","single",1,0,0,0,false)
	var player: SlasherPlayer=ground.player;var kit: Node=player.warrior_kit;var enemy := enemies()[0]
	player.aim_direction=Vector2.RIGHT;player.use_action("special");kit.banner.center=player.global_position
	var state := RunState.new();state.set_class("healer");state.start_new_run(GearData.create("support_test","Support test",1,false,0,"","","healer"),"forest")
	var ally := SlasherPlayer.new();ally.setup(state);ground.combat_root.add_child(ally);ally.global_position=player.global_position+Vector2(60,0);ally.set_physics_process(false)
	var benched := SlasherPlayer.new();benched.setup(state);ground.combat_root.add_child(benched);benched.global_position=player.global_position+Vector2(30,0);benched.process_mode=Node.PROCESS_MODE_DISABLED
	kit._physics_process(0.01)
	check(is_equal_approx(player.kit_buffs.speed_multiplier(),1.15) and is_equal_approx(ally.kit_buffs.speed_multiplier(),1.15) and benched.kit_buffs.speed_multiplier()==1,"Banner speed must affect self/deployed ally, never benched actors")
	player.use_action("defensive")
	check(player.kit_buffs.ward_amount()>0 and ally.kit_buffs.ward_amount()>0 and benched.kit_buffs.ward_amount()==0,"Banner must share ward with nearest eligible deployed ally")
	var lifetime: float=kit.banner.left;player.use_action("movement")
	check(kit.banner.center==player.global_position and kit.banner.left==lifetime,"Advancing banner must move it without renewal")
	for hit_index in 10:kit.slash(kit.banner.center,Vector2.RIGHT,1000,360,kit.attack_for("basic","Rally Cut",true))
	check(kit.banner.added<=2,"Rally Cuts must have a finite extension budget")
	var before: int=ally.health;var barrier: int=ally.kit_buffs.ward_amount();ally.receive_damage(barrier,Vector2.ZERO)
	check(ally.health==before and ally.kit_buffs.ward_amount()==0,"Shared ward must absorb actual damage without healing")
	kit._physics_process(8);check(kit.banner.is_empty() and ally.kit_buffs.speed_multiplier()==1,"Banner expiry must remove ally benefits")
	ground.reset_arena();check(ground.player.combo_runtime.feedback().is_empty() and ground.player.kit_buffs.ward_amount()==0,"Reset must clear Warrior state")

func get_recipe(id: String) -> Dictionary:
	for value in ground.player.combo_runtime.recipes:
		if value.id==id:return value
	return {}
func test_edge_cases() -> void:
	await equip("chain_of_the_siege_breaker","single",1,0,0,0,false)
	var player: SlasherPlayer=ground.player;var kit: Node=player.warrior_kit;var enemy := enemies()[0]
	player.aim_direction=Vector2.RIGHT;ground.state.class_resource=0;player.use_action("defensive")
	var shots: Array[SlasherHostileProjectile]=[]
	for index in 4:
		var shot := SlasherHostileProjectile.new().setup(enemy,player,player.global_position+Vector2(55+index*8,0),Vector2.LEFT,2,{})
		ground.combat_root.add_child(shot);shot.set_physics_process(false);shots.append(shot)
	var unblockable := SlasherHostileProjectile.new().setup(enemy,player,player.global_position+Vector2(35,0),Vector2.LEFT,2,{})
	unblockable.set_meta("unblockable",true);ground.combat_root.add_child(unblockable);unblockable.set_physics_process(false)
	kit._physics_process(0.01);var blocked := 0
	for shot in shots:blocked+=int(shot.impacted)
	check(blocked==3 and not unblockable.impacted and ground.state.class_resource==1,"Chain Guard must cap interception at three, bypass unblockable shots, and reward once")
	player.invulnerable=0;enemy.global_position=player.global_position+Vector2(80,0);player.receive_damage(2,Vector2.ZERO,enemy)
	check(ground.state.class_resource==1,"Interception and next-hit guard must share their resource budget")
	await equip("duelists_paired_sabres","single",1,0,0,0,false)
	player=ground.player;kit=player.warrior_kit;enemy=enemies()[0]
	player.aim_direction=Vector2.RIGHT;enemy.global_position=player.global_position+Vector2(95,0);player.invulnerable=0
	player.use_action("defensive");var previous_health: int=player.health
	var arrow := SlasherHostileProjectile.new().setup(enemy,player,player.global_position+Vector2(1,0),Vector2.LEFT,4,{})
	ground.combat_root.add_child(arrow);arrow.set_physics_process(false);arrow._physics_process(0.001)
	check(player.health==previous_health-2 and kit.exposure.is_empty() and not player._receiving_projectile,"Close-range projectile hits must remain ranged for Bind Steel and restore damage context")
	await equip("borderkeepers_spear","cluster",1,0,0,0,false)
	player=ground.player;kit=player.warrior_kit;player.aim_direction=Vector2.RIGHT
	enemies()[0].global_position=player.global_position+Vector2(90,0);enemies()[1].global_position=player.global_position+Vector2(220,0)
	ground.state.class_resource=0;player.use_action("basic")
	check(ground.state.class_resource==2,"A close hit must not consume the tip reward before a later tip hit")
	await equip("headsmans_greatsword","single")
	player=ground.player;kit=player.warrior_kit;enemy=enemies()[0];player.aim_direction=Vector2.RIGHT
	enemy.global_position=player.global_position+Vector2(160,0);player.use_action("special")
	var original: int=kit.pending.back().attack.damage;player.warrior_combo_effects.execute(get_recipe("red_sentence"))
	check(kit.pending.back().degrees==80 and kit.pending.back().attack.damage==int(round(original*1.6)),"Red Sentence must widen and amplify the real pending strike")
	var before: int=enemy.total_damage;kit._physics_process(0.23)
	check(enemy.total_damage-before==int(round(original*1.6)),"Amplified Sentence must land actual damage")
	var saved: Dictionary=player.combo_runtime.snapshot();clear_cooldowns();ground.state.class_resource=0;player.use_action("special")
	check(player.combo_runtime.snapshot()==saved,"Warrior failed resource casts must preserve recipe progress")
	await equip("duelists_paired_sabres","single")
	player=ground.player;kit=player.warrior_kit
	player.warrior_combo_effects.execute(get_recipe("perfect_measure"));player.use_action("special")
	var combined := 0
	for entry in kit.pending:combined+=int(entry.attack.damage)
	check(abs(combined-int(round(player._scaled_damage(kit.tuning("special"))*1.5)))<=1 and kit.special_bonus.is_empty(),"Perfect Measure must amplify exactly one actual Crossing Blades")
	kit.pending.clear();clear_cooldowns();ground.state.class_resource=3;player.use_action("special");combined=0
	for entry in kit.pending:combined+=int(entry.attack.damage)
	check(abs(combined-player._scaled_damage(kit.tuning("special")))<=1,"Consumed empowerment must not carry into another special")
	await equip("borderkeepers_spear","single")
	player=ground.player;kit=player.warrior_kit;player.aim_direction=Vector2.RIGHT;player.use_action("special")
	player.warrior_combo_effects.execute(get_recipe("long_watch"))
	check(kit.lane.reach==420 and kit.lane.left==4 and kit.lane.width==50,"Long Watch must modify the native lane")
	player.warrior_combo_effects.execute(get_recipe("second_rank"));check(not player.warrior_combo_effects.combo_lane.is_empty(),"Second Rank must create an independent real lane")
	player.warrior_combo_effects._physics_process(3.1);check(player.warrior_combo_effects.combo_lane.is_empty(),"Second Rank lane must expire")
	await equip("banner_of_the_vanguard","single")
	player=ground.player;kit=player.warrior_kit;player.use_action("special")
	var lifetime: float=kit.banner.left
	player.warrior_combo_effects.execute(get_recipe("unbroken_standard"));var extended: float=kit.banner.left
	player.warrior_combo_effects.execute(get_recipe("unbroken_standard"))
	check(extended==lifetime+2 and kit.banner.left==extended,"Unbroken Standard may extend a planting only once")
	await equip("chain_of_the_siege_breaker","cluster")
	player=ground.player;kit=player.warrior_kit;player.aim_direction=Vector2.RIGHT
	enemies()[0].global_position=player.global_position+Vector2(100,0);enemies()[1].global_position=player.global_position+Vector2(180,40);enemies()[2].global_position=player.global_position+Vector2(190,-40)
	player.use_action("basic");var a: int=enemies()[1].total_damage;var b: int=enemies()[2].total_damage
	player.warrior_combo_effects.execute(get_recipe("linked_weights"))
	check(player.warrior_combo_effects.last_result.links==2 and enemies()[1].total_damage>a and enemies()[2].total_damage>b,"Linked Weights must hit two distinct nearby targets")
	var resource: int=ground.state.class_resource
	check(resource==3,"Secondary chain hits must not alter Stamina")
