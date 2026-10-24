extends RefCounted
class_name HearthLodging

## Rooms, furnishings and stat training at the Hearth (data/lodging.json).
##
## Every adventurer in the company has a room. Rooms are built one at a time up to
## the establishment tier's limit, can be upgraded in quality, and hold
## furnishings. Training spends gold for a chance to raise one attribute; the
## trainee's room quality and furnishings make the stats they suit easier to train.

const PATH := "res://data/lodging.json"
const ATTRIBUTE_IDS := ["str","dex","con","int","wis","cha"]

static var _cache: Dictionary = {}

static func data() -> Dictionary:
	if _cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_cache = Dictionary(parsed) if parsed is Dictionary else {}
	return _cache

static func qualities() -> Array: return Array(data().get("qualities",[]))
static func training_rules() -> Dictionary: return Dictionary(data().get("training",{}))
static func furnishings() -> Dictionary: return Dictionary(data().get("furnishings",{}))
static func furnishing(id: String) -> Dictionary: return Dictionary(furnishings().get(id,{}))

static func quality(id: String) -> Dictionary:
	for value in qualities():
		if String(Dictionary(value).get("id","")) == id: return Dictionary(value)
	return Dictionary(qualities()[0]) if not qualities().is_empty() else {}

static func quality_index(id: String) -> int:
	for index in qualities().size():
		if String(Dictionary(qualities()[index]).get("id","")) == id: return index
	return 0

# ---------------------------------------------------------------- rooms

## Rooms the building has space for at the current establishment tier.
static func room_limit(c: CampaignState) -> int:
	return int(HearthCatalog.tier(c.establishment_tier).capacity)

static func new_room(index: int) -> Dictionary:
	return {"id":"room_%d" % index,"quality":String(Dictionary(qualities()[0]).get("id","cot")),"furnishings":[],"occupant":""}

## Creates the starting rooms for a new Hearth, or for a save from before rooms
## existed (enough rooms that nobody is left without one).
static func ensure_rooms(c: CampaignState) -> void:
	if not c.rooms.is_empty(): return
	var count := int(data().get("starting_rooms",4))
	if c.lodging_migrated_from_capacity: count = maxi(count,room_limit(c))
	count = maxi(count,c.living_roster().size())
	for index in count: c.rooms.append(new_room(index+1))
	sync_occupants(c)

## Keeps rooms and the company in step: people who have left vacate their room,
## and anyone without a room moves into the best free one.
static func sync_occupants(c: CampaignState) -> void:
	var living := {}
	for member in c.living_roster(): living[member.id] = true
	var housed := {}
	for index in c.rooms.size():
		var room: Dictionary = c.rooms[index]
		var occupant := String(room.get("occupant",""))
		if occupant.is_empty(): continue
		if not living.has(occupant) or housed.has(occupant): room.occupant = ""; c.rooms[index] = room
		else: housed[occupant] = true
	for member in c.living_roster():
		if housed.has(member.id): continue
		var free := _best_free_room(c)
		if free < 0: break
		c.rooms[free].occupant = member.id
		housed[member.id] = true

static func _best_free_room(c: CampaignState) -> int:
	var best := -1
	for index in c.rooms.size():
		if not String(c.rooms[index].get("occupant","")).is_empty(): continue
		if best < 0 or quality_index(String(c.rooms[index].quality)) > quality_index(String(c.rooms[best].quality)): best = index
	return best

static func room_of(c: CampaignState, character_id: String) -> Dictionary:
	for room in c.rooms:
		if String(room.get("occupant","")) == character_id: return room
	return {}

static func room_index(c: CampaignState, room_id: String) -> int:
	for index in c.rooms.size():
		if String(c.rooms[index].get("id","")) == room_id: return index
	return -1

static func build_cost(c: CampaignState) -> int:
	var rule: Dictionary = Dictionary(data().get("room_build_cost",{}))
	return int(rule.get("base",40)) + int(rule.get("per_room",15)) * c.rooms.size()

