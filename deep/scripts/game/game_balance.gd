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
const FIELD_ROOMS_PATH := "res://data/field_rooms.json"
const SLASHER_BALANCE_PATH := "res://data/slasher_balance.json"
const STRATEGY_BALANCE_PATH := "res://data/strategy_balance.json"
const SLASHER_JOURNAL_PATH := "res://data/slasher_journal.json"
const SLASHER_PROGRESSION_PATH := "res://data/slasher_progression.json"
const SLASHER_ITEM_EFFECTS_PATH := "res://data/slasher_item_effects.json"

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
static var _field_rooms: Dictionary = {}
static var _slasher_balance: Dictionary = {}
static var _strategy_balance: Dictionary = {}
static var _slasher_journal: Dictionary = {}
static var _slasher_progression: Dictionary = {}
static var _debug_unlock_all_dungeons := false
static var _slasher_item_effects: Dictionary = {}
static var _content_registry: ContentRegistry
static var _loaded := false

static func get_progression() -> Dictionary:
	_load_all()
	return _progression

static func get_slasher_balance(section: String = "") -> Dictionary:
	_load_all()
	if section.is_empty(): return _slasher_balance.duplicate(true)
	var value: Variant = _slasher_balance.get(section, {})
	return value.duplicate(true) if value is Dictionary else {}

static func get_strategy_balance(section: String = "") -> Dictionary:
	_load_all()
	if section.is_empty(): return _strategy_balance.duplicate(true)
	var value: Variant = _strategy_balance.get(section, {})
	return value.duplicate(true) if value is Dictionary else {}

static func get_strategy_value(path: Array, fallback: Variant) -> Variant:
	_load_all()
	return _get_nested(_strategy_balance, path, fallback)

static func get_strategy_class_tuning(class_id: String) -> Dictionary:
	_load_all()
	var classes: Dictionary = Dictionary(_strategy_balance.get("runtime", {})).get("classes", {})
	var value: Variant = classes.get(normalize_class_id(class_id), {})
	return value.duplicate(true) if value is Dictionary else {}

static func get_slasher_class_tuning(class_id: String) -> Dictionary:
	_load_all()
	var classes: Variant = _slasher_balance.get("classes", {})
	var value: Variant = classes.get(normalize_class_id(class_id), {}) if classes is Dictionary else {}
	if not (value is Dictionary) or value.is_empty():
		push_warning("Invalid Slasher class tuning for '%s'." % class_id)
		return {}
	var result:Dictionary=value.duplicate(true)
	for requirement in [{"key":"speed","fallback":185.0},{"key":"collision_radius","fallback":18.0}]:
		var key:String=String(requirement.key);var candidate:Variant=result.get(key)
		if typeof(candidate) not in [TYPE_INT,TYPE_FLOAT]:push_warning("Invalid Slasher numeric tuning '%s.%s'; using %s."%[class_id,key,requirement.fallback]);result[key]=requirement.fallback
	return result

static func get_slasher_ability_tuning(class_id: String, slot: String) -> Dictionary:
	var value: Variant = get_slasher_class_tuning(class_id).get(slot, {})
	if not (value is Dictionary) or value.is_empty():
		push_warning("Invalid Slasher ability tuning for '%s.%s'." % [class_id, slot])
		return {}
	var result:Dictionary=value.duplicate(true)
	var defaults:Dictionary={"cooldown":0.4 if slot=="basic" else 3.0,"resource_cost":2 if slot=="special" else 0,"animation_lock":0.32}
	for key:String in defaults:
		var candidate:Variant=result.get(key)
		if typeof(candidate) not in [TYPE_INT,TYPE_FLOAT]:push_warning("Invalid Slasher numeric tuning '%s.%s.%s'; using %s."%[class_id,slot,key,defaults[key]]);result[key]=defaults[key]
	return result

static func get_slasher_progression(class_id:String)->Dictionary:
	_load_all()
	var classes:Dictionary=Dictionary(_slasher_progression.get("classes",{}));var value:Variant=classes.get(normalize_class_id(class_id),{})
	return value.duplicate(true) if value is Dictionary else {}

