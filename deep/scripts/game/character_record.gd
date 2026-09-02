extends RefCounted
class_name CharacterRecord

const STATUS_AVAILABLE := "available"
const STATUS_EXPEDITION := "expedition"
const STATUS_DEAD := "dead"

var id: String = ""
var display_name: String = ""
var portrait_variant: int = 0
var class_id: String = "warrior"
var level: int = 1
var xp: int = 0
var current_health: int = 1
var max_health: int = 1
var gear_id: String = ""
var inventory: Array[String] = []
var trait_id: String = "steady"
var trait_name: String = "Steady"
var trait_description: String = "No unusual strengths or weaknesses."
var progression: Dictionary = {}
var status: String = STATUS_AVAILABLE
var expeditions: int = 0
var victories: int = 0
var deepest_floor: int = 0
var kills: int = 0

static func create(character_id: String, name: String, character_class: String, trait_data: Dictionary, portrait: int = 0) -> CharacterRecord:
	var record := CharacterRecord.new()
	record.id = character_id
	record.display_name = name
	record.class_id = GameBalance.normalize_class_id(character_class)
	record.portrait_variant = portrait
	record.trait_id = String(trait_data.get("id", "steady"))
	record.trait_name = String(trait_data.get("name", "Steady"))
	record.trait_description = String(trait_data.get("description", "No unusual strengths or weaknesses."))
	record.progression = {"level":1, "xp":0, "attributes":{}, "inventory":[], "slasher_evolution_path":[], "slasher_upgrades":[]}
	return record

func to_dict() -> Dictionary:
	return {
		"id":id, "display_name":display_name, "portrait_variant":portrait_variant, "class_id":class_id,
		"level":level, "xp":xp, "current_health":current_health, "max_health":max_health,
		"gear_id":gear_id, "inventory":inventory.duplicate(), "trait_id":trait_id, "trait_name":trait_name,
		"trait_description":trait_description, "progression":progression.duplicate(true), "status":status,
		"expeditions":expeditions, "victories":victories, "deepest_floor":deepest_floor, "kills":kills,
	}

static func from_dict(data: Dictionary) -> CharacterRecord:
	var record := CharacterRecord.new()
	record.id = String(data.get("id", "")); record.display_name = String(data.get("display_name", "Adventurer"))
	record.portrait_variant = int(data.get("portrait_variant", 0)); record.class_id = GameBalance.normalize_class_id(String(data.get("class_id", "warrior")))
	record.level = maxi(1, int(data.get("level", 1))); record.xp = maxi(0, int(data.get("xp", 0)))
	record.current_health = int(data.get("current_health", 1)); record.max_health = maxi(1, int(data.get("max_health", 1)))
	record.gear_id = String(data.get("gear_id", "")); record.inventory.assign(data.get("inventory", []))
	record.trait_id = String(data.get("trait_id", "steady")); record.trait_name = String(data.get("trait_name", "Steady"))
	record.trait_description = String(data.get("trait_description", "No unusual strengths or weaknesses."))
	record.progression = Dictionary(data.get("progression", {})).duplicate(true); record.status = String(data.get("status", STATUS_AVAILABLE))
	record.expeditions = maxi(0, int(data.get("expeditions", 0))); record.victories = maxi(0, int(data.get("victories", 0)))
	record.deepest_floor = maxi(0, int(data.get("deepest_floor", 0))); record.kills = maxi(0, int(data.get("kills", 0)))
	return record
