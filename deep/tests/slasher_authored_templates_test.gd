extends SceneTree

const TEMPLATE_PATHS:Array[String]=[
	"res://scenes/slasher/templates/ForestBranchingTemplate.tscn",
	"res://scenes/slasher/templates/MineLoopTemplate.tscn",
	"res://scenes/slasher/templates/FoundryArenaTemplate.tscn",
	"res://scenes/slasher/templates/CryptGauntletTemplate.tscn",
]

func _initialize()->void:
	call_deferred("_run")

func _run()->void:
	var failures:Array[String]=[]
	for path:String in TEMPLATE_PATHS:
		var packed:=load(path) as PackedScene
		_expect(packed!=null,"Could not load %s"%path,failures)
		if packed==null:continue
		var map:=packed.instantiate();map.designer_playtest=false;root.add_child(map)
		var layout:Dictionary=map._layout_from_authored_nodes()
		_expect(not layout.is_empty(),"%s produced no authored layout"%path,failures)
		if layout.is_empty():map.queue_free();continue
		_expect(SlasherForestGenerator.layout_is_connected(layout),"%s is disconnected"%path,failures)
		_expect(layout.cells.has(layout.start),"%s player spawn is outside the floor"%path,failures)
		_expect(layout.cells.has(layout.exit),"%s exit is outside the floor"%path,failures)
		_expect(not layout.enemy_spawns.is_empty(),"%s has no enemy encounter"%path,failures)
		for spawn_value:Variant in layout.enemy_spawns:
			var spawn:Dictionary=Dictionary(spawn_value)
			_expect(layout.cells.has(Vector2i(spawn.position)),"%s has an enemy outside the floor"%path,failures)
		for prop_value:Variant in layout.solid_props:
			var prop:Dictionary=Dictionary(prop_value)
			_expect(layout.cells.has(Vector2i(prop.cell)),"%s has a prop outside the floor"%path,failures)
		var play_state:=RunState.new();play_state.set_class("warrior")
		play_state.start_new_run(GearData.create("authored_test","Authored Test Gear",3,false,0,"","","warrior"),map.designer_dungeon_id,"slasher")
		play_state.current_floor=map.designer_floor;map.setup(null,play_state)
		_expect(map.player!=null,"%s did not spawn a playable character"%path,failures)
		_expect(map.enemies_remaining==layout.enemy_spawns.size(),"%s did not spawn its authored encounter"%path,failures)
		_expect(Dictionary(map.layout.get("cells",{})).size()==Dictionary(layout.cells).size(),"%s changed geometry while entering play"%path,failures)
		map.queue_free()
	if failures.is_empty():print("SLASHER_AUTHORED_TEMPLATES_TESTS_PASSED");quit(0)
	else:
		for failure:String in failures:push_error(failure)
		quit(1)

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
