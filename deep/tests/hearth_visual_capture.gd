extends SceneTree

func _initialize() -> void: call_deferred("capture")

func capture() -> void:
	var state := RunState.new()
	var c := state.campaign
	c.apply_post_tutorial_state("victory")
	for candidate in c.get_candidates(): c.recruit_candidate(candidate.id)
	c.establishment_tier=3
	c.tavern_upgrades.roster_services=3
	c.banked_gold=1800
	c.reputation=65
	c.relic_essence=70
	c.record_dungeon_clear("forest")
	c.last_presented_wave_id=c.candidate_wave_id
	c.first_normal_launch_completed=true
	HearthArmory.grant(c,"light_armor_1")
	HearthArmory.grant(c,"hearth_quickstep_charm")
	var tavern:=preload("res://scenes/tavern/Tavern.tscn").instantiate()
	var options: Array[GearData]=[HearthCatalog.gear("sword_shield")]
	tavern.setup(null,state,options,"")
	root.add_child(tavern)
	await process_frame
	await process_frame
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png("res://build/hearth_expanded.png")
	for page in HearthManagement.SECTIONS:
		tavern.management.open(c,state,page)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/hearth_%s.png" % page.to_lower())
	tavern.queue_free()
	await process_frame
	print("HEARTH_VISUAL_CAPTURE_PASSED")
	quit()
