extends RefCounted
class_name BountyBoard

## The tavern's bounty board (data/bounties.json). Bounties are posted a few
## at a time and taken down after a few days. An expedition that returns alive
## having met a bounty's goal completes it and is paid on return.
##
## CampaignState.bounties = {"offers":[bounty...], "next_uid":int}
## bounty = {uid, template, text, goal{type,...resolved}, reward{gold,renown,essence}, posted_day, expires_day}

const PATH := "res://data/bounties.json"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = Dictionary(parsed) if parsed is Dictionary else {"bounties":[],"settings":{}}
	return _data

static func slots(campaign) -> int:
	return int(Dictionary(data().get("settings",{})).get("slots",2)) + Unlocks.bounty_slots(campaign)

static func offers(campaign) -> Array:
	return Array(campaign.bounties.get("offers",[]))

## Takes down expired bounties and posts new ones into empty slots.
static func refresh(campaign) -> void:
	var board: Dictionary = campaign.bounties
	var current: Array = Array(board.get("offers",[])).filter(func(b): return int(b.get("expires_day",0)) >= int(campaign.calendar_day))
	var templates: Array = Array(data().get("bounties",[]))
	var uid := int(board.get("next_uid",1))
	var guard := 0
	while current.size() < slots(campaign) and guard < 40 and not templates.is_empty():
		guard += 1
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("bounty:%d:%d" % [uid,int(campaign.calendar_day)])
		var template: Dictionary = templates[rng.randi_range(0,templates.size() - 1)]
		if current.any(func(b): return String(b.template) == String(template.id)): uid += 1; continue
		var bounty := _make(campaign,template,rng,uid)
		uid += 1
		if bounty.is_empty(): continue
		current.append(bounty)
	board["offers"] = current
	board["next_uid"] = uid
	campaign.bounties = board

static func _make(campaign, template: Dictionary, rng: RandomNumberGenerator, uid: int) -> Dictionary:
	var goal: Dictionary = Dictionary(template.get("goal",{})).duplicate(true)
	var fill := {}
	var dungeon_id := String(goal.get("dungeon","forest"))
	fill["dungeon"] = String(GameBalance.get_dungeon(dungeon_id).get("name",dungeon_id.capitalize()))
	match String(goal.type):
		"kills","gold":
			goal["count"] = rng.randi_range(int(goal.get("min",5)),int(goal.get("max",10)))
			fill["count"] = str(goal.count)
		"clear_time":
			var record := ClearRecords.best(campaign,dungeon_id)
			var seconds := float(record.time) * float(goal.get("seconds_from_record",1.15)) if not record.is_empty() else float(goal.get("default_seconds",1080))
			goal["seconds"] = snappedf(seconds,5.0)
			fill["time"] = ClearRecords.format_time(float(goal.seconds)).split(".")[0]
		"clear_class":
			var classes: Array = []
			for member in campaign.living_roster():
				if not classes.has(member.class_id): classes.append(member.class_id)
			if classes.is_empty(): classes = Array(campaign.unlocked_classes)
			if classes.is_empty(): return {}
			goal["class"] = String(classes[rng.randi_range(0,classes.size() - 1)])
			fill["class"] = String(goal["class"]).capitalize()
	var text := String(template.get("text",""))
	for key in fill: text = text.replace("{%s}" % key,String(fill[key]))
	var reward := {}
	var authored: Dictionary = template.get("reward",{})
	for key in authored:
		var span: Variant = authored[key]
		reward[key] = rng.randi_range(int(span[0]),int(span[1])) if span is Array else int(span)
	var lasts := int(Dictionary(data().get("settings",{})).get("lasts_days",3))
	return {"uid":uid,"template":String(template.id),"text":text,"goal":goal,"reward":reward,"posted_day":int(campaign.calendar_day),"expires_day":int(campaign.calendar_day) + lasts - 1}

## Progress toward a bounty from this expedition's stats: {done, current, target, label}.
static func progress(bounty: Dictionary, run_stats: Dictionary, gold: int = 0) -> Dictionary:
	var goal: Dictionary = bounty.get("goal",{})
	var clears: Array = Array(run_stats.get("clears",[]))
	match String(goal.get("type","")):
		"kills":
			var have := int(Dictionary(run_stats.get("kills",{})).get(String(goal.get("family","any")),0)) if String(goal.get("family","any")) != "any" else int(run_stats.get("kills_total",0))
			return {"done":have >= int(goal.count),"current":mini(have,int(goal.count)),"target":int(goal.count),"label":"%d / %d" % [mini(have,int(goal.count)),int(goal.count)]}
		"gold":
			return {"done":gold >= int(goal.count),"current":mini(gold,int(goal.count)),"target":int(goal.count),"label":"%d / %d gold" % [mini(gold,int(goal.count)),int(goal.count)]}
		"clear_time":
			for clear in clears:
				if String(clear.dungeon) == String(goal.dungeon) and float(clear.seconds) <= float(goal.seconds): return {"done":true,"label":ClearRecords.format_time(float(clear.seconds))}
			return {"done":false,"label":"not yet"}
		"clear_class":
			for clear in clears:
				if String(clear.dungeon) == String(goal.dungeon) and String(clear.class_id) == String(goal["class"]): return {"done":true,"label":"done"}
			return {"done":false,"label":"not yet"}
		"clear_no_potion":
			for clear in clears:
				if String(clear.dungeon) == String(goal.dungeon) and int(clear.potions) == 0: return {"done":true,"label":"done"}
			return {"done":false,"label":"potions drunk: %d" % int(run_stats.get("potions",0)) if int(run_stats.get("potions",0)) > 0 else "not yet"}
	return {"done":false,"label":""}

## Pays out bounties met by a returning expedition. Returns completed bounties.
static func settle(campaign, run_stats: Dictionary, outcome: String, gold: int) -> Array:
	var completed: Array = []
	if outcome == "death": return completed
	var keep: Array = []
	for bounty in offers(campaign):
		if bool(progress(bounty,run_stats,gold).done):
			var reward: Dictionary = bounty.reward
			campaign.banked_gold += int(reward.get("gold",0))
			campaign.reputation = mini(100,campaign.reputation + int(reward.get("renown",0)))
			campaign.relic_essence += int(reward.get("essence",0))
			campaign.lifetime_stats["bounties"] = int(campaign.lifetime_stats.get("bounties",0)) + 1
			completed.append(bounty)
		else:
			keep.append(bounty)
	campaign.bounties["offers"] = keep
	return completed

static func reward_text(reward: Dictionary) -> String:
	var parts: Array[String] = []
	if int(reward.get("gold",0)) > 0: parts.append("%d gold" % int(reward.gold))
	if int(reward.get("renown",0)) > 0: parts.append("%d renown" % int(reward.renown))
	if int(reward.get("essence",0)) > 0: parts.append("%d essence" % int(reward.essence))
	return ", ".join(parts)
