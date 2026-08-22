extends RefCounted
class_name RunState

const MAX_HERO_LEVEL := 20
const FALLBACK_XP_THRESHOLDS := [0, 0, 100, 220, 380, 580, 820, 1100, 1420, 1780, 2180, 2620, 3100, 3620, 4180, 4780, 5420, 6100, 6820, 7580, 8380]
const FALLBACK_CLASS_STATS := {
	"fighter": {"str": 16, "dex": 12, "con": 15, "int": 8, "wis": 10, "cha": 10},
	"mage": {"str": 8, "dex": 14, "con": 11, "int": 16, "wis": 12, "cha": 10},
}
const FALLBACK_DERIVED_CONFIG := {
	"fighter": {
		"max_health": {"base": 12, "per_level": 3, "stat": "con"},
		"attack_bonus": {"stat": "str", "stat_offset": -2, "min": 1, "per_levels": 4},
		"spell_power": {"flat": 0},
		"defense": {"stat": "con", "stat_offset": -1, "min": 0, "per_levels": 5},
		"initiative_modifier": {"base": 1, "stat": "dex", "stat_offset": -1, "min": 0, "per_levels": 6},
		"potion_heal_bonus": {"stat": "wis", "stat_offset": 0, "min": 0, "per_levels": 5, "level_basis": "level"},
	},
	"mage": {
		"max_health": {"base": 10, "per_level": 2, "stat": "con"},
		"attack_bonus": {"flat": 0},
		"spell_power": {"stat": "int", "stat_offset": -2, "min": 1, "per_levels": 4},
		"defense": {"stat": "dex", "stat_offset": -2, "min": 0, "per_levels": 6},
		"initiative_modifier": {"base": 2, "stat": "dex", "stat_offset": -2, "min": 0, "per_levels": 6},
		"potion_heal_bonus": {"stat": "wis", "stat_offset": 0, "min": 0, "per_levels": 5, "level_basis": "level"},
	},
}

var selected_gear: GearData
var selected_class_id: String = "fighter"
var selected_class_name: String = "Fighter"
var current_health: int = 12
var max_health: int = 12
var gold: int = 0
var keys: int = 0
var potions: int = 0
var floor_seed: int = 1001
var current_floor: int = 1
var max_floors: int = 5
var run_outcome: String = "The bartender polishes a glass and waits."
var completed_runs: int = 0
var deaths: int = 0
var hero_profiles: Dictionary = {}
var pending_level_logs: Array[String] = []
var inventory_items: Array[Dictionary] = []
var pending_chest_choices: Array[String] = []
var starter_reward_claimed: bool = false

func _init() -> void:
	_ensure_profiles()
	_sync_health_from_profile(true)

func set_class(class_id: String) -> void:
	selected_class_id = class_id
	selected_class_name = "Mage" if class_id == "mage" else "Fighter"
	_ensure_profiles()
	_restore_permanent_inventory_for_active_class()
	recalculate_derived_stats()
	_sync_health_from_profile(true)

func start_new_run(gear: GearData) -> void:
	selected_gear = gear
	_ensure_profiles()
	_restore_permanent_inventory_for_active_class()
	pending_chest_choices.clear()
	starter_reward_claimed = false
	recalculate_derived_stats()
	_sync_health_from_profile(true)
	gold = 0
	keys = 0
	potions = 0
	current_floor = 1
	floor_seed += 37
	run_outcome = "The forest door opens. The tavern falls quiet behind you."

func advance_floor() -> bool:
	if current_floor >= max_floors:
		return false
	current_floor += 1
	_tick_inventory_floor_durations()
	return true

func get_current_floor_seed() -> int:
	return floor_seed + current_floor * 997

func finish_run(outcome: String, message: String) -> void:
	run_outcome = message
	if outcome == "victory":
		completed_runs += 1
	elif outcome == "death":
		deaths += 1
		_clear_permanent_inventory_for_active_class()
	selected_gear = null

func heal(amount: int) -> void:
	_sync_health_from_profile(false)
	current_health = mini(max_health, current_health + amount)

func hurt(amount: int) -> void:
	_sync_health_from_profile(false)
	current_health = maxi(0, current_health - amount)

func get_level() -> int:
	return int(_active_profile()["level"])

