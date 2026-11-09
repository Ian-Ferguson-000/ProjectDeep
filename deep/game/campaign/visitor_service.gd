extends RefCounted
class_name VisitorService

## Visitors of merit (data/visitors.json): named people who call at the Hearth
## on a schedule, give quests, and open shops that grow with their favour.
##
## Quest flow: available -> (accept while they're here) active -> (the run or
## the tavern meets the objective) ready -> (talk to them on a later visit)
## done, which pays the reward. "deliver" quests are handed over in person
## and complete at once. Progress counts only from when a quest is accepted.
##
## Everything is saved in campaign.visitor_state:
##   {visitor_id: {"favour", "met", "quests": {quest_id: {"state", "progress"}},
##                 "bought": [offer ids], "contest_visit": day}, "_flags": {flag: day}}

const DATA_PATH := "res://data/visitors.json"
const FLAGS := "_flags"
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func ids() -> Array[String]:
	var result: Array[String] = []
	for id in Dictionary(data().get("visitors", {})).keys():
		result.append(String(id))
	return result


static func visitor(id: String) -> Dictionary:
	return Dictionary(Dictionary(data().get("visitors", {})).get(id, {}))


static func state(c: CampaignState, id: String) -> Dictionary:
	if not c.visitor_state.has(id):
		c.visitor_state[id] = {
			"favour": 0, "met": false, "quests": {}, "bought": [], "contest_visit": -1
		}
	return Dictionary(c.visitor_state[id])


# ---------------------------------------------------------------- favour and ranks


static func ranks(id: String) -> Array:
	var own: Array = Array(visitor(id).get("ranks", []))
	return (
		own
		if not own.is_empty()
		else Array(data().get("default_ranks", [{"name": "Stranger", "favour": 0}]))
	)


static func favour(c: CampaignState, id: String) -> int:
	return int(state(c, id).get("favour", 0))


static func rank(c: CampaignState, id: String) -> int:
	var value := favour(c, id)
	var result := 0
	var list := ranks(id)
	for index in list.size():
		if value >= int(Dictionary(list[index]).get("favour", 0)):
			result = index
	return result


static func rank_name(c: CampaignState, id: String) -> String:
	return String(Dictionary(ranks(id)[rank(c, id)]).get("name", "Stranger"))


## Favour needed for the next rank, or -1 at the top.
static func next_rank_favour(c: CampaignState, id: String) -> int:
	var list := ranks(id)
	var index := rank(c, id) + 1
	return int(Dictionary(list[index]).get("favour", 0)) if index < list.size() else -1


static func add_favour(c: CampaignState, id: String, amount: int) -> void:
	var s := state(c, id)
	s["favour"] = maxi(0, int(s.get("favour", 0)) + amount)


# ---------------------------------------------------------------- schedule


## Whether they could visit at all yet (requires: a dungeon clear or a story flag).
static func unlocked(c: CampaignState, id: String) -> bool:
	var requires: Dictionary = Dictionary(
		Dictionary(visitor(id).get("schedule", {})).get("requires", {})
	)
	if requires.has("clear") and not c.has_completed_dungeon(String(requires.clear)):
		return false
	if requires.has("flag") and not has_flag(c, String(requires.flag)):
		return false
	return true


static func present_on(c: CampaignState, id: String, day: int) -> bool:
	if not c.is_tutorial_complete() or not unlocked(c, id):
		return false
	var schedule: Dictionary = Dictionary(visitor(id).get("schedule", {}))
	var first := int(schedule.get("first_day", 1))
	if day < first:
		return false
	return (
		(day - first) % maxi(1, int(schedule.get("every_days", 5)))
		< maxi(1, int(schedule.get("stay_days", 1)))
	)


static func is_present(c: CampaignState, id: String) -> bool:
	return present_on(c, id, c.calendar_day)


static func present(c: CampaignState) -> Array[String]:
	var result: Array[String] = []
	for id in ids():
		if is_present(c, id):
			result.append(id)
	return result


