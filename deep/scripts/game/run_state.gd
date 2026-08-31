extends RefCounted
class_name RunState

const PLAY_MODE_STRATEGY := "strategy"
const PLAY_MODE_SLASHER := "slasher"
const MAX_HERO_LEVEL := 20
const FALLBACK_XP_THRESHOLDS := [0, 0, 100, 220, 380, 580, 820, 1100, 1420, 1780, 2180, 2620, 3100, 3620, 4180, 4780, 5420, 6100, 6820, 7580, 8380]
const FALLBACK_CLASS_STATS := {
	"warrior": {"str": 16, "dex": 12, "con": 15, "int": 8, "wis": 10, "cha": 10},
	"mage": {"str": 8, "dex": 14, "con": 11, "int": 16, "wis": 12, "cha": 10},
}
const FALLBACK_DERIVED_CONFIG := {
	"warrior": {
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
var selected_gear_by_class: Dictionary = {}
var selected_class_id: String = "warrior"
var selected_class_name: String = "Warrior"
var class_resource: int = 0
var current_health: int = 12
var max_health: int = 12
var gold: int = 0
var keys: int = 0
var potions: int = 0
var floor_seed: int = 1001
var current_floor: int = 1
var max_floors: int = 5
var active_dungeon_id: String = "forest"
var active_play_mode: String = PLAY_MODE_STRATEGY
var last_play_mode: String = PLAY_MODE_STRATEGY
var forest_cleared: bool = false
var crypt_unlocked: bool = false
var completed_dungeons: Dictionary = {}
var field_run: Dictionary = {}
var run_outcome: String = "The bartender polishes a glass and waits."
var completed_runs: int = 0
var deaths: int = 0
var hero_profiles: Dictionary = {}
var pending_level_logs: Array[String] = []
var inventory_items: Array[Dictionary] = []
var pending_chest_choices: Array[String] = []
var starter_reward_claimed: bool = false
var merchant_progress: Dictionary = {}
var pending_shop_items: Array[String] = []
var pending_shop_potions: int = 0
var pending_shop_keys: int = 0
var purchased_favor_offers: Dictionary = {}
var merchant_offer_stock: Dictionary = {}
var consumable_items: Array[String] = []
var pending_shop_consumables: Array[String] = []
var enemy_defeat_counts:Dictionary={}
var slasher_endless_mode:=false
var slasher_campaign_boss_cleared:=false

func record_enemy_defeat(enemy_id:String)->int:
	if enemy_id.is_empty():return 0
	var count:=int(enemy_defeat_counts.get(enemy_id,0))+1;enemy_defeat_counts[enemy_id]=count;return count

func get_enemy_defeat_count(enemy_id:String)->int:return int(enemy_defeat_counts.get(enemy_id,0))
func is_enemy_discovered(enemy_id:String)->bool:return get_enemy_defeat_count(enemy_id)>0
func get_enemy_journal_snapshot()->Dictionary:return enemy_defeat_counts.duplicate(true)

func _init() -> void:
	_ensure_profiles()
	_ensure_merchant_progress()
	_sync_health_from_profile(true)

func set_class(class_id: String) -> void:
	selected_class_id = GameBalance.normalize_class_id(class_id)
	var class_data := GameBalance.get_base_class(selected_class_id)
	selected_class_name = String(class_data.get("name", selected_class_id.capitalize()))
	class_resource = 0
	var stored_gear_value: Variant = selected_gear_by_class.get(selected_class_id, null)
	selected_gear = stored_gear_value if stored_gear_value is GearData else null
	_ensure_profiles()
	_restore_permanent_inventory_for_active_class()
	recalculate_derived_stats()
	_sync_health_from_profile(true)
	_sync_crypt_unlock()

func start_new_run(gear: GearData, dungeon_id: String = "forest", play_mode: String = PLAY_MODE_STRATEGY) -> void:
	selected_gear = gear
	if selected_gear != null:
		selected_gear_by_class[selected_class_id] = selected_gear
	active_dungeon_id = dungeon_id
	active_play_mode = normalize_play_mode(play_mode)
	last_play_mode = active_play_mode
	if active_play_mode==PLAY_MODE_SLASHER:reconcile_slasher_progression()
	var dungeon := GameBalance.get_dungeon(active_dungeon_id)
	# TUNING: Slasher Forest campaign depth is set in dungeons.json under forest.slasher.campaign_floors; Strategy keeps its original floor count.
	var slasher_config:Dictionary=Dictionary(dungeon.get("slasher",{}));max_floors=int(slasher_config.get("campaign_floors",dungeon.get("floors",1))) if active_play_mode==PLAY_MODE_SLASHER else int(dungeon.get("floors",1))
	_ensure_profiles()
	_restore_permanent_inventory_for_active_class()
	pending_chest_choices.clear()
	starter_reward_claimed = false
	recalculate_derived_stats()
	_sync_health_from_profile(true)
	gold = 0
	keys = 0
	potions = 0
	keys += pending_shop_keys
	consumable_items.clear()
	for consumable_id in pending_shop_consumables:
		add_consumable(consumable_id)
	for legacy_index in range(pending_shop_potions):
		add_consumable("healing_potion")
	for item_id in pending_shop_items:
		add_inventory_item(item_id, 1)
	pending_shop_items.clear()
	pending_shop_potions = 0
	pending_shop_consumables.clear()
	pending_shop_keys = 0
	current_floor = 1
	slasher_endless_mode=false;slasher_campaign_boss_cleared=false
	class_resource = 0
	floor_seed += 37
	field_run.clear()
	if String(dungeon.get("dungeon_type", "mystery")) == "field":
		var room_count: Dictionary = dungeon.get("room_count", {"min":10,"max":12})
		field_run = FieldDungeonGenerator.generate(get_current_floor_seed(), int(room_count.get("min", 10)), int(room_count.get("max", 12)))
	run_outcome = "%s opens in %s mode. The tavern falls quiet behind you." % [String(dungeon.get("name", active_dungeon_id.capitalize())), active_play_mode.capitalize()]
	_sync_crypt_unlock()

func normalize_play_mode(play_mode: String) -> String:
	return PLAY_MODE_SLASHER if play_mode.to_lower() == PLAY_MODE_SLASHER else PLAY_MODE_STRATEGY

func dungeon_supports_mode(dungeon_id: String, play_mode: String) -> bool:
	var modes: Array = GameBalance.get_dungeon(dungeon_id).get("supported_modes", [PLAY_MODE_STRATEGY])
	return normalize_play_mode(play_mode) in modes

func advance_floor() -> bool:
	if current_floor >= max_floors:
		return false
	current_floor += 1
	class_resource = 0
	_tick_inventory_floor_durations()
	return true

func advance_slasher_floor()->void:
	current_floor+=1;class_resource=0;_tick_inventory_floor_durations()

func get_slasher_cycle_length()->int:
	# TUNING: Change forest.slasher.cycle_length to alter the repeating Endless cadence.
	return maxi(1,int(Dictionary(GameBalance.get_dungeon(active_dungeon_id).get("slasher",{})).get("cycle_length",8)))

func get_slasher_cycle_floor()->int:return ((current_floor-1)%get_slasher_cycle_length())+1
func get_slasher_cycle_number()->int:return int((current_floor-1)/get_slasher_cycle_length())+1
func is_slasher_boss_floor()->bool:return get_slasher_cycle_floor()==get_slasher_cycle_length()
func is_slasher_elite_floor()->bool:
	# TUNING: Change forest.slasher.elite_floor_in_cycle to move the elite miniboss.
	return get_slasher_cycle_floor()==int(Dictionary(GameBalance.get_dungeon(active_dungeon_id).get("slasher",{})).get("elite_floor_in_cycle",5))
func enter_slasher_endless()->void:slasher_endless_mode=true;slasher_campaign_boss_cleared=true

func get_current_floor_seed() -> int:
	return floor_seed + current_floor * 997

func finish_run(outcome: String, message: String) -> void:
	run_outcome = message
	if outcome == "victory":
		completed_runs += 1
		completed_dungeons[active_dungeon_id] = true
	elif outcome == "death":
		deaths += 1
		_clear_permanent_inventory_for_active_class()
	_sync_crypt_unlock()

func has_completed_dungeon(dungeon_id: String) -> bool:
	if dungeon_id == "forest" and forest_cleared: return true
	return bool(completed_dungeons.get(dungeon_id, false))

func is_dungeon_unlocked(dungeon_id: String) -> bool:
	var dungeon := GameBalance.get_dungeon(dungeon_id)
	if dungeon.is_empty(): return false
	if GameBalance.are_all_dungeons_unlocked_for_testing(): return true
	var unlock: Dictionary = dungeon.get("unlock", {})
	match String(unlock.get("type", "always")):
		"always": return true
		"dungeon_clear":
			if not has_completed_dungeon(String(unlock.get("dungeon_id", ""))): return false
			return _highest_hero_level() >= int(unlock.get("min_level", 1))
		"crypt_progression": return has_completed_dungeon("forest") and _highest_hero_level() >= 5
	return false

func get_field_room(room_id: int) -> Dictionary:
	var rooms: Array = field_run.get("rooms", [])
	if room_id < 0 or room_id >= rooms.size() or not (rooms[room_id] is Dictionary): return {}
	return Dictionary(rooms[room_id]).duplicate(true)

func update_field_room(room_id: int, changes: Dictionary) -> void:
	var rooms: Array = field_run.get("rooms", [])
	if room_id < 0 or room_id >= rooms.size(): return
	var room: Dictionary = rooms[room_id]
	for key in changes: room[key] = changes[key]
	rooms[room_id] = room; field_run["rooms"] = rooms

func enter_field_room(room_id: int, previous_room: int) -> void:
	field_run["previous_room"] = previous_room; field_run["current_room"] = room_id
	update_field_room(room_id, {"visited":true})

func get_field_discovered_count() -> int:
	var total := 0
	for room in field_run.get("rooms", []):
		if room is Dictionary and bool(room.get("visited", false)): total += 1
	return total

func get_field_cleared_count() -> int:
	var total := 0
	for room in field_run.get("rooms", []):
		if room is Dictionary and bool(room.get("cleared", false)): total += 1
	return total

func get_field_progress_summary() -> String:
	if field_run.is_empty(): return "No active field expedition"
	return "%d/%d discovered · %d cleared%s" % [get_field_discovered_count(), int(field_run.get("room_count", 0)), get_field_cleared_count(), " · Boss defeated" if bool(field_run.get("boss_defeated", false)) else ""]

func set_selected_gear(gear: GearData) -> void:
	selected_gear = gear
	if selected_gear != null:
		selected_gear_by_class[selected_class_id] = selected_gear

func mark_forest_cleared() -> void:
	forest_cleared = true
	_sync_crypt_unlock()

func is_crypt_unlocked() -> bool:
	_sync_crypt_unlock()
	return crypt_unlocked

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

func get_class_resource_name() -> String:
	return String(GameBalance.get_base_class(selected_class_id).get("resource", "Power"))

func get_class_resource_max() -> int:
	return int(GameBalance.get_class_resource_rules(selected_class_id).get("max", GameBalance.get_class_resource_max()))

func get_class_resource_explanation() -> String:
	var rules := GameBalance.get_class_resource_rules(selected_class_id)
	var gains: Array[String] = []
	for entry in rules.get("gain", []): gains.append(String(entry))
	return "%s (max %d). Gain: %s. Specials cost %d." % [get_class_resource_name(), get_class_resource_max(), "; ".join(gains), int(rules.get("special_cost", 2))]

func get_attribute_growth_explanation(stat_id: String) -> String:
	for rule in GameBalance.get_class_data(selected_class_id).get("stat_growth", []):
		if rule is Dictionary and String(rule.get("stat", "")) == stat_id:
			return "+%d every %d levels" % [int(rule.get("amount", 1)), int(rule.get("every", 1))]
	return "No scheduled class growth"

func get_stat_breakdown(stat_id: String) -> Dictionary:
	var profile := _active_profile()
	var stats := get_stats()
	var progression := int(_selected_progression_modifiers(profile).get(stat_id, 0))
	var item := get_active_item_modifier_value(stat_id)
	var final := get_derived_stat(stat_id)
	var lookup_id := "attack_bonus" if stat_id == "attack_power" else ("spell_power" if stat_id == "spell_potency" else stat_id)
	var config: Dictionary = GameBalance.get_class_data(selected_class_id).get("derived", {}).get(lookup_id, {})
	var attribute := String(config.get("stat", ""))
	if stat_id == "accuracy":
		var best := -99
		for candidate in GameBalance.get_class_data(selected_class_id).get("primary", {}).get("accuracy", []):
			var modifier := _stat_modifier(int(stats.get(String(candidate), 10)))
			if modifier > best: best = modifier; attribute = String(candidate)
	var attribute_value := int(stats.get(attribute, 0)) if not attribute.is_empty() else 0
	return {"attribute":attribute,"attribute_value":attribute_value,"attribute_modifier":_stat_modifier(attribute_value) if not attribute.is_empty() else 0,"base_and_level":final-progression-item,"progression":progression,"item":item,"final":final,"formula":String(config.get("explanation", _derived_formula_explanation(stat_id)))}

func get_action_modifier_breakdown(slot: String, context: Dictionary = {}) -> Dictionary:
	var action_bonus := 0
	var conditional_bonus := 0
	var ignored: Array = []
	for value in GameBalance.get_class_action(selected_class_id, slot).get("modifiers", []):
		if not (value is Dictionary): continue
		var modifier: Dictionary = value
		var condition := String(modifier.get("condition", "always"))
		var matches := condition == "always"
		if condition == "adjacent_enemies_at_least": matches = int(context.get("adjacent_enemies", 0)) >= int(modifier.get("value", 0))
		elif condition == "target_status": matches = bool(context.get("target_%s" % String(modifier.get("status", "")), false))
		elif condition == "target_threshold_at_least": matches = int(context.get("target_threshold", 0)) >= int(modifier.get("value", 1))
		elif condition == "coordinated_wolf_attack": matches = bool(context.get("coordinated_wolf_attack", false))
		if matches:
			if modifier.has("ignore"): ignored.append_array(modifier.get("ignore", []))
			elif condition == "always": action_bonus += int(modifier.get("amount", 0))
			else: conditional_bonus += int(modifier.get("amount", 0))
	return {"action_bonus":action_bonus,"conditional_bonus":conditional_bonus,"ignore":ignored}

func _derived_formula_explanation(stat_id: String) -> String:
	match stat_id:
		"accuracy": return "Best primary Accuracy attribute modifier + 1 every 4 levels"
		"penetration": return "1 every 6 levels"
		"armor_class": return "9 + positive CON modifier"
		"evasion": return "10 + DEX modifier"
		"threshold": return "Positive CON modifier"
	return "Class formula + progression + items"

func gain_class_resource(amount: int = 1) -> int:
	class_resource = clampi(class_resource + amount, 0, get_class_resource_max())
	return class_resource

func get_consumable_capacity() -> int:
	return GameBalance.get_consumable_base_capacity() + get_derived_stat("consumable_capacity")

func get_consumables() -> Array[String]:
	_migrate_legacy_potions()
	return consumable_items.duplicate()

func add_consumable(consumable_id: String) -> bool:
	if GameBalance.get_consumable(consumable_id).is_empty() or consumable_items.size() >= get_consumable_capacity():
		return false
	consumable_items.append(consumable_id)
	_sync_legacy_potion_count()
	return true

func remove_consumable_at(index: int) -> String:
	_migrate_legacy_potions()
	if index < 0 or index >= consumable_items.size():
		return ""
	var consumed := consumable_items[index]
	consumable_items.remove_at(index)
	_sync_legacy_potion_count()
	return consumed

func _migrate_legacy_potions() -> void:
	var represented := consumable_items.count("healing_potion")
	while represented < potions and consumable_items.size() < get_consumable_capacity():
		consumable_items.append("healing_potion")
		represented += 1
	_sync_legacy_potion_count()

func _sync_legacy_potion_count() -> void:
	potions = consumable_items.count("healing_potion")

func spend_class_resource(amount: int) -> bool:
	if class_resource < amount:
		return false
	class_resource -= amount
	return true

func get_active_item_modifier_value(stat_id: String) -> int:
	return int(get_active_item_modifiers().get(stat_id, 0))

func get_active_item_effects(trigger: String = "") -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	for entry in inventory_items:
		var item := GameBalance.get_item(String(entry.get("id", "")))
		var effect_values: Variant = item.get("effects", [])
		if not (effect_values is Array):
			continue
		for effect_value in effect_values:
			if not (effect_value is Dictionary):
				continue
			var effect: Dictionary = effect_value
			if trigger.is_empty() or String(effect.get("trigger", "")) == trigger:
				var copy := effect.duplicate(true)
				copy["source_item_id"] = String(entry.get("id", ""))
				copy["source_item_name"] = String(item.get("name", entry.get("id", "Item")))
				effects.append(copy)
	return effects

func get_contextual_item_modifier(stat_id: String, context: Dictionary = {}) -> int:
	var total := 0
	for effect in get_active_item_effects():
		if not effect.has("condition") or not _item_condition_matches(effect, context):
			continue
		var modifiers_value: Variant = effect.get("modifiers", {})
		if modifiers_value is Dictionary:
			total += int(modifiers_value.get(stat_id, 0))
		if stat_id == "penetration" and effect.has("penetration_from_range"):
			total += int(floor(float(context.get("range_bonus", 0)) * float(effect["penetration_from_range"])))
	return total

func apply_reward_bonus(base_amount: int, reward_type: String) -> int:
	var modifier_id := "%s_bonus_percent" % reward_type
	var bonus_percent: int = get_active_item_modifier_value(modifier_id)
	return maxi(0, int(round(float(base_amount) * (1.0 + float(bonus_percent) / 100.0))))

func _ensure_merchant_progress() -> void:
	for merchant_id in GameBalance.get_merchants().keys():
		if merchant_progress.has(merchant_id):
			continue
		merchant_progress[merchant_id] = {
			"lifetime_favor": 0,
			"available_favor": 0,
			"highest_depth": 0,
			"boss_cleared": false,
			"recruited": merchant_id == "tavern",
		}

func get_merchant_progress(merchant_id: String) -> Dictionary:
	_ensure_merchant_progress()
	var value: Variant = merchant_progress.get(merchant_id, {})
	return value.duplicate(true) if value is Dictionary else {}

func get_merchant_rank(merchant_id: String) -> int:
	var progress := get_merchant_progress(merchant_id)
	var requirements := GameBalance.get_merchant_rank_requirements()
	var rank := 0
	for i in range(requirements.size()):
		var value: Variant = requirements[i]
		if not (value is Dictionary):
			continue
		var requirement: Dictionary = value
		if int(progress.get("lifetime_favor", 0)) < int(requirement.get("favor", 0)):
			continue
		if int(progress.get("highest_depth", 0)) < int(requirement.get("depth", 0)):
			continue
		if bool(requirement.get("boss_clear", false)) and not bool(progress.get("boss_cleared", false)):
			continue
		rank = i
	return rank

func is_merchant_recruited(merchant_id: String) -> bool:
	return bool(get_merchant_progress(merchant_id).get("recruited", false))

func record_dungeon_floor_clear(dungeon_id: String, depth: int, boss_clear: bool = false) -> Array[String]:
	_ensure_merchant_progress()
	var logs: Array[String] = []
	for merchant_id in [dungeon_id, "tavern"]:
		if not merchant_progress.has(merchant_id):
			continue
		var progress: Dictionary = merchant_progress[merchant_id]
		var old_depth := int(progress.get("highest_depth", 0))
		var favor_gain := 1
		if depth > old_depth:
			progress["highest_depth"] = depth
			favor_gain = 3 + depth
		if boss_clear and merchant_id == dungeon_id:
			favor_gain += 10
			progress["boss_cleared"] = true
			progress["recruited"] = true
		progress["lifetime_favor"] = int(progress.get("lifetime_favor", 0)) + favor_gain
		progress["available_favor"] = int(progress.get("available_favor", 0)) + favor_gain
		merchant_progress[merchant_id] = progress
		logs.append("+%d %s Favor." % [favor_gain, String(GameBalance.get_merchant(merchant_id).get("name", merchant_id.capitalize()))])
	return logs

func get_merchant_offers(merchant_id: String, location: String) -> Array[Dictionary]:
	var merchant := GameBalance.get_merchant(merchant_id)
	var rank := get_merchant_rank(merchant_id)
	var result: Array[Dictionary] = []
	var stock: Variant = merchant.get("stock", [])
	if not (stock is Array):
		return result
	for value in stock:
		if not (value is Dictionary):
			continue
		var offer: Dictionary = value.duplicate(true)
		var offer_id := String(offer.get("offer_id", ""))
		var offer_location := String(offer.get("location", "both"))
		var location_matches := offer_location == "both" or offer_location == location or (location == "tavern" and offer_location == "favor")
		if not location_matches:
			continue
		offer["unlocked"] = rank >= int(offer.get("min_rank", 0))
		offer["claimed"] = purchased_favor_offers.has(offer_id)
		if offer.has("gold") and location == "tavern":
			offer["base_gold"] = int(offer["gold"])
			var price_factor := 1.0 - minf(0.20, float(rank) * 0.05)
			if merchant_id != "tavern":
				price_factor = 1.20 - minf(0.12, float(rank) * 0.03)
			offer["gold"] = maxi(1, int(round(float(offer["gold"]) * price_factor)))
		if String(offer.get("kind", "")) == "item":
			var item := GameBalance.get_item(String(offer.get("item_id", "")))
			offer["name"] = String(item.get("name", offer.get("item_id", "Item")))
			offer["description"] = String(item.get("description", ""))
			offer["rules_text"] = String(item.get("rules_text", ""))
			offer["rarity"] = String(item.get("rarity", "common"))
		elif String(offer.get("kind", "")) == "consumable":
			var consumable := GameBalance.get_consumable(String(offer.get("consumable_id", "")))
			offer["rarity"] = String(consumable.get("rarity", "common"))
		else:
			offer["rarity"] = String(offer.get("rarity", "common"))
		var stock_key := _merchant_stock_key(merchant_id, offer_id)
		var max_stock := 1 if int(offer.get("favor", 0)) > 0 else GameBalance.get_merchant_stock_for_rarity(String(offer["rarity"]))
		if not merchant_offer_stock.has(stock_key): merchant_offer_stock[stock_key] = max_stock
		offer["max_stock"] = max_stock
		offer["stock_remaining"] = maxi(0, int(merchant_offer_stock.get(stock_key, max_stock)))
		offer["sold"] = bool(offer["claimed"]) or int(offer["stock_remaining"]) <= 0
		result.append(offer)
	return result

func purchase_merchant_offer(merchant_id: String, offer_id: String, location: String) -> Array[String]:
	var logs: Array[String] = []
	if location == "tavern" and not is_merchant_recruited(merchant_id):
		return ["That merchant has not joined the tavern yet."]
	var chosen: Dictionary = {}
	for offer in get_merchant_offers(merchant_id, location):
		if String(offer.get("offer_id", "")) == offer_id:
			chosen = offer
			break
	if chosen.is_empty() or not bool(chosen.get("unlocked", false)):
		return ["That offer is still locked."]
	if bool(chosen.get("claimed", false)):
		return ["That unique Favor reward has already been claimed."]
	if bool(chosen.get("sold", false)):
		return ["That offer is sold out."]
	if String(chosen.get("kind", "")) == "consumable":
		var held_count := pending_shop_consumables.size() if location == "tavern" else get_consumables().size()
		if held_count >= get_consumable_capacity():
			return ["Your Consumables slots are full."]
	var favor_cost := int(chosen.get("favor", 0))
	var gold_cost := int(chosen.get("gold", 0))
	if favor_cost > 0:
		if purchased_favor_offers.has(offer_id):
			return ["That unique Favor reward has already been claimed."]
		var progress: Dictionary = merchant_progress[merchant_id]
		if int(progress.get("available_favor", 0)) < favor_cost:
			return ["Not enough Favor."]
		progress["available_favor"] = int(progress["available_favor"]) - favor_cost
		merchant_progress[merchant_id] = progress
		purchased_favor_offers[offer_id] = true
	elif gold < gold_cost:
		return ["Not enough gold."]
	else:
		gold -= gold_cost
	var kind := String(chosen.get("kind", "item"))
	match kind:
		"consumable":
			var consumable_id := String(chosen.get("consumable_id", "healing_potion"))
			if location == "tavern": pending_shop_consumables.append(consumable_id)
			else: add_consumable(consumable_id)
		"key":
			if location == "tavern": pending_shop_keys += 1
			else: keys += 1
		_:
			var item_id := String(chosen.get("item_id", ""))
			if location == "tavern": pending_shop_items.append(item_id)
			else: logs.append_array(add_inventory_item(item_id, current_floor))
	var stock_key := _merchant_stock_key(merchant_id, offer_id)
	merchant_offer_stock[stock_key] = maxi(0, int(chosen.get("stock_remaining", 1)) - 1)
	logs.push_front("Purchased %s for %d %s." % [String(chosen.get("name", offer_id)), favor_cost if favor_cost > 0 else gold_cost, "Favor" if favor_cost > 0 else "gold"])
	return logs

func _merchant_stock_key(merchant_id: String, offer_id: String) -> String:
	return "%s:%s" % [merchant_id, offer_id]

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
	if active_play_mode==PLAY_MODE_SLASHER:logs.append_array(reconcile_slasher_progression())
	_sync_health_from_profile(false)
	_sync_crypt_unlock()
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

func generate_slasher_chest_choices(floor_number:int,chest_identity:Variant,endless_cycle:int=0)->Array[String]:
	# Chest offerings deliberately use their own RNG so opening one never perturbs encounter or Strategy loot rolls.
	var identity_hash:int=String(chest_identity).hash();var source_rng:=RandomNumberGenerator.new()
	source_rng.seed=get_current_floor_seed()*1103515245+floor_number*961748927+identity_hash
	var choices:Array[String]=[];var items:Dictionary=GameBalance.get_items();var weights:Dictionary=GameBalance.get_slasher_chest_rarity_weights(floor_number,endless_cycle)
	var choice_count:int=int(GameBalance.get_loot_table().get("choice_count",3));var attempts:int=0
	while choices.size()<choice_count and attempts<120:
		attempts+=1;var rarity:String=_roll_weighted_rarity(weights,source_rng);var candidates:Array[String]=_item_ids_for_rarity(items,rarity)
		if candidates.is_empty():candidates=_all_item_ids(items)
		if candidates.is_empty():break
		var item_id:String=candidates[source_rng.randi_range(0,candidates.size()-1)]
		if not choices.has(item_id):choices.append(item_id)
	pending_chest_choices.assign(choices);return choices

func _roll_weighted_rarity(weights:Dictionary,source_rng:RandomNumberGenerator)->String:
	var total:int=0
	for value:Variant in weights.values():total+=maxi(0,int(value))
	if total<=0:return "common"
	var roll:int=source_rng.randi_range(1,total);var running:int=0
	for key:Variant in weights:
		running+=maxi(0,int(weights[key]))
		if roll<=running:return String(key)
	return "common"

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
	return "Gold %d | Keys %d | Consumables %d/%d" % [gold, keys, get_consumables().size(), get_consumable_capacity()]

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
	var class_id: String = String(profile.get("class_id", selected_class_id))
	var path: Array = _profile_array(profile, "evolution_path")
	var upgrades: Array = _profile_array(profile, "ability_upgrades")
	var path_names: Array[String] = []
	for choice_id in path:
		path_names.append(_progression_choice_name(String(choice_id), class_id))
	var upgrade_names: Array[String] = []
	for choice_id in upgrades:
		upgrade_names.append(_progression_choice_name(String(choice_id), class_id))
	var path_text: String = "Unevolved" if path_names.is_empty() else " -> ".join(path_names)
	var upgrade_text: String = "No ability upgrades" if upgrade_names.is_empty() else ", ".join(upgrade_names)
	return "Path: %s\nUpgrades: %s" % [path_text, upgrade_text]

func get_current_evolution_name() -> String:
	var path: Array = _profile_array(_active_profile(), "evolution_path")
	if path.is_empty():
		return ""
	return _progression_choice_name(String(path[path.size() - 1]), selected_class_id)

func get_progression_flag_value(flag_id: String) -> int:
	var flags: Dictionary = _selected_progression_flags(_active_profile())
	return int(flags.get(flag_id, 0))

func reconcile_slasher_progression()->Array[String]:
	_ensure_profiles();var logs:Array[String]=[];var profile:Dictionary=_active_profile();var pending:Array=_profile_array(profile,"pending_slasher_progression_choices")
	if not pending.is_empty():return logs
	var level:int=int(profile.get("level",1));var class_id:String=String(profile.get("class_id",selected_class_id))
	for milestone:int in [3,5,7,9,10,11,13,15,17,19,20]:
		if milestone>level:break
		if milestone in [10,15,20]:
			var branch:String=_slasher_branch_from_profile(profile,class_id)
			if branch.is_empty():continue
			var stage_id:String="%s_branch_%s_stage_%d"%[class_id,branch,milestone];var path:Array=_profile_array(profile,"slasher_evolution_path")
			if not path.has(stage_id):path.append(stage_id);profile.slasher_evolution_path=path;logs.append("%s advances to %s."%[selected_class_name,_slasher_stage_name(class_id,branch,milestone)])
			continue
		if _has_slasher_choice_at_level(profile,class_id,milestone):continue
		var choices:Array[Dictionary]=GameBalance.get_slasher_choices_for_level(class_id,milestone,profile)
		if choices.is_empty():continue
		pending.append({"level":milestone,"type":String(choices[0].get("type","ability")),"choices":choices});profile.pending_slasher_progression_choices=pending;logs.append("Slasher progression choice unlocked at level %d."%milestone);break
	hero_profiles[selected_class_id]=profile;return logs

func has_pending_slasher_progression_choice()->bool:
	return not _profile_array(_active_profile(),"pending_slasher_progression_choices").is_empty()

func get_pending_slasher_progression_choice()->Dictionary:
	var pending:Array=_profile_array(_active_profile(),"pending_slasher_progression_choices")
	return pending[0].duplicate(true) if not pending.is_empty() and pending[0] is Dictionary else {}

func choose_slasher_progression_choice(choice_id:String)->Array[String]:
	var logs:Array[String]=[];var profile:Dictionary=_active_profile();var pending:Array=_profile_array(profile,"pending_slasher_progression_choices")
	if pending.is_empty() or not (pending[0] is Dictionary):return logs
	var pending_choice:Dictionary=pending[0];var selected:Dictionary={}
	for value:Variant in pending_choice.get("choices",[]):
		if value is Dictionary and String(value.get("id",""))==choice_id:selected=value;break
	if selected.is_empty():return ["That Slasher progression choice is no longer available."]
	var canonical:Dictionary=GameBalance.get_slasher_progression_choice(selected_class_id,choice_id)
	if canonical.is_empty() or int(canonical.get("level",-1))!=int(pending_choice.get("level",-2)):return ["That Slasher progression choice is invalid."]
	var destination_key:String="slasher_evolution_path" if String(canonical.get("type","ability"))=="evolution" else "slasher_ability_upgrades";var selected_ids:Array=_profile_array(profile,destination_key)
	if selected_ids.has(choice_id):return ["That Slasher progression choice was already claimed."]
	selected_ids.append(choice_id);profile[destination_key]=selected_ids;pending.remove_at(0);profile.pending_slasher_progression_choices=pending;hero_profiles[selected_class_id]=profile
	logs.append("Slasher upgrade selected: %s."%String(canonical.get("name",choice_id)));logs.append_array(reconcile_slasher_progression());pending_level_logs.append_array(logs);return logs

func get_slasher_selected_choices()->Array:
	var profile:Dictionary=_active_profile();return _profile_array(profile,"slasher_evolution_path")+_profile_array(profile,"slasher_ability_upgrades")

func get_effective_slasher_ability_tuning(slot:String)->Dictionary:
	return GameBalance.get_effective_slasher_ability_tuning(selected_class_id,slot,get_slasher_selected_choices())

func get_effective_slasher_companion_tuning(companion_id:String="wolf")->Dictionary:
	return GameBalance.get_effective_slasher_companion_tuning(selected_class_id,companion_id,get_slasher_selected_choices())

func get_slasher_specialization_name()->String:
	var profile:Dictionary=_active_profile();var branch:String=_slasher_branch_from_profile(profile,selected_class_id)
	return "Unspecialized" if branch.is_empty() else _slasher_stage_name(selected_class_id,branch,int(profile.get("level",1)))

func get_slasher_progression_summary()->String:
	var profile:Dictionary=_active_profile();var upgrades:Array=_profile_array(profile,"slasher_ability_upgrades");return "%s · %d ability upgrades"%[get_slasher_specialization_name(),upgrades.size()]

func _has_slasher_choice_at_level(profile:Dictionary,class_id:String,level:int)->bool:
	for value:Variant in _profile_array(profile,"slasher_evolution_path")+_profile_array(profile,"slasher_ability_upgrades"):
		var choice:Dictionary=GameBalance.get_slasher_progression_choice(class_id,String(value))
		if not choice.is_empty() and int(choice.get("level",-1))==level:return true
	return false

func _slasher_branch_from_profile(profile:Dictionary,class_id:String)->String:
	for value:Variant in _profile_array(profile,"slasher_evolution_path"):
		var choice:Dictionary=GameBalance.get_slasher_progression_choice(class_id,String(value))
		if int(choice.get("level",0))==5:return String(choice.get("branch",""))
	return ""

func _slasher_stage_name(class_id:String,branch_id:String,level:int)->String:
	var stage_index:int=0
	if level>=20:stage_index=3
	elif level>=15:stage_index=2
	elif level>=10:stage_index=1
	for value:Variant in GameBalance.get_slasher_progression(class_id).get("branches",[]):
		if value is Dictionary and String(value.get("id",""))==branch_id:
			var stages:Array=value.get("stages",[]);return String(stages[mini(stage_index,maxi(0,stages.size()-1))]) if not stages.is_empty() else String(value.get("name",branch_id.capitalize()))
	return branch_id.capitalize()

func _ensure_profiles() -> void:
	if hero_profiles.has("fighter") and not hero_profiles.has("warrior"):
		hero_profiles["warrior"] = hero_profiles["fighter"]
		hero_profiles.erase("fighter")
	for class_id in GameBalance.get_base_classes().keys():
		if not hero_profiles.has(class_id):
			hero_profiles[class_id] = _create_profile(String(class_id))
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
		if not profile.has("slasher_evolution_path"):profile["slasher_evolution_path"]=[]
		if not profile.has("slasher_ability_upgrades"):profile["slasher_ability_upgrades"]=[]
		if not profile.has("pending_slasher_progression_choices"):profile["pending_slasher_progression_choices"]=[]
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
		"slasher_evolution_path": [],
		"slasher_ability_upgrades": [],
		"pending_slasher_progression_choices": [],
	}
	_recalculate_profile(profile)
	return profile

func _base_stats_for_class(class_id: String) -> Dictionary:
	var class_data: Dictionary = GameBalance.get_class_data(class_id)
	class_id = GameBalance.normalize_class_id(class_id)
	var fallback_value: Variant = FALLBACK_CLASS_STATS.get(class_id, FALLBACK_CLASS_STATS["warrior"])
	var fighter_fallback_value: Variant = FALLBACK_CLASS_STATS["warrior"]
	var fighter_fallback: Dictionary = fighter_fallback_value if fighter_fallback_value is Dictionary else {}
	var fallback: Dictionary = fallback_value if fallback_value is Dictionary else fighter_fallback
	var stats_value: Variant = class_data.get("base_stats", fallback)
	var stats: Dictionary = stats_value if stats_value is Dictionary else fallback
	return stats.duplicate(true)

func _active_profile() -> Dictionary:
	_ensure_profiles()
	var profile_value: Variant = hero_profiles.get(selected_class_id, hero_profiles["warrior"])
	var fighter_profile_value: Variant = hero_profiles["warrior"]
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
	var legacy := {
		"max_health": _derive_stat_value(derived_config.get("max_health", {}), level, stats, true),
		"attack_bonus": _derive_stat_value(derived_config.get("attack_bonus", {}), level, stats, false),
		"spell_power": _derive_stat_value(derived_config.get("spell_power", {}), level, stats, false),
		"defense": _derive_stat_value(derived_config.get("defense", {}), level, stats, false),
		"initiative_modifier": _derive_stat_value(derived_config.get("initiative_modifier", {}), level, stats, false),
		"potion_heal_bonus": _derive_stat_value(derived_config.get("potion_heal_bonus", {}), level, stats, false),
		"movement": 0,
		"block_bonus": 0,
	}
	var strength := _stat_modifier(int(stats.get("str", 10)))
	var dexterity := _stat_modifier(int(stats.get("dex", 10)))
	var constitution := _stat_modifier(int(stats.get("con", 10)))
	var intellect := _stat_modifier(int(stats.get("int", 10)))
	var wisdom := _stat_modifier(int(stats.get("wis", 10)))
	var modifiers := {"str":strength,"dex":dexterity,"con":constitution,"int":intellect,"wis":wisdom,"cha":_stat_modifier(int(stats.get("cha", 10)))}
	var primary_accuracy: Array = class_data.get("primary", {}).get("accuracy", [])
	var accuracy_modifier := -99
	for stat_id in primary_accuracy: accuracy_modifier = maxi(accuracy_modifier, int(modifiers.get(String(stat_id), -99)))
	if accuracy_modifier == -99: accuracy_modifier = maxi(maxi(strength, dexterity), maxi(intellect, wisdom))
	legacy["accuracy"] = accuracy_modifier + int(floori(float(level - 1) / 4.0))
	legacy["penetration"] = int(floori(float(level - 1) / 6.0))
	legacy["attack_power"] = int(legacy["attack_bonus"])
	legacy["spell_potency"] = int(legacy["spell_power"])
	legacy["armor_class"] = 9 + maxi(0, constitution)
	legacy["evasion"] = 10 + dexterity
	legacy["threshold"] = maxi(0, constitution)
	legacy["aegis_all"] = 0
	for damage_type in CombatResolver.DAMAGE_TYPES:
		legacy["aegis_%s" % damage_type] = 0
	legacy["range"] = 0
	legacy["critical_range"] = 20
	return legacy

func _apply_inventory_modifiers_to_derived(derived_stats: Dictionary) -> void:
	var modifiers: Dictionary = get_active_item_modifiers()
	for key in modifiers.keys():
		if String(key).ends_with("_bonus_percent"):
			continue
		_apply_derived_modifier(derived_stats, String(key), int(modifiers[key]))

func _apply_progression_modifiers_to_derived(profile: Dictionary, derived_stats: Dictionary) -> void:
	var modifiers: Dictionary = _selected_progression_modifiers(profile)
	for key in modifiers.keys():
		_apply_derived_modifier(derived_stats, String(key), int(modifiers[key]))

func _apply_derived_modifier(derived_stats: Dictionary, stat_id: String, amount: int) -> void:
	derived_stats[stat_id] = int(derived_stats.get(stat_id, 0)) + amount
	match stat_id:
		"attack_bonus":
			derived_stats["attack_power"] = int(derived_stats.get("attack_power", 0)) + amount
		"spell_power":
			derived_stats["spell_potency"] = int(derived_stats.get("spell_potency", 0)) + amount
		"defense":
			derived_stats["armor_class"] = int(derived_stats.get("armor_class", 10)) + amount
		"block_bonus":
			derived_stats["threshold"] = int(derived_stats.get("threshold", 0)) + amount

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
	var fallback_value: Variant = FALLBACK_DERIVED_CONFIG.get(class_id, FALLBACK_DERIVED_CONFIG["warrior"])
	if fallback_value is Dictionary:
		return fallback_value
	return {}

func _enqueue_progression_choices(profile: Dictionary, level: int) -> Array[String]:
	var logs: Array[String] = []
	var class_id: String = String(profile.get("class_id", ""))
	var progression: Dictionary = GameBalance.get_class_progression(class_id)
	if progression.is_empty():
		return logs
	var pending: Array = _profile_array(profile, "pending_progression_choices")
	if _has_selected_progression_at_level(profile, "evolutions", level) and _has_selected_progression_at_level(profile, "ability_upgrades", level):
		return logs
	var evolution_choices: Array = GameBalance.get_evolution_choices(class_id, level, profile)
	if not _has_selected_progression_at_level(profile, "evolutions", level) and not evolution_choices.is_empty() and not _pending_choice_exists(pending, "evolution", level):
		pending.append({"type": "evolution", "level": level, "choices": evolution_choices})
		logs.append("%s evolution unlocked at level %d." % [String(profile.get("class_id", selected_class_name)).capitalize(), level])
	var ability_choices: Array = GameBalance.get_ability_upgrade_choices(class_id, level, profile)
	if not _has_selected_progression_at_level(profile, "ability_upgrades", level) and not ability_choices.is_empty() and not _pending_choice_exists(pending, "ability", level):
		pending.append({"type": "ability", "level": level, "choices": ability_choices})
		logs.append("%s ability upgrade unlocked at level %d." % [String(profile.get("class_id", selected_class_name)).capitalize(), level])
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
	var class_id: String = String(profile.get("class_id", selected_class_id))
	var selected_ids: Array = _profile_array(profile, "evolution_path") if list_key == "evolutions" else _profile_array(profile, "ability_upgrades")
	for choice_id in selected_ids:
		var choice: Dictionary = GameBalance.get_progression_choice(class_id, String(choice_id))
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
	var class_id: String = String(profile.get("class_id", selected_class_id))
	var selected_ids: Array = _profile_array(profile, "evolution_path") + _profile_array(profile, "ability_upgrades")
	for choice_id in selected_ids:
		var choice: Dictionary = GameBalance.get_progression_choice(class_id, String(choice_id))
		if not choice.is_empty():
			choices.append(choice)
	return choices

func _progression_choice_name(choice_id: String, class_id: String = "") -> String:
	var lookup_class_id: String = selected_class_id if class_id.is_empty() else class_id
	var choice: Dictionary = GameBalance.get_progression_choice(lookup_class_id, choice_id)
	return String(choice.get("name", choice_id.capitalize()))

func _profile_array(profile: Dictionary, key: String) -> Array:
	var value: Variant = profile.get(key, [])
	if value is Array:
		return value
	return []

func _stat_modifier(value: int) -> int:
	return int(floori(float(value - 10) / 2.0))

func _item_condition_matches(effect: Dictionary, context: Dictionary) -> bool:
	var condition := String(effect.get("condition", ""))
	if effect.has("damage_type") and String(effect["damage_type"]) != String(context.get("damage_type", "")):
		return false
	match condition:
		"always": return true
		"first_attack": return int(context.get("attack_index", 0)) == 0
		"first_spell_floor": return int(context.get("spell_index_floor", 0)) == 0
		"low_health": return current_health * 2 <= max_health
		"moved": return bool(context.get("moved", false))
		"moved_far": return int(context.get("tiles_moved", 0)) >= 2
		"stationary": return int(context.get("tiles_moved", 0)) == 0
		"isolated_target": return bool(context.get("isolated_target", false))
		"elite_target": return bool(context.get("elite_target", false))
		"unrevealed": return bool(context.get("unrevealed", false))
		"area_attack": return bool(context.get("area_attack", false))
		"surrounded": return int(context.get("adjacent_enemies", 0)) >= 2
		"close_spell": return bool(context.get("spell_attack", false)) and int(context.get("distance", 99)) <= 2
		"first_incoming_hit": return int(context.get("incoming_hit_index", 0)) == 0
		"unengaged": return int(context.get("adjacent_enemies", 0)) == 0
		"movement_ability": return bool(context.get("movement_ability", false))
		"repeated_target": return bool(context.get("repeated_target", false))
		"spell_attack": return bool(context.get("spell_attack", false))
		"studied_target": return bool(context.get("studied_target", false))
		"first_enemy_type": return bool(context.get("first_enemy_type", false))
		"damage_type": return true
	return false

func _xp_required_for_level(level: int) -> int:
	var thresholds: Array = GameBalance.get_xp_thresholds()
	if thresholds.is_empty():
		thresholds = FALLBACK_XP_THRESHOLDS
	var clamped_level: int = clampi(level, 1, mini(_max_level(), thresholds.size() - 1))
	return int(thresholds[clamped_level])

func _max_level() -> int:
	return GameBalance.get_max_level(MAX_HERO_LEVEL)

func _sync_crypt_unlock() -> void:
	crypt_unlocked = is_dungeon_unlocked("crypt") if not GameBalance.get_dungeon("crypt").is_empty() else forest_cleared and _highest_hero_level() >= 5

func _highest_hero_level() -> int:
	_ensure_profiles()
	var highest := 1
	for class_id in hero_profiles.keys():
		var profile_value: Variant = hero_profiles[class_id]
		if profile_value is Dictionary:
			highest = maxi(highest, int(profile_value.get("level", 1)))
	return highest

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
		if item_value is Dictionary and not GameBalance.is_favor_exclusive_item(String(item_id)) and String(item_value.get("rarity", "common")) == rarity:
			ids.append(String(item_id))
	return ids

func _all_item_ids(items: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for item_id in items.keys():
		if not GameBalance.is_favor_exclusive_item(String(item_id)):
			ids.append(String(item_id))
	return ids
