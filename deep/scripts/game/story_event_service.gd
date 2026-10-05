extends RefCounted
class_name StoryEventService

const EVENTS_PATH := "res://data/story/events.json"
static var _events: Dictionary = {}

static func events() -> Dictionary:
	if _events.is_empty(): _events = Dictionary(_load_json(EVENTS_PATH).get("events", {})).duplicate(true)
	return _events

static func definition(event_id: String) -> Dictionary:
	return Dictionary(events().get(event_id, {})).duplicate(true)

static func can_play(event_id: String, campaign: CampaignState) -> bool:
	var event := definition(event_id)
	if event.is_empty(): return false
	if campaign == null or String(event.get("repeat", "repeatable")) == "repeatable": return true
	var prior: Variant = campaign.story_event_history.get(event_id)
	if prior == null: return true
	if String(event.get("repeat", "")) == "once_ever": return false
	var record := Dictionary(prior) if prior is Dictionary else {}
	return int(record.get("loop_number", -1)) != int(campaign.keeper_memory.get("loop_number", 0))

static func lines(event_id: String, campaign: CampaignState, variant: String = "default", values: Dictionary = {}) -> Array[Dictionary]:
	var event := definition(event_id)
	var variants := Dictionary(event.get("variants", {}))
	var source: Array = Array(variants.get(variant, variants.get("default", [])))
	var rendered: Array[Dictionary] = []
	for value in source:
		var line := Dictionary(value).duplicate(true)
		for key in values:
			line["speaker"] = String(line.get("speaker", "")).replace("{%s}" % key, String(values[key]))
			line["text"] = String(line.get("text", "")).replace("{%s}" % key, String(values[key]))
			line["portrait"] = String(line.get("portrait", "")).replace("{%s}" % key, String(values[key]))
		rendered.append(line)
	return rendered

static func mark_played(event_id: String, campaign: CampaignState, variant: String = "default") -> void:
	if campaign == null or definition(event_id).is_empty(): return
	var first_completion := can_play(event_id,campaign)
	if first_completion and bool(definition(event_id).get("major",false)): HearthCalendar.reset_story_period(campaign)
	campaign.story_event_history[event_id] = {"loop_number":int(campaign.keeper_memory.get("loop_number", 0)),"day":campaign.calendar_day,"variant":variant}

static func validate() -> Array[String]:
	var errors: Array[String] = []
	for event_id in events():
		var event := Dictionary(events()[event_id])
		if String(event.get("repeat", "")) not in ["repeatable", "once_ever", "once_per_loop"]: errors.append("Story event %s has an invalid repeat policy." % event_id)
		if Dictionary(event.get("variants", {})).is_empty(): errors.append("Story event %s has no variants." % event_id)
	return errors

static func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return Dictionary(parsed) if parsed is Dictionary else {}