## The next day they'll be here (today if they're here now), or -1 if not yet known.
static func next_visit_day(c: CampaignState, id: String) -> int:
	if not unlocked(c, id):
		return -1
	for offset in 60:
		if present_on(c, id, c.calendar_day + offset):
			return c.calendar_day + offset
	return -1


## The first day of the visit they're on now (one mini-game win per visit).
static func visit_start(c: CampaignState, id: String) -> int:
	var day := c.calendar_day
	while day > 1 and present_on(c, id, day - 1):
		day -= 1
	return day


# ---------------------------------------------------------------- quests


static func quests(id: String) -> Array:
	return Array(visitor(id).get("quests", []))


static func quest(id: String, quest_id: String) -> Dictionary:
	for value in quests(id):
		if String(Dictionary(value).get("id", "")) == quest_id:
			return Dictionary(value)
	return {}


static func _quest_record(c: CampaignState, id: String, quest_id: String) -> Dictionary:
	var all: Dictionary = Dictionary(state(c, id).get("quests", {}))
	state(c, id)["quests"] = all
	return Dictionary(all.get(quest_id, {}))


static func _set_quest(c: CampaignState, id: String, quest_id: String, record: Dictionary) -> void:
	var all: Dictionary = Dictionary(state(c, id).get("quests", {}))
	all[quest_id] = record
	state(c, id)["quests"] = all


## locked · available · active · ready · done
static func quest_state(c: CampaignState, id: String, quest_id: String) -> String:
	var record := _quest_record(c, id, quest_id)
	if not record.is_empty():
		return String(record.get("state", "active"))
	var q := quest(id, quest_id)
	if rank(c, id) < int(q.get("requires_rank", 0)):
		return "locked"
	for needed in Array(q.get("requires_quests", [])):
		if quest_state(c, id, String(needed)) != "done":
			return "locked"
	return "available"


## Why a locked quest is locked, in words.
static func lock_reason(c: CampaignState, id: String, quest_id: String) -> String:
	var q := quest(id, quest_id)
	var needed_rank := int(q.get("requires_rank", 0))
	if rank(c, id) < needed_rank:
		return (
			"Become their %s"
			% String(Dictionary(ranks(id)[mini(needed_rank, ranks(id).size() - 1)]).get("name", ""))
		)
	for needed in Array(q.get("requires_quests", [])):
		if quest_state(c, id, String(needed)) != "done":
			return 'Finish "%s" first' % String(quest(id, String(needed)).get("title", needed))
	return ""


static func target(q: Dictionary) -> int:
	var objective: Dictionary = Dictionary(q.get("objective", {}))
	match String(objective.get("type", "")):
		"kills", "runs_home", "train", "contest_win":
			return maxi(1, int(objective.get("count", 1)))
		"deliver":
			return maxi(1, int(objective.get("count", objective.get("gold", 1))))
	return 1


static func progress(c: CampaignState, id: String, quest_id: String) -> int:
	return int(_quest_record(c, id, quest_id).get("progress", 0))


static func progress_text(c: CampaignState, id: String, quest_id: String) -> String:
	var q := quest(id, quest_id)
	var state_id := quest_state(c, id, quest_id)
	if state_id == "ready":
		return "Done · return to %s" % String(visitor(id).get("name", id))
	if state_id == "done":
		return "Complete"
	if String(Dictionary(q.get("objective", {})).get("type", "")) == "deliver":
		return _deliver_text(c, q)
	var goal := target(q)
	return (
		"%d / %d" % [mini(progress(c, id, quest_id), goal), goal]
		if goal > 1
		else ("Not yet" if state_id == "active" else "")
	)


