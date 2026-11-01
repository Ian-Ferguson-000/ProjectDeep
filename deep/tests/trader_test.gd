extends SceneTree

## The dungeon trader: 3 commons plus sometimes 1-2 pricier higher-tier relics,
## rolled fresh per floor and per run, no consumables anywhere.

var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var state := RunState.new(); state.set_class("warrior"); state.start_new_run(null,"forest")
	var settings := RunState.trader_settings()
	var prices: Dictionary = settings.prices

	# Shape and pricing.
	var offers := state.get_merchant_offers("forest","dungeon")
	_expect(offers.size() >= 3 and offers.size() <= 5,"Trader should show 3 to 5 items, shows %d" % offers.size())
	for index in 3: _expect(String(offers[index].rarity) == "common","Slot %d should be common" % (index + 1))
	for offer in offers:
		_expect(String(offer.kind) == "item","Trader sold a %s" % offer.kind)
		_expect(int(offer.gold) == int(prices[String(offer.rarity)]),"%s priced wrong" % offer.name)
		_expect(GameBalance.item_usable_by_class(String(offer.item_id),"warrior") and not Unlocks.is_item_locked(state.campaign,String(offer.item_id)),"%s should not be on sale" % offer.item_id)
		_expect(String(offer.rules_text).to_lower() == GameBalance.get_slasher_item_rules_text(String(offer.item_id)).trim_prefix("Slasher: ").to_lower(),"%s shows the old turn-based rules" % offer.name)
	var ids := offers.map(func(o): return String(o.item_id))
	for id in ids: _expect(ids.count(id) == 1,"Trader offered %s twice" % id)

	# Potions drop in runs, so potion relics are in the pool (the trader never sells potions themselves).
	var potion_relic_seen := false
	for sample in 200:
		state.floor_seed = 77 + sample * 13
		for offer in state.get_merchant_offers("forest","dungeon"):
			_expect(String(offer.kind) != "consumable","Trader sold consumable %s" % offer.offer_id)
			if String(offer.item_id) in ["healers_brooch","menders_sachet","apothecarys_cup"]: potion_relic_seen = true
	_expect(potion_relic_seen,"Potion relics never offered although potions drop")
	state.floor_seed = 1001 + 37
	offers = state.get_merchant_offers("forest","dungeon")

	# Same floor: same stock. New floor or new run: fresh stock.
	_expect(_ids(state.get_merchant_offers("forest","dungeon")) == _ids(offers),"Stock changed while staying on the floor")
	var changed_floors := 0
	for floor_number in range(2,8):
		state.current_floor = floor_number
		if _ids(state.get_merchant_offers("forest","dungeon")) != _ids(offers): changed_floors += 1
	_expect(changed_floors >= 5,"Stock did not refresh between floors (%d of 6 changed)" % changed_floors)
	state.current_floor = 1
	var other_run := RunState.new(); other_run.set_class("warrior"); other_run.start_new_run(null,"forest"); other_run.floor_seed += 7919
	_expect(_ids(other_run.get_merchant_offers("forest","dungeon")) != _ids(offers),"A new run kept the old stock")

	# Launching the game twice must not give the same first run.
	var launch_a := RunState.new(); launch_a.set_class("warrior"); launch_a.start_new_run(null,"forest")
	var launch_b := RunState.new(); launch_b.set_class("warrior"); launch_b.start_new_run(null,"forest")
	_expect(launch_a.floor_seed != launch_b.floor_seed and _ids(launch_a.get_merchant_offers("forest","dungeon")) != _ids(launch_b.get_merchant_offers("forest","dungeon")),"Two fresh launches got the same first run")
	var c := CampaignState.new(); c.apply_post_tutorial_state("victory")
	for candidate in c.get_candidates(): c.recruit_candidate(candidate.id)
	c.launch_expedition([c.living_roster()[0].id],"forest")
	var expedition_run := RunState.new(); expedition_run.attach_campaign(c); expedition_run.active_character_id = c.living_roster()[0].id; expedition_run.start_new_run(null,"forest")
	_expect(c.expedition.floor_seed == expedition_run.floor_seed and ExpeditionState.from_dict(c.expedition.to_dict()).floor_seed == expedition_run.floor_seed,"Run seed not saved with the expedition")

	# Bonus slots: sometimes, and always above common.
	var fourth := 0; var fifth := 0
	for sample in 600:
		state.floor_seed = 1000 + sample * 31
		var stock := state.get_merchant_offers("forest","dungeon")
		if stock.size() >= 4:
			fourth += 1
			for extra in stock.slice(3): _expect(String(extra.rarity) != "common" and int(extra.gold) >= int(prices.uncommon),"Bonus slot held a cheap common")
		if stock.size() == 5: fifth += 1
	_expect(fourth > 180 and fourth < 400,"Bonus slots should appear sometimes (%d of 600)" % fourth)
	_expect(fifth > 0 and fifth < fourth,"A fifth slot should be rarer than a fourth (%d vs %d)" % [fifth,fourth])

	# Buying: expensive, one each, refreshed next floor.
	state.floor_seed = 4242; state.current_floor = 1
	var stock := state.get_merchant_offers("forest","dungeon")
	var first: Dictionary = stock[0]
	state.gold = int(first.gold) - 1
	_expect(String(state.purchase_merchant_offer("forest",String(first.offer_id),"dungeon")[0]) == "Not enough gold.","Bought without enough gold")
	state.gold = int(first.gold) + 5
	var held := state.inventory_items.size()
	state.purchase_merchant_offer("forest",String(first.offer_id),"dungeon")
	_expect(state.gold == 5 and state.inventory_items.size() == held + 1,"Purchase did not take gold and give the relic")
	_expect(bool(state.get_merchant_offers("forest","dungeon")[0].sold),"Bought slot not marked sold")
	state.gold = 9999
	_expect(String(state.purchase_merchant_offer("forest",String(first.offer_id),"dungeon")[0]) == "That offer is sold out.","Bought the same slot twice")
	state.current_floor = 2
	_expect(not state.get_merchant_offers("forest","dungeon").any(func(o): return bool(o.sold)),"Next floor's stock started sold out")
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
