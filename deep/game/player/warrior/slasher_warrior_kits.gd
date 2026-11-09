extends RefCounted
const KIT := preload("res://game/player/warrior/slasher_warrior_kit.gd")
const FIGHTER_ARSENAL := preload("res://game/player/warrior/slasher_fighter_arsenal.gd")
const DATA := {
"headsmans_greatsword":{"name":"Headsman's Greatsword","actions":{"basic":"Hew","special":"Sentence","defensive":"Shoulder the Blow","movement":"Committed Step"},"description":"Broad Hew lands after a short windup. Sentence cleaves a telegraphed lane. Shoulder a frontal blow for an instant Hew; step forward with protection."},
"borderkeepers_spear":{"name":"Borderkeeper's Spear","actions":{"basic":"Measured Thrust","special":"Hold the Pass","defensive":"Yielding Guard","movement":"Flank March"},"description":"Thrust at the highlighted tip for bonus damage and Stamina. Plant a single-use lane; guard with a backstep and flank sideways."},
"banner_of_the_vanguard":{"name":"Banner of the Vanguard","actions":{"basic":"Rally Cut","special":"Plant the Standard","defensive":"Stand Together","movement":"Advance the Colors"},"description":"Plant a damaging rally banner, granting 15% nearby ally movement speed. Cuts extend its life within a finite budget. Share barriers with one deployed ally and carry the banner when advancing."},
"duelists_paired_sabres":{"name":"Duelist's Paired Sabres","actions":{"basic":"Answering Cuts","special":"Crossing Blades","defensive":"Bind Steel","movement":"Passing Step"},"description":"Alternate rapid cuts on the same enemy to earn Stamina. Cross two aimed arcs, bind a frontal melee attack for an exposed target, and sidestep without losing your pair."},
"chain_of_the_siege_breaker":{"name":"Chain of the Siege-Breaker","actions":{"basic":"Cast the Weight","special":"Draw and Break","defensive":"Chain Guard","movement":"Reel Through"},"description":"Strike and tether the first enemy in a long line. Pull ordinary foes into a slam; bosses take full impact without movement. Intercept three frontal shots or reel toward your tether."}}
const FIGHTER_DATA := {
"eldritch_bowstaff":{"name":"Eldritch Bowstaff","actions":{"basic":"Curse Strike","special":"Profane Sweep","defensive":"Crooked Guard","movement":"Witchstep"},"description":"Every strike brands an Eldritch Curse. Slain cursed creatures dissolve into one corrupted mini-beast per stack to fight beside you."},
"demon_blade":{"name":"Demon Blade","actions":{"basic":"Blood Draw","special":"Frenzy Cleave","defensive":"Reckless Guard","movement":"Bloodrush"},"description":"Drawing blood causes Frenzy, increasing attack damage and speed while doubling damage received."},
"storm_trident":{"name":"Storm Trident","actions":{"basic":"Thunder Prong","special":"Skyfall Throw","defensive":"Storm Guard","movement":"Flash Step"},"description":"Throw the trident into a targeted area to stun and pin enemies. Pinned enemies take double damage; retrieve the trident before throwing again."},
"valkyrian_sling":{"name":"Valkyrian Sling","actions":{"basic":"Valkyrie's Flight","special":"Choosers' Volley","defensive":"Return Parry","movement":"Winged Step"},"description":"A returning shot ricochets through enemies. Parry it on the return to launch it again with another full stack of attack damage."},
"dragonbone_dagger":{"name":"Dragonbone Dagger","actions":{"basic":"Deepen Wound","special":"Rend Scale","defensive":"Bone Turn","movement":"Drake Step"},"description":"Rapid cuts stack a refreshing armor-reducing Deep Wound, causing subsequent strikes to bite deeper."},
"archon_crossbow":{"name":"Archon Crossbow","actions":{"basic":"Impaling Bolt","special":"Archon's Skewer","defensive":"Steel Stock","movement":"Crankstep"},"description":"Metal bolts pierce and drag creatures in their path, gaining bonus damage for every creature already speared."},
"divine_hammer":{"name":"Divine Hammer","actions":{"basic":"Radiant Impact","special":"Heavenfall","defensive":"Hallowed Guard","movement":"Pilgrim's Step"},"description":"Every hit bursts with radiant splash. A killing smite refreshes the attack and instantly repeats the smash on the nearest enemy."},
"grim_reaver":{"name":"Grim Reaver","actions":{"basic":"Reaping Arc","special":"Grim Harvest","defensive":"Reaver's Guard","movement":"Deathstep"},"description":"Wide scythe arcs have a high critical rate. Kills begin a rampage whose stacking fury raises critical chance further."},
"sentinel_shield":{"name":"Sentinel Shield","actions":{"basic":"Shield Edge","special":"Sentinel Bash","defensive":"Hold Fast","movement":"Line Advance"},"description":"A brutal shield bash drives enemies backward and controls the front line."},
"umbral_bow":{"name":"Umbral Bow","actions":{"basic":"Shadow Slick","special":"Night Tether","defensive":"Shade Guard","movement":"Gloamstep"},"description":"Shadow arrows leash enemies to you, slowing them while stealing their speed to hasten your movement."}}
static func all_gear() -> Array[GearData]:
	var result: Array[GearData]=[]
	for id in DATA:result.append(GearData.create(id,DATA[id].name,3,false,0,DATA[id].actions.special,DATA[id].description,"warrior",DATA[id].actions.defensive))
	return result
static func has_kit(id: String) -> bool:return DATA.has(id) or FIGHTER_DATA.has(id)
static func data_for(id: String) -> Dictionary:return Dictionary(DATA.get(id,FIGHTER_DATA.get(id,{})))
static func description(id: String) -> String:return String(data_for(id).get("description",""))
static func script_for(id: String) -> Script:return FIGHTER_ARSENAL if FIGHTER_ARSENAL.WEAPON_IDS.has(id) else KIT
