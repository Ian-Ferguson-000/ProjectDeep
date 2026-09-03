extends SceneTree

const SCENE:=preload("res://scenes/slasher/SlasherFarmstead.tscn")

func _initialize()->void:call_deferred("_run")

func _run()->void:
	_ensure_slasher_actions()
	var failures:Array[String]=[];var definition:=GameBalance.get_dungeon("ashen_farmstead")
	_expect(Array(definition.get("supported_modes",[])).has("slasher"),"Farmstead must advertise Slasher mode",failures)
	_expect(String(definition.get("slasher_runtime",""))=="ashen_farmstead","Farmstead Slasher runtime id is missing",failures)
	_expect(not bool(Dictionary(definition.get("slasher",{})).get("endless_available",true)),"Farmstead Slasher must not enable Endless",failures)
	for enemy_id in ["ash_rat","possessed_scarecrow","ember_crow","blighted_farmhand","harvest_wretch"]:
		_expect(ResourceLoader.exists("res://assets/enemies/%s/generated_source.png"%enemy_id),"%s animation source is missing"%enemy_id,failures)
		var frames:=SlasherSpriteLibrary.enemy_frames(enemy_id)
		for direction in ["down","left","right","up"]:
			for action in ["idle","run","attack"]:_expect(frames.has_animation("%s_%s"%[action,direction]),"%s lacks %s_%s"%[enemy_id,action,direction],failures)
	var state:=RunState.new();state.set_class("mage");var gear:=GearData.create("test_focus","Test Focus",2,false,0,"","","mage","none");state.start_new_run(gear,"ashen_farmstead",RunState.PLAY_MODE_SLASHER)
	_expect(int(state.field_run.get("room_count",0))>=10 and int(state.field_run.get("room_count",0))<=12,"Slasher Field graph must contain 10-12 rooms",failures)
	var scene:=SCENE.instantiate();scene.setup(null,state);root.add_child(scene);await process_frame;await process_frame
	_expect(scene.room_id==0,"Slasher Farmstead did not open the graph start room",failures)
	_expect(scene.get_node_or_null("HUD/FieldMinimap")!=null,"Field graph minimap was not created",failures)
	_expect(is_instance_valid(scene.player) and scene.player.class_id=="mage","Shared six-class player kit was not initialized",failures)
	_expect(scene.objective_label.text.contains("EXPLORED") and scene.objective_label.text.contains("CLEARED"),"HUD lacks Field room progress",failures)
	scene.queue_free();await process_frame
	if failures.is_empty():print("FARMSTEAD_SLASHER_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)

func _ensure_slasher_actions()->void:
	for action in ["character_menu","cycle_party","extract_expedition","slasher_up","slasher_down","slasher_left","slasher_right","slasher_aim_left","slasher_aim_right","slasher_aim_up","slasher_aim_down","slasher_controller_basic","slasher_mobility","slasher_special","slasher_defend","slasher_potion","slasher_abandon","slasher_consumable_1","slasher_consumable_2","slasher_consumable_3","slasher_consumable_4"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
