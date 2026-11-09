extends RefCounted

# Successful actions only; each step has a generous 2.5 second practice window.
const ENTRIES := {
"standard":[
["arcane_crossfire","Arcane Crossfire","DMB","Blink after Repel, then fire two crossing arcane bolts from your departure and arrival points."],
["repulsion_well","Repulsion Well","BDM","Leave a two-second, 120-radius gravity pocket at Blink departure: pull ordinary foes and pulse arcane damage."],
["astral_bulwark","Astral Bulwark","MBD","Gain a three-second barrier worth 25% maximum HP; release six arcane bolts when it is exhausted."]],
"tome_of_the_pyromancer":[
["backdraft","Backdraft","MBS","Ignite every stored trail and detonate an extra 90-radius burst at each burning trail midpoint."],
["furnace_wake","Furnace Wake","DMB","Extend the independent Furnace aura to 1.5 seconds and instantly ignite the new dash trail."],
["wildfire_braid","Wildfire Braid","BMB","Fire five piercing flame lances in a 50-degree fan, lighting multiple lanes."],
["flashover","Flashover","BDS","Consume nearby owned Burns for a 30x fire burst around each marked enemy; overlapping bursts can hit a pack."],
["ember_orbit","Ember Orbit","MDB","Create a three-second moving 85-radius fire aura, pulsing 4x damage every 0.4 seconds."],
["ashen_return","Ashen Return","SBM","Leave a two-second 120-radius ash field at departure: fire pulses and a 40% ordinary-enemy slow."]],
"winterglass_codex":[
["whiteout","Whiteout","MBS","Freeze a five-second 140-radius field at your current position and send eight ice needles radially."],
["glacial_crosscut","Glacial Crosscut","BMB","Fire three parallel piercing ice lances from separated lanes for 12x damage each."],
["cold_front","Cold Front","DBS","Extend the current Icebook Wall to five seconds and fire five ice needles from its center (or your position)."],
["icebreaker","Icebreaker","BDS","Consume nearby Chill and burst around each marked foe: 8x damage per consumed stack in 80 range."],
["permafrost","Permafrost","SBM","Leave a five-second 140-radius frozen pool at departure and pulse 20x ice damage there."],
["diamond_guard","Diamond Guard","MBD","Gain a three-second 25%-HP barrier that releases eight radial ice needles when exhausted."]],
"stormbringers_grimoire":[
["closed_circuit","Closed Circuit","SBS","Link every pair of active rods: enemies within 24 of a link take 20x lightning once per combo."],
["thunderstep","Thunderstep","SBM","On arrival, discharge a 130-radius 20x lightning burst and eight radial lightning bolts."],
["overcharge","Overcharge","DBS","Charge every active rod for a doubled next pulse and bring that pulse forward to the next physics tick."],
["forked_horizon","Forked Horizon","MDB","Each rod arcs to its two nearest enemies within 180, for 12x secondary lightning per rod."],
["rolling_thunder","Rolling Thunder","BMS","Launch a moving 90-radius thunder field along aim for two seconds, pulsing 5x damage every 0.4 seconds."],
["storm_cage","Storm Cage","BDM","Discharge 20x lightning within 140 at arrival and root ordinary foes for 0.5 seconds; bosses only take damage."]],
"grimoire_of_gravity":[
["orbital_slingshot","Orbital Slingshot","SMB","Launch six piercing arcane stones radially from the live well or your position, dealing 12x each."],
["event_horizon","Event Horizon","BDS","Add a two-second 170-radius pulling field at the well or aimed position, pulsing 5x arcane damage."],
["singularity_step","Singularity Step","BSM","Leave a one-second 140-radius pulling field at departure, ending in a 25x arcane collapse."],
["satellite_guard","Satellite Guard","MBD","Orbit a 95-radius screen for two seconds; intercept up to three ordinary hostile shots and fire a stone down each intercepted lane."],
["tidal_inversion","Tidal Inversion","DMS","Burst outward at the return anchor or your position for 25x arcane damage and ordinary-enemy knockback."],
["return_trajectory","Return Trajectory","MSM","Launch three staggered piercing stones from your last departure toward the return landing, for 12x each."]],
"mirrorbound_manuscript":[
["palimpsest","Palimpsest","MBS","Alongside Read Again, send two half-strength recorded bolts from the mirror at plus/minus 18 degrees."],
["hall_of_mirrors","Hall of Mirrors","BMB","Fire from two ephemeral mirror images 75 to either side of your departure point; each piercing bolt deals 12x."],
["silver_crossfire","Silver Crossfire","MSB","Fire three 12x bolts from the mirror, aimed toward the clicked point with a 30-degree spread."],
["blank_verdict","Blank Verdict","BDS","Gain a three-second 20%-HP barrier and fire a 25x piercing verdict down the current aim from the mirror or you."],
["echo_passage","Echo Passage","SBM","Release a 15x piercing bolt from the old mirror and the new reflection; both aim down your departure direction."],
["prismatic_chorus","Prismatic Chorus","DBS","Fire four 10x piercing replay bolts from the mirror (or you) in a 60-degree fan."]]
}
const SLOTS := {"B":"basic","S":"special","D":"defensive","M":"movement"}

static func recipes(kit: String, names: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if kit=="standard":result=GameBalance.get_slasher_combos("mage")
	for entry in ENTRIES.get(kit,[]):
		var steps: Array[String]=[];var labels: Array[String]=[]
		for letter in String(entry[2]):
			var slot: String=SLOTS[letter];steps.append("action:"+slot);labels.append(String(names.get(slot,slot.capitalize())))
		result.append({"id":entry[0],"name":entry[1],"description":entry[3],"steps":steps,"step_labels":labels,"window":2.5,"priority":40,"effect":{"mage_combo":true}})
	return result