static func accept(c: CampaignState, id: String, quest_id: String) -> Dictionary:
	if not is_present(c, id):
		return {
			"ok": false,
			"error": "%s isn't at the Hearth today." % String(visitor(id).get("name", id))
		}
	if quest_state(c, id, quest_id) != "available":
		return {"ok": false, "error": "That job isn't on offer."}
	_set_quest(c, id, quest_id, {"state": "active", "progress": 0, "accepted_day": c.calendar_day})
	state(c, id)["met"] = true
	return {
		"ok": true, "message": "Accepted: %s." % String(quest(id, quest_id).get("title", quest_id))
	}


## Active quests everywhere: [{visitor, quest, state, progress}].
static func active_quests(c: CampaignState) -> Array:
	var result: Array = []
	for id in ids():
		for value in quests(id):
			var quest_id := String(Dictionary(value).get("id", ""))
			var state_id := quest_state(c, id, quest_id)
			if state_id in ["active", "ready"]:
				result.append({"visitor": id, "quest": quest_id, "state": state_id})
	return result


## Something happened that quests might care about. Returns the quests this made
## ready, as "Visitor: Quest title" strings. Events:
##   {type: kill, family} · {type: floor, dungeon, floor} · {type: clear, dungeon, class_id, seconds, potions}
##   {type: return, outcome, gold} · {type: train} · {type: contest_win, visitor}
static func notify(c: CampaignState, event: Dictionary) -> Array[String]:
	var finished: Array[String] = []
	if c == null:
		return finished
	for entry in active_quests(c):
		if String(entry.state) != "active":
			continue
		var id := String(entry.visitor)
		var quest_id := String(entry.quest)
		var q := quest(id, quest_id)
		var record := _quest_record(c, id, quest_id)
		var gained := _progress_from(Dictionary(q.get("objective", {})), event, id)
		if gained <= 0:
			continue
		record["progress"] = int(record.get("progress", 0)) + gained
		if int(record.progress) >= target(q):
			record["state"] = "ready"
			finished.append(
				"%s: %s" % [String(visitor(id).get("name", id)), String(q.get("title", quest_id))]
			)
		_set_quest(c, id, quest_id, record)
	return finished


static func _progress_from(objective: Dictionary, event: Dictionary, visitor_id: String) -> int:
	var kind := String(event.get("type", ""))
	match String(objective.get("type", "")):
		"kills":
			if kind != "kill":
				return 0
			var family := String(objective.get("family", "any"))
			return 1 if family == "any" or family == String(event.get("family", "")) else 0
		"reach_floor":
			if (
				kind != "floor"
				or String(event.get("dungeon", "")) != String(objective.get("dungeon", ""))
			):
				return 0
			return 1 if int(event.get("floor", 0)) >= int(objective.get("floor", 1)) else 0
		"clear":
			if kind != "clear":
				return 0
			if (
				String(objective.get("dungeon", "")) != ""
				and String(objective.dungeon) != String(event.get("dungeon", ""))
			):
				return 0
			if (
				objective.has("class")
				and String(objective["class"]) != String(event.get("class_id", ""))
			):
				return 0
			if (
				objective.has("max_seconds")
				and float(event.get("seconds", INF)) > float(objective.max_seconds)
			):
				return 0
			if (
				objective.has("max_potions")
				and int(event.get("potions", 0)) > int(objective.max_potions)
			):
				return 0
			return 1
		"return_gold":
			if kind != "return" or String(event.get("outcome", "")) == "death":
				return 0
			return 1 if int(event.get("gold", 0)) >= int(objective.get("gold", 0)) else 0
		"runs_home":
			return 1 if kind == "return" and String(event.get("outcome", "")) != "death" else 0
		"train":
			return 1 if kind == "train" else 0
		"contest_win":
			return (
				1 if kind == "contest_win" and String(event.get("visitor", "")) == visitor_id else 0
			)
	return 0


# ---------------------------------------------------------------- deliveries and rewards


