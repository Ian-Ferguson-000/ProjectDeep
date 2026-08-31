class_name StarterRunes
extends RefCounted

const FORMS:= ["particle","beam","scatter","aura","rocket","wave","zone","trap","weapon","summoned","environmental","remote"]
const ELEMENTS:= ["fire","burn","lightning","magnetism","aether","void","force","wave","growth","earth","light","wind"]
const NAMES:= [
	["Fireball","Flamethrower","Flame Shower","Flame Charge","Explosion","Heatwave","Drought","Flaming Snare","Fire Sword","Fire Spirit","Magma Storm","Kindle"],
	["Cinder Bolt","Searing Ray","Cinder Spray","Searing Aura","Combustion","Scorchwave","Scorched Earth","Searing Trap","Searing Blade","Cinder Spirit","Inferno","Ignite"],
	["Ball Lightning","Lightning Bolt","Arc Scatter","Static Field","Thunderburst","Arc Wave","Storm Field","Static Trap","Lightning Spear","Storm Spirit","Thunderstorm","Electrocute"],
	["Lodestone Orb","Polarity Ray","Shrapnel Burst","Magnetic Field","Repulsion Burst","Polarity Wave","Magnetic Zone","Magnetic Snare","Lodestone Blade","Magnetic Construct","Metal Storm","Attract"],
	["Aether Blast","Aether Ray","Aether Shards","Aether Aura","Aether Burst","Aether Wave","Aether Field","Aether Snare","Aether Blade","Aether Wisp","Aether Storm","Displace"],
	["Void Bolt","Void Lance","Void Shards","Void Aura","Implosion","Null Wave","Null Zone","Void Snare","Void Blade","Voidling","Spatial Collapse","Banish"],
	["Force Bolt","Force Ray","Force Barrage","Force Aura","Force Burst","Force Wave","Force Field","Force Snare","Force Blade","Force Construct","Gravity Storm","Push"],
	["Sonic Orb","Resonance Beam","Sonic Scatter","Resonance Aura","Sonic Boom","Shockwave","Resonance Field","Resonance Trap","Resonant Blade","Echo Spirit","Resonance Storm","Vibrate"],
	["Seed Shot","Growth Ray","Thorn Volley","Regrowth Aura","Bloom","Overgrowth","Verdant Field","Vine Snare","Thorn Blade","Verdant Spirit","Wild Growth","Sprout"],
	["Stone Shot","Stone Lance","Rock Barrage","Stone Skin","Stone Eruption","Tremor","Quagmire","Earthen Snare","Stone Hammer","Golem","Earthquake","Petrify"],
	["Radiant Orb","Light Ray","Star Shower","Halo","Flash","Radiant Wave","Daylight","Flare Trap","Light Blade","Luminous Spirit","False Dawn","Illuminate"],
	["Air Bullet","Wind Lance","Razor Winds","Wind Cloak","Airburst","Gale","Cyclone","Wind Snare","Wind Blade","Air Spirit","Hurricane","Gust"]]
const MATERIALS:= ["sun_shard","ember_ash","storm_glass","lodestone_fragment","moon_moss","void_residue","kinetic_core","echo_shell","verdant_seed","stone_heart","dawn_prism","gale_feather"]
const SIGNATURES:= {"fire":["fire","burn",2,90.0],"burn":["burn","scorch",3,35.0],"lightning":["lightning","shock",2,55.0],"magnetism":["magnetism","attract",2,-150.0],"aether":["aether","phase_burn",2,110.0],"void":["void","silence",2,130.0],"force":["force","repel",2,210.0],"wave":["sonic","stagger",2,100.0],"growth":["growth","root",2,45.0],"earth":["earth","slow",2,80.0],"light":["light","illuminate",2,60.0],"wind":["wind","push",2,180.0]}
const FORM_DEFAULTS:= [[18,8,12.0,1.0,0.0,0.25,1,0.0,1],[7,0,9.0,0.8,0.0,0.18,1,0.0,1],[7,11,9.0,2.0,0.0,0.25,5,42.0,1],[6,12,4.0,4.0,8.0,1.0,1,0.0,1],[25,14,7.0,4.0,0.0,0.25,1,0.0,1],[15,11,10.0,3.0,1.0,0.25,1,80.0,1],[6,18,10.0,8.0,8.0,1.0,1,0.0,2],[14,10,8.0,4.0,15.0,0.25,1,0.0,3],[8,12,2.2,1.0,10.0,0.25,1,0.0,1],[7,16,9.0,6.0,15.0,1.2,1,0.0,1],[10,25,14.0,12.0,8.0,0.8,1,0.0,1],[6,7,10.0,2.0,0.0,0.25,1,0.0,1]]

## Builds the tutorial rune followed by the complete twelve-element by twelve-form matrix.
static func all() -> Array:
	var result:Array=[_cleansing_rune()]; var paths:=_generated_paths(144)
	for element_index in ELEMENTS.size():
		for form_index in FORMS.size():result.append(_build_rune(element_index,form_index,paths[element_index*12+form_index]))
	return result

