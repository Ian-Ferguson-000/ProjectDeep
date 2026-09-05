extends RefCounted
class_name CampaignState

const SAVE_VERSION := 5
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
	clues.clear()
	unlocked_classes = ["warrior", "mage"]
	tavern_upgrades = {"roster_services":0,"starting_supplies":0,"item_rarity":0,"merchant_stock":0,"relic_capacity":0,"secret_research":0,"replacement_quality":0}
	roster.clear()
	next_character_number = 1
	candidate_pool.clear()
	candidate_wave_id = 1
	calendar_day = 1
	var warrior := _generate_character("warrior")
	warrior.display_name = "Brina"
	warrior.portrait_variant = 0
	warrior.gear_id = "sword_shield"
	var mage := _generate_character("mage")
	mage.display_name = "Eamon"
	mage.portrait_variant = 0
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

func ensure_tavern_cycle() -> Dictionary:
	if not is_tutorial_complete():return {"ok":false,"error":"The tutorial is not complete."}
	if expedition.active:return {"ok":false,"error":"An expedition is active."}
	var changed:=false
	if candidate_pool.is_empty() and (candidate_wave_id==0 or living_roster().is_empty()):_generate_candidate_wave(false);changed=true
	if tavern_phase==TAVERN_EXPEDITION:tavern_phase=TAVERN_OPEN
	if last_presented_wave_id<candidate_wave_id:tavern_phase=TAVERN_ARRIVALS
	if changed:save_atomic()
	return {"ok":true,"wave_id":candidate_wave_id,"phase":tavern_phase}

func mark_arrivals_presented(wave_id:int) -> Dictionary:
	if wave_id!=candidate_wave_id:return {"ok":false,"error":"That candidate wave is no longer present."}
	last_presented_wave_id=maxi(last_presented_wave_id,wave_id);tavern_phase=TAVERN_OPEN;save_atomic()
	return {"ok":true,"wave_id":wave_id}

func recruit_candidate(candidate_id:String) -> Dictionary:
	var candidate:=candidate_pool.get(candidate_id) as CandidateRecord
	if candidate==null:return {"ok":false,"error":"That adventurer is no longer at the Hearth."}
	if living_roster().size()>=get_roster_capacity():return {"ok":false,"error":"The Hearth has no open rooms."}
	var member:=candidate.adventurer;member.status=CharacterRecord.STATUS_AVAILABLE;roster[member.id]=member;candidate_pool.erase(candidate_id)
	first_company_recruited=first_company_ids.all(func(id:String):return roster.has(id))
	_add_calendar_event("recruitment","%s joins the company."%member.display_name);save_atomic()
	return {"ok":true,"character_id":member.id,"message":"%s joins the company."%member.display_name}

func dismiss_character(character_id:String) -> Dictionary:
	var member:=character(character_id)
	if member==null or member.status!=CharacterRecord.STATUS_AVAILABLE:return {"ok":false,"error":"Only an available adventurer can be dismissed."}
	if not first_normal_launch_completed and first_company_ids.has(character_id):return {"ok":false,"error":"The founding recruits must complete the first expedition briefing."}
	roster.erase(character_id);_add_calendar_event("departure","%s leaves the Hearth."%member.display_name);save_atomic()
	if living_roster().is_empty() and candidate_pool.is_empty():_generate_candidate_wave(false);save_atomic()
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
	candidate_pool.clear();first_normal_launch_completed=true;tavern_phase=TAVERN_EXPEDITION;save_atomic()
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
	var rng := RandomNumberGenerator.new(); rng.seed = 7919 + next_character_number * 104729
	var name := String(NAMES[rng.randi_range(0, NAMES.size() - 1)])
	var trait_data: Dictionary = TRAITS[rng.randi_range(0, TRAITS.size() - 1)]
	var character := CharacterRecord.create("hero_%06d" % next_character_number, name, class_id, trait_data, rng.randi_range(0, 3))
	var quality_rank:=int(tavern_upgrades.get("replacement_quality",0));character.level=mini(20,1+quality_rank);character.progression["level"]=character.level
	var class_data := GameBalance.get_base_class(class_id)
	var stats: Dictionary = Dictionary(class_data.get("base_stats", {}))
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
		candidate_pool[member.id]=CandidateRecord.create(member,calendar_day,candidate_wave_id,motivation,false)
	_add_calendar_event("arrivals","%d new adventurers arrive at the Hearth."%count)
	tavern_phase=TAVERN_ARRIVALS

