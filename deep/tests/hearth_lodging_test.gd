extends SceneTree

## Hearth rooms, furnishings and stat training (data/lodging.json).

var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	_expect(HearthLodging.validate().is_empty(),"lodging.json is invalid: %s" % "; ".join(HearthLodging.validate()))
	var c := CampaignState.new(); c.apply_post_tutorial_state("victory")
	for candidate in c.get_candidates(): c.recruit_candidate(candidate.id)
	var starting := int(HearthLodging.data().starting_rooms)
	_expect(c.get_roster_capacity() == starting and c.get_room_limit() == 6,"A new Hearth should start with %d rooms and space for 6" % starting)
	var members := c.living_roster()
	for member in members: _expect(not HearthLodging.room_of(c,member.id).is_empty(),"%s has no room" % member.display_name)
	# Rooms fill up, then recruiting is blocked until another is built.
	c.banked_gold = 5000
	var guard := 0
	while c.living_roster().size() < c.get_roster_capacity() and guard < 10:
		guard += 1
		if c.get_candidates().is_empty(): c._generate_candidate_wave(false)
		c.recruit_candidate(c.get_candidates()[0].id)
	if c.get_candidates().is_empty(): c._generate_candidate_wave(false)
	_expect(not bool(c.recruit_candidate(c.get_candidates()[0].id).ok),"Recruited without a free room")
	var gold := c.banked_gold; var cost := HearthLodging.build_cost(c)
	_expect(bool(HearthLodging.build_room(c).ok) and c.banked_gold == gold - cost and c.get_roster_capacity() == starting + 1,"Building a room did not add a room for its cost")
	_expect(bool(c.recruit_candidate(c.get_candidates()[0].id).ok),"Could not recruit into the new room")
	while c.rooms.size() < c.get_room_limit(): HearthLodging.build_room(c)
	_expect(not bool(HearthLodging.build_room(c).ok),"Built past the establishment tier's room limit")
	c.establishment_tier = 1
	_expect(bool(HearthLodging.build_room(c).ok),"Expanding the Hearth did not make space for more rooms")
	# Quality upgrades respect the establishment tier.
	var room: Dictionary = HearthLodging.room_of(c,members[0].id)
	_expect(bool(HearthLodging.upgrade_room(c,String(room.id)).ok) and bool(HearthLodging.upgrade_room(c,String(room.id)).ok),"Could not upgrade a room to a Hearth Chamber")
	_expect(not bool(HearthLodging.upgrade_room(c,String(room.id)).ok),"Upgraded to a Lantern Suite before the Hearth was big enough")
	# Furnishings fill slots, need the right quality, and go to storage when removed.
	var cot: Dictionary = c.rooms.filter(func(r): return String(r.quality) == "cot")[0]
	_expect(not bool(HearthLodging.place_furnishing(c,String(cot.id),"crystal_ball").ok),"A crystal ball fit in a straw cot")
	_expect(bool(HearthLodging.place_furnishing(c,String(cot.id),"spellbook_stack").ok),"Could not place spellbooks in a cot")
	_expect(not bool(HearthLodging.place_furnishing(c,String(cot.id),"training_dummy").ok),"A one-slot cot took two furnishings")
	_expect(bool(HearthLodging.remove_furnishing(c,String(cot.id),0).ok) and int(c.furnishing_storage.get("spellbook_stack",0)) == 1,"Removing a furnishing did not store it")
	gold = c.banked_gold
	HearthLodging.place_furnishing(c,String(room.id),"spellbook_stack")
	_expect(c.banked_gold == gold and not c.furnishing_storage.has("spellbook_stack"),"A stored furnishing was bought again instead of reused")
	# Moving rooms swaps occupants.
	var a := members[0]; var b := members[1]
	var room_a := String(HearthLodging.room_of(c,a.id).id); var room_b := String(HearthLodging.room_of(c,b.id).id)
	_expect(bool(HearthLodging.assign_room(c,room_b,a.id).ok) and String(HearthLodging.room_of(c,a.id).id) == room_b and String(HearthLodging.room_of(c,b.id).id) == room_a,"Moving into an occupied room did not swap")
	# Training: matching furnishings raise the chance, sessions cost gold, once per day.
	var warrior := members.filter(func(m): return m.class_id == "warrior")[0] as CharacterRecord
	warrior.attributes["str"] = 12
	var plain := int(HearthLodging.training_chance(c,warrior,"str").chance)
	var home := String(HearthLodging.room_of(c,warrior.id).id)
	for index in c.rooms.size():
		if String(c.rooms[index].id) == home: c.rooms[index].furnishings = []; c.rooms[index].quality = "suite"
	var suite_str := int(HearthLodging.training_chance(c,warrior,"str").chance)
	var suite_int := int(HearthLodging.training_chance(c,warrior,"int").chance)
	_expect(suite_str > plain,"A finer room did not make training easier")
	HearthLodging.place_furnishing(c,home,"training_dummy")
	_expect(int(HearthLodging.training_chance(c,warrior,"str").chance) > suite_str,"A training dummy did not help a warrior train Strength")
	_expect(int(HearthLodging.training_chance(c,warrior,"int").chance) == suite_int,"A training dummy helped Intelligence")
	gold = c.banked_gold; var session_cost := HearthLodging.training_cost(warrior,"str"); var before := int(warrior.attributes.str)
	var result := HearthLodging.train(c,warrior.id,"str")
	_expect(bool(result.ok) and c.banked_gold == gold - session_cost,"Training did not charge its cost")
	_expect(int(warrior.attributes.str) == before + (1 if bool(result.success) else 0),"Training changed the stat by the wrong amount")
	_expect(not bool(HearthLodging.train(c,warrior.id,"dex").ok),"Trained twice in one day")
	# Failures build practice; over several days training always pays off eventually.
	var start_con := int(warrior.attributes.con)
	warrior.attributes["con"] = 16; warrior.training = {}
	var successes := 0
	for day in 12:
		c.calendar_day += 1
		var outcome := HearthLodging.train(c,warrior.id,"con")
		if bool(outcome.get("success",false)): successes += 1
		elif bool(outcome.ok): _expect(int(Dictionary(warrior.training.practice).get("con",0)) > 0,"A failed session did not bank practice")
	_expect(successes >= 1 and int(warrior.attributes.con) <= int(HearthLodging.training_rules().stat_cap),"Training never succeeded, or passed the cap")
	_expect(warrior.max_health == AdventurerBuilds.max_health_for(warrior.class_id,warrior.level,warrior.attributes),"Constitution training did not update health")
	warrior.attributes["con"] = start_con
	# Away adventurers cannot train.
	b.status = CharacterRecord.STATUS_EXPEDITION; c.calendar_day += 1
	_expect(not bool(HearthLodging.train(c,b.id,"str").ok),"An adventurer on expedition trained")
	b.status = CharacterRecord.STATUS_AVAILABLE
	# Saves keep rooms, storage and training; old saves keep their capacity.
	HearthLodging.remove_furnishing(c,home,0)
	var restored := CampaignState.new(); restored._load_dict(c.to_dict())
	_expect(restored.rooms == c.rooms and restored.furnishing_storage == c.furnishing_storage,"Rooms or storage lost on save/load")
	_expect(restored.character(warrior.id).training == warrior.training,"Training history lost on save/load")
	var legacy := c.to_dict(); legacy.erase("rooms"); legacy.erase("furnishing_storage")
	var old := CampaignState.new(); old._load_dict(legacy)
	_expect(old.get_roster_capacity() >= old.get_room_limit() and old.get_roster_capacity() >= old.living_roster().size(),"An old save lost rooms when loaded")
	for member in old.living_roster(): _expect(not HearthLodging.room_of(old,member.id).is_empty(),"%s lost their room in an old save" % member.display_name)
	# Leaving the company frees a room.
	var leaving := c.living_roster().back() as CharacterRecord
	c.first_normal_launch_completed = true
	c.dismiss_character(leaving.id); HearthLodging.sync_occupants(c)
	_expect(HearthLodging.room_of(c,leaving.id).is_empty(),"A dismissed adventurer kept their room")
	if failures.is_empty(): print("HEARTH_LODGING_TESTS_PASSED"); quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(value: bool, message: String) -> void:
	if not value and not failures.has(message): failures.append(message)
