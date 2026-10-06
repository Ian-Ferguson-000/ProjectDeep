extends SceneTree

const GROUND := preload("res://scenes/slasher/TestingGround.tscn")
const KITS := preload("res://scripts/slasher/slasher_mage_kits.gd")
const CATALOG := preload("res://scripts/slasher/slasher_mage_combos.gd")
var ground: Node
var failures: Array[String]=[]
var completed := 0

func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:failures.append(message)

func equip(id: String) -> void:
	ground.class_picker.select(1);ground._refresh_class()
	for index in ground.gear_options.size():
		if (id=="standard" and index==0) or ground.gear_options[index].id==id:ground.gear_picker.select(index);break
	ground.dummy_mode="cluster";ground.apply_build();ground.set_editor_visible(false)
	await process_frame;await physics_frame
	ground.player.set_physics_process(false)
	if is_instance_valid(ground.player.mage_kit):ground.player.mage_kit.set_physics_process(false)
	ground.player.mage_combo_effects.set_physics_process(false)

func projectile_hit(enemy: SlasherEnemy) -> void:
	for child in ground.combat_root.get_children():
		if child is SlasherProjectile:
			child.set_physics_process(false);child._damage_impact(enemy)
			ground.combat_root.remove_child(child);child.queue_free()

func run() -> void:
	ground=GROUND.instantiate();root.add_child(ground);await process_frame
	check(not ground.combo_panel.visible,"Combo panel must be optional by default")
	ground.toggle_combo_panel();check(ground.combo_panel.visible and ground.combo_button.button_pressed,"Practice toggle must enable panel")
	var seen: Dictionary={}
	for kit_id in CATALOG.ENTRIES:
		await equip(kit_id)
		check(ground.player.combo_runtime.recipes.size()==6,"Every Mage kit must expose six combos: "+kit_id)
		var recipes: Array=ground.player.combo_runtime.recipes.duplicate(true)
		for recipe in recipes:
			await equip(kit_id)
			var player: SlasherPlayer=ground.player
			var effects: Node=player.mage_combo_effects
			var enemy: SlasherEnemy=ground.combat_root.get_child(1)
			player.global_position=Vector2(-180,30);player.aim_direction=Vector2.RIGHT
			enemy.global_position=player.global_position+Vector2(65 if kit_id=="standard" else 160,0)
			var before: int=enemy.total_damage
			check(not seen.has(recipe.id),"Combo design IDs must be unique")
			seen[recipe.id]=true
			for index in player.combo_runtime.recipes.size():
				if player.combo_runtime.recipes[index].id==recipe.id:ground.combo_panel.picker.select(index)
			var result: Dictionary={}
			for token in recipe.steps:
				player.cooldowns={"basic":0.0,"special":0.0,"defensive":0.0,"movement":0.0}
				ground.state.class_resource=ground.state.get_class_resource_max()
				# Keep native fields and hit conditions alive; a normal player can execute
				# every action inside the 2.5-second window with actual cooldowns.
				if token=="confirm:repel_hit":result=player.use_action("defensive")
				else:
					var slot: String=String(token).trim_prefix("action:")
					enemy.global_position=player.global_position+Vector2(65 if kit_id=="standard" else 160,0)
					player.aim_direction=Vector2.RIGHT
					result=player.use_action(slot)
					if slot=="basic":
						if kit_id=="grimoire_of_gravity":player.mage_kit._physics_process(0.11)
						projectile_hit(enemy)
				check(result.get("started",false),"Recipe action failed: "+String(recipe.id))
			check(result.get("combo_id","")==recipe.id,"Combo did not complete through player actions: "+String(recipe.id))
			if recipe.effect.get("mage_combo",false):
				check(effects.last_result.get("id","")==recipe.id and effects.last_result.size()>1,"Combo has no executed mechanical payload: "+String(recipe.id))
				# Exercise actual scheduled payloads and active field physics.
				effects._physics_process(0.2)
				for child in ground.combat_root.get_children():
					if child is SlasherProjectile and child.attack.get("mage_secondary",false):
						check(not child.attack.has("mage_resource") and not child.attack.has("echo_damage_multiplier"),"Combo projectile must not recursively grant Mana/echo")
			check(ground.combo_panel.counts.get(recipe.id,0)>0,"Panel did not record success: "+String(recipe.id))
			ground.combo_panel.refresh();check("successes" in ground.combo_panel.progress.text,"Practice panel lacks completion count")
			completed+=1
	print("Exercised %d Mage combos through real ability actions"%completed)
	check(completed==36,"Expected 36 distinct playable combos")
	await equip("winterglass_codex")
	var player: SlasherPlayer=ground.player
	player.use_action("basic");var saved: Dictionary=player.combo_runtime.snapshot()
	player.cooldowns.basic=1;player.use_action("basic")
	check(player.combo_runtime.snapshot()==saved,"Cooldown rejection must preserve combo progress")
	ground.state.class_resource=0;player.cooldowns.special=0;player.use_action("special")
	check(player.combo_runtime.snapshot()==saved,"Resource rejection must preserve combo progress")
	player.combo_runtime.tick(2.6)
	check(player.combo_runtime.feedback().is_empty(),"Expired progress must reset")
	player.use_action("movement");var countdown: float=player.combo_runtime.feedback().remaining
	ground.set_editor_visible(true)
	player.set_physics_process(true)
	for frame in 3:await physics_frame
	check(is_equal_approx(player.combo_runtime.feedback().remaining,countdown),"Build editing must pause combo timers")
	ground.reset_arena();check(ground.player.combo_runtime.feedback().is_empty() and ground.player.mage_combo_effects.fields.is_empty(),"Reset must clear combo progress and effects")
	ground.set_editor_visible(false)
	ground.toggle_combo_panel();check(not ground.combo_panel.visible,"Practice panel must be dismissible")
	await test_payloads()
	ground.queue_free();await process_frame;await process_frame
	for message in failures:push_error(message)
	print("Mage combo practice: PASS" if failures.is_empty() else "Mage combo practice: FAIL")
	quit(0 if failures.is_empty() else 1)

