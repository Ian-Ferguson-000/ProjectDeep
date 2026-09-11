extends RefCounted
class_name CampaignState

const SAVE_VERSION := 7
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
var completed_dungeon_modes: Dictionary = {}
var banked_gold: int = 0
var supplies: int = 0
var relic_essence: int = 0
var lifetime_relic_essence: int = 0
var banked_relics: Array[String] = []
var successful_levels: int = 0
var tavern_upgrades: Dictionary = {"roster_services":0,"starting_supplies":0,"item_rarity":0,"merchant_stock":0,"relic_capacity":0,"secret_research":0,"replacement_quality":0}
var tavern_dialogue_flags: Dictionary = {}
var clues: Dictionary = {}
var tutorial_outcome: String = ""
var tutorial_history: Dictionary = {}
var tutorial_keepsake_id: String = ""
var tutorial_letter_unlocked: bool = false
var post_tutorial_initialized: bool = false
var former_keeper_encounter_pending: bool = false
var former_keeper_encounter_seen: bool = false
var calendar_day: int = 1
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
var next_character_number: int = 1
var expedition := ExpeditionState.new()
var legacy_runtime: Dictionary = {}
var last_save_error: String = ""
var save_slot: int = 1
var last_saved_unix: int = 0
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
	return {"slot":slot,"exists":true,"recoverable":true,"recovered":recovered,"tutorial_phase":String(data.get("tutorial_phase",TUTORIAL_NEW)),"roster_count":living,"completed_dungeons":Dictionary(data.get("completed_dungeon_modes",{})).size(),"banked_gold":int(data.get("banked_gold",0)),"last_saved_unix":int(data.get("last_saved_unix",0))}

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
	alden.gear_id = "sword_shield"
	roster[alden.id] = alden
	return alden

func restart_tutorial_expedition() -> CharacterRecord:
	if not expedition.tutorial_run: return null
	var restart_count := expedition.tutorial_restart_count + 1
	var alden := create_tutorial_adventurer()
	alden.status = CharacterRecord.STATUS_EXPEDITION
	alden.max_health = TUTORIAL_STARTING_HEALTH
	alden.current_health = TUTORIAL_STARTING_HEALTH
	expedition.begin([alden.id], "forest", "slasher", true, expedition.expedition_id)
	expedition.tutorial_restart_count = restart_count
	return alden

func apply_post_tutorial_state(outcome: String) -> void:
	if post_tutorial_initialized: return
	outcome = "victory" if outcome == "victory" else "death"
	tutorial_outcome = outcome
	tutorial_history = {"adventurer":"Alden","class_id":"warrior","outcome":"retired" if outcome == "victory" else "memorialized"}
	tutorial_keepsake_id = "briarway_deed_seal" if outcome == "victory" else "aldens_mourning_ribbon"
	tutorial_letter_unlocked = true
	former_keeper_encounter_pending = outcome == "victory"
	former_keeper_encounter_seen = false
	banked_gold = 120
	supplies = 8
	relic_essence = 0
	lifetime_relic_essence = 0
	banked_relics.clear()
	successful_levels = 0
	completed_dungeon_modes.clear()
	reputation=0;used_curated_ids.clear();lineage_registry.clear()
	clues.clear()
	unlocked_classes = ["warrior", "mage"]
	tavern_upgrades = {"roster_services":0,"starting_supplies":0,"item_rarity":0,"merchant_stock":0,"relic_capacity":0,"secret_research":0,"replacement_quality":0}
	tavern_dialogue_flags.clear()
	roster.clear()
	next_character_number = 1
	candidate_pool.clear()
	candidate_wave_id = 1
	calendar_day = 1
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
	return BASE_ROSTER_CAPACITY + 2 * maxi(0, int(tavern_upgrades.get("roster_services", 0)))

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
	var member:=candidate.adventurer;member.status=CharacterRecord.STATUS_AVAILABLE;roster[member.id]=member;candidate_pool.erase(candidate_id)
	first_company_recruited=first_company_ids.all(func(id:String):return roster.has(id))
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
	roster.erase(character_id);_add_calendar_event("departure","%s leaves the Hearth."%member.display_name)
	if living_roster().is_empty() and candidate_pool.is_empty():_generate_candidate_wave(false)
	return {"ok":true,"message":"%s leaves the Hearth."%member.display_name}

