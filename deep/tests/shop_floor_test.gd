extends SceneTree
## Shop rooms: the trader stands back at a stall, every offer lies on the floor;
## standing on one shows its name, price and effect, and E buys it.
const FOREST := preload("res://scenes/forest3d/Forest3D.tscn")
const CRYPT := preload("res://scenes/crypt3d/Crypt3D.tscn")
class MemoryCampaign extends CampaignState:
	func save_atomic() -> bool: return true
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func expect(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error(message)
func _run() -> void:
	root.size = Vector2i(1600,1000)
	for pair in [[FOREST,"forest"],[CRYPT,"crypt"]]: await _check(pair[0],pair[1])
	if failures.is_empty(): print("SHOP_FLOOR_TEST: PASS")
	quit(1 if not failures.is_empty() else 0)

func _check(packed: PackedScene, dungeon: String) -> void:
	var scene = packed.instantiate()
	scene._ensure_designer_controls()
	var state := RunState.new()
	state.campaign = MemoryCampaign.new()
	state.requested_seed = 13579
	state.start_new_run(GearData.create("shop_test","Shop",3,false,0,"","","warrior"),dungeon)
	state.starter_reward_claimed = true
	scene.run_state = state
	root.add_child(scene)
	for i in 6: await process_frame
	var shop_id := -1
	for record in state.field_run.rooms:
		if String(record.role) == "shop": shop_id = int(record.id)
	expect(shop_id >= 0,"%s: no shop room on the floor" % dungeon)
	state.field_run["current_room"] = shop_id
	scene._build_floor()
	for i in 6: await process_frame
	var offers: Array = state.get_merchant_offers(scene._dungeon_merchant_id(),"dungeon")
	expect(scene.shop_offer_nodes.size() == offers.size(),"%s: %d wares on the floor for %d offers" % [dungeon,scene.shop_offer_nodes.size(),offers.size()])
	var cells := {}
	for area in scene.shop_offer_nodes:
		var cell: Vector2i = Vector2i(((area.position - scene.ORIGIN) / scene.TILE).floor())
		expect(not cells.has(cell),"%s: two wares share a cell" % dungeon); cells[cell] = true
		expect(Dictionary(scene.layout.cells).has(cell),"%s: a ware sits off the floor" % dungeon)
		expect(area.global_position.distance_to(scene.merchant_position) > 90.0,"%s: a ware sits on the trader" % dungeon)
	# The 3D room gives each ware a plinth.
	var stands := 0
	for model in scene.world_3d.actors.values(): if model.name.begins_with("Ware"): stands += 1
	expect(stands == offers.size(),"%s: %d plinths for %d wares" % [dungeon,stands,offers.size()])
	# Stand on the first item: the tag shows name, price and effect.
	var area: Area2D = scene.shop_offer_nodes[0]
	var offer: Dictionary = offers[0]
	scene.player.set_physics_process(false)
	scene.player.global_position = area.global_position
	state.gold = 0
	for i in 3: await process_frame
	expect(scene.shop_tag != null and scene.shop_tag.visible,"%s: standing on a ware shows nothing" % dungeon)
	if scene.shop_tag != null:
		var text: String = scene._shop_tag_label.get_parsed_text()
		expect(text.contains(String(offer.name)) and text.contains("%d¢" % int(offer.gold)),"%s: the tag lacks name or price: %s" % [dungeon,text])
		expect(text.contains(scene.offer_effect_text(offer).left(20)),"%s: the tag lacks the effect: %s" % [dungeon,text])
		expect(text.contains("more coin"),"%s: a broke player is not told the shortfall" % dungeon)
	# With the coins, E buys it and the ware leaves the floor.
	state.gold = 99
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	for i in 3: await process_frame
	expect(state.gold == 99 - int(offer.gold),"%s: buying did not take the price (%d left)" % [dungeon,state.gold])
	expect(not is_instance_valid(area) or area.is_queued_for_deletion(),"%s: the bought ware stayed on the floor" % dungeon)
	expect(not scene.shop_tag.visible,"%s: the tag stayed up after buying" % dungeon)
	# Walking off: no tag.
	scene.player.global_position = scene.merchant_position + Vector2(0,200)
	for i in 3: await process_frame
	expect(not scene.shop_tag.visible,"%s: the tag stays up off the wares" % dungeon)
	scene.queue_free()
	for i in 3: await process_frame
