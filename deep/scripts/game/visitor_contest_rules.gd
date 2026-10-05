extends RefCounted
class_name VisitorContestRules

const CONTESTS := {
	"arm_wrestling": {"name":"Arm Wrestling", "stat":"str"},
	"memory_match": {"name":"Memory Match", "stat":"int"},
	"quick_draw": {"name":"Quick Draw", "stat":"dex"},
	"drinking": {"name":"Drinking Contest", "stat":"con"},
}
const TUNING := {
	"countdown":3.0, "arm_duration":20.0, "arm_push":0.07, "arm_cooldown":0.06,
	"arm_pull_base":0.10, "arm_pull_scale":0.40,
	"memory_rounds":5, "memory_show":2.0, "memory_select":8.0,
	"memory_recall_base":0.35, "memory_recall_scale":0.60,
	"reaction_targets":12, "reaction_wait_min":0.5, "reaction_wait_max":1.2,
	"reaction_lifetime":1.0, "reaction_base":0.85, "reaction_scale":0.65,
	"reaction_jitter":0.08, "reaction_miss":0.25,
	"drink_rounds":5, "drink_cues":4, "drink_spacing":0.65, "drink_window":0.15,
	"drink_failures":3, "drink_success_base":0.55, "drink_success_scale":0.43,
}
const LEARNING := {"deliberate":0.90, "steady":1.0, "quick_learner":1.15}

static func ability(value:int) -> float:
	return float(clampi(value,4,20)-4)/16.0

static func band(value:int) -> String:
	return "Frail" if value<=7 else ("Average" if value<=11 else ("Strong" if value<=15 else "Exceptional"))

static func stat_range(value:int) -> String:
	if value<=7:return "4–7"
	if value<=11:return "8–11"
	if value<=15:return "12–15"
	return "16–20"

static func stat_analysis(value:int,exact_known:bool=false) -> String:
	return "%d (appraised)"%value if exact_known else "%s (estimated)"%stat_range(value)

static func learning_tier(identity:String) -> String:
	var rng:=RandomNumberGenerator.new()
	rng.seed=identity.hash() ^ 0x61eaf
	var roll:=rng.randf()
	return "deliberate" if roll<0.2 else ("steady" if roll<0.8 else "quick_learner")

static func learning_name(tier:String) -> String:
	return {"deliberate":"Deliberate", "steady":"Steady", "quick_learner":"Quick Learner"}.get(tier,"Steady")

static func scale_xp(amount:int, tier:String) -> int:
	return maxi(1,roundi(amount*float(LEARNING.get(tier,1.0)))) if amount>0 else 0
