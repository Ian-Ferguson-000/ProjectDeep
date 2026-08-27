extends RefCounted
class_name GameBalance

const PROGRESSION_PATH := "res://data/progression.json"
const COMBAT_PATH := "res://data/combat_balance.json"
const ENEMY_PATH := "res://data/enemy_balance.json"
const ITEMS_PATH := "res://data/items.json"
const LOOT_TABLES_PATH := "res://data/loot_tables.json"
const CLASS_PROGRESSION_PATH := "res://data/class_progression.json"
const CLASSES_PATH := "res://data/classes.json"
const ITEM_EFFECTS_PATH := "res://data/item_effects.json"
const MERCHANTS_PATH := "res://data/merchants.json"
const CONSUMABLES_PATH := "res://data/consumables.json"
const DUNGEONS_PATH := "res://data/dungeons.json"

static var _progression: Dictionary = {}
static var _combat: Dictionary = {}
static var _enemies: Dictionary = {}
static var _items: Dictionary = {}
static var _loot_tables: Dictionary = {}
static var _class_progression: Dictionary = {}
static var _classes: Dictionary = {}
static var _item_effects: Dictionary = {}
static var _merchants: Dictionary = {}
static var _consumables: Dictionary = {}
static var _dungeons: Dictionary = {}
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

static func get_enemy_combat_stat(enemy_type: String, stat: String, fallback: Variant) -> Variant:
	_load_all()
	var defaults_value: Variant = _enemies.get("defaults", {})
	var defaults: Dictionary = defaults_value if defaults_value is Dictionary else {}
	return get_enemy_value(enemy_type, stat, defaults.get(stat, fallback))

static func get_items() -> Dictionary:
	_load_all()
	var items_value: Variant = _items.get("items", {})
	if items_value is Dictionary:
		var merged: Dictionary = items_value.duplicate(true)
		for item_id in _item_effects.keys():
			if not merged.has(item_id) or not (merged[item_id] is Dictionary):
				continue
			var item: Dictionary = merged[item_id]
			var upgrade_value: Variant = _item_effects[item_id]
			if upgrade_value is Dictionary:
				for key in upgrade_value.keys():
					item[key] = upgrade_value[key]
			merged[item_id] = item
		return merged
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
	class_id = normalize_class_id(class_id)
	var classes_value: Variant = _classes.get("classes", {})
	var classes: Dictionary = classes_value if classes_value is Dictionary else {}
	var class_value: Variant = classes.get(class_id, {})
	if not (class_value is Dictionary) or class_value.is_empty():
		var legacy_value: Variant = _progression.get("classes", {})
		var legacy: Dictionary = legacy_value if legacy_value is Dictionary else {}
		class_value = legacy.get(class_id, legacy.get("warrior", legacy.get("fighter", {})))
	if class_value is Dictionary:
		return class_value
	return {}

static func normalize_class_id(class_id: String) -> String:
	return "warrior" if class_id == "fighter" else class_id

static func get_base_classes() -> Dictionary:
	_load_all()
	var value: Variant = _classes.get("classes", {})
	return value if value is Dictionary else {}

static func get_base_class(class_id: String) -> Dictionary:
	var classes := get_base_classes()
	var value: Variant = classes.get(normalize_class_id(class_id), {})
	return value if value is Dictionary else {}

static func get_class_action(class_id: String, slot: String) -> Dictionary:
	var class_data := get_base_class(class_id)
	var actions_value: Variant = class_data.get("actions", {})
	var actions: Dictionary = actions_value if actions_value is Dictionary else {}
	var value: Variant = actions.get(slot, {})
	return value if value is Dictionary else {}

static func get_class_resource_max() -> int:
	_load_all()
	return int(_classes.get("resource_max", 3))

static func get_class_resource_rules(class_id: String) -> Dictionary:
	var value: Variant = get_base_class(class_id).get("resource_rules", {})
	return value.duplicate(true) if value is Dictionary else {"max": get_class_resource_max(), "special_cost": 2, "gain": []}

