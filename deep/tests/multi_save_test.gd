extends SceneTree

const START:=preload("res://scenes/start/StartScreen.tscn")

class MockController extends Node:
	var continued_slot:=0
	var new_slot:=0
	func get_save_slot_summaries()->Array[Dictionary]:
		return [
			{"slot":1,"exists":false,"recoverable":false},
			{"slot":2,"exists":true,"recoverable":true,"tutorial_phase":"complete","roster_count":6,"completed_dungeons":3,"banked_gold":42,"last_saved_unix":1700000000},
			{"slot":3,"exists":true,"recoverable":false,"error":"Unreadable"},
		]
	func continue_from_slot(slot:int)->void:continued_slot=slot
	func new_game_in_slot(slot:int)->void:new_slot=slot

func _initialize()->void:call_deferred("_run")

func _run()->void:
	var failures:Array[String]=[]
	_expect(CampaignState.SAVE_SLOT_COUNT==3,"Campaign must expose exactly three save slots",failures)
	var paths:Array[String]=[]
	for slot in range(1,4):paths.append(CampaignState.save_path(slot))
	_expect(paths.duplicate().size()==3 and paths[0]!=paths[1] and paths[1]!=paths[2],"Save slots do not use independent paths",failures)
	var campaign:=CampaignState.new();campaign.save_slot=3;campaign.tutorial_phase=CampaignState.TUTORIAL_COMPLETE;campaign.ensure_roster();var restored:=CampaignState.new();restored._load_dict(campaign.to_dict())
	_expect(restored.save_slot==3 and restored.living_roster().size()==6,"Save-slot identity did not round trip",failures)
	var migrated:=CampaignState._migrate_dict({"version":2,"tutorial_phase":"complete"})
	_expect(int(migrated.get("version",0))==CampaignState.SAVE_VERSION and int(migrated.get("save_slot",0))==1,"Version-2 single save did not migrate to slot 1",failures)
	var controller:=MockController.new();root.add_child(controller);var screen:=START.instantiate();screen.setup(controller);root.add_child(screen);await process_frame
	var continue_button:Button=screen.find_child("ContinueButton",true,false);var new_button:Button=screen.find_child("NewGameButton",true,false)
	_expect(continue_button!=null and not continue_button.disabled,"Continue must enable when a recoverable slot exists",failures)
	_expect(new_button!=null and not new_button.disabled,"New Game must always be available",failures)
	screen._open_slot_picker(false);await process_frame
	var picker:=screen.get_node("SlotPickerOverlay");var slot_buttons:Array[Button]=[]
	for node in picker.find_children("*","Button",true,false):
		if (node as Button).text.begins_with("SLOT"):slot_buttons.append(node)
	_expect(slot_buttons.size()==3,"Continue picker must show exactly three slots",failures)
	_expect(slot_buttons[0].disabled and not slot_buttons[1].disabled and slot_buttons[2].disabled,"Continue picker enabled empty or unreadable slots",failures)
	_expect(slot_buttons[1].text.contains("6 recruits") and slot_buttons[1].text.contains("42 gold"),"Slot summary omits campaign metadata",failures)
	picker.queue_free();await process_frame;screen._open_slot_picker(true);await process_frame
	picker=screen.get_node("SlotPickerOverlay");slot_buttons.clear()
	for node in picker.find_children("*","Button",true,false):
		if (node as Button).text.begins_with("SLOT"):slot_buttons.append(node)
	_expect(slot_buttons.size()==3 and slot_buttons.all(func(button:Button)->bool:return not button.disabled),"New Game picker must allow all three slots",failures)
	screen._select_slot(2,true,true,picker);await process_frame
	_expect(picker.find_children("*","ConfirmationDialog",true,false).size()==1,"Occupied New Game slot must require overwrite confirmation",failures)
	screen._commit_slot(1,true,picker);await process_frame
	_expect(controller.new_slot==1,"Empty New Game slot did not route the selected slot",failures)
	controller.queue_free();screen.queue_free();await process_frame
	if failures.is_empty():print("MULTI_SAVE_TESTS_PASSED");quit(0);return
	for failure in failures:push_error(failure)
	quit(1)

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
