extends SceneTree

const CRYPT:=preload("res://scenes/slasher/SlasherCrypt.tscn")

func _initialize()->void:call_deferred("_run")
func _run()->void:
	for floor_number:int in [1,4,7]:
		var state:=RunState.new();state.set_class("warrior");state.start_new_run(GearData.create("crypt_visual","Crypt Visual",3,true,1,"","","warrior"),"crypt","slasher");state.current_floor=floor_number
		var scene:=CRYPT.instantiate();scene._ensure_designer_controls();scene.setup(null,state);root.add_child(scene);await process_frame;await process_frame
		if scene.relic_modal!=null and scene.relic_modal.visible:scene.relic_modal.finish()
		if floor_number==7:
			var boss:SlasherCryptEnemy
			for node in get_nodes_in_group("slasher_enemy"):
				if node is SlasherCryptEnemy and node.boss:boss=node;break
			if boss!=null:scene.player.global_position=scene.sanitize_player_position(boss.global_position+Vector2(170,0));scene.player.camera.reset_smoothing();boss.activation_delay=0.0;boss.pattern_cooldown=0.0;boss._process_crypt_lord()
		await create_timer(0.15).timeout
		if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png("res://build/crypt_slasher_floor_%d_1280x720.png"%floor_number)
		scene.free();await process_frame
	print("CRYPT_SLASHER_VISUAL_CAPTURE_PASSED");quit(0)
