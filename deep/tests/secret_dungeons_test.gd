extends SceneTree

const SCENES={"moonlit_grove":preload("res://scenes/slasher/SlasherGrove.tscn"),"abyssal_archive":preload("res://scenes/slasher/SlasherArchive.tscn")}
func _initialize()->void:call_deferred("_run")
func _run()->void:
	var failures:Array[String]=[]
	for dungeon_id in SCENES:
		var definition:=GameBalance.get_dungeon(dungeon_id);_expect(String(definition.get("runtime",""))==dungeon_id and String(definition.get("merchant_id",""))=="","%s runtime profile is incomplete"%dungeon_id,failures)
		var state:=RunState.new();state.start_new_run(null,dungeon_id);var scene:Node2D=SCENES[dungeon_id].instantiate();scene.setup(null,state);root.add_child(scene);await process_frame
		_expect(scene.layout.size()>0 and scene.enemies_remaining>0,"%s did not generate an encounter"%dungeon_id,failures)
		_expect(not scene.has_dungeon_merchant,"%s should not place a dungeon merchant"%dungeon_id,failures);scene.free()
	if failures.is_empty():print("SECRET_DUNGEON_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)
func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
