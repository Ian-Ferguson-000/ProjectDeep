extends RefCounted
class_name TavernDialogueService

const CONVERSATIONS_PATH := "res://data/tavern_conversations.json"
const CRITERIA_PATH := "res://data/tavern_recruitment_criteria.json"

var conversations: Dictionary = {}
var criteria: Dictionary = {}
var messages: Dictionary = {}

func _init() -> void:
	conversations = _load_json(CONVERSATIONS_PATH).get("conversations", {})
	var requirement_data := _load_json(CRITERIA_PATH)
	criteria = requirement_data.get("criteria", {})
	criteria["default"] = requirement_data.get("default", {"all": []})
	messages = requirement_data.get("messages", {})

func play(conversation_id: String, context: Dictionary = {}) -> Dictionary:
	var conversation: Dictionary = conversations.get(conversation_id, conversations.get("merchant_default", {}))
	var node_id := String(conversation.get("start", ""))
	for route_value in conversation.get("routes", []):
		var route := Dictionary(route_value)
		if evaluate_condition(Dictionary(route.get("condition", {})), context):
			node_id = String(route.get("node", node_id))
			break
	var node: Dictionary = Dictionary(conversation.get("nodes", {})).get(node_id, {})
	return {"conversation_id": conversation_id, "node_id": node_id, "lines": _render_lines(Array(node.get("lines", [])), context), "choices": Array(node.get("choices", [])).duplicate(true), "effects": Dictionary(node.get("effects", {})).duplicate(true), "context": context}

func _render_lines(source_lines: Array, context: Dictionary) -> Array:
	var values := _dialogue_values(context)
	var rendered: Array = []
	for line_value in source_lines:
		var line := Dictionary(line_value).duplicate(true)
		for key in values:
			line["speaker"] = String(line.get("speaker", "")).replace("{%s}" % key, String(values[key]))
			line["text"] = String(line.get("text", "")).replace("{%s}" % key, String(values[key]))
		rendered.append(line)
	return rendered

func _dialogue_values(context: Dictionary) -> Dictionary:
	var candidate := context.get("candidate") as CandidateRecord
	var member: CharacterRecord = candidate.adventurer if candidate != null else context.get("member") as CharacterRecord
	if member == null: return {}
	return {
		"name": member.display_name,
		"class": member.class_id.capitalize(),
		"origin": member.origin,
		"occupation": member.occupation,
		"personality": member.personality,
		"preference": member.preference,
		"biography": member.biography,
		"motivation": candidate.motivation if candidate != null else "I want my next choice to mean something.",
	}

func evaluate_condition(condition: Dictionary, context: Dictionary) -> bool:
	if condition.is_empty():
		return true
	if condition.has("all"):
		for item in condition.all:
			if not evaluate_condition(Dictionary(item), context): return false
		return true
	if condition.has("any"):
		for item in condition.any:
			if evaluate_condition(Dictionary(item), context): return true
		return false
	if condition.has("not"):
		return not evaluate_condition(Dictionary(condition.get("not", {})), context)
	var campaign: CampaignState = context.get("campaign") as CampaignState
	if condition.has("flag"):
		return campaign != null and bool(campaign.tavern_dialogue_flags.get(String(condition.flag), false))
	if condition.has("campaign") and campaign != null:
		var key := String(condition.campaign)
		var value: Variant = campaign.get(key) if key in ["calendar_day", "reputation", "successful_levels"] else null
		if condition.has("gte"): return value != null and float(value) >= float(condition.gte)
		if condition.has("lte"): return value != null and float(value) <= float(condition.lte)
		if condition.has("equals"): return value != null and value == condition.equals
	if condition.has("completed_dungeon") and campaign != null:
		return campaign.has_completed_dungeon(String(condition.get("completed_dungeon")))
	if condition.has("upgrade_rank") and campaign != null:
		var upgrade_id:=String(condition.get("upgrade_rank"));var rank:=int(campaign.tavern_upgrades.get(upgrade_id,0))
		return rank >= int(condition.get("gte",1))
	if condition.has("merchant_recruited"):
		var run_state:RunState=context.get("run_state") as RunState
		return run_state != null and run_state.is_merchant_recruited(String(condition.get("merchant_recruited")))
	if condition.has("candidate_knowledge"):
		var candidate: CandidateRecord = context.get("candidate") as CandidateRecord
		return candidate != null and String(candidate.knowledge.get(String(condition.candidate_knowledge), "unknown")) == String(condition.get("equals", "exact"))
	return false

func apply_effects(effects: Dictionary, context: Dictionary) -> void:
	var campaign: CampaignState = context.get("campaign") as CampaignState
	if campaign == null: return
	for flag in effects.get("add_flags", []): campaign.tavern_dialogue_flags[String(flag)] = true
	for flag in effects.get("remove_flags", []): campaign.tavern_dialogue_flags.erase(String(flag))
	var candidate: CandidateRecord = context.get("candidate") as CandidateRecord
	for knowledge in effects.get("reveal_knowledge", []):
		if candidate != null: candidate.knowledge[String(knowledge)] = "exact"

func recruitment_requirement(candidate_id: String) -> Dictionary:
	return Dictionary(criteria.get(candidate_id, criteria.get("default", {"all": []}))).duplicate(true)

func requirement_message(candidate_id: String, context: Dictionary) -> String:
	var requirement := recruitment_requirement(candidate_id)
	if evaluate_condition(requirement, context): return ""
	var flag := String(requirement.get("flag", ""))
	return String(messages.get(flag, "This adventurer is not ready to join the company yet."))

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing tavern data file: " + path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	if not parsed is Dictionary:
		push_error("Invalid tavern JSON: " + path)
		return {}
	return parsed
