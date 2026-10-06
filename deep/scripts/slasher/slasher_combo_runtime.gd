extends RefCounted
class_name SlasherComboRuntime

var kit_id := ""
var class_id: String = ""
var recipes: Array[Dictionary] = []
var states: Dictionary = {}

func setup(value: String, kit: String = "standard", names: Dictionary = {}) -> void:
	class_id = GameBalance.normalize_class_id(value)
	kit_id=kit
	recipes = preload("res://scripts/slasher/slasher_mage_combos.gd").recipes(kit,names) if class_id=="mage" else preload("res://scripts/slasher/slasher_warrior_combos.gd").recipes(kit,names) if class_id=="warrior" else GameBalance.get_slasher_combos(class_id)
	states.clear()
	for recipe in recipes:
		states[String(recipe.get("id", ""))] = {"index": 0, "remaining": 0.0}

func record_action(slot: String) -> Dictionary:
	return _record("action:" + slot, true)

func record_confirmation(token: String) -> Dictionary:
	return _record("confirm:" + token, false)

func tick(delta: float) -> bool:
	var changed := false
	for recipe in recipes:
		var id := String(recipe.get("id", ""))
		var state: Dictionary = states.get(id, {"index": 0, "remaining": 0.0})
		if int(state.get("index", 0)) <= 0: continue
		state.remaining = maxf(0.0, float(state.get("remaining", 0.0)) - delta)
		if state.remaining <= 0.0:
			state.index = 0
			changed = true
		states[id] = state
	return changed

func snapshot() -> Dictionary:
	return {"class_id": class_id, "kit_id":kit_id,"states": states.duplicate(true)}

func restore(value: Dictionary) -> void:
	if String(value.get("class_id", class_id)) != class_id or String(value.get("kit_id",kit_id))!=kit_id: return
	var saved: Dictionary = Dictionary(value.get("states", {}))
	for recipe in recipes:
		var id := String(recipe.get("id", ""))
		if saved.get(id) is Dictionary:
			var state: Dictionary = Dictionary(saved[id])
			var maximum := Array(recipe.get("steps", [])).size()
			states[id] = {"index": clampi(int(state.get("index", 0)), 0, maximum), "remaining": maxf(0.0, float(state.get("remaining", 0.0)))}

func feedback() -> Dictionary:
	return _best_progress()

func _record(token: String, is_action: bool) -> Dictionary:
	var completed: Array[Dictionary] = []
	for recipe in recipes:
		var id := String(recipe.get("id", ""))
		var steps: Array = recipe.get("steps", [])
		if steps.is_empty(): continue
		var state: Dictionary = states.get(id, {"index": 0, "remaining": 0.0})
		var index := int(state.get("index", 0))
		if index > 0 and float(state.get("remaining", 0.0)) <= 0.0: index = 0
		if index < steps.size() and String(steps[index]) == token:
			index += 1
			state.remaining = float(recipe.get("window", 2.5))
		elif is_action:
			index = 1 if String(steps[0]) == token else 0
			state.remaining = float(recipe.get("window", 2.5)) if index > 0 else 0.0
		state.index = index
		states[id] = state
		if index >= steps.size(): completed.append(recipe)
	if not completed.is_empty():
		completed.sort_custom(func(a: Dictionary, b: Dictionary):
			var a_steps := Array(a.get("steps", [])).size(); var b_steps := Array(b.get("steps", [])).size()
			return a_steps > b_steps if a_steps != b_steps else int(a.get("priority", 0)) > int(b.get("priority", 0)))
		var winner: Dictionary = completed[0].duplicate(true)
		_reset_all()
		return {"triggered": winner, "progress": {}}
	return {"triggered": {}, "progress": _best_progress()}

func _best_progress() -> Dictionary:
	var best: Dictionary = {}
	for recipe in recipes:
		var state: Dictionary = states.get(String(recipe.get("id", "")), {})
		var index := int(state.get("index", 0))
		if index <= 0: continue
		if best.is_empty() or index > int(best.get("index", 0)) or index == int(best.get("index", 0)) and int(recipe.get("priority", 0)) > int(best.get("priority", 0)):
			var steps: Array = recipe.get("steps", [])
			best = {"id": String(recipe.get("id", "")), "name": String(recipe.get("name", "Combo")), "index": index, "total": steps.size(), "remaining": float(state.get("remaining", 0.0)), "next": String(Array(recipe.get("step_labels", []))[index]) if index < Array(recipe.get("step_labels", [])).size() else "", "priority": int(recipe.get("priority", 0))}
	return best

func _reset_all() -> void:
	for id in states: states[id] = {"index": 0, "remaining": 0.0}