func launch_expedition(ids:Array[String],dungeon_id:String,mode:String) -> Dictionary:
	if expedition.active:return {"ok":false,"error":"An expedition is already active."}
	if GameBalance.get_dungeon(dungeon_id).is_empty():return {"ok":false,"error":"That dungeon does not exist."}
	if mode not in ["strategy","slasher"] or not Array(GameBalance.get_dungeon(dungeon_id).get("supported_modes",[])).has(mode):return {"ok":false,"error":"That combat mode is unavailable for this dungeon."}
	var unique_ids:Dictionary={};for id in ids:unique_ids[id]=true
	if unique_ids.size()!=ids.size():return {"ok":false,"error":"A party cannot contain the same adventurer twice."}
	if not first_company_recruited:return {"ok":false,"error":"Recruit both Brina and Eamon before the first expedition."}
	if not _begin_expedition_validated(ids,dungeon_id,mode,false):return {"ok":false,"error":"The selected party cannot enter that dungeon."}
	for candidate in get_candidates():_add_calendar_event("departure","%s leaves with the morning crowd."%candidate.adventurer.display_name)
	candidate_pool.clear();first_normal_launch_completed=true;tavern_phase=TAVERN_EXPEDITION
	return {"ok":true,"expedition_id":expedition.expedition_id}

func should_trigger_former_keeper_encounter(dungeon_id: String, outcome: String) -> bool:
	return is_tutorial_complete() and tutorial_outcome == "victory" and former_keeper_encounter_pending and not former_keeper_encounter_seen and dungeon_id == "forest" and outcome == "victory"

func mark_former_keeper_encounter_seen() -> void:
	former_keeper_encounter_pending = false
	former_keeper_encounter_seen = true

func get_party_cap(dungeon_id: String) -> int:
	return 2 if dungeon_id == "forest" else (4 if has_completed_dungeon("forest") else 2)

func has_completed_dungeon(dungeon_id: String) -> bool:
	return not Array(completed_dungeon_modes.get(dungeon_id, [])).is_empty()

func record_dungeon_clear(dungeon_id: String, mode: String) -> Array[String]:
	var logs: Array[String] = []
	var modes: Array = completed_dungeon_modes.get(dungeon_id, [])
	var first_clear := modes.is_empty()
	if not modes.has(mode): modes.append(mode); completed_dungeon_modes[dungeon_id] = modes
	if dungeon_id == "forest" and mode == "strategy": logs.append_array(unlock_class("tank"))
	if dungeon_id == "forest" and mode == "slasher": logs.append_array(unlock_class("rogue"))
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
	var character:=_generate_character(class_id);roster[character.id]=character;return character

func _generate_character(class_id:String="") -> CharacterRecord:
	var allowed := unlocked_classes if not unlocked_classes.is_empty() else ["warrior", "mage"]
	if class_id.is_empty() or not allowed.has(class_id): class_id = String(allowed[(next_character_number - 1) % allowed.size()])
	var seed:=7919+next_character_number*104729+candidate_wave_id*3571;var identity_rng:=_rng(seed^0x11d);var available:Array=[]
	for value in ADVENTURERS.curated():if value is Dictionary and String(value.get("class",""))==class_id and not used_curated_ids.has(String(value.get("id",""))):available.append(value)
	var character:CharacterRecord
	if not available.is_empty():character=_character_from_definition(Dictionary(available[identity_rng.randi_range(0,available.size()-1)]))
	else:character=_generic_character(class_id,seed)
	var hidden_rng:=_rng(seed^0x4f1);var trait_pool:Array=ADVENTURERS.pool("traits");if hidden_rng.randf()<0.6 and trait_pool.size()>1:
		var hidden_id:=String(Dictionary(trait_pool[hidden_rng.randi_range(0,trait_pool.size()-1)]).get("id",""));if not hidden_id.is_empty() and hidden_id!=character.trait_id:character.hidden_traits.append(hidden_id)
	var quality_rank:=int(tavern_upgrades.get("replacement_quality",0));character.level=mini(20,1+quality_rank);character.progression["level"]=character.level
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
	var count:=2 if first_wave else clampi(2+int(tavern_upgrades.get("roster_services",0)),2,7)
	for index in count:
		var allowed:=unlocked_classes if not unlocked_classes.is_empty() else ["warrior","mage"]
		var class_id:=String(allowed[(calendar_day+candidate_wave_id+index-2)%allowed.size()])
		var member:=_generate_character(class_id)
		var motivation:=_candidate_motivation(member,index)
		var candidate:=CandidateRecord.create(member,calendar_day,candidate_wave_id,motivation,false);candidate.quality_seed=member.id.hash()^candidate_wave_id;candidate.quality_score=_quality_from_attributes(member);candidate_pool[member.id]=candidate
	_try_add_descendant()
	_add_calendar_event("arrivals","%d new adventurers arrive at the Hearth."%count)
	tavern_phase=TAVERN_ARRIVALS

