extends SceneTree

const MineScene:=preload("res://scenes/slasher/SlasherMine.tscn")

func _initialize()->void:call_deferred("_run")

func _run()->void:
	var failures:Array[String]=[];var definition:=GameBalance.get_dungeon("sunken_mine")
	_expect(String(definition.get("runtime",""))=="sunken_mine" and int(definition.get("floors",0))==6,"Mine campaign runtime is incomplete",failures)
	_expect(String(definition.get("merchant_id",""))=="mine","Mine merchant assignment is missing",failures)
	var state:=RunState.new();state.start_new_run(null,"sunken_mine")
	var mine:=MineScene.instantiate();mine.setup(null,state);root.add_child(mine);await process_frame
	_expect(mine.layout.size()>0 and mine.enemies_remaining>0,"Mine did not generate a playable Slasher floor",failures)
	_expect(not mine.flooded_zones.is_empty() and not mine.machinery_zones.is_empty(),"Mine hazards are missing",failures)
	mine.free()
	if failures.is_empty():print("SUNKEN_MINE_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
