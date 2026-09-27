extends RefCounted
class_name ExpeditionState

var active: bool = false
var expedition_id: int = 0
var dungeon_id: String = ""
var play_mode: String = "strategy"
var party_ids: Array[String] = []
var member_runtime: Dictionary = {}
var floor: int = 1
var carried_gold: int = 0
var carried_relic_essence: int = 0
var carried_relics: Array[String] = []
var casualties: Array[String] = []
var extraction_available: bool = false
var tutorial_run: bool = false
var tutorial_step: int = 0
var tutorial_controls_complete: bool = false
var tutorial_restart_count: int = 0
var rewarded_checkpoints: Dictionary = {}
var deployment_type: String = "manual"
var departure_day: int = 1
var due_day: int = 8
var retreat_policy: String = "balanced"
var simulation_seed: int = 0
var risk_ratio: float = 1.0
var locked_loadouts: Dictionary = {}
var secured_gold: int = 0
var secured_essence: int = 0

func begin(ids: Array[String], target_dungeon: String, mode: String, is_tutorial: bool = false, run_id: int = 0) -> void:
	active = true; expedition_id = maxi(0, run_id); dungeon_id = target_dungeon; play_mode = mode; party_ids = ids.duplicate()
	member_runtime.clear(); casualties.clear(); carried_relics.clear(); rewarded_checkpoints.clear(); floor = 1
	for character_id in party_ids:member_runtime[character_id]={"position":[],"health":-1,"resource":0,"strategy_turn":{},"slasher":{}}
	carried_gold = 0; carried_relic_essence = 0; extraction_available = false; tutorial_run = is_tutorial
	tutorial_step = 0; tutorial_controls_complete = false; tutorial_restart_count = 0

func living_party_ids() -> Array[String]:
	var living: Array[String] = []
	for character_id in party_ids:
		if not casualties.has(character_id): living.append(character_id)
	return living

func record_casualty(character_id: String) -> void:
	if party_ids.has(character_id) and not casualties.has(character_id): casualties.append(character_id)

func clear_floor() -> void:
	extraction_available = true

func reward_checkpoint(checkpoint_id:String, essence:int) -> bool:
	if rewarded_checkpoints.has(checkpoint_id): return false
	rewarded_checkpoints[checkpoint_id] = true; carried_relic_essence += maxi(0, essence); return true

func continue_from_checkpoint() -> void:
	extraction_available = false

func to_dict() -> Dictionary:
	return {"deployment_type":deployment_type,"departure_day":departure_day,"due_day":due_day,"retreat_policy":retreat_policy,"simulation_seed":simulation_seed,"risk_ratio":risk_ratio,"locked_loadouts":locked_loadouts,"secured_gold":secured_gold,"secured_essence":secured_essence,"active":active,"expedition_id":expedition_id,"dungeon_id":dungeon_id,"play_mode":play_mode,"party_ids":party_ids.duplicate(),"member_runtime":member_runtime.duplicate(true),"floor":floor,"carried_gold":carried_gold,"carried_relic_essence":carried_relic_essence,"carried_relics":carried_relics.duplicate(),"casualties":casualties.duplicate(),"extraction_available":extraction_available,"tutorial_run":tutorial_run,"tutorial_step":tutorial_step,"tutorial_controls_complete":tutorial_controls_complete,"tutorial_restart_count":tutorial_restart_count,"rewarded_checkpoints":rewarded_checkpoints.duplicate(true)}

static func from_dict(data: Dictionary) -> ExpeditionState:
	var state := ExpeditionState.new();
	state.deployment_type = data.get("deployment_type","manual")
	state.departure_day = data.get("departure_day",1)
	state.due_day = data.get("due_day",8)
	state.retreat_policy = data.get("retreat_policy","balanced")
	state.simulation_seed = data.get("simulation_seed",0)
	state.risk_ratio = data.get("risk_ratio",1.0)
	state.locked_loadouts = data.get("locked_loadouts",{})
	state.secured_gold = data.get("secured_gold",0)
	state.secured_essence = data.get("secured_essence",0)
	state.active = bool(data.get("active", false)); state.expedition_id = maxi(0, int(data.get("expedition_id", 0))); state.dungeon_id = String(data.get("dungeon_id", "")); state.play_mode = String(data.get("play_mode", "strategy"))
	state.party_ids.assign(data.get("party_ids", [])); state.member_runtime = Dictionary(data.get("member_runtime", {})).duplicate(true); state.floor = maxi(1, int(data.get("floor", 1)))
	state.carried_gold = maxi(0, int(data.get("carried_gold", 0))); state.carried_relic_essence = maxi(0, int(data.get("carried_relic_essence", 0))); state.carried_relics.assign(data.get("carried_relics", [])); state.casualties.assign(data.get("casualties", []))
	state.extraction_available = bool(data.get("extraction_available", false)); state.tutorial_run = bool(data.get("tutorial_run", false)); state.tutorial_step = clampi(int(data.get("tutorial_step", 0)), 0, 9); state.tutorial_controls_complete = bool(data.get("tutorial_controls_complete", state.tutorial_step >= 9)); state.tutorial_restart_count = maxi(0, int(data.get("tutorial_restart_count", 0))); state.rewarded_checkpoints = Dictionary(data.get("rewarded_checkpoints", {})).duplicate(true); return state
