extends RefCounted
class_name HearthFacilities

static func quote(c: CampaignState, branch: String) -> Dictionary:
	if c.construction.has(branch): return {"gold":0,"essence":0,"levels":0,"available":false,"error":"Construction in progress."}
	var cost: Dictionary
	if branch == "roster_services":
		if c.establishment_tier >= 3: return {"gold":0,"essence":0,"levels":0,"available":false,"error":"Fully expanded."}
		cost = HearthCatalog.tier(c.establishment_tier+1).duplicate(true)
		cost["tier"] = c.establishment_tier
	else:
		var facility: Dictionary = HearthCatalog.data().facilities.get(branch,{})
		var rank := int(c.tavern_upgrades.get(branch,0))
		if facility.is_empty() or rank >= (1 if branch == "recovery" else 3): return {"gold":0,"essence":0,"levels":0,"available":false,"error":"Maximum rank reached."}
		cost = facility.ranks[rank].duplicate(true)
	cost["levels"] = 0
	cost["available"] = true
	return cost

static func purchase(c: CampaignState, branch: String) -> Dictionary:
	var cost := quote(c,branch)
	if not cost.available: return HearthArmory.fail(cost.error)
	if c.establishment_tier < int(cost.tier): return HearthArmory.fail("Expand the tavern first.")
	if c.reputation < int(cost.get("reputation",0)): return HearthArmory.fail("Earn more reputation before expanding.")
	if c.completed_dungeons.size() < int(cost.get("manual_clears",0)): return HearthArmory.fail("Explore and manually clear more distinct dungeons.")
	if c.banked_gold < int(cost.gold) or c.relic_essence < int(cost.essence): return HearthArmory.fail("Not enough gold or relic essence.")
	c.banked_gold -= int(cost.gold)
	c.relic_essence -= int(cost.essence)
	c.construction[branch] = {"due_day":c.calendar_day+int(cost.days)}
	return {"ok":true,"message":"Construction completes on Day %d." % c.construction[branch].due_day}

static func train(c: CampaignState, id: String) -> Dictionary:
	var member := c.character(id)
	if member == null or member.status != CharacterRecord.STATUS_AVAILABLE: return HearthArmory.fail("That adventurer is not ready to train.")
	var ceiling := mini(20, 2 + c.establishment_tier*4 + int(c.tavern_upgrades.replacement_quality))
	if int(c.tavern_upgrades.replacement_quality) == 0 or member.level >= ceiling: return HearthArmory.fail("Improve Training to develop this adventurer further.")
	var cost := 15*member.level
	if c.banked_gold < cost: return HearthArmory.fail("Training costs %d gold." % cost)
	c.banked_gold -= cost
	member.level += 1
	member.progression.level = member.level
	member.xp = int(GameBalance.get_progression().xp_thresholds[member.level])
	member.progression.xp = member.xp
	member.progression.total_xp = maxi(member.xp,int(member.progression.get("total_xp",0)))
	member.recovery_until = c.calendar_day+2
	member.status = "recovering"
	return {"ok":true,"message":"Training completes in two days."}
