extends RefCounted
class_name DivineFavorService

const DATA_PATH := "res://data/story/pantheons.json"
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		if not FileAccess.file_exists(DATA_PATH): push_error("Missing pantheon data: " + DATA_PATH); return {}
		var file := FileAccess.open(DATA_PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
		if parsed is Dictionary: _data = Dictionary(parsed).duplicate(true)
		else: push_error("Invalid pantheon data: " + DATA_PATH)
	return _data

static func deities() -> Dictionary: return Dictionary(data().get("deities", {}))
static func deity(deity_id: String) -> Dictionary: return Dictionary(deities().get(deity_id, {})).duplicate(true)
static func deity_name(deity_id: String) -> String: return String(deity(deity_id).get("name", deity_id.replace("_", " ").capitalize()))

static func ordered_deity_ids() -> Array[String]:
	var ids: Array[String] = []
	for value in deities().keys(): ids.append(String(value))
	ids.sort_custom(func(a: String, b: String): return deity_name(a) < deity_name(b))
	return ids

static func validate() -> Array[String]:
	var errors: Array[String] = []; var known := deities()
	for pantheon_id in Dictionary(data().get("pantheons", {})):
		var pantheon := Dictionary(data().pantheons[pantheon_id])
		if NarrativeContent.nation(String(pantheon.get("nation_id", ""))).is_empty(): errors.append("Pantheon %s references an unknown nation." % pantheon_id)
		for deity_id in Array(pantheon.get("deity_ids", [])):
			if not known.has(String(deity_id)): errors.append("Pantheon %s references missing deity %s." % [pantheon_id, deity_id])
	for deity_id in known:
		var definition := Dictionary(known[deity_id]); var boon := Dictionary(definition.get("boon", {}))
		if String(definition.get("name", "")).is_empty(): errors.append("Deity %s has no name." % deity_id)
		if NarrativeContent.nation(String(definition.get("nation_id", ""))).is_empty(): errors.append("Deity %s references an unknown nation." % deity_id)
		if boon.is_empty() or int(boon.get("cost", 0)) <= 0: errors.append("Deity %s has no valid boon." % deity_id)
		for rival_id in Array(definition.get("rival_ids", [])):
			if not known.has(String(rival_id)): errors.append("Deity %s references missing rival %s." % [deity_id, rival_id])
	return errors

static func can_accept_boon(campaign, deity_id: String) -> Dictionary:
	var definition := deity(deity_id)
	if definition.is_empty(): return {"ok":false,"error":"Unknown deity."}
	if Dictionary(campaign.active_boons).has(deity_id): return {"ok":false,"error":"That bargain is already active."}
	var boon := Dictionary(definition.get("boon", {})); var cost := int(boon.get("cost", 0))
	if int(campaign.divine_favor.get(deity_id, 0)) < cost: return {"ok":false,"error":"This bargain requires %d favor." % cost}
	return {"ok":true,"cost":cost,"boon":boon}

static func accept_boon(campaign, deity_id: String) -> Dictionary:
	var check := can_accept_boon(campaign, deity_id)
	if not bool(check.get("ok", false)): return check
	var boon := Dictionary(check.boon)
	campaign.divine_favor[deity_id] = int(campaign.divine_favor.get(deity_id, 0)) - int(check.cost)
	campaign.active_boons[deity_id] = {"boon_id":String(boon.get("id", "")),"accepted_day":campaign.calendar_day,"status":"promised","effects":Dictionary(boon.get("effects", {})).duplicate(true),"obligation":String(boon.get("obligation", ""))}
	campaign._add_calendar_event("divine_bargain", "%s accepts the Keeper's promise." % deity_name(deity_id))
	return {"ok":true,"message":"%s granted: %s" % [String(boon.get("name", "Boon")), String(boon.get("obligation", ""))]}

static func settlement_modifiers(campaign, expedition) -> Dictionary:
	var deity_id := String(expedition.patron_deity_id)
	if deity_id.is_empty(): return {"gold_multiplier":1.0,"contribution_multiplier":1.0}
	var effects := Dictionary(Dictionary(campaign.active_boons.get(deity_id, {})).get("effects", {}))
	return {"gold_multiplier":float(effects.get("gold_multiplier", 1.0)),"contribution_multiplier":float(effects.get("contribution_multiplier", 1.0))}

static func record_expedition_outcome(campaign, expedition, outcome: String) -> Dictionary:
	var deity_id := String(expedition.patron_deity_id)
	if deity_id.is_empty() or deity(deity_id).is_empty(): return {"patron_id":"","favor_gained":0,"obligation":"none"}
	var gain: int = int({"victory":6,"retreat":3,"death":2}.get(outcome, 0)) + mini(4, int(expedition.carried_contribution) / 10)
	campaign.divine_favor[deity_id] = int(campaign.divine_favor.get(deity_id, 0)) + gain
	for rival_id in Array(deity(deity_id).get("rival_ids", [])):
		var rival := String(rival_id)
		if int(campaign.divine_favor.get(rival, 0)) > 0: campaign.divine_favor[rival] = int(campaign.divine_favor[rival]) - 1
	var obligation_status := "none"
	if campaign.active_boons.has(deity_id):
		var active := Dictionary(campaign.active_boons[deity_id]).duplicate(true)
		obligation_status = "fulfilled" if outcome == "victory" else "broken"
		active.merge({"status":obligation_status,"resolved_day":campaign.calendar_day,"outcome":outcome,"deity_id":deity_id}, true)
		campaign.divine_obligations.append(active); campaign.active_boons.erase(deity_id)
		if obligation_status == "broken": campaign.divine_favor[deity_id] = maxi(0, int(campaign.divine_favor[deity_id]) - 3)
	campaign._add_calendar_event("divine_favor", "%s records the expedition's %s." % [deity_name(deity_id), outcome])
	return {"patron_id":deity_id,"patron_name":deity_name(deity_id),"favor_gained":gain,"obligation":obligation_status}
