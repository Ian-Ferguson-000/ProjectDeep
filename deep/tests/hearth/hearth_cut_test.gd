extends SceneTree

## The tavern's cut and recruit fame (data/tavern_cut.json, HearthCut).

var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _company() -> CampaignState:
	var c := CampaignState.new()
	c.apply_post_tutorial_state("victory")
	for candidate in c.get_candidates(): c.recruit_candidate(candidate.id)
	return c

func _run() -> void:
	var rules := HearthCut.rules()
	var c := _company()
	var member: CharacterRecord = c.living_roster()[0]
	_expect(member.joined_day == c.calendar_day,"Recruits don't record the day they joined")
	# A fresh recruit: base cut plus whatever mood they arrive in, never below the minimum.
	member.morale = 60   # Settled
	var start := HearthCut.percent(c,member)
	_expect(start >= int(rules.min) and start <= int(rules.min) + 10,"A fresh recruit's cut is %d%%" % start)
	# Training raises it.
	member.training["sessions"] = 3
	_expect(HearthCut.percent(c,member) == start + 3 * int(rules.per_training_session),"Training sessions don't raise the cut")
	# Mood: content raises it, miserable lowers it.
	member.morale = 90
	var content := HearthCut.percent(c,member)
	member.morale = 10
	_expect(HearthCut.percent(c,member) < content,"Mood doesn't affect the cut")
	member.morale = 90
	# Days at the Hearth.
	c.calendar_day += 5
	_expect(HearthCut.percent(c,member) == content + 5 * int(rules.per_day_housed),"Days housed don't raise the cut")
	# A finer room and furnishings that suit them.
	var room := HearthLodging.room_of(c,member.id)
	_expect(not room.is_empty(),"The recruit has no room")
	var before_room := HearthCut.percent(c,member)
	room["quality"] = "chamber"
	var suited := ""
	for id in HearthLodging.furnishings().keys():
		if Array(HearthLodging.furnishing(String(id)).get("suits",[])).has(member.class_id): suited = String(id); break
	if not suited.is_empty(): room["furnishings"] = [suited]
	var with_room := HearthCut.percent(c,member)
	_expect(with_room >= before_room + int(Dictionary(rules.room_quality).chamber) + (int(rules.per_suited_furnishing) if not suited.is_empty() else 0),"Room quality/furnishings don't raise the cut (%d -> %d)" % [before_room,with_room])
	# Capped at the maximum.
	member.training["sessions"] = 999; c.calendar_day += 999
	_expect(HearthCut.percent(c,member) <= int(rules.max),"The cut went over the maximum")
	_expect(HearthCut.explain(c,member).contains("Training"),"The breakdown doesn't list training")
	# Splitting gold.
	var split := HearthCut.split(200,35)
	_expect(int(split.cut) == 70 and int(split.purse) == 130,"200 gold at 35%% should be 70/130, got %s" % [split])

	# ---- fame
	var unknown := CharacterRecord.new(); unknown.level = 2; unknown.attributes = {"str":10,"dex":10,"con":10,"int":10,"wis":10,"cha":10}
	var famous := CharacterRecord.from_dict(unknown.to_dict())
	HearthCut.apply_fame(unknown,"unknown",true)
	HearthCut.apply_fame(famous,"famous",true)
	_expect(famous.signing_fee > unknown.signing_fee * 3,"Famous recruits aren't much pricier (%d vs %d)" % [famous.signing_fee,unknown.signing_fee])
	_expect(int(famous.attributes.str) > int(unknown.attributes.str) and famous.level > unknown.level,"Famous recruits aren't stronger")
	var copy := CharacterRecord.from_dict(famous.to_dict())
	_expect(copy.fame == "famous" and copy.joined_day == famous.joined_day,"Fame or join day lost on save")
	# Bigger Hearths draw bigger names.
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var small := {}; var big := {}
	for i in 400:
		var a := HearthCut.roll_fame(0,rng); small[a] = int(small.get(a,0)) + 1
		var b := HearthCut.roll_fame(3,rng); big[b] = int(big.get(b,0)) + 1
	_expect(int(small.get("famous",0)) == 0 and int(big.get("famous",0)) > 40,"Fame odds don't follow the Hearth's size: %s / %s" % [small,big])
	_expect(int(small.get("unknown",0)) > int(big.get("unknown",0)),"Small Hearths should mostly draw unknowns")
	# Generated recruits carry a fame tier and a matching fee.
	var any_fame := false
	for candidate in c.get_candidates():
		_expect(HearthCut.fame_tier(candidate.adventurer.fame).has("name"),"A recruit has no fame tier")
		any_fame = true
	_expect(any_fame or c.get_candidates().is_empty(),"No recruits to check")

	if failures.is_empty():
		print("HEARTH_CUT_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures: printerr("FAIL: " + failure)
		quit(1)
