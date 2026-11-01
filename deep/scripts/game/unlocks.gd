extends RefCounted
class_name Unlocks

## Permanent goals (data/unlocks.json). Meeting one adds items to the drop
## pool or raises drop luck and bounty slots. Earned unlocks live in
## CampaignState.unlocks_earned {id: day} and survive Hearth loops.

const PATH := "res://data/unlocks.json"
const FAMILIES := {"sporeling":"sporeling","bandit_cutthroat":"bandit","bandit_knifethrower":"bandit","skeleton":"undead","skeletal_archer":"undead","grave_acolyte":"undead","soul_wisp":"undead","crypt_lord":"undead","ghoul":"undead","gravedigger":"undead","tomb_guard":"undead","revenant":"undead","charnel_king":"undead"}

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = Dictionary(parsed) if parsed is Dictionary else {"unlocks":[]}
	return _data

static func all() -> Array:
	return Array(data().get("unlocks",[]))

static func find(id: String) -> Dictionary:
	for value in all():
		if String(value.get("id","")) == id: return value
	return {}

## Which group an enemy counts toward for kill goals.
static func family(enemy_id: String) -> String:
	if FAMILIES.has(enemy_id): return FAMILIES[enemy_id]
	if enemy_id.begins_with("wolf_") or enemy_id.contains("wolf"): return "wolf"
	return "beast"

static func is_earned(campaign, id: String) -> bool:
	return campaign != null and campaign.unlocks_earned.has(id)

## An item is locked while an unearned unlock lists it as a reward.
static func is_item_locked(campaign, item_id: String) -> bool:
	if campaign == null: return false
	for value in all():
		if Array(Dictionary(value.get("reward",{})).get("items",[])).has(item_id) and not campaign.unlocks_earned.has(String(value.id)): return true
	return false

static func drop_luck(campaign) -> float:
	var luck := 1.0
	if campaign != null:
		for id in campaign.unlocks_earned: luck += float(Dictionary(find(String(id)).get("reward",{})).get("drop_luck",0.0))
	return luck

static func bounty_slots(campaign) -> int:
	var slots := 0
	if campaign != null:
		for id in campaign.unlocks_earned: slots += int(Dictionary(find(String(id)).get("reward",{})).get("bounty_slots",0))
	return slots

## Checks every unearned unlock whose condition matches this event, grants the
## ones now met and returns them. event: {type: kill|clear|death|bounty|reach, ...}.
static func check(campaign, run_stats: Dictionary, event: Dictionary) -> Array:
	var earned: Array = []
	if campaign == null: return earned
	for value in all():
		var unlock: Dictionary = value
		var id := String(unlock.get("id",""))
		if campaign.unlocks_earned.has(id): continue
		if _met(campaign,run_stats,Dictionary(unlock.get("condition",{})),event):
			campaign.unlocks_earned[id] = int(campaign.calendar_day)
			earned.append(unlock)
	return earned

static func _met(campaign, run_stats: Dictionary, condition: Dictionary, event: Dictionary) -> bool:
	var stats: Dictionary = campaign.lifetime_stats
	match String(condition.get("type","")):
		"kills":
			if String(event.get("type","")) != "kill": return false
			var family_id := String(condition.get("family","any"))
			var count := int(stats.get("kills_total",0)) if family_id == "any" else int(Dictionary(stats.get("kills",{})).get(family_id,0))
			return count >= int(condition.get("count",1))
		"kills_in_run":
			if String(event.get("type","")) != "kill": return false
			var family_id := String(condition.get("family","any"))
			var count := int(run_stats.get("kills_total",0)) if family_id == "any" else int(Dictionary(run_stats.get("kills",{})).get(family_id,0))
			return count >= int(condition.get("count",1))
		"clear":
			if String(event.get("type","")) != "clear": return false
			if String(condition.get("dungeon","")) != "" and String(condition.dungeon) != String(event.get("dungeon","")): return false
			if condition.has("class") and String(condition["class"]) != String(event.get("class_id","")): return false
			if condition.has("max_seconds") and float(event.get("seconds",INF)) > float(condition.max_seconds): return false
			if condition.has("max_potions") and int(event.get("potions",0)) > int(condition.max_potions): return false
			if condition.has("holding") and not Array(event.get("holding",[])).has(String(condition.holding)): return false
			return true
		"clears": return String(event.get("type","")) == "clear" and int(stats.get("clears",0)) >= int(condition.get("count",1))
		"deaths": return String(event.get("type","")) == "death" and int(stats.get("deaths",0)) >= int(condition.get("count",1))
		"bounties": return String(event.get("type","")) == "bounty" and int(stats.get("bounties",0)) >= int(condition.get("count",1))
		"reach": return String(event.get("type","")) == "reach" and String(event.get("dungeon","")) == String(condition.get("dungeon",""))
	return false

## Progress text for the Hearth's Unlocks page, e.g. "12 / 30".
static func progress(campaign, unlock: Dictionary) -> String:
	var condition: Dictionary = unlock.get("condition",{})
	var stats: Dictionary = campaign.lifetime_stats
	match String(condition.get("type","")):
		"kills":
			var family_id := String(condition.get("family","any"))
			var count := int(stats.get("kills_total",0)) if family_id == "any" else int(Dictionary(stats.get("kills",{})).get(family_id,0))
			return "%d / %d" % [mini(count,int(condition.count)),int(condition.count)]
		"clears": return "%d / %d" % [mini(int(stats.get("clears",0)),int(condition.count)),int(condition.count)]
		"deaths": return "%d / %d" % [mini(int(stats.get("deaths",0)),int(condition.count)),int(condition.count)]
		"bounties": return "%d / %d" % [mini(int(stats.get("bounties",0)),int(condition.count)),int(condition.count)]
	return ""

static func validate() -> Array[String]:
	var errors: Array[String] = []
	var ids := {}
	for value in all():
		var id := String(value.get("id",""))
		if id.is_empty() or ids.has(id): errors.append("Missing or duplicate unlock id %s" % id)
		ids[id] = true
		for item_id in Array(Dictionary(value.get("reward",{})).get("items",[])):
			if GameBalance.get_item(String(item_id)).is_empty(): errors.append("%s unlocks unknown item %s" % [id,item_id])
		if not String(Dictionary(value.get("condition",{})).get("type","")) in ["kills","kills_in_run","clear","clears","deaths","bounties","reach"]: errors.append("%s has an unknown condition type" % id)
	return errors