func get_xp_to_next_level() -> int:
	var profile: Dictionary = _active_profile()
	var level: int = int(profile["level"])
	if level >= _max_level():
		return 0
	return _xp_required_for_level(level + 1) - int(profile["xp"])

func get_stats() -> Dictionary:
	var profile: Dictionary = _active_profile()
	var stats_value: Variant = profile.get("stats", {})
	var stats: Dictionary = stats_value if stats_value is Dictionary else {}
	return stats.duplicate(true)

func get_derived_stat(stat_id: String) -> int:
	var profile: Dictionary = _active_profile()
	var derived_value: Variant = profile.get("derived_stats", {})
	var derived: Dictionary = derived_value if derived_value is Dictionary else {}
	return int(derived.get(stat_id, 0))

func get_active_item_modifier_value(stat_id: String) -> int:
	return int(get_active_item_modifiers().get(stat_id, 0))

func apply_reward_bonus(base_amount: int, reward_type: String) -> int:
	var modifier_id := "%s_bonus_percent" % reward_type
	var bonus_percent: int = get_active_item_modifier_value(modifier_id)
	return maxi(0, int(round(float(base_amount) * (1.0 + float(bonus_percent) / 100.0))))

func get_profile_summary() -> String:
	var profile: Dictionary = _active_profile()
	var level: int = int(profile["level"])
	if level >= _max_level():
		return "Lv %d  XP Max" % level
	return "Lv %d  XP %d/%d" % [level, int(profile["xp"]), _xp_required_for_level(level + 1)]

func gain_xp(amount: int, reason: String) -> Array[String]:
	_ensure_profiles()
	var logs: Array[String] = []
	if amount <= 0:
		return logs
	var profile: Dictionary = _active_profile()
	var old_max_health: int = int(profile["derived_stats"]["max_health"])
	profile["xp"] = int(profile["xp"]) + amount
	profile["total_xp"] = int(profile["total_xp"]) + amount
	logs.append("+%d XP: %s." % [amount, reason])
	while int(profile["level"]) < _max_level() and int(profile["xp"]) >= _xp_required_for_level(int(profile["level"]) + 1):
		profile["level"] = int(profile["level"]) + 1
		_recalculate_profile(profile)
		var new_max_health: int = int(profile["derived_stats"]["max_health"])
		var health_gain: int = maxi(0, new_max_health - old_max_health)
		max_health = new_max_health
		current_health = mini(max_health, current_health + health_gain)
		old_max_health = new_max_health
		logs.append("%s reaches level %d. Max HP +%d." % [selected_class_name, int(profile["level"]), health_gain])
		logs.append_array(_enqueue_progression_choices(profile, int(profile["level"])))
	hero_profiles[selected_class_id] = profile
	_sync_health_from_profile(false)
	pending_level_logs.append_array(logs)
	return logs

func recalculate_derived_stats() -> void:
	_ensure_profiles()
	for class_id in hero_profiles.keys():
		var profile_value: Variant = hero_profiles[class_id]
		var profile: Dictionary = profile_value if profile_value is Dictionary else {}
		_recalculate_profile(profile)
		hero_profiles[class_id] = profile
	_sync_health_from_profile(false)

func generate_chest_choices(floor: int, source_rng: RandomNumberGenerator) -> Array[String]:
	var choices: Array[String] = []
	var loot_table: Dictionary = GameBalance.get_loot_table()
	var choice_count: int = int(loot_table.get("choice_count", 3))
	var items: Dictionary = GameBalance.get_items()
	var attempts := 0
	while choices.size() < choice_count and attempts < 80:
		attempts += 1
		var rarity: String = _roll_item_rarity(floor, source_rng)
		var candidates: Array[String] = _item_ids_for_rarity(items, rarity)
		if candidates.is_empty():
			candidates = _all_item_ids(items)
		if candidates.is_empty():
			break
		var item_id: String = candidates[source_rng.randi_range(0, candidates.size() - 1)]
		if not choices.has(item_id):
			choices.append(item_id)
	pending_chest_choices.clear()
	pending_chest_choices.append_array(choices)
	return choices

func choose_chest_item(item_id: String) -> Array[String]:
	var logs: Array[String] = []
	if not pending_chest_choices.has(item_id):
		logs.append("That relic fades before you can claim it.")
		return logs
	logs.append_array(add_inventory_item(item_id, current_floor))
	pending_chest_choices.clear()
	return logs