func _candidate_motivation(member:CharacterRecord,index:int) -> String:
	return member.biography+" "+String(ADVENTURERS.pool("motives")[(calendar_day+candidate_wave_id+index)%ADVENTURERS.pool("motives").size()])

func _rng(seed:int)->RandomNumberGenerator:var rng:=RandomNumberGenerator.new();rng.seed=seed;return rng
func _character_from_definition(definition:Dictionary)->CharacterRecord:
	var trait_data:Dictionary=ADVENTURERS.trait_definition(String(definition.get("trait","stalwart")));var id:="hero_%06d"%next_character_number;var member:=CharacterRecord.create(id,String(definition.get("name","Adventurer")),String(definition.get("class","warrior")),trait_data,int(definition.get("portrait",0)))
	member.definition_id=String(definition.get("id",""));member.family_name=String(definition.get("family",""));member.pronouns=String(definition.get("pronouns","they/them"));member.origin=String(definition.get("origin","Unknown"));member.age_band=String(definition.get("age","Prime"));member.occupation=String(definition.get("occupation","Adventurer"));member.personality=String(definition.get("personality","Reserved"));member.preference=String(definition.get("preference","A fair contract"));member.biography=String(definition.get("biography","A traveler seeking work."));member.career_limit=clampi(int(definition.get("career",8))+int(trait_data.get("career",0)),6,10);member.lineage_id=id;member.arrival_year=get_calendar_date().year
	if not member.definition_id.is_empty() and not used_curated_ids.has(member.definition_id):used_curated_ids.append(member.definition_id)
	return member
func _generic_character(class_id:String,seed:int)->CharacterRecord:
	var rng:=_rng(seed);var names:Array=ADVENTURERS.pool("names");var families:Array=ADVENTURERS.pool("family_names");var traits:Array=ADVENTURERS.pool("traits");var trait_data:Dictionary=traits[rng.randi_range(0,traits.size()-1)];var member:=CharacterRecord.create("hero_%06d"%next_character_number,String(names[rng.randi_range(0,names.size()-1)]),class_id,trait_data,rng.randi_range(0,3));member.family_name=String(families[rng.randi_range(0,families.size()-1)]);member.pronouns=String(ADVENTURERS.pool("pronouns")[rng.randi_range(0,ADVENTURERS.pool("pronouns").size()-1)]);member.origin=String(ADVENTURERS.pool("origins")[rng.randi_range(0,ADVENTURERS.pool("origins").size()-1)]);member.age_band=String(ADVENTURERS.pool("age_bands")[rng.randi_range(0,ADVENTURERS.pool("age_bands").size()-1)]);member.occupation=String(ADVENTURERS.pool("occupations")[rng.randi_range(0,ADVENTURERS.pool("occupations").size()-1)]);member.preference=String(ADVENTURERS.pool("preferences")[rng.randi_range(0,ADVENTURERS.pool("preferences").size()-1)]);member.personality="Practical, guarded, and accustomed to uncertain roads.";member.biography="A %s from %s. %s"%[member.occupation,member.origin,String(ADVENTURERS.pool("hooks")[rng.randi_range(0,ADVENTURERS.pool("hooks").size()-1)])];member.career_limit=clampi(rng.randi_range(6,10)+int(trait_data.get("career",0)),6,10);member.lineage_id=member.id;member.arrival_year=get_calendar_date().year;member.generation=member.arrival_year;return member
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
	calendar_history.append({"day":calendar_day,"kind":kind,"text":text})
	while calendar_history.size()>40:calendar_history.pop_front()

