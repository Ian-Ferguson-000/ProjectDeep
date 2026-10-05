extends RefCounted
class_name CampaignState

const SAVE_VERSION := 16
const CALENDAR_HISTORY_DAYS := 112
const TARGET_ROSTER_SIZE := 2
const BASE_ROSTER_CAPACITY := 6
const TUTORIAL_STARTING_HEALTH := 3
const SAVE_SLOT_COUNT := 3
const LEGACY_SAVE_PATH := "user://campaign.json"
const LEGACY_BACKUP_SAVE_PATH := "user://campaign.json.bak"
const TUTORIAL_NEW := "new"
const TUTORIAL_DIALOGUE := "dialogue"
const TUTORIAL_LOADOUT := "loadout"
# Keep the legacy serialized value so existing tutorial saves remain loadable.
const TUTORIAL_EXPEDITION := "last_stand"
const TUTORIAL_MOURNING := "mourning"
const TUTORIAL_COMPLETE := "complete"
const TAVERN_SETTLEMENT := "settlement"
const TAVERN_STORY := "story"
const TAVERN_CALENDAR := "calendar"
const TAVERN_ARRIVALS := "arrivals"
const TAVERN_OPEN := "open"
const TAVERN_EXPEDITION := "expedition"
const WEEKDAYS := ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]
const SEASONS := ["Spring","Summer","Autumn","Winter"]
const BASIC_GEAR := {"warrior":"sword_shield","mage":"magic_missile_shield","healer":"sunwood_staff","tank":"tower_shield","rogue":"spectral_dagger","summoner":"bond_staff"}
const ADVENTURERS:=preload("res://scripts/game/adventurer_content.gd")
const COMPATIBILITY:=preload("res://scripts/game/party_compatibility.gd")
const ECOLOGY:=preload("res://scripts/game/dungeon_ecology.gd")
const DIVINE:=preload("res://scripts/game/divine_favor_service.gd")
const CRISIS:=preload("res://scripts/game/world_crisis.gd")
const OBJECTIVES:=preload("res://scripts/game/dungeon_objective_service.gd")
const NATION_ARRIVALS:=preload("res://scripts/game/nation_arrival_service.gd")
const ATTRIBUTE_IDS:=["str","dex","con","int","wis","cha"]

const NAMES := ["Alden","Brina","Corin","Dessa","Eamon","Fara","Garrick","Hale","Ilyra","Joren","Kael","Lysa","Merek","Nessa","Orin","Petra","Quill","Rhea","Soren","Tamsin","Ulric","Veya"]
const TRAITS := [
	{"id":"stalwart","name":"Stalwart","description":"+1 maximum health; -1 initiative."},
	{"id":"quick","name":"Quick","description":"+1 initiative; -1 maximum health."},
	{"id":"keen","name":"Keen","description":"+1 accuracy; healing received is reduced by 1."},
	{"id":"hardy","name":"Hardy","description":"Healing received +1; movement actions cannot gain bonus distance."},
]

var tutorial_phase: String = TUTORIAL_NEW
var roster: Dictionary = {}
var memorial: Array[Dictionary] = []
var unlocked_classes: Array[String] = ["warrior", "mage"]
var completed_dungeons: Dictionary = {}
var banked_gold: int = 0
var supplies: int = 0
var relic_essence: int = 0
var lifetime_relic_essence: int = 0
var banked_relics: Array[String] = []
var successful_levels: int = 0
var tavern_upgrades: Dictionary = {"recovery":0,"roster_services":0,"starting_supplies":0,"item_rarity":0,"merchant_stock":0,"relic_capacity":0,"secret_research":0,"replacement_quality":0}
var tavern_dialogue_flags: Dictionary = {}
var clues: Dictionary = {}
var tutorial_outcome: String = ""
var tutorial_history: Dictionary = {}
var tutorial_keepsake_id: String = ""
var tutorial_letter_unlocked: bool = false
var keeper_journal_unlocked: bool = false
var contribution: int = 0
var faction_standing: Dictionary = {}
var divine_favor: Dictionary = {}
var active_boons: Dictionary = {}
var divine_obligations: Array[Dictionary] = []
var story_event_history: Dictionary = {}
var keeper_memory: Dictionary = {"loop_number":0,"discoveries":[],"remembered_people":[]}
var dungeon_ecology:Dictionary={}
var world_crisis:Dictionary={}
var ending_state:Dictionary={}
var post_tutorial_initialized: bool = false
var former_keeper_encounter_pending: bool = false
var former_keeper_encounter_seen: bool = false
var calendar_day: int = 1
var calendar_shift: int = 0
var period_elapsed_shifts: int = 0
var period_completed_runs: int = 0
var tavern_phase: String = TAVERN_OPEN
var candidate_wave_id: int = 0
var candidate_pool: Dictionary = {}
var last_presented_wave_id: int = 0
var calendar_history: Array[Dictionary] = []
var retired_heroes: Array[Dictionary] = []
var first_company_ids: Array[String] = []
var first_company_recruited: bool = false
var first_normal_launch_completed: bool = false
var next_expedition_id: int = 1
var last_settled_expedition_id: int = 0
var pending_settlement_summary:Dictionary={}
var pending_story_context:String=""
var pending_story_event_id:String=""
var next_character_number: int = 1
var expedition := ExpeditionState.new()
var legacy_runtime: Dictionary = {}
var last_save_error: String = ""
var save_slot: int = 1
var last_saved_unix: int = 0
var armory: Dictionary = {}
var next_item_id = 1
var establishment_tier = 0
var construction: Dictionary = {}
var dispatches: Dictionary = {}
var settled_expeditions: Dictionary = {}
var return_reports = []
var market_stock: Dictionary = {}
var consumable_stock: Dictionary = {}
var reputation:=0
var used_curated_ids:Array[String]=[]
var lineage_registry:Dictionary={}

static func save_path(slot:int)->String:return "user://campaign_slot_%d.json"%clampi(slot,1,SAVE_SLOT_COUNT)
static func temp_save_path(slot:int)->String:return save_path(slot)+".tmp"
static func backup_save_path(slot:int)->String:return save_path(slot)+".bak"

static func slot_summary(slot:int)->Dictionary:
	slot=clampi(slot,1,SAVE_SLOT_COUNT)
	var parsed:=_read_save_dictionary(save_path(slot));var recovered:=false
	if parsed.is_empty():parsed=_read_save_dictionary(backup_save_path(slot));recovered=not parsed.is_empty()
	if parsed.is_empty() and slot==1:parsed=_read_save_dictionary(LEGACY_SAVE_PATH);recovered=not parsed.is_empty()
	if parsed.is_empty():return {"slot":slot,"exists":false,"recoverable":false}
	if int(parsed.get("version",0))>SAVE_VERSION:return {"slot":slot,"exists":true,"recoverable":false,"error":"Newer save version"}
	var data:=_migrate_dict(parsed);var roster_values:Array=Array(data.get("roster",[]));var living:=0
	for value in roster_values:
		if value is Dictionary and String(value.get("status","available"))!="dead":living+=1
	return {"slot":slot,"exists":true,"recoverable":true,"recovered":recovered,"tutorial_phase":String(data.get("tutorial_phase",TUTORIAL_NEW)),"roster_count":living,"completed_dungeons":Dictionary(data.get("completed_dungeons",{})).size(),"banked_gold":int(data.get("banked_gold",0)),"last_saved_unix":int(data.get("last_saved_unix",0))}

static func all_slot_summaries()->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for slot in range(1,SAVE_SLOT_COUNT+1):result.append(slot_summary(slot))
	return result

func is_tutorial_complete() -> bool: return tutorial_phase == TUTORIAL_COMPLETE

func create_tutorial_adventurer() -> CharacterRecord:
	var existing := character("tutorial_alden")
	if existing != null: return existing
	var alden := CharacterRecord.create("tutorial_alden", "Alden", "warrior", {"id":"steady","name":"Steady","description":"No unusual strengths or weaknesses."}, 0)
	alden.max_health = TUTORIAL_STARTING_HEALTH
	alden.current_health = TUTORIAL_STARTING_HEALTH
	if int(keeper_memory.get("loop_number",0))>0:
		alden.max_health=TUTORIAL_STARTING_HEALTH+2;alden.current_health=alden.max_health;alden.accomplishments.append("The Keeper prepared him using memory of the road ahead.")
	alden.gear_id = "sword_shield"
	alden.origin = "Nordia's Briarway border"
	alden.nation_id = "nordia"
	alden.faith_id = "unaffiliated"
	alden.doctrine_id = "nordia_destroy"
	alden.biography = "A young Nordian who entered the failing Hearth when the roads had nearly gone quiet."
	roster[alden.id] = alden
	return alden