## Builds one complete spell record by combining its element signature, form defaults, exact name, and recipe tier.
static func _build_rune(element_index:int,form_index:int,path:Array) -> Dictionary:
	var element:String=ELEMENTS[element_index]; var form:String=FORMS[form_index]; var name:String=NAMES[element_index][form_index]
	var defaults:Array=FORM_DEFAULTS[form_index]; var signature:Array=SIGNATURES[element]; var tier:int=1+form_index/4
	var catalyst:String=["rune_dust","arcane_binding","primal_core"][tier-1]; var id:=_slug(name)
	var record:={"id":id,"name":name,"display_name":name,"element":element,"form":form,"primary_mana":element,"secondary_mana":"neutral","invocation":element.left(3).capitalize(),"damage_type":signature[0],"power":defaults[0],"mana_cost":defaults[1],"mana_per_second":3.0 if form=="beam" else 0.0,"range":defaults[2],"cooldown":defaults[3],"targeting":form,"status_effect":signature[1],"status_power":signature[2],"knockback":signature[3],"duration":defaults[4],"tick_interval":defaults[5],"projectile_count":defaults[6],"spread_angle":defaults[7],"ownership_cap":defaults[8],"radius":96.0 if form in ["aura","rocket","zone","trap"] else 64.0,"tags":[element,form],"path":path,"costs":{MATERIALS[element_index]:tier,catalyst:1},"spell_id":id,"vfx_id":id,"description":"%s shapes %s mana into a %s spell that applies %s."%[name,element,form,signature[1].replace("_"," ")]}
	if id=="flamethrower":record.range=5.0;record.mana_per_second=8.0;record.tick_interval=0.18;record.spread_angle=52.0
	if id=="flame_shower":record.projectile_count=7;record.spread_angle=56.0
	if id=="stone_skin":record.status_effect="fortify"
	if id=="regrowth_aura":record.status_effect="regeneration"
	if id=="wind_cloak":record.status_effect="haste"
	if id=="banish":record.knockback=420.0
	if form=="environmental":record.radius=224.0;record.range=18.0
	elif form=="zone":record.radius=144.0;record.range=14.0
	elif form=="trap":record.radius=72.0
	elif form=="rocket":record.radius=112.0
	return record

## Converts a display name to its stable lowercase underscore identifier.
static func _slug(value:String) -> String:return value.to_lower().replace(" ","_").replace("-","_")

## Generates deterministic unique non-self-intersecting direction paths from valid walks on the 7×7 lattice.
static func _generated_paths(count:int) -> Array:
	var result:Array=[];var seen:Dictionary={}
	for start in [Vector2i(3,3),Vector2i(2,3),Vector2i(3,2)]:
		_collect_paths(start,[start],[],result,seen,count)
		if result.size()>=count:break
	return result

## Depth-first enumerates simple six-step lattice walks and records each normalized direction sequence once.
static func _collect_paths(point:Vector2i,visited:Array,directions:Array,result:Array,seen:Dictionary,limit:int) -> void:
	if result.size()>=limit:return
	if directions.size()==6:
		var key:=canonical_path_key(directions)
		if not seen.has(key):seen[key]=true;result.append(directions.duplicate())
		return
	for direction in 6:
		var next:=_step(point,direction)
		if next.x<0 or next.y<0 or next.x>=7 or next.y>=7 or next in visited:continue
		visited.append(next);directions.append(direction);_collect_paths(next,visited,directions,result,seen,limit);directions.pop_back();visited.pop_back()

## Applies one normalized direction to a staggered-row lattice coordinate.
static func _step(point:Vector2i,direction:int) -> Vector2i:
	var even:=[Vector2i.RIGHT,Vector2i(0,-1),Vector2i(-1,-1),Vector2i.LEFT,Vector2i(-1,1),Vector2i(0,1)];var odd:=[Vector2i.RIGHT,Vector2i(1,-1),Vector2i(0,-1),Vector2i.LEFT,Vector2i(0,1),Vector2i(1,1)]
	return point+(odd[direction] if point.y&1 else even[direction])

## Returns the opposite-direction sequence used to traverse an authored undirected rune from its other endpoint.
static func reverse_path(path:Array) -> Array:
	var result:Array=[]
	for index in range(path.size()-1,-1,-1):result.append((int(path[index])+3)%6)
	return result

## Returns one stable identity shared by a forward path and its endpoint-reversed equivalent.
static func canonical_path_key(path:Array) -> String:
	var forward:=str(path);var reversed:=str(reverse_path(path));return forward if forward<reversed else reversed

## Returns the special Spirit tutorial rune outside the elemental matrix.
static func _cleansing_rune() -> Dictionary:
	return {"id":"cleansing_spark","name":"Cleansing Spark","display_name":"Cleansing Spark","element":"spirit","form":"particle","primary_mana":"white","secondary_mana":"green","invocation":"Sana","damage_type":"spirit","power":3,"mana_cost":4,"mana_per_second":0.0,"range":12.0,"cooldown":0.55,"targeting":"particle","status_effect":"cleanse","status_power":3,"knockback":90.0,"duration":0.0,"tick_interval":0.25,"projectile_count":1,"spread_angle":0.0,"ownership_cap":1,"radius":48.0,"tags":["spirit","particle"],"path":[0,1,2,3],"costs":{"sun_shard":1,"moon_moss":1},"spell_id":"cleanse_bolt","vfx_id":"cleansing_spark","description":"A bright spiral that unravels corruption."}

## Finds a rune by stable ID and returns a defensive deep copy.
static func get_rune(id:String) -> Dictionary:
	for rune in all():
		if rune.id==id:return rune.duplicate(true)
	return {}

## Returns all generated runes in one elemental family.
static func by_element(element:String) -> Array:return all().filter(func(rune):return rune.element==element)