func _candidate_motivation(member:CharacterRecord,index:int) -> String:
	var lines:= ["I want a company that remembers the names it sends below.","I have debts to settle and enough courage to make the attempt.","Give me a fair road, honest gear, and a place by the fire when I return.","Rumors brought me here. The next victory will give people a reason to stay."]
	return "%s %s"%[String(lines[(calendar_day+candidate_wave_id+index)%lines.size()]),member.trait_description]

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
	memorial.append({"id":member.id,"name":member.display_name,"class_id":member.class_id,"level":member.level,"cause":cause,"expeditions":member.expeditions,"victories":member.victories})
	if not expedition.tutorial_run:_add_calendar_event("death","%s dies during the expedition."%member.display_name)

func resolve_expedition(outcome: String) -> Array[String]:
	var result:=settle_expedition(expedition.expedition_id,outcome,{})
	var logs:Array[String]=[];logs.assign(result.get("logs",[]));return logs

func settle_expedition(run_id:int,outcome:String,result_data:Dictionary={}) -> Dictionary:
	if outcome not in ["victory","death"]:return {"ok":false,"error":"Expeditions resolve only through boss victory or total defeat.","logs":[]}
	if run_id>0 and run_id==last_settled_expedition_id:return {"ok":true,"duplicate":true,"logs":[]}
	if not expedition.active:return {"ok":false,"error":"No expedition is active.","logs":[]}
	if expedition.expedition_id!=run_id:return {"ok":false,"error":"The expedition ID does not match.","logs":[]}
	var tutorial_run:=expedition.tutorial_run;var party:=expedition.party_ids.duplicate();var dungeon_id:=expedition.dungeon_id;var resolved_mode:=expedition.play_mode;var resolved_depth:=expedition.floor;var logs:Array[String]=[];var retired_names:Array[String]=[]
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
			member.victories+=1;successful_levels+=member.level;member.status=CharacterRecord.STATUS_RETIRED
			retired_heroes.append({"id":member.id,"name":member.display_name,"class_id":member.class_id,"level":member.level,"gear_id":member.gear_id,"expeditions":member.expeditions,"victories":member.victories,"kills":member.kills,"deepest_floor":member.deepest_floor,"retired_day":calendar_day+1,"dungeon_id":dungeon_id})
			roster.erase(member.id)
			retired_names.append(member.display_name)
			logs.append("%s retires to the Hall of Heroes."%member.display_name)
		else:
			record_casualty(member.id, String(result_data.get("headline", "Lost with the expedition")))
	if run_id>0:last_settled_expedition_id=run_id
	expedition=ExpeditionState.new()
	if not tutorial_run:
		calendar_day+=1;_add_calendar_event("victory" if outcome=="victory" else "defeat",String(result_data.get("headline","The expedition returns victorious." if outcome=="victory" else "The expedition is lost.")))
		for retired_name in retired_names:_add_calendar_event("retirement","%s enters the Hall of Heroes."%retired_name)
		_generate_candidate_wave(false)
	else:tavern_phase=TAVERN_STORY
	pending_settlement_summary={"outcome":outcome,"headline":String(result_data.get("headline","Expedition resolved.")),"dungeon":dungeon_id,"mode":resolved_mode,"depth":resolved_depth,"gold":banked_gold if outcome=="victory" else 0}
	save_atomic()
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
	return {"version":SAVE_VERSION,"save_slot":save_slot,"last_saved_unix":last_saved_unix,"tutorial_phase":tutorial_phase,"tutorial_outcome":tutorial_outcome,"tutorial_history":tutorial_history.duplicate(true),"tutorial_keepsake_id":tutorial_keepsake_id,"tutorial_letter_unlocked":tutorial_letter_unlocked,"post_tutorial_initialized":post_tutorial_initialized,"former_keeper_encounter_pending":former_keeper_encounter_pending,"former_keeper_encounter_seen":former_keeper_encounter_seen,"calendar_day":calendar_day,"tavern_phase":tavern_phase,"candidate_wave_id":candidate_wave_id,"candidate_pool":encoded_candidates,"last_presented_wave_id":last_presented_wave_id,"calendar_history":calendar_history.duplicate(true),"retired_heroes":retired_heroes.duplicate(true),"first_company_ids":first_company_ids.duplicate(),"first_company_recruited":first_company_recruited,"first_normal_launch_completed":first_normal_launch_completed,"next_expedition_id":next_expedition_id,"last_settled_expedition_id":last_settled_expedition_id,"pending_settlement_summary":pending_settlement_summary.duplicate(true),"pending_story_context":pending_story_context,"roster":encoded_roster,"memorial":memorial.duplicate(true),"unlocked_classes":unlocked_classes.duplicate(),"completed_dungeon_modes":completed_dungeon_modes.duplicate(true),"banked_gold":banked_gold,"supplies":supplies,"relic_essence":relic_essence,"lifetime_relic_essence":lifetime_relic_essence,"banked_relics":banked_relics.duplicate(),"successful_levels":successful_levels,"tavern_upgrades":tavern_upgrades.duplicate(true),"clues":clues.duplicate(true),"next_character_number":next_character_number,"expedition":expedition.to_dict(),"legacy_runtime":legacy_runtime.duplicate(true)}

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
	var classes:Array=[];classes.assign(data.get("unlocked_classes",["warrior","mage"]))
	for i in range(classes.size()):if String(classes[i])=="phantom":classes[i]="rogue"
	data["unlocked_classes"]=classes;data["version"]=SAVE_VERSION;return data

