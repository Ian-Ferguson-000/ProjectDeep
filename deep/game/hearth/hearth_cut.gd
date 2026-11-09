extends RefCounted
class_name HearthCut

## The tavern's business (data/tavern_cut.json).
##
## You pay to recruit adventurers into the Eros company; they live and train at
## the Hearth until they go on their one expedition. When they come home the
## Hearth keeps a cut of what they bring back and the adventurer keeps the rest,
## then retires to Eros town for good (into retired_heroes, where a child may
## one day turn up at the tavern). The more you train and care for someone,
## the bigger your cut: 10% for a stranger up to 90% for someone you raised.
##
## Recruits also have a fame tier: better known costs more but comes stronger.

const DATA_PATH := "res://data/tavern_cut.json"
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func rules() -> Dictionary:
	return Dictionary(data().get("cut", {}))


# ---------------------------------------------------------------- the cut


## The cut and where it comes from: {"percent", "parts": [[label, points], ...]}.
static func breakdown(c: CampaignState, member: CharacterRecord) -> Dictionary:
	var r := rules()
	var parts: Array = []
	if member == null:
		return {"percent": int(r.get("min", 10)), "parts": parts}
	var sessions := int(member.training.get("sessions", 0))
	var training := mini(
		int(r.get("training_cap", 40)), sessions * int(r.get("per_training_session", 4))
	)
	if training != 0:
		parts.append(
			["Training (%d session%s)" % [sessions, "" if sessions == 1 else "s"], training]
		)
	var mood := HearthUpkeep.band(HearthUpkeep.happiness(member))
	var mood_points := int(Dictionary(r.get("happiness", {})).get(String(mood.get("name", "")), 0))
	if mood_points != 0:
		parts.append(["Mood: %s" % String(mood.get("name", "")), mood_points])
	if c != null:
		var room := HearthLodging.room_of(c, member.id)
		if not room.is_empty():
			var quality_id := String(room.get("quality", "cot"))
			var room_points := int(Dictionary(r.get("room_quality", {})).get(quality_id, 0))
			if room_points != 0:
				parts.append(
					[
						(
							"Room: %s"
							% String(HearthLodging.quality(quality_id).get("name", quality_id))
						),
						room_points
					]
				)
			var suited := 0
			for furnishing_id in Array(room.get("furnishings", [])):
				if Array(HearthLodging.furnishing(String(furnishing_id)).get("suits", [])).has(
					member.class_id
				):
					suited += 1
			var furnishing_points := mini(
				int(r.get("furnishing_cap", 12)), suited * int(r.get("per_suited_furnishing", 3))
			)
			if furnishing_points != 0:
				parts.append(["Furnishings that suit them", furnishing_points])
		var days := maxi(0, c.calendar_day - member.joined_day) if member.joined_day >= 0 else 0
		var day_points := mini(int(r.get("days_cap", 15)), days * int(r.get("per_day_housed", 1)))
		if day_points != 0:
			parts.append(["Days at the Hearth (%d)" % days, day_points])
	var total := int(r.get("min", 10))
	for part in parts:
		total += int(part[1])
	return {"percent": clampi(total, int(r.get("min", 10)), int(r.get("max", 90))), "parts": parts}


static func percent(c: CampaignState, member: CharacterRecord) -> int:
	return int(breakdown(c, member).percent)


## One line for tooltips: "Base 10% · Training (3 sessions) +12 · Mood: Content +10".
static func explain(c: CampaignState, member: CharacterRecord) -> String:
	var info := breakdown(c, member)
	var bits := PackedStringArray(["Base %d%%" % int(rules().get("min", 10))])
	for part in info.parts:
		bits.append("%s %+d" % [String(part[0]), int(part[1])])
	return (
		"Tavern cut %d%%: %s. Train and care for them to raise it (up to %d%%)."
		% [int(info.percent), " · ".join(bits), int(rules().get("max", 90))]
	)


## Splits a run's gold: {"cut": hearth's gold, "purse": adventurer's gold, "percent"}.
static func split(gold: int, cut_percent: int) -> Dictionary:
	var cut := roundi(gold * cut_percent / 100.0)
	return {"cut": cut, "purse": maxi(0, gold - cut), "percent": cut_percent}


## After their expedition: gear goes back to the armory, packed potions back to
## storage, and they retire to Eros town with their purse.
static func retire_to_town(
	c: CampaignState, member: CharacterRecord, purse: int, dungeon_id: String, outcome: String
) -> void:
	HearthArmory.release(c, member)
	for id in member.provisions:
		c.consumable_stock[id] = int(c.consumable_stock.get(id, 0)) + 1
	member.provisions.clear()
	member.status = CharacterRecord.STATUS_RETIRED
	var record := member.to_dict()
	record.merge(
		{
			"name": member.display_name,
			"retired_day": c.calendar_day,
			"dungeon_id": dungeon_id,
			"outcome": outcome,
			"purse": purse,
			"settled_in_town": true,
			"descendant_checks": 0,
			"descendant_created": false
		},
		true
	)
	c.retired_heroes.append(record)
	c.lineage_registry[member.id] = {
		"retired_day": c.calendar_day, "checks": 0, "descendant_created": false
	}
	c.roster.erase(member.id)
	HearthLodging.sync_occupants(c)


# ---------------------------------------------------------------- fame


static func fame_tier(id: String) -> Dictionary:
	return Dictionary(
		Dictionary(Dictionary(data().get("fame", {})).get("tiers", {})).get(
			id,
			{
				"name": "Unknown",
				"fee_multiplier": 1.0,
				"stat_bonus": 0,
				"level_bonus": 0,
				"color": "a99678"
			}
		)
	)


static func fame_name(id: String) -> String:
	return String(fame_tier(id).get("name", "Unknown"))


static func fame_color(id: String) -> Color:
	return Color("#" + String(fame_tier(id).get("color", "a99678")))


## Rolls a recruit's fame for the Hearth's size (bigger Hearths draw bigger names).
static func roll_fame(establishment_tier: int, rng: RandomNumberGenerator) -> String:
	var fame: Dictionary = Dictionary(data().get("fame", {}))
	var order: Array = Array(fame.get("order", ["unknown"]))
	var table: Array = Array(fame.get("weights_by_establishment_tier", [[1]]))
	var weights: Array = Array(table[clampi(establishment_tier, 0, table.size() - 1)])
	var total := 0
	for weight in weights:
		total += int(weight)
	var roll := rng.randi_range(1, maxi(1, total))
	for index in mini(order.size(), weights.size()):
		roll -= int(weights[index])
		if roll <= 0:
			return String(order[index])
	return String(order[0])


## Applies a fame tier to a fresh recruit: stats, level and signing fee.
static func apply_fame(member: CharacterRecord, fame_id: String, leveling_enabled: bool) -> void:
	var tier := fame_tier(fame_id)
	member.fame = fame_id
	var bonus := int(tier.get("stat_bonus", 0))
	if bonus != 0:
		for stat in member.attributes.keys():
			member.attributes[stat] = mini(18, int(member.attributes[stat]) + bonus)
	if leveling_enabled:
		member.level = mini(20, member.level + int(tier.get("level_bonus", 0)))
	member.signing_fee = roundi(
		(8 + member.level * member.level * 3) * float(tier.get("fee_multiplier", 1.0))
	)
