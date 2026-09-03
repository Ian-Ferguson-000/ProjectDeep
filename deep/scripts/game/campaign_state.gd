extends RefCounted
class_name CampaignState

const SAVE_VERSION := 4
const TARGET_ROSTER_SIZE := 6
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
var relic_essence: int = 0
var lifetime_relic_essence: int = 0
var banked_relics: Array[String] = []
var successful_levels: int = 0
var tavern_upgrades: Dictionary = {"roster_services":0,"starting_supplies":0,"item_rarity":0,"merchant_stock":0,"relic_capacity":0,"secret_research":0,"replacement_quality":0}
var clues: Dictionary = {}
var candidates: Array[Dictionary] = []
var contracts: Array[Dictionary] = []
var company_tabs: Array[Dictionary] = []
var injuries: Dictionary = {}
var recovery: Dictionary = {}
var relationships: Dictionary = {}
var secured_loot: Dictionary = {"gold": 0, "items": [], "relics": []}
var applied_settlement_ids: Array[String] = []
var reputation: Dictionary = {"company": 0, "regions": {}}
var definition_versions: Dictionary = {"manifest": "demo-1"}
var unknown_definition_placeholders: Array[Dictionary] = []
var migration_diagnostics: Array[String] = []
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
	character.max_health = maxi(1, health); character.current_health = character.max_health
	next_character_number += 1; roster[character.id] = character; return character

func ensure_roster() -> void:
	while living_roster().size() < TARGET_ROSTER_SIZE: create_character()

func living_roster() -> Array[CharacterRecord]:
	var result: Array[CharacterRecord] = []
	for value in roster.values():
		if value is CharacterRecord and value.status != CharacterRecord.STATUS_DEAD: result.append(value)
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
	if ids.is_empty() or ids.size() > get_party_cap(dungeon_id): return false
	for character_id in ids:
		var member := character(character_id)
		if member == null or member.status != CharacterRecord.STATUS_AVAILABLE: return false
	for character_id in ids:
		var member := character(character_id); member.status = CharacterRecord.STATUS_EXPEDITION; member.expeditions += 1
	expedition.begin(ids, dungeon_id, mode, is_tutorial); return true

func record_casualty(character_id: String, cause: String = "Fell in the dungeon") -> void:
	var member := character(character_id)
	if member == null or member.status == CharacterRecord.STATUS_DEAD: return
	member.status = CharacterRecord.STATUS_DEAD; expedition.record_casualty(character_id)
	memorial.append({"id":member.id,"name":member.display_name,"class_id":member.class_id,"level":member.level,"cause":cause,"expeditions":member.expeditions,"victories":member.victories})

