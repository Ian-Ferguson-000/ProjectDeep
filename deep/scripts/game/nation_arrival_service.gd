extends RefCounted
class_name NationArrivalService

const DATA_PATH:="res://data/story/nation_arrivals.json"
static var _data:Dictionary={}
static func data()->Dictionary:
	if _data.is_empty():var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH));_data=Dictionary(parsed) if parsed is Dictionary else {}
	return _data
static func reserved_definition_ids()->Array[String]:
	var result:Array[String]=[]
	for value in Array(data().get("arrivals",[])):result.append(String(Dictionary(value).get("definition_id","")))
	return result
static func inject_next(campaign)->Dictionary:
	for value in Array(data().get("arrivals",[])):
		var arrival:=Dictionary(value);var definition_id:=String(arrival.get("definition_id",""));var history_id:="nation_arrival:%s"%String(arrival.get("id",""))
		var prior:=Dictionary(campaign.story_event_history.get(history_id,{}));var loop_number:=int(campaign.keeper_memory.get("loop_number",0))
		if int(prior.get("loop_number",-1))==loop_number or campaign.used_curated_ids.has(definition_id):continue
		if not campaign.has_completed_dungeon(String(arrival.get("requires_dungeon",""))):continue
		var definition:=AdventurerContent.definition(definition_id)
		if definition.is_empty():continue
		var class_id:=String(definition.get("class",""))
		if not campaign.unlocked_classes.has(class_id):continue
		if campaign.candidate_pool.size()>=7:
			var ordinary:CandidateRecord=campaign.get_candidates().back();campaign.candidate_pool.erase(ordinary.id)
		var member:CharacterRecord=campaign._character_from_definition(definition);campaign._apply_attributes(member,48,definition_id.hash()^campaign.candidate_wave_id)
		var candidate:=CandidateRecord.create(member,campaign.calendar_day,campaign.candidate_wave_id,String(arrival.get("motivation","")),false);candidate.quality_seed=definition_id.hash();candidate.quality_score=campaign._quality_from_attributes(member);campaign.candidate_pool[member.id]=candidate
		campaign.story_event_history[history_id]={"loop_number":int(campaign.keeper_memory.get("loop_number",0)),"day":campaign.calendar_day,"variant":definition_id}
		campaign._add_calendar_event("nation_arrival",String(arrival.get("calendar_text","%s arrives at the Hearth."%member.display_name)))
		return {"added":true,"arrival_id":arrival.id,"candidate_id":member.id,"definition_id":definition_id}
	return {"added":false}
static func validate()->Array[String]:
	var errors:Array[String]=[];var seen:Dictionary={}
	for value in Array(data().get("arrivals",[])):
		var arrival:=Dictionary(value);var id:=String(arrival.get("id",""));var definition_id:=String(arrival.get("definition_id",""))
		if id.is_empty() or seen.has(id):errors.append("Missing or duplicate nation arrival ID: %s"%id)
		seen[id]=true
		if AdventurerContent.definition(definition_id).is_empty():errors.append("Nation arrival %s references missing adventurer %s."%[id,definition_id])
		if NarrativeContent.nation(String(arrival.get("nation_id",""))).is_empty():errors.append("Nation arrival %s references an unknown nation."%id)
		if GameBalance.get_dungeon(String(arrival.get("requires_dungeon",""))).is_empty():errors.append("Nation arrival %s references an unknown dungeon."%id)
	return errors