func ensure_roster() -> void:
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

func begin_expedition(ids: Array[String], dungeon_id: String, mode: String, is_tutorial: bool = false) -> bool:
	return _begin_expedition_validated(ids,dungeon_id,mode,is_tutorial)

func _begin_expedition_validated(ids:Array[String],dungeon_id:String,mode:String,is_tutorial:bool=false) -> bool:
	if ids.is_empty() or ids.size() > get_party_cap(dungeon_id): return false
	for character_id in ids:
		var member := character(character_id)
		if member == null or member.status != CharacterRecord.STATUS_AVAILABLE: return false
	for character_id in ids:
		var member := character(character_id); member.status = CharacterRecord.STATUS_EXPEDITION; member.expeditions += 1
	var run_id:=0
	if not is_tutorial:run_id=next_expedition_id;next_expedition_id+=1
	expedition.begin(ids,dungeon_id,mode,is_tutorial,run_id);return true

func record_casualty(character_id: String, cause: String = "Fell in the dungeon") -> void:
	var member := character(character_id)
	if member == null or member.status == CharacterRecord.STATUS_DEAD: return
	member.status = CharacterRecord.STATUS_DEAD; expedition.record_casualty(character_id)
	var record:=member.to_dict();record.merge({"name":member.display_name,"cause":cause,"death_day":calendar_day,"epitaph":"%s of %s, remembered after %d expedition%s."%[member.display_name,member.origin,member.expeditions,"" if member.expeditions==1 else "s"]},true);memorial.append(record)
	if not expedition.tutorial_run:_add_calendar_event("death","%s dies during the expedition."%member.display_name)

func resolve_expedition(outcome: String) -> Array[String]:
	var result:=settle_expedition(expedition.expedition_id,outcome,{})
	var logs:Array[String]=[];logs.assign(result.get("logs",[]));return logs

func settle_expedition(run_id:int,outcome:String,result_data:Dictionary={}) -> Dictionary:
	if outcome not in ["victory","death"]:return {"ok":false,"error":"Expeditions resolve only through boss victory or total defeat.","logs":[]}
	if run_id>0 and run_id==last_settled_expedition_id:return {"ok":true,"duplicate":true,"logs":[]}
	if not expedition.active:return {"ok":false,"error":"No expedition is active.","logs":[]}
	if expedition.expedition_id!=run_id:return {"ok":false,"error":"The expedition ID does not match.","logs":[]}
	var tutorial_run:=expedition.tutorial_run;var party:=expedition.party_ids.duplicate();var dungeon_id:=expedition.dungeon_id;var resolved_mode:=expedition.play_mode;var resolved_depth:=expedition.floor;var logs:Array[String]=[];var retired_names:Array[String]=[];var returned_names:Array[String]=[]
	if outcome=="victory":
		banked_gold+=expedition.carried_gold;relic_essence+=expedition.carried_relic_essence;lifetime_relic_essence+=expedition.carried_relic_essence
		for relic_id in expedition.carried_relics:
			if not banked_relics.has(relic_id):banked_relics.append(relic_id)
		logs.append("Banked %d gold and %d relic essence."%[expedition.carried_gold,expedition.carried_relic_essence])
		if not expedition.carried_relics.is_empty():logs.append("Banked relics: %s."%", ".join(expedition.carried_relics))
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
	if run_id>0:last_settled_expedition_id=run_id
	expedition=ExpeditionState.new()
	if not tutorial_run:
		calendar_day+=7;if outcome=="victory":reputation=clampi(reputation+2+party.size(),0,100)
		_add_calendar_event("victory" if outcome=="victory" else "defeat",String(result_data.get("headline","The expedition returns victorious." if outcome=="victory" else "The expedition is lost.")))
		for returned_name in returned_names:_add_calendar_event("return","%s returns for another season at the Hearth."%returned_name)
		for retired_name in retired_names:_add_calendar_event("retirement","%s enters the Hall of Heroes."%retired_name)
		_generate_candidate_wave(false)
	else:tavern_phase=TAVERN_STORY
	pending_settlement_summary={"outcome":outcome,"headline":String(result_data.get("headline","Expedition resolved.")),"dungeon":dungeon_id,"mode":resolved_mode,"depth":resolved_depth,"gold":banked_gold if outcome=="victory" else 0}
	return {"ok":true,"duplicate":false,"logs":logs,"wave_id":candidate_wave_id,"calendar":get_calendar_date()}

