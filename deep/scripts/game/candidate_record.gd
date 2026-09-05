extends RefCounted
class_name CandidateRecord

var id: String = ""
var adventurer: CharacterRecord
var arrival_day: int = 1
var wave_id: int = 1
var motivation: String = ""
var first_company: bool = false

static func create(record: CharacterRecord, day: int, wave: int, motivation_text: String, is_first_company: bool = false) -> CandidateRecord:
	var candidate := CandidateRecord.new()
	candidate.id = record.id
	candidate.adventurer = record
	candidate.arrival_day = maxi(1, day)
	candidate.wave_id = maxi(1, wave)
	candidate.motivation = motivation_text
	candidate.first_company = is_first_company
	return candidate

func to_dict() -> Dictionary:
	return {
		"id": id,
		"adventurer": adventurer.to_dict() if adventurer != null else {},
		"arrival_day": arrival_day,
		"wave_id": wave_id,
		"motivation": motivation,
		"first_company": first_company,
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
	return candidate
