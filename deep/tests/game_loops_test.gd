extends SceneTree

## Unlocks, the bounty board, enemy drops and the guardian choice screen.

const FOREST_SCRIPT := preload("res://scripts/slasher/slasher_forest.gd")

var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _company() -> CampaignState:
	var c := CampaignState.new(); c.apply_post_tutorial_state("victory")
	for candidate in c.get_candidates(): c.recruit_candidate(candidate.id)
	return c

func _run() -> void:
	_expect(Unlocks.validate().is_empty(),"Unlock data invalid: %s" % "; ".join(Unlocks.validate()))

	# Drops: low to begin with, raised by luck, capped, none from bosses.
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var hits := 0
	for i in 20000: if FOREST_SCRIPT.roll_drop("wolf_vanguard",false,false,1.0,rng) != "": hits += 1
	var base_rate := hits / 20000.0
	_expect(base_rate > 0.15 and base_rate < 0.30,"Base drop rate should be low (~22%%), got %.3f" % base_rate)
	hits = 0
	for i in 20000: if FOREST_SCRIPT.roll_drop("wolf_vanguard",false,false,1.5,rng) != "": hits += 1
	_expect(hits / 20000.0 > base_rate * 1.25,"Drop luck did not raise drops")
	hits = 0
	for i in 5000: if FOREST_SCRIPT.roll_drop("sporeling",false,false,1.0,rng) != "": hits += 1
	_expect(hits / 5000.0 < base_rate * 0.6,"Sporelings should drop less often")
	var relics := 0
	for i in 20000: if FOREST_SCRIPT.roll_drop("wolf_vanguard",false,false,1.0,rng) == "relic": relics += 1
	_expect(relics > 20 and relics < 160,"Relic drops should be rare (%d in 20000)" % relics)
	_expect(FOREST_SCRIPT.roll_drop("wolfmaster",false,true,10.0,rng) == "","Bosses should not roll enemy drops")

	# Locked items stay out of chests until their unlock is earned.
	var c := _company()
	var hero: CharacterRecord = c.living_roster()[0]
	_expect(Unlocks.is_item_locked(c,"bursting_spore_sac") and not Unlocks.is_item_locked(c,"windrunner_boots"),"Unlock item locks wrong")
	var state := RunState.new(); state.attach_campaign(c)
	_expect(bool(c.launch_expedition([hero.id],"forest").ok),"Expedition did not launch")
	state.active_character_id = hero.id; state.start_new_run(null,"forest")
	var offered := {}
	for chest in 200:
		for item_id in state.generate_slasher_chest_choices(1 + chest % 6,"c%d" % chest): offered[item_id] = true
	for locked in ["bursting_spore_sac","tempest_brand","thunderheart_amulet","emberwind_edge"]: _expect(not offered.has(locked),"%s was offered while locked" % locked)

	# Kill goals unlock mid-run.
	var earned: Array = []
	for i in 29: earned.append_array(state.note_kill("sporeling"))
	_expect(earned.is_empty(),"Spore Harvest unlocked too early")
	earned = state.note_kill("sporeling")
	_expect(earned.size() == 1 and String(earned[0].id) == "spore_harvest","30th sporeling did not unlock Spore Harvest")
	_expect(not Unlocks.is_item_locked(c,"bursting_spore_sac"),"Bursting Spore Sac still locked")
	_expect(Array(state.run_stats().get("unlocked",[])).has("Spore Harvest"),"Unlock not noted for the run")
	for i in 25: state.note_kill("bandit_cutthroat")
	_expect(is_equal_approx(Unlocks.drop_luck(c),1.15),"Bandit Hunter should add 15%% drop luck (%.2f)" % Unlocks.drop_luck(c))

	# Clear goals: class, speed, no potions, holding an item.
	state.add_inventory_item("emberwind_edge",1)
	state.tick_run_clock(600.0)
	var logs := state.record_active_dungeon_completion()
	for id in ["forest_guardian","swift_forest","no_potions","ember_mastery"]: _expect(Unlocks.is_earned(c,id),"%s not earned on a fast, potion-free clear with Emberwind" % id)
	_expect(Unlocks.is_earned(c,"%s_clear" % hero.class_id) == (hero.class_id in ["mage","warrior"]),"Class clear unlock wrong for %s" % hero.class_id)
	_expect(logs.any(func(line): return String(line).begins_with("Unlocked: Through the Thicket")),"Clear log missing the unlock")
	var stats := state.run_stats()
	_expect(Array(stats.clears).size() == 1 and int(stats.clears[0].potions) == 0,"Clear not recorded in run stats")

	# Bounties: posted, progress, paid on return, expire.
	c.bounties = {}
	BountyBoard.refresh(c)
	_expect(BountyBoard.offers(c).size() == 2,"Board should post two bounties")
	for bounty in BountyBoard.offers(c): _expect(not String(bounty.text).contains("{"),"Bounty text not filled: %s" % bounty.text)
	c.bounties.offers = [
		{"uid":90,"template":"cull_sporelings","text":"Cull 12 Sporelings","goal":{"type":"kills","family":"sporeling","count":12},"reward":{"gold":40},"posted_day":c.calendar_day,"expires_day":c.calendar_day + 2},
		{"uid":91,"template":"class_clear","text":"Clear as a Healer","goal":{"type":"clear_class","dungeon":"forest","class":"healer"},"reward":{"gold":50},"posted_day":c.calendar_day,"expires_day":c.calendar_day + 2},
	]
	_expect(bool(BountyBoard.progress(c.bounties.offers[0],stats).done) and not bool(BountyBoard.progress(c.bounties.offers[1],stats).done),"Bounty progress wrong")
	var bank_before := c.banked_gold
	var done := BountyBoard.settle(c,stats,"death",0)
	_expect(done.is_empty(),"Bounties paid out on a death")
	done = BountyBoard.settle(c,stats,"victory",0)
	_expect(done.size() == 1 and c.banked_gold == bank_before + 40 and int(c.lifetime_stats.bounties) == 1,"Bounty not paid on return")
	_expect(BountyBoard.offers(c).size() == 1,"Completed bounty not taken down")
	c.calendar_day += 5; BountyBoard.refresh(c)
	_expect(not BountyBoard.offers(c).any(func(b): return int(b.uid) == 91),"Expired bounty still posted")
	c.lifetime_stats["bounties"] = 3
	Unlocks.check(c,{},{"type":"bounty"})
	_expect(BountyBoard.slots(c) == 3,"Trusted Contractor should add a bounty slot")

	# Settling an expedition pays bounties and reports unlocks.
	var c2 := _company()
	var hero2: CharacterRecord = c2.living_roster()[0]
	c2.launch_expedition([hero2.id],"forest")
	BountyBoard.refresh(c2)
	c2.bounties.offers = [{"uid":1,"template":"haul","text":"Bring home 10 gold","goal":{"type":"gold","count":10},"reward":{"renown":3},"posted_day":c2.calendar_day,"expires_day":c2.calendar_day + 2}]
	c2.expedition.carried_gold = 50
	c2.expedition.run_stats = {"unlocked":["Spore Harvest"]}
	var renown := c2.reputation
	var result: Dictionary = c2.settle_expedition(c2.expedition.expedition_id,"victory")
	var report: Dictionary = result.get("report",{})
	_expect(Array(report.get("bounties",[])).size() == 1 and c2.reputation >= renown + 3,"Settlement did not pay the bounty")
	_expect(Array(report.get("unlocks",[])).has("Spore Harvest"),"Settlement report missing unlocks")
	# Deaths count toward Lessons in Loss.
	var c3 := _company()
	c3.lifetime_stats["deaths"] = 2
	var victim: CharacterRecord = c3.living_roster()[0]
	c3.launch_expedition([victim.id],"forest")
	c3.settle_expedition(c3.expedition.expedition_id,"death")
	_expect(Unlocks.is_earned(c3,"remembered"),"Third death did not unlock Lessons in Loss")

	# Saved with the campaign.
	var restored := CampaignState.new(); restored._load_dict(c.to_dict())
	_expect(restored.unlocks_earned.size() == c.unlocks_earned.size() and int(restored.lifetime_stats.get("kills_total",0)) == int(c.lifetime_stats.kills_total),"Unlocks or lifetime stats lost on save")
	var saved := ExpeditionState.from_dict(c.expedition.to_dict())
	_expect(saved.run_stats == c.expedition.run_stats,"Run stats lost on save")

	# The guardian choice screen lists what is kept and lost.
	var screen := GuardianCrossroads.new().setup(state,"Stone Crypt",true)
	root.add_child(screen)
	await process_frame
	var texts: Array = screen.find_children("*","Label",true,false).map(func(l): return String(l.text))
	_expect(texts.has("THE GUARDIAN FALLS"),"Choice screen has no title")
	_expect(texts.has("Lost on return") and texts.has("Emberwind Edge"),"Choice screen does not show items and what happens to them")
	_expect(texts.any(func(t): return String(t).begins_with("◆ ")),"Choice screen does not list unlocks")
	_expect(screen.continue_button.text == "Continue to Stone Crypt" and not screen.continue_button.disabled,"Continue button wrong")
	_expect(paused,"The game should pause behind the choice screen")
	var chosen := []
	screen.decided.connect(func(go_on): chosen.append(go_on))
	screen.continue_button.pressed.emit()
	_expect(chosen == [true] and not paused,"Continue choice not delivered")
	await process_frame
	var closed := GuardianCrossroads.new().setup(state,"",false)
	root.add_child(closed); await process_frame
	_expect(closed.continue_button.disabled,"Continue should be disabled when the road is closed")
	closed.return_button.pressed.emit()
	await process_frame

	if failures.is_empty(): print("GAME_LOOPS_TESTS_PASSED"); quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(value: bool, message: String) -> void:
	if not value and not failures.has(message): failures.append(message)