func restart_tutorial_expedition() -> CharacterRecord:
	if not expedition.tutorial_run: return null
	var restart_count := expedition.tutorial_restart_count + 1
	var alden := create_tutorial_adventurer()
	alden.status = CharacterRecord.STATUS_EXPEDITION
	alden.max_health = TUTORIAL_STARTING_HEALTH
	alden.current_health = TUTORIAL_STARTING_HEALTH
	if int(keeper_memory.get("loop_number",0))>0:alden.max_health=TUTORIAL_STARTING_HEALTH+2;alden.current_health=alden.max_health
	expedition.begin([alden.id], "forest", true, expedition.expedition_id)
	expedition.tutorial_restart_count = restart_count
	return alden

func apply_post_tutorial_state(outcome: String) -> void:
	if post_tutorial_initialized: return
	outcome = "victory" if outcome == "victory" else "death"
	tutorial_outcome = outcome
	var opening_contribution := 90 if outcome == "victory" else 55
	tutorial_history = {"adventurer":"Alden","class_id":"warrior","nation_id":"nordia","outcome":"returned_hero" if outcome == "victory" else "memorialized","contribution":opening_contribution}
	tutorial_keepsake_id = "aldens_first_contract" if outcome == "victory" else "aldens_mourning_ribbon"
	tutorial_letter_unlocked = false
	keeper_journal_unlocked = true
	contribution = opening_contribution
	faction_standing = {"nordia":2 if outcome == "victory" else 1,"zarabia":0}
	divine_favor.clear()
	story_event_history = {"last_customer_resolved":true}
	keeper_memory = {"loop_number":0,"discoveries":["briarway_approach"],"remembered_people":["tutorial_alden"]}
	dungeon_ecology.clear();ECOLOGY.ensure(self)
	world_crisis=CRISIS.defaults(calendar_day)
	former_keeper_encounter_pending = false
	former_keeper_encounter_seen = false
	armory.clear();next_item_id=1;establishment_tier=0;construction.clear();dispatches.clear();settled_expeditions.clear();return_reports.clear();market_stock.clear();consumable_stock.clear()
	banked_gold = 120
	supplies = 8
	relic_essence = 0
	lifetime_relic_essence = 0
	banked_relics.clear()
	successful_levels = 0
	completed_dungeons.clear()
	reputation=0;used_curated_ids.clear();lineage_registry.clear()
	clues.clear()
	unlocked_classes = ["warrior", "mage"]
	tavern_upgrades = {"recovery":0,"roster_services":0,"starting_supplies":0,"item_rarity":0,"merchant_stock":0,"relic_capacity":0,"secret_research":0,"replacement_quality":0}
	tavern_dialogue_flags.clear()
	roster.clear()
	next_character_number = 1
	candidate_pool.clear()
	candidate_wave_id = 1
	calendar_day = 1
	calendar_shift = 0
	HearthCalendar.reset_story_period(self)
	var warrior := _character_from_definition(ADVENTURERS.definition("brina_founder"))
	_apply_attributes(warrior,45,0x0b71a)
	next_character_number+=1
	warrior.gear_id = "sword_shield"
	var mage := _character_from_definition(ADVENTURERS.definition("eamon_founder"))
	_apply_attributes(mage,45,0x0ea40)
	next_character_number+=1
	mage.gear_id = "magic_missile_shield"
	first_company_ids = [warrior.id, mage.id]
	candidate_pool[warrior.id] = CandidateRecord.create(warrior, calendar_day, candidate_wave_id, "I want to prove that steady hands can outlast the Briarway.", true)
	candidate_pool[mage.id] = CandidateRecord.create(mage, calendar_day, candidate_wave_id, "There are truths in those ruins that no safe library can teach.", true)
	first_company_recruited = false
	first_normal_launch_completed = false
	last_presented_wave_id = 0
	tavern_phase = TAVERN_ARRIVALS
	calendar_history = [{"day":calendar_day,"kind":"arrivals","text":"Brina and Eamon arrive at the Hearth."}]
	retired_heroes.clear()
	next_expedition_id = 1
	last_settled_expedition_id = 0
	expedition = ExpeditionState.new()
	tutorial_phase = TUTORIAL_COMPLETE
	post_tutorial_initialized = true

func get_calendar_date() -> Dictionary:
	var zero_based := maxi(0, calendar_day - 1)
	return {"absolute_day":calendar_day,"weekday":WEEKDAYS[zero_based%7],"season":SEASONS[int(zero_based/28)%SEASONS.size()],"season_day":zero_based%28+1,"year":int(zero_based/112)+1}

func get_active_season_modifiers()->Array[Dictionary]:
	# Extension hook for the later seasonal-mechanics phase.
	return []

func get_roster_capacity() -> int:
	return int(HearthCatalog.tier(establishment_tier).capacity)

func get_candidates() -> Array[CandidateRecord]:
	var result:Array[CandidateRecord]=[]
	for value in candidate_pool.values():
		if value is CandidateRecord:result.append(value)
	result.sort_custom(func(a:CandidateRecord,b:CandidateRecord):return a.id<b.id)
	return result

func evaluate_tavern_condition(condition: Dictionary, candidate_id: String = "") -> bool:
	var service := TavernDialogueService.new()
	return service.evaluate_condition(condition, {"campaign": self, "candidate": candidate_pool.get(candidate_id)})

func get_recruitment_requirement(candidate_id: String) -> Dictionary:
	return TavernDialogueService.new().recruitment_requirement(candidate_id)

func ensure_tavern_cycle() -> Dictionary:
	if not is_tutorial_complete():return {"ok":false,"error":"The tutorial is not complete."}
	if expedition.active:return {"ok":false,"error":"An expedition is active."}
	if candidate_pool.is_empty() and (candidate_wave_id==0 or living_roster().is_empty()):_generate_candidate_wave(false)
	_ensure_unrepresented_class_candidates()
	if tavern_phase==TAVERN_EXPEDITION:tavern_phase=TAVERN_OPEN
	if last_presented_wave_id<candidate_wave_id:tavern_phase=TAVERN_ARRIVALS
	return {"ok":true,"wave_id":candidate_wave_id,"phase":tavern_phase}

func mark_arrivals_presented(wave_id:int) -> Dictionary:
	if wave_id!=candidate_wave_id:return {"ok":false,"error":"That candidate wave is no longer present."}
	last_presented_wave_id=maxi(last_presented_wave_id,wave_id);tavern_phase=TAVERN_OPEN
	return {"ok":true,"wave_id":wave_id}

func recruit_candidate(candidate_id:String) -> Dictionary:
	var candidate:=candidate_pool.get(candidate_id) as CandidateRecord
	if candidate==null:return {"ok":false,"error":"That adventurer is no longer at the Hearth."}
	if living_roster().size()>=get_roster_capacity():return {"ok":false,"error":"The Hearth has no open rooms."}
	var fee := candidate.adventurer.signing_fee
	if not candidate.first_company and living_roster().size() < 2 and banked_gold < fee and candidate.adventurer.level <= 2: fee = 0
	if banked_gold < fee: return {"ok":false,"error":"Signing this recruit costs %d gold." % fee}
	banked_gold -= fee
	var member:=candidate.adventurer;member.status=CharacterRecord.STATUS_AVAILABLE;roster[member.id]=member;candidate_pool.erase(candidate_id)
	HearthArmory.ensure_starter(self,member)
	var was_recruited := first_company_recruited
	first_company_recruited=first_company_recruited or first_company_ids.all(func(id:String):return roster.has(id))
	if first_company_recruited and not was_recruited: HearthCalendar.reset_story_period(self)
	_add_calendar_event("recruitment","%s joins the company."%member.display_name)
	return {"ok":true,"character_id":member.id,"message":"%s joins the company."%member.display_name}

func inspect_candidate(candidate_id:String,interaction_id:String)->Dictionary:
	var candidate:=candidate_pool.get(candidate_id) as CandidateRecord
	if candidate==null:return {"ok":false,"error":"That adventurer is no longer at the Hearth."}
	if interaction_id not in ["review","observe","talk"]:return {"ok":false,"error":"Unknown candidate interaction."}
	if interaction_id!="review" and candidate.completed_interactions.has(interaction_id):return {"ok":true,"duplicate":true,"result":candidate.last_result,"candidate":candidate}
	if interaction_id=="observe":candidate.knowledge.equipment="exact";candidate.knowledge.personality="hint";candidate.last_result="Observation confirms %s and a %s temperament."%[candidate.adventurer.gear_id.replace("_"," "),candidate.adventurer.personality.to_lower()]
	elif interaction_id=="talk":candidate.knowledge.origin="exact";candidate.knowledge.preference="exact";candidate.knowledge.biography="exact";candidate.last_result=candidate.adventurer.biography
	else:candidate.last_result="The review confirms class, equipment, trait, and %s aptitude."%_primary_stat(candidate.adventurer.class_id).to_upper()
	if not candidate.completed_interactions.has(interaction_id):candidate.completed_interactions.append(interaction_id)
	_add_calendar_event("assessment","%s is assessed at the Hearth."%candidate.adventurer.display_name);return {"ok":true,"duplicate":false,"result":candidate.last_result,"candidate":candidate}

