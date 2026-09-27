from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def edit(path,fn):
 p=ROOT/path; s=p.read_text(encoding='utf-8'); p.write_text(fn(s),encoding='utf-8')
def character(s):
 s=s.replace('var personal_history:Array[Dictionary]=[]','''var personal_history:Array[Dictionary]=[]
var equipment: Dictionary = {}
var provisions: Array[String] = []
var birth_day: int = -2687
var recovery_until: int = 0
var signing_fee: int = 0

func age_on(day: int) -> int:
	return maxi(18, int((day-birth_day)/112))''')
 s=s.replace('"id":id, "display_name"','"equipment":equipment.duplicate(true),"provisions":provisions.duplicate(),"birth_day":birth_day,"recovery_until":recovery_until,"signing_fee":signing_fee,\n\t\t"id":id, "display_name"')
 s=s.replace('record.id = String(data.get("id", ""));','''record.equipment = Dictionary(data.get("equipment",{})).duplicate(true)
	record.provisions.assign(data.get("provisions",[]))
	record.birth_day = int(data.get("birth_day",-2687))
	record.recovery_until = int(data.get("recovery_until",0))
	record.signing_fee = int(data.get("signing_fee",0))
	record.id = String(data.get("id", ""));''')
 return s
def expedition(s):
 fields={'deployment_type':'"manual"','departure_day':'1','due_day':'8','retreat_policy':'"balanced"','simulation_seed':'0','risk_ratio':'1.0','locked_loadouts':'{}','secured_gold':'0','secured_essence':'0'}
 s=s.replace('var rewarded_checkpoints: Dictionary = {}','var rewarded_checkpoints: Dictionary = {}\n'+ '\n'.join(f'var {k} = {v}' for k,v in fields.items()))
 s=s.replace('return {"active":active','return {'+','.join(f'"{k}":{k}' for k in fields)+',"active":active')
 s=s.replace('var state := ExpeditionState.new();','var state := ExpeditionState.new();\n'+''.join(f'\tstate.{k} = data.get("{k}",{v})\n' for k,v in fields.items())+'\t')
 return s
def campaign(s):
 s=s.replace('const SAVE_VERSION := 7','const SAVE_VERSION := 8')
 fields={'armory':'{}','next_item_id':'1','establishment_tier':'0','construction':'{}','dispatches':'{}','settled_expeditions':'{}','return_reports':'[]','market_stock':'{}','consumable_stock':'{}'}
 s=s.replace('var reputation:=0','\n'.join(f'var {k} = {v}' for k,v in fields.items())+'\nvar reputation:=0')
 s=s.replace('"roster_services":0,','"recovery":0,"roster_services":0,')
 s=s.replace('return BASE_ROSTER_CAPACITY + 2 * maxi(0, int(tavern_upgrades.get("roster_services", 0)))','return int(HearthCatalog.tier(establishment_tier).capacity)')
 s=s.replace('var member:=candidate.adventurer;member.status', '''var fee := candidate.adventurer.signing_fee
	if not candidate.first_company and living_roster().size() < 2 and banked_gold < fee: fee = 0
	if banked_gold < fee: return {"ok":false,"error":"Signing this recruit costs %d gold." % fee}
	banked_gold -= fee
	var member:=candidate.adventurer;member.status''')
 s=s.replace('first_company_recruited=first_company_ids.all','HearthArmory.ensure_starter(self,member)\n\tfirst_company_recruited=first_company_ids.all')
 s=s.replace('roster.erase(character_id);_add_calendar_event','HearthArmory.release(self,member)\n\tfor id in member.provisions: consumable_stock[id] = int(consumable_stock.get(id,0))+1\n\troster.erase(character_id);_add_calendar_event')
 s=s.replace('var quality_rank:=int(tavern_upgrades.get("replacement_quality",0));character.level=mini(20,1+quality_rank);character.progression["level"]=character.level', '''var band: Array = HearthCatalog.tier(establishment_tier).recruit_levels
	character.level = mini(20,identity_rng.randi_range(int(band[0]),int(band[1]))+int(tavern_upgrades.replacement_quality))
	character.progression["level"] = character.level
	character.birth_day = calendar_day - identity_rng.randi_range(20,55)*112
	character.signing_fee = 8 + character.level*character.level*3''')
 s=s.replace('member.status = CharacterRecord.STATUS_DEAD; expedition.record_casualty(character_id)','member.status = CharacterRecord.STATUS_DEAD; expedition.record_casualty(character_id)\n\tHearthArmory.release(self,member,true)')
 s=s.replace('if ids.is_empty() or ids.size() > get_party_cap(dungeon_id): return false','''if not is_tutorial:
		for id in ids:
			var recruit := character(id)
			if recruit != null: HearthArmory.ensure_starter(self,recruit)
		var check := HearthExpeditions.readiness(self,ids,dungeon_id)
		if not check.ok: return false
		supplies -= int(check.supplies)
	if ids.is_empty() or ids.size() > get_party_cap(dungeon_id): return false''')
 s=s.replace('expedition.begin(ids,dungeon_id,mode,is_tutorial,run_id);return true','''expedition.begin(ids,dungeon_id,mode,is_tutorial,run_id)
	expedition.departure_day = calendar_day
	expedition.due_day = calendar_day+7
	for id in ids: expedition.locked_loadouts[id] = character(id).equipment.duplicate(true)
	return true''')
 s=s.replace('func settle_expedition(run_id:int,outcome:String,result_data:Dictionary={}) -> Dictionary:\n','''func settle_expedition(run_id:int,outcome:String,result_data:Dictionary={}) -> Dictionary:
	if settled_expeditions.has(str(run_id)): return {"ok":true,"duplicate":true,"logs":[]}
	if not expedition.tutorial_run:
		if expedition.expedition_id != run_id: return {"ok":false,"error":"Expedition ID does not match.","logs":[]}
		return HearthExpeditions.settle(self,expedition,outcome,result_data)
''')
 start=s.index('func upgrade_cost('); end=s.index('func to_dict()',start)
 s=s[:start]+'''func upgrade_cost(branch: String) -> Dictionary:
	return HearthFacilities.quote(self,branch)

func purchase_upgrade(branch: String) -> Array[String]:
	var result := HearthFacilities.purchase(self,branch)
	return [String(result.get("message",result.get("error","")))]

'''+s[end:]
 s=s.replace('return {"version":SAVE_VERSION','return {'+','.join(f'"{k}":{k}' for k in fields)+',"version":SAVE_VERSION')
 s=s.replace('func _load_dict(data: Dictionary) -> void:\n','func _load_dict(data: Dictionary) -> void:\n'+''.join(f'\t{k} = data.get("{k}",{v})\n' for k,v in fields.items()))
 s=s.replace('if bool(data.get("_convert_first_company_candidates",false)):_convert_legacy_first_company()','''if bool(data.get("_convert_first_company_candidates",false)):_convert_legacy_first_company()
	if not data.has("establishment_tier"): establishment_tier = clampi(int(tavern_upgrades.roster_services),0,3)
	for key in tavern_upgrades: tavern_upgrades[key] = clampi(int(tavern_upgrades[key]),0,3)
	for member in living_roster(): HearthArmory.ensure_starter(self,member)
	if expedition.active and not data.has("dispatches"):
		expedition.departure_day = calendar_day
		expedition.due_day = calendar_day+7''')
 return s
# Character migration already applied
edit('scripts/game/expedition_state.gd',expedition)
edit('scripts/game/campaign_state.gd',campaign)

