extends RefCounted
class_name NarrativeContent

const NATIONS_PATH := "res://data/story/nations.json"
const DUNGEON_LORE_PATH := "res://data/story/dungeon_lore.json"

static var _nations: Dictionary = {}
static var _dungeon_lore: Dictionary = {}
static var _routes: Dictionary = {}

static func nations() -> Dictionary:
	if _nations.is_empty():
		_nations = Dictionary(_load_json(NATIONS_PATH).get("nations", {})).duplicate(true)
	return _nations

static func nation(nation_id: String) -> Dictionary:
	return Dictionary(nations().get(nation_id, nations().get("crossroads", {}))).duplicate(true)

static func nation_name(nation_id: String) -> String:
	return String(nation(nation_id).get("name", "The Crossroads"))

static func dungeon_lore(dungeon_id: String) -> Dictionary:
	_load_dungeon_lore()
	return Dictionary(_dungeon_lore.get(dungeon_id, {})).duplicate(true)

static func next_route_stage(dungeon_id: String) -> String:
	_load_dungeon_lore()
	var route_id := String(dungeon_lore(dungeon_id).get("route_id", ""))
	var stages: Array = Array(Dictionary(_routes.get(route_id, {})).get("stages", []))
	var index := stages.find(dungeon_id)
	return String(stages[index + 1]) if index >= 0 and index + 1 < stages.size() else ""

static func _load_dungeon_lore() -> void:
	if not _dungeon_lore.is_empty(): return
	var data := _load_json(DUNGEON_LORE_PATH)
	_dungeon_lore = Dictionary(data.get("dungeons", {})).duplicate(true)
	_routes = Dictionary(data.get("routes", {})).duplicate(true)

static func validate() -> Array[String]:
	var errors: Array[String] = []
	var required := ["crossroads", "nordia", "zarabia", "helvetica", "verdant_concord", "veiled_isles", "sun_crowned_dominion"]
	for nation_id in required:
		var definition := nation(nation_id)
		if definition.is_empty(): errors.append("Missing nation: %s" % nation_id)
		elif String(definition.get("name", "")).is_empty(): errors.append("Nation %s has no display name." % nation_id)
	for dungeon_id in GameBalance.get_dungeon_order():
		if dungeon_lore(String(dungeon_id)).is_empty(): errors.append("Missing narrative lore for dungeon: %s" % dungeon_id)
	return errors

static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing narrative data file: " + path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	if not parsed is Dictionary:
		push_error("Invalid narrative JSON: " + path)
		return {}
	return parsed