func can_unlock_secret(secret_id: String) -> bool:
	if int(tavern_upgrades.get("secret_research", 0)) < 1: return false
	if secret_id == "moonlit_grove": return bool(clues.get("moonlit_forest", false)) and bool(clues.get("moonlit_farmstead", false))
	if secret_id == "abyssal_archive": return bool(clues.get("abyssal_crypt", false)) and bool(clues.get("abyssal_foundry", false))
	return false

func upgrade_cost(branch: String) -> Dictionary:
	var next_rank := int(tavern_upgrades.get(branch, 0)) + 1
	return {"gold":20 * next_rank, "essence":5 * next_rank, "levels":next_rank * 2}

func purchase_upgrade(branch: String) -> Array[String]:
	if not tavern_upgrades.has(branch): return ["Unknown tavern upgrade."]
	var cost := upgrade_cost(branch)
	if banked_gold < int(cost.gold) or relic_essence < int(cost.essence) or successful_levels < int(cost.levels): return ["The company lacks the gold, relic essence, or successful levels for that upgrade."]
	banked_gold -= int(cost.gold); relic_essence -= int(cost.essence); tavern_upgrades[branch] = int(tavern_upgrades[branch]) + 1
	return ["%s reaches rank %d." % [branch.replace("_", " ").capitalize(), int(tavern_upgrades[branch])]]

