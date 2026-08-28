extends SceneTree

const TAVERN := preload("res://scenes/tavern/Tavern.tscn")
const CLASS_IDS := ["warrior","mage","healer","tank","phantom","summoner"]

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	for viewport_size in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
		root.size = viewport_size
		var state := RunState.new(); state.set_class("warrior")
		var gear := GearData.create("test","Test Blade",3,false,0,"","Reliable gear.","warrior","none")
		var summary := {"outcome":"victory","headline":"Forest cleared","dungeon":"forest","depth":5,"gold":42,"changes":["+8 Mara Vell Favor"]}
		var gear_list: Array[GearData] = [gear]
		var tavern := TAVERN.instantiate(); tavern.setup(null,state,gear_list,"Welcome home.",summary); root.add_child(tavern)
		await process_frame
		_expect(tavern.backdrop != null and tavern.top_hud != null, "missing backdrop or HUD at %s"%viewport_size,failures)
		_expect(tavern.results_backdrop.visible and tavern.results_text.text.contains("Forest cleared"),"structured results missing at %s"%viewport_size,failures)
		_expect(tavern._grid_center(Vector2i(9,8)).x > 0 and tavern._grid_center(Vector2i(9,8)).x < viewport_size.x,"grid failed responsive centering at %s"%viewport_size,failures)
		var floor_path: Array[Vector2i] = tavern._find_navigation_path(tavern.player_pos,Vector2i(12,7))
		_expect(not floor_path.is_empty() and floor_path[floor_path.size()-1] == Vector2i(12,7),"click navigation could not route across Tavern floor",failures)
		var gate_station: Dictionary = tavern._station_at(Vector2i(13,1)); var gate_approach: Vector2i = tavern._best_station_approach(Vector2i(13,1))
		_expect(not gate_station.is_empty() and gate_approach != Vector2i(-1,-1) and tavern._distance(gate_approach,Vector2i(13,1))==1,"click navigation could not approach expedition gate",failures)
		tavern._open_dungeon_selector()
		var dungeon_button_count := 0
		for entry in tavern.expedition_list.get_children():
			if entry is Button: dungeon_button_count += 1
		_expect(dungeon_button_count==3,"dungeon selector did not list registered dungeons",failures)
		_expect(tavern.expedition_list.find_child("ForestDungeonButton",false,false) != null,"Forest selector entry missing",failures)
		_expect(tavern.expedition_list.find_child("AshenFarmsteadDungeonButton",false,false) != null,"Farmstead selector entry missing",failures)
		_expect(tavern.expedition_list.find_child("CryptDungeonButton",false,false) != null,"Crypt selector entry missing",failures)
		tavern._close_modal(tavern.expedition_backdrop)
		tavern._close_modal(tavern.results_backdrop)
		tavern._open_armory()
		_expect(tavern.armory_backdrop.visible and tavern.armory_list.get_child_count()==1,"armory modal failed",failures)
		tavern._close_modal(tavern.armory_backdrop)
		tavern._open_expedition("forest")
		_expect(tavern.expedition_backdrop.visible and not tavern.expedition_launch.disabled,"Forest confirmation failed",failures)
		tavern._close_modal(tavern.expedition_backdrop)
		tavern._open_expedition("crypt")
		_expect(not tavern.expedition_launch.disabled and tavern.expedition_detail.text.contains("Testing unlock active"),"testing unlock did not enable Crypt",failures)
		tavern.free()
	for class_id in CLASS_IDS:
		var class_state := RunState.new(); class_state.set_class(class_id)
		var class_gear := GearData.create("test_"+class_id,"Test "+class_id.capitalize(),2,false,0,"","Class gear.",class_id,"none")
		var class_gear_list: Array[GearData] = [class_gear]
		var class_tavern := TAVERN.instantiate(); class_tavern.setup(null,class_state,class_gear_list,""); root.add_child(class_tavern); await process_frame
		class_tavern._open_armory()
		_expect(class_tavern.armory_detail.text.contains(class_state.selected_class_name),"armory omitted %s class identity"%class_id,failures)
		class_tavern.free()
	if failures.is_empty(): print("Player-ready Tavern redesign validation passed."); quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(value: bool,failure: String,failures: Array[String]) -> void:
	if not value: failures.append(failure)
