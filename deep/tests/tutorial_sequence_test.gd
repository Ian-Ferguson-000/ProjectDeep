extends SceneTree

const TUTORIAL_SEQUENCE := preload("res://scripts/slasher/forest_tutorial_sequence.gd")
const DIALOGUE_CHAT := preload("res://scripts/ui/dialogue_chat.gd")
const SLASHER_FOREST := preload("res://scripts/slasher/slasher_forest.gd")
const TAVERN := preload("res://scenes/tavern/Tavern.tscn")

class ReturnController extends Node:
	var return_count := 0
	func return_to_tavern(_outcome: String, _message: String) -> void: return_count += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var tutorial_campaign := CampaignState.new()
	var alden := tutorial_campaign.create_tutorial_adventurer()
	_expect(alden.id=="tutorial_alden" and alden.display_name=="Alden" and alden.class_id=="warrior" and alden.portrait_variant==0 and alden.gear_id=="sword_shield" and alden.current_health==3 and alden.max_health==3,"Preset Alden contract is incomplete",failures)
	_expect(tutorial_campaign.begin_expedition([alden.id],"forest","slasher",true),"Tutorial expedition did not start",failures)
	tutorial_campaign.expedition.tutorial_step=4
	var restored_expedition:=ExpeditionState.from_dict(tutorial_campaign.expedition.to_dict())
	_expect(restored_expedition.tutorial_step==4 and not restored_expedition.tutorial_controls_complete,"Tutorial step did not survive expedition serialization",failures)
	var forest:=SLASHER_FOREST.new();_expect(not forest.has_method("_abandon_run"),"Slasher runtime still exposes abandonment",failures);forest.free()
	tutorial_campaign.expedition.carried_gold=47;tutorial_campaign.expedition.carried_relics=["test_relic"];tutorial_campaign.expedition.floor=3
	var restarted_alden:=tutorial_campaign.restart_tutorial_expedition();_expect(restarted_alden!=null and restarted_alden.current_health==3 and tutorial_campaign.expedition.floor==1 and tutorial_campaign.expedition.tutorial_step==0 and tutorial_campaign.expedition.carried_gold==0 and tutorial_campaign.expedition.carried_relics.is_empty() and tutorial_campaign.expedition.tutorial_restart_count==1 and tutorial_campaign.memorial.is_empty(),"Early tutorial death did not perform a clean onboarding restart",failures)

	var sequence:ForestTutorialSequence=TUTORIAL_SEQUENCE.new();root.add_child(sequence);await process_frame
	sequence.begin(0,Vector2.ZERO)
	sequence.observe_movement(Vector2(40,0),false);_expect(sequence.current_step==0,"Controller movement advanced keyboard onboarding",failures)
	sequence.observe_movement(Vector2(40,0),true);_expect(sequence.current_step==0,"Tapping WASD after controller movement advanced onboarding",failures)
	sequence.observe_movement(Vector2(75,0),true);await _transition();_expect(sequence.current_step==1,"WASD movement did not advance",failures)
	sequence.observe_ability({"started":false,"slot":"basic","input_source":"mouse"});_expect(sequence.current_step==1,"Failed attack advanced onboarding",failures)
	sequence.observe_ability({"started":true,"slot":"basic","input_source":"controller"});_expect(sequence.current_step==1,"Controller attack advanced mouse onboarding",failures)
	sequence.observe_ability({"started":true,"slot":"basic","input_source":"mouse"});await _transition()
	sequence.observe_ability({"started":true,"slot":"movement","input_source":"mouse"});await _transition()
	sequence.observe_ability({"started":true,"slot":"special","input_source":"keyboard"});await _transition()
	sequence.observe_ability({"started":true,"slot":"defensive","input_source":"mouse_shift"});await _transition()
	sequence.observe_consumable("potion","keyboard");await _transition()
	sequence.observe_consumable("slot","keyboard");await _transition()
	sequence.observe_reward();await _transition()
	sequence.observe_menu_opened("controller");_expect(sequence.current_step==8,"Controller menu advanced keyboard onboarding",failures)
	sequence.observe_menu_opened("keyboard");_expect(sequence.current_step==9 and not sequence.visible,"M did not finish onboarding",failures)
	sequence.queue_free()

	var death_campaign:=CampaignState.new();death_campaign.memorial.append({"id":"tutorial_alden","name":"Alden","class_id":"warrior","level":1,"cause":"Tutorial death","expeditions":1,"victories":0});death_campaign.apply_post_tutorial_state("death")
	var victory_campaign:=CampaignState.new();victory_campaign.apply_post_tutorial_state("victory")
	var original_victory_roster:=victory_campaign.roster.keys();victory_campaign.apply_post_tutorial_state("death");_expect(victory_campaign.tutorial_outcome=="victory" and victory_campaign.roster.keys()==original_victory_roster,"Post-tutorial campaign initialization was not idempotent",failures)
	for campaign in [death_campaign,victory_campaign]:
		_expect(campaign.is_tutorial_complete() and campaign.living_roster().is_empty() and campaign.candidate_pool.size()==2,"Tutorial ending did not create exactly two candidates",failures)
		var first_wave:Array=campaign.get_candidates();_expect(first_wave[0].adventurer.class_id=="warrior" and first_wave[1].adventurer.class_id=="mage","Starting Warrior and Mage candidates are missing",failures)
		_expect(campaign.banked_gold==120 and campaign.supplies==8,"Standardized tutorial resources are incorrect",failures)
		_expect(campaign.tutorial_letter_unlocked and not campaign.tutorial_keepsake_id.is_empty(),"Tutorial story unlocks are missing",failures)
		_expect(campaign.completed_dungeon_modes.is_empty() and campaign.unlocked_classes==["warrior","mage"],"Tutorial outcome leaked campaign power",failures)
	_expect(death_campaign.memorial.size()==1 and not death_campaign.former_keeper_encounter_pending,"Death branch history is incorrect",failures)
	_expect(victory_campaign.memorial.is_empty() and victory_campaign.former_keeper_encounter_pending,"Victory branch history is incorrect",failures)
	_expect(victory_campaign.should_trigger_former_keeper_encounter("forest","victory"),"Former keeper confrontation did not become eligible",failures)
	victory_campaign.mark_former_keeper_encounter_seen();_expect(not victory_campaign.should_trigger_former_keeper_encounter("forest","victory"),"Former keeper confrontation was not one-time",failures)
	var round_trip:=CampaignState.new();round_trip._load_dict(CampaignState._migrate_dict(victory_campaign.to_dict()));_expect(round_trip.supplies==8 and round_trip.tutorial_outcome=="victory" and round_trip.former_keeper_encounter_seen,"Tutorial campaign state did not round trip",failures)
	var neutral_migration:=CampaignState._migrate_dict({"version":3,"tutorial_phase":CampaignState.TUTORIAL_COMPLETE,"roster":[]});_expect(int(neutral_migration.get("supplies",-1))==0 and String(neutral_migration.get("tutorial_outcome","x")).is_empty() and not bool(neutral_migration.get("tutorial_letter_unlocked",true)) and not bool(neutral_migration.get("former_keeper_encounter_pending",true)),"Version-3 tutorial fields did not migrate with neutral defaults",failures)
	_expect(ResourceLoader.exists("res://assets/generated_characters/town_mayor.png"),"Mayor portrait is missing",failures)

	var chat:DialogueChat=DIALOGUE_CHAT.new();root.add_child(chat);await process_frame
	chat.play([{"speaker":"Left","text":"Test line","portrait":"res://assets/merchants/tavern_mara.png","side":"left"},{"speaker":"Right","text":"Reply","portrait":"res://assets/roster_portraits/warrior_0.png","side":"right"}])
	_expect(paused and chat.visible and chat.left_portrait.texture!=null and chat.right_portrait.texture!=null,"Dialogue chat did not pause or populate both portrait sides",failures)
	chat._advance();chat._advance();_expect(not paused and not chat.visible,"Dialogue chat did not restore pause state",failures);chat.queue_free()

	var ledger_state:=RunState.new();ledger_state.attach_campaign(victory_campaign);ledger_state.set_class("warrior")
	var ledger_gear:Array[GearData]=[];var tavern:=TAVERN.instantiate();tavern.setup(null,ledger_state,ledger_gear,"");root.add_child(tavern);await process_frame;tavern._open_company_ledger();await process_frame
	var resource_copy:=""
	for label in tavern.company_pages["Resources"].find_children("*","Label",true,false):resource_copy+="\n"+String((label as Label).text)
	_expect(resource_copy.contains("SUPPLIES") and resource_copy.contains("Briarway Deed Seal") and resource_copy.contains("THE FORMER KEEPER'S LETTER"),"Company Ledger omitted tutorial resources or story unlocks",failures)
	tavern.queue_free()

	if failures.is_empty():print("TUTORIAL_SEQUENCE_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)

func _transition() -> void:
	await create_timer(0.36).timeout

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
