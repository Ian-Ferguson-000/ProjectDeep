extends SceneTree

const EXPECTED_CLASSES := ["warrior", "mage", "healer", "tank", "phantom", "summoner"]
const EXPECTED_SLOTS := ["basic", "special", "defensive", "movement"]

func _initialize() -> void:
	var failures: Array[String] = []
	if GameBalance.normalize_class_id("fighter") != "warrior":
		failures.append("legacy fighter id did not normalize")
	var classes := GameBalance.get_base_classes()
	for schema_failure in GameBalance.validate_base_classes(): failures.append(schema_failure)
	for class_id in EXPECTED_CLASSES:
		if not classes.has(class_id):
			failures.append("missing class: %s" % class_id)
			continue
		var class_data: Dictionary = classes[class_id]
		var actions: Dictionary = class_data.get("actions", {})
		for slot in EXPECTED_SLOTS:
			if not actions.has(slot) or String(actions[slot].get("id", "")).is_empty():
				failures.append("%s missing %s action" % [class_id, slot])
		var resource := RunState.new()
		resource.set_class(class_id)
		resource.gain_class_resource(99)
		if resource.class_resource != 3:
			failures.append("%s resource cap failed" % class_id)
		if not resource.spend_class_resource(2) or resource.class_resource != 1:
			failures.append("%s resource spend failed" % class_id)
		if resource.get_class_resource_explanation().find(String(class_data.get("resource", ""))) == -1:
			failures.append("%s resource explanation missing" % class_id)
		var sprite_path := String(class_data.get("sprite", ""))
		if sprite_path.is_empty() or not FileAccess.file_exists(sprite_path):
			failures.append("%s sprite missing: %s" % [class_id, sprite_path])
	var mage := RunState.new(); mage.set_class("mage")
	var missile := mage.get_action_modifier_breakdown("basic", {})
	if int(missile.get("action_bonus", 0)) != 10: failures.append("Arcane Missile must grant exactly +10 Accuracy")
	var warrior := RunState.new(); warrior.set_class("warrior")
	if int(warrior.get_action_modifier_breakdown("basic", {"adjacent_enemies":1}).get("conditional_bonus", 0)) != 0: failures.append("Slash bonus applied outside surrounded context")
	if int(warrior.get_action_modifier_breakdown("basic", {"adjacent_enemies":2}).get("conditional_bonus", 0)) != 2: failures.append("Slash surrounded bonus missing")
	var healer := RunState.new(); healer.set_class("healer")
	if int(healer.get_action_modifier_breakdown("basic", {"target_slowed":true}).get("conditional_bonus", 0)) != 3: failures.append("Binding Light Slowed bonus missing")
	var tank := RunState.new(); tank.set_class("tank")
	if int(tank.get_action_modifier_breakdown("basic", {"target_threshold":2}).get("conditional_bonus", 0)) != 4: failures.append("Shield Bash Threshold bonus missing")
	var phantom := RunState.new(); phantom.set_class("phantom")
	if not phantom.get_action_modifier_breakdown("basic", {}).get("ignore", []).has("threshold"): failures.append("Pierce Threshold ignore missing")
	var summoner := RunState.new(); summoner.set_class("summoner")
	if int(summoner.get_action_modifier_breakdown("basic", {"coordinated_wolf_attack":true}).get("conditional_bonus", 0)) != 3: failures.append("wolf coordinated Accuracy missing")
	var legacy := RunState.new()
	legacy.hero_profiles = {"fighter":{"class_id":"fighter","level":1,"xp":0,"total_xp":0,"base_stats":{"str":19,"dex":12,"con":15,"int":8,"wis":10,"cha":10},"stats":{"str":19},"derived_stats":{}}}
	legacy._ensure_profiles()
	if legacy.hero_profiles.has("fighter") or not legacy.hero_profiles.has("warrior"): failures.append("legacy Fighter profile normalization failed")
	if int(legacy.hero_profiles["warrior"].get("base_stats", {}).get("str", 0)) != 19: failures.append("legacy profile lost stored attributes")
	if failures.is_empty():
		print("Six-class data validation passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
