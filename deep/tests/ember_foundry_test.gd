extends SceneTree

const SCENE:=preload("res://scenes/slasher/SlasherFoundry.tscn")
func _initialize()->void:call_deferred("_run")
func _run()->void:
	var failures:Array[String]=[];var definition:=GameBalance.get_dungeon("ember_foundry")
	_expect(String(definition.get("runtime",""))=="ember_foundry" and int(definition.get("floors",0))==6,"Foundry runtime routing is incomplete",failures)
	var state:=RunState.new();state.start_new_run(null,"ember_foundry");var scene:=SCENE.instantiate();scene.setup(null,state);root.add_child(scene);await process_frame
	_expect(scene.layout.size()>0 and scene.enemies_remaining>0,"Foundry failed to generate its encounter",failures)
	_expect(not scene.flooded_zones.is_empty() and not scene.machinery_zones.is_empty(),"Foundry hazards are missing",failures);scene.free()
	if failures.is_empty():print("EMBER_FOUNDRY_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)
func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
