extends RefCounted
class_name NarrativeProgression

const CODEX_PATH:="res://data/story/codex_entries.json"
const ENDINGS_PATH:="res://data/story/endings.json"
static var _codex:Dictionary={};static var _endings:Dictionary={}

static func _load(path:String)->Dictionary:
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(path));return Dictionary(parsed) if parsed is Dictionary else {}
static func codex()->Dictionary:
	if _codex.is_empty():_codex=Dictionary(_load(CODEX_PATH).get("entries",{}))
	return _codex
static func endings()->Dictionary:
	if _endings.is_empty():_endings=Dictionary(_load(ENDINGS_PATH).get("endings",{}))
	return _endings

static func unlocked_codex(campaign)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for entry_id in codex():
		var entry:=Dictionary(codex()[entry_id]);var source:=Dictionary(entry.get("source",{}));var unlocked:=false
		match String(source.get("type","")):
			"discovery":unlocked=Array(campaign.keeper_memory.get("discoveries",[])).has(String(source.get("id","")))
			"discovery_prefix":
				for value in Array(campaign.keeper_memory.get("discoveries",[])):
					if String(value).begins_with(String(source.get("id",""))):unlocked=true;break
			"clue":unlocked=bool(campaign.clues.get(String(source.get("id","")),false))
			"obligation_count":unlocked=campaign.divine_obligations.size()>=int(source.get("value",1))
		if unlocked:var copy:=entry.duplicate(true);copy["id"]=entry_id;result.append(copy)
	return result

static func ending_status(campaign,ending_id:String)->Dictionary:
	var definition:=Dictionary(endings().get(ending_id,{}));var missing:Array[String]=[]
	if definition.is_empty():return {"eligible":false,"missing":["Unknown ending."]}
	for requirement_value in Array(definition.get("requirements",[])):
		var requirement:=Dictionary(requirement_value);var kind:=String(requirement.get("type",""));var minimum:=int(requirement.get("minimum",0))
		match kind:
			"loop":
				if int(campaign.keeper_memory.get("loop_number",0))<minimum:missing.append("Reach Loop %d."%minimum)
			"contribution":
				if campaign.contribution<minimum:missing.append("Record %d Contribution."%minimum)
			"discoveries":
				for id in Array(requirement.get("all",[])):
					if not Array(campaign.keeper_memory.get("discoveries",[])).has(id):missing.append("Recover remembered evidence: %s."%String(id).replace("_"," "))
			"clues":
				for id in Array(requirement.get("all",[])):
					if not bool(campaign.clues.get(String(id),false)):missing.append("Recover evidence: %s."%String(id).replace("_"," "))
			"faction_count":
				var count:=0;for standing in campaign.faction_standing.values():if int(standing)>=int(requirement.get("standing",0)):count+=1
				if count<minimum:missing.append("Earn standing %d with %d nations."%[int(requirement.get("standing",0)),minimum])
			"deity_count":
				var count:=0;for favor in campaign.divine_favor.values():if int(favor)>=int(requirement.get("favor",0)):count+=1
				if count<minimum:missing.append("Earn %d favor with %d gods."%[int(requirement.get("favor",0)),minimum])
			"fulfilled_obligations":
				var count:=0;for record_value in campaign.divine_obligations:if String(Dictionary(record_value).get("status",""))=="fulfilled":count+=1
				if count<minimum:missing.append("Fulfill %d divine promises."%minimum)
	return {"eligible":missing.is_empty(),"missing":missing,"definition":definition}

static func choose_ending(campaign,ending_id:String)->Dictionary:
	var status:=ending_status(campaign,ending_id)
	if not bool(status.eligible):return {"ok":false,"error":"The Keeper lacks the required evidence and relationships.","missing":status.missing}
	campaign.ending_state={"ending_id":ending_id,"chosen_day":campaign.calendar_day,"loop_number":int(campaign.keeper_memory.get("loop_number",0)),"name":String(Dictionary(status.definition).get("name",ending_id))}
	campaign.pending_story_event_id="ending_%s"%ending_id
	campaign._add_calendar_event("ending",String(campaign.ending_state.name)+" becomes possible through the Keeper's final choice.")
	return {"ok":true,"ending":campaign.ending_state.duplicate(true),"story_event_id":campaign.pending_story_event_id}

static func validate()->Array[String]:
	var errors:Array[String]=[]
	for id in codex():if String(Dictionary(codex()[id]).get("title","")).is_empty():errors.append("Codex entry %s has no title."%id)
	for id in endings():if Array(Dictionary(endings()[id]).get("requirements",[])).is_empty():errors.append("Ending %s has no requirements."%id)
	return errors