func run_candidate_trial(candidate_id:String)->Dictionary:
	var candidate:=candidate_pool.get(candidate_id) as CandidateRecord
	if candidate==null:return {"ok":false,"error":"That adventurer is no longer at the Hearth."}
	if candidate.completed_interactions.has("trial"):return {"ok":true,"duplicate":true,"result":candidate.last_result,"candidate":candidate}
	var stat:=_trial_stat(candidate.adventurer.class_id);var value:=int(candidate.adventurer.attributes.get(stat,10));var rng:=_rng(candidate.quality_seed^0x54a17);var benchmark:=10+rng.randi_range(-1,1);var delta:=rng.randi_range(3,6) if value>=benchmark else -rng.randi_range(2,5);var applied:=maxi(-banked_gold,delta);banked_gold+=applied
	candidate.knowledge[stat]="exact" if value==benchmark else "band";candidate.completed_interactions.append("trial");candidate.last_result="%s: %s is %s the benchmark (%s%d gold)."%[_trial_name(candidate.adventurer.class_id),candidate.adventurer.display_name,"equal to" if value==benchmark else ("above" if value>benchmark else "below"),"+" if applied>=0 else "",applied]
	_add_calendar_event("assessment",candidate.last_result);return {"ok":true,"duplicate":false,"stat":stat,"value":value if value==benchmark else null,"comparison":signi(value-benchmark),"gold_change":applied,"result":candidate.last_result,"candidate":candidate}

func complete_candidate_contest(candidate_id:String,result:Dictionary)->Dictionary:
	var candidate:=candidate_pool.get(candidate_id) as CandidateRecord
	if candidate==null:return {"ok":false,"error":"That adventurer is no longer at the Hearth."}
	var contest_id:=String(result.get("contest_id",""))
	if not VisitorContestRules.CONTESTS.has(contest_id):return {"ok":false,"error":"Unknown contest."}
	if String(result.get("outcome","")) not in ["win","loss","draw"]:return {"ok":false,"error":"Invalid contest outcome."}
	var stat:=String(VisitorContestRules.CONTESTS[contest_id].stat)
	if String(candidate.knowledge.get(stat,"unknown"))!="exact":candidate.knowledge[stat]="band"
	candidate.adventurer.learning_potential_known=true
	candidate.contest_results[contest_id]={"contest_id":contest_id,"outcome":String(result.outcome),"player_score":maxi(0,int(result.get("player_score",0))),"visitor_score":maxi(0,int(result.get("visitor_score",0))),"details":Dictionary(result.get("details",{})).duplicate(true)}
	var interaction:="contest:%s"%contest_id
	var first:=not candidate.completed_interactions.has(interaction)
	if first:candidate.completed_interactions.append(interaction)
	candidate.last_result="%s · %s: You %d / Visitor %d. %s aptitude: %s. Learning potential: %s."%[VisitorContestRules.CONTESTS[contest_id].name,String(result.outcome).capitalize(),candidate.contest_results[contest_id].player_score,candidate.contest_results[contest_id].visitor_score,stat.to_upper(),VisitorContestRules.stat_analysis(int(candidate.adventurer.attributes.get(stat,10)),String(candidate.knowledge.get(stat,"unknown"))=="exact"),VisitorContestRules.learning_name(candidate.adventurer.learning_potential)]
	if first:_add_calendar_event("assessment","%s completes %s."%[candidate.adventurer.display_name,VisitorContestRules.CONTESTS[contest_id].name])
	return {"ok":true,"result":candidate.last_result}

func appraise_candidate(candidate_id:String,stat_id:String)->Dictionary:
	var candidate:=candidate_pool.get(candidate_id) as CandidateRecord
	if candidate==null:return {"ok":false,"error":"That adventurer is no longer at the Hearth."}
	if stat_id not in ATTRIBUTE_IDS:return {"ok":false,"error":"That attribute cannot be appraised."}
	if String(candidate.knowledge.get(stat_id,"unknown"))=="exact":return {"ok":false,"error":"That attribute is already known exactly."}
	if banked_gold<12:return {"ok":false,"error":"Exact appraisal costs 12 banked gold."}
	banked_gold-=12;candidate.knowledge[stat_id]="exact";candidate.appraisal_history.append(stat_id);candidate.completed_interactions.append("appraise:%s"%stat_id);candidate.last_result="The appraisal confirms %s %d."%[stat_id.to_upper(),int(candidate.adventurer.attributes.get(stat_id,10))];_add_calendar_event("assessment","%s receives a specialist appraisal."%candidate.adventurer.display_name);return {"ok":true,"stat":stat_id,"value":candidate.adventurer.attributes.get(stat_id,10),"cost":12,"result":candidate.last_result,"candidate":candidate}

func dismiss_character(character_id:String) -> Dictionary:
	var member:=character(character_id)
	if member==null or member.status!=CharacterRecord.STATUS_AVAILABLE:return {"ok":false,"error":"Only an available adventurer can be dismissed."}
	if not first_normal_launch_completed and first_company_ids.has(character_id):return {"ok":false,"error":"The founding recruits must complete the first expedition briefing."}
	HearthArmory.release(self,member)
	for id in member.provisions: consumable_stock[id] = int(consumable_stock.get(id,0))+1
	roster.erase(character_id);_add_calendar_event("departure","%s leaves the Hearth."%member.display_name)
	if living_roster().is_empty() and candidate_pool.is_empty():_generate_candidate_wave(false)
	return {"ok":true,"message":"%s leaves the Hearth."%member.display_name}

func launch_expedition(ids:Array[String],dungeon_id:String,patron_deity_id:String="",objective_id:String="") -> Dictionary:
	if expedition.active:return {"ok":false,"error":"An expedition is already active."}
	if GameBalance.get_dungeon(dungeon_id).is_empty():return {"ok":false,"error":"That dungeon does not exist."}
	if not RunState.dungeon_available(dungeon_id):return {"ok":false,"error":"That dungeon is unavailable."}
	var unique_ids:Dictionary={};for id in ids:unique_ids[id]=true
	if unique_ids.size()!=ids.size():return {"ok":false,"error":"A party cannot contain the same adventurer twice."}
	if not first_company_recruited:return {"ok":false,"error":"Recruit both Brina and Eamon before the first expedition."}
	if not patron_deity_id.is_empty() and DIVINE.deity(patron_deity_id).is_empty():return {"ok":false,"error":"That divine patron is unknown."}
	if not objective_id.is_empty() and not OBJECTIVES.objective_ids(dungeon_id).has(objective_id):return {"ok":false,"error":"That objective is unavailable here."}
	if not _begin_expedition_validated(ids,dungeon_id,false,patron_deity_id,objective_id):return {"ok":false,"error":"The selected party cannot enter that dungeon."}
	first_normal_launch_completed=true;tavern_phase=TAVERN_EXPEDITION
	return {"ok":true,"expedition_id":expedition.expedition_id}

func should_trigger_former_keeper_encounter(dungeon_id: String, outcome: String) -> bool:
	return is_tutorial_complete() and tutorial_outcome == "victory" and former_keeper_encounter_pending and not former_keeper_encounter_seen and dungeon_id == "forest" and outcome == "victory"

func mark_former_keeper_encounter_seen() -> void:
	former_keeper_encounter_pending = false
	former_keeper_encounter_seen = true

func get_party_cap(dungeon_id: String) -> int:
	return 2 if dungeon_id == "forest" else (4 if has_completed_dungeon("forest") else 2)

func has_completed_dungeon(dungeon_id: String) -> bool:
	return bool(completed_dungeons.get(dungeon_id, false))

func record_dungeon_clear(dungeon_id: String) -> Array[String]:
	var logs: Array[String] = []
	var first_clear := not completed_dungeons.has(dungeon_id)
	completed_dungeons[dungeon_id] = true
	var resolution_key:="objective_resolution:%s"%dungeon_id
	if not expedition.active or not expedition.rewarded_checkpoints.has(resolution_key):
		logs.append_array(OBJECTIVES.resolve(self,expedition,dungeon_id))
		if expedition.active:expedition.rewarded_checkpoints[resolution_key]=true
	if dungeon_id == "forest":
		logs.append_array(unlock_class("tank")); logs.append_array(unlock_class("rogue"))
	if dungeon_id == "ashen_farmstead": logs.append_array(unlock_class("healer")); clues["moonlit_farmstead"] = true
	if dungeon_id == "crypt": logs.append_array(unlock_class("summoner")); clues["abyssal_crypt"] = true
	if dungeon_id == "forest": clues["moonlit_forest"] = true
	if dungeon_id == "ember_foundry": clues["abyssal_foundry"] = true
	if first_clear and expedition.active:
		for reward_value in GameBalance.get_dungeon(dungeon_id).get("unique_rewards", []):
			var reward_id := String(reward_value)
			if not banked_relics.has(reward_id) and not expedition.carried_relics.has(reward_id): expedition.carried_relics.append(reward_id); logs.append("Recovered the unique relic: %s." % reward_id.replace("_", " ").capitalize())
	return logs

func unlock_class(class_id: String) -> Array[String]:
	class_id = GameBalance.normalize_class_id(class_id)
	if unlocked_classes.has(class_id): return []
	unlocked_classes.append(class_id); return ["%s recruits may now arrive at the tavern." % class_id.capitalize()]