static func get_slasher_choices_for_level(class_id:String,level:int,profile:Dictionary)->Array[Dictionary]:
	_load_all();class_id=normalize_class_id(class_id);var choices:Array[Dictionary]=[]
	var selected:Array=_profile_array(profile,"slasher_ability_upgrades")+_profile_array(profile,"slasher_evolution_path")
	if level==3:
		for foundation_value:Variant in _slasher_progression.get("foundations",[]):
			if foundation_value is Dictionary:
				var foundation:Dictionary=foundation_value.duplicate(true);foundation["id"]="%s_foundation_%s"%[class_id,String(foundation.get("key","choice"))];foundation["level"]=3;foundation["type"]="ability"
				if not selected.has(foundation.id):choices.append(foundation)
		return choices
	var progression:Dictionary=get_slasher_progression(class_id);var branches:Array=progression.get("branches",[])
	if level==5:
		for branch_value:Variant in branches:
			if branch_value is Dictionary:
				var branch:Dictionary=branch_value;var branch_id:String=String(branch.get("id",""));var choice:Dictionary={"id":"%s_branch_%s"%[class_id,branch_id],"level":5,"type":"evolution","branch":branch_id,"name":String(branch.get("name",branch_id.capitalize())),"description":String(branch.get("description","")),"flags":[branch_id+"_path"]}
				if not selected.has(choice.id):choices.append(choice)
		return choices
	if level not in [7,9,11,13,17,19]:return choices
	var branch_id:String=_slasher_profile_branch(class_id,profile);var branch:Dictionary=_slasher_branch(class_id,branch_id)
	if branch.is_empty():return choices
	var focus:Array=branch.get("focus",["basic","special"]);var milestone_index:int=[7,9,11,13,17,19].find(level);var slot:String=String(focus[milestone_index%maxi(1,focus.size())]);var templates:Dictionary=Dictionary(_slasher_progression.get("milestone_templates",{}));var level_template:Dictionary=Dictionary(templates.get(str(level),{}));var flags:Array=branch.get("flags",[]);var mechanic_flag:String=String(flags[mini(milestone_index,maxi(0,flags.size()-1))]) if not flags.is_empty() else branch_id+"_mastery"
	for variant:String in ["power","flow"]:
		var choice_id:String="%s_%s_l%d_%s"%[class_id,branch_id,level,variant]
		if selected.has(choice_id):continue
		choices.append({"id":choice_id,"level":level,"type":"ability","branch":branch_id,"slot":slot,"name":"%s %s"%[String(branch.get("name",branch_id.capitalize())),"Mastery" if variant=="power" else "Flow"],"description":"Transform %s through %s."%[slot.capitalize(),"greater impact" if variant=="power" else "faster resource tempo"],"operations":Dictionary(level_template.get(variant,{})).duplicate(true),"flags":[mechanic_flag] if variant=="power" else [mechanic_flag+"_flow"]})
	return choices

static func get_slasher_progression_choice(class_id:String,choice_id:String)->Dictionary:
	var synthetic:Dictionary={"slasher_ability_upgrades":[],"slasher_evolution_path":[]}
	for level:int in [3,5]:
		for choice:Dictionary in get_slasher_choices_for_level(class_id,level,synthetic):
			if String(choice.get("id",""))==choice_id:return choice
	for branch_value:Variant in get_slasher_progression(class_id).get("branches",[]):
		if not (branch_value is Dictionary):continue
		var branch_id:String=String(branch_value.get("id",""));synthetic.slasher_evolution_path=["%s_branch_%s"%[normalize_class_id(class_id),branch_id]]
		for level:int in [7,9,11,13,17,19]:
			for choice:Dictionary in get_slasher_choices_for_level(class_id,level,synthetic):
				if String(choice.get("id",""))==choice_id:return choice
	return {}

static func get_effective_slasher_ability_tuning(class_id:String,slot:String,selected_choices:Array)->Dictionary:
	var tuning:Dictionary=get_slasher_ability_tuning(class_id,slot);var flags:Array[String]=[]
	for choice_value:Variant in selected_choices:
		var choice:Dictionary=get_slasher_progression_choice(class_id,String(choice_value))
		if choice.is_empty():continue
		var choice_slot:String=String(choice.get("slot",""));var applies:bool=choice_slot.is_empty() or choice_slot==slot
		if applies:
			_apply_slasher_operations(tuning,Dictionary(choice.get("operations",{})))
			for flag_value:Variant in choice.get("flags",[]):
				var flag:String=String(flag_value)
				if not flags.has(flag):flags.append(flag)
	_apply_slasher_flag_effects(tuning,flags,slot);tuning["progression_flags"]=flags;return tuning

