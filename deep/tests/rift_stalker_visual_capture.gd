extends SceneTree

const HELL:=preload("res://scenes/slasher/SlasherHell.tscn")
const HELL_ENEMY:=preload("res://scripts/slasher/slasher_hell_enemy.gd")

func _initialize()->void:call_deferred("_run")

func _run()->void:
	var state:=RunState.new();state.set_class("warrior");state.start_new_run(GearData.create("rift_capture","Rift Capture",3,true,1,"","","warrior"),"balors_hell","slasher");state.current_floor=2
	var scene=HELL.instantiate();scene._ensure_designer_controls();scene.setup(null,state);root.add_child(scene);await process_frame;await process_frame
	if scene.relic_modal!=null and scene.relic_modal.visible:scene.relic_modal.finish()
	var stalker:SlasherHellEnemy=HELL_ENEMY.new();stalker.configure(2,false,"rift_stalker",false,"rift_stalker");scene.actor_layer.add_child(stalker);stalker.global_position=scene.player.global_position+Vector2(-170,0);stalker.target=scene.player;stalker.pathfinder=scene.pathfinder;stalker.activation_delay=0.0;stalker.special_cooldown=0.0;stalker._process_stalker();scene.player.camera.reset_smoothing()
	await create_timer(0.35).timeout
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png("res://build/rift_stalker_telegraph_1280x720.png")
	print("RIFT_STALKER_VISUAL_CAPTURE_PASSED");quit(0)