func create_character(class_id: String = "") -> CharacterRecord:
	var character:=_generate_character(class_id);roster[character.id]=character;HearthArmory.ensure_starter(self,character);return character

func _generate_character(class_id:String="") -> CharacterRecord:
	var allowed := unlocked_classes if not unlocked_classes.is_empty() else ["warrior", "mage"]
	if class_id.is_empty() or not allowed.has(class_id): class_id = String(allowed[(next_character_number - 1) % allowed.size()])
	var seed:=7919+next_character_number*104729+candidate_wave_id*3571;var identity_rng:=_rng(seed^0x11d);var available:Array=[]
	var reserved_arrivals:=NATION_ARRIVALS.reserved_definition_ids()
	for value in ADVENTURERS.curated():if value is Dictionary and String(value.get("class",""))==class_id and not used_curated_ids.has(String(value.get("id",""))) and not reserved_arrivals.has(String(value.get("id",""))):available.append(value)
	var character:CharacterRecord
	if not available.is_empty():character=_character_from_definition(Dictionary(available[identity_rng.randi_range(0,available.size()-1)]))
	else:character=_generic_character(class_id,seed)
	if character.doctrine_id=="unaligned":character.doctrine_id=String(NarrativeContent.nation(character.nation_id).get("default_doctrine","unaligned"))
	var hidden_rng:=_rng(seed^0x4f1);var trait_pool:Array=ADVENTURERS.pool("traits");if hidden_rng.randf()<0.6 and trait_pool.size()>1:
		var hidden_id:=String(Dictionary(trait_pool[hidden_rng.randi_range(0,trait_pool.size()-1)]).get("id",""));if not hidden_id.is_empty() and hidden_id!=character.trait_id:character.hidden_traits.append(hidden_id)
	var band: Array = HearthCatalog.tier(establishment_tier).recruit_levels
	character.level = mini(20, int(band[0])+int(tavern_upgrades.replacement_quality) if establishment_tier == 0 else identity_rng.randi_range(int(band[0]),int(band[1]))+int(tavern_upgrades.replacement_quality))
	character.progression["level"] = character.level
	character.xp = int(GameBalance.get_progression().xp_thresholds[character.level])
	character.progression["xp"] = character.xp
	character.progression["total_xp"] = character.xp
	character.birth_day = calendar_day - identity_rng.randi_range(20,55)*112
	character.signing_fee = 8 + character.level*character.level*3
	var quality_rng:=_rng(seed^0x719);var quality:=clampi(roundi(quality_rng.randfn(35.0+6.0*int(tavern_upgrades.get("roster_services",0))+0.25*reputation,maxf(4.0,15.0-int(tavern_upgrades.get("roster_services",0))))),5,95);_apply_attributes(character,quality,seed)
	var class_data := GameBalance.get_base_class(class_id)
	var stats: Dictionary = character.attributes
	var health_rule: Dictionary = Dictionary(Dictionary(class_data.get("derived", {})).get("max_health", {}))
	var health := int(health_rule.get("base", 1)) + (character.level - 1) * int(health_rule.get("per_level", 0))
	var health_stat := String(health_rule.get("stat", ""))
	if not health_stat.is_empty():
		var modifier := int(floori(float(int(stats.get(health_stat, 10)) - 10) / 2.0)) + int(health_rule.get("stat_offset", 0))
		health += maxi(int(health_rule.get("min", -999)), modifier)
	character.max_health = maxi(1, health); character.current_health = character.max_health;character.gear_id=String(BASIC_GEAR.get(class_id,""))
	next_character_number += 1;return character

func _generate_candidate_wave(first_wave:bool=false) -> void:
	candidate_pool.clear();candidate_wave_id+=1
	var wave_rng := _rng(7919 + calendar_day * 104729 + candidate_wave_id * 3571 + calendar_shift)
	var count:=2 if first_wave else mini(7,wave_rng.randi_range(1,4)+int(tavern_upgrades.get("roster_services",0)))
	for index in count:
		var allowed:=unlocked_classes if not unlocked_classes.is_empty() else ["warrior","mage"]
		var class_id:=String(allowed[(candidate_wave_id+index-1)%allowed.size()])
		var member:=_generate_character(class_id)
		var motivation:=_candidate_motivation(member,index)
		var candidate:=CandidateRecord.create(member,calendar_day,candidate_wave_id,motivation,false);candidate.quality_seed=member.id.hash()^candidate_wave_id;candidate.quality_score=_quality_from_attributes(member);candidate_pool[member.id]=candidate
	_try_add_descendant()
	NATION_ARRIVALS.inject_next(self)
	_add_calendar_event("arrivals","%d new adventurers arrive at the Hearth."%count)
	tavern_phase=TAVERN_ARRIVALS

func _ensure_unrepresented_class_candidates() -> void:
	if candidate_wave_id<=1 or not has_completed_dungeon("forest"):return
	var represented:Dictionary={}
	for member in living_roster():represented[member.class_id]=true
	for candidate in get_candidates():represented[candidate.adventurer.class_id]=true
	for class_id in unlocked_classes:
		if represented.has(class_id):continue
		var member:=_generate_character(class_id)
		var candidate:=CandidateRecord.create(member,calendar_day,candidate_wave_id,_candidate_motivation(member,candidate_pool.size()),false)
		candidate.quality_seed=member.id.hash()^candidate_wave_id
		candidate.quality_score=_quality_from_attributes(member)
		candidate_pool[member.id]=candidate
		represented[class_id]=true
		tavern_phase=TAVERN_ARRIVALS
		_add_calendar_event("arrivals","%s arrives at the Hearth after the %s class becomes available."%[member.display_name,class_id.capitalize()])

func _candidate_motivation(member:CharacterRecord,index:int) -> String:
	var authored := ADVENTURERS.definition(member.definition_id)
	if not String(authored.get("motivation","")).is_empty(): return String(authored.motivation)
	return member.biography+" "+String(ADVENTURERS.pool("motives")[(calendar_day+candidate_wave_id+index)%ADVENTURERS.pool("motives").size()])

func _rng(seed:int)->RandomNumberGenerator:var rng:=RandomNumberGenerator.new();rng.seed=seed;return rng
func _character_from_definition(definition:Dictionary)->CharacterRecord:
	var trait_data:Dictionary=ADVENTURERS.trait_definition(String(definition.get("trait","stalwart")));var id:="hero_%06d"%next_character_number;var member:=CharacterRecord.create(id,String(definition.get("name","Adventurer")),String(definition.get("class","warrior")),trait_data,int(definition.get("portrait",0)))
	member.definition_id=String(definition.get("id",""));member.family_name=String(definition.get("family",""));member.pronouns=String(definition.get("pronouns","they/them"));member.origin=String(definition.get("origin","Unknown"));member.nation_id=String(definition.get("nation_id",ADVENTURERS.nation_for_definition(member.definition_id)));member.faith_id=String(definition.get("faith_id",ADVENTURERS.faith_for_definition(member.definition_id)));member.age_band=String(definition.get("age","Prime"));member.occupation=String(definition.get("occupation","Adventurer"));member.personality=String(definition.get("personality","Reserved"));member.preference=String(definition.get("preference","A fair contract"));member.biography=String(definition.get("biography","A traveler seeking work."));member.career_limit=clampi(int(definition.get("career",8))+int(trait_data.get("career",0)),6,10);member.lineage_id=id;member.arrival_year=get_calendar_date().year
	member.doctrine_id=String(definition.get("doctrine_id",ADVENTURERS.doctrine_for_definition(member.definition_id,member.nation_id)))
	if not member.definition_id.is_empty() and not used_curated_ids.has(member.definition_id):used_curated_ids.append(member.definition_id)
	return member
func _generic_character(class_id:String,seed:int)->CharacterRecord:
	var rng:=_rng(seed);var names:Array=ADVENTURERS.pool("names");var families:Array=ADVENTURERS.pool("family_names");var traits:Array=ADVENTURERS.pool("traits");var trait_data:Dictionary=traits[rng.randi_range(0,traits.size()-1)];var member:=CharacterRecord.create("hero_%06d"%next_character_number,String(names[rng.randi_range(0,names.size()-1)]),class_id,trait_data,rng.randi_range(0,3));member.family_name=String(families[rng.randi_range(0,families.size()-1)]);member.pronouns=String(ADVENTURERS.pool("pronouns")[rng.randi_range(0,ADVENTURERS.pool("pronouns").size()-1)]);member.origin=String(ADVENTURERS.pool("origins")[rng.randi_range(0,ADVENTURERS.pool("origins").size()-1)]);var nations:=ADVENTURERS.pool("nation_ids");member.nation_id=String(nations[rng.randi_range(0,nations.size()-1)]) if not nations.is_empty() else "crossroads";member.age_band=String(ADVENTURERS.pool("age_bands")[rng.randi_range(0,ADVENTURERS.pool("age_bands").size()-1)]);member.occupation=String(ADVENTURERS.pool("occupations")[rng.randi_range(0,ADVENTURERS.pool("occupations").size()-1)]);member.preference=String(ADVENTURERS.pool("preferences")[rng.randi_range(0,ADVENTURERS.pool("preferences").size()-1)]);member.personality="Practical, guarded, and accustomed to uncertain roads.";member.biography="A %s from %s. %s"%[member.occupation,member.origin,String(ADVENTURERS.pool("hooks")[rng.randi_range(0,ADVENTURERS.pool("hooks").size()-1)])];member.career_limit=clampi(rng.randi_range(6,10)+int(trait_data.get("career",0)),6,10);member.lineage_id=member.id;member.arrival_year=get_calendar_date().year;member.generation=member.arrival_year;return member
