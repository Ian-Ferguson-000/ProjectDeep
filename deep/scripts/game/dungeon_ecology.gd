extends RefCounted
class_name DungeonEcology

const DATA_PATH := "res://data/story/dungeon_ecology.json"
static var _data:Dictionary={}

static func data()->Dictionary:
	if _data.is_empty():
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH));_data=Dictionary(parsed) if parsed is Dictionary else {}
	return _data

static func ecology_id(dungeon_id:String)->String:
	return String(NarrativeContent.dungeon_lore(dungeon_id).get("ecology_id",dungeon_id))

static func ensure(campaign)->void:
	if campaign==null:return
	var defaults:=Dictionary(data().get("defaults",{}))
	for id in Dictionary(data().get("ecologies",{})):
		if campaign.dungeon_ecology.has(id):continue
		var config:=defaults.duplicate(true);config.merge(Dictionary(data().ecologies[id]),true)
		campaign.dungeon_ecology[id]={"pressure":float(config.get("pressure",60)),"resources":float(config.get("resources",70)),"stability":float(config.get("stability",45)),"last_day":campaign.calendar_day,"suppression_count":0,"outbreak":false}

static func state(campaign,dungeon_id:String)->Dictionary:
	ensure(campaign);return Dictionary(campaign.dungeon_ecology.get(ecology_id(dungeon_id),{})).duplicate(true)

static func advance_to_day(campaign,target_day:int)->Array[String]:
	ensure(campaign);var events:Array[String]=[];var defaults:=Dictionary(data().get("defaults",{}))
	for id in campaign.dungeon_ecology:
		var current:=Dictionary(campaign.dungeon_ecology[id]);var days:=maxi(0,target_day-int(current.get("last_day",target_day)))
		if days==0:continue
		var config:=defaults.duplicate(true);config.merge(Dictionary(data().get("ecologies",{}).get(id,{})),true)
		current.pressure=clampf(float(current.pressure)+days*float(config.get("pressure_per_day",1.25)),0,100)
		current.resources=clampf(float(current.resources)+days*float(config.get("resources_per_day",0.65)),0,100)
		current.stability=clampf(float(current.stability)+days*float(config.get("stability_per_day",-0.45)),0,100);current.last_day=target_day
		var was_outbreak:=bool(current.get("outbreak",false));current.outbreak=float(current.pressure)>=100.0 or float(current.stability)<=0.0
		campaign.dungeon_ecology[id]=current
		if bool(current.outbreak) and not was_outbreak:events.append("%s has breached containment."%String(config.get("name",String(id).capitalize())))
	return events

static func record_progress(campaign,dungeon_id:String)->Array[String]:
	return record_resolution(campaign,dungeon_id,"suppress")

static func record_resolution(campaign,dungeon_id:String,resolution:String)->Array[String]:
	ensure(campaign);var id:=ecology_id(dungeon_id);var current:=Dictionary(campaign.dungeon_ecology.get(id,{}));var lore:=NarrativeContent.dungeon_lore(dungeon_id);var stage:=String(lore.get("stage",""));var routed:=not String(lore.get("route_id","")).is_empty()
	var terminal:=stage in ["prison","keystone"] or not routed
	match resolution:
		"rebind":
			current.pressure=maxf(8.0,float(current.pressure)-(45.0 if terminal else 18.0));current.resources=maxf(0.0,float(current.resources)-5.0);current.stability=minf(100.0,float(current.stability)+(45.0 if terminal else 18.0));current.outbreak=false
			if terminal:current.suppression_count=int(current.get("suppression_count",0))+1;current["resolution"]="rebound"
		"evidence":
			current.pressure=maxf(0.0,float(current.pressure)-8.0);current.resources=maxf(0.0,float(current.resources)-15.0);current.stability=minf(100.0,float(current.stability)+3.0);current["resolution"]="evidence_recovered"
		"negotiate":
			current.pressure=20.0 if terminal else maxf(20.0,float(current.pressure)-12.0);current.resources=maxf(0.0,float(current.resources)-4.0);current.stability=90.0 if terminal else minf(100.0,float(current.stability)+15.0);current.outbreak=false;current["resolution"]="new_covenant"
		_:
			if terminal:current.pressure=15.0;current.resources=35.0;current.stability=85.0;current.suppression_count=int(current.get("suppression_count",0))+1;current.outbreak=false
			else:current.pressure=maxf(0.0,float(current.pressure)-(10.0 if stage in ["approach","leak_zone"] else 20.0));current.resources=maxf(0.0,float(current.resources)-8.0);current.stability=minf(100.0,float(current.stability)+8.0)
			current["resolution"]="suppressed" if terminal else "advanced"
	current.last_day=campaign.calendar_day;campaign.dungeon_ecology[id]=current
	return ["%s pressure now %d%%; resources %d%%; stability %d%%. Resolution: %s."%[String(Dictionary(data().ecologies.get(id,{})).get("name",id.capitalize())),roundi(current.pressure),roundi(current.resources),roundi(current.stability),String(current.get("resolution",resolution)).replace("_"," ")]]

static func threat_multiplier(campaign,dungeon_id:String)->float:return lerpf(0.85,1.25,float(state(campaign,dungeon_id).get("pressure",60))/100.0)
static func reward_multiplier(campaign,dungeon_id:String)->float:return lerpf(0.65,1.35,float(state(campaign,dungeon_id).get("resources",70))/100.0)