static func get_effective_slasher_companion_tuning(class_id:String,companion_id:String,selected_choices:Array)->Dictionary:
	var tuning:Dictionary=get_slasher_companion_tuning(companion_id);var flags:Array[String]=[]
	if normalize_class_id(class_id)!="summoner":return tuning
	for choice_value:Variant in selected_choices:
		var choice:Dictionary=get_slasher_progression_choice(class_id,String(choice_value));var choice_id:String=String(choice.get("id",""))
		if choice.is_empty() or not choice_id.contains("packmaster") and not choice_id.contains("warden") and not choice_id.contains("wildrider"):continue
		var operations:Dictionary=Dictionary(choice.get("operations",{}))
		if choice_id.ends_with("_power"):
			_apply_slasher_operations(tuning,{"damage_coefficient":operations.get("damage_coefficient",{"multiply":1.15}),"pounce_range":{"multiply":1.10}})
		else:_apply_slasher_operations(tuning,{"attack_cooldown":{"multiply":0.88},"combat_speed":{"multiply":1.10},"resource_gain":operations.get("resource_gain",{"add":0})})
		for flag_value:Variant in choice.get("flags",[]):flags.append(String(flag_value))
	_apply_slasher_flag_effects(tuning,flags,"companion");tuning["progression_flags"]=flags;return tuning

static func _apply_slasher_flag_effects(tuning:Dictionary,flags:Array[String],slot:String)->void:
	for flag:String in flags:
		if flag.contains("splash") or flag.contains("widen") or flag.contains("aura") or flag.contains("growth"):
			if tuning.has("area_radius"):tuning.area_radius=float(tuning.area_radius)*1.20
			elif tuning.has("reach"):tuning.reach=float(tuning.reach)*1.18
			elif tuning.has("pounce_range"):tuning.pounce_range=float(tuning.pounce_range)*1.20
		if flag.contains("chain") or flag.contains("echo") or flag.contains("double") or flag.contains("trail") or flag.contains("aftershock") or flag.contains("trample"):
			tuning["echo_damage_multiplier"]=maxf(float(tuning.get("echo_damage_multiplier",0.0)),0.45);tuning["piercing"]=true
		if flag.contains("refund") or flag.contains("overflow") or flag.contains("surge"):
			tuning["resource_refund_on_hit"]=maxi(int(tuning.get("resource_refund_on_hit",0)),1)
		if flag.contains("hidden") and tuning.has("hidden_duration"):tuning.hidden_duration=float(tuning.hidden_duration)+0.35
		if flag.contains("threshold") and tuning.has("low_health_fraction"):tuning.low_health_fraction=minf(0.85,float(tuning.low_health_fraction)+0.15)
		if flag.contains("store") and tuning.has("storage_fraction"):tuning.storage_fraction=minf(1.0,float(tuning.storage_fraction)+0.15)
		if flag.contains("persist") and tuning.has("effect_duration"):tuning.effect_duration=float(tuning.effect_duration)*1.35
		if flag.contains("frenzy") or flag.contains("rapid_cast") or flag.contains("fury_speed"):tuning.cooldown=float(tuning.get("cooldown",1.0))*0.85
		if flag.ends_with("capstone"):
			if tuning.has("damage_coefficient"):tuning.damage_coefficient=float(tuning.damage_coefficient)*1.20
			if tuning.has("cooldown"):tuning.cooldown=float(tuning.cooldown)*0.82
	if slot=="companion" and not flags.is_empty():tuning.combat_speed=float(tuning.get("combat_speed",145.0))*1.08

static func _apply_slasher_operations(tuning:Dictionary,operations:Dictionary)->void:
	for key_value:Variant in operations:
		var key:String=String(key_value)
		if not tuning.has(key) or typeof(tuning[key]) not in [TYPE_INT,TYPE_FLOAT]:continue
		var operation_value:Variant=operations[key]
		if not (operation_value is Dictionary):continue
		var operation:Dictionary=operation_value;var value:float=float(tuning[key])
		if operation.has("multiply"):value*=float(operation.multiply)
		if operation.has("add"):value+=float(operation.add)
		if operation.has("set"):value=float(operation.set)
		if operation.has("min"):value=maxf(value,float(operation.min))
		if operation.has("max"):value=minf(value,float(operation.max))
		tuning[key]=roundi(value) if typeof(tuning[key])==TYPE_INT else value

static func _slasher_branch(class_id:String,branch_id:String)->Dictionary:
	for value:Variant in get_slasher_progression(class_id).get("branches",[]):
		if value is Dictionary and String(value.get("id",""))==branch_id:return value.duplicate(true)
	return {}

