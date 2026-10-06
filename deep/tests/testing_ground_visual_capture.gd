extends SceneTree

const GROUND := preload("res://scenes/slasher/TestingGround.tscn")

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size=Vector2i(1280,720)
	var ground := GROUND.instantiate();root.add_child(ground)
	await process_frame;await process_frame
	ground.class_picker.select(1);ground._refresh_class();ground.gear_picker.select(4);ground._update_details();ground.apply_build()
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/testing_ground_editor_1280x720.png")
	root.size=Vector2i(960,540)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/testing_ground_editor_960x540.png")
	# Inspect the actual item tab as well as the build controls at the smaller size.
	ground.loot_checks.values()[0].button_pressed=true
	var tab_container: TabContainer=ground.loot_checks.values()[0].get_parent().get_parent().get_parent().get_parent()
	tab_container.current_tab=1
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/testing_ground_items_960x540.png")
	tab_container.current_tab=0
	root.size=Vector2i(1280,720)
	ground.set_editor_visible(false)
	await physics_frame;await process_frame
	ground.player.set_physics_process(false)
	ground.player.aim_direction=Vector2.RIGHT
	ground.player.use_action("movement")
	ground.player.aim_direction=Vector2.LEFT
	ground.player.use_action("basic")
	await physics_frame;await physics_frame
	ground.player.global_position=Vector2(-130,50)
	ground.player.use_action("defensive")
	var target: SlasherEnemy=ground.combat_root.get_child(1)
	target.receive_attack({"damage":48,"damage_type":"fire","damage_source":"Lance"},ground.player)
	ground.player.pyromancy.apply_burn(target)
	ground.combat_root.get_child(2).receive_attack({"damage":34,"damage_type":"arcane"},ground.player)
	ground.combat_root.get_child(3).receive_attack({"damage":21,"damage_type":"physical"},ground.player)
	ground.player.pyromancy.detonations.append({"center":Vector2(170,-20),"radius":120.0,"left":ground.PYROMANCY.BLAST_DELAY,"attack":{"damage":80,"damage_type":"fire","damage_source":"Blast"}})
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/testing_ground_floor_1280x720.png")
	for frame in 20:await physics_frame
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/testing_ground_explosion_1280x720.png")
	root.size=Vector2i(960,540)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/testing_ground_fire_960x540.png")
	root.size=Vector2i(1280,720)
	ground.queue_free();await process_frame
	var campaign := CampaignState.new()
	campaign.apply_post_tutorial_state("victory")
	for candidate in campaign.get_candidates():campaign.recruit_candidate(candidate.id)
	var state := RunState.new();state.attach_campaign(campaign)
	var armory := HearthManagement.new();root.add_child(armory)
	armory.open(campaign,state,"Armory")
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/testing_ground_armory_1280x720.png")
	root.size=Vector2i(960,540)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/testing_ground_armory_960x540.png")
	armory.queue_free();await process_frame
	quit()
