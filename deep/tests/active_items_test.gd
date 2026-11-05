extends SceneTree

## Active items: the slot, charging, treasure-room pedestals, swapping, and what
## each warrior item does.

const FOREST := preload("res://scenes/slasher/SlasherForest.tscn")
const ACTIVE_ITEM_VFX := preload("res://scripts/slasher/slasher_active_item_vfx.gd")
const FIGHTER_ACTIVE_IDS := ["eldritch_bowstaff","demon_blade","storm_trident","valkyrian_sling","dragonbone_dagger","archon_crossbow","divine_hammer","grim_reaver","sentinel_shield","umbral_bow"]
const MAGE_ACTIVE_IDS := ["michaels_orb","gulthias_staff","skyblinder_staff","dragonstaff_of_ahghairon","jade_serpent_staff","arachne_staff","tome_of_toth","shangos_shatterer","solar_scepter","drumamus_bargain"]
const NEUTRAL_ACTIVE_IDS := ["siren_song_lyre","witherbloom_brooche","white_dragon_mask","black_titan_crown","dissonant_whisper_jar","mahoragan_adaption_wheel","pandoras_paradoxical_compass","vibranium_tattoo","shadowfell_brand","blood_ruby_gem","abyssal_sapphire_gem","feywild_shawl","bramble_vine_snare","heartbreaker_amulet","war_horn_of_valor"]
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _frames(count: int) -> void:
	for i in count: await process_frame

func _dummy(scene, offset: Vector2) -> SlasherEnemy:
	var foe: SlasherEnemy = scene._spawn_enemy(scene.player.global_position + offset,"bandit_cutthroat","bandit_cutthroat")
	foe.activation_delay = 999.0
	return foe