func to_dict() -> Dictionary:
	var encoded_roster: Array[Dictionary] = []
	for value in roster.values(): if value is CharacterRecord: encoded_roster.append(value.to_dict())
	var encoded_candidates:Array[Dictionary]=[]
	for value in candidate_pool.values():if value is CandidateRecord:encoded_candidates.append(value.to_dict())
	return {"version":SAVE_VERSION,"save_slot":save_slot,"last_saved_unix":last_saved_unix,"tutorial_phase":tutorial_phase,"tutorial_outcome":tutorial_outcome,"tutorial_history":tutorial_history.duplicate(true),"tutorial_keepsake_id":tutorial_keepsake_id,"tutorial_letter_unlocked":tutorial_letter_unlocked,"post_tutorial_initialized":post_tutorial_initialized,"former_keeper_encounter_pending":former_keeper_encounter_pending,"former_keeper_encounter_seen":former_keeper_encounter_seen,"calendar_day":calendar_day,"tavern_phase":tavern_phase,"candidate_wave_id":candidate_wave_id,"candidate_pool":encoded_candidates,"last_presented_wave_id":last_presented_wave_id,"calendar_history":calendar_history.duplicate(true),"retired_heroes":retired_heroes.duplicate(true),"first_company_ids":first_company_ids.duplicate(),"first_company_recruited":first_company_recruited,"first_normal_launch_completed":first_normal_launch_completed,"next_expedition_id":next_expedition_id,"last_settled_expedition_id":last_settled_expedition_id,"pending_settlement_summary":pending_settlement_summary.duplicate(true),"pending_story_context":pending_story_context,"roster":encoded_roster,"memorial":memorial.duplicate(true),"unlocked_classes":unlocked_classes.duplicate(),"completed_dungeon_modes":completed_dungeon_modes.duplicate(true),"banked_gold":banked_gold,"supplies":supplies,"relic_essence":relic_essence,"lifetime_relic_essence":lifetime_relic_essence,"banked_relics":banked_relics.duplicate(),"successful_levels":successful_levels,"tavern_upgrades":tavern_upgrades.duplicate(true),"tavern_dialogue_flags":tavern_dialogue_flags.duplicate(true),"clues":clues.duplicate(true),"next_character_number":next_character_number,"expedition":expedition.to_dict(),"legacy_runtime":legacy_runtime.duplicate(true),"reputation":reputation,"used_curated_ids":used_curated_ids.duplicate(),"lineage_registry":lineage_registry.duplicate(true)}

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
	campaign._load_dict(_migrate_dict(parsed))
	campaign.save_slot=slot
	if campaign.is_tutorial_complete() and not campaign.expedition.active:campaign.ensure_tavern_cycle()
	if imported_legacy:campaign.last_save_error="The previous single campaign was imported into Save Slot 1.";campaign.save_atomic()
	return campaign

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
		data["legacy_runtime"]={"completed_dungeons":Dictionary(data.get("completed_dungeons",{})).duplicate(true),"forest_cleared":bool(data.get("forest_cleared",false)),"completed_runs":int(data.get("completed_runs",0)),"deaths":int(data.get("deaths",0))}
	if version<=1:data["banked_relics"]=Array(data.get("banked_relics",[]))
	if version<=2:data["save_slot"]=int(data.get("save_slot",1));data["last_saved_unix"]=int(data.get("last_saved_unix",0))
	if version<=3:
		data["supplies"]=int(data.get("supplies",0));data["tutorial_outcome"]=String(data.get("tutorial_outcome",""));data["tutorial_history"]=Dictionary(data.get("tutorial_history",{})).duplicate(true);data["tutorial_keepsake_id"]=String(data.get("tutorial_keepsake_id",""));data["tutorial_letter_unlocked"]=bool(data.get("tutorial_letter_unlocked",false));data["post_tutorial_initialized"]=bool(data.get("post_tutorial_initialized",String(data.get("tutorial_phase",TUTORIAL_NEW))==TUTORIAL_COMPLETE));data["former_keeper_encounter_pending"]=bool(data.get("former_keeper_encounter_pending",false));data["former_keeper_encounter_seen"]=bool(data.get("former_keeper_encounter_seen",false))
	if version<=4:
		data["calendar_day"]=maxi(1,int(data.get("calendar_day",1)));data["tavern_phase"]=String(data.get("tavern_phase",TAVERN_OPEN));data["candidate_wave_id"]=int(data.get("candidate_wave_id",0));data["candidate_pool"]=Array(data.get("candidate_pool",[]));data["last_presented_wave_id"]=int(data.get("last_presented_wave_id",0));data["calendar_history"]=Array(data.get("calendar_history",[]));data["retired_heroes"]=Array(data.get("retired_heroes",[]));data["first_company_ids"]=Array(data.get("first_company_ids",[]));data["first_company_recruited"]=bool(data.get("first_company_recruited",true));data["first_normal_launch_completed"]=bool(data.get("first_normal_launch_completed",true));data["next_expedition_id"]=maxi(1,int(data.get("next_expedition_id",1)));data["last_settled_expedition_id"]=maxi(0,int(data.get("last_settled_expedition_id",0)));
		var old_roster:Array=Array(data.get("roster",[]));var names:Array[String]=[]
		for record in old_roster:if record is Dictionary:names.append(String(record.get("display_name","")))
		data["_convert_first_company_candidates"]=String(data.get("tutorial_phase",TUTORIAL_NEW))==TUTORIAL_COMPLETE and Dictionary(data.get("completed_dungeon_modes",{})).is_empty() and old_roster.size()==2 and names.has("Brina") and names.has("Eamon")
	if version<=5:data["reputation"]=int(data.get("reputation",0));data["used_curated_ids"]=Array(data.get("used_curated_ids",[]));data["lineage_registry"]=Dictionary(data.get("lineage_registry",{})).duplicate(true)
	if version<=6:data["tavern_dialogue_flags"]=Dictionary(data.get("tavern_dialogue_flags",{})).duplicate(true)
	var classes:Array=[];classes.assign(data.get("unlocked_classes",["warrior","mage"]))
	for i in range(classes.size()):if String(classes[i])=="phantom":classes[i]="rogue"
	data["unlocked_classes"]=classes;data["version"]=SAVE_VERSION;return data

