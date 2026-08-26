extends SceneTree

const EXPECTED_CLASSES := ["warrior", "mage", "healer", "tank", "phantom", "summoner"]
const EXPECTED_SLOTS := ["basic", "special", "defensive", "movement"]

func _initialize() -> void:
	var failures: Array[String] = []
	if GameBalance.normalize_class_id("fighter") != "warrior":
		failures.append("legacy fighter id did not normalize")
	var classes := GameBalance.get_base_classes()
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
		var sprite_path := String(class_data.get("sprite", ""))
		if sprite_path.is_empty() or not FileAccess.file_exists(sprite_path):
			failures.append("%s sprite missing: %s" % [class_id, sprite_path])
	if failures.is_empty():
		print("Six-class data validation passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
