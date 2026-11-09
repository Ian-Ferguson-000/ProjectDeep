class_name EnemyJournal
extends RefCounted

const DEFINITIONS_ROOT:="res://Data/enemies"
const SPECIAL_ENTRY_PATH:="res://Data/journal/corrupted_heart.tres"
static var cached_definitions:Array[EnemyDefinition]=[]

## Loads and returns every authored journal entry in stable display order.
static func all() -> Array[EnemyJournalEntry]:
	var result: Array[EnemyJournalEntry]=[]
	for definition in all_definitions():
		if definition.journal_entry:result.append(definition.journal_entry)
	var special:EnemyJournalEntry=load(SPECIAL_ENTRY_PATH)
	if special:result.append(special)
	return result

## Discovers and caches every enemy definition beneath the standardized data root in stable ID order.
static func all_definitions() -> Array[EnemyDefinition]:
	if not cached_definitions.is_empty():return cached_definitions
	var paths:Array[String]=[]; _collect_definition_paths(DEFINITIONS_ROOT,paths); paths.sort()
	for path in paths:
		var definition:EnemyDefinition=load(path)
		if definition:cached_definitions.append(definition)
	return cached_definitions

## Recursively collects definition.tres paths so adding an enemy folder requires no registry edit.
static func _collect_definition_paths(root:String,result:Array[String]) -> void:
	var directory:=DirAccess.open(root)
	if not directory:return
	for filename in directory.get_files():
		if filename=="definition.tres":result.append(root+"/"+filename)
	for folder in directory.get_directories():_collect_definition_paths(root+"/"+folder,result)

## Finds a journal entry by stable enemy ID and returns null when no entry is registered.
static func get_entry(enemy_id: String) -> EnemyJournalEntry:
	for entry in all():
		if entry.enemy_id==enemy_id: return entry
	return null
