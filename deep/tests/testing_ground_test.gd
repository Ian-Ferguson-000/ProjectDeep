extends SceneTree

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
	_expect(ground.editor.visible and ground.combat_root.process_mode==Node.PROCESS_MODE_DISABLED,"Build editor must pause combat")
	_expect(ground.loot_checks.size()==64,"All 52 items and 12 Hearth relics must be available")
	var kit_count := 0
	for index in 6:
		ground.class_picker.select(index);ground._refresh_class()
		for gear_index in ground.gear_options.size():
			ground.gear_picker.select(gear_index);ground.apply_build()
			_expect(ground.state.selected_gear==ground.gear_options[gear_index],"Selected kit was not applied")
			_expect(not ground.state.campaign.expedition.active,"Training must not start a campaign expedition")
			kit_count += 1
	_expect(kit_count==34,"Expected 24 current weapons and five alternatives each for Mage and Warrior")
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
