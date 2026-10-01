extends RefCounted
class_name DungeonObjectiveService

const DATA_PATH:="res://data/story/dungeon_objectives.json"
const ECOLOGY:=preload("res://scripts/game/dungeon_ecology.gd")
static var _data:Dictionary={}

static func data()->Dictionary:
	if _data.is_empty():
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH));_data=Dictionary(parsed) if parsed is Dictionary else {}
	return _data
static func objective(objective_id:String)->Dictionary:return Dictionary(Dictionary(data().get("objectives",{})).get(objective_id,{})).duplicate(true)
static func objective_ids(dungeon_id:String)->Array[String]:
	var ids:Array[String]=[]
	for value in Array(Dictionary(Dictionary(data().get("dungeons",{})).get(dungeon_id,{})).get("objective_ids",[])):ids.append(String(value))
	return ids
static func default_objective(dungeon_id:String)->String:
	var ids:=objective_ids(dungeon_id);return ids[0] if not ids.is_empty() else "suppress"

static func resolve(campaign,expedition,dungeon_id:String)->Array[String]:
	var selected:=String(expedition.objective_id)
	if selected.is_empty() or not objective_ids(dungeon_id).has(selected):selected=default_objective(dungeon_id)
	var definition:=objective(selected);var resolution:=String(definition.get("resolution","suppress"));var logs:=ECOLOGY.record_resolution(campaign,dungeon_id,resolution)
	for nation_id in NarrativeContent.nations():
		var doctrine_id:=String(NarrativeContent.nation(String(nation_id)).get("default_doctrine",""))
		if Array(definition.get("doctrine_ids",[])).has(doctrine_id):campaign.faction_standing[nation_id]=int(campaign.faction_standing.get(nation_id,0))+2
	if resolution=="evidence":
		var evidence_id:="evidence_%s"%dungeon_id;campaign.clues[evidence_id]=true
		var discoveries:Array=Array(campaign.keeper_memory.get("discoveries",[]))
		if not discoveries.has(evidence_id):discoveries.append(evidence_id);campaign.keeper_memory["discoveries"]=discoveries
	if resolution=="negotiate":campaign.faction_standing["nordia"]=int(campaign.faction_standing.get("nordia",0))-1
	logs.append("Objective fulfilled: %s. Aligned traditions recognize the Hearth's choice."%String(definition.get("name",selected)))
	return logs

static func validate()->Array[String]:
	var errors:Array[String]=[];var objectives:=Dictionary(data().get("objectives",{}))
	for objective_id in objectives:
		if String(Dictionary(objectives[objective_id]).get("name","")).is_empty():errors.append("Objective %s has no name."%objective_id)
	for dungeon_id in GameBalance.get_dungeon_order():
		var ids:=objective_ids(String(dungeon_id))
		if ids.is_empty():errors.append("Dungeon %s has no objectives."%dungeon_id)
		for objective_id in ids:
			if not objectives.has(objective_id):errors.append("Dungeon %s references missing objective %s."%[dungeon_id,objective_id])
	return errors
