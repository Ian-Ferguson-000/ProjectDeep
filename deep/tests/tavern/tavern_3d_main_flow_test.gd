extends SceneTree
const MAIN:=preload("res://game/main/main.gd")
class MemoryCampaign extends CampaignState:
	func save_atomic() -> bool:return true
var failures:Array[String]=[]
func _initialize() -> void:call_deferred("_run")
func expect(value:bool,text:String) -> void:
	if not value:failures.append(text);push_error(text)
func _run() -> void:
	var main:=MAIN.new()
	root.add_child(main)
	var state:=RunState.new()
	state.campaign=MemoryCampaign.new()
	state.campaign.apply_post_tutorial_state("victory")
	state.campaign.last_presented_wave_id=state.campaign.candidate_wave_id
	state.campaign.first_normal_launch_completed=true
	state.campaign.tavern_phase=CampaignState.TAVERN_OPEN
	TavernTour.mark_done(state.campaign)
	var candidate:CandidateRecord=state.campaign.get_candidates()[0]
	for visitor in state.campaign.get_candidates():state.campaign.recruit_candidate(visitor.id)
	main.run_state=state
	main.campaign=state.campaign
	main.show_tavern()
	for i in 12:await physics_frame
	expect(main.current_scene.get_node_or_null("World3D")!=null,"Main did not enter the 3D hub")
	var member:CharacterRecord=state.campaign.character(candidate.id)
	var gear:=HearthCatalog.gear(member.gear_id)
	main.start_dungeon("forest",gear,[member.id] as Array[String])
	for i in 5:await physics_frame
	expect(state.campaign.expedition.active,"3D hub could not launch an expedition")
	expect(main.current_scene.get_node_or_null("ForestWorld3D")!=null,"Forest expedition did not use the 3D rooms")
	expect(main.current_scene.get_node_or_null("World3D")==null,"Dungeon transition left the tavern active")
	main.return_to_tavern("victory","Integration test return")
	for i in 12:await physics_frame
	expect(main.current_scene.get_node_or_null("World3D")!=null,"Returning from the dungeon did not restore the 3D hub")
	expect(main.current_scene.results_backdrop.visible,"Return results were lost during the 3D transition")
	main.current_scene._close_modal(main.current_scene.results_backdrop)
	for i in 3:await process_frame
	main.queue_free()
	await process_frame
	if failures.is_empty():print("TAVERN_3D_MAIN_FLOW_PASSED")
	quit(0 if failures.is_empty() else 1)
