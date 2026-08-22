extends RefCounted
class_name GameBalance

const PROGRESSION_PATH := "res://data/progression.json"
const COMBAT_PATH := "res://data/combat_balance.json"
const ENEMY_PATH := "res://data/enemy_balance.json"
const ITEMS_PATH := "res://data/items.json"
const LOOT_TABLES_PATH := "res://data/loot_tables.json"
const CLASS_PROGRESSION_PATH := "res://data/class_progression.json"

static var _progression: Dictionary = {}
static var _combat: Dictionary = {}
static var _enemies: Dictionary = {}
static var _items: Dictionary = {}
static var _loot_tables: Dictionary = {}
static var _class_progression: Dictionary = {}
static var _loaded := false

static func get_progression() -> Dictionary:
	_load_all()
	return _progression

static func get_combat_value(path: Array, fallback: Variant) -> Variant:
	_load_all()
	return _get_nested(_combat, path, fallback)

static func get_enemy_value(enemy_type: String, stat: String, fallback: Variant) -> Variant:
	_load_all()
	var enemy_value: Variant = _enemies.get(enemy_type, {})
	var enemy: Dictionary = enemy_value if enemy_value is Dictionary else {}
	return enemy.get(stat, fallback)

static func get_items() -> Dictionary:
	_load_all()
	var items_value: Variant = _items.get("items", {})
	if items_value is Dictionary:
		return items_value
	return {}

static func get_item(item_id: String) -> Dictionary:
	var items: Dictionary = get_items()
	var item_value: Variant = items.get(item_id, {})
	if item_value is Dictionary:
		return item_value
	return {}

static func get_item_rarities() -> Dictionary:
	_load_all()
	var rarities_value: Variant = _items.get("rarities", {})
	if rarities_value is Dictionary:
		return rarities_value
	return {}

static func get_loot_table() -> Dictionary:
	_load_all()
	return _loot_tables

static func get_rarity_weights(floor: int) -> Dictionary:
	_load_all()
	var weights_by_floor_value: Variant = _loot_tables.get("rarity_weights_by_floor", {})
	var weights_by_floor: Dictionary = weights_by_floor_value if weights_by_floor_value is Dictionary else {}
	var weights_value: Variant = weights_by_floor.get(str(floor), weights_by_floor.get("1", {}))
	if weights_value is Dictionary:
		return weights_value
	return {"common": 100}

static func get_prop_hp(kind: String, fallback: int) -> int:
	_load_all()
	return int(_get_nested(_combat, ["props", "hp", kind], fallback))

static func get_class_data(class_id: String) -> Dictionary:
	_load_all()
	var classes_value: Variant = _progression.get("classes", {})
	var classes: Dictionary = classes_value if classes_value is Dictionary else {}
	var class_value: Variant = classes.get(class_id, classes.get("fighter", {}))
	if class_value is Dictionary:
		return class_value
	return {}

static func get_xp_thresholds() -> Array:
	_load_all()
	var thresholds: Variant = _progression.get("xp_thresholds", [])
	if thresholds is Array:
		return thresholds
	return []

static func get_max_level(fallback: int = 20) -> int:
	_load_all()
	return int(_progression.get("max_level", fallback))

static func get_class_progression(class_id: String) -> Dictionary:
	_load_all()
	var progression_value: Variant = _class_progression.get(class_id, {})
	if progression_value is Dictionary:
		return progression_value
	return {}

static func get_evolution_choices(class_id: String, level: int, profile: Dictionary) -> Array:
	return _class_choices_for_level(class_id, "evolutions", level, profile)

static func get_ability_upgrade_choices(class_id: String, level: int, profile: Dictionary) -> Array:
	return _class_choices_for_level(class_id, "ability_upgrades", level, profile)

static func get_progression_choice(class_id: String, choice_id: String) -> Dictionary:
	var progression: Dictionary = get_class_progression(class_id)
	for list_key in ["evolutions", "ability_upgrades"]:
		var list_value: Variant = progression.get(list_key, [])
		if not (list_value is Array):
			continue
		for choice in list_value:
			if not (choice is Dictionary):
				continue
			var choice_dict: Dictionary = choice
			if String(choice_dict.get("id", "")) == choice_id:
				return choice_dict.duplicate(true)
	return {}

static func _load_all() -> void:
	if _loaded:
		return
	_loaded = true
	_progression = _load_json(PROGRESSION_PATH)
	_combat = _load_json(COMBAT_PATH)
	_enemies = _load_json(ENEMY_PATH)
	_items = _load_json(ITEMS_PATH)
	_loot_tables = _load_json(LOOT_TABLES_PATH)
	_class_progression = _load_json(CLASS_PROGRESSION_PATH)

static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Missing balance data file: %s" % path)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Could not open balance data file: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_warning("Invalid balance data JSON: %s" % path)
	return {}

static func _get_nested(source: Dictionary, path: Array, fallback: Variant) -> Variant:
	var cursor: Variant = source
	for key in path:
		if not (cursor is Dictionary) or not cursor.has(key):
			return fallback
		cursor = cursor[key]
	return cursor

static func _class_choices_for_level(class_id: String, list_key: String, level: int, profile: Dictionary) -> Array:
	var progression: Dictionary = get_class_progression(class_id)
	var list_value: Variant = progression.get(list_key, [])
	var selected_paths: Array = _profile_array(profile, "evolution_path")
	var selected_upgrades: Array = _profile_array(profile, "ability_upgrades")
	var selected: Array = selected_paths + selected_upgrades
	var choices: Array = []
	if not (list_value is Array):
		return choices
	for choice in list_value:
		if not (choice is Dictionary):
			continue
		var choice_dict: Dictionary = choice
		var choice_id: String = String(choice_dict.get("id", ""))
		if int(choice_dict.get("level", -1)) != level or choice_id.is_empty() or selected.has(choice_id):
			continue
		var required_path: String = String(choice_dict.get("requires", ""))
		if not required_path.is_empty() and not selected_paths.has(required_path):
			continue
		choices.append(choice_dict.duplicate(true))
	return choices

static func _profile_array(profile: Dictionary, key: String) -> Array:
	var value: Variant = profile.get(key, [])
	if value is Array:
		return value
	return []