func choose_starter_item(item_id: String) -> Array[String]:
	var logs: Array[String] = []
	if starter_reward_claimed:
		logs.append("The opening boon has already been claimed.")
		return logs
	if not pending_chest_choices.has(item_id):
		logs.append("That relic fades before you can claim it.")
		return logs
	logs.append_array(add_inventory_item(item_id, current_floor))
	pending_chest_choices.clear()
	starter_reward_claimed = true
	return logs

func add_inventory_item(item_id: String, source_floor: int) -> Array[String]:
	var item: Dictionary = GameBalance.get_item(item_id)
	if item.is_empty():
		return ["The chest sputters; its relic is missing from the catalog."]
	var entry: Dictionary = _make_inventory_entry(item_id, item, source_floor)
	inventory_items.append(entry)
	if String(entry["duration_type"]) == "permanent":
		var profile: Dictionary = _active_profile()
		var permanent_items_value: Variant = profile.get("permanent_items", [])
		var permanent_items: Array = permanent_items_value if permanent_items_value is Array else []
		permanent_items.append(entry.duplicate(true))
		profile["permanent_items"] = permanent_items
		hero_profiles[selected_class_id] = profile
	recalculate_derived_stats()
	return ["Claimed %s." % String(item.get("name", item_id))]

func get_inventory_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for entry in inventory_items:
		items.append(entry.duplicate(true))
	return items

func get_active_item_modifiers() -> Dictionary:
	var modifiers: Dictionary = {}
	for entry in inventory_items:
		var item: Dictionary = GameBalance.get_item(String(entry.get("id", "")))
		var item_modifiers_value: Variant = item.get("modifiers", {})
		if not (item_modifiers_value is Dictionary):
			continue
		var item_modifiers: Dictionary = item_modifiers_value
		for key in item_modifiers.keys():
			modifiers[String(key)] = int(modifiers.get(String(key), 0)) + int(item_modifiers[key])
	return modifiers

func get_resource_summary() -> String:
	return "Gold %d | Keys %d | Potions %d" % [gold, keys, potions]

func consume_pending_level_logs() -> Array[String]:
	var logs: Array[String] = []
	logs.append_array(pending_level_logs)
	pending_level_logs.clear()
	return logs

func has_pending_progression_choice() -> bool:
	var pending: Array = _profile_array(_active_profile(), "pending_progression_choices")
	return not pending.is_empty()

func get_pending_progression_choice() -> Dictionary:
	var pending: Array = _profile_array(_active_profile(), "pending_progression_choices")
	if pending.is_empty() or not (pending[0] is Dictionary):
		return {}
	return pending[0].duplicate(true)

func choose_progression_choice(choice_id: String) -> Array[String]:
	var logs: Array[String] = []
	var profile: Dictionary = _active_profile()
	var pending: Array = _profile_array(profile, "pending_progression_choices")
	if pending.is_empty() or not (pending[0] is Dictionary):
		return logs
	var pending_choice: Dictionary = pending[0]
	var choices: Array = _profile_array(pending_choice, "choices")
	var selected_choice: Dictionary = {}
	for choice in choices:
		if not (choice is Dictionary):
			continue
		var choice_dict: Dictionary = choice
		if String(choice_dict.get("id", "")) == choice_id:
			selected_choice = choice_dict
			break
	if selected_choice.is_empty():
		logs.append("That progression choice is no longer available.")
		return logs
	var old_derived_value: Variant = profile.get("derived_stats", {})
	var old_derived: Dictionary = old_derived_value if old_derived_value is Dictionary else {}
	var old_max_health: int = int(old_derived.get("max_health", max_health))
	var choice_type: String = String(pending_choice.get("type", "ability"))
	if choice_type == "evolution":
		var path: Array = _profile_array(profile, "evolution_path")
		path.append(choice_id)
		profile["evolution_path"] = path
		logs.append("%s evolves: %s." % [selected_class_name, String(selected_choice.get("name", choice_id))])
	else:
		var upgrades: Array = _profile_array(profile, "ability_upgrades")
		upgrades.append(choice_id)
		profile["ability_upgrades"] = upgrades
		logs.append("Ability upgraded: %s." % String(selected_choice.get("name", choice_id)))
	pending.remove_at(0)
	profile["pending_progression_choices"] = pending
	logs.append_array(_enqueue_missing_progression_choices(profile))
	hero_profiles[selected_class_id] = profile
	recalculate_derived_stats()
	var new_max_health: int = get_derived_stat("max_health")
	var health_gain: int = maxi(0, new_max_health - old_max_health)
	if health_gain > 0:
		logs.append("Max HP +%d." % health_gain)
	pending_level_logs.append_array(logs)
	return logs