static func build_room(c: CampaignState) -> Dictionary:
	ensure_rooms(c)
	if c.rooms.size() >= room_limit(c): return HearthArmory.fail("The Hearth has no space for another room. Expand the building first.")
	var cost := build_cost(c)
	if c.banked_gold < cost: return HearthArmory.fail("A new room costs %d gold." % cost)
	c.banked_gold -= cost
	c.rooms.append(new_room(c.rooms.size()+1))
	sync_occupants(c)
	return {"ok":true,"message":"Carpenters finish Room %d. The Hearth now has %d rooms." % [c.rooms.size(),c.rooms.size()]}

static func next_quality(room: Dictionary) -> Dictionary:
	var index := quality_index(String(room.get("quality","cot"))) + 1
	return Dictionary(qualities()[index]) if index < qualities().size() else {}

static func upgrade_room(c: CampaignState, room_id: String) -> Dictionary:
	var index := room_index(c,room_id)
	if index < 0: return HearthArmory.fail("That room does not exist.")
	var target := next_quality(c.rooms[index])
	if target.is_empty(): return HearthArmory.fail("This room is already as fine as the Hearth can make it.")
	if c.establishment_tier < int(target.get("min_tier",0)): return HearthArmory.fail("Expand the Hearth to %s before building a %s." % [String(HearthCatalog.tier(int(target.min_tier)).name),String(target.name)])
	var cost := int(target.get("upgrade_cost",0))
	if c.banked_gold < cost: return HearthArmory.fail("Upgrading to a %s costs %d gold." % [String(target.name),cost])
	c.banked_gold -= cost
	c.rooms[index].quality = String(target.id)
	return {"ok":true,"message":"%s is now a %s." % [room_label(c,c.rooms[index]),String(target.name)]}

## Moves an adventurer into a room, swapping with whoever lives there.
static func assign_room(c: CampaignState, room_id: String, character_id: String) -> Dictionary:
	var target := room_index(c,room_id)
	if target < 0: return HearthArmory.fail("That room does not exist.")
	var member := c.character(character_id)
	if member == null: return HearthArmory.fail("That adventurer is not in the company.")
	var current := -1
	for index in c.rooms.size():
		if String(c.rooms[index].get("occupant","")) == character_id: current = index
	if current == target: return HearthArmory.fail("%s already lives here." % member.display_name)
	var displaced := String(c.rooms[target].get("occupant",""))
	c.rooms[target].occupant = character_id
	if current >= 0: c.rooms[current].occupant = displaced
	var other := c.character(displaced)
	return {"ok":true,"message":"%s moves into %s%s." % [member.display_name,room_label(c,c.rooms[target])," and %s takes their old room" % other.display_name if other != null and current >= 0 else ""]}

static func room_label(c: CampaignState, room: Dictionary) -> String:
	return "Room %d" % (room_index(c,String(room.get("id",""))) + 1)

# ---------------------------------------------------------------- furnishings

static func slots(room: Dictionary) -> int:
	return int(quality(String(room.get("quality","cot"))).get("slots",1))

static func can_fit(room: Dictionary, furnishing_id: String) -> bool:
	return quality_index(String(room.get("quality","cot"))) >= quality_index(String(furnishing(furnishing_id).get("min_quality","cot")))

## Places a furnishing, taking it from storage if one is waiting there and buying
## it otherwise.
static func place_furnishing(c: CampaignState, room_id: String, furnishing_id: String) -> Dictionary:
	var index := room_index(c,room_id)
	var item := furnishing(furnishing_id)
	if index < 0 or item.is_empty(): return HearthArmory.fail("That cannot be placed here.")
	var room: Dictionary = c.rooms[index]
	var placed: Array = Array(room.get("furnishings",[]))
	if placed.size() >= slots(room): return HearthArmory.fail("%s has no free space. Upgrade the room for more." % room_label(c,room))
	if not can_fit(room,furnishing_id): return HearthArmory.fail("A %s needs at least a %s." % [String(item.name),String(quality(String(item.get("min_quality","cot"))).name)])
	var stored := int(c.furnishing_storage.get(furnishing_id,0))
	if stored > 0:
		c.furnishing_storage[furnishing_id] = stored - 1
		if int(c.furnishing_storage[furnishing_id]) <= 0: c.furnishing_storage.erase(furnishing_id)
	else:
		var cost := int(item.get("cost",0))
		if c.banked_gold < cost: return HearthArmory.fail("A %s costs %d gold." % [String(item.name),cost])
		c.banked_gold -= cost
	placed.append(furnishing_id)
	room.furnishings = placed
	c.rooms[index] = room
	return {"ok":true,"message":"%s placed in %s." % [String(item.name),room_label(c,room)]}

