extends RefCounted
class_name PartyCompatibility

const DOCTRINES_PATH := "res://data/story/doctrines.json"
static var _doctrines: Dictionary = {}

static func doctrines() -> Dictionary:
	if _doctrines.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DOCTRINES_PATH))
		_doctrines = Dictionary(Dictionary(parsed).get("doctrines", {})).duplicate(true) if parsed is Dictionary else {}
	return _doctrines

static func doctrine_name(doctrine_id: String) -> String:
	return String(Dictionary(doctrines().get(doctrine_id, doctrines().get("unaligned", {}))).get("name", "Undeclared"))

static func evaluate(campaign: CampaignState, ids: Array[String]) -> Dictionary:
	var score := 0
	var reasons: Array[String] = []
	var nations: Dictionary = {}
	for id in ids:
		var member := campaign.character(id) if campaign != null else null
		if member != null: nations[member.nation_id] = true
	for left_index in range(ids.size()):
		var left := campaign.character(ids[left_index]) if campaign != null else null
		if left == null: continue
		for right_index in range(left_index + 1, ids.size()):
			var right := campaign.character(ids[right_index])
			if right == null: continue
			var pair_score := clampi(int(left.relationships.get(right.id, 0)), -2, 2)
			if left.doctrine_id == right.doctrine_id and left.doctrine_id != "unaligned":
				pair_score += 1
				reasons.append("%s and %s share the %s." % [left.display_name, right.display_name, doctrine_name(left.doctrine_id)])
			elif doctrines_conflict(left.doctrine_id, right.doctrine_id):
				pair_score -= 1
				reasons.append("%s and %s disagree about what must happen to the prisons." % [left.display_name, right.display_name])
			if left.preference == right.preference:
				pair_score += 1
				reasons.append("%s and %s share an off-road ritual: %s." % [left.display_name, right.display_name, left.preference])
			score += clampi(pair_score, -3, 3)
	if nations.size() > 1:
		score += 1
		reasons.append("A cross-national party brings more than one doctrine's field knowledge.")
	return {"score":score,"multiplier":clampf(1.0+float(score)*0.04,0.84,1.16),"band":"Cohesive" if score>=2 else ("Strained" if score<0 else "Stable"),"reasons":reasons}

static func doctrines_conflict(left_id: String, right_id: String) -> bool:
	return Array(Dictionary(doctrines().get(left_id, {})).get("conflicts", [])).has(right_id) or Array(Dictionary(doctrines().get(right_id, {})).get("conflicts", [])).has(left_id)

static func record_shared_outcome(campaign: CampaignState, ids: Array[String], outcome: String) -> void:
	if campaign == null or outcome not in ["victory", "retreat"]: return
	for left_index in range(ids.size()):
		var left := campaign.character(ids[left_index])
		if left == null or left.status == CharacterRecord.STATUS_DEAD: continue
		for right_index in range(left_index + 1, ids.size()):
			var right := campaign.character(ids[right_index])
			if right == null or right.status == CharacterRecord.STATUS_DEAD: continue
			left.relationships[right.id] = clampi(int(left.relationships.get(right.id, 0)) + 1, -3, 3)
			right.relationships[left.id] = clampi(int(right.relationships.get(left.id, 0)) + 1, -3, 3)
