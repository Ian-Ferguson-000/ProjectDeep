extends RefCounted
class_name CandidateRecord

var id: String = ""
var adventurer: CharacterRecord
var arrival_day: int = 1
var wave_id: int = 1
var motivation: String = ""
var first_company: bool = false
var quality_seed:=0
var quality_score:=35
var knowledge:Dictionary={}
var completed_interactions:Array[String]=[]
var appraisal_history:Array[String]=[]
var last_result:=""

static func create(record: CharacterRecord, day: int, wave: int, motivation_text: String, is_first_company: bool = false) -> CandidateRecord:
	var candidate := CandidateRecord.new()
	candidate.id = record.id
	candidate.adventurer = record
	candidate.arrival_day = maxi(1, day)
	candidate.wave_id = maxi(1, wave)
	candidate.motivation = motivation_text
	candidate.first_company = is_first_company
	candidate.knowledge={"class":"exact","level":"band","equipment":"hint","trait":"exact","primary_stat":"band","origin":"unknown","preference":"unknown","biography":"unknown"}
	return candidate

func to_dict() -> Dictionary:
	return {
		"id": id,
		"adventurer": adventurer.to_dict() if adventurer != null else {},
		"arrival_day": arrival_day,
		"wave_id": wave_id,
		"motivation": motivation,
		"first_company": first_company,
		"quality_seed":quality_seed,"quality_score":quality_score,"knowledge":knowledge.duplicate(true),"completed_interactions":completed_interactions.duplicate(),"appraisal_history":appraisal_history.duplicate(),"last_result":last_result,
	}

static func from_dict(data: Dictionary) -> CandidateRecord:
	var candidate := CandidateRecord.new()
	candidate.id = String(data.get("id", ""))
	candidate.adventurer = CharacterRecord.from_dict(Dictionary(data.get("adventurer", {})))
	if candidate.id.is_empty(): candidate.id = candidate.adventurer.id
	candidate.arrival_day = maxi(1, int(data.get("arrival_day", 1)))
	candidate.wave_id = maxi(1, int(data.get("wave_id", 1)))
	candidate.motivation = String(data.get("motivation", "I am looking for a road worth taking."))
	candidate.first_company = bool(data.get("first_company", false))
	candidate.quality_seed=int(data.get("quality_seed",candidate.id.hash()));candidate.quality_score=clampi(int(data.get("quality_score",35)),5,95);candidate.knowledge=Dictionary(data.get("knowledge",{"class":"exact","level":"band","equipment":"hint","trait":"exact","primary_stat":"band","origin":"unknown","preference":"unknown","biography":"unknown"})).duplicate(true);candidate.completed_interactions.assign(data.get("completed_interactions",[]));candidate.appraisal_history.assign(data.get("appraisal_history",[]));candidate.last_result=String(data.get("last_result",""))
	return candidate