static func _deliver_text(c: CampaignState, q: Dictionary) -> String:
	var objective: Dictionary = Dictionary(q.get("objective", {}))
	if objective.has("gold"):
		return "Hand over %d gold (you have %d)" % [int(objective.gold), c.banked_gold]
	if objective.has("material"):
		var material_id := String(objective.material)
		return (
			"Hand over %d %s (%d at the Hearth)"
			% [
				int(objective.get("count", 1)),
				Materials.material_name(material_id),
				int(c.materials.get(material_id, 0))
			]
		)
	var food_id := String(objective.get("food", ""))
	return (
		"Hand over %d %s (%d in the pantry)"
		% [
			int(objective.get("count", 1)),
			String(HearthUpkeep.food(food_id).get("name", food_id)),
			int(c.pantry.get(food_id, 0))
		]
	)


static func can_deliver(c: CampaignState, id: String, quest_id: String) -> bool:
	var objective: Dictionary = Dictionary(quest(id, quest_id).get("objective", {}))
	if String(objective.get("type", "")) != "deliver":
		return false
	if objective.has("gold"):
		return c.banked_gold >= int(objective.gold)
	if objective.has("material"):
		return int(c.materials.get(String(objective.material), 0)) >= int(objective.get("count", 1))
	return int(c.pantry.get(String(objective.get("food", "")), 0)) >= int(objective.get("count", 1))


## Hands the goods over and pays the reward straight away.
static func deliver(c: CampaignState, id: String, quest_id: String) -> Dictionary:
	if not is_present(c, id):
		return {"ok": false, "error": "They aren't here to take it."}
	if quest_state(c, id, quest_id) != "active":
		return {"ok": false, "error": "Accept the job first."}
	if not can_deliver(c, id, quest_id):
		return {"ok": false, "error": "You don't have enough to hand over."}
	var objective: Dictionary = Dictionary(quest(id, quest_id).get("objective", {}))
	if objective.has("gold"):
		c.banked_gold -= int(objective.gold)
	elif objective.has("material"):
		c.materials[String(objective.material)] = (
			int(c.materials.get(String(objective.material), 0)) - int(objective.get("count", 1))
		)
	else:
		var food_id := String(objective.get("food", ""))
		c.pantry[food_id] = int(c.pantry.get(food_id, 0)) - int(objective.get("count", 1))
	_set_quest(c, id, quest_id, {"state": "ready", "progress": target(quest(id, quest_id))})
	return claim(c, id, quest_id)


## Collect the reward for a finished quest (in person).
static func claim(c: CampaignState, id: String, quest_id: String) -> Dictionary:
	if not is_present(c, id):
		return {
			"ok": false,
			"error": "Come back when %s is at the Hearth." % String(visitor(id).get("name", id))
		}
	if quest_state(c, id, quest_id) != "ready":
		return {"ok": false, "error": "That job isn't finished yet."}
	var record := _quest_record(c, id, quest_id)
	record["state"] = "done"
	record["done_day"] = c.calendar_day
	_set_quest(c, id, quest_id, record)
	var got := grant(c, id, Dictionary(quest(id, quest_id).get("reward", {})))
	return {
		"ok": true,
		"message": "%s · %s" % [String(quest(id, quest_id).get("title", quest_id)), ", ".join(got)],
		"rewards": got
	}


## Pays a reward; returns what was given, in words.
static func grant(c: CampaignState, id: String, reward: Dictionary) -> Array[String]:
	var got: Array[String] = []
	if int(reward.get("gold", 0)) > 0:
		c.banked_gold += int(reward.gold)
		got.append("%d gold" % int(reward.gold))
	if int(reward.get("renown", 0)) > 0:
		c.reputation = mini(100, c.reputation + int(reward.renown))
		got.append("%d renown" % int(reward.renown))
	if int(reward.get("favour", 0)) > 0:
		add_favour(c, id, int(reward.favour))
		got.append("+%d favour" % int(reward.favour))
	for item_id in Array(reward.get("items", [])):
		HearthArmory.grant(c, String(item_id))
		got.append(String(HearthCatalog.item(String(item_id)).get("name", item_id)))
	for furnishing_id in Array(reward.get("furnishings", [])):
		c.furnishing_storage[String(furnishing_id)] = (
			int(c.furnishing_storage.get(String(furnishing_id), 0)) + 1
		)
		got.append(
			(
				"%s (in storage)"
				% String(HearthLodging.furnishing(String(furnishing_id)).get("name", furnishing_id))
			)
		)
	var food: Dictionary = Dictionary(reward.get("food", {}))
	for food_id in food:
		HearthUpkeep.add(c, String(food_id), int(food[food_id]))
		got.append(
			(
				"%d %s"
				% [
					int(food[food_id]),
					String(HearthUpkeep.food(String(food_id)).get("name", food_id))
				]
			)
		)
	if not String(reward.get("flag", "")).is_empty():
		set_flag(c, String(reward.flag))
	return got