static func get_action_tooltip(class_id: String, slot: String) -> String:
	var action := get_class_action(class_id, slot)
	if action.is_empty(): return ""
	var lines: Array[String] = [String(action.get("description", ""))]
	var target: Dictionary = action.get("targeting", {})
	lines.append("Target: %s · Range %d" % [String(target.get("type", "none")).replace("_", " ").capitalize(), int(target.get("range", 0))])
	if action.has("cost"): lines.append("Cost: %d %s" % [int(action["cost"]), String(get_base_class(class_id).get("resource", "Power"))])
	for effect in action.get("effects", []): lines.append("• %s" % String(effect))
	for modifier in action.get("modifiers", []):
		if modifier is Dictionary: lines.append("• %s" % String(modifier.get("text", "")))
	return "\n".join(lines)

static func validate_base_classes() -> Array[String]:
	var errors: Array[String] = []
	for class_id in ["warrior", "mage", "healer", "tank", "phantom", "summoner"]:
		var data := get_base_class(class_id)
		for key in ["name", "base_stats", "primary", "stat_growth", "derived", "resource_rules", "actions"]:
			if not data.has(key): errors.append("%s missing %s" % [class_id, key])
		for stat_id in ["str", "dex", "con", "int", "wis", "cha"]:
			if not data.get("base_stats", {}).has(stat_id): errors.append("%s missing %s" % [class_id, stat_id])
		for slot in ["basic", "special", "defensive", "movement"]:
			var action: Variant = data.get("actions", {}).get(slot, {})
			if not (action is Dictionary) or String(action.get("id", "")).is_empty() or not action.has("targeting"):
				errors.append("%s invalid %s action" % [class_id, slot])
	return errors

static func get_merchants() -> Dictionary:
	_load_all()
	var value: Variant = _merchants.get("merchants", {})
	return value if value is Dictionary else {}

static func get_merchant(merchant_id: String) -> Dictionary:
	var value: Variant = get_merchants().get(merchant_id, {})
	return value.duplicate(true) if value is Dictionary else {}

static func get_merchant_rank_requirements() -> Array:
	_load_all()
	var value: Variant = _merchants.get("rank_requirements", [])
	return value if value is Array else []

static func get_merchant_rank_name(rank: int) -> String:
	_load_all()
	var names: Variant = _merchants.get("rank_names", [])
	if names is Array and rank >= 0 and rank < names.size():
		return String(names[rank])
	return "Stranger"

static func get_merchant_stock_for_rarity(rarity: String) -> int:
	_load_all()
	var values: Variant = _merchants.get("stock_by_rarity", {})
	var stock: Dictionary = values if values is Dictionary else {}
	return maxi(1, int(stock.get(rarity, stock.get("common", 5))))

static func is_favor_exclusive_item(item_id: String) -> bool:
	for merchant_value in get_merchants().values():
		if not (merchant_value is Dictionary):
			continue
		var stock: Variant = merchant_value.get("stock", [])
		if not (stock is Array):
			continue
		for offer_value in stock:
			if offer_value is Dictionary and int(offer_value.get("favor", 0)) > 0 and String(offer_value.get("item_id", "")) == item_id:
				return true
	return false

static func get_consumables() -> Dictionary:
	_load_all()
	var value: Variant = _consumables.get("consumables", {})
	return value if value is Dictionary else {}

static func get_consumable(consumable_id: String) -> Dictionary:
	var value: Variant = get_consumables().get(consumable_id, {})
	return value.duplicate(true) if value is Dictionary else {}

static func get_consumable_base_capacity() -> int:
	_load_all()
	return int(_consumables.get("base_capacity", 4))

static func get_dungeons() -> Dictionary:
	_load_all()
	var value: Variant = _dungeons.get("dungeons", {})
	return value if value is Dictionary else {}

static func get_dungeon(dungeon_id: String) -> Dictionary:
	var value: Variant = get_dungeons().get(dungeon_id, {})
	return value.duplicate(true) if value is Dictionary else {}

static func get_dungeon_order() -> Array:
	_load_all()
	var value: Variant = _dungeons.get("order", [])
	return value.duplicate() if value is Array else get_dungeons().keys()

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
	class_id = "fighter" if normalize_class_id(class_id) == "warrior" else normalize_class_id(class_id)
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
	_classes = _load_json(CLASSES_PATH)
	_item_effects = _load_json(ITEM_EFFECTS_PATH)
	_merchants = _load_json(MERCHANTS_PATH)
	_consumables = _load_json(CONSUMABLES_PATH)
	_dungeons = _load_json(DUNGEONS_PATH)

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
