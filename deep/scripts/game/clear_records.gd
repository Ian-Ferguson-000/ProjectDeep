extends RefCounted
class_name ClearRecords

## Dungeons are never "finished": every run that defeats a dungeon's guardian is
## a clear, timed from entering the dungeon to the guardian falling. Success is
## measured by those times: the best overall and the best for each class.
##
## Stored on CampaignState.clear_records and kept through Hearth loops:
## {dungeon_id: {
##     "clears": int,
##     "best": {time, class_id, hero, day},
##     "best_by_class": {class_id: {time, hero, day}},
##     "recent": [{time, class_id, hero, day, best_for_class, best_overall}]  (newest first)
## }}
##
## The run clock only advances while you are inside a dungeon and the game is
## not paused (see SlasherForest._process).

const RECENT_LIMIT := 10

static func record_clear(campaign, dungeon_id: String, class_id: String, hero: String, seconds: float) -> Dictionary:
	seconds = maxf(0.1,snappedf(seconds,0.1))
	var entry: Dictionary = Dictionary(campaign.clear_records.get(dungeon_id,{})).duplicate(true)
	var by_class: Dictionary = Dictionary(entry.get("best_by_class",{}))
	var class_best: Dictionary = Dictionary(by_class.get(class_id,{}))
	var overall: Dictionary = Dictionary(entry.get("best",{}))
	var day := int(campaign.calendar_day)
	var record := {"time":seconds,"class_id":class_id,"hero":hero,"day":day}
	var result := {
		"time":seconds,"dungeon_id":dungeon_id,"class_id":class_id,
		"previous_class_best":float(class_best.get("time",0.0)),
		"previous_best":float(overall.get("time",0.0)),
		"first_clear":int(entry.get("clears",0)) == 0,
		"first_for_class":class_best.is_empty(),
	}
	result["best_for_class"] = class_best.is_empty() or seconds < float(class_best.get("time",INF))
	result["best_overall"] = overall.is_empty() or seconds < float(overall.get("time",INF))
	if bool(result.best_for_class): by_class[class_id] = {"time":seconds,"hero":hero,"day":day}
	if bool(result.best_overall): entry["best"] = record.duplicate()
	entry["best_by_class"] = by_class
	entry["clears"] = int(entry.get("clears",0)) + 1
	var recent: Array = Array(entry.get("recent",[]))
	var logged := record.duplicate()
	logged["best_for_class"] = result.best_for_class
	logged["best_overall"] = result.best_overall
	recent.push_front(logged)
	entry["recent"] = recent.slice(0,RECENT_LIMIT)
	campaign.clear_records[dungeon_id] = entry
	result["message"] = summary(result)
	return result

static func clears(campaign, dungeon_id: String) -> int:
	return int(Dictionary(campaign.clear_records.get(dungeon_id,{})).get("clears",0))

## Best record for a dungeon; with a class, the best by that class. Empty if none.
static func best(campaign, dungeon_id: String, class_id: String = "") -> Dictionary:
	var entry: Dictionary = Dictionary(campaign.clear_records.get(dungeon_id,{}))
	if class_id.is_empty(): return Dictionary(entry.get("best",{}))
	return Dictionary(Dictionary(entry.get("best_by_class",{})).get(class_id,{}))

static func recent(campaign, dungeon_id: String) -> Array:
	return Array(Dictionary(campaign.clear_records.get(dungeon_id,{})).get("recent",[]))

static func total_clears(campaign) -> int:
	var total := 0
	for entry in campaign.clear_records.values(): total += int(Dictionary(entry).get("clears",0))
	return total

## 754.3 -> "12:34.3"; an hour or more -> "1:02:34".
static func format_time(seconds: float) -> String:
	if seconds <= 0.0: return "--:--"
	var whole := int(floor(seconds))
	var tenths := int(floor((seconds - whole) * 10.0 + 0.0001))
	if whole >= 3600: return "%d:%02d:%02d" % [whole / 3600,(whole / 60) % 60,whole % 60]
	return "%d:%02d.%d" % [whole / 60,whole % 60,tenths]

## "+0:12.4" slower or "-0:03.1" faster than a reference time.
static func format_delta(seconds: float, reference: float) -> String:
	var delta := seconds - reference
	return ("+" if delta >= 0.0 else "-") + format_time(maxf(0.1,absf(delta)))

static func summary(result: Dictionary) -> String:
	var class_name_text := String(result.class_id).capitalize()
	var time_text := format_time(float(result.time))
	if bool(result.first_clear): return "First clear in %s." % time_text
	if bool(result.best_overall): return "%s · a new record, %s faster than the old best!" % [time_text,format_time(float(result.previous_best) - float(result.time))]
	if bool(result.first_for_class): return "%s · the first %s clear." % [time_text,class_name_text]
	if bool(result.best_for_class): return "%s · a new %s best by %s." % [time_text,class_name_text,format_time(float(result.previous_class_best) - float(result.time))]
	return "%s · %s best is %s." % [time_text,class_name_text,format_time(float(result.previous_class_best))]