func recipe(id: String) -> Dictionary:
	for value in ground.player.combo_runtime.recipes:
		if value.id==id:return value
	return {}

func test_payloads() -> void:
	await equip("stormbringers_grimoire")
	var player: SlasherPlayer=ground.player;var kit: Node=player.mage_kit;var effects: Node=player.mage_combo_effects
	var enemy: SlasherEnemy=ground.combat_root.get_child(1)
	kit.perform("special",{"started":true});kit.rods[0].center=Vector2(0,0)
	kit.perform("special",{"started":true});kit.rods[1].center=Vector2(300,0)
	enemy.global_position=Vector2(150,0);var before: int=enemy.total_damage
	effects.execute(recipe("closed_circuit"))
	check(enemy.total_damage-before==effects.damage(20),"Closed Circuit must damage a target inside the rod link exactly once")
	var resource: int=ground.state.class_resource
	effects.execute(recipe("overcharge"));kit.rods[0].center=enemy.global_position;kit.rods[1].center=Vector2(-400,0)
	before=enemy.total_damage;kit._physics_process(0.01)
	check(enemy.total_damage-before==int(kit.rods[0].attack.damage)*2 and not kit.rods[0].has("pulse_bonus"),"Overcharge must double only the next rod pulse")
	check(ground.state.class_resource==resource,"Combo rod damage must not create Mana")
	await equip("winterglass_codex")
	player=ground.player;kit=player.mage_kit;effects=player.mage_combo_effects
	effects.departure=player.global_position;effects.execute(recipe("permafrost"))
	check(kit.frozen_fields.back().kind=="disk" and kit.frozen_fields.back().left==5 and kit.movement_speed_multiplier()==1.4,"Permafrost must produce a real five-second skateable pool")
	effects.execute(recipe("diamond_guard"));var ward: int=effects.barrier;var health: int=player.health
	ground.state.class_resource=0;player.invulnerable=0;player.defense_window=0
	player.receive_damage(ward,Vector2.ZERO)
	check(player.health==health and effects.barrier==0,"Combo barrier must absorb actual incoming damage")
	var shards := 0
	for child in ground.combat_root.get_children():
		if child is SlasherProjectile and child.attack.get("damage_source","")=="Ward shards":shards+=1
	check(shards==8 and ground.state.class_resource==0,"Diamond Guard must retaliate once without Mana")
	effects.execute(recipe("diamond_guard"));effects._physics_process(3.1)
	check(effects.barrier==0 and effects.barrier_shards==0,"Unused combo barriers must expire without a free retaliation")
	await equip("grimoire_of_gravity")
	player=ground.player;effects=player.mage_combo_effects;enemy=ground.combat_root.get_child(1)
	var shot_script := preload("res://scripts/slasher/slasher_hostile_projectile.gd")
	effects.execute(recipe("satellite_guard"))
	var shots: Array[SlasherHostileProjectile]=[]
	for index in 4:
		var shot := shot_script.new().setup(enemy,player,player.global_position+Vector2(40+index*10,0),Vector2.LEFT,3,{})
		ground.combat_root.add_child(shot);shot.set_physics_process(false);shots.append(shot)
	effects._physics_process(0.01);var stopped := 0
	for shot in shots:stopped+=int(shot.impacted)
	check(stopped==3 and effects.last_result.get("projectiles",0)==3,"Satellite Guard must intercept exactly three shots and return three stones")
	for shot in shots:if not shot.impacted:shot._finish()
	enemy.global_position=player.global_position+Vector2(100,0)
	kit=player.mage_kit;kit.well={"center":player.global_position}
	effects.execute(recipe("event_horizon"));var start := enemy.global_position;before=enemy.total_damage
	effects._physics_process(0.1)
	check(enemy.global_position.distance_to(player.global_position)<start.distance_to(player.global_position) and enemy.total_damage>before,"Event Horizon must pull and damage a normal foe")
	enemy.boss=true;start=enemy.global_position;effects._physics_process(0.4)
	check(enemy.global_position==start,"Combo pulling fields must not displace bosses")
	effects._physics_process(2.1);check(effects.fields.is_empty(),"Combo fields must expire without leaving effects behind")
	await equip("mirrorbound_manuscript")
	player=ground.player;effects=player.mage_combo_effects
	effects.previous_mirror={"center":Vector2(0,0)};effects.previous_recording={"direction":Vector2.RIGHT,"attack":{"damage":101}}
	effects.execute(recipe("palimpsest"));var copies := 0
	for child in ground.combat_root.get_children():
		if child is SlasherProjectile and child.attack.get("damage_source","")=="Palimpsest":
			copies+=1;check(child.attack.damage==51 and child.global_position==Vector2.ZERO,"Palimpsest must copy half the resolved recording from the mirror")
	check(copies==2,"Palimpsest must emit two recorded copies")
