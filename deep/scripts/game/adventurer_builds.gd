extends RefCounted
class_name AdventurerBuilds

## Class-independent stat blocks for arriving adventurers.
##
## Every arrival rolls a "build" (Brawler, Bookworm, Silver Tongue...) that shapes
## how their attribute points fall, plus the occasional hidden talent or old
## setback. The build is who they are; the class is the job the keeper gives them.
## Class fit is scored against each class's own base_stats in classes.json, so new
## classes are graded automatically.

const ATTRIBUTE_IDS := ["str","dex","con","int","wis","cha"]
const CLASS_IDS := ["warrior","mage","healer","tank","rogue","summoner"]
const FIT_GRADES := [[4.5,"Exceptional"],[3.0,"Strong"],[1.5,"Good"],[0.0,"Fair"]]
const POOR_GRADE := "Poor"
# Midpoints used when the keeper only knows a band or a contest estimate.
const BAND_ESTIMATES := {"Frail":6,"Average":10,"Strong":14,"Exceptional":17}

static func builds() -> Array:
	return AdventurerContent.pool("stat_builds")

static func rules() -> Dictionary:
	return Dictionary(AdventurerContent.data().get("stat_build_rules",{}))

static func build(id: String) -> Dictionary:
	for value in builds():
		if value is Dictionary and String(value.get("id","")) == id: return Dictionary(value)
	return {}

static func build_name(id: String) -> String:
	return String(build(id).get("name","Unremarkable"))

## Picks a build. With probability `aligned_chance` the build suits the calling
## class; otherwise any build can appear, which is where unexpected talent comes from.
static func pick_build(calling_class: String, rng: RandomNumberGenerator, aligned_chance: float) -> Dictionary:
	var all := builds()
	if all.is_empty(): return {}
	var aligned: Array = all.filter(func(value): return value is Dictionary and Array(value.get("callings",[])).has(calling_class))
	var source: Array = aligned if not aligned.is_empty() and rng.randf() < aligned_chance else all
	var total := 0.0
	for value in source: total += float(Dictionary(value).get("frequency",1.0))
	var pick := rng.randf() * total
	for value in source:
		pick -= float(Dictionary(value).get("frequency",1.0))
		if pick <= 0.0: return Dictionary(value)
	return Dictionary(source.back())

## Rolls a full stat block for a build. Quality (5–95, 35 is ordinary) sets the
## total point budget; the build decides where those points tend to land.
static func roll_attributes(build_data: Dictionary, quality: int, rng: RandomNumberGenerator) -> Dictionary:
	var r := rules()
	var floor_value := int(r.get("floor",6))
	var total := clampi(int(r.get("base_total",70)) + roundi((quality-35) / float(r.get("quality_per_point",6))), int(r.get("min_total",62)), int(r.get("max_total",84)))
	var cap := int(r.get("cap",17)) + (1 if quality >= 60 else 0) + (1 if quality >= 80 else 0)
	var flaw := String(build_data.get("flaw",""))
	var flaw_cap := int(r.get("flaw_cap",8))
	var off_weight := float(r.get("off_weight",0.6))
	var weights: Dictionary = Dictionary(build_data.get("weights",{}))
	var stats := {}
	for stat in ATTRIBUTE_IDS: stats[stat] = floor_value
	var remaining := total - floor_value*ATTRIBUTE_IDS.size()
	var guard := 0
	while remaining > 0 and guard < 500:
		guard += 1
		var open: Array[String] = []
		var open_weights: Array[float] = []
		var weight_sum := 0.0
		for stat in ATTRIBUTE_IDS:
			var limit := flaw_cap if stat == flaw else cap
			if int(stats[stat]) >= limit: continue
			var weight := float(weights.get(stat,0.0)) + off_weight
			open.append(stat); open_weights.append(weight); weight_sum += weight
		if open.is_empty(): break
		var pick := rng.randf() * weight_sum
		var chosen := open[open.size()-1]
		for index in open.size():
			pick -= open_weights[index]
			if pick <= 0.0: chosen = open[index]; break
		stats[chosen] = int(stats[chosen]) + 1
		remaining -= 1
	# A hidden talent: something the build would never predict.
	if rng.randf() < float(r.get("talent_chance",0.22)):
		var candidates: Array = ATTRIBUTE_IDS.filter(func(stat): return float(weights.get(stat,0.0)) <= 1.0 and stat != flaw)
		if not candidates.is_empty():
			var talent := String(candidates[rng.randi_range(0,candidates.size()-1)])
			var bonus: Array = Array(r.get("talent_bonus",[2,3]))
			stats[talent] = int(stats[talent]) + rng.randi_range(int(bonus[0]), int(bonus[1]))
	# An old injury or bad habit that dulls one of their better qualities.
	if rng.randf() < float(r.get("setback_chance",0.18)):
		var strong: Array = ATTRIBUTE_IDS.filter(func(stat): return float(weights.get(stat,0.0)) >= 1.0)
		if not strong.is_empty():
			var setback := String(strong[rng.randi_range(0,strong.size()-1)])
			var penalty: Array = Array(r.get("setback_penalty",[1,2]))
			stats[setback] = int(stats[setback]) - rng.randi_range(int(penalty[0]), int(penalty[1]))
	for stat in ATTRIBUTE_IDS: stats[stat] = clampi(int(stats[stat]), 4, 20)
	return stats

