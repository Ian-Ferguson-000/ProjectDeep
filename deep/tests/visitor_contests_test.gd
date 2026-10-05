extends SceneTree

var failures:Array[String]=[]
var completions:=0
var cancellations:=0

class MemoryState extends RunState:
	var saves:=0
	func autosave_on_floor_entry()->bool:
		saves+=1;return true

func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	if not value:failures.append(message)

func make_game(id:String,attribute:int=12)->VisitorContest:
	var scene:=load("res://scenes/minigames/%s.tscn"%id) as PackedScene
	var game:=scene.instantiate() as VisitorContest
	game.setup({"visitor_name":"Brina","attribute":attribute,"learning_potential":"quick_learner","seed":417,"portrait":"res://assets/roster_portraits/warrior_0.png"})
	game.completed.connect(func(_result:Dictionary):completions+=1)
	game.cancelled.connect(func():cancellations+=1)
	root.add_child(game);game.set_process(false)
	return game

func play(game:VisitorContest)->void:
	game.start();game._process(float(VisitorContestRules.TUNING.countdown))
	check(game.phase=="playing","Countdown did not start gameplay")

func run()->void:
	root.size=Vector2i(1280,720)
	var state:=MemoryState.new();state.campaign.apply_post_tutorial_state("victory")
	var campaign:=state.campaign;var candidate:=campaign.get_candidates()[0]
	var range_cases:={4:"4–7",7:"4–7",8:"8–11",11:"8–11",12:"12–15",15:"12–15",16:"16–20",20:"16–20"}
	for value in range_cases:check(VisitorContestRules.stat_range(value)==range_cases[value],"Incorrect numeric estimate at a range boundary")
	var dossier:=RecruitmentDialogue.new()
	check(dossier._stat_display(candidate,"str")==VisitorContestRules.band(int(candidate.adventurer.attributes.str)),"Numeric estimate revealed before contest")
	var gold:=campaign.banked_gold;var day:=campaign.calendar_day;var shift:=campaign.calendar_shift;var xp:=candidate.adventurer.xp
	for id in VisitorContestRules.CONTESTS:
		var result:={"contest_id":id,"outcome":"loss","player_score":0,"visitor_score":10,"details":{}}
		check(bool(campaign.complete_candidate_contest(candidate.id,result).ok),"Contest completion failed")
		check(candidate.knowledge[VisitorContestRules.CONTESTS[id].stat]=="band","Losing did not reveal band")
		var stat:String=VisitorContestRules.CONTESTS[id].stat
		var estimate:=VisitorContestRules.stat_range(int(candidate.adventurer.attributes[stat]))
		check(candidate.last_result.contains(estimate+" (estimated)") and dossier._stat_display(candidate,stat)==estimate+" est.","Contest report/dossier did not show numeric range")
		campaign.complete_candidate_contest(candidate.id,result)
	check(candidate.contest_results.size()==4,"Latest results not bounded per contest")
	check(candidate.adventurer.learning_potential_known,"Potential not revealed")
	check(campaign.banked_gold==gold and campaign.calendar_day==day and campaign.calendar_shift==shift and candidate.adventurer.xp==xp,"Contests changed economy, time or XP")
	candidate.knowledge.str="exact"
	campaign.complete_candidate_contest(candidate.id,{"contest_id":"arm_wrestling","outcome":"draw"})
	check(candidate.knowledge.str=="exact","Contest downgraded exact appraisal")
	check(candidate.last_result.contains("%d (appraised)"%int(candidate.adventurer.attributes.str)) and dossier._stat_display(candidate,"str")==str(candidate.adventurer.attributes.str),"Contest obscured an already appraised value")
	check(not bool(campaign.complete_candidate_contest("missing",{"contest_id":"drinking","outcome":"win"}).ok),"Missing candidate accepted")
	check(not bool(campaign.complete_candidate_contest(candidate.id,{"contest_id":"bad","outcome":"win"}).ok),"Invalid contest accepted")
	var restored:=CandidateRecord.from_dict(candidate.to_dict())
	check(restored.contest_results==candidate.contest_results and restored.adventurer.learning_potential_known,"Save/load lost assessment")
	check(dossier._stat_display(restored,"int").contains("–"),"Save/load lost numeric range")
	dossier.free()
	var legacy:=candidate.adventurer.to_dict();legacy.erase("learning_potential");legacy.erase("learning_potential_known")
	var migrated:=CharacterRecord.from_dict(legacy)
	check(migrated.learning_potential=="steady" and not migrated.learning_potential_known and migrated.xp==xp,"Old-save migration changed progression")
	for tier in VisitorContestRules.LEARNING:
		check(VisitorContestRules.scale_xp(100,tier)==roundi(100*float(VisitorContestRules.LEARNING[tier])),"Tier XP multiplier incorrect")
		check(VisitorContestRules.scale_xp(1,tier)==1 and VisitorContestRules.scale_xp(0,tier)==0,"Small XP scaling incorrect")
		check(VisitorContestRules.learning_tier("visitor_21")==VisitorContestRules.learning_tier("visitor_21"),"Potential rerolled")
	var strong_arm:=make_game("arm_wrestling",20);var weak_arm:=make_game("arm_wrestling",4)
	await process_frame;play(strong_arm);play(weak_arm);strong_arm._tick_game(0.5);weak_arm._tick_game(0.5)
	check(strong_arm.pull<weak_arm.pull,"Stronger arm wrestler did not pull harder")
	strong_arm.queue_free();weak_arm.queue_free();await process_frame
	var arm:=make_game("arm_wrestling",4)
	await process_frame;await process_frame
	check(arm.panel.position.y>=0 and arm.panel.size.y<=root.size.y,"Contest layout overflowed viewport")
	play(arm)
	arm._game_key(KEY_Q);var initial:float=arm.pull;arm._game_key(KEY_Q);arm._game_key(KEY_E)
	check(is_equal_approx(arm.pull,initial),"Repeat/cooldown counted another press")
	arm.clock+=0.1;arm._game_key(KEY_E);check(arm.pull>initial,"Alternating press did not push")
	arm.elapsed=20;arm._tick_game(0);var before:=completions;arm.finish()
	check(arm.phase=="results" and arm.feedback.text.contains("4–7 (estimated)") and completions==before,"Arm finished more than once")
	play(arm);check(arm.player_score==0 and arm.last_key==0,"Arm replay did not reset")
	arm.leave();check(cancellations==1,"Cancel not emitted");arm.queue_free();await process_frame
	var memory:=make_game("memory_match",20);await process_frame;play(memory)
	for round_index in 5:
		memory._tick_game(2);check(memory.stage=="select","Memory did not hide pattern")
		for tile in memory.pattern:memory._select(tile)
		memory._submit()
		if round_index<4:memory._advance()
	check(memory.player_score==25 and memory.phase=="results" and memory.round_review.visible,"Memory scoring/round count incorrect")
	play(memory);memory._tick_game(2);memory._tick_game(8);check(memory.stage=="review","Memory timeout failed")
	memory.queue_free();await process_frame
	var reaction:=make_game("quick_draw",20);await process_frame;play(reaction)
	for i in 12:
		reaction._tick_game(1.2);reaction.stage_time=0.2;reaction._hit();reaction._hit();reaction._tick_game(0.81)
	check(reaction.phase=="results" and reaction.player_score==960 and reaction.hits==12,"Reaction duplicate hit/scoring failed")
	play(reaction);check(reaction.hits==0 and reaction.target_number==1,"Reaction replay failed")
	reaction.queue_free();await process_frame
	var drink:=make_game("drinking",20);await process_frame;play(drink)
	for i in 4:
		drink.round_time=drink._cue_time(i);drink._game_key(drink.cues[i])
	drink._tick_game(0.16)
	check(drink.survived==1 and drink.accurate==4,"Accurate drinking cues did not survive")
	drink._game_key(KEY_Q);drink._game_key(KEY_Q);drink._game_key(KEY_Q)
	check(drink.tipped,"Three incorrect presses did not tip player")
	for i in 25:
		if drink.phase=="playing":drink._tick_game(0.8)
	check(drink.phase=="results","Drinking never ended")
	play(drink);check(not drink.tipped and drink.accurate==0 and drink.visitor_cue_index==0,"Drinking replay retained state")
	drink.queue_free();await process_frame
	# Same seed creates paired samples: stronger opponents cannot perform worse.
	for id in ["memory_match","quick_draw","drinking"]:
		var weak:=make_game(id,4);var strong:=make_game(id,20);await process_frame
		play(weak);play(strong)
		for step in 400:
			for game in [weak,strong]:
				if game.phase!="playing":continue
				game._process(0.15)
				if id=="memory_match" and game.stage=="review":game._advance()
		check(strong.visitor_score>=weak.visitor_score,"Stronger %s visitor performed worse"%id)
		weak.queue_free();strong.queue_free();await process_frame
	var tavern:Node=load("res://scenes/tavern/Tavern.tscn").instantiate()
	var gear_list:Array[GearData]=[]
	tavern.setup(null,state,gear_list,"");root.add_child(tavern);await process_frame;await process_frame
	tavern.arrivals_need_sequence=false
	tavern.calendar_backdrop.hide()
	if tavern.results_backdrop.visible:tavern._close_modal(tavern.results_backdrop)
	tavern._open_candidate(candidate.id);tavern._open_visitor_contest(candidate.id,"arm_wrestling");await process_frame
	check(tavern.active_contest!=null and not tavern.recruitment_dialogue.visible and not tavern.keeper.input_enabled,"Contest did not isolate tavern")
	var contest:VisitorContest=tavern.active_contest;contest.set_process(false);play(contest)
	var event:=InputEventKey.new();event.physical_keycode=KEY_Q;event.pressed=true;event.echo=true;contest._input(event)
	check(contest.last_key==0,"Keyboard auto-repeat counted")
	var saves:=state.saves;contest.player_score=1;contest.finish()
	check(state.saves==saves+1,"Completion did not persist immediately")
	tavern._close_top_modal();await process_frame
	check(tavern.active_contest==null and tavern.recruitment_dialogue.visible and tavern.recruitment_dialogue.candidate_id==candidate.id and not tavern.keeper.input_enabled,"Return did not restore same visitor/modal pause")
	tavern.recruitment_dialogue.close();check(tavern.keeper.input_enabled,"Keeper did not resume after closing recruitment")
	var other:=campaign.get_candidates()[1]
	tavern._open_candidate(other.id);tavern.recruitment_dialogue.compete_button.pressed.emit()
	check(tavern.recruitment_dialogue.contest_choices.visible,"Compete did not open chooser")
	var choices:Array[Node]=tavern.recruitment_dialogue.contest_choices.get_children()
	var index:=0
	for id in VisitorContestRules.CONTESTS:
		choices[index].pressed.emit();await process_frame
		check(tavern.active_contest!=null and tavern.active_contest.contest_id==id,"Chooser opened wrong scene")
		var cancel_saves:=state.saves
		tavern.active_contest.leave();await process_frame
		check(state.saves==cancel_saves and other.contest_results.is_empty() and not other.adventurer.learning_potential_known,"Cancelled attempt saved/revealed knowledge")
		index+=1
	tavern.queue_free();await process_frame
	# Manual and automated XP both apply the same tier exactly once.
	campaign.recruit_candidate(candidate.id);var member:=campaign.character(candidate.id);member.learning_potential="quick_learner"
	state.active_character_id=member.id;state._load_character_profile(member);state.set_class(member.class_id)
	var profile_xp:int=state.hero_profiles[member.id].xp;state.gain_xp(1000,"test")
	check(state.hero_profiles[member.id].xp==profile_xp+1150 and state.get_level()>member.level,"Manual XP scaling/level-ups failed")
	var auto:=MemoryState.new();auto.campaign.apply_post_tutorial_state("victory")
	for arrival in auto.campaign.get_candidates():auto.campaign.recruit_candidate(arrival.id)
	var veteran:=auto.campaign.living_roster()[0];veteran.learning_potential="quick_learner";var auto_xp:=veteran.xp
	auto.campaign.begin_expedition([veteran.id],"forest")
	var expedition:=auto.campaign.expedition;expedition.deployment_type="automated";expedition.floor=10
	HearthExpeditions.settle(auto.campaign,expedition,"victory",{})
	check(veteran.xp==auto_xp+575 and int(veteran.progression.total_xp)>=veteran.xp,"Automated XP scaling/totals failed")
	if failures.is_empty():print("VISITOR_CONTESTS_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)