func _apply_attributes(member:CharacterRecord,quality:int,seed:int)->void:
	var base:=Dictionary(GameBalance.get_base_class(member.class_id).get("base_stats",{}));var rng:=_rng(seed^0x37f);var budget:=roundi((quality-35)/12.0);member.attributes={}
	for stat in ATTRIBUTE_IDS:member.attributes[stat]=clampi(int(base.get(stat,10))+rng.randi_range(-2,2),4,20)
	var primary:=_primary_stat(member.class_id);member.attributes[primary]=clampi(int(member.attributes[primary])+budget,4,20);member.progression["attributes"]=member.attributes.duplicate(true)
func _quality_from_attributes(member:CharacterRecord)->int:
	var base:=Dictionary(GameBalance.get_base_class(member.class_id).get("base_stats",{}));var delta:=0
	for stat in ATTRIBUTE_IDS:delta+=int(member.attributes.get(stat,10))-int(base.get(stat,10))
	return clampi(35+delta*4,5,95)
func _primary_stat(class_id:String)->String:return {"warrior":"str","tank":"con","rogue":"dex","mage":"int","healer":"wis","summoner":"wis"}.get(class_id,"str")
func _trial_stat(class_id:String)->String:return {"warrior":"str","tank":"con","rogue":"dex","mage":"int","healer":"wis","summoner":"cha"}.get(class_id,"str")
func _trial_name(class_id:String)->String:return {"warrior":"Arm-wrestling","tank":"Endurance","rogue":"Precision","mage":"Lore","healer":"Judgment","summoner":"Bond"}.get(class_id,"Aptitude")+" trial"
func _try_add_descendant()->void:
	for index in retired_heroes.size():
		var parent:Dictionary=retired_heroes[index];var parent_id:=String(parent.get("id",""));var state:Dictionary=Dictionary(lineage_registry.get(parent_id,{"retired_day":int(parent.get("retired_day",calendar_day)),"checks":int(parent.get("descendant_checks",0)),"descendant_created":bool(parent.get("descendant_created",false))}))
		if bool(state.get("descendant_created",false)) or calendar_day-int(state.get("retired_day",calendar_day))<112:continue
		var checks:=int(state.get("checks",0))+1;state.checks=checks;var rng:=_rng(parent_id.hash()^candidate_wave_id^0x5de5);var appears:=checks>=4 or rng.randf()<(0.35+0.15*(checks-1));lineage_registry[parent_id]=state;parent.descendant_checks=checks;retired_heroes[index]=parent
		if not appears:continue
		var parent_class:=String(parent.get("class_id","warrior"));var class_id:=parent_class if rng.randf()<0.55 else String(unlocked_classes[rng.randi_range(0,unlocked_classes.size()-1)]);var child:=_generic_character(class_id,parent_id.hash()+calendar_day*97);child.parent_id=parent_id;child.lineage_id=String(parent.get("lineage_id",parent_id));child.family_name=String(parent.get("family_name",parent.get("name","Vale")));child.generation=maxi(2,int(parent.get("generation",1))+1);child.biography="A descendant of %s, who served the Hearth before them. %s comes carrying family stories of %s."%[String(parent.get("name","a former hero")),child.display_name,String(parent.get("dungeon_id","the old roads")).replace("_"," ")];_apply_attributes(child,35,parent_id.hash()+calendar_day);child.gear_id=String(BASIC_GEAR.get(class_id,""));next_character_number+=1
		if candidate_pool.size()>=7:var ordinary:CandidateRecord=get_candidates().back();candidate_pool.erase(ordinary.id)
		var descendant:=CandidateRecord.create(child,calendar_day,candidate_wave_id,"I grew up hearing what the Hearth made possible. Now I want a story of my own.",false);descendant.quality_seed=child.id.hash()^candidate_wave_id;descendant.quality_score=_quality_from_attributes(child);candidate_pool[child.id]=descendant;state.descendant_created=true;lineage_registry[parent_id]=state;parent.descendant_created=true;retired_heroes[index]=parent;_add_calendar_event("lineage","%s %s, descendant of %s, arrives at the Hearth."%[child.display_name,child.family_name,String(parent.get("name","a former hero"))]);return

func _add_calendar_event(kind:String,text:String) -> void:
	calendar_history.append({"day":calendar_day,"shift":calendar_shift,"kind":kind,"text":text})
	while not calendar_history.is_empty() and int(calendar_history.front().get("day",1)) < calendar_day-CALENDAR_HISTORY_DAYS+1:
		calendar_history.pop_front()

func ensure_roster() -> void:
	if supplies <= 0: supplies = 8
	while living_roster().size() < TARGET_ROSTER_SIZE: create_character()

func living_roster() -> Array[CharacterRecord]:
	var result: Array[CharacterRecord] = []
	for value in roster.values():
		if value is CharacterRecord and value.status not in [CharacterRecord.STATUS_DEAD, CharacterRecord.STATUS_RETIRED]: result.append(value)
	result.sort_custom(func(a: CharacterRecord, b: CharacterRecord): return a.id < b.id)
	return result

func character(character_id: String) -> CharacterRecord:
	var value: Variant = roster.get(character_id, null); return value if value is CharacterRecord else null

func default_party(dungeon_id: String) -> Array[String]:
	var ids: Array[String] = []
	for member in living_roster():
		if member.status == CharacterRecord.STATUS_AVAILABLE: ids.append(member.id)
		if ids.size() >= get_party_cap(dungeon_id): break
	return ids

func begin_expedition(ids: Array[String], dungeon_id: String, is_tutorial: bool = false, patron_deity_id: String = "", objective_id: String = "") -> bool:
	return _begin_expedition_validated(ids,dungeon_id,is_tutorial,patron_deity_id,objective_id)

func _begin_expedition_validated(ids:Array[String],dungeon_id:String,is_tutorial:bool=false,patron_deity_id:String="",objective_id:String="") -> bool:
	if not is_tutorial:
		var check := HearthExpeditions.readiness(self,ids,dungeon_id)
		if not check.ok: return false
		supplies -= int(check.supplies)
	if ids.is_empty() or ids.size() > get_party_cap(dungeon_id): return false
	for character_id in ids:
		var member := character(character_id)
		if member == null or member.status != CharacterRecord.STATUS_AVAILABLE: return false
	for character_id in ids:
		var member := character(character_id); member.status = CharacterRecord.STATUS_EXPEDITION; member.expeditions += 1
	var run_id:=0
	if not is_tutorial:run_id=next_expedition_id;next_expedition_id+=1
	expedition.begin(ids,dungeon_id,is_tutorial,run_id,patron_deity_id,objective_id)
	expedition.departure_day = calendar_day
	expedition.departure_shift_index = HearthCalendar.shift_index(self)
	expedition.due_shift_index = expedition.departure_shift_index + 1
	expedition.due_day = 1 + int(expedition.due_shift_index / 2)
	for id in ids: expedition.locked_loadouts[id] = character(id).equipment.duplicate(true)
	return true

func record_casualty(character_id: String, cause: String = "Fell in the dungeon") -> void:
	var member := character(character_id)
	if member == null or member.status == CharacterRecord.STATUS_DEAD: return
	member.status = CharacterRecord.STATUS_DEAD; expedition.record_casualty(character_id)
	HearthArmory.release(self,member,true)
	var record:=member.to_dict();record.merge({"name":member.display_name,"cause":cause,"death_day":calendar_day,"epitaph":"%s of %s, remembered after %d expedition%s."%[member.display_name,member.origin,member.expeditions,"" if member.expeditions==1 else "s"]},true);memorial.append(record)
	if not expedition.tutorial_run:_add_calendar_event("death","%s dies during the expedition."%member.display_name)

func resolve_expedition(outcome: String) -> Array[String]:
	var result:=settle_expedition(expedition.expedition_id,outcome,{"legacy_resolve":true})
	var logs:Array[String]=[];logs.assign(result.get("logs",[]));return logs