func get_progression_summary() -> String:
	var profile: Dictionary = _active_profile()
	if String(profile.get("class_id", selected_class_id)) != "mage":
		return "No class evolution chosen."
	var path: Array = _profile_array(profile, "evolution_path")
	var upgrades: Array = _profile_array(profile, "ability_upgrades")
	var path_names: Array[String] = []
	for choice_id in path:
		path_names.append(_progression_choice_name(String(choice_id)))
	var upgrade_names: Array[String] = []
	for choice_id in upgrades:
		upgrade_names.append(_progression_choice_name(String(choice_id)))
	var path_text: String = "Unevolved" if path_names.is_empty() else " -> ".join(path_names)
	var upgrade_text: String = "No ability upgrades" if upgrade_names.is_empty() else ", ".join(upgrade_names)
	return "Path: %s\nUpgrades: %s" % [path_text, upgrade_text]

func get_current_evolution_name() -> String:
	var path: Array = _profile_array(_active_profile(), "evolution_path")
	if path.is_empty():
		return ""
	return _progression_choice_name(String(path[path.size() - 1]))

func get_progression_flag_value(flag_id: String) -> int:
	var flags: Dictionary = _selected_progression_flags(_active_profile())
	return int(flags.get(flag_id, 0))

func _ensure_profiles() -> void:
	if not hero_profiles.has("fighter"):
		hero_profiles["fighter"] = _create_profile("fighter")
	if not hero_profiles.has("mage"):
		hero_profiles["mage"] = _create_profile("mage")
	for class_id in hero_profiles.keys():
		var profile_value: Variant = hero_profiles[class_id]
		var profile: Dictionary = profile_value if profile_value is Dictionary else {}
		if not profile.has("permanent_items"):
			profile["permanent_items"] = []
		if not profile.has("evolution_path"):
			profile["evolution_path"] = []
		if not profile.has("ability_upgrades"):
			profile["ability_upgrades"] = []
		if not profile.has("pending_progression_choices"):
			profile["pending_progression_choices"] = []
		hero_profiles[class_id] = profile

func _create_profile(class_id: String) -> Dictionary:
	var profile: Dictionary = {
		"class_id": class_id,
		"level": 1,
		"xp": 0,
		"total_xp": 0,
		"base_stats": _base_stats_for_class(class_id),
		"stats": {},
		"derived_stats": {},
		"permanent_items": [],
		"evolution_path": [],
		"ability_upgrades": [],
		"pending_progression_choices": [],
	}
	_recalculate_profile(profile)
	return profile

func _base_stats_for_class(class_id: String) -> Dictionary:
	var class_data: Dictionary = GameBalance.get_class_data(class_id)
	var fallback_value: Variant = FALLBACK_CLASS_STATS.get(class_id, FALLBACK_CLASS_STATS["fighter"])
	var fighter_fallback_value: Variant = FALLBACK_CLASS_STATS["fighter"]
	var fighter_fallback: Dictionary = fighter_fallback_value if fighter_fallback_value is Dictionary else {}
	var fallback: Dictionary = fallback_value if fallback_value is Dictionary else fighter_fallback
	var stats_value: Variant = class_data.get("base_stats", fallback)
	var stats: Dictionary = stats_value if stats_value is Dictionary else fallback
	return stats.duplicate(true)

func _active_profile() -> Dictionary:
	_ensure_profiles()
	var profile_value: Variant = hero_profiles.get(selected_class_id, hero_profiles["fighter"])
	var fighter_profile_value: Variant = hero_profiles["fighter"]
	var fighter_profile: Dictionary = fighter_profile_value if fighter_profile_value is Dictionary else {}
	var profile: Dictionary = profile_value if profile_value is Dictionary else fighter_profile
	return profile

