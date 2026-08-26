extends SceneTree

const CLASS_IDS := ["warrior", "mage", "healer", "tank", "phantom", "summoner"]
const FOREST := preload("res://scenes/forest/Forest.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for class_id in CLASS_IDS:
		var state := RunState.new()
		state.set_class(class_id)
		var gear := GearData.create("test_" + class_id, "Test Gear", 2, class_id == "tank", 1, "", "", class_id, "none")
		state.start_new_run(gear)
		var scene := FOREST.instantiate()
		scene.setup(null, state)
		root.add_child(scene)
		await process_frame
		if scene.run_state.selected_class_id != class_id:
			push_error("Forest failed to initialize %s" % class_id)
			quit(1)
			return
		scene.free()
	print("Six-class forest scene smoke test passed.")
	quit(0)
