extends SceneTree

const DIVINE:=preload("res://scripts/game/divine_favor_service.gd")

func _initialize()->void:
	var failures:Array[String]=[]
	_expect(DIVINE.validate().is_empty(),"Pantheon data did not validate.",failures)
	_expect(DIVINE.ordered_deity_ids().size()==12,"The six pantheons do not contain the initial twelve authored gods.",failures)
	var campaign:=CampaignState.new();var expedition:=ExpeditionState.new();expedition.begin(["test_hero"],"forest",false,7,"yrsa_hearth_wolf");expedition.carried_contribution=20;expedition.carried_gold=100
	var restored_expedition:=ExpeditionState.from_dict(expedition.to_dict())
	_expect(restored_expedition.patron_deity_id=="yrsa_hearth_wolf","Expedition patronage did not round trip.",failures)
	var unpatroned:=ExpeditionState.new();unpatroned.begin(["test_hero"],"forest",false,8)
	_expect(String(unpatroned.patron_deity_id).is_empty() and int(DIVINE.record_expedition_outcome(campaign,unpatroned,"victory").favor_gained)==0,"Unpatroned expeditions are not neutral and viable.",failures)
	campaign.divine_favor["yrsa_hearth_wolf"]=10;var accepted:=DIVINE.accept_boon(campaign,"yrsa_hearth_wolf")
	_expect(bool(accepted.ok) and int(campaign.divine_favor["yrsa_hearth_wolf"])==2 and campaign.active_boons.has("yrsa_hearth_wolf"),"Favor did not purchase the authored bargain.",failures)
	var modifiers:=DIVINE.settlement_modifiers(campaign,expedition)
	_expect(float(modifiers.contribution_multiplier)>1.0 and is_equal_approx(float(modifiers.gold_multiplier),1.0),"Boon effects were not scoped to their sponsored expedition.",failures)
	var result:=DIVINE.record_expedition_outcome(campaign,expedition,"victory")
	_expect(int(result.favor_gained)==8 and String(result.obligation)=="fulfilled" and not campaign.active_boons.has("yrsa_hearth_wolf") and campaign.divine_obligations.size()==1,"Victory did not award favor and fulfill the bargain.",failures)
	campaign.divine_favor["sai_half_mask"]=3;campaign.divine_favor["yrsa_hearth_wolf"]=8;DIVINE.accept_boon(campaign,"yrsa_hearth_wolf");var broken:=DIVINE.record_expedition_outcome(campaign,expedition,"death")
	_expect(String(broken.obligation)=="broken" and int(campaign.divine_favor["sai_half_mask"])==2,"Broken promises or divine rivalry costs were not recorded.",failures)
	var snapshot:=campaign.to_dict();var loaded:=CampaignState.new();loaded._load_dict(snapshot)
	_expect(loaded.divine_obligations.size()==2 and loaded.divine_favor==campaign.divine_favor,"Divine state did not round trip through the campaign save.",failures)
	var migrated:=CampaignState._migrate_dict({"version":11,"divine_favor":{"yrsa_hearth_wolf":4}})
	_expect(int(migrated.version)==CampaignState.SAVE_VERSION and Dictionary(migrated.active_boons).is_empty() and Array(migrated.divine_obligations).is_empty(),"Version 11 divine state did not migrate safely.",failures)
	if failures.is_empty():print("DIVINE_FAVOR_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