func _recalculate_profile(profile: Dictionary) -> void:
	var class_id: String = String(profile["class_id"])
	var level: int = int(profile["level"])
	var base_stats_value: Variant = profile.get("base_stats", {})
	var base_stats: Dictionary = base_stats_value if base_stats_value is Dictionary else {}
	var stats: Dictionary = base_stats.duplicate(true)
	for gained_level in range(2, level + 1):
		_apply_level_stat_gain(stats, class_id, gained_level)
	profile["stats"] = stats
	var derived_stats: Dictionary = _derive_stats(class_id, level, stats)
	_apply_progression_modifiers_to_derived(profile, derived_stats)
	if class_id == selected_class_id:
		_apply_inventory_modifiers_to_derived(derived_stats)
	profile["derived_stats"] = derived_stats

func _apply_level_stat_gain(stats: Dictionary, class_id: String, level: int) -> void:
	var class_data: Dictionary = GameBalance.get_class_data(class_id)
	var rules_value: Variant = class_data.get("stat_growth", _fallback_growth_rules(class_id))
	var rules: Array = rules_value if rules_value is Array else _fallback_growth_rules(class_id)
	for rule in rules:
		if not (rule is Dictionary):
			continue
		var every: int = maxi(1, int(rule.get("every", 1)))
		if level % every != 0:
			continue
		var stat: String = String(rule.get("stat", ""))
		if stats.has(stat):
			stats[stat] = int(stats[stat]) + int(rule.get("amount", 1))

func _derive_stats(class_id: String, level: int, stats: Dictionary) -> Dictionary:
	var class_data: Dictionary = GameBalance.get_class_data(class_id)
	var derived_value: Variant = class_data.get("derived", _fallback_derived_config(class_id))
	var derived_config: Dictionary = derived_value if derived_value is Dictionary else _fallback_derived_config(class_id)
	return {
		"max_health": _derive_stat_value(derived_config.get("max_health", {}), level, stats, true),
		"attack_bonus": _derive_stat_value(derived_config.get("attack_bonus", {}), level, stats, false),
		"spell_power": _derive_stat_value(derived_config.get("spell_power", {}), level, stats, false),
		"defense": _derive_stat_value(derived_config.get("defense", {}), level, stats, false),
		"initiative_modifier": _derive_stat_value(derived_config.get("initiative_modifier", {}), level, stats, false),
		"potion_heal_bonus": _derive_stat_value(derived_config.get("potion_heal_bonus", {}), level, stats, false),
		"movement": 0,
		"block_bonus": 0,
	}

func _apply_inventory_modifiers_to_derived(derived_stats: Dictionary) -> void:
	var modifiers: Dictionary = get_active_item_modifiers()
	for key in modifiers.keys():
		if String(key).ends_with("_bonus_percent"):
			continue
		derived_stats[String(key)] = int(derived_stats.get(String(key), 0)) + int(modifiers[key])

func _apply_progression_modifiers_to_derived(profile: Dictionary, derived_stats: Dictionary) -> void:
	var modifiers: Dictionary = _selected_progression_modifiers(profile)
	for key in modifiers.keys():
		derived_stats[String(key)] = int(derived_stats.get(String(key), 0)) + int(modifiers[key])

func _derive_stat_value(config_value: Variant, level: int, stats: Dictionary, include_level_base: bool) -> int:
	if not (config_value is Dictionary):
		return 0
	var config: Dictionary = config_value
	if config.has("flat"):
		return int(config["flat"])
	var value: int = int(config.get("base", 0))
	if include_level_base:
		value += (level - 1) * int(config.get("per_level", 0))
	var stat_name: String = String(config.get("stat", ""))
	if not stat_name.is_empty() and stats.has(stat_name):
		value += maxi(int(config.get("min", -999)), _stat_modifier(int(stats[stat_name])) + int(config.get("stat_offset", 0)))
	var per_levels: int = int(config.get("per_levels", 0))
	if per_levels > 0:
		var level_basis: int = level - 1
		if String(config.get("level_basis", "")) == "level":
			level_basis = level
		value += int(floori(float(level_basis) / float(per_levels)))
	return value