static func remove_furnishing(c: CampaignState, room_id: String, slot_index: int) -> Dictionary:
	var index := room_index(c,room_id)
	if index < 0: return HearthArmory.fail("That room does not exist.")
	var placed: Array = Array(c.rooms[index].get("furnishings",[]))
	if slot_index < 0 or slot_index >= placed.size(): return HearthArmory.fail("Nothing is there.")
	var furnishing_id := String(placed[slot_index])
	placed.remove_at(slot_index)
	c.rooms[index].furnishings = placed
	c.furnishing_storage[furnishing_id] = int(c.furnishing_storage.get(furnishing_id,0)) + 1
	return {"ok":true,"message":"%s moved to storage." % String(furnishing(furnishing_id).get("name",furnishing_id))}

## Classes a room's furnishings are themed for, most matches first.
static func room_suits(room: Dictionary) -> Array[String]:
	var counts := {}
	for furnishing_id in Array(room.get("furnishings",[])):
		for class_id in Array(furnishing(String(furnishing_id)).get("suits",[])): counts[String(class_id)] = int(counts.get(String(class_id),0)) + 1
	var result: Array[String] = []
	for class_id in counts: result.append(String(class_id))
	result.sort_custom(func(a: String, b: String): return int(counts[a]) > int(counts[b]))
	return result

# ---------------------------------------------------------------- training

static func training_cost(member: CharacterRecord, stat: String) -> int:
	var rules := training_rules()
	return int(rules.get("base_cost",14)) + int(rules.get("cost_per_point_above_10",4)) * maxi(0,int(member.attributes.get(stat,10)) - 10)

static func trained_today(c: CampaignState, member: CharacterRecord) -> bool:
	return int(member.training.get("last_day",-1)) == c.calendar_day

## The % chance a session on this stat succeeds, and where it comes from.
static func training_chance(c: CampaignState, member: CharacterRecord, stat: String) -> Dictionary:
	var rules := training_rules()
	var value := int(member.attributes.get(stat,10))
	var parts: Array[String] = []
	var chance := int(rules.get("base_chance",70)) - int(rules.get("chance_drop_per_point_above_10",7)) * maxi(0,value - 10)
	var room := room_of(c,member.id)
	var room_bonus := int(quality(String(room.get("quality","cot"))).get("training_bonus",0)) if not room.is_empty() else 0
	if room_bonus != 0: chance += room_bonus; parts.append("room +%d%%" % room_bonus)
	var furnishing_bonus := 0
	for furnishing_id in Array(room.get("furnishings",[])): furnishing_bonus += int(Dictionary(furnishing(String(furnishing_id)).get("stats",{})).get(stat,0))
	if furnishing_bonus != 0: chance += furnishing_bonus; parts.append("furnishings +%d%%" % furnishing_bonus)
	var practice := int(Dictionary(member.training.get("practice",{})).get(stat,0)) * int(rules.get("practice_bonus",15))
	if practice != 0: chance += practice; parts.append("practice +%d%%" % practice)
	if member.learning_potential_known:
		var learning := int(Dictionary(rules.get("learning_bonus",{})).get(member.learning_potential,0))
		if learning != 0: chance += learning; parts.append("%s %+d%%" % [VisitorContestRules.learning_name(member.learning_potential).to_lower(),learning])
	return {"chance":clampi(chance,int(rules.get("min_chance",10)),int(rules.get("max_chance",95))),"parts":parts}

