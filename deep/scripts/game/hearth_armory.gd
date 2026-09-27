extends RefCounted
class_name HearthArmory

static func grant(c: CampaignState, item_id: String, bound: bool = false) -> String:
	if HearthCatalog.item(item_id).is_empty(): return ""
	var id := "gear_%d" % c.next_item_id
	c.next_item_id += 1
	c.armory[id] = {"item_id":item_id, "owner":"", "bound":bound}
	return id

static func equip(c: CampaignState, character_id: String, instance_id: String) -> Dictionary:
	var member := c.character(character_id)
	if member == null or member.status != CharacterRecord.STATUS_AVAILABLE: return fail("Only adventurers at home can change equipment.")
	var instance: Dictionary = c.armory.get(instance_id, {})
	if instance.is_empty(): return fail("This item is no longer in the armory.")
	if not String(instance.owner).is_empty() and instance.owner != character_id: return fail("This item is assigned to another adventurer.")
	var entry := HearthCatalog.item(instance.item_id)
	if entry.get("class_id", member.class_id) != member.class_id: return fail("This weapon belongs to another class.")
	var slot: String = entry.slot
	unequip(c, character_id, slot)
	member.equipment[slot] = instance_id
	instance.owner = character_id
	if slot == "weapon": member.gear_id = instance.item_id
	return {"ok":true,"message":"%s equips %s." % [member.display_name, entry.name]}

static func unequip(c: CampaignState, character_id: String, slot: String) -> Dictionary:
	var member := c.character(character_id)
	if member == null or member.status != CharacterRecord.STATUS_AVAILABLE: return fail("Only adventurers at home can change equipment.")
	var id: String = member.equipment.get(slot, "")
	if c.armory.has(id): c.armory[id].owner = ""
	member.equipment.erase(slot)
	if slot == "weapon": member.gear_id = ""
	return {"ok":true}

static func release(c: CampaignState, member: CharacterRecord, lost: bool = false) -> void:
	for id in member.equipment.values():
		if not c.armory.has(id): continue
		if lost: c.armory.erase(id)
		else: c.armory[id].owner = ""
	member.equipment.clear()

static func buy(c: CampaignState, item_id: String) -> Dictionary:
	var entry := HearthCatalog.item(item_id)
	if entry.is_empty() or not entry.sources.has("merchant"): return fail("This item must be recovered from a dungeon.")
	if int(entry.tier) > c.establishment_tier: return fail("Expand the Hearth to attract this equipment.")
	var key := "%d:%s" % [int((c.calendar_day - 1) / 7), item_id]
	var remaining := int(c.market_stock.get(key, 2 + int(c.tavern_upgrades.merchant_stock)))
	if remaining <= 0: return fail("Sold out until the next week.")
	if c.banked_gold < int(entry.price): return fail("Not enough banked gold.")
	c.banked_gold -= int(entry.price)
	c.market_stock[key] = remaining - 1
	return {"ok":true,"instance_id":grant(c,item_id),"message":"Purchased %s." % entry.name}

static func sell(c: CampaignState, id: String) -> Dictionary:
	var instance: Dictionary = c.armory.get(id, {})
	if instance.is_empty(): return fail("This item is no longer available.")
	if instance.get("bound", false): return fail("Starter equipment cannot be sold.")
	if not String(instance.owner).is_empty(): return fail("Unassign this item before selling it.")
	var price := int(HearthCatalog.item(instance.item_id).price / 3)
	c.banked_gold += price
	c.armory.erase(id)
	return {"ok":true,"message":"Sold for %d gold." % price}

static func provision(c: CampaignState, character_id: String, consumable_id: String) -> Dictionary:
	var member := c.character(character_id)
	if member == null or member.status != CharacterRecord.STATUS_AVAILABLE: return fail("That adventurer is away.")
	if member.provisions.size() >= 4: return fail("All four consumable slots are filled.")
	if int(c.consumable_stock.get(consumable_id,0)) <= 0: return fail("No bottle of that type is in storage.")
	c.consumable_stock[consumable_id] -= 1
	member.provisions.append(consumable_id)
	return {"ok":true,"message":"Provision assigned."}

static func buy_consumable(c: CampaignState, id: String) -> Dictionary:
	if not HearthCatalog.data().consumables.has(id): return fail("Unknown provision.")
	var price := 8 if id == "healing_potion" else 18
	if c.banked_gold < price: return fail("Not enough gold.")
	c.banked_gold -= price
	c.consumable_stock[id] = int(c.consumable_stock.get(id,0)) + 1
	return {"ok":true,"message":"Provision added to storage."}

static func ensure_starter(c: CampaignState, member: CharacterRecord) -> void:
	if member.equipment.has("weapon"): return
	var item_id: String = member.gear_id
	if HearthCatalog.item(item_id).is_empty(): item_id = CampaignState.BASIC_GEAR.get(member.class_id,"sword_shield")
	var id := grant(c, item_id, true)
	member.equipment.weapon = id
	c.armory[id].owner = member.id
	member.gear_id = item_id

static func fail(message: String) -> Dictionary:
	return {"ok":false,"error":message}
