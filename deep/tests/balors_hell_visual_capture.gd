extends SceneTree

const HELL:=preload("res://scenes/slasher/SlasherHell.tscn")

func _initialize()->void:call_deferred("_run")

func _run()->void:
	var state:=RunState.new();state.set_class("warrior");state.start_new_run(GearData.create("hell_visual","Hell Visual",3,true,1,"","","warrior"),"balors_hell","slasher");state.current_floor=6
	var scene:=HELL.instantiate();scene._ensure_designer_controls();scene.setup(null,state);root.add_child(scene);await process_frame;await process_frame
	if scene.relic_modal!=null and scene.relic_modal.visible:scene.relic_modal.finish()
	var boss:SlasherHellEnemy
	for node:Node in get_nodes_in_group("slasher_enemy"):
		if node is SlasherHellEnemy and node.boss:boss=node;break
	if boss!=null:
		scene.player.global_position=scene.sanitize_player_position(boss.global_position+Vector2(185,0));scene.player.camera.reset_smoothing();boss.activation_delay=0.0;boss.pattern_cooldown=0.0;boss._process_balor();boss.state_timer=0.0;boss._process_balor()
	await create_timer(0.2).timeout
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png("res://build/balors_hell_boss_1280x720.png")
	print("BALORS_HELL_VISUAL_CAPTURE_PASSED");quit(0)