## The attribute an onlooker notices first: their single best stat.
static func lead_stat(attributes: Dictionary, build_id: String = "") -> String:
	var weights: Dictionary = Dictionary(build(build_id).get("weights",{}))
	var best := "str"; var best_value := -1; var best_weight := -1.0
	for stat in ATTRIBUTE_IDS:
		var value := int(attributes.get(stat,10)); var weight := float(weights.get(stat,0.0))
		if value > best_value or (value == best_value and weight > best_weight):
			best = stat; best_value = value; best_weight = weight
	return best

## How much a class leans on each attribute: its base_stats above 10, with an
## extra share for the stat that powers its attacks.
const POWER_STAT_WEIGHT := 4
static func class_weights(class_id: String) -> Dictionary:
	var data: Dictionary = GameBalance.get_base_class(class_id)
	var base: Dictionary = Dictionary(data.get("base_stats",{}))
	var power := String(Dictionary(data.get("primary",{})).get("power",""))
	var result := {}
	for stat in ATTRIBUTE_IDS:
		var weight := maxi(0, int(base.get(stat,10)) - 10) + (POWER_STAT_WEIGHT if stat == power else 0)
		if weight > 0: result[stat] = weight
	return result

## Average bonus above 10 on the attributes this class cares about.
static func class_fit_score(attributes: Dictionary, class_id: String) -> float:
	var weights := class_weights(class_id)
	var total := 0.0; var weight_sum := 0.0
	for stat in weights:
		total += (int(attributes.get(stat,10)) - 10) * float(weights[stat]); weight_sum += float(weights[stat])
	return total / weight_sum if weight_sum > 0.0 else 0.0

static func fit_grade(score: float) -> String:
	for entry in FIT_GRADES:
		if score >= float(entry[0]): return String(entry[1])
	return POOR_GRADE

static func class_fit(attributes: Dictionary, class_id: String) -> String:
	return fit_grade(class_fit_score(attributes, class_id))

## Classes ordered best fit first.
static func ranked_classes(attributes: Dictionary, allowed: Array) -> Array[String]:
	var result: Array[String] = []
	for value in allowed: result.append(String(value))
	result.sort_custom(func(a: String, b: String): return class_fit_score(attributes,a) > class_fit_score(attributes,b))
	return result

## The attributes as the keeper currently understands them. Exact appraisals are
## used as-is; bands and contest estimates use their midpoint; unknowns read as 10.
static func estimated_attributes(candidate: CandidateRecord) -> Dictionary:
	var member := candidate.adventurer
	var lead := lead_stat(member.attributes, member.stat_build_id)
	var result := {}
	for stat in ATTRIBUTE_IDS:
		var value := int(member.attributes.get(stat,10))
		var state := String(candidate.knowledge.get(stat, candidate.knowledge.get("primary_stat","unknown") if stat == lead else "unknown"))
		var contested := false
		for contest_id in VisitorContestRules.CONTESTS:
			if String(VisitorContestRules.CONTESTS[contest_id].stat) == stat and candidate.completed_interactions.has("contest:%s" % contest_id): contested = true
		if state == "exact": result[stat] = value
		elif state == "band" or contested or stat == lead: result[stat] = int(BAND_ESTIMATES.get(VisitorContestRules.band(value),10))
		else: result[stat] = 10
	return result

static func max_health_for(class_id: String, level: int, attributes: Dictionary) -> int:
	var rule: Dictionary = Dictionary(Dictionary(GameBalance.get_base_class(class_id).get("derived",{})).get("max_health",{}))
	var health := int(rule.get("base",1)) + (level-1) * int(rule.get("per_level",0))
	var stat := String(rule.get("stat",""))
	if not stat.is_empty():
		var modifier := int(floori(float(int(attributes.get(stat,10)) - 10) / 2.0)) + int(rule.get("stat_offset",0))
		health += maxi(int(rule.get("min",-999)), modifier)
	return maxi(1, health)

static func validate() -> Array[String]:
	var errors: Array[String] = []
	var ids := {}
	for value in builds():
		if not value is Dictionary: errors.append("Stat build entry is not an object."); continue
		var entry: Dictionary = value; var id := String(entry.get("id",""))
		if id.is_empty() or ids.has(id): errors.append("Missing or duplicate stat build ID: %s" % id)
		ids[id] = true
		if String(entry.get("name","")).is_empty() or String(entry.get("description","")).is_empty(): errors.append("%s needs a name and description." % id)
		var weights: Dictionary = Dictionary(entry.get("weights",{}))
		if weights.is_empty(): errors.append("%s has no stat weights." % id)
		for stat in weights:
			if not ATTRIBUTE_IDS.has(String(stat)): errors.append("%s weights unknown stat %s." % [id,stat])
		var flaw := String(entry.get("flaw",""))
		if not flaw.is_empty() and (not ATTRIBUTE_IDS.has(flaw) or weights.has(flaw)): errors.append("%s has an invalid flaw." % id)
		var callings: Array = Array(entry.get("callings",[]))
		if callings.is_empty(): errors.append("%s suits no class." % id)
		for class_id in callings:
			if not CLASS_IDS.has(String(class_id)): errors.append("%s suits unknown class %s." % [id,class_id])
	for class_id in CLASS_IDS:
		if not builds().any(func(value): return value is Dictionary and Array(value.get("callings",[])).has(class_id)): errors.append("No stat build suits %s." % class_id)
	return errors