static func _slasher_profile_branch(class_id:String,profile:Dictionary)->String:
	for value:Variant in _profile_array(profile,"slasher_evolution_path"):
		var choice:Dictionary=get_slasher_progression_choice(class_id,String(value))
		if not choice.is_empty() and int(choice.get("level",0))==5:return String(choice.get("branch",""))
	return ""

static func get_slasher_enemy_tuning(kind: String) -> Dictionary:
	_load_all()
	var enemies: Variant = _slasher_balance.get("enemies", {})
	var value: Variant = enemies.get(kind, {}) if enemies is Dictionary else {}
	if not (value is Dictionary) or value.is_empty():
		push_warning("Invalid Slasher enemy tuning for '%s'." % kind)
		return {}
	return value.duplicate(true)

static func get_slasher_enemy_visual_tuning(visual_id:String)->Dictionary:
	_load_all()
	var visuals:Variant=_slasher_balance.get("enemy_visuals",{})
	var value:Variant=visuals.get(visual_id,{}) if visuals is Dictionary else {}
	if not (value is Dictionary) or value.is_empty():
		push_warning("Missing Slasher enemy visual tuning for '%s'; using presentation defaults."%visual_id)
		return {"sprite_offset_x":0.0,"sprite_offset_y":-18.0,"sprite_scale":0.7}
	return value.duplicate(true)

static func get_slasher_wolf_archetype(archetype_id:String)->Dictionary:
	_load_all()
	var archetypes:Variant=_slasher_balance.get("wolf_archetypes",{})
	var value:Variant=archetypes.get(archetype_id,{}) if archetypes is Dictionary else {}
	return value.duplicate(true) if value is Dictionary else {}

static func get_slasher_wolfmaster_tuning()->Dictionary:
	_load_all()
	var value:Variant=_slasher_balance.get("wolfmaster",{})
	return value.duplicate(true) if value is Dictionary else {}

static func get_slasher_companion_tuning(companion_id: String) -> Dictionary:
	_load_all()
	var companions: Variant = _slasher_balance.get("companions", {})
	var value: Variant = companions.get(companion_id, {}) if companions is Dictionary else {}
	if not (value is Dictionary) or value.is_empty():
		push_warning("Invalid Slasher companion tuning for '%s'." % companion_id)
		return {}
	return value.duplicate(true)

static func get_slasher_journal()->Dictionary:
	_load_all()
	return _slasher_journal.duplicate(true)

static func get_slasher_journal_entry(enemy_id:String)->Dictionary:
	var entries:Variant=get_slasher_journal().get("entries",{})
	var value:Variant=entries.get(enemy_id,{}) if entries is Dictionary else {}
	return value.duplicate(true) if value is Dictionary else {}

static func get_slasher_item_effects(item_id:String)->Dictionary:
	_load_all()
	var authored:Variant=Dictionary(_slasher_item_effects.get("items",{})).get(item_id,{})
	var record:Dictionary=authored.duplicate(true) if authored is Dictionary else {}
	var item:Dictionary=get_item(item_id)
	if item.is_empty():return {}
	var conversions:Dictionary={}
	var modifiers:Dictionary=Dictionary(item.get("modifiers",{}))
	for key_value:Variant in modifiers:
		var key:String=String(key_value);var value:float=float(modifiers[key_value])
		match key:
			"attack_bonus":conversions["attack_power"]=value
			"spell_power":conversions["spell_power"]=value
			"defense":conversions["damage_reduction"]=minf(0.30,value*0.035)
			"threshold":conversions["flat_prevention"]=value
			"initiative_modifier":conversions["cooldown_reduction"]=minf(0.35,value*0.025)
			"movement":conversions["speed_multiplier"]=1.0+value*0.05;conversions["mobility_multiplier"]=1.0+value*0.05
			"accuracy":conversions["precision_hits"]=maxi(2,7-int(value))
			"penetration":conversions["elite_damage_multiplier"]=1.0+value*0.08
			"evasion":conversions["defense_window_bonus"]=value*0.06
			"range":conversions["range_pixels"]=value*48.0
			_:conversions[key]=value
	var authored_conversions:Dictionary=Dictionary(record.get("conversions",{}));authored_conversions.merge(conversions,true);record["conversions"]=authored_conversions
	if not record.has("rules"):
		var summary:Array[String]=[]
		for conversion_key:Variant in conversions:summary.append("%s %s"%[String(conversion_key).replace("_"," ").capitalize(),str(conversions[conversion_key])])
		record["rules"]="Slasher: %s."%(", ".join(summary) if not summary.is_empty() else "activates a deterministic combat effect on its listed trigger")
	record["trigger"]=String(record.get("trigger","passive"));record["internal_cooldown"]=float(record.get("internal_cooldown",0.0))
	return record

