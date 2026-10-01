extends SceneTree

const OBJECTIVES:=preload("res://scripts/game/dungeon_objective_service.gd")
const ECOLOGY:=preload("res://scripts/game/dungeon_ecology.gd")

func _initialize()->void:
	var failures:Array[String]=[]
	_expect(OBJECTIVES.validate().is_empty(),"Dungeon objective data did not validate.",failures)
	_expect(NarrativeContent.next_route_stage("ashen_farmstead")=="sunken_mine" and NarrativeContent.next_route_stage("sunken_mine")=="ember_foundry" and NarrativeContent.next_route_stage("ember_foundry").is_empty(),"The playable Cinderway route is not connected or does not terminate at its keystone.",failures)
	var farmstead:=NarrativeContent.dungeon_lore("ashen_farmstead");var foundry:=NarrativeContent.dungeon_lore("ember_foundry")
	_expect(String(farmstead.prisoner_id)=="adragor" and String(foundry.stage)=="keystone" and Array(foundry.claims).size()>=3,"Adragor route roles or political claims are incomplete.",failures)
	var campaign:=CampaignState.new();campaign.apply_post_tutorial_state("victory");campaign.expedition.begin(["witness"],"ashen_farmstead",false,12,"","recover_evidence")
	var before:=ECOLOGY.state(campaign,"ashen_farmstead");campaign.record_dungeon_clear("ashen_farmstead");var after:=ECOLOGY.state(campaign,"sunken_mine")
	_expect(after==ECOLOGY.state(campaign,"ember_foundry") and float(after.resources)<float(before.resources),"Cinderway stages do not share ecology or evidence recovery did not consume resources.",failures)
	_expect(bool(campaign.clues.get("evidence_ashen_farmstead",false)) and Array(campaign.keeper_memory.discoveries).has("evidence_ashen_farmstead"),"Evidence objective did not persist its cross-loop record.",failures)
	_expect(int(campaign.faction_standing.get("veiled_isles",0))>=2 and int(campaign.faction_standing.get("sun_crowned_dominion",0))>=2,"Doctrine-aligned nations did not recognize the selected objective.",failures)
	var once:=ECOLOGY.state(campaign,"ashen_farmstead");campaign.record_dungeon_clear("ashen_farmstead")
	_expect(ECOLOGY.state(campaign,"ashen_farmstead")==once,"One expedition resolved the same stage objective more than once.",failures)
	var rebound:=CampaignState.new();rebound.apply_post_tutorial_state("death");rebound.expedition.begin(["binder"],"ember_foundry",false,13,"","rebind");rebound.record_dungeon_clear("ember_foundry");var rebound_state:=ECOLOGY.state(rebound,"ember_foundry")
	_expect(String(rebound_state.resolution)=="rebound" and float(rebound_state.stability)>=70.0 and int(rebound_state.suppression_count)==1,"Rebinding is not mechanically distinct at the route keystone.",failures)
	var negotiated:=CampaignState.new();negotiated.apply_post_tutorial_state("victory");negotiated.expedition.begin(["envoy"],"ember_foundry",false,14,"","negotiate");negotiated.record_dungeon_clear("ember_foundry");var negotiated_state:=ECOLOGY.state(negotiated,"ember_foundry")
	_expect(String(negotiated_state.resolution)=="new_covenant" and roundi(float(negotiated_state.pressure))==20 and int(negotiated.faction_standing.get("nordia",0))<2,"Negotiation does not produce its authored ecological and political tradeoff.",failures)
	var restored:=ExpeditionState.from_dict(negotiated.expedition.to_dict())
	_expect(restored.objective_id=="negotiate","Declared objective did not round trip with the expedition.",failures)
	var foundry_unlock:=Dictionary(GameBalance.get_dungeon("ember_foundry").get("unlock",{}))
	_expect(String(foundry_unlock.type)=="dungeon_clear" and String(foundry_unlock.dungeon_id)=="sunken_mine","Normal progression does not unlock the Foundry from the Cinderway's mine stage.",failures)
	if failures.is_empty():print("DUNGEON_OBJECTIVES_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
