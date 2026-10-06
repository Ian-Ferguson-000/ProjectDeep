extends RefCounted

const PYROMANCY := preload("res://scripts/slasher/slasher_pyromancy.gd")
const WINTERGLASS := preload("res://scripts/slasher/slasher_winterglass.gd")
const STORMBRINGER := preload("res://scripts/slasher/slasher_stormbringer.gd")
const GRAVITY := preload("res://scripts/slasher/slasher_gravity.gd")
const MIRRORBOUND := preload("res://scripts/slasher/slasher_mirrorbound.gd")
const SCRIPTS := [PYROMANCY,WINTERGLASS,STORMBRINGER,GRAVITY,MIRRORBOUND]

static func script_for(id: String) -> Script:
	for script in SCRIPTS:
		if script.GEAR_ID==id:return script
	return null

static func all_gear() -> Array[GearData]:
	var result: Array[GearData]=[]
	for script in SCRIPTS:result.append(script.gear())
	return result

static func description(id: String) -> String:
	match id:
		PYROMANCY.GEAR_ID:return "Rapid piercing Lance applies Burn. Any fire ignites stacking Cinder Trails along their full paths, including Conflagration. Furnace Mantle burns a 130-radius aura and mitigates one hit. Fire damage; 1 Mana Special."
		WINTERGLASS.GEAR_ID:return "Weaker Needles stack three Chill pips; cold kills shatter into eight radial needles. Fracture consumes Chill for burst and freezes terrain for 5 seconds. Icebook Wall blocks hostile shots and enemy movement; allies pass. Retreat freezes a 5-second strip. Frozen terrain grants you 40% movement speed. Ice damage; 1 Mana Special."
		STORMBRINGER.GEAR_ID:return "Spark always chains to up to four distinct nearby enemies. Each bounce retains 70% damage; an active conductor preserves full damage. Place up to three pulsing rods. Static Screen blocks up to three frontal shots. Flash Circuit travels to the rod nearest your clicked point. Lightning damage; 1 Mana Special."
		GRAVITY.GEAR_ID:return "Explosive stones arrive after a short launch delay. Collapse pulls ordinary enemies then bursts; bosses take burst damage without being moved. Heavy Air slows hostile shots and mitigates one hit. Anchor Exchange offers one return. Arcane damage; 1 Mana Special."
		MIRRORBOUND.GEAR_ID:return "Movement leaves a mirror. Script fires a half-strength shot from the mirror and records one aim direction; Read Again fires from you and replays the recorded shot from the mirror. Blank Page can trade that recording for a short barrier. Arcane damage; 1 Mana Special."
	return ""