# ---------------------------------------------------------------- story flags


static func has_flag(c: CampaignState, flag: String) -> bool:
	return Dictionary(c.visitor_state.get(FLAGS, {})).has(flag)


static func set_flag(c: CampaignState, flag: String) -> void:
	var flags: Dictionary = Dictionary(c.visitor_state.get(FLAGS, {}))
	flags[flag] = c.calendar_day
	c.visitor_state[FLAGS] = flags


# ---------------------------------------------------------------- shop


## Offers with "locked" (rank too low) and "sold" (once-only, already bought).
static func shop(c: CampaignState, id: String) -> Array:
	var result: Array = []
	var bought: Array = Array(state(c, id).get("bought", []))
	for value in Array(visitor(id).get("shop", [])):
		var offer: Dictionary = Dictionary(value).duplicate()
		offer["locked"] = rank(c, id) < int(offer.get("min_rank", 0))
		offer["sold"] = (
			bool(offer.get("once", false)) and bought.has(String(offer.get("offer_id", "")))
		)
		offer["label"] = offer_name(offer)
		result.append(offer)
	return result


static func offer_name(offer: Dictionary) -> String:
	var item_id := String(offer.get("id", ""))
	match String(offer.get("kind", "")):
		"item":
			return String(HearthCatalog.item(item_id).get("name", item_id))
		"furnishing":
			return String(HearthLodging.furnishing(item_id).get("name", item_id))
		"food":
			return (
				"%d %s"
				% [
					int(offer.get("count", 1)),
					String(HearthUpkeep.food(item_id).get("name", item_id))
				]
			)
	return item_id


static func buy(c: CampaignState, id: String, offer_id: String) -> Dictionary:
	if not is_present(c, id):
		return {"ok": false, "error": "They've packed up their stall."}
	var offer: Dictionary = {}
	for value in shop(c, id):
		if String(value.get("offer_id", "")) == offer_id:
			offer = value
	if offer.is_empty():
		return {"ok": false, "error": "Not for sale."}
	if bool(offer.locked):
		return {"ok": false, "error": "They don't trust you with that yet."}
	if bool(offer.sold):
		return {"ok": false, "error": "Sold out."}
	var price := int(offer.get("price", 0))
	if c.banked_gold < price:
		return {"ok": false, "error": "That costs %d gold." % price}
	c.banked_gold -= price
	var item_id := String(offer.get("id", ""))
	match String(offer.get("kind", "")):
		"item":
			HearthArmory.grant(c, item_id)
		"furnishing":
			c.furnishing_storage[item_id] = int(c.furnishing_storage.get(item_id, 0)) + 1
		"food":
			HearthUpkeep.add(c, item_id, int(offer.get("count", 1)))
	var bought: Array = Array(state(c, id).get("bought", []))
	bought.append(offer_id)
	state(c, id)["bought"] = bought
	state(c, id)["met"] = true
	return {"ok": true, "message": "Bought %s." % String(offer.label)}


# ---------------------------------------------------------------- mini-game and talk


static func minigame(id: String) -> Dictionary:
	return Dictionary(visitor(id).get("minigame", {}))


