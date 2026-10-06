extends RefCounted
const KIT := preload("res://scripts/slasher/slasher_warrior_kit.gd")
const DATA := {
"headsmans_greatsword":{"name":"Headsman's Greatsword","actions":{"basic":"Hew","special":"Sentence","defensive":"Shoulder the Blow","movement":"Committed Step"},"description":"Broad Hew lands after a short windup. Sentence cleaves a telegraphed lane. Shoulder a frontal blow for an instant Hew; step forward with protection."},
"borderkeepers_spear":{"name":"Borderkeeper's Spear","actions":{"basic":"Measured Thrust","special":"Hold the Pass","defensive":"Yielding Guard","movement":"Flank March"},"description":"Thrust at the highlighted tip for bonus damage and Stamina. Plant a single-use lane; guard with a backstep and flank sideways."},
"banner_of_the_vanguard":{"name":"Banner of the Vanguard","actions":{"basic":"Rally Cut","special":"Plant the Standard","defensive":"Stand Together","movement":"Advance the Colors"},"description":"Plant a damaging rally banner, granting 15% nearby ally movement speed. Cuts extend its life within a finite budget. Share barriers with one deployed ally and carry the banner when advancing."},
"duelists_paired_sabres":{"name":"Duelist's Paired Sabres","actions":{"basic":"Answering Cuts","special":"Crossing Blades","defensive":"Bind Steel","movement":"Passing Step"},"description":"Alternate rapid cuts on the same enemy to earn Stamina. Cross two aimed arcs, bind a frontal melee attack for an exposed target, and sidestep without losing your pair."},
"chain_of_the_siege_breaker":{"name":"Chain of the Siege-Breaker","actions":{"basic":"Cast the Weight","special":"Draw and Break","defensive":"Chain Guard","movement":"Reel Through"},"description":"Strike and tether the first enemy in a long line. Pull ordinary foes into a slam; bosses take full impact without movement. Intercept three frontal shots or reel toward your tether."}}
static func all_gear() -> Array[GearData]:
	var result: Array[GearData]=[]
	for id in DATA:result.append(GearData.create(id,DATA[id].name,3,false,0,DATA[id].actions.special,DATA[id].description,"warrior",DATA[id].actions.defensive))
	return result
static func has_kit(id: String) -> bool:return DATA.has(id)
static func description(id: String) -> String:return String(DATA.get(id,{}).get("description",""))
