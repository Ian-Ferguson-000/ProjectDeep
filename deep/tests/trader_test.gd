extends SceneTree

## The dungeon trader: exactly 3 items, rarity from the stage's odds (as chests), and nothing else,
## rolled fresh per floor and per run, no consumables anywhere.

var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var state := RunState.new(); state.set_class("warrior"); state.start_new_run(null,"forest")
	var settings := RunState.trader_settings()
	var prices: Dictionary = settings.prices

	# Shape and pricing.
	var offers := state.get_merchant_offers("forest","dungeon").filter(func(o): return String(o.kind) == "item")
	_expect(offers.size() == 3,"Trader should show 3 items, shows %d" % offers.size())
	for offer in offers:
		_expect(String(offer.kind) == "item","Trader sold a %s" % offer.kind)
		_expect(int(offer.gold) == int(prices[String(offer.rarity)]),"%s priced wrong" % offer.name)
		_expect(GameBalance.item_usable_by_class(String(offer.item_id),"warrior") and not Unlocks.is_item_locked(state.campaign,String(offer.item_id)),"%s should not be on sale" % offer.item_id)
		_expect(String(offer.rules_text).to_lower() == GameBalance.get_slasher_item_rules_text(String(offer.item_id)).trim_prefix("Slasher: ").to_lower(),"%s shows the old turn-based rules" % offer.name)
	# No hearts, keys or other pickups on the counter.
	var pickups := state.get_merchant_offers("forest","dungeon").filter(func(o): return String(o.kind) != "item")
	_expect(pickups.is_empty(),"The trader sells pickups: %s" % [pickups])
	var ids := offers.map(func(o): return String(o.item_id))
	for id in ids: _expect(ids.count(id) == 1,"Trader offered %s twice" % id)

	# Potions drop in runs, so potion relics are in the pool (the trader never sells potions themselves).
	var potion_relic_seen := false
	for sample in 200:
		state.floor_seed = 77 + sample * 13
		for offer in state.get_merchant_offers("forest","dungeon").filter(func(o): return String(o.kind) == "item"):
			_expect(String(offer.kind) != "consumable","Trader sold consumable %s" % offer.offer_id)
			if String(offer.item_id) in ["healers_brooch","apothecarys_cup","saints_phial"]: potion_relic_seen = true
	_expect(potion_relic_seen,"Potion relics never offered although potions drop")
	state.floor_seed = 1001 + 37
	offers = state.get_merchant_offers("forest","dungeon").filter(func(o): return String(o.kind) == "item")

	# Same floor: same stock. New floor or new run: fresh stock.
	_expect(_ids(state.get_merchant_offers("forest","dungeon").filter(func(o): return String(o.kind) == "item")) == _ids(offers),"Stock changed while staying on the floor")
	var changed_floors := 0
	for floor_number in range(2,8):
		state.current_floor = floor_number
		if _ids(state.get_merchant_offers("forest","dungeon").filter(func(o): return String(o.kind) == "item")) != _ids(offers): changed_floors += 1
	_expect(changed_floors >= 5,"Stock did not refresh between floors (%d of 6 changed)" % changed_floors)
	state.current_floor = 1
	var other_run := RunState.new(); other_run.set_class("warrior"); other_run.start_new_run(null,"forest"); other_run.floor_seed += 7919
	_expect(_ids(other_run.get_merchant_offers("forest","dungeon").filter(func(o): return String(o.kind) == "item")) != _ids(offers),"A new run kept the old stock")

	# Launching the game twice must not give the same first run.
	var launch_a := RunState.new(); launch_a.set_class("warrior"); launch_a.start_new_run(null,"forest")
	var launch_b := RunState.new(); launch_b.set_class("warrior"); launch_b.start_new_run(null,"forest")
	_expect(launch_a.floor_seed != launch_b.floor_seed and _ids(launch_a.get_merchant_offers("forest","dungeon").filter(func(o): return String(o.kind) == "item")) != _ids(launch_b.get_merchant_offers("forest","dungeon").filter(func(o): return String(o.kind) == "item")),"Two fresh launches got the same first run")
	var c := CampaignState.new(); c.apply_post_tutorial_state("victory")
	for candidate in c.get_candidates(): c.recruit_candidate(candidate.id)
	c.launch_expedition([c.living_roster()[0].id],"forest")
	var expedition_run := RunState.new(); expedition_run.attach_campaign(c); expedition_run.active_character_id = c.living_roster()[0].id; expedition_run.start_new_run(null,"forest")
	_expect(c.expedition.floor_seed == expedition_run.floor_seed and ExpeditionState.from_dict(c.expedition.to_dict()).floor_seed == expedition_run.floor_seed,"Run seed not saved with the expedition")

	# Rarity mix follows the stage (loot_tables.json rarity_weights_by_stage):
	# forest, crypt and hell each roll their own odds, for the trader and chests alike.
	for dungeon in ["forest","crypt","balors_hell"]:
		var stage_run := RunState.new(); stage_run.set_class("warrior"); stage_run.start_new_run(null,dungeon)
		var weights: Dictionary = GameBalance.get_stage_rarity_weights(dungeon)
		var total := 0.0
		for key in weights: total += float(weights[key])
		var seen := {}
		var rolls := 0
		for sample in 700:
			stage_run.floor_seed = 1000 + sample * 31
			var stock := stage_run.get_merchant_offers(dungeon,"dungeon")
			_expect(stock.size() == 3,"%s trader stock was not 3 items" % dungeon)
			for extra in stock: seen[String(extra.rarity)] = int(seen.get(String(extra.rarity),0)) + 1; rolls += 1
		for key in ["uncommon","rare"]:
			var share := float(seen.get(key,0)) / float(rolls)
			var want := float(weights.get(key,0)) / total
			_expect(absf(share - want) < 0.06,"%s trader %s share %.2f, expected about %.2f" % [dungeon,key,share,want])
	_expect(GameBalance.stage_of("forest") == "forest" and GameBalance.stage_of("crypt") == "crypt" and GameBalance.stage_of("balors_hell") == "hell","Dungeons map to the wrong stages")
	for pair in [["forest",[70,25,4,1]],["crypt",[60,25,10,5]],["balors_hell",[40,40,10,10]]]:
		var odds: Dictionary = GameBalance.get_stage_rarity_weights(pair[0])
		var got := ["uncommon","rare","very_rare","legendary"].map(func(key): return int(odds.get(key,-1)))
		_expect(got == pair[1],"%s odds are %s, want %s" % [pair[0],got,pair[1]])
	# Chests in the forest use the forest odds.
	var chest_run := RunState.new(); chest_run.set_class("warrior"); chest_run.start_new_run(null,"forest")
	_expect(GameBalance.get_slasher_chest_rarity_weights(1,0,"forest") == GameBalance.get_stage_rarity_weights("forest"),"Forest chests ignore the forest odds")

	# Buying: expensive, one each, refreshed next floor.
	state.floor_seed = 4242; state.current_floor = 1
	var stock := state.get_merchant_offers("forest","dungeon").filter(func(o): return String(o.kind) == "item")
	var first: Dictionary = stock[0]
	state.gold = int(first.gold) - 1
	_expect(String(state.purchase_merchant_offer("forest",String(first.offer_id),"dungeon")[0]) == "Not enough gold.","Bought without enough gold")
	state.gold = int(first.gold) + 5
	var held := state.inventory_items.size()
	state.purchase_merchant_offer("forest",String(first.offer_id),"dungeon")
	_expect(state.gold == 5 and state.inventory_items.size() == held + 1,"Purchase did not take gold and give the relic")
	_expect(bool(state.get_merchant_offers("forest","dungeon").filter(func(o): return String(o.kind) == "item")[0].sold),"Bought slot not marked sold")
	state.gold = 9999
	_expect(String(state.purchase_merchant_offer("forest",String(first.offer_id),"dungeon")[0]) == "That offer is sold out.","Bought the same slot twice")
	state.current_floor = 2
	_expect(not state.get_merchant_offers("forest","dungeon").filter(func(o): return String(o.kind) == "item").any(func(o): return bool(o.sold)),"Next floor's stock started sold out")
	state.start_new_run(null,"forest")
	_expect(state.trader_sold.is_empty(),"Purchases carried into a new run")

	# No consumables for now: tavern supplier, loot and drops.
	_expect(not RunState.consumables_for_sale(),"Consumables should not be for sale")
	_expect(RunState.potions_drop(),"Potions should still drop in runs")
	_expect(not bool(HearthArmory.buy_consumable(state.campaign,"healing_potion").get("ok",true)),"The Hearth still sells potions")
	for offer in state.get_merchant_offers("tavern","tavern"): _expect(String(offer.kind) != "consumable","Tavern supplier still sells %s" % offer.offer_id)

	# The shop panel shows the trader's stock.
	var panel := MerchantShopPanel.new(); root.add_child(panel)
	panel.setup(state,"forest","dungeon"); panel.open()
	await process_frame
	var buttons := panel.find_children("*BuyButton","",true,false)
	_expect(buttons.size() == state.get_merchant_offers("forest","dungeon").size(),"Shop panel shows %d buttons for %d offers" % [buttons.size(),state.get_merchant_offers("forest","dungeon").size()])
	panel.free()

	if failures.is_empty(): print("TRADER_TESTS_PASSED"); quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _ids(stock: Array) -> Array:
	return stock.map(func(o): return String(o.item_id))

func _expect(value: bool, message: String) -> void:
	if not value and not failures.has(message): failures.append(message)
