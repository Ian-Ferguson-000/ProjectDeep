extends RefCounted
class_name AdventurerContent

const PATH:="res://data/adventurers.json"
static var cache:Dictionary={}

static func data()->Dictionary:
	if cache.is_empty():
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH));cache=Dictionary(parsed) if parsed is Dictionary else {}
	return cache
static func pool(key:String)->Array:return Array(data().get(key,[]))
static func nation_for_definition(id:String)->String:return String(Dictionary(data().get("nation_by_definition",{})).get(id,"crossroads"))
static func faith_for_definition(id:String)->String:return String(Dictionary(data().get("faith_by_definition",{})).get(id,"unaffiliated"))
static func doctrine_for_definition(id:String,nation_id:String)->String:return String(Dictionary(data().get("doctrine_by_definition",{})).get(id,NarrativeContent.nation(nation_id).get("default_doctrine","unaligned")))
static func curated()->Array:return pool("curated")
static func definition(id:String)->Dictionary:
	for value in curated():if value is Dictionary and String(value.get("id",""))==id:return Dictionary(value)
	return {}
static func trait_definition(id:String)->Dictionary:
	for value in pool("traits"):if value is Dictionary and String(value.get("id",""))==id:return Dictionary(value)
	return {}
static func validate()->Array[String]:
	var errors:Array[String]=[];var ids:Dictionary={};var coverage:Dictionary={}
	for value in curated():
		if not value is Dictionary:errors.append("Curated adventurer entry is not an object.");continue
		var entry:Dictionary=value;var id:=String(entry.get("id",""));var class_id:=String(entry.get("class",""))
		if id.is_empty() or ids.has(id):errors.append("Missing or duplicate curated ID: %s"%id)
		ids[id]=true;coverage[class_id]=int(coverage.get(class_id,0))+1
		for key in ["name","family","pronouns","origin","age","occupation","personality","preference","motivation","biography","trait"]:
			if String(entry.get(key,"")).is_empty():errors.append("%s is missing %s."%[id,key])
		if GameBalance.get_base_class(class_id).is_empty():errors.append("%s references unknown class %s."%[id,class_id])
		var nation_id:=String(entry.get("nation_id",nation_for_definition(id)))
		if not NarrativeContent.nations().has(nation_id):errors.append("%s references unknown nation %s."%[id,nation_id])
		if int(entry.get("portrait",-1)) not in range(4):errors.append("%s has an invalid portrait."%id)
	for class_id in ["warrior","mage","healer","tank","rogue","summoner"]:if int(coverage.get(class_id,0))<4:errors.append("%s needs four curated adventurers."%class_id)
	var known_deities:=DivineFavorService.deities();var known_doctrines:=PartyCompatibility.doctrines()
	for definition_id in Dictionary(data().get("faith_by_definition",{})):
		if not known_deities.has(String(data().faith_by_definition[definition_id])):errors.append("%s references an unknown faith."%definition_id)
	for definition_id in Dictionary(data().get("doctrine_by_definition",{})):
		if not known_doctrines.has(String(data().doctrine_by_definition[definition_id])):errors.append("%s references an unknown doctrine."%definition_id)
	return errors
