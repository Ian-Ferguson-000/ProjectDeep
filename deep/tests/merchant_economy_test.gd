extends SceneTree

const TAVERN := preload("res://scenes/tavern/Tavern.tscn")
const FOREST := preload("res://scenes/forest/Forest.tscn")
const CRYPT := preload("res://scenes/crypt/Crypt.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	_expect(GameBalance.get_merchants().size() == 3, "expected Tavern, Forest, and Crypt merchants", failures)
	_expect(GameBalance.get_dungeons().size() == 2, "expected Forest and Crypt dungeon selector entries", failures)
	_expect(String(GameBalance.get_dungeon("crypt").get("unlock",{}).get("type","")) == "crypt_progression", "Crypt selector unlock metadata missing", failures)
	_expect(GameBalance.get_merchant_stock_for_rarity("common") == 5, "common stock quantity should be 5", failures)
	_expect(GameBalance.get_merchant_stock_for_rarity("rare") == 3, "rare stock quantity should be 3", failures)
	_expect(GameBalance.get_merchant_stock_for_rarity("legendary") == 1, "legendary stock quantity should be 1", failures)
	var state := RunState.new()
	state.gold = 100
	var purchase := state.purchase_merchant_offer("tavern", "tavern_potion", "tavern")
	_expect(purchase[0].contains("Purchased"), "tavern supply purchase failed", failures)
	state.purchase_merchant_offer("tavern", "quickstep_charm", "tavern")
	var gear := GearData.create("test", "Test Gear", 2, false, 0, "", "", "warrior", "none")
	state.start_new_run(gear, "forest")
	_expect(state.get_consumables().count("healing_potion") == 1, "tavern consumable did not transfer to next run", failures)
	_expect(_has_item(state, "quickstep_charm"), "tavern item did not transfer to next run", failures)
	for depth in range(1, 6):
		state.record_dungeon_floor_clear("forest", depth, depth == 5)
	_expect(state.is_merchant_recruited("forest"), "Forest merchant was not recruited by boss clear", failures)
	_expect(int(state.get_merchant_progress("forest").get("highest_depth", 0)) == 5, "highest Forest depth was not retained", failures)
	_expect(state.get_merchant_rank("forest") >= 3, "Forest Favor/depth rank did not advance", failures)
	for repeat in range(20): state.record_dungeon_floor_clear("forest", 5, false)
	_expect(state.get_merchant_rank("forest") == 4, "Devoted rank did not require accumulated Favor and boss completion", failures)
	var favor_before := int(state.get_merchant_progress("forest").get("available_favor", 0))
	var favor_purchase := state.purchase_merchant_offer("forest", "heartwood_crown", "tavern")
	_expect(favor_purchase[0].contains("Purchased"), "Favor-exclusive purchase failed", failures)
	_expect(int(state.get_merchant_progress("forest").get("available_favor", 0)) == favor_before - 55, "Favor was not spent independently of lifetime Favor", failures)
	_expect(state.purchase_merchant_offer("forest", "heartwood_crown", "tavern")[0].contains("already"), "Favor-exclusive reward could be purchased twice", failures)
	_expect(GameBalance.is_favor_exclusive_item("heartwood_crown"), "Favor-exclusive item was not marked outside ordinary loot", failures)
	state.gold = 100
	var dungeon_purchase := state.purchase_merchant_offer("forest", "ironroot_ring", "dungeon")
	_expect(dungeon_purchase[0].contains("Purchased"), "in-dungeon purchase failed", failures)
	_expect(_has_item(state, "ironroot_ring"), "in-dungeon item was not granted immediately", failures)

	var stock_state := RunState.new()
	stock_state.gold = 1000
	var quickstep_offer := _offer(stock_state, "tavern", "quickstep_charm", "tavern")
	_expect(int(quickstep_offer.get("stock_remaining", 0)) == 5, "common merchant item did not begin with five stock", failures)
	for purchase_index in range(5):
		_expect(stock_state.purchase_merchant_offer("tavern", "quickstep_charm", "tavern")[0].contains("Purchased"), "stocked item purchase %d failed" % purchase_index, failures)
	var sold_offer := _offer(stock_state, "tavern", "quickstep_charm", "tavern")
	_expect(bool(sold_offer.get("sold", false)) and int(sold_offer.get("stock_remaining", -1)) == 0, "depleted merchant item was not marked sold", failures)
	_expect(stock_state.purchase_merchant_offer("tavern", "quickstep_charm", "tavern")[0].contains("sold out"), "sold item could still be purchased", failures)
	var stock_panel := MerchantShopPanel.new()
	root.add_child(stock_panel)
	stock_panel.setup(stock_state, "tavern", "tavern")
	await process_frame
	var sold_button := stock_panel.find_child("QuickstepCharmBuyButton", true, false) as Button
	_expect(sold_button != null and sold_button.text == "Sold" and sold_button.disabled, "depleted shop row did not display disabled Sold button", failures)
	stock_panel.free()

	var tavern := TAVERN.instantiate()
	var gear_options: Array[GearData] = [gear]
	tavern.setup(null, state, gear_options, "Test tavern")
	root.add_child(tavern)
	await process_frame
	_expect(tavern.merchant_shop_panel != null, "Tavern shop modal did not initialize", failures)
	_expect(tavern.forest_merchant_token.visible, "recruited Forest merchant did not appear in Tavern", failures)
	tavern._open_merchant_shop("forest")
	_expect(tavern.merchant_shop_panel.visible, "Tavern merchant shop did not open", failures)
	tavern.free()

	for scene_resource in [FOREST, CRYPT]:
		var dungeon = scene_resource.instantiate()
		dungeon.setup(null, state)
		root.add_child(dungeon)
		await process_frame
		_expect(not dungeon.dungeon_merchant.is_empty(), "dungeon merchant was not placed", failures)
		_expect(dungeon.merchant_shop_panel != null, "dungeon shop modal did not initialize", failures)
		dungeon.free()

	if failures.is_empty():
		print("Merchant economy, recruitment, shop transfer, and scene validation passed.")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _has_item(state: RunState, item_id: String) -> bool:
	for entry in state.get_inventory_items():
		if String(entry.get("id", "")) == item_id:
			return true
	return false

func _offer(state: RunState, merchant_id: String, offer_id: String, location: String) -> Dictionary:
	for offer in state.get_merchant_offers(merchant_id, location):
		if String(offer.get("offer_id", "")) == offer_id: return offer
	return {}

func _expect(value: bool, failure: String, failures: Array[String]) -> void:
	if not value: failures.append(failure)