func _fallback_growth_rules(class_id: String) -> Array:
	if class_id == "mage":
		return [{"stat": "int", "every": 2}, {"stat": "dex", "every": 3}, {"stat": "con", "every": 5}, {"stat": "wis", "every": 7}]
	return [{"stat": "str", "every": 2}, {"stat": "con", "every": 3}, {"stat": "dex", "every": 5}, {"stat": "wis", "every": 7}]

func _fallback_derived_config(class_id: String) -> Dictionary:
	var fallback_value: Variant = FALLBACK_DERIVED_CONFIG.get(class_id, FALLBACK_DERIVED_CONFIG["fighter"])
	if fallback_value is Dictionary:
		return fallback_value
	return {}

func _enqueue_progression_choices(profile: Dictionary, level: int) -> Array[String]:
	var logs: Array[String] = []
	if String(profile.get("class_id", "")) != "mage":
		return logs
	var pending: Array = _profile_array(profile, "pending_progression_choices")
	if _has_selected_progression_at_level(profile, "evolutions", level) and _has_selected_progression_at_level(profile, "ability_upgrades", level):
		return logs
	var evolution_choices: Array = GameBalance.get_evolution_choices("mage", level, profile)
	if not _has_selected_progression_at_level(profile, "evolutions", level) and not evolution_choices.is_empty() and not _pending_choice_exists(pending, "evolution", level):
		pending.append({"type": "evolution", "level": level, "choices": evolution_choices})
		logs.append("Mage evolution unlocked at level %d." % level)
	var ability_choices: Array = GameBalance.get_ability_upgrade_choices("mage", level, profile)
	if not _has_selected_progression_at_level(profile, "ability_upgrades", level) and not ability_choices.is_empty() and not _pending_choice_exists(pending, "ability", level):
		pending.append({"type": "ability", "level": level, "choices": ability_choices})
		logs.append("Mage ability upgrade unlocked at level %d." % level)
	profile["pending_progression_choices"] = pending
	return logs

func _enqueue_missing_progression_choices(profile: Dictionary) -> Array[String]:
	var logs: Array[String] = []
	var level: int = int(profile.get("level", 1))
	for gained_level in range(2, level + 1):
		logs.append_array(_enqueue_progression_choices(profile, gained_level))
	return logs

func _pending_choice_exists(pending: Array, choice_type: String, level: int) -> bool:
	for entry in pending:
		if entry is Dictionary and String(entry.get("type", "")) == choice_type and int(entry.get("level", -1)) == level:
			return true
	return false

func _has_selected_progression_at_level(profile: Dictionary, list_key: String, level: int) -> bool:
	var selected_ids: Array = _profile_array(profile, "evolution_path") if list_key == "evolutions" else _profile_array(profile, "ability_upgrades")
	for choice_id in selected_ids:
		var choice: Dictionary = GameBalance.get_progression_choice("mage", String(choice_id))
		if int(choice.get("level", -1)) == level:
			return true
	return false

func _selected_progression_modifiers(profile: Dictionary) -> Dictionary:
	var modifiers: Dictionary = {}
	for choice in _selected_progression_choices(profile):
		var choice_modifiers_value: Variant = choice.get("modifiers", {})
		if not (choice_modifiers_value is Dictionary):
			continue
		var choice_modifiers: Dictionary = choice_modifiers_value
		for key in choice_modifiers.keys():
			modifiers[String(key)] = int(modifiers.get(String(key), 0)) + int(choice_modifiers[key])
	return modifiers

func _selected_progression_flags(profile: Dictionary) -> Dictionary:
	var flags: Dictionary = {}
	for choice in _selected_progression_choices(profile):
		var choice_flags_value: Variant = choice.get("flags", {})
		if not (choice_flags_value is Dictionary):
			continue
		var choice_flags: Dictionary = choice_flags_value
		for key in choice_flags.keys():
			flags[String(key)] = int(flags.get(String(key), 0)) + int(choice_flags[key])
	return flags

func _selected_progression_choices(profile: Dictionary) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if String(profile.get("class_id", "")) != "mage":
		return choices
	var selected_ids: Array = _profile_array(profile, "evolution_path") + _profile_array(profile, "ability_upgrades")
	for choice_id in selected_ids:
		var choice: Dictionary = GameBalance.get_progression_choice("mage", String(choice_id))
		if not choice.is_empty():
			choices.append(choice)
	return choices