func settle_expedition(run_id:int,outcome:String,result_data:Dictionary={}) -> Dictionary:
	if settled_expeditions.has(str(run_id)): return {"ok":true,"duplicate":true,"logs":[]}
	if not expedition.tutorial_run:
		if expedition.expedition_id != run_id: return {"ok":false,"error":"Expedition ID does not match.","logs":[]}
		return HearthExpeditions.settle(self,expedition,outcome,result_data)
	if outcome not in ["victory","death"]:return {"ok":false,"error":"Expeditions resolve only through boss victory or total defeat.","logs":[]}
	if run_id>0 and run_id==last_settled_expedition_id:return {"ok":true,"duplicate":true,"logs":[]}
	if not expedition.active:return {"ok":false,"error":"No expedition is active.","logs":[]}
	if expedition.expedition_id!=run_id:return {"ok":false,"error":"The expedition ID does not match.","logs":[]}
	var tutorial_run:=expedition.tutorial_run;var party:=expedition.party_ids.duplicate();var dungeon_id:=expedition.dungeon_id;var resolved_depth:=expedition.floor;var logs:Array[String]=[];var retired_names:Array[String]=[];var returned_names:Array[String]=[]
	if outcome=="victory":
		banked_gold+=expedition.carried_gold;relic_essence+=expedition.carried_relic_essence;lifetime_relic_essence+=expedition.carried_relic_essence
		for relic_id in expedition.carried_relics:
			if not banked_relics.has(relic_id):banked_relics.append(relic_id)
		logs.append("Banked %d gold and %d relic essence."%[expedition.carried_gold,expedition.carried_relic_essence])
		if not expedition.carried_relics.is_empty():logs.append("Banked relics: %s."%", ".join(expedition.carried_relics))
	contribution+=expedition.carried_contribution
	for character_id in party:
		var member:=character(character_id)
		if member==null or member.status==CharacterRecord.STATUS_DEAD:continue
		if tutorial_run:member.status=CharacterRecord.STATUS_AVAILABLE
		elif outcome=="victory":
			member.victories+=1;successful_levels+=member.level;member.accomplishments.append("Cleared %s on Day %d."%[dungeon_id.capitalize(),calendar_day+7]);member.personal_history.append({"day":calendar_day+7,"kind":"victory","dungeon":dungeon_id})
			if member.expeditions>=member.career_limit:
				member.status=CharacterRecord.STATUS_RETIRED;var record:=member.to_dict();record.merge({"name":member.display_name,"retired_day":calendar_day+7,"dungeon_id":dungeon_id,"descendant_checks":0,"descendant_created":false},true);retired_heroes.append(record);lineage_registry[member.id]={"retired_day":calendar_day+7,"checks":0,"descendant_created":false};roster.erase(member.id);retired_names.append(member.display_name);logs.append("%s completes a storied career and retires."%member.display_name)
			else:member.status=CharacterRecord.STATUS_AVAILABLE;returned_names.append(member.display_name);logs.append("%s returns to the Hearth (%d/%d expeditions)."%[member.display_name,member.expeditions,member.career_limit])
		else:
			record_casualty(member.id, String(result_data.get("headline", "Lost with the expedition")))
	COMPATIBILITY.record_shared_outcome(self,expedition.living_party_ids(),outcome)
	if outcome=="victory":
		var represented_nations:Dictionary={}
		for id in expedition.living_party_ids():
			var survivor:=character(id)
			if survivor!=null:represented_nations[survivor.nation_id]=true
		for nation_id in represented_nations:faction_standing[nation_id]=int(faction_standing.get(nation_id,0))+1
	if run_id>0:last_settled_expedition_id=run_id
	expedition=ExpeditionState.new()
	if not tutorial_run:
		calendar_day+=7;ECOLOGY.advance_to_day(self,calendar_day);if outcome=="victory":reputation=clampi(reputation+2+party.size(),0,100)
		_add_calendar_event("victory" if outcome=="victory" else "defeat",String(result_data.get("headline","The expedition returns victorious." if outcome=="victory" else "The expedition is lost.")))
		for returned_name in returned_names:_add_calendar_event("return","%s returns for another season at the Hearth."%returned_name)
		for retired_name in retired_names:_add_calendar_event("retirement","%s enters the Hall of Heroes."%retired_name)
		_generate_candidate_wave(false)
	else:tavern_phase=TAVERN_STORY
	pending_settlement_summary={"outcome":outcome,"headline":String(result_data.get("headline","Expedition resolved.")),"dungeon":dungeon_id,"depth":resolved_depth,"gold":banked_gold if outcome=="victory" else 0}
	return {"ok":true,"duplicate":false,"logs":logs,"wave_id":candidate_wave_id,"calendar":get_calendar_date()}

func can_unlock_secret(secret_id: String) -> bool:
	if int(tavern_upgrades.get("secret_research", 0)) < 1: return false
	if secret_id == "moonlit_grove": return bool(clues.get("moonlit_forest", false)) and bool(clues.get("moonlit_farmstead", false))
	if secret_id == "abyssal_archive": return bool(clues.get("abyssal_crypt", false)) and bool(clues.get("abyssal_foundry", false))
	return false

func upgrade_cost(branch: String) -> Dictionary:
	return HearthFacilities.quote(self,branch)

func purchase_upgrade(branch: String) -> Array[String]:
	if not tavern_upgrades.has(branch): return ["Unknown tavern upgrade."]
	if branch == "recovery" and int(tavern_upgrades.recovery) >= 1: return ["Maximum recovery rank reached."]
	var rank := int(tavern_upgrades.get(branch,0))+1
	var gold_cost := 20*rank
	var essence_cost := 5*rank
	if banked_gold < gold_cost or relic_essence < essence_cost: return ["The company lacks the gold or relic essence for that upgrade."]
	banked_gold -= gold_cost; relic_essence -= essence_cost; tavern_upgrades[branch]=rank
	return ["%s reaches rank %d." % [branch.replace("_"," ").capitalize(),rank]]

func to_dict() -> Dictionary:
	var encoded_roster: Array[Dictionary] = []
	for value in roster.values(): if value is CharacterRecord: encoded_roster.append(value.to_dict())
	var encoded_candidates:Array[Dictionary]=[]
	for value in candidate_pool.values():if value is CandidateRecord:encoded_candidates.append(value.to_dict())
	return {"ending_state":ending_state.duplicate(true),"world_crisis":world_crisis.duplicate(true),"active_boons":active_boons.duplicate(true),"divine_obligations":divine_obligations.duplicate(true),"dungeon_ecology":dungeon_ecology.duplicate(true),"armory":armory.duplicate(true),"next_item_id":next_item_id,"establishment_tier":establishment_tier,"construction":construction.duplicate(true),"dispatches":dispatches.duplicate(true),"settled_expeditions":settled_expeditions.duplicate(true),"return_reports":return_reports.duplicate(true),"market_stock":market_stock.duplicate(true),"consumable_stock":consumable_stock.duplicate(true),"version":SAVE_VERSION,"save_slot":save_slot,"last_saved_unix":last_saved_unix,"tutorial_phase":tutorial_phase,"tutorial_outcome":tutorial_outcome,"tutorial_history":tutorial_history.duplicate(true),"tutorial_keepsake_id":tutorial_keepsake_id,"tutorial_letter_unlocked":tutorial_letter_unlocked,"keeper_journal_unlocked":keeper_journal_unlocked,"contribution":contribution,"faction_standing":faction_standing.duplicate(true),"divine_favor":divine_favor.duplicate(true),"story_event_history":story_event_history.duplicate(true),"keeper_memory":keeper_memory.duplicate(true),"post_tutorial_initialized":post_tutorial_initialized,"former_keeper_encounter_pending":former_keeper_encounter_pending,"former_keeper_encounter_seen":former_keeper_encounter_seen,"calendar_day":calendar_day,"calendar_shift":calendar_shift,"period_elapsed_shifts":period_elapsed_shifts,"period_completed_runs":period_completed_runs,"tavern_phase":tavern_phase,"candidate_wave_id":candidate_wave_id,"candidate_pool":encoded_candidates,"last_presented_wave_id":last_presented_wave_id,"calendar_history":calendar_history.duplicate(true),"retired_heroes":retired_heroes.duplicate(true),"first_company_ids":first_company_ids.duplicate(),"first_company_recruited":first_company_recruited,"first_normal_launch_completed":first_normal_launch_completed,"next_expedition_id":next_expedition_id,"last_settled_expedition_id":last_settled_expedition_id,"pending_settlement_summary":pending_settlement_summary.duplicate(true),"pending_story_context":pending_story_context,"pending_story_event_id":pending_story_event_id,"roster":encoded_roster,"memorial":memorial.duplicate(true),"unlocked_classes":unlocked_classes.duplicate(),"completed_dungeons":completed_dungeons.duplicate(true),"banked_gold":banked_gold,"supplies":supplies,"relic_essence":relic_essence,"lifetime_relic_essence":lifetime_relic_essence,"banked_relics":banked_relics.duplicate(),"successful_levels":successful_levels,"tavern_upgrades":tavern_upgrades.duplicate(true),"tavern_dialogue_flags":tavern_dialogue_flags.duplicate(true),"clues":clues.duplicate(true),"next_character_number":next_character_number,"expedition":expedition.to_dict(),"legacy_runtime":legacy_runtime.duplicate(true),"reputation":reputation,"used_curated_ids":used_curated_ids.duplicate(),"lineage_registry":lineage_registry.duplicate(true)}

