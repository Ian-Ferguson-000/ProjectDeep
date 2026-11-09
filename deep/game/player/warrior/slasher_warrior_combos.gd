extends RefCounted
const ENTRIES := {
 "standard": [
  [
   "shield_drum",
   "Shield Drum",
   "DBS",
   "After the normal Cleave, slam a 180-radius physical ring for 8x attack power; ordinary enemies briefly stagger."
  ],
  [
   "marching_edge",
   "Marching Edge",
   "MDB",
   "Cut a 300-long, 35-wide lane from Charge departure for 8x attack power, covering your advance."
  ]
 ],
 "headsmans_greatsword": [
  [
   "red_sentence",
   "Red Sentence",
   "BBS",
   "Widen the finishing Sentence lane to 80 half-width and increase its pending damage by 60%."
  ],
  [
   "quarry_breaker",
   "Quarry Breaker",
   "DMS",
   "Send two parallel 260-range shock cleaves, each dealing 7x physical damage."
  ],
  [
   "reaping_advance",
   "Reaping Advance",
   "MBS",
   "Reap a 190-radius full circle at Committed Step departure for 12x damage."
  ],
  [
   "iron_rebuttal",
   "Iron Rebuttal",
   "BDB",
   "Gain a three-second 25%-HP barrier and perform an immediate 180-range, 150-degree Hew for 6x damage."
  ],
  [
   "execution_wheel",
   "Execution Wheel",
   "MDS",
   "Spin a 220-radius full-circle blade sweep for 12x damage; ordinary foes stagger briefly."
  ],
  [
   "last_word",
   "Last Word",
   "SBM",
   "Leave a telegraphed departure cleave, resolving after 0.25 seconds along a 300-range lane for 14x damage."
  ]
 ],
 "borderkeepers_spear": [
  [
   "crossing_points",
   "Crossing Points",
   "BMB",
   "Thrust along two crossing 300-range spear lines at plus/minus 15 degrees for 6x damage each."
  ],
  [
   "long_watch",
   "Long Watch",
   "MBS",
   "Extend Hold the Pass to 420 range and four seconds, with a 50 half-width; it remains single-use."
  ],
  [
   "second_rank",
   "Second Rank",
   "DBS",
   "Add a second single-use, three-second spear lane 70 to the side, dealing 10x damage after a 0.12-second arm."
  ],
  [
   "mobile_redoubt",
   "Mobile Redoubt",
   "SBM",
   "Replant the existing lane at your landing point and current aim without extending its remaining life."
  ],
  [
   "rearward_fence",
   "Rearward Fence",
   "BDM",
   "Strike a 280-range spear line from your movement departure for 8x damage and knock ordinary enemies away."
  ],
  [
   "needle_gate",
   "Needle Gate",
   "MDB",
   "Send three parallel 300-range thrusts from lanes 45 apart, each dealing 6x damage."
  ]
 ],
 "banner_of_the_vanguard": [
  [
   "vanguard_crash",
   "Vanguard Crash",
   "SBM",
   "Burst for 10x damage in 150 range at arrival and grant self plus one nearby deployed ally a two-second 15%-HP barrier."
  ],
  [
   "unbroken_standard",
   "Unbroken Standard",
   "BSB",
   "Add two seconds to the banner extension budget once per planting, then strike a 150-radius ring at the banner for 8x damage."
  ],
  [
   "captains_oath",
   "Captain's Oath",
   "DBS",
   "At the planted banner, grant self and the nearest deployed ally within 150 a three-second 25%-HP barrier."
  ],
  [
   "covering_colors",
   "Covering Colors",
   "MBD",
   "Gain a three-second 25%-HP barrier and cut backward in a 160-range, 140-degree arc for 7x damage."
  ],
  [
   "rally_march",
   "Rally March",
   "BDM",
   "Grant self and deployed allies within 150 a nonstacking 25% speed boost for two seconds; advance with a 130-radius 7x burst."
  ],
  [
   "standard_relay",
   "Standard Relay",
   "SMBS",
   "Burst for 12x damage in 150 range at the previous banner position, rewarding a staged relocation before replanting."
  ]
 ],
 "duelists_paired_sabres": [
  [
   "answered_challenge",
   "Answered Challenge",
   "BMB",
   "Immediately land two crossing 130-range cuts, dealing 5x damage each, in addition to the paired Basic."
  ],
  [
   "steel_verdict",
   "Steel Verdict",
   "DBS",
   "Add two narrow crossing blade lanes for 8x damage each, rewarding a bound attack angle."
  ],
  [
   "circling_blades",
   "Circling Blades",
   "MBS",
   "Cut from your departure and arrival positions in opposed 140-degree arcs for 8x damage each."
  ],
  [
   "duelists_resolve",
   "Duelist's Resolve",
   "BDM",
   "Gain a three-second 20%-HP barrier and bind nearby ordinary enemies with a 100-radius 6x slowing sweep."
  ],
  [
   "phantom_flurry",
   "Phantom Flurry",
   "SBM",
   "Leave three staggered departure cuts at 0.08-second intervals, each dealing 5x damage in 150 range."
  ],
  [
   "perfect_measure",
   "Perfect Measure",
   "MDB",
   "Empower the next Crossing Blades within two seconds by 50%, without changing its cost or hit-proc budget."
  ]
 ],
 "chain_of_the_siege_breaker": [
  [
   "breach_run",
   "Breach Run",
   "BSM",
   "Sweep the path from Reel Through departure to arrival for 10x damage in a 45-wide lane."
  ],
  [
   "wrecking_ball",
   "Wrecking Ball",
   "MBS",
   "Add a 150-radius, 12x physical impact around the drawn target or forward slam point."
  ],
  [
   "iron_net",
   "Iron Net",
   "DBS",
   "Strike three diverging 280-range chain lanes for 7x damage each."
  ],
  [
   "anchor_crash",
   "Anchor Crash",
   "BDM",
   "Detonate a 120-radius, 10x chain impact at the last tether point; ordinary enemies are slowed for 0.5 seconds."
  ],
  [
   "siege_wheel",
   "Siege Wheel",
   "SBM",
   "Spin a 180-radius 12x physical sweep at arrival and push ordinary enemies outward."
  ],
  [
   "linked_weights",
   "Linked Weights",
   "BMB",
   "Arc from the newly tethered target to two distinct nearby foes within 180, dealing 8x physical damage per target with no recursive procs."
  ]
 ]
}
const SLOTS := {"B":"basic","S":"special","D":"defensive","M":"movement"}
static func recipes(kit: String, names: Dictionary={}) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if kit=="standard":result=GameBalance.get_slasher_combos("warrior")
	for entry in ENTRIES.get(kit,[]):
		var steps: Array[String]=[];var labels: Array[String]=[]
		for letter in String(entry[2]):
			var slot: String=SLOTS[letter];steps.append("action:"+slot);labels.append(String(names.get(slot,slot.capitalize())))
		result.append({"id":entry[0],"name":entry[1],"steps":steps,"step_labels":labels,"window":2.5,"priority":40,"description":entry[3],"effect":{"warrior_combo":true}})
	return result