func _progression_choice_name(choice_id: String) -> String:
	var choice: Dictionary = GameBalance.get_progression_choice("mage", choice_id)
	return String(choice.get("name", choice_id.capitalize()))

func _profile_array(profile: Dictionary, key: String) -> Array:
	var value: Variant = profile.get(key, [])
	if value is Array:
		return value
	return []

func _stat_modifier(value: int) -> int:
	return int(floori(float(value - 10) / 2.0))

func _xp_required_for_level(level: int) -> int:
	var thresholds: Array = GameBalance.get_xp_thresholds()
	if thresholds.is_empty():
		thresholds = FALLBACK_XP_THRESHOLDS
	var clamped_level: int = clampi(level, 1, mini(_max_level(), thresholds.size() - 1))
	return int(thresholds[clamped_level])

func _max_level() -> int:
	return GameBalance.get_max_level(MAX_HERO_LEVEL)

func _sync_health_from_profile(reset_current: bool) -> void:
	_ensure_profiles()
	var profile: Dictionary = _active_profile()
	var derived_value: Variant = profile.get("derived_stats", {})
	var derived: Dictionary = derived_value if derived_value is Dictionary else {}
	var previous_max: int = max_health
	max_health = int(derived.get("max_health", max_health))
	if reset_current:
		current_health = max_health
	else:
		current_health = mini(max_health, current_health + maxi(0, max_health - previous_max))

func _restore_permanent_inventory_for_active_class() -> void:
	var profile: Dictionary = _active_profile()
	var permanent_items_value: Variant = profile.get("permanent_items", [])
	inventory_items.clear()
	if permanent_items_value is Array:
		for entry in permanent_items_value:
			if entry is Dictionary:
				inventory_items.append(entry.duplicate(true))

func _clear_permanent_inventory_for_active_class() -> void:
	var profile: Dictionary = _active_profile()
	profile["permanent_items"] = []
	hero_profiles[selected_class_id] = profile
	for i in range(inventory_items.size() - 1, -1, -1):
		if String(inventory_items[i].get("duration_type", "")) == "permanent":
			inventory_items.remove_at(i)
	recalculate_derived_stats()

func _tick_inventory_floor_durations() -> void:
	var expired_names: Array[String] = []
	for i in range(inventory_items.size() - 1, -1, -1):
		var entry: Dictionary = inventory_items[i]
		if String(entry.get("duration_type", "")) != "temporary":
			continue
		entry["remaining_floors"] = int(entry.get("remaining_floors", 0)) - 1
		if int(entry["remaining_floors"]) <= 0:
			var item: Dictionary = GameBalance.get_item(String(entry.get("id", "")))
			expired_names.append(String(item.get("name", entry.get("id", "Relic"))))
			inventory_items.remove_at(i)
		else:
			inventory_items[i] = entry
	if not expired_names.is_empty():
		pending_level_logs.append("Expired: %s." % ", ".join(expired_names))
	recalculate_derived_stats()

func _make_inventory_entry(item_id: String, item: Dictionary, source_floor: int) -> Dictionary:
	var duration_type: String = String(item.get("duration_type", "dungeon_bound"))
	var remaining_floors := 0
	if duration_type == "temporary":
		remaining_floors = int(item.get("duration_floors", 2))
	return {
		"id": item_id,
		"source_floor": source_floor,
		"duration_type": duration_type,
		"remaining_floors": remaining_floors,
	}

func _roll_item_rarity(floor: int, source_rng: RandomNumberGenerator) -> String:
	var weights: Dictionary = GameBalance.get_rarity_weights(floor)
	var total_weight := 0
	for key in weights.keys():
		total_weight += maxi(0, int(weights[key]))
	if total_weight <= 0:
		return "common"
	var roll := source_rng.randi_range(1, total_weight)
	var running := 0
	for key in weights.keys():
		running += maxi(0, int(weights[key]))
		if roll <= running:
			return String(key)
	return "common"

func _item_ids_for_rarity(items: Dictionary, rarity: String) -> Array[String]:
	var ids: Array[String] = []
	for item_id in items.keys():
		var item_value: Variant = items[item_id]
		if item_value is Dictionary and String(item_value.get("rarity", "common")) == rarity:
			ids.append(String(item_id))
	return ids

func _all_item_ids(items: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for item_id in items.keys():
		ids.append(String(item_id))
	return ids