func _load_dict(data: Dictionary) -> void:
	save_slot=clampi(int(data.get("save_slot",save_slot)),1,SAVE_SLOT_COUNT);last_saved_unix=maxi(0,int(data.get("last_saved_unix",0)))
	tutorial_phase = String(data.get("tutorial_phase", TUTORIAL_NEW)); tutorial_outcome = String(data.get("tutorial_outcome", "")); tutorial_history = Dictionary(data.get("tutorial_history", {})).duplicate(true); tutorial_keepsake_id = String(data.get("tutorial_keepsake_id", "")); tutorial_letter_unlocked = bool(data.get("tutorial_letter_unlocked", false)); post_tutorial_initialized = bool(data.get("post_tutorial_initialized", tutorial_phase == TUTORIAL_COMPLETE)); former_keeper_encounter_pending = bool(data.get("former_keeper_encounter_pending", false)); former_keeper_encounter_seen = bool(data.get("former_keeper_encounter_seen", false)); memorial.assign(data.get("memorial", [])); unlocked_classes.assign(data.get("unlocked_classes", ["warrior","mage"]))
	completed_dungeon_modes = Dictionary(data.get("completed_dungeon_modes", {})).duplicate(true); banked_gold = maxi(0, int(data.get("banked_gold", 0))); supplies = maxi(0, int(data.get("supplies", 0))); relic_essence = maxi(0, int(data.get("relic_essence", 0))); lifetime_relic_essence = maxi(relic_essence, int(data.get("lifetime_relic_essence", relic_essence))); successful_levels = maxi(0, int(data.get("successful_levels", 0)))
	banked_relics.assign(data.get("banked_relics", []))
	tavern_upgrades.merge(Dictionary(data.get("tavern_upgrades", {})), true); tavern_dialogue_flags = Dictionary(data.get("tavern_dialogue_flags", {})).duplicate(true); clues = Dictionary(data.get("clues", {})).duplicate(true); next_character_number = maxi(1, int(data.get("next_character_number", 1)))
	roster.clear()
	for value in data.get("roster", []):
		if value is Dictionary:
			var member := CharacterRecord.from_dict(value)
			if not member.id.is_empty(): roster[member.id] = member
	expedition = ExpeditionState.from_dict(Dictionary(data.get("expedition", {})))
	legacy_runtime = Dictionary(data.get("legacy_runtime", {})).duplicate(true)
	calendar_day=maxi(1,int(data.get("calendar_day",1)));tavern_phase=String(data.get("tavern_phase",TAVERN_OPEN));candidate_wave_id=maxi(0,int(data.get("candidate_wave_id",0)));last_presented_wave_id=maxi(0,int(data.get("last_presented_wave_id",0)));calendar_history.assign(data.get("calendar_history",[]));retired_heroes.assign(data.get("retired_heroes",[]));first_company_ids.assign(data.get("first_company_ids",[]));first_company_recruited=bool(data.get("first_company_recruited",true));first_normal_launch_completed=bool(data.get("first_normal_launch_completed",true));next_expedition_id=maxi(1,int(data.get("next_expedition_id",1)));last_settled_expedition_id=maxi(0,int(data.get("last_settled_expedition_id",0)))
	pending_settlement_summary=Dictionary(data.get("pending_settlement_summary",{})).duplicate(true);pending_story_context=String(data.get("pending_story_context",""))
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

func _convert_legacy_first_company() -> void:
	if roster.size()!=2:return
	candidate_wave_id=1;first_company_ids.clear();candidate_pool.clear()
	for member in living_roster():
		first_company_ids.append(member.id);candidate_pool[member.id]=CandidateRecord.create(member,calendar_day,candidate_wave_id,"I came to the Hearth for the first company expedition.",true)
	roster.clear();first_company_recruited=false;first_normal_launch_completed=false;last_presented_wave_id=0;tavern_phase=TAVERN_ARRIVALS
