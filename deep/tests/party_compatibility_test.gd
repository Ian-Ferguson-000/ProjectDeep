extends SceneTree

const COMPATIBILITY := preload("res://scripts/game/party_compatibility.gd")

func _initialize() -> void:
	var failures:Array[String]=[]
	var campaign:=CampaignState.new();campaign.apply_post_tutorial_state("victory")
	for candidate in campaign.get_candidates():campaign.recruit_candidate(candidate.id)
	var party:=campaign.default_party("forest")
	_expect(party.size()==2,"Founding party is incomplete.",failures)
	var brina:=campaign.character(party[0]);var eamon:=campaign.character(party[1])
	_expect(brina.doctrine_id=="nordia_destroy" and eamon.doctrine_id=="zarabia_rebind","Founders did not receive their national default doctrines.",failures)
	var initial:=COMPATIBILITY.evaluate(campaign,party)
	_expect(int(initial.score)==0 and String(initial.band)=="Stable","Cross-national field knowledge should offset the founders' initial doctrinal dispute.",failures)
	_expect(COMPATIBILITY.doctrines_conflict(brina.doctrine_id,eamon.doctrine_id),"Founding doctrinal conflict is not represented.",failures)
	COMPATIBILITY.record_shared_outcome(campaign,party,"victory")
	_expect(int(brina.relationships.get(eamon.id,0))==1 and int(eamon.relationships.get(brina.id,0))==1,"Shared victory did not build a reciprocal relationship.",failures)
	var improved:=COMPATIBILITY.evaluate(campaign,party)
	_expect(int(improved.score)>int(initial.score),"A shared expedition did not improve future party cohesion.",failures)
	var copy:=CharacterRecord.from_dict(brina.to_dict())
	_expect(copy.doctrine_id==brina.doctrine_id and int(copy.relationships.get(eamon.id,0))==1,"Doctrine or relationships did not survive character serialization.",failures)
	var risk:=HearthExpeditions.risk(campaign,party,"forest")
	_expect(risk.has("compatibility") and Array(risk.reasons).any(func(reason):return String(reason).contains("Social cohesion")),"Expedition risk does not expose social compatibility.",failures)
	var settlement_campaign:=CampaignState.new();settlement_campaign.apply_post_tutorial_state("victory")
	for candidate in settlement_campaign.get_candidates():settlement_campaign.recruit_candidate(candidate.id)
	var settlement_party:=settlement_campaign.default_party("forest");var launch:=settlement_campaign.launch_expedition(settlement_party,"forest")
	settlement_campaign.expedition.carried_contribution=7
	var settlement:=settlement_campaign.settle_expedition(int(launch.get("expedition_id",0)),"victory",{"headline":"Founders return"})
	var returned_brina:=settlement_campaign.character(settlement_party[0]);var returned_eamon:=settlement_campaign.character(settlement_party[1])
	_expect(bool(settlement.get("ok",false)) and int(settlement_campaign.faction_standing.get("nordia",0))==3 and int(settlement_campaign.faction_standing.get("zarabia",0))==1,"Victory settlement did not advance represented nation standings exactly once.",failures)
	_expect(returned_brina!=null and returned_eamon!=null and int(returned_brina.relationships.get(returned_eamon.id,0))==1,"Victory settlement did not build the surviving party relationship.",failures)
	_expect(settlement_campaign.contribution==97,"Settlement did not preserve expedition Contribution.",failures)
	if failures.is_empty():print("PARTY_COMPATIBILITY_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