func save_atomic() -> bool:
	last_save_error = "";save_slot=clampi(save_slot,1,SAVE_SLOT_COUNT);last_saved_unix=int(Time.get_unix_time_from_system());var temporary:=temp_save_path(save_slot);var destination:=save_path(save_slot);var backup:=backup_save_path(save_slot);var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: last_save_error = "Unable to open temporary campaign save."; return false
	file.store_string(JSON.stringify(to_dict(), "  ")); file.flush(); file.close()
	var absolute_temp := ProjectSettings.globalize_path(temporary); var absolute_save := ProjectSettings.globalize_path(destination);var absolute_backup:=ProjectSettings.globalize_path(backup)
	if FileAccess.file_exists(backup):DirAccess.remove_absolute(absolute_backup)
	if FileAccess.file_exists(destination):
		var backup_result:=DirAccess.rename_absolute(absolute_save,absolute_backup)
		if backup_result!=OK:last_save_error="Unable to preserve the previous campaign save (%d)."%backup_result;return false
	var result := DirAccess.rename_absolute(absolute_temp, absolute_save)
	if result != OK:
		if FileAccess.file_exists(backup):DirAccess.rename_absolute(absolute_backup,absolute_save)
		last_save_error = "Unable to commit campaign save (%d); the previous save was restored." % result; return false
	return true

static func load_or_new(slot:int=1) -> CampaignState:
	slot=clampi(slot,1,SAVE_SLOT_COUNT);var campaign := CampaignState.new();campaign.save_slot=slot
	var destination:=save_path(slot);var backup:=backup_save_path(slot);var parsed:=_read_save_dictionary(destination);var imported_legacy:=false
	if parsed.is_empty() and FileAccess.file_exists(backup):parsed=_read_save_dictionary(backup);campaign.last_save_error="The latest slot save was invalid; its previous backup was recovered."
	if parsed.is_empty() and slot==1:
		parsed=_read_save_dictionary(LEGACY_SAVE_PATH)
		if parsed.is_empty():parsed=_read_save_dictionary(LEGACY_BACKUP_SAVE_PATH)
		imported_legacy=not parsed.is_empty()
	if parsed.is_empty():
		if FileAccess.file_exists(destination):campaign.last_save_error="Slot save was invalid; a recoverable new campaign was created."
		return campaign
	var version:=int(parsed.get("version",0))
	if version>SAVE_VERSION:
		campaign.last_save_error="Campaign save is from a newer unsupported version; a recoverable new campaign was created."
		return campaign
	var migrated:=_migrate_dict(parsed)
	campaign._load_dict(migrated)
	campaign.save_slot=slot
	var ended_removed_mode_run:=_settle_removed_mode_run(campaign,migrated)
	if ended_removed_mode_run:campaign.save_atomic()
	if campaign.is_tutorial_complete() and not campaign.expedition.active:campaign.ensure_tavern_cycle()
	if imported_legacy:campaign.last_save_error="The previous single campaign was imported into Save Slot 1.";campaign.save_atomic()
	return campaign

static func _settle_removed_mode_run(campaign:CampaignState,migrated:Dictionary)->bool:
	if not bool(migrated.get("_settle_removed_mode_run",false)) or campaign==null or not campaign.expedition.active:return false
	campaign.settle_expedition(campaign.expedition.expedition_id,"death",{"headline":"The expedition was lost when its combat system was retired."})
	return true

static func _read_save_dictionary(path:String)->Dictionary:
	if not FileAccess.file_exists(path):return {}
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:return {}
	var parsed:Variant=JSON.parse_string(file.get_as_text());return Dictionary(parsed) if parsed is Dictionary else {}

static func _migrate_dict(source:Dictionary)->Dictionary:
	var data:=source.duplicate(true);var version:=int(data.get("version",0))
	if version<=0:
		if bool(data.get("forest_cleared",false)):data["completed_dungeon_modes"]={"forest":["strategy"]};data["tutorial_phase"]=TUTORIAL_COMPLETE
		if data.has("selected_class_id"):data["unlocked_classes"]=["warrior","mage"]
		data["legacy_runtime"]={"completed_dungeons":Dictionary(data.get("completed_dungeons",data.get("completed_dungeon_modes",{}))).duplicate(true),"forest_cleared":bool(data.get("forest_cleared",false)),"completed_runs":int(data.get("completed_runs",0)),"deaths":int(data.get("deaths",0))}
	if version<=1:data["banked_relics"]=Array(data.get("banked_relics",[]))
	if version<=2:data["save_slot"]=int(data.get("save_slot",1));data["last_saved_unix"]=int(data.get("last_saved_unix",0))
	if version<=3:
		data["supplies"]=int(data.get("supplies",0));data["tutorial_outcome"]=String(data.get("tutorial_outcome",""));data["tutorial_history"]=Dictionary(data.get("tutorial_history",{})).duplicate(true);data["tutorial_keepsake_id"]=String(data.get("tutorial_keepsake_id",""));data["tutorial_letter_unlocked"]=bool(data.get("tutorial_letter_unlocked",false));data["post_tutorial_initialized"]=bool(data.get("post_tutorial_initialized",String(data.get("tutorial_phase",TUTORIAL_NEW))==TUTORIAL_COMPLETE));data["former_keeper_encounter_pending"]=bool(data.get("former_keeper_encounter_pending",false));data["former_keeper_encounter_seen"]=bool(data.get("former_keeper_encounter_seen",false))
	if version<=4:
		data["calendar_day"]=maxi(1,int(data.get("calendar_day",1)));data["tavern_phase"]=String(data.get("tavern_phase",TAVERN_OPEN));data["candidate_wave_id"]=int(data.get("candidate_wave_id",0));data["candidate_pool"]=Array(data.get("candidate_pool",[]));data["last_presented_wave_id"]=int(data.get("last_presented_wave_id",0));data["calendar_history"]=Array(data.get("calendar_history",[]));data["retired_heroes"]=Array(data.get("retired_heroes",[]));data["first_company_ids"]=Array(data.get("first_company_ids",[]));data["first_company_recruited"]=bool(data.get("first_company_recruited",true));data["first_normal_launch_completed"]=bool(data.get("first_normal_launch_completed",true));data["next_expedition_id"]=maxi(1,int(data.get("next_expedition_id",1)));data["last_settled_expedition_id"]=maxi(0,int(data.get("last_settled_expedition_id",0)));
		var old_roster:Array=Array(data.get("roster",[]));var names:Array[String]=[]
		for record in old_roster:if record is Dictionary:names.append(String(record.get("display_name","")))
		data["_convert_first_company_candidates"]=String(data.get("tutorial_phase",TUTORIAL_NEW))==TUTORIAL_COMPLETE and Dictionary(data.get("completed_dungeons",data.get("completed_dungeon_modes",{}))).is_empty() and old_roster.size()==2 and names.has("Brina") and names.has("Eamon")
	if version<=5:data["reputation"]=int(data.get("reputation",0));data["used_curated_ids"]=Array(data.get("used_curated_ids",[]));data["lineage_registry"]=Dictionary(data.get("lineage_registry",{})).duplicate(true)
	if version<=6:data["tavern_dialogue_flags"]=Dictionary(data.get("tavern_dialogue_flags",{})).duplicate(true)
	if version<=9:
		data["keeper_journal_unlocked"]=bool(data.get("keeper_journal_unlocked",false));data["contribution"]=maxi(0,int(data.get("contribution",0)));data["faction_standing"]=Dictionary(data.get("faction_standing",{})).duplicate(true);data["divine_favor"]=Dictionary(data.get("divine_favor",{})).duplicate(true);data["story_event_history"]=Dictionary(data.get("story_event_history",{})).duplicate(true);data["keeper_memory"]=Dictionary(data.get("keeper_memory",{"loop_number":0,"discoveries":[],"remembered_people":[]})).duplicate(true)
		# The former-owner confrontation is retired by the Keeper-centered story. Preserve fields for compatibility, but never leave the event pending.
		data["former_keeper_encounter_pending"]=false
	if version<=10:data["dungeon_ecology"]=Dictionary(data.get("dungeon_ecology",{})).duplicate(true)
	if version<=11:data["active_boons"]=Dictionary(data.get("active_boons",{})).duplicate(true);data["divine_obligations"]=Array(data.get("divine_obligations",[])).duplicate(true)
	if version<=12:data["world_crisis"]=Dictionary(data.get("world_crisis",{})).duplicate(true)
	if version<=13:data["ending_state"]=Dictionary(data.get("ending_state",{})).duplicate(true)
	if version<=15:
		data["calendar_shift"]=0
		data["period_elapsed_shifts"]=0
		data["period_completed_runs"]=0
	if version<=14:data["pending_story_event_id"]=String(data.get("pending_story_event_id",""))
	# Convert legacy per-mode clears to the mode-free completion map and flag runs the removed runtime cannot resume.
	var old_completions:Dictionary=Dictionary(data.get("completed_dungeon_modes",{}))
	var completions:Dictionary=Dictionary(data.get("completed_dungeons",{})).duplicate(true)
	for dungeon_id in old_completions:
		var prior:Variant=old_completions[dungeon_id]
		if (prior is Array and not prior.is_empty()) or bool(prior): completions[String(dungeon_id)]=true
	data["completed_dungeons"]=completions
	data.erase("completed_dungeon_modes")
	var expedition_data:Dictionary=Dictionary(data.get("expedition",{})).duplicate(true)
	var saved_mode:String=String(expedition_data.get("play_mode","slasher"))
	data["_settle_removed_mode_run"]=bool(expedition_data.get("active",false)) and saved_mode!="slasher"
	expedition_data.erase("play_mode")
	var runtime:Dictionary=Dictionary(expedition_data.get("member_runtime",{})).duplicate(true)
	for character_id in runtime:
		var member_runtime:Dictionary=Dictionary(runtime[character_id]).duplicate(true)
		member_runtime.erase("strategy_turn")
		runtime[character_id]=member_runtime
	expedition_data["member_runtime"]=runtime
	data["expedition"]=expedition_data
	var classes:Array=[];classes.assign(data.get("unlocked_classes",["warrior","mage"]))
	for i in range(classes.size()):if String(classes[i])=="phantom":classes[i]="rogue"
	data["unlocked_classes"]=classes;data["version"]=SAVE_VERSION;return data