static func get_slasher_item_rules_text(item_id:String)->String:return String(get_slasher_item_effects(item_id).get("rules",""))
static func get_slasher_item_stat_conversions(item_id:String)->Dictionary:return Dictionary(get_slasher_item_effects(item_id).get("conversions",{})).duplicate(true)

static func get_slasher_chest_rarity_weights(floor_number:int,endless_cycle:int=0)->Dictionary:
	_load_all();var weights:Dictionary=get_rarity_weights(clampi(floor_number,1,5)).duplicate(true)
	if endless_cycle<=0:return weights
	var scaling:Dictionary=Dictionary(_slasher_item_effects.get("endless_rarity",{}));var shift:int=endless_cycle*int(scaling.get("shift_per_cycle",4))
	weights["common"]=maxi(0,int(weights.get("common",0))-shift*2);weights["uncommon"]=maxi(0,int(weights.get("uncommon",0))-shift)
	weights["rare"]=int(weights.get("rare",0))+shift;weights["very_rare"]=int(weights.get("very_rare",0))+shift
	weights["legendary"]=mini(int(scaling.get("legendary_weight_cap",15)),int(weights.get("legendary",0))+maxi(1,endless_cycle*int(scaling.get("legendary_per_cycle",2))))
	return weights

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
	_load_all()
	return _content_registry.canonical_id("classes", class_id) if _content_registry != null else class_id

static func get_content_registry() -> ContentRegistry:
	_load_all()
	return _content_registry

static func get_base_classes() -> Dictionary:
	_load_all()
	var value: Variant = _classes.get("classes", {})
	return value if value is Dictionary else {}

static func get_base_class(class_id: String) -> Dictionary:
	var classes := get_base_classes()
	var value: Variant = classes.get(normalize_class_id(class_id), {})
	if not (value is Dictionary): return {}
	_load_all()
	var overrides: Dictionary = Dictionary(_strategy_balance.get("characters", {}))
	var class_override: Variant = overrides.get(normalize_class_id(class_id), {})
	return _deep_merge(value, class_override) if class_override is Dictionary else value

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
	for class_id in ["warrior", "mage", "healer", "tank", "rogue", "summoner"]:
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

static func get_field_room_templates(signature: String) -> Array[Dictionary]:
	_load_all()
	var result: Array[Dictionary] = []
	for value in _field_rooms.get("templates", []):
		if value is Dictionary and String(value.get("signature", "")) == signature: result.append(value.duplicate(true))
	return result

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

static func are_all_dungeons_unlocked_for_testing() -> bool:
	_load_all()
	return _debug_unlock_all_dungeons

static func set_debug_unlock_all_dungeons(enabled: bool) -> void:
	_debug_unlock_all_dungeons = enabled

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
	_field_rooms = _load_json(FIELD_ROOMS_PATH)
	_slasher_balance = _load_json(SLASHER_BALANCE_PATH)
	_strategy_balance = _load_json(STRATEGY_BALANCE_PATH)
	_slasher_journal = _load_json(SLASHER_JOURNAL_PATH)
	_slasher_progression = _load_json(SLASHER_PROGRESSION_PATH)
	_slasher_item_effects = _load_json(SLASHER_ITEM_EFFECTS_PATH)
	_content_registry = ContentRegistry.new()
	if _content_registry.load_catalog():
		var catalog_classes := _content_registry.get_legacy_catalog("classes")
		var catalog_dungeons := _content_registry.get_legacy_catalog("dungeons")
		var catalog_merchants := _content_registry.get_legacy_catalog("merchants")
		var catalog_items := _content_registry.get_legacy_catalog("items")
		if not catalog_classes.is_empty():
			_classes["classes"] = catalog_classes
		if not catalog_dungeons.is_empty():
			_dungeons["dungeons"] = catalog_dungeons
		if not catalog_merchants.is_empty():
			_merchants["merchants"] = catalog_merchants
		if not catalog_items.is_empty():
			_items["items"] = catalog_items
	else:
		for diagnostic: String in _content_registry.diagnostics:
			push_warning(diagnostic)

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

static func _deep_merge(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key in overrides.keys():
		var incoming: Variant = overrides[key]
		if result.get(key) is Dictionary and incoming is Dictionary:
			result[key] = _deep_merge(Dictionary(result[key]), Dictionary(incoming))
		else:
			result[key] = incoming.duplicate(true) if incoming is Dictionary or incoming is Array else incoming
	return result

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