## One win per visit counts toward favour.
static func can_contest(c: CampaignState, id: String) -> bool:
	return (
		not minigame(id).is_empty()
		and is_present(c, id)
		and int(state(c, id).get("contest_visit", -1)) != visit_start(c, id)
	)


static func record_contest(c: CampaignState, id: String, outcome: String) -> Array[String]:
	var finished: Array[String] = []
	if outcome != "win" or not can_contest(c, id):
		return finished
	state(c, id)["contest_visit"] = visit_start(c, id)
	add_favour(c, id, int(minigame(id).get("favour_per_win", 1)))
	finished = notify(c, {"type": "contest_win", "visitor": id})
	return finished


static func greeting(c: CampaignState, id: String) -> String:
	var lines: Array = Array(Dictionary(visitor(id).get("lines", {})).get("greeting", []))
	return String(lines[mini(rank(c, id), lines.size() - 1)]) if not lines.is_empty() else ""


static func idle_line(c: CampaignState, id: String) -> String:
	var lines: Array = Array(Dictionary(visitor(id).get("lines", {})).get("idle", []))
	return (
		String(lines[posmod(c.calendar_day + c.calendar_shift, lines.size())])
		if not lines.is_empty()
		else ""
	)


static func quest_line(id: String, quest_id: String, which: String) -> String:
	return String(Dictionary(quest(id, quest_id).get("lines", {})).get(which, ""))


## Whether they have something for you: a job to hand in, or one on offer.
static func has_news(c: CampaignState, id: String) -> bool:
	for value in quests(id):
		if quest_state(c, id, String(Dictionary(value).get("id", ""))) in ["ready", "available"]:
			return true
	return false


## Data checks for the editor/tests.
static func validate() -> Array[String]:
	var errors: Array[String] = []
	for id in ids():
		var v := visitor(id)
		for key in ["name", "title", "schedule", "quests"]:
			if not v.has(key):
				errors.append("%s is missing %s" % [id, key])
		var quest_ids: Array = quests(id).map(func(q): return String(Dictionary(q).get("id", "")))
		for value in quests(id):
			var q: Dictionary = value
			var kind := String(Dictionary(q.get("objective", {})).get("type", ""))
			if not (
				kind
				in [
					"kills",
					"reach_floor",
					"clear",
					"return_gold",
					"runs_home",
					"train",
					"contest_win",
					"deliver"
				]
			):
				errors.append("%s/%s has unknown objective %s" % [id, q.get("id", ""), kind])
			for needed in Array(q.get("requires_quests", [])):
				if not quest_ids.has(String(needed)):
					errors.append("%s/%s requires unknown quest %s" % [id, q.get("id", ""), needed])
			var deliver_material := String(Dictionary(q.get("objective", {})).get("material", ""))
			if not deliver_material.is_empty() and Materials.material(deliver_material).is_empty():
				errors.append(
					"%s/%s asks for unknown material %s" % [id, q.get("id", ""), deliver_material]
				)
			for item_id in Array(Dictionary(q.get("reward", {})).get("items", [])):
				if HearthCatalog.item(String(item_id)).is_empty():
					errors.append("%s/%s rewards unknown item %s" % [id, q.get("id", ""), item_id])
		for value in Array(v.get("shop", [])):
			var offer: Dictionary = value
			var item_id := String(offer.get("id", ""))
			var known := false
			match String(offer.get("kind", "")):
				"item":
					known = not HearthCatalog.item(item_id).is_empty()
				"furnishing":
					known = not HearthLodging.furnishing(item_id).is_empty()
				"food":
					known = not HearthUpkeep.food(item_id).is_empty()
			if not known:
				errors.append("%s shop: unknown %s %s" % [id, offer.get("kind", ""), item_id])
		var contest := String(minigame(id).get("contest", ""))
		if not contest.is_empty() and not VisitorContestRules.CONTESTS.has(contest):
			errors.append("%s: unknown mini-game %s" % [id, contest])
	return errors
