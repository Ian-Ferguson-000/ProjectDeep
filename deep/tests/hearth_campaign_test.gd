extends SceneTree

var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func company() -> CampaignState:
	var c := CampaignState.new()
	c.apply_post_tutorial_state("victory")
	for candidate in c.get_candidates(): check(c.recruit_candidate(candidate.id).ok,"Founders could not recruit")
	return c

func run() -> void:
	var counts: Dictionary = {}
	for id in HearthCatalog.data().items:
		var item := HearthCatalog.item(id)
		counts[item.slot] = int(counts.get(item.slot,0))+1
		check(not item.sources.is_empty() and FileAccess.file_exists(item.icon),"Missing source/icon: "+id)
		check(not GameBalance.get_item(id).is_empty() and not GameBalance.get_slasher_item_effects(id).is_empty(),"Missing mode support: "+id)
	check(counts=={"weapon":24,"armor":12,"accessory":16,"relic":12},"Catalog count mismatch")
	check(HearthCatalog.data().legacy_item_audit.size()==52,"Legacy audit incomplete")
	var c := company()
	var first: CharacterRecord=c.living_roster()[0]
	var second: CharacterRecord=c.living_roster()[1]
	check(c.armory.size()==2,"Founders did not receive owned starter equipment")
	var purchase := HearthArmory.buy(c,"light_armor_0")
	check(purchase.ok,"Could not buy armor")
	var item_id: String=purchase.instance_id
	check(HearthArmory.equip(c,first.id,item_id).ok,"Could not equip armor")
	check(not HearthArmory.equip(c,second.id,item_id).ok,"Same item equipped twice")
	check(not HearthArmory.sell(c,item_id).ok,"Assigned item was sold")
	check(not HearthArmory.sell(c,first.equipment.weapon).ok,"Starter equipment was sold")
	var snapshot := c.to_dict()
	var restored := CampaignState.new()
	restored._load_dict(snapshot)
	check(restored.character(first.id).equipment.armor==item_id and restored.armory[item_id].owner==first.id,"Armory ownership lost on load")
	check(HearthArmory.unequip(c,first.id,"armor").ok and HearthArmory.sell(c,item_id).ok,"Unassign/sell failed")
	var before := c.banked_gold
	check(not HearthArmory.sell(c,item_id).ok and c.banked_gold==before,"Sale applied twice")
	var launch := c.launch_expedition([first.id,second.id], "forest")
	check(launch.ok,"Manual party failed to launch")
	check(not HearthArmory.unequip(c,first.id,"weapon").ok,"Away loadout was mutable")
	c.expedition.carried_gold=100
	c.expedition.carried_relic_essence=8
	var run_id:=c.expedition.expedition_id
	var result:=c.settle_expedition(run_id,"victory")
	check(result.ok and c.banked_gold==before+80 and c.calendar_day==1 and c.calendar_shift==1,"Net settlement/calendar mismatch")
	check(first.status=="recovering" and first.recovery_until==2,"Recovery date mismatch")
	check(c.settle_expedition(run_id,"victory").duplicate and c.banked_gold==before+80,"Settlement applied twice")
	HearthCalendar.advance(c,3,false)
	check(first.status=="available" and first.current_health==first.max_health,"Recovery did not restore readiness")
	var returning_id: String=first.equipment.weapon
	check(HearthCalendar.retire(c,first).ok and c.armory[returning_id].owner=="","Retirement did not return gear")
	var expansion:=company()
	expansion.banked_gold=2000
	expansion.relic_essence=100
	expansion.reputation=70
	expansion.record_dungeon_clear("forest")
	check(HearthFacilities.purchase(expansion,"roster_services").ok,"Expansion refused valid requirements")
	var paid_gold:=expansion.banked_gold
	check(not HearthFacilities.purchase(expansion,"roster_services").ok and expansion.banked_gold==paid_gold,"Duplicate construction charged")
	HearthCalendar.advance(expansion,3,false)
	check(expansion.establishment_tier==1 and expansion.get_roster_capacity()==10,"Expansion did not complete")
	var members:=expansion.living_roster()
	expansion.supplies=30
	for member in members: member.level=10; member.max_health=100; member.current_health=100
	var away: Array[String]=[members[0].id]
	check(HearthExpeditions.dispatch(expansion,away,"forest","cautious").ok,"Automated dispatch failed")
	check(not HearthExpeditions.dispatch(expansion,away,"forest","cautious").ok,"Same character dispatched twice")
	check(not HearthExpeditions.dispatch(expansion,[members[1].id],"crypt","balanced").ok,"Automation skipped manual unlock")
	var saved:=expansion.to_dict()
	var duplicate:=CampaignState.new()
	duplicate._load_dict(saved)
	HearthCalendar.advance(expansion,7,false)
	HearthCalendar.advance(duplicate,7,false)
	check(JSON.stringify(expansion.return_reports)==JSON.stringify(duplicate.return_reports),"Saved simulation rerolled")
	check(expansion.dispatches.is_empty(),"Resolved dispatch remained active")
	var same:=company()
	var a:=same.living_roster()[0]
	var b:=same.create_character(a.class_id)
	HearthArmory.ensure_starter(same,b)
	a.level=3; a.progression.level=3
	b.level=8; b.progression.level=8
	same.supplies=20
	check(same.launch_expedition([a.id,b.id], "forest").ok,"Same-class party failed")
	var state:=RunState.new()
	state.attach_campaign(same)
	state.start_new_run(HearthCatalog.gear(a.gear_id), "forest")
	check(state.get_level()==3,"First same-class member loaded wrong level")
	state.select_active_character(b.id)
	check(state.get_level()==8,"Second same-class member loaded wrong level")
	state.select_active_character(a.id)
	check(state.get_level()==3,"Same-class swap overwrote progression")
	var defeated:=company()
	var ids:=defeated.default_party("forest")
	defeated.launch_expedition(ids, "forest")
	defeated.settle_expedition(defeated.expedition.expedition_id,"death")
	check(defeated.memorial.size()==2 and defeated.armory.is_empty(),"Defeat did not lose equipped items")
	var ui:=preload("res://scenes/ui/hearth/Company.tscn").instantiate()
	root.add_child(ui)
	var ui_state:=RunState.new()
	ui_state.attach_campaign(expansion)
	for page in HearthManagement.SECTIONS:
		ui.open(expansion,ui_state,page)
		check(ui.body.get_child_count()>0,"Empty UI page: "+page)
	# Regression: party and policy controls rebuild the management page from
	# inside their own signals. The old synchronous free crashed Godot after a
	# return/recruit/select sequence instead of producing a recoverable script error.
	var selection_campaign:=company()
	var selection_state:=RunState.new()
	selection_state.attach_campaign(selection_campaign)
	ui.open(selection_campaign,selection_state,"Expeditions")
	var party_checks: Array[Node]=ui.body.find_children("*","CheckBox",true,false)
	check(not party_checks.is_empty(),"Expedition page did not create party selectors")
	if not party_checks.is_empty():
		var party_check:=party_checks[0] as CheckBox
		party_check.button_pressed=true
		await process_frame
		check(ui.selected_party.size()==1,"Party selection was lost during safe page refresh")
	var policy_button:Button=null
	var policy_buttons: Array[Node]=ui.body.find_children("*","Button",true,false)
	for candidate in policy_buttons:
		if (candidate as Button).text.ends_with("Bold"): policy_button=candidate as Button;break
	check(policy_button!=null,"Expedition page did not create policy controls")
	if policy_button!=null:
		policy_button.pressed.emit()
		await process_frame
		check(ui.policy=="bold","Policy selection was lost during safe page refresh")
	ui.queue_free()
	await process_frame
	if failures.is_empty(): print("HEARTH_CAMPAIGN_TESTS_PASSED")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
