extends Node
class_name SlasherItemRuntime

signal effect_activated(text:String)

var run_state:RunState
var owner_player:SlasherPlayer
var conversions:Dictionary={}
var records:Array[Dictionary]=[]
var cooldowns:Dictionary={}
var floor_uses:Dictionary={}
var precision_count:=0

func setup(state:RunState,actor:SlasherPlayer)->void:run_state=state;owner_player=actor;refresh()

func refresh()->void:
	conversions.clear();records.clear()
	for entry:Dictionary in run_state.get_inventory_items():
		var item_id:String=String(entry.get("id",""));var record:Dictionary=GameBalance.get_slasher_item_effects(item_id);record["item_id"]=item_id;records.append(record)
		for key:Variant in Dictionary(record.get("conversions",{})):
			var value:float=float(Dictionary(record.get("conversions",{}))[key]);var key_string:String=String(key)
			if key_string.ends_with("_multiplier"):conversions[key_string]=float(conversions.get(key_string,1.0))*value
			else:conversions[key_string]=float(conversions.get(key_string,0.0))+value

func floor_entered()->void:
	floor_uses.clear();precision_count=0
	for record:Dictionary in records:
		if String(record.get("trigger",""))=="floor_entry" and int(record.get("heal",0))>0:owner_player.heal(int(record.heal));effect_activated.emit(GameBalance.get_item(String(record.item_id)).get("name","Relic")+" restores health.")

func handle_event(event:Dictionary)->Dictionary:
	var result:Dictionary={"trigger":String(event.get("trigger","")),"damage_multiplier":1.0,"healing":0,"cooldown_reduction":0.0,"resource_change":0,"activations":[]}
	for record:Dictionary in records:
		if String(record.get("trigger","passive"))!=String(result.trigger):continue
		var item_id:String=String(record.get("item_id",""));var internal:float=float(record.get("internal_cooldown",0.0))
		if float(cooldowns.get(item_id,0.0))>0.0 or bool(record.get("once_per_floor",false)) and floor_uses.has(item_id):continue
		if internal>0.0:cooldowns[item_id]=internal
		if bool(record.get("once_per_floor",false)):floor_uses[item_id]=true
		result.damage_multiplier*=float(record.get("damage_multiplier",1.0));result.healing+=int(record.get("heal",0));result.cooldown_reduction+=float(record.get("cooldown_flat",0.0));result.resource_change+=int(record.get("resource_change",0));result.activations.append(item_id)
		if not String(record.get("rules","")).is_empty():effect_activated.emit(String(GameBalance.get_item(item_id).get("name",item_id))+" activates.")
	return result

func _process(delta:float)->void:
	for key:Variant in cooldowns:cooldowns[key]=maxf(0.0,float(cooldowns[key])-delta)

func conversion(key:String,fallback:float=0.0)->float:return float(conversions.get(key,fallback))
func cooldown_multiplier()->float:return clampf(1.0-conversion("cooldown_reduction"),0.55,1.0)

func transform_attack(attack:Dictionary,slot:String)->Dictionary:
	var result:Dictionary=attack.duplicate(true);var cadence:int=0
	if conversions.has("precision_hits"):cadence=maxi(2,int(conversion("precision_hits")))
	for record:Dictionary in records:
		if record.has("precision_hits"):cadence=int(record.precision_hits) if cadence==0 else mini(cadence,int(record.precision_hits))
	if cadence>0:precision_count+=1
	if cadence>0 and precision_count>=cadence:
		precision_count=0;result["damage"]=maxi(1,int(round(float(result.get("damage",1))*1.25)));result["precision_hit"]=true;effect_activated.emit("Precision impact!")
	for record:Dictionary in records:
		if slot=="special" and record.has("special_damage_multiplier"):result["damage"]=maxi(1,int(round(float(result.damage)*float(record.special_damage_multiplier))))
		if record.has("area_radius_bonus"):result["area_radius"]=float(result.get("area_radius",0.0))+float(record.area_radius_bonus)
	return result

func mitigate_damage(amount:int)->Dictionary:
	var reduction:float=clampf(conversion("damage_reduction"),0.0,0.65);var prevented:int=int(round(amount*reduction))+int(conversion("flat_prevention"));return {"damage":maxi(0,amount-prevented),"prevented":mini(amount,prevented)}

func try_prevent_lethal(final_damage:int,current_health:int)->bool:
	if final_damage<current_health:return false
	for record:Dictionary in records:
		var item_id:String=String(record.get("item_id",""))
		if String(record.get("trigger",""))=="lethal_damage" and not floor_uses.has(item_id):floor_uses[item_id]=true;effect_activated.emit("%s prevents a lethal blow."%String(GameBalance.get_item(item_id).get("name",item_id)));return true
	return false