func _run() -> void:
	var game_settings:Node=root.get_node("GameSettings");game_settings.values["dev_mode"]=false
	# ---- data
	var warrior := ActiveItems.ids_for_class("warrior")
	_expect(warrior.size() >= 15,"Expected the five base and ten fighter weapon active items")
	for id in warrior:
		var record := ActiveItems.item(id)
		_expect(String(record.get("charge","")) in ["rooms","timer"],"%s has no charge type" % id)
		_expect(not String(record.get("name","")).is_empty() and not String(record.get("description","")).is_empty(),"%s lacks a name or description" % id)
		_expect(DungeonHud.item_icon(String(record.get("icon",""))) != null,"%s has no icon" % id)
	for id in FIGHTER_ACTIVE_IDS:
		_expect(warrior.has(id) and String(ActiveItems.item(id).get("effect",{}).get("kind",""))=="fighter_weapon","%s is not in the active fighter weapon pool"%id)
	var mage:=ActiveItems.ids_for_class("mage")
	for id in MAGE_ACTIVE_IDS:
		_expect(mage.has(id) and String(ActiveItems.item(id).get("effect",{}).get("kind",""))=="mage_item","%s is not in the active Mage item pool"%id)
	for id in NEUTRAL_ACTIVE_IDS:
		_expect(warrior.has(id) and mage.has(id) and String(ActiveItems.item(id).get("effect",{}).get("kind",""))=="neutral_item","%s is not available to every class"%id)
	# Every authored item has its own imported pixel-art source. This catches a
	# misspelled id/path before a pickup silently falls back to a generic glyph.
	var authored_ids:=FIGHTER_ACTIVE_IDS+MAGE_ACTIVE_IDS+NEUTRAL_ACTIVE_IDS
	var icon_paths:Dictionary={}
	var animation_motifs:Dictionary={}
	for id in authored_ids:
		var texture:=SlasherActiveEffects.icon_texture(id)
		_expect(texture!=null,"%s has no unique active-item pixel art"%id)
		if texture!=null:
			_expect(texture.get_width()<=128 and texture.get_height()<=128,"%s icon is larger than the 128px source budget"%id)
			var path:=texture.resource_path
			_expect(not icon_paths.has(path),"%s reuses another authored item's icon"%id)
			icon_paths[path]=id
		_expect(ACTIVE_ITEM_VFX.LOOKS.has(id),"%s has no authored activation animation"%id)
		if ACTIVE_ITEM_VFX.LOOKS.has(id):
			var motif:=String(ACTIVE_ITEM_VFX.LOOKS[id][0])
			_expect(not animation_motifs.has(motif),"%s reuses the %s activation motif"%[id,motif])
			animation_motifs[motif]=id

	# ---- slot rules
	var state := RunState.new()
	state.start_new_run(GearData.create("t","Tester",3,false,0,"","","warrior"),"forest")
	_expect(ActiveItems.held(state).is_empty(),"A new run starts with an active item")
	_expect(ActiveItems.give(state,"whirlwind") == "" and ActiveItems.is_ready(state),"Picking up an item doesn't fill its charge")
	ActiveItems.spend(state)
	_expect(not ActiveItems.is_ready(state),"Spent item is still ready")
	ActiveItems.add_room_charge(state); _expect(not ActiveItems.is_ready(state),"Two-room item ready after one room")
	ActiveItems.add_room_charge(state); _expect(ActiveItems.is_ready(state),"Two-room item not ready after two rooms")
	_expect(ActiveItems.give(state,"shadow_step") == "whirlwind","Swapping didn't hand back the old item")
	ActiveItems.spend(state); ActiveItems.add_room_charge(state,5)
	_expect(not ActiveItems.is_ready(state),"Room clears charged a timer item")
	ActiveItems.tick(state,10.0); _expect(ActiveItems.is_ready(state),"Timer item didn't recharge over time")
	_expect(Dictionary(state.run_stats().get("active_item",{})).get("id","") == "shadow_step","The slot isn't kept in the run's stats")
	# Main-screen Dev Mode accelerates both room-pip and timed recharge without
	# changing either item's authored maximum charge.
	game_settings.values["dev_mode"]=true
	ActiveItems.give(state,"whirlwind");ActiveItems.spend(state);ActiveItems.add_room_charge(state)
	_expect(ActiveItems.is_ready(state),"Dev Mode did not accelerate room-based active-item recharge")
	ActiveItems.give(state,"shadow_step");ActiveItems.spend(state);ActiveItems.tick(state,0.7)
	_expect(ActiveItems.is_ready(state),"Dev Mode did not accelerate timed active-item recharge by 5×")
	game_settings.values["dev_mode"]=false

	# ---- in a run
	state = RunState.new()
	state.start_new_run(GearData.create("t","Tester",3,false,0,"","","warrior"),"forest")
	var scene = FOREST.instantiate(); scene._ensure_designer_controls(); scene.run_state = state; root.add_child(scene)
	await _frames(4)
	for node in root.find_children("*","",true,false):
		if node.get_script() and String(node.get_script().resource_path).contains("relic_choice_modal"): node.call("finish")
	paused = false
	scene.player.invulnerable = 9999.0
	var slot: Control = scene.dungeon_hud.active_slot
	_expect(slot != null and slot.item_id == "" and slot.position.x < 60.0 and slot.position.y > root.get_visible_rect().size.y * 0.7,"The empty active slot isn't in the bottom-left corner")
	_expect(not scene.use_active_item(),"Space with an empty slot did something")
	# First treasure room of the run: an active item on the pedestal.
	var treasure := -1
	for value in state.field_run.rooms:
		if String(value.role) == "treasure": treasure = int(value.id)
	# Walk in through a door, as in play (arriving nowhere drops you on the pedestal).
	var neighbors: Dictionary = Dictionary(state.get_field_room(treasure).get("neighbors",{}))
	var door: String = String(neighbors.keys()[0])
	state.field_run["current_room"] = treasure; state.field_run["previous_room"] = int(neighbors[door]); state.field_run["arrival_direction"] = door
	scene._build_floor(); await _frames(2)
	_expect(is_instance_valid(scene.active_pedestal) and not String(scene.active_pedestal.item_id).is_empty(),"The first treasure room has no active item")
	_expect(scene.treasure_area == null,"The active item room also has a relic chest")
	if is_instance_valid(scene.active_pedestal):
		var offered := String(scene.active_pedestal.item_id)
		scene.player.global_position = scene.active_pedestal.global_position
		scene._pedestal_armed = true
		scene._check_active_pedestal()
		_expect(ActiveItems.held(state) == offered,"Walking onto the pedestal with an empty slot didn't pick it up")
		_expect(String(scene.active_pedestal.item_id).is_empty(),"The pedestal still shows the taken item")
		scene._refresh_active_hud()
		slot = scene.dungeon_hud.active_slot
		_expect(slot.item_id == offered and slot.is_ready(),"The HUD slot doesn't show the new, charged item")
		# Swap: the old item is left behind.
		scene.active_pedestal.item_id = "iron_skin"
		ActiveItems.give(state,"whirlwind")
		_expect(scene.take_active_item() == "whirlwind" and ActiveItems.held(state) == "iron_skin" and scene.active_pedestal.item_id == "whirlwind","Swapping didn't leave the old item on the pedestal")
		_expect(String(Dictionary(scene.room.slasher).get("active_pedestal","")) == "whirlwind","The swapped item isn't remembered by the room")

	# ---- the items
	scene.player.aim_direction = Vector2.RIGHT
	ActiveItems.give(state,"whirlwind")
	var near := _dummy(scene,Vector2(80,0)); var far := _dummy(scene,Vector2(400,0))
	var near_health := near.health; var far_health := far.health
	_expect(scene.use_active_item(),"Whirlwind didn't fire")
	_expect(near.health < near_health and far.health == far_health,"Whirlwind didn't hit only what was close")
	_expect(not ActiveItems.is_ready(state) and not scene.use_active_item(),"Whirlwind could be used again straight away")
	scene._mark_room_cleared(true); scene._mark_room_cleared(true)
	_expect(ActiveItems.is_ready(state),"Clearing two rooms didn't recharge Whirlwind")
	near.queue_free(); far.queue_free(); await _frames(1)

	ActiveItems.give(state,"earthsplitter")
	var ahead := _dummy(scene,Vector2(220,0)); var beside := _dummy(scene,Vector2(0,160))
	var ahead_health := ahead.health; var beside_health := beside.health
	scene.player.aim_direction = Vector2.RIGHT
	scene.use_active_item()
	_expect(ahead.health < ahead_health and beside.health == beside_health,"Earthsplitter didn't hit only along its line")
	ahead.queue_free(); beside.queue_free(); await _frames(1)

	ActiveItems.give(state,"war_horn")
	var plain: int = int(scene.player._attack_data(10,"physical").damage)
	scene.use_active_item()
	_expect(int(scene.player._attack_data(10,"physical").damage) > plain and scene.player.active_buff_time > 0.0,"War Horn didn't strengthen attacks")

	ActiveItems.give(state,"iron_skin")
	scene.use_active_item()
	_expect(scene.player.kit_buffs.ward_amount() >= 8,"Iron Skin gave no ward")

	# Every authored fighter weapon executes from the same active slot and keeps
	# a room-local runtime for its persistent mechanics.
	for id in FIGHTER_ACTIVE_IDS:
		ActiveItems.give(state,id)
		scene.player.aim_direction=Vector2.RIGHT
		var victim:=_dummy(scene,Vector2(90,0))
		var victim_health:int=victim.health
		_expect(scene.use_active_item(),"%s did not activate from the active-item slot"%id)
		_expect(scene.player.get_children().any(func(child):return child.get_meta("fighter_active_weapon_id","")==id),"%s created no persistent combat runtime"%id)
		var runtime:Node=null
		for child in scene.player.get_children():
			if child.get_meta("fighter_active_weapon_id","")==id:runtime=child;break
		if runtime!=null:
			_expect(String(scene.player.sprite.animation).begins_with("slash_"),"%s active slot played the conflicting generic special crescent"%id)
			_expect(absf(scene.player.animation_lock-runtime.presentation_action_duration(0.3))<0.001,"%s active-slot pose duration differs from its attack clock"%id)
			ActiveItems.give(state,id)
			_expect(not scene.use_active_item() and ActiveItems.is_ready(state),"%s rejected repeat activation consumed its active-item charge"%id)
			runtime.set_physics_process(false)
			# Keep deterministic time while using the real dungeon activation,
			# cooldown, ownership, room physics, and enemy damage paths.
			if id=="storm_trident":runtime.trident.destination=victim.global_position
			for step in 240:runtime._physics_process(1.0/120)
			_expect(victim.health<victim_health,"%s activated but dealt no damage through the dungeon path"%id)
			runtime.on_unequipped()
		victim.queue_free();await _frames(1)
	# Real room rebuild destroys room-owned projectiles/summons and the player
	# node, but must not let a committed frenzy shed its damage penalty.
	scene.player.activate_fighter_frenzy(4,1.45,1.45,2)
	var previous_player:WeakRef=weakref(scene.player)
	scene._build_floor();await _frames(2)
	_expect(previous_player.get_ref()==null,"Room rebuild retained its old combat player")
	_expect(scene.player.fighter_frenzy_left>0 and scene.player.fighter_frenzy_incoming==2,"Room transition erased Demon frenzy commitment")
	scene.player.invulnerable=0;scene.player.health=1000;scene.player.max_health=1000
	scene.player.receive_damage(10,Vector2.ZERO)
	_expect(scene.player.health==980,"Restored room frenzy failed to double actual incoming damage")
	scene.player.invulnerable=9999
	# Elite/boss world drops are acquired immediately, fully charged, replacing
	# whatever was held just like a treasure pedestal pickup.
	# Find deterministic successful rolls without changing authored drop rates.
	# Then kill real scene enemies, proving defeated -> drop roll -> world loot.
	for boss_drop in [false,true]:
		for expected_id in FIGHTER_ACTIVE_IDS:
			var winning_seed:=-1
			var probe:=RandomNumberGenerator.new()
			for candidate_seed in 10000:
				probe.seed=candidate_seed
				if scene.roll_class_active_item("warrior",not boss_drop,boss_drop,probe)==expected_id:
					winning_seed=candidate_seed;break
			_expect(winning_seed>=0,"No authored drop roll can select "+expected_id)
			if winning_seed<0:continue
			var drop_victim:=_dummy(scene,Vector2(120,0))
			drop_victim.elite=not boss_drop;drop_victim.boss=boss_drop;drop_victim.health=1
			scene.enemies_remaining=maxi(2,scene.enemies_remaining)
			var loot_before:int=scene.loot_nodes.size()
			scene.drop_rng().seed=winning_seed
			drop_victim.receive_attack({"damage":100000,"damage_type":"physical"},scene.player)
			var actual_drop:Area2D=null
			for index in range(loot_before,scene.loot_nodes.size()):
				var candidate:Area2D=scene.loot_nodes[index]
				if candidate.get_meta("kind","")=="active_item" and candidate.get_meta("item_id","")==expected_id:actual_drop=candidate
			_expect(drop_victim.dead and actual_drop!=null,"Real %s death did not drop %s"%["boss" if boss_drop else "elite",expected_id])
			if actual_drop!=null:
				scene._collect_loot(actual_drop)
				_expect(ActiveItems.held(state)==expected_id and ActiveItems.is_ready(state),"Enemy-dropped fighter item was not usable: "+expected_id)
	ActiveItems.give(state,"umbral_bow")
	scene._spawn_fighter_active_drop(scene.player.global_position,"grim_reaver")
	var dropped:Area2D=scene.loot_nodes.back();scene._collect_loot(dropped)
	_expect(ActiveItems.held(state)=="grim_reaver" and ActiveItems.is_ready(state),"Fighter world drop did not enter the charged active slot")
	_expect(scene.loot_nodes.any(func(node):return is_instance_valid(node) and node!=dropped and node.get_meta("kind","")=="active_item" and node.get_meta("item_id","")=="umbral_bow"),"Replacing a dropped active item did not leave the old one behind")
	# Dev Mode enemy drops pause play and present three cards. Choosing one
	# equips it fully charged, while the replaced item remains an exact pickup.
	game_settings.values["dev_mode"]=true
	ActiveItems.give(state,"sentinel_shield")
	var dev_boss:=_dummy(scene,Vector2(140,0));dev_boss.boss=true;dev_boss.health=1
	scene.enemies_remaining=maxi(2,scene.enemies_remaining)
	var dev_loot_before:int=scene.loot_nodes.size()
	dev_boss.receive_attack({"damage":100000,"damage_type":"physical"},scene.player)
	var dev_boss_drop:Area2D=null
	for index in range(dev_loot_before,scene.loot_nodes.size()):
		if scene.loot_nodes[index].get_meta("kind","")=="active_item":dev_boss_drop=scene.loot_nodes[index]
	_expect(dev_boss_drop!=null,"Dev boss death produced no active-item drop")
	if dev_boss_drop!=null:
		_expect(Array(dev_boss_drop.get_meta("choices",[])).size()==3,"Dev boss death did not author three drop choices")
		scene._collect_loot(dev_boss_drop)
		_expect(scene.relic_modal.visible and scene.relic_modal.choice_buttons.size()==3,"Actual Dev boss loot did not open three selection cards")
		if not scene.relic_modal.active_item_choices.is_empty():
			var dev_boss_choice:String=scene.relic_modal.active_item_choices[0];scene._claim_relic(dev_boss_choice)
			_expect(ActiveItems.held(state)==dev_boss_choice and ActiveItems.is_ready(state),"Actual Dev boss choice did not equip a charged item")
	ActiveItems.give(state,"sentinel_shield")
	# Even a drop without precomputed choice metadata must expand on pickup.
	scene._spawn_active_item_drop(scene.player.global_position,"demon_blade")
	var dev_drop:Area2D=scene.loot_nodes.back();scene._collect_loot(dev_drop)
	_expect(scene.relic_modal.visible and scene.relic_modal.active_item_mode and scene.relic_modal.choice_buttons.size()==3,"Dev active-item drop did not open a three-item choice")
	_expect(ActiveItems.held(state)=="sentinel_shield","Dev item choice replaced the held item before a selection")
	var selected_dev_item:String=scene.relic_modal.active_item_choices[1];scene._claim_relic(selected_dev_item)
	_expect(ActiveItems.held(state)==selected_dev_item and ActiveItems.is_ready(state) and not scene.relic_modal.visible,"Selecting a Dev drop choice did not equip and charge it")
	_expect(scene.loot_nodes.any(func(node):return is_instance_valid(node) and node.get_meta("item_id","")=="sentinel_shield" and bool(node.get_meta("exact_active_item",false))),"The item swapped out from a Dev choice was not marked as an exact pickup")
	game_settings.values["dev_mode"]=false

	ActiveItems.give(state,"shadow_step")
	scene.player.invulnerable = 0.0
	var start: Vector2 = scene.player.global_position
	# Room-rebuild coverage above can leave the hero at an entrance wall.
	# Test movement along an observed clear lane, not through that wall.
	var dash_direction:=Vector2.ZERO
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		scene.player.aim_direction=direction
		if scene.player._safe_destination(start+direction*190).distance_to(start)>150:
			dash_direction=direction;break
	_expect(dash_direction!=Vector2.ZERO,"Shadow Step fixture has no clear movement lane")
	scene.player.velocity = dash_direction * 200.0
	scene.use_active_item()
	_expect(scene.player.invulnerable > 0.0,"Shadow Step didn't make the hero untouchable")
	for frame in 20:await physics_frame
	_expect(scene.player.global_position.distance_to(start) > 60.0,"Shadow Step didn't move the hero")

	scene.queue_free(); await _frames(3)
	if failures.is_empty(): print("ACTIVE_ITEMS_TESTS_PASSED"); quit(0)
	else:
		for failure in failures: printerr("FAIL: " + failure)
		quit(1)
