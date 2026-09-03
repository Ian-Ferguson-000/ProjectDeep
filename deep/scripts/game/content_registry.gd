extends RefCounted
class_name ContentRegistry

const MANIFEST_PATH := "res://data/manifest.json"

var _loaded := false
var _catalogs: Dictionary = {}
var _aliases: Dictionary = {}
var diagnostics: Array[String] = []

func load_catalog() -> bool:
	if _loaded:
		return diagnostics.is_empty()
	_loaded = true
	var manifest := _load_json(MANIFEST_PATH)
	if manifest.is_empty():
		diagnostics.append("Content manifest is missing or invalid.")
		return false
	_aliases = Dictionary(manifest.get("aliases", {})).duplicate(true)
	var catalog_paths: Dictionary = Dictionary(manifest.get("catalogs", {}))
	var domain_names: Array = catalog_paths.keys()
	domain_names.sort()
	for domain_value: Variant in domain_names:
		var domain := String(domain_value)
		var records: Dictionary = {}
		var paths: Array = catalog_paths.get(domain, [])
		for path_value: Variant in paths:
			var relative := String(path_value)
			var definition := _load_json("res://data/%s" % relative)
			var identifier := String(definition.get("id", ""))
			if identifier.is_empty() or records.has(identifier):
				diagnostics.append("Invalid or duplicate %s definition in %s." % [domain, relative])
				continue
			records[identifier] = definition
		_catalogs[domain] = records
	return diagnostics.is_empty()

func canonical_id(domain: String, identifier: String) -> String:
	load_catalog()
	return String(Dictionary(_aliases.get(domain, {})).get(identifier, identifier))

func get_definition(domain: String, identifier: String) -> Dictionary:
	load_catalog()
	identifier = canonical_id(domain, identifier)
	var value: Variant = Dictionary(_catalogs.get(domain, {})).get(identifier, {})
	return value.duplicate(true) if value is Dictionary else {}

func get_definitions(domain: String) -> Dictionary:
	load_catalog()
	return Dictionary(_catalogs.get(domain, {})).duplicate(true)

func get_legacy_catalog(domain: String) -> Dictionary:
	var result: Dictionary = {}
	for identifier: String in get_definitions(domain):
		var definition: Dictionary = get_definition(domain, identifier)
		var display: Dictionary = Dictionary(definition.get("display", {}))
		definition["name"] = String(display.get("name", identifier.capitalize()))
		for metadata_key: String in ["schema_version", "id", "display", "tags"]:
			definition.erase(metadata_key)
		if domain == "classes":
			var actions: Dictionary = {}
			for action_id: Variant in definition.get("default_action_ids", []):
				var action := get_definition("actions", String(action_id))
				var slot := String(action.get("slot", ""))
				if slot.is_empty():
					continue
				action["name"] = String(Dictionary(action.get("display", {})).get("name", String(action_id).capitalize()))
				for metadata_key: String in ["schema_version", "display", "tags", "class_id", "slot"]:
					action.erase(metadata_key)
				actions[slot] = action
			definition["actions"] = actions
		result[identifier] = definition
	return result

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
