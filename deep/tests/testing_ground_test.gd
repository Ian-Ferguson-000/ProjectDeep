extends SceneTree

## Dash, special and block are switched off in progression.json; this checks them anyway.
func _init() -> void: GameBalance.set_actions_override(GameBalance.ALL_ACTIONS)

const GROUND := preload("res://scenes/slasher/TestingGround.tscn")
const PYRO := preload("res://scripts/slasher/slasher_pyromancy.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _check_pacing(ground: Node) -> void:
	var standard: Dictionary=ground.state.get_effective_slasher_ability_tuning("basic")
	var fire: Dictionary=ground.player._ability_tuning("basic")
	var standard_rate: float=float(ground.player._scaled_damage(standard))/float(standard.cooldown)
	var fire_rate: float=float(ground.player._scaled_damage(fire))/float(fire.cooldown)
	_expect(fire_rate>=standard_rate,"Lance must match the current standard Mage's direct damage rate before Burn")
	_expect(float(fire.cooldown)<=float(standard.cooldown),"Lance must keep up with standard Mage casting pace")
	_expect(float(ground.player._ability_tuning("special").cooldown)<=1.2,"Conflagration must cycle quickly")
	_expect(float(ground.player._ability_tuning("movement").cooldown)<=0.8,"Cinder Trail must support fast repositioning")
	print("Level %d normalized direct damage/sec: standard %.1f, Pyromancer %.1f (before Burn or ground)"%[ground.state.get_level(),standard_rate,fire_rate])

func _run() -> void:
	var ground := GROUND.instantiate()
	root.add_child(ground)
	await process_frame
	_expect(ground.class_picker.item_count==6,"All six classes must be available")
	_expect(not ground.editor.visible and ground.combat_root.process_mode==Node.PROCESS_MODE_INHERIT,"Armory must open directly into playable combat")
	_expect(ground.state.selected_class_id=="warrior" and ground.state.get_level()==1 and ground.state.selected_gear.id==CampaignState.BASIC_GEAR.warrior,"Armory must default to a standard level-one Fighter")
	_expect(ground.FLOOR.size.x>=1800.0 and ground.FLOOR.size.y>=900.0,"Expanded armory floor is still using the old compact dimensions")
	_expect(ground.class_podiums.size()==6,"Walk-in armory must provide one podium for every class")
	_expect(ground.item_displays.size()==ActiveItems.items().size(),"Walk-in armory must mount every active item along its walls")
	_expect(ground.find_children("*","Button",true,false).all(func(button):return button.focus_mode==Control.FOCUS_NONE),"Testing HUD buttons can retain keyboard focus and turn Space into an accidental reset")
	var tattoo_display:Node2D=ground.item_displays.filter(func(node):return node.item_id=="vibranium_tattoo")[0]
	ground.player.global_position=tattoo_display.global_position;ground._process_armory_interactions()
	_expect(ActiveItems.held(ground.state)=="vibranium_tattoo" and ActiveItems.is_ready(ground.state),"Walking into a compatible item did not equip it fully charged")
	var mage_podium:Node2D=ground.class_podiums.filter(func(node):return node.class_id=="mage")[0]
	ground.interaction_lock=null;ground.player.global_position=mage_podium.global_position;ground._process_armory_interactions()
	_expect(ground.state.selected_class_id=="mage" and ground.state.get_level()==1 and ground.state.selected_gear.id==CampaignState.BASIC_GEAR.mage,"Walking into the Mage podium did not apply its standard build")
	_expect(ActiveItems.held(ground.state)=="vibranium_tattoo","Class podium discarded a compatible neutral item")
	var orb_display:Node2D=ground.item_displays.filter(func(node):return node.item_id=="michaels_orb")[0]
	ground.interaction_lock=null;ground.player.global_position=orb_display.global_position;ground._process_armory_interactions()
	_expect(ActiveItems.held(ground.state)=="michaels_orb","Walking into a class item did not swap the active slot")
	_expect(ground.use_active_item() and ground.player.get_children().any(func(node):return node.get_meta("active_item_runtime_id","")=="michaels_orb"),"Michael's Orb crashed or failed through the walk-in armory activation path")
	ground.interaction_lock=null;var warrior_podium:Node2D=ground.class_podiums.filter(func(node):return node.class_id=="warrior")[0];ground.player.global_position=warrior_podium.global_position;ground._process_armory_interactions()
	_expect(ground.state.selected_class_id=="warrior" and ActiveItems.held(ground.state).is_empty(),"Class swap retained an incompatible active item")
	for id in preload("res://scripts/slasher/slasher_fighter_arsenal.gd").WEAPON_IDS:
		var display:Node2D=ground.item_displays.filter(func(node):return node.item_id==id)[0]
		ground.interaction_lock=null;ground.player.global_position=display.global_position
		ground._process_armory_interactions()
		_expect(ActiveItems.held(ground.state)==id and ActiveItems.is_ready(ground.state),id+": walk-in display must equip a charged fighter item")
		_expect(ground.use_active_item() and not ActiveItems.is_ready(ground.state),id+": wall pickup must activate and spend through the armory input path")
	ground._equip_active_item("whirlwind");_expect(ground.use_active_item() and not ActiveItems.is_ready(ground.state),"Testing Ground did not activate and spend a wall item")
	ground._process(ground.TRAINING_RECHARGE_SECONDS+0.01);_expect(ActiveItems.is_ready(ground.state),"Testing Ground did not rapidly recharge the active item")
	var expected_loot:=GameBalance.get_items().size()
	for id in HearthCatalog.data().items:
		if HearthCatalog.item(id).get("slot","")=="relic" and not GameBalance.get_items().has(id):expected_loot+=1
	_expect(ground.loot_checks.size()==expected_loot,"All combat items and Hearth relics must be available")
	var kit_count := 0
	for index in 6:
		ground.class_picker.select(index);ground._refresh_class()
		for gear_index in ground.gear_options.size():
			ground.gear_picker.select(gear_index);ground.apply_build()
			_expect(ground.state.selected_gear==ground.gear_options[gear_index],"Selected kit was not applied")
			_expect(not ground.state.campaign.expedition.active,"Training must not start a campaign expedition")
			kit_count += 1
	_expect(kit_count==44,"Expected 34 current weapons and five alternatives each for Mage and Warrior")
	ground.class_picker.select(1);ground._refresh_class();ground.gear_picker.select(4)
	ground.apply_build();_check_pacing(ground)
	ground.loot_checks["flameheart_talisman"].button_pressed=true
	ground.level_picker.value=20;ground.foundation_picker.select(1);ground.branch_picker.select(1)
	for picker in ground.upgrade_pickers:picker.select(1)
	ground.apply_build();await process_frame
	_check_pacing(ground)
	_expect(ground.state.get_level()==20 and ground.state.get_inventory_items().size()==1,"Level and selected loot did not apply")
	ground.set_editor_visible(false)
	await physics_frame
	await process_frame
	ground.player.set_physics_process(false)
	var player: SlasherPlayer=ground.player
	_expect(player.uses_pyromancy(),"Tome must select the new fire kit")
	_expect(player._action_name("special")=="Conflagration","Tome must expose its own action names")
	var resource_before: int=ground.state.class_resource
	player.aim_direction=Vector2.RIGHT
	var move_result: Dictionary=player.use_action("movement")
	_expect(bool(move_result.started) and ground.state.class_resource==resource_before,"Cinder Trail must move without spending Focus")
	_expect(not player.pyromancy.trails.is_empty(),"Cinder Trail must leave an unlit trail")
	player.use_action("basic")
	player.pyromancy._physics_process(0.016)
	_expect(player.pyromancy.patches.is_empty(),"Firing away from the trail must not ignite it")
	for child in ground.combat_root.get_children():
		if child is SlasherProjectile:ground.combat_root.remove_child(child);child.queue_free()
	player.aim_direction=Vector2.LEFT;player.cooldowns.basic=0.0
	player.use_action("basic")
	player.pyromancy._physics_process(0.016)
	_expect(player.pyromancy.patches.size()>=8 and player.pyromancy.trails.is_empty(),"Ignition must cover the full trail")
	ground.set_editor_visible(true)
	var paused_lifetime: float=player.pyromancy.patches[0].left
	for frame in 3:await physics_frame
	_expect(is_equal_approx(player.pyromancy.patches[0].left,paused_lifetime),"Build editing must pause kit effect timers")
	ground.set_editor_visible(false);await physics_frame;await process_frame
	var enemy: SlasherEnemy=ground.combat_root.get_child(1)
	var burn_attack := {"pyro_burn":true,"pyro_cast":100}
	ground.state.class_resource=0
	player.pyromancy.on_direct_hit(enemy,burn_attack);player.pyromancy.on_direct_hit(enemy,burn_attack)
	_expect(ground.state.class_resource==1,"A piercing Ember cast must award only one Focus")
	_expect(player.pyromancy.burns.size()==1,"Repeated Burn must refresh, not stack")
	var damage_before: int=enemy.total_damage
	player.pyromancy._physics_process(1.0)
	_expect(enemy.total_damage>damage_before and ground.state.class_resource==1,"Burn must deal damage without generating Focus")
	_expect(int(ground.damage_by_type.get("fire",0))>0 and enemy.last_damage_type=="fire","Burn must be attributed to fire in training feedback")
	player.resource_suppression_time=1.0
	player.pyromancy.on_direct_hit(enemy,{"pyro_burn":true,"pyro_cast":101})
	_expect(ground.state.class_resource==1,"Lance must respect resource suppression")
	player.resource_suppression_time=0.0
	ground.state.class_resource=3;player.cooldowns.special=0.0
	var special: Dictionary=player.use_action("special")
	_expect(bool(special.started) and ground.state.class_resource==2,"Conflagration must spend one Mana")
	_expect(player.pyromancy.detonations.size()==1,"Conflagration must be delayed")
	player.pyromancy.detonations[0].center=enemy.global_position
	player.pyromancy._physics_process(0.8)
	_expect(player.pyromancy.detonations.is_empty() and not player.pyromancy.burns.has(enemy.get_instance_id()),"Blast must resolve and consume owned Burn")
	player.cooldowns.defensive=0.0;player.invulnerable=0.0;player.use_action("defensive")
	player.global_position=enemy.global_position+Vector2(-50,0)
	await physics_frame
	await process_frame
	var before: int=player.health
	player.receive_damage(10,Vector2.ZERO,enemy)
	_expect(player.health==before-4 and not player.pyromancy.burns.is_empty(),"Furnace Mantle must mitigate 60% and burn nearby enemies")
	ground.reset_arena();await process_frame
	_expect(ground.player.pyromancy.burns.is_empty() and ground.player.pyromancy.patches.is_empty(),"Reset must clear the old kit's fields and burns")
	_expect(ground.damage_by_type.is_empty() and ground.target_popups.is_empty(),"Reset must clear damage breakdowns and popups")
	var normal: SlasherEnemy=ground.combat_root.get_child(1)
	_expect(normal.receive_hit(1000000)==1000000 and not normal.dead and not normal.is_queued_for_deletion(),"Normal targets must survive even extreme build damage")
	ground.state.class_resource=0
	_expect(not ground.player.use_action("special").started and ground.player.pyromancy.detonations.is_empty(),"Insufficient Mana must prevent Conflagration")
	ground.dummy_mode="boss";ground.reset_arena();await process_frame
	var boss: SlasherEnemy=ground.combat_root.get_child(1)
	var dealt := boss.receive_attack({"damage":10000,"damage_type":"fire"},ground.player)
	_expect(dealt<=50 and not boss.dead,"Boss target must retain hit caps and survive")
	_expect(int(ground.damage_by_type.get("fire",0))==dealt,"Type breakdown must report actual boss-capped damage once")
	var popup: Node=ground.target_popups[boss.get_instance_id()][0].get_ref()
	_expect(popup.amount==dealt and popup.damage_type=="fire","Boss damage popup must show actual amount and type")
	var shielded := boss.receive_attack({"damage":40,"damage_type":"arcane"},ground.player)
	_expect(shielded==10 and int(ground.damage_by_type.get("arcane",0))==10,"Popups and type totals must respect the boss's temporary shield")
	boss.receive_hit(4)
	_expect(int(ground.damage_by_type.get("physical",0))==1,"Direct hits must not inherit a previous attack's type")
	for hit in 12:boss.receive_attack({"damage":4,"damage_type":"fire","damage_source":"Burn"},ground.player)
	_expect(ground.target_popups[boss.get_instance_id()].size()<=6,"Rapid hit popups must remain bounded")
	ground.dummy_mode="live";ground.reset_arena();await process_frame
	_expect(ground.combat_root.get_child_count()==4,"Live scenario must spawn three enemies")
	var live: SlasherEnemy=ground.combat_root.get_child(1)
	live.receive_attack({"damage":7,"damage_type":"arcane"},ground.player)
	_expect(int(ground.damage_by_type.get("arcane",0))==7,"Live enemies must also report typed damage")
	var live_root:Node2D=ground.combat_root;Input.action_press("slasher_special");ground._process(0.016);Input.action_release("slasher_special")
	_expect(ground.combat_root==live_root and ground.combat_root.get_children().filter(func(node):return node is SlasherEnemy and not node.dead).size()==3,"Space rebuilt the live arena instead of activating the held item")
	live.receive_attack({"damage":1000,"damage_type":"physical"},ground.player);await process_frame
	_expect(ground.live_respawns.size()==1 and ground.combat_root.get_children().filter(func(node):return node is SlasherEnemy and not node.dead).size()==2,"Defeated live enemy did not enter the respawn queue")
	ground._process_live_respawns(2.9);_expect(ground.combat_root.get_children().filter(func(node):return node is SlasherEnemy and not node.dead).size()==2,"Live enemy respawned before three seconds")
	ground._process_live_respawns(0.11);_expect(ground.live_respawns.is_empty() and ground.combat_root.get_children().filter(func(node):return node is SlasherEnemy and not node.dead).size()==3,"Live enemy did not respawn naturally after three seconds")
	var jade_victim:SlasherEnemy=ground.combat_root.get_children().filter(func(node):return node is SlasherEnemy and not node.dead)[0];jade_victim.global_position=ground.player.global_position+Vector2(160,0);jade_victim.health=1;var jade_victim_id:=jade_victim.get_instance_id();ground.player.aim_direction=Vector2.RIGHT;ground._equip_active_item("jade_serpent_staff")
	_expect(ground.use_active_item(),"Jade Serpent Staff did not activate against a live training enemy")
	var jade_runtime:Node=ground.player.get_children().filter(func(node):return node.get_meta("active_item_runtime_id","")=="jade_serpent_staff")[0]
	jade_runtime.set_physics_process(false)
	for step in 60:jade_runtime._step(1.0/60.0)
	_expect(jade_victim.dead,"Traveling Jade dart did not kill the live training enemy")
	await process_frame;await process_frame
	jade_runtime._process_poison(0.1);jade_runtime._process_missiles(0.1)
	_expect(not jade_runtime.poison.has(jade_victim_id) and not jade_runtime.marked.has(jade_victim_id),"Jade Serpent Staff retained its freed live-enemy victim")
	ground.queue_free();await process_frame;await process_frame
	var main_script := load("res://scripts/main.gd")
	var main: Node=main_script.new()
	root.add_child(main);await process_frame
	main.campaign=CampaignState.new()
	main.campaign.apply_post_tutorial_state("victory")
	for candidate in main.campaign.get_candidates():main.campaign.recruit_candidate(candidate.id)
	main.run_state.attach_campaign(main.campaign)
	main.show_tavern();await process_frame
	var management: HearthManagement=main.current_scene.management
	management.open(main.campaign,main.run_state,"Company")
	_expect(not management.testing_ground_button.visible,"Testing entrance should belong to the Armory page")
	management.show_section("Armory");await process_frame
	_expect(management.testing_ground_button.is_visible_in_tree() and not management.testing_ground_button.disabled,"Current Hearth armory must show an enabled testing-ground entrance")
	var original_state: RunState=main.run_state
	var original_campaign: String=JSON.stringify(main.campaign.to_dict())
	management.testing_ground_button.pressed.emit();await process_frame;await process_frame
	var isolated: Node=main.current_scene
	isolated.state.gold=9999;isolated.loot_checks["starfallen_sigil"].button_pressed=true;isolated.apply_build()
	_expect(main.run_state==original_state and isolated.state!=original_state,"Training must keep the original RunState isolated")
	_expect(JSON.stringify(main.campaign.to_dict())==original_campaign,"Training must not mutate campaign state")
	main.leave_testing_ground();await process_frame;await process_frame
	_expect(main.run_state==original_state and main.current_scene.management.visible and main.current_scene.management.section=="Armory","Return must reopen the current Hearth armory")
	_expect(main.run_state.gold!=9999 and not main.campaign.expedition.active,"Testing gold or expedition state leaked into campaign")
	main.queue_free();await process_frame;await process_frame
	if failures.is_empty():print("Testing ground and Pyromancer: PASS")
	else:
		for message in failures:push_error(message)
	quit(0 if failures.is_empty() else 1)
