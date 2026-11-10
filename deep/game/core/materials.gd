extends RefCounted
class_name Materials

## Crafting and quest materials (data/materials.json). Basic enemies drop only
## these; mini bosses and bosses drop their trophy. Carried in
## RunState.materials during a run and banked into CampaignState.materials
## when the adventurer comes home alive.

const PATH := "res://data/materials.json"
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func material(id: String) -> Dictionary:
	return Dictionary(Dictionary(data().get("materials", {})).get(id, {}))


static func material_name(id: String) -> String:
	return String(material(id).get("name", id.capitalize()))


static func color(id: String) -> Color:
	return Color("#" + String(material(id).get("color", "c9a36a")))


## What an enemy drops: its trophy (mini bosses, bosses) or its family's material.
static func for_enemy(visual_id: String, behavior_id: String, trophy: bool) -> String:
	var by_enemy: Dictionary = Dictionary(data().get("by_enemy", {}))
	if trophy:
		for key in [behavior_id, visual_id]:
			if by_enemy.has(key):
				return String(by_enemy[key])
	return String(Dictionary(data().get("by_family", {})).get(Unlocks.family(visual_id), ""))


## Adds materials to a {id: count} store.
static func add(store: Dictionary, id: String, count: int = 1) -> void:
	if id.is_empty() or count <= 0:
		return
	store[id] = int(store.get(id, 0)) + count


static func total(store: Dictionary) -> int:
	var sum := 0
	for id in store:
		sum += int(store[id])
	return sum
