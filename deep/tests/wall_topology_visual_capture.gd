extends SceneTree

const FOREST:=preload("res://scenes/slasher/SlasherForest.tscn")
const CRYPT:=preload("res://scenes/slasher/SlasherCrypt.tscn")

func _initialize()->void:call_deferred("_run")
func _run()->void:
	for record in [{"id":"forest","scene":FOREST,"floor":3},{"id":"crypt","scene":CRYPT,"floor":4}]:
		var state:=RunState.new();state.set_class("warrior");state.start_new_run(GearData.create("wall_capture","Wall Capture",3,true,1,"","","warrior"),String(record.id),"slasher");state.current_floor=int(record.floor)
		var dungeon=record.scene.instantiate();dungeon._ensure_designer_controls();dungeon.setup(null,state);root.add_child(dungeon);await process_frame;await process_frame
		if dungeon.relic_modal!=null and dungeon.relic_modal.visible:dungeon.relic_modal.finish()
		await create_timer(0.1).timeout
		if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png("res://build/wall_topology_%s_1280x720.png"%String(record.id))
		dungeon.free();await process_frame
	print("WALL_TOPOLOGY_VISUAL_CAPTURE_PASSED");quit(0)
