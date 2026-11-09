extends SceneTree

## Visitors of merit: data, schedules, quests from accept to reward, deliveries,
## favour and ranks, shops, mini-game favour, saving, and the tavern panel.

const TAVERN := preload("res://game/tavern/2d/Tavern.tscn")
var failures: Array[String] = []

class MemoryState extends RunState:
	func autosave_on_floor_entry() -> bool: return true

func _initialize() -> void: _run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _frames(count: int) -> void:
	for i in count: await process_frame

func _company() -> CampaignState:
	var c := CampaignState.new()
	c.apply_post_tutorial_state("victory")
	for candidate in c.get_candidates(): c.recruit_candidate(candidate.id)
	TavernTour.mark_done(c)
	return c

func _run() -> void:
	root.size = Vector2i(1280,720)
	var errors := VisitorService.validate()
	_expect(errors.is_empty(),"visitors.json has errors: %s" % "; ".join(errors))
	_expect(VisitorService.ids().size() >= 4,"Expected at least four visitors")
	var c := _company()
	const MAYOR := "mayor_corvin_rook"
	const SMITH := "tessaly_vane"

	# ---- schedule
	c.calendar_day = 2
	_expect(VisitorService.is_present(c,MAYOR),"The mayor should visit on day 2")
	c.calendar_day = 3
	_expect(not VisitorService.is_present(c,MAYOR) and VisitorService.next_visit_day(c,MAYOR) == 7,"The mayor's next visit should be day 7, got %d" % VisitorService.next_visit_day(c,MAYOR))
	_expect(not VisitorService.unlocked(c,"grey_archivist"),"The Archivist shouldn't come before the forest is cleared")

	# ---- accepting needs them present
	_expect(not bool(VisitorService.accept(c,MAYOR,"roads_open").ok),"Accepted a job from someone who isn't here")
	c.calendar_day = 2
	_expect(VisitorService.quest_state(c,MAYOR,"guardian_of_the_crossroads") == "locked","A rank-gated quest should be locked")
	_expect(bool(VisitorService.accept(c,MAYOR,"roads_open").ok) and VisitorService.quest_state(c,MAYOR,"roads_open") == "active","Accepting a job failed")

	# ---- progress from run events, counted only once accepted
	VisitorService.notify(c,{"type":"floor","dungeon":"forest","floor":2})
	_expect(VisitorService.quest_state(c,MAYOR,"roads_open") == "active","Floor 2 shouldn't finish a floor 3 job")
	var finished := VisitorService.notify(c,{"type":"floor","dungeon":"forest","floor":3})
	_expect(VisitorService.quest_state(c,MAYOR,"roads_open") == "ready" and finished.size() == 1,"Reaching floor 3 didn't finish the job")
	# Rewards are collected in person.
	c.calendar_day = 3
	_expect(not bool(VisitorService.claim(c,MAYOR,"roads_open").ok),"Collected a reward from someone who isn't here")
	c.calendar_day = 7
	var gold := c.banked_gold; var renown := c.reputation
	var claim := VisitorService.claim(c,MAYOR,"roads_open")
	_expect(bool(claim.ok) and c.banked_gold == gold + 40 and c.reputation == renown + 3 and VisitorService.favour(c,MAYOR) == 3,"The reward wasn't paid: %s" % [claim])
	_expect(VisitorService.rank(c,MAYOR) == 1 and VisitorService.rank_name(c,MAYOR) == "Acquaintance","3 favour should make you an Acquaintance")
	_expect(VisitorService.quest_state(c,MAYOR,"guardian_of_the_crossroads") == "available","Rank and the earlier job should open the next quest")

	# ---- deliveries
	_expect(bool(VisitorService.accept(c,MAYOR,"refugee_rations").ok),"Couldn't accept the delivery")
	c.pantry["hearty"] = 2
	_expect(not VisitorService.can_deliver(c,MAYOR,"refugee_rations"),"Could deliver without enough food")
	c.pantry["hearty"] = 6
	var delivered := VisitorService.deliver(c,MAYOR,"refugee_rations")
	_expect(bool(delivered.ok) and int(c.pantry.hearty) == 2 and VisitorService.quest_state(c,MAYOR,"refugee_rations") == "done","Delivering food failed: %s" % [delivered])

	# ---- kills, items and flags
	c.calendar_day = 3
	_expect(VisitorService.is_present(c,SMITH),"Tessaly should visit on day 3")
	VisitorService.accept(c,SMITH,"kobold_trouble")
	for i in 14: VisitorService.notify(c,{"type":"kill","family":"bandit"})
	VisitorService.notify(c,{"type":"kill","family":"sporeling"})
	_expect(VisitorService.progress(c,SMITH,"kobold_trouble") == 14,"Kill progress miscounted")
	VisitorService.notify(c,{"type":"kill","family":"bandit"})
	_expect(VisitorService.quest_state(c,SMITH,"kobold_trouble") == "ready","15 bandit kills didn't finish the job")
	VisitorService.claim(c,SMITH,"kobold_trouble")
	VisitorService.accept(c,SMITH,"proven_blade")
	VisitorService.notify(c,{"type":"clear","dungeon":"forest","class_id":"mage"})
	_expect(VisitorService.quest_state(c,SMITH,"proven_blade") == "active","A mage clear finished a warrior-only job")
	VisitorService.notify(c,{"type":"clear","dungeon":"forest","class_id":"warrior"})
	var items_before := c.armory.size()
	VisitorService.claim(c,SMITH,"proven_blade")
	_expect(c.armory.size() == items_before + 1,"The item reward didn't reach the Armory")

	# ---- shop: rank-gated, once-only
	var offers := VisitorService.shop(c,SMITH)
	var greatsword: Dictionary = offers.filter(func(o): return String(o.offer_id) == "tessaly_greatsword")[0]
	_expect(VisitorService.rank(c,SMITH) >= 2 or bool(greatsword.locked),"A rank-locked offer isn't locked")
	c.banked_gold = 1000
	VisitorService.add_favour(c,SMITH,20)
	_expect(bool(VisitorService.buy(c,SMITH,"tessaly_greatsword").ok),"Couldn't buy an unlocked offer")
	_expect(not bool(VisitorService.buy(c,SMITH,"tessaly_greatsword").ok),"Bought a once-only offer twice")
	_expect(bool(VisitorService.buy(c,SMITH,"tessaly_medium_armor").ok) and bool(VisitorService.buy(c,SMITH,"tessaly_medium_armor").ok),"Repeatable offers should sell again")

	# ---- mini-game favour, once per visit
	var favour := VisitorService.favour(c,SMITH)
	VisitorService.record_contest(c,SMITH,"win")
	VisitorService.record_contest(c,SMITH,"win")
	_expect(VisitorService.favour(c,SMITH) == favour + 1,"Mini-game favour should count once per visit")
	c.calendar_day = 7
	_expect(VisitorService.is_present(c,SMITH) and VisitorService.can_contest(c,SMITH),"A new visit should allow another counted win")

	# ---- training and coming home feed quests
	const DOCTOR := "calden_ashwick"
	c.calendar_day = 4
	VisitorService.accept(c,DOCTOR,"well_trained")
	var member: CharacterRecord = c.living_roster()[0]
	c.banked_gold = 1000
	HearthLodging.train(c,member.id,"str")
	_expect(VisitorService.progress(c,DOCTOR,"well_trained") == 1,"Training didn't count for the quest")

	# ---- saving
	var copy := CampaignState.new(); copy._load_dict(c.to_dict())
	_expect(VisitorService.quest_state(copy,MAYOR,"roads_open") == "done" and VisitorService.favour(copy,SMITH) == VisitorService.favour(c,SMITH) and VisitorService.progress(copy,DOCTOR,"well_trained") == 1,"Visitor progress didn't survive a save")
	_expect(VisitorService.has_flag(copy,"tessaly_crypt_steel") == VisitorService.has_flag(c,"tessaly_crypt_steel"),"Flags didn't survive a save")

	# ---- the tavern: visitor on the floor, panel, accept, Quests page
	var state := MemoryState.new()
	state.campaign = _company(); state.campaign.calendar_day = 2
	state.campaign.last_presented_wave_id = state.campaign.candidate_wave_id
	var gear_list: Array[GearData] = [HearthCatalog.gear(state.campaign.living_roster()[0].gear_id)]
	var tavern = TAVERN.instantiate(); tavern.setup(null,state,gear_list,""); root.add_child(tavern)
	await _frames(6)
	var actor = tavern.activity_controller.actors.get(MAYOR)
	_expect(actor != null and actor.actor_kind == "visitor","The mayor isn't in the tavern on his day")
	tavern._on_living_actor_interaction("visitor",MAYOR); await _frames(2)
	var panel: VisitorPanel = tavern.visitor_panel
	_expect(panel.visible and panel.portrait_rect.texture != null,"Talking to the mayor didn't open his panel with a portrait")
	var accept := panel.find_child("Quest_roads_open",true,false).find_child("Accept",true,false) as Button
	_expect(accept != null,"No Accept button on an offered job")
	if accept != null:
		accept.pressed.emit(); await _frames(2)
		_expect(VisitorService.quest_state(state.campaign,MAYOR,"roads_open") == "active","Accept in the panel didn't take the job")
	(panel.find_child("Close",true,false) as Button).pressed.emit(); await _frames(2)
	_expect(not panel.visible,"Farewell didn't close the panel")
	tavern._open_hearth("Quests"); await _frames(2)
	_expect(tavern.management.section == "Quests" and tavern.management.find_child("QuestsTab",true,false) != null,"No Quests page in the Hearth")
	tavern.queue_free(); await _frames(2)

	if failures.is_empty():
		print("VISITORS_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures: printerr("FAIL: " + failure)
		quit(1)
