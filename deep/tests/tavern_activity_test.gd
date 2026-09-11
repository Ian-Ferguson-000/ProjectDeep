extends SceneTree

const TAVERN:=preload("res://scenes/tavern/Tavern.tscn")

class ControllerStub:
	extends Node
	var starts:=0
	var party:Array[String]=[]
	func start_dungeon(_dungeon_id:String,_gear:GearData,_mode:String,ids:Array[String])->void:starts+=1;party=ids.duplicate()

func _initialize()->void:call_deferred("_run")

func _run()->void:
	var failures:Array[String]=[];var state:=RunState.new();state.campaign.apply_post_tutorial_state("victory");state.campaign.last_presented_wave_id=state.campaign.candidate_wave_id;state.campaign.tavern_phase=CampaignState.TAVERN_OPEN;state.set_class("warrior")
	for candidate in state.campaign.get_candidates():state.campaign.recruit_candidate(candidate.id)
	state.merchant_progress["forest"]={"recruited":true,"available_favor":0,"lifetime_favor":0,"highest_depth":1}
	var controller:=ControllerStub.new();root.add_child(controller);var gear:=GearData.create("test","Test Blade",3,false,0,"","","warrior","none");var gears:Array[GearData]=[gear]
	var tavern:=TAVERN.instantiate();tavern.setup(controller,state,gears,"");root.add_child(tavern);await process_frame;await process_frame
	_expect(tavern.find_child("Entrance",true,false)!=null and tavern.find_child("Stairway",true,false)!=null,"activity anchors missing",failures)
	_expect(tavern.world.get_node("Props").get_child_count()==3,"three social tables missing",failures)
	_expect(tavern.activity_controller.actors.has("tavern") and tavern.activity_controller.actors.has("forest"),"named merchants were not populated from campaign state",failures)
	_expect(tavern.activity_controller.actors.size()<=11,"curated crowd exceeded adventurer cap plus named NPCs",failures)
	var ids:Array[String]=[];for member in state.campaign.living_roster():ids.append(member.id)
	tavern.selected_party_ids=ids.slice(0,1);tavern.departure_running=true;tavern.activity_controller.begin_departure(tavern.selected_party_ids,tavern._complete_expedition_launch);tavern.activity_controller.fast_forward();await process_frame
	_expect(controller.starts==1 and controller.party==tavern.selected_party_ids,"departure did not launch the selected party exactly once",failures)
	tavern.activity_controller.fast_forward();_expect(controller.starts==1,"skipped departure launched twice",failures)
	tavern.free();controller.free();await process_frame
	if failures.is_empty():print("Living tavern activity validation passed.");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)

func _expect(value:bool,failure:String,failures:Array[String])->void:
	if not value:failures.append(failure)