func resolve_expedition(outcome: String) -> Array[String]:
	var logs: Array[String] = []
	var banks_loot := outcome in ["victory", "extract"]
	if banks_loot:
		banked_gold += expedition.carried_gold; relic_essence += expedition.carried_relic_essence; lifetime_relic_essence += expedition.carried_relic_essence
		for relic_id in expedition.carried_relics:
			if not banked_relics.has(relic_id): banked_relics.append(relic_id)
		logs.append("Banked %d gold and %d relic essence." % [expedition.carried_gold, expedition.carried_relic_essence])
		if not expedition.carried_relics.is_empty(): logs.append("Banked relics: %s." % ", ".join(expedition.carried_relics))
	for character_id in expedition.party_ids:
		var member := character(character_id)
		if member == null or member.status == CharacterRecord.STATUS_DEAD: continue
		member.status = CharacterRecord.STATUS_AVAILABLE
		if outcome == "victory": member.victories += 1; successful_levels += member.level
	expedition = ExpeditionState.new(); ensure_roster(); return logs

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
	return {"version":SAVE_VERSION,"save_slot":save_slot,"last_saved_unix":last_saved_unix,"tutorial_phase":tutorial_phase,"roster":encoded_roster,"memorial":memorial.duplicate(true),"unlocked_classes":unlocked_classes.duplicate(),"completed_dungeon_modes":completed_dungeon_modes.duplicate(true),"banked_gold":banked_gold,"relic_essence":relic_essence,"lifetime_relic_essence":lifetime_relic_essence,"banked_relics":banked_relics.duplicate(),"successful_levels":successful_levels,"tavern_upgrades":tavern_upgrades.duplicate(true),"clues":clues.duplicate(true),"candidates":candidates.duplicate(true),"contracts":contracts.duplicate(true),"company_tabs":company_tabs.duplicate(true),"injuries":injuries.duplicate(true),"recovery":recovery.duplicate(true),"relationships":relationships.duplicate(true),"secured_loot":secured_loot.duplicate(true),"applied_settlement_ids":applied_settlement_ids.duplicate(),"reputation":reputation.duplicate(true),"definition_versions":definition_versions.duplicate(true),"unknown_definition_placeholders":unknown_definition_placeholders.duplicate(true),"migration_diagnostics":migration_diagnostics.duplicate(),"next_character_number":next_character_number,"expedition":expedition.to_dict(),"legacy_runtime":legacy_runtime.duplicate(true)}

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
	if campaign.is_tutorial_complete():campaign.ensure_roster()
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
		data["candidates"]=Array(data.get("candidates",[]));data["contracts"]=Array(data.get("contracts",[]));data["company_tabs"]=Array(data.get("company_tabs",[]))
		data["injuries"]=Dictionary(data.get("injuries",{}));data["recovery"]=Dictionary(data.get("recovery",{}));data["relationships"]=Dictionary(data.get("relationships",{}))
		data["secured_loot"]=Dictionary(data.get("secured_loot",{"gold":0,"items":[],"relics":[]}));data["applied_settlement_ids"]=Array(data.get("applied_settlement_ids",[]))
		data["reputation"]=Dictionary(data.get("reputation",{"company":0,"regions":{}}));data["definition_versions"]=Dictionary(data.get("definition_versions",{"manifest":"demo-1"}))
		data["unknown_definition_placeholders"]=Array(data.get("unknown_definition_placeholders",[]));data["migration_diagnostics"]=Array(data.get("migration_diagnostics",[]))
	var classes:Array=[];classes.assign(data.get("unlocked_classes",["warrior","mage"]))
	for i in range(classes.size()):classes[i]=GameBalance.normalize_class_id(String(classes[i]))
	data["unlocked_classes"]=classes;data["version"]=SAVE_VERSION;return data

func _load_dict(data: Dictionary) -> void:
	save_slot=clampi(int(data.get("save_slot",save_slot)),1,SAVE_SLOT_COUNT);last_saved_unix=maxi(0,int(data.get("last_saved_unix",0)))
	tutorial_phase = String(data.get("tutorial_phase", TUTORIAL_NEW)); memorial.assign(data.get("memorial", [])); unlocked_classes.assign(data.get("unlocked_classes", ["warrior","mage"]))
	completed_dungeon_modes = Dictionary(data.get("completed_dungeon_modes", {})).duplicate(true); banked_gold = maxi(0, int(data.get("banked_gold", 0))); relic_essence = maxi(0, int(data.get("relic_essence", 0))); lifetime_relic_essence = maxi(relic_essence, int(data.get("lifetime_relic_essence", relic_essence))); successful_levels = maxi(0, int(data.get("successful_levels", 0)))
	banked_relics.assign(data.get("banked_relics", []))
	tavern_upgrades.merge(Dictionary(data.get("tavern_upgrades", {})), true); clues = Dictionary(data.get("clues", {})).duplicate(true); next_character_number = maxi(1, int(data.get("next_character_number", 1)))
	candidates.assign(data.get("candidates", []));contracts.assign(data.get("contracts", []));company_tabs.assign(data.get("company_tabs", []))
	injuries=Dictionary(data.get("injuries", {})).duplicate(true);recovery=Dictionary(data.get("recovery", {})).duplicate(true);relationships=Dictionary(data.get("relationships", {})).duplicate(true)
	secured_loot=Dictionary(data.get("secured_loot", {"gold":0,"items":[],"relics":[]})).duplicate(true);applied_settlement_ids.assign(data.get("applied_settlement_ids", []))
	reputation=Dictionary(data.get("reputation", {"company":0,"regions":{}})).duplicate(true);definition_versions=Dictionary(data.get("definition_versions", {"manifest":"demo-1"})).duplicate(true)
	unknown_definition_placeholders.assign(data.get("unknown_definition_placeholders", []));migration_diagnostics.assign(data.get("migration_diagnostics", []))
	roster.clear()
	for value in data.get("roster", []):
		if value is Dictionary:
			var member := CharacterRecord.from_dict(value)
			if not member.id.is_empty(): roster[member.id] = member
	expedition = ExpeditionState.from_dict(Dictionary(data.get("expedition", {})))
	legacy_runtime = Dictionary(data.get("legacy_runtime", {})).duplicate(true)
