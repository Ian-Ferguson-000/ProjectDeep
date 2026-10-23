extends SceneTree

## pickup_items.json is well formed, keeps every item, and restricts drops by
## class group; and the levelling switch turns XP, levels and Training off.

const VALID_RARITIES := ["common","uncommon","rare","very_rare","legendary"]
const VALID_DURATIONS := ["permanent","dungeon_bound","run","temporary"]

var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pickup_items.json"))
	_expect(source != null and not source.is_empty(),"pickup_items.json does not parse")
	var groups: Dictionary = Dictionary(source.get("class_groups",{}))
	var grouped := {}
	for group in groups: for class_id in groups[group]: _expect(not grouped.has(class_id),"%s is in two class groups" % class_id); grouped[class_id] = group
	for class_id in ["warrior","mage","healer","tank","rogue","summoner"]: _expect(grouped.has(class_id),"%s is in no class group" % class_id)
	var seen := {}
	for group in GameBalance.ITEM_GROUPS:
		for item_id in Dictionary(source.get(group,{})):
			var item: Dictionary = source[group][item_id]
			_expect(not seen.has(item_id),"%s appears in more than one group" % item_id); seen[item_id] = true
			for field in ["name","rarity","lasts","description","stats"]: _expect(item.has(field),"%s is missing %s" % [item_id,field])
			_expect(VALID_RARITIES.has(String(item.get("rarity",""))),"%s has an unknown rarity" % item_id)
			_expect(VALID_DURATIONS.has(String(item.get("lasts",""))),"%s has an unknown 'lasts' value" % item_id)
			if String(item.get("lasts","")) == "temporary": _expect(int(item.get("floors",0)) > 0,"%s is temporary but has no floors" % item_id)
	_expect(seen.size() == 52 and GameBalance.get_items().size() == 52,"Item count changed during the move to pickup_items.json")
	var giant: Dictionary = GameBalance.get_item("giant_bane_grip")
	_expect(String(giant.usable_by) == "melee_only" and int(Dictionary(giant.modifiers).get("attack_power",0)) == 2,"Item stats did not survive the move")
	_expect(is_equal_approx(float(GameBalance.get_slasher_item_effects("giant_bane_grip").get("elite_damage_multiplier",0)),1.16),"Combat rules did not survive the move")
	# Class groups decide what drops.
	for class_id in ["warrior","rogue","tank","mage","healer","summoner"]:
		var state := RunState.new()
		state.set_class(class_id)
		state.start_new_run(null,"forest")
		var offered := {}
		for chest in 60:
			for item_id in state.generate_slasher_chest_choices(1 + chest % 5,"chest_%d" % chest): offered[item_id] = true
		var group := GameBalance.get_class_item_group(class_id)
		for item_id in offered:
			var usable := String(GameBalance.get_item(item_id).usable_by)
			_expect(usable == "any_class" or usable == "%s_only" % group,"%s was offered %s (%s)" % [class_id,item_id,usable])
			_expect(bool(GameBalance.get_item(item_id).drops),"%s was offered %s, which is out of the drop pool" % [class_id,item_id])
		for offer in state.get_merchant_offers("tavern","tavern"):
			if String(offer.get("kind","")) == "item": _expect(GameBalance.item_usable_by_class(String(offer.item_id),class_id),"%s merchant offered %s" % [class_id,offer.item_id])
	# Levelling switched off: no XP, no levels, no level-up choices, no Training.
	GameBalance.set_leveling_override(null)
	_expect(not GameBalance.leveling_enabled(),"Levelling should be off in progression.json")
	var runner := RunState.new()
	runner.set_class("warrior")
	runner.start_new_run(null,"forest")
	var health_before := runner.max_health
	runner.gain_xp(100000,"test")
	_expect(runner.get_level() == 1 and runner.max_health == health_before and not runner.has_pending_slasher_progression_choice(),"XP still levels heroes while levelling is off")
	var campaign := CampaignState.new(); campaign.apply_post_tutorial_state("victory"); campaign.establishment_tier = 3
	var recruit := campaign._generate_character("warrior")
	_expect(recruit.level == 1,"Recruits arrive above level 1 while levelling is off")
	recruit.level = 7
	_expect(recruit.max_health == AdventurerBuilds.max_health_for("warrior",1,recruit.attributes) and AdventurerBuilds.max_health_for("warrior",7,recruit.attributes) == AdventurerBuilds.max_health_for("warrior",1,recruit.attributes),"Stored levels still raise health while levelling is off")
	for candidate in campaign.get_candidates(): campaign.recruit_candidate(candidate.id)
	campaign.tavern_upgrades.replacement_quality = 2
	_expect(not bool(HearthFacilities.train(campaign,campaign.living_roster()[0].id).ok),"Training still works while levelling is off")
	# Switching it back on restores the old behaviour.
	GameBalance.set_leveling_override(true)
	var leveled := RunState.new(); leveled.set_class("warrior"); leveled.start_new_run(null,"forest")
	leveled.gain_xp(500,"test")
	_expect(leveled.get_level() > 1,"Levelling did not come back when switched on")
	GameBalance.set_leveling_override(null)
	if failures.is_empty(): print("PICKUP_ITEMS_TESTS_PASSED"); quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(value: bool, message: String) -> void:
	if not value and not failures.has(message): failures.append(message)
