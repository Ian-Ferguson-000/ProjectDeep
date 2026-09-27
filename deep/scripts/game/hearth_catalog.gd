extends RefCounted
class_name HearthCatalog

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/hearth_campaign.json"))
	return _data

static func item(id: String) -> Dictionary:
	return data().items.get(id, {})

static func tier(rank: int) -> Dictionary:
	return data().tiers[clampi(rank, 0, 3)]

static func gear(id: String) -> GearData:
	var entry := item(id)
	if entry.is_empty() or entry.slot != "weapon": return null
	var specials := {"warrior":"charge","mage":"force_blast","healer":"recover","tank":"shield_bash","rogue":"assassinate","summoner":"bond"}
	var special_id := String(entry.get("special_id",specials.get(entry.class_id,"")))
	return GearData.create(id, entry.name, int(entry.damage), bool(entry.get("block", false)), int(entry.get("block_limit", 0)), special_id, entry.description, entry.class_id, entry.get("defense_id","block" if entry.get("block", false) else "none"))

static func modifiers(campaign: CampaignState, member: CharacterRecord) -> Dictionary:
	var result: Dictionary = {}
	for instance_id in member.equipment.values():
		var instance: Dictionary = campaign.armory.get(instance_id, {})
		var entry := item(String(instance.get("item_id", "")))
		for key in Dictionary(entry.get("modifiers", {})):
			result[key] = float(result.get(key, 0)) + float(entry.modifiers[key])
	return result