func _load_dict(data: Dictionary) -> void:
	ending_state=Dictionary(data.get("ending_state",{})).duplicate(true)
	active_boons=Dictionary(data.get("active_boons",{})).duplicate(true);divine_obligations.assign(data.get("divine_obligations",[]))
	world_crisis=Dictionary(data.get("world_crisis",{})).duplicate(true)
	dungeon_ecology=Dictionary(data.get("dungeon_ecology",{})).duplicate(true)
	armory = Dictionary(data.get("armory",{})).duplicate(true)
	next_item_id = data.get("next_item_id",1)
	establishment_tier = data.get("establishment_tier",0)
	construction = Dictionary(data.get("construction",{})).duplicate(true)
	dispatches = Dictionary(data.get("dispatches",{})).duplicate(true)
	settled_expeditions = Dictionary(data.get("settled_expeditions",{})).duplicate(true)
	return_reports = Array(data.get("return_reports",[])).duplicate(true)
	market_stock = Dictionary(data.get("market_stock",{})).duplicate(true)
	consumable_stock = Dictionary(data.get("consumable_stock",{})).duplicate(true)
	save_slot=clampi(int(data.get("save_slot",save_slot)),1,SAVE_SLOT_COUNT);last_saved_unix=maxi(0,int(data.get("last_saved_unix",0)))
	tutorial_phase = String(data.get("tutorial_phase", TUTORIAL_NEW)); tutorial_outcome = String(data.get("tutorial_outcome", "")); tutorial_history = Dictionary(data.get("tutorial_history", {})).duplicate(true); tutorial_keepsake_id = String(data.get("tutorial_keepsake_id", "")); tutorial_letter_unlocked = bool(data.get("tutorial_letter_unlocked", false)); keeper_journal_unlocked=bool(data.get("keeper_journal_unlocked",false)); contribution=maxi(0,int(data.get("contribution",0))); faction_standing=Dictionary(data.get("faction_standing",{})).duplicate(true); divine_favor=Dictionary(data.get("divine_favor",{})).duplicate(true); story_event_history=Dictionary(data.get("story_event_history",{})).duplicate(true); keeper_memory=Dictionary(data.get("keeper_memory",{"loop_number":0,"discoveries":[],"remembered_people":[]})).duplicate(true); post_tutorial_initialized = bool(data.get("post_tutorial_initialized", tutorial_phase == TUTORIAL_COMPLETE)); former_keeper_encounter_pending = false; former_keeper_encounter_seen = bool(data.get("former_keeper_encounter_seen", false)); memorial.assign(data.get("memorial", [])); unlocked_classes.assign(data.get("unlocked_classes", ["warrior","mage"]))
	completed_dungeons = Dictionary(data.get("completed_dungeons", {})).duplicate(true); banked_gold = maxi(0, int(data.get("banked_gold", 0))); supplies = maxi(0, int(data.get("supplies", 0))); relic_essence = maxi(0, int(data.get("relic_essence", 0))); lifetime_relic_essence = maxi(relic_essence, int(data.get("lifetime_relic_essence", relic_essence))); successful_levels = maxi(0, int(data.get("successful_levels", 0)))
	banked_relics.assign(data.get("banked_relics", []))
	tavern_upgrades.merge(Dictionary(data.get("tavern_upgrades", {})), true); tavern_dialogue_flags = Dictionary(data.get("tavern_dialogue_flags", {})).duplicate(true); clues = Dictionary(data.get("clues", {})).duplicate(true); next_character_number = maxi(1, int(data.get("next_character_number", 1)))
	roster.clear()
	for value in data.get("roster", []):
		if value is Dictionary:
			var member := CharacterRecord.from_dict(value)
			if not member.id.is_empty(): roster[member.id] = member
	if has_completed_dungeon("forest"):
		unlock_class("tank"); unlock_class("rogue")
	expedition = ExpeditionState.from_dict(Dictionary(data.get("expedition", {})))
	legacy_runtime = Dictionary(data.get("legacy_runtime", {})).duplicate(true)
	calendar_shift=clampi(int(data.get("calendar_shift",0)),0,1)
	period_elapsed_shifts=maxi(0,int(data.get("period_elapsed_shifts",0)))
	period_completed_runs=maxi(0,int(data.get("period_completed_runs",0)))
	calendar_day=maxi(1,int(data.get("calendar_day",1)));tavern_phase=String(data.get("tavern_phase",TAVERN_OPEN));candidate_wave_id=maxi(0,int(data.get("candidate_wave_id",0)));last_presented_wave_id=maxi(0,int(data.get("last_presented_wave_id",0)));calendar_history.assign(data.get("calendar_history",[]));retired_heroes.assign(data.get("retired_heroes",[]));first_company_ids.assign(data.get("first_company_ids",[]));first_company_recruited=bool(data.get("first_company_recruited",true));first_normal_launch_completed=bool(data.get("first_normal_launch_completed",true));next_expedition_id=maxi(1,int(data.get("next_expedition_id",1)));last_settled_expedition_id=maxi(0,int(data.get("last_settled_expedition_id",0)))
	pending_settlement_summary=Dictionary(data.get("pending_settlement_summary",{})).duplicate(true);pending_story_context=String(data.get("pending_story_context",""));pending_story_event_id=String(data.get("pending_story_event_id",""))
	reputation=clampi(int(data.get("reputation",0)),0,100);used_curated_ids.assign(data.get("used_curated_ids",[]));lineage_registry=Dictionary(data.get("lineage_registry",{})).duplicate(true)
	candidate_pool.clear()
	for value in data.get("candidate_pool",[]):
		if value is Dictionary:
			var candidate:=CandidateRecord.from_dict(value)
			if not candidate.id.is_empty():candidate_pool[candidate.id]=candidate
	for member in living_roster():if not member.definition_id.is_empty() and not used_curated_ids.has(member.definition_id):used_curated_ids.append(member.definition_id)
	for candidate in get_candidates():if not candidate.adventurer.definition_id.is_empty() and not used_curated_ids.has(candidate.adventurer.definition_id):used_curated_ids.append(candidate.adventurer.definition_id)
	for index in retired_heroes.size():
		var retired:Dictionary=retired_heroes[index];retired["generation"]=maxi(1,int(retired.get("generation",1)));retired["family_name"]=String(retired.get("family_name",""));retired["descendant_checks"]=maxi(0,int(retired.get("descendant_checks",0)));retired["descendant_created"]=bool(retired.get("descendant_created",false));retired_heroes[index]=retired
	if bool(data.get("_convert_first_company_candidates",false)):_convert_legacy_first_company()
	if not data.has("establishment_tier"): establishment_tier = clampi(int(tavern_upgrades.roster_services),0,3)
	for key in tavern_upgrades: tavern_upgrades[key] = clampi(int(tavern_upgrades[key]),0,3)
	if not data.has("armory"):
		for member in living_roster(): HearthArmory.ensure_starter(self,member)
	if expedition.active and not data.has("dispatches"):
		expedition.departure_day = calendar_day
		expedition.due_day = calendar_day+7
	HearthMigration.upgrade(self,data)
	ECOLOGY.ensure(self);ECOLOGY.advance_to_day(self,calendar_day);CRISIS.ensure(self)

func _convert_legacy_first_company() -> void:
	if roster.size()!=2:return
	candidate_wave_id=1;first_company_ids.clear();candidate_pool.clear()
	for member in living_roster():
		first_company_ids.append(member.id);candidate_pool[member.id]=CandidateRecord.create(member,calendar_day,candidate_wave_id,"I came to the Hearth for the first company expedition.",true)
	roster.clear();first_company_recruited=false;first_normal_launch_completed=false;last_presented_wave_id=0;tavern_phase=TAVERN_ARRIVALS
