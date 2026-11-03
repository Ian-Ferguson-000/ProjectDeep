extends SceneTree

## The Set Out screen, coming-soon destinations, the pantry and happiness.

var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _company() -> CampaignState:
	var state := RunState.new()
	var c := state.campaign
	c.apply_post_tutorial_state("victory")
	for candidate in c.get_candidates(): c.recruit_candidate(candidate.id)
	c.first_normal_launch_completed = true
	return c

func _run() -> void:
	# ---- coming soon
	for id in ["ashen_farmstead","balors_hell","sunken_mine","ember_foundry","moonlit_grove","abyssal_archive"]:
		_expect(RunState.is_coming_soon(id) and not RunState.dungeon_available(id),"%s should be coming soon" % id)
	_expect(not RunState.is_coming_soon("forest") and RunState.dungeon_available("forest") and RunState.dungeon_available("crypt"),"Forest and crypt should be playable")
	var probe := RunState.new()
	_expect(not probe.is_dungeon_unlocked("balors_hell"),"A coming-soon dungeon reports as unlocked")

	# ---- the screen
	var c := _company()
	var state := RunState.new(); state.attach_campaign(c)
	var screen := ExpeditionSetup.new()
	root.add_child(screen)
	screen.open(c,state)
	await process_frame
	_expect(screen.visible and screen.step == 0,"Set Out didn't open on the destination step")
	_expect(screen.find_child("Destination_forest",true,false) is Button,"No forest card")
	# Three tiles, left to right: forest, then the farmstead and grove as locked "coming soon".
	var row: Node = screen.find_child("Destination_forest",true,false).get_parent()
	var names: Array = row.get_children().map(func(n): return String(n.name))
	_expect(names == ["Destination_forest","ComingSoon_ashen_farmstead","ComingSoon_moonlit_grove"],"Destination tiles are %s" % [names])
	for id in ["ashen_farmstead","moonlit_grove"]:
		var soon := screen.find_child("ComingSoon_%s" % id,true,false)
		_expect(soon != null and not soon is BaseButton and soon.find_child("Lock",true,false) != null,"%s should be a locked, unclickable tile" % id)
	# The crypt is reached by playing through the forest, not picked here.
	_expect(screen.find_child("Destination_crypt",true,false) == null and screen.find_child("Destination_balors_hell",true,false) == null,"Only the forest should be selectable")
	screen.dungeon_id = "crypt"; screen.go_to(1); await process_frame
	_expect(screen.step == 0 and not screen.readiness().ok,"The crypt can be chosen as a starting destination")
	screen.dungeon_id = "forest"
	(screen.find_child("Destination_forest",true,false) as Button).pressed.emit()
	await process_frame
	screen.go_to(1); await process_frame
	var heroes: Array[Node] = screen.find_children("Hero_*","Button",true,false)
	_expect(heroes.size() == c.living_roster().size(),"Not every adventurer has a card")
	var away := c.living_roster()[0]
	away.status = "recovering"; away.recovery_until = c.calendar_day + 2
	screen.refresh(); await process_frame
	var away_card := screen.find_child("Hero_%s" % away.id,true,false) as Button
	_expect(away_card != null and away_card.disabled,"A recovering adventurer can be picked")
	var hero := c.living_roster()[1]
	(screen.find_child("Hero_%s" % hero.id,true,false) as Button).pressed.emit()
	await process_frame
	_expect(screen.hero_id == hero.id,"Picking an adventurer didn't select them")
	screen.go_to(2); await process_frame
	_expect(screen.find_child("Slot_weapon",true,false) != null and screen.find_child("Slot_relic",true,false) != null,"Gear step lacks equipment slots")
	# Equip from storage through the slot picker.
	var armor_id := HearthArmory.grant(c,"light_armor_1")
	screen.refresh(); await process_frame
	var armor_picker := screen.find_child("Slot_armor",true,false).find_child("Picker",true,false) as OptionButton
	if armor_picker != null and armor_picker.item_count > 1 and String(HearthCatalog.item("light_armor_1").get("class_id",hero.class_id)) == hero.class_id:
		armor_picker.item_selected.emit(1)
		await process_frame; await process_frame
		_expect(String(hero.equipment.get("armor","")) == armor_id,"Choosing armor in the slot didn't equip it")
	# Potions.
	c.consumable_stock["healing_potion"] = 2
	screen.refresh(); await process_frame
	(screen.find_child("PackPotion",true,false) as Button).pressed.emit()
	await process_frame
	_expect(hero.provisions.count("healing_potion") == 1 and int(c.consumable_stock.healing_potion) == 1,"Packing a potion didn't move it from storage")
	# Rations gate Set Out.
	c.pantry = {"scraps":0,"hearty":0,"feast":0}
	screen.refresh(); await process_frame
	_expect(not screen.readiness().ok and screen.next_button.disabled,"Set Out allowed with an empty pantry")
	c.pantry["hearty"] = 5
	screen.refresh(); await process_frame
	var launched := []
	screen.launch_requested.connect(func(d, h): launched.append([d,h]))
	_expect(screen.readiness().ok and not screen.next_button.disabled,"Set Out blocked with rations and a ready hero: %s" % screen.readiness().get("error",""))
	screen.next_button.pressed.emit()
	_expect(launched.size() == 1 and launched[0] == ["forest",hero.id],"Set Out didn't launch the chosen run")
	screen.queue_free()

	# ---- the pantry and happiness
	c = _company()
	var members := HearthUpkeep.diners(c)
	c.pantry = {"scraps":0,"hearty":0,"feast":10}
	c.served_food = "feast"
	for member in members: member.morale = 50
	HearthUpkeep.daily(c)
	_expect(int(c.pantry.feast) == 10 - members.size(),"Everyone at home didn't eat one ration")
	_expect(members.all(func(m): return m.morale == 50 + int(HearthUpkeep.food("feast").happiness)),"A feast didn't lift happiness")
	c.pantry = {"scraps":3,"hearty":0,"feast":0}; c.served_food = "hearty"
	HearthUpkeep.daily(c)
	_expect(int(c.pantry.scraps) == 3 - members.size(),"Out of the served food, the Hearth didn't fall back to what it has")
	c.pantry = {"scraps":0,"hearty":0,"feast":0}
	var before := members[0].morale
	var events := HearthUpkeep.daily(c)
	_expect(members[0].morale < before and events.any(func(line): return String(line).contains("hungry")),"An empty pantry didn't hurt and wasn't reported")
	# Unhappy adventurers walk out, sooner after training.
	var leaver := members[0]
	var gone := false
	for day in 40:
		c.calendar_day += 1
		c.pantry["hearty"] = 50
		leaver.morale = 0
		leaver.training["last_day"] = c.calendar_day - 1
		HearthUpkeep.daily(c)
		if c.character(leaver.id) == null: gone = true; break
	_expect(gone,"A miserable adventurer never left")
	# Expedition results.
	var hero2 := c.living_roster()[0]
	hero2.morale = 50
	HearthUpkeep.on_return(c,[hero2.id],"victory")
	_expect(hero2.morale == 50 + int(HearthUpkeep.data().victory_happiness),"Victory didn't cheer the hero")
	# Buying and serving.
	c.banked_gold = 100
	_expect(HearthUpkeep.buy(c,"hearty",5).ok and int(c.pantry.hearty) >= 5 and c.banked_gold == 100 - 5 * int(HearthUpkeep.food("hearty").cost),"Buying supplies failed")
	_expect(HearthUpkeep.serve(c,"scraps").ok and c.served_food == "scraps","Changing what's served failed")
	# Saves keep the pantry; old saves turn plain supplies into Hearty Fare.
	var loaded := CampaignState.new(); loaded._load_dict(CampaignState._migrate_dict(c.to_dict()))
	_expect(JSON.stringify(loaded.pantry) == JSON.stringify(c.pantry) and loaded.served_food == "scraps","The pantry didn't survive a save")
	var old := c.to_dict(); old.erase("pantry"); old["supplies"] = 7
	var migrated := CampaignState.new(); migrated._load_dict(CampaignState._migrate_dict(old))
	_expect(int(migrated.pantry.get("hearty",0)) == 7 and migrated.supplies == 7,"Old supplies didn't become Hearty Fare")
	# A run takes rations.
	var runner := _company()
	runner.pantry = {"scraps":0,"hearty":10,"feast":0}
	var ids: Array[String] = [runner.default_party("forest")[0]]
	_expect(runner.launch_expedition(ids,"forest").ok and runner.supplies == 10 - HearthUpkeep.rations_per_run(),"Setting out didn't take rations")
	# Expanding the Hearth costs renown.
	var builder := _company()
	builder.banked_gold = 5000; builder.reputation = 30; builder.record_dungeon_clear("forest")
	var renown_cost := int(HearthFacilities.quote(builder,"roster_services").get("renown",0))
	_expect(renown_cost > 0 and HearthFacilities.purchase(builder,"roster_services").ok and builder.reputation == 30 - renown_cost,"Expanding the Hearth didn't spend renown")

	await process_frame
	if failures.is_empty(): print("EXPEDITION_SETUP_TESTS_PASSED"); quit(0)
	else:
		for failure in failures: printerr("FAIL: " + failure)
		quit(1)