static func can_train(c: CampaignState, member: CharacterRecord, stat: String) -> Dictionary:
	if member == null: return HearthArmory.fail("That adventurer is not in the company.")
	if not ATTRIBUTE_IDS.has(stat): return HearthArmory.fail("That is not something you can train.")
	if member.status != CharacterRecord.STATUS_AVAILABLE: return HearthArmory.fail("%s is away and cannot train." % member.display_name)
	if trained_today(c,member): return HearthArmory.fail("%s has already trained today. Rest until tomorrow." % member.display_name)
	if int(member.attributes.get(stat,10)) >= int(training_rules().get("stat_cap",18)): return HearthArmory.fail("%s has trained %s as far as the Hearth can take it." % [member.display_name,stat.to_upper()])
	var cost := training_cost(member,stat)
	if c.banked_gold < cost: return HearthArmory.fail("This session costs %d gold." % cost)
	return {"ok":true,"cost":cost}

## One training session. Costs gold either way; success raises the stat by 1,
## failure banks a practice point that makes the next attempt likelier.
static func train(c: CampaignState, character_id: String, stat: String) -> Dictionary:
	var member := c.character(character_id)
	var check := can_train(c,member,stat)
	if not bool(check.ok): return check
	var chance := int(training_chance(c,member,stat).chance)
	c.banked_gold -= int(check.cost)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%d:%s:%d" % [member.id,c.calendar_day,c.calendar_shift,stat,int(member.training.get("sessions",0))])
	var success := rng.randi_range(1,100) <= chance
	var training: Dictionary = member.training.duplicate(true)
	var practice: Dictionary = Dictionary(training.get("practice",{}))
	var gains: Dictionary = Dictionary(training.get("gains",{}))
	training["last_day"] = c.calendar_day
	training["sessions"] = int(training.get("sessions",0)) + 1
	var message := ""
	if success:
		var old_max := member.max_health
		member.attributes[stat] = int(member.attributes.get(stat,10)) + 1
		member.progression["attributes"] = member.attributes.duplicate(true)
		if member.progression.has("base_stats"): member.progression["base_stats"] = member.attributes.duplicate(true)
		member.max_health = AdventurerBuilds.max_health_for(member.class_id,member.level,member.attributes)
		member.current_health = clampi(member.current_health + maxi(0,member.max_health - old_max),1,member.max_health)
		practice.erase(stat)
		gains[stat] = int(gains.get(stat,0)) + 1
		message = "%s's %s rises to %d." % [member.display_name,stat.to_upper(),int(member.attributes[stat])]
	else:
		practice[stat] = int(practice.get(stat,0)) + 1
		message = "%s trains hard but %s holds at %d. Practice will help next time." % [member.display_name,stat.to_upper(),int(member.attributes.get(stat,10))]
	training["practice"] = practice
	training["gains"] = gains
	member.training = training
	c._add_calendar_event("training",message)
	return {"ok":true,"success":success,"stat":stat,"chance":chance,"cost":int(check.cost),"message":message}

static func validate() -> Array[String]:
	var errors: Array[String] = []
	if qualities().is_empty(): errors.append("lodging.json has no room qualities.")
	var quality_ids := {}
	for value in qualities():
		var entry: Dictionary = value
		if String(entry.get("id","")).is_empty() or quality_ids.has(String(entry.id)): errors.append("Room quality ids must be unique and set.")
		quality_ids[String(entry.get("id",""))] = true
		if int(entry.get("slots",0)) < 1: errors.append("%s needs at least one furnishing slot." % entry.get("id",""))
	for furnishing_id in furnishings():
		var entry := furnishing(String(furnishing_id))
		for field in ["name","description","cost","stats","suits","min_quality"]:
			if not entry.has(field): errors.append("Furnishing %s is missing %s." % [furnishing_id,field])
		for stat in Dictionary(entry.get("stats",{})):
			if not ATTRIBUTE_IDS.has(String(stat)): errors.append("Furnishing %s boosts unknown stat %s." % [furnishing_id,stat])
		for class_id in Array(entry.get("suits",[])):
			if not AdventurerBuilds.CLASS_IDS.has(String(class_id)): errors.append("Furnishing %s suits unknown class %s." % [furnishing_id,class_id])
		if not quality_ids.has(String(entry.get("min_quality",""))): errors.append("Furnishing %s needs an unknown room quality." % furnishing_id)
	for class_id in AdventurerBuilds.CLASS_IDS:
		if not furnishings().values().any(func(entry): return Array(Dictionary(entry).get("suits",[])).has(class_id)): errors.append("No furnishing suits %s." % class_id)
	return errors
