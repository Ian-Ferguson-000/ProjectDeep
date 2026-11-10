extends RefCounted
class_name HearthUpkeep

## Keeping the company fed and happy (data/upkeep.json), Mewgenics style.
##
## The Hearth's pantry holds supplies in three qualities. Once a day everyone at
## home eats one ration of the quality you serve: better food lifts their
## happiness, scraps wear it down, an empty pantry hurts. Training is hard work
## and costs a little happiness. Every expedition takes rations with it, and
## how it went changes the hero's mood on return. An adventurer whose happiness
## falls too low may walk out at the start of a day, more likely the day after
## training. Happiness is CharacterRecord.morale (0-100).

const PATH := "res://data/upkeep.json"
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func foods() -> Dictionary:
	return Dictionary(data().get("foods", {}))


static func food(id: String) -> Dictionary:
	return Dictionary(foods().get(id, {}))


static func order() -> Array:
	return Array(data().get("order", ["scraps", "hearty", "feast"]))


static func rations_per_run() -> int:
	return int(data().get("rations_per_run", 2))


static func new_pantry() -> Dictionary:
	var pantry := {}
	for id in order():
		pantry[id] = int(Dictionary(data().get("starting_pantry", {})).get(id, 0))
	return pantry


static func total(c: CampaignState) -> int:
	var count := 0
	for id in order():
		count += int(c.pantry.get(id, 0))
	return count


## Who eats at the Hearth: everyone home (available, recovering, training).
static func diners(c: CampaignState) -> Array[CharacterRecord]:
	var result: Array[CharacterRecord] = []
	for member in c.living_roster():
		if member.status != CharacterRecord.STATUS_EXPEDITION:
			result.append(member)
	return result


## The order rations are drawn in: what you serve, then cheaper, then better.
static func draw_order(c: CampaignState) -> Array:
	var served := String(c.served_food)
	var list: Array = [served]
	var index := order().find(served)
	for step in range(index - 1, -1, -1):
		list.append(order()[step])
	for step in range(index + 1, order().size()):
		list.append(order()[step])
	return list


## Takes up to `count` rations; returns the quality of each one taken.
static func take(c: CampaignState, count: int) -> Array[String]:
	var taken: Array[String] = []
	for id in draw_order(c):
		while taken.size() < count and int(c.pantry.get(id, 0)) > 0:
			c.pantry[id] = int(c.pantry[id]) - 1
			taken.append(String(id))
	return taken


static func add(c: CampaignState, id: String, count: int) -> void:
	c.pantry[id] = int(c.pantry.get(id, 0)) + count


static func buy(c: CampaignState, id: String, count: int = 1) -> Dictionary:
	if food(id).is_empty():
		return HearthArmory.fail("Unknown supplies.")
	var price := int(food(id).get("cost", 1)) * count
	if c.banked_gold < price:
		return HearthArmory.fail("Not enough gold for %d %s." % [count, String(food(id).name)])
	c.banked_gold -= price
	add(c, id, count)
	return {"ok": true, "message": "Bought %d %s for %dg." % [count, String(food(id).name), price]}


static func serve(c: CampaignState, id: String) -> Dictionary:
	if food(id).is_empty():
		return HearthArmory.fail("Unknown supplies.")
	c.served_food = id
	return {"ok": true, "message": "The Hearth now serves %s." % String(food(id).name)}


## Days the pantry lasts at the current headcount.
static func days_left(c: CampaignState) -> int:
	var eaters := maxi(1, diners(c).size())
	return int(total(c) / eaters)


static func happiness(member: CharacterRecord) -> int:
	return member.morale


static func change(member: CharacterRecord, amount: int) -> void:
	member.morale = clampi(member.morale + amount, 0, 100)


static func band(value: int) -> Dictionary:
	for entry in Array(data().get("bands", [])):
		if value >= int(entry.get("min", 0)):
			return entry
	return {"name": "Miserable", "color": "#e07a62"}


## Runs at the start of each new day. Returns calendar lines.
static func daily(c: CampaignState) -> Array[String]:
	var events: Array[String] = []
	var hungry: Array[String] = []
	for member in diners(c):
		var meal := take(c, 1)
		if meal.is_empty():
			change(member, int(data().get("hungry_happiness", -15)))
			hungry.append(member.display_name)
		else:
			change(member, int(food(meal[0]).get("happiness", 0)))
		if int(member.training.get("last_day", -99)) == c.calendar_day - 1:
			change(member, int(data().get("training_happiness", -4)))
	if not hungry.is_empty():
		events.append("The pantry is empty: %s went hungry." % ", ".join(hungry))
	# Walking out: unhappy adventurers at home may leave, more so the day after training.
	for member in diners(c):
		if (
			member.status != CharacterRecord.STATUS_AVAILABLE
			or member.morale >= int(data().get("leave_below", 25))
		):
			continue
		if not c.first_normal_launch_completed and c.first_company_ids.has(member.id):
			continue
		var trained := int(member.training.get("last_day", -99)) == c.calendar_day - 1
		var chance := float(
			data().get("leave_chance_after_training" if trained else "leave_chance", 0.2)
		)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s:%d:leave" % [member.id, c.calendar_day])
		if rng.randf() >= chance:
			continue
		var name := member.display_name
		if HearthCalendar.retire(c, member).ok:
			events.append("%s has had enough of the Hearth and leaves." % name)
	return events


## How an expedition went changes the returning hero's mood.
static func on_return(c: CampaignState, ids: Array, outcome: String) -> void:
	var key: String = String(
		{"victory": "victory_happiness", "retreat": "retreat_happiness"}.get(
			outcome, "defeat_happiness"
		)
	)
	for id in ids:
		var member := c.character(String(id))
		if member != null and member.status != CharacterRecord.STATUS_DEAD:
			change(member, int(data().get(key, 0)))