func _load_dict(data: Dictionary) -> void:
	save_slot=clampi(int(data.get("save_slot",save_slot)),1,SAVE_SLOT_COUNT);last_saved_unix=maxi(0,int(data.get("last_saved_unix",0)))
	tutorial_phase = String(data.get("tutorial_phase", TUTORIAL_NEW)); tutorial_outcome = String(data.get("tutorial_outcome", "")); tutorial_history = Dictionary(data.get("tutorial_history", {})).duplicate(true); tutorial_keepsake_id = String(data.get("tutorial_keepsake_id", "")); tutorial_letter_unlocked = bool(data.get("tutorial_letter_unlocked", false)); post_tutorial_initialized = bool(data.get("post_tutorial_initialized", tutorial_phase == TUTORIAL_COMPLETE)); former_keeper_encounter_pending = bool(data.get("former_keeper_encounter_pending", false)); former_keeper_encounter_seen = bool(data.get("former_keeper_encounter_seen", false)); memorial.assign(data.get("memorial", [])); unlocked_classes.assign(data.get("unlocked_classes", ["warrior","mage"]))
	completed_dungeon_modes = Dictionary(data.get("completed_dungeon_modes", {})).duplicate(true); banked_gold = maxi(0, int(data.get("banked_gold", 0))); supplies = maxi(0, int(data.get("supplies", 0))); relic_essence = maxi(0, int(data.get("relic_essence", 0))); lifetime_relic_essence = maxi(relic_essence, int(data.get("lifetime_relic_essence", relic_essence))); successful_levels = maxi(0, int(data.get("successful_levels", 0)))
	banked_relics.assign(data.get("banked_relics", []))
	tavern_upgrades.merge(Dictionary(data.get("tavern_upgrades", {})), true); clues = Dictionary(data.get("clues", {})).duplicate(true); next_character_number = maxi(1, int(data.get("next_character_number", 1)))
	roster.clear()
	for value in data.get("roster", []):
		if value is Dictionary:
			var member := CharacterRecord.from_dict(value)
			if not member.id.is_empty(): roster[member.id] = member
	expedition = ExpeditionState.from_dict(Dictionary(data.get("expedition", {})))
	legacy_runtime = Dictionary(data.get("legacy_runtime", {})).duplicate(true)
	calendar_day=maxi(1,int(data.get("calendar_day",1)));tavern_phase=String(data.get("tavern_phase",TAVERN_OPEN));candidate_wave_id=maxi(0,int(data.get("candidate_wave_id",0)));last_presented_wave_id=maxi(0,int(data.get("last_presented_wave_id",0)));calendar_history.assign(data.get("calendar_history",[]));retired_heroes.assign(data.get("retired_heroes",[]));first_company_ids.assign(data.get("first_company_ids",[]));first_company_recruited=bool(data.get("first_company_recruited",true));first_normal_launch_completed=bool(data.get("first_normal_launch_completed",true));next_expedition_id=maxi(1,int(data.get("next_expedition_id",1)));last_settled_expedition_id=maxi(0,int(data.get("last_settled_expedition_id",0)))
	pending_settlement_summary=Dictionary(data.get("pending_settlement_summary",{})).duplicate(true);pending_story_context=String(data.get("pending_story_context",""))
	candidate_pool.clear()
	for value in data.get("candidate_pool",[]):
		if value is Dictionary:
			var candidate:=CandidateRecord.from_dict(value)
			if not candidate.id.is_empty():candidate_pool[candidate.id]=candidate
	if bool(data.get("_convert_first_company_candidates",false)):_convert_legacy_first_company()

func _convert_legacy_first_company() -> void:
	if roster.size()!=2:return
	candidate_wave_id=1;first_company_ids.clear();candidate_pool.clear()
	for member in living_roster():
		first_company_ids.append(member.id);candidate_pool[member.id]=CandidateRecord.create(member,calendar_day,candidate_wave_id,"I came to the Hearth for the first company expedition.",true)
	roster.clear();first_company_recruited=false;first_normal_launch_completed=false;last_presented_wave_id=0;tavern_phase=TAVERN_ARRIVALS
