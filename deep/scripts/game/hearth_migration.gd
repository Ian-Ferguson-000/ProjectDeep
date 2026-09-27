extends RefCounted
class_name HearthMigration

static func upgrade(c: CampaignState, data: Dictionary) -> void:
	if data.has("armory"): return
	for branch in Dictionary(data.get("tavern_upgrades",{})):
		var old_rank := maxi(0,int(data.tavern_upgrades[branch]))
		if old_rank > 3:
			var refunded_ranks := int(old_rank*(old_rank+1)/2)-6
			c.banked_gold += 20*refunded_ranks
			c.relic_essence += 5*refunded_ranks
	for member in c.living_roster():
		var permanent: Array = Array(member.progression.get("permanent_items",[]))
		var remaining: Array = []
		for entry in permanent:
			var old_id := String(entry.get("id","")) if entry is Dictionary else String(entry)
			var target := mapped_item(old_id)
			if target.is_empty(): remaining.append(entry); continue
			HearthArmory.grant(c,target)
		member.progression["permanent_items"] = remaining
		if member.progression.has("runtime_inventory"):
			member.progression.runtime_inventory = Array(member.progression.runtime_inventory).filter(func(entry:Dictionary): return mapped_item(String(entry.get("id",""))).is_empty())
	for old_id in Array(data.get("pending_shop_items",c.legacy_runtime.get("pending_shop_items",[]))):
		var target := mapped_item(String(old_id))
		if not target.is_empty(): HearthArmory.grant(c,target)
	for id in Array(data.get("pending_shop_consumables",c.legacy_runtime.get("pending_shop_consumables",[]))):
		c.consumable_stock[id] = int(c.consumable_stock.get(id,0))+1
	c.legacy_runtime.erase("pending_shop_items")
	c.legacy_runtime.erase("pending_shop_consumables")

static func mapped_item(id: String) -> String:
	if not HearthCatalog.item(id).is_empty(): return id
	if not HearthCatalog.item("hearth_"+id).is_empty(): return "hearth_"+id
	return ""
