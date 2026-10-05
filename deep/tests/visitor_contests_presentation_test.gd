extends SceneTree

var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	if not value:failures.append(message)

func run()->void:
	for viewport_size in [Vector2i(1280,720),Vector2i(960,600)]:
		root.size=viewport_size;root.content_scale_size=viewport_size
		for id in VisitorContestRules.CONTESTS:
			var game:VisitorContest=load("res://scenes/minigames/%s.tscn"%id).instantiate()
			game.setup({"visitor_name":"A visitor","attribute":12,"seed":413})
			root.add_child(game);await process_frame;await process_frame
			game.set_process(false);game.stage_art.set_process(false)
			check(game.panel.position.y>=0 and game.panel.size.y<=viewport_size.y,"Panel exceeds viewport: %s"%id)
			check(game.arena.size.y>=280 and game.stage_art.size==game.arena.size,"Stage does not fill arena: %s"%id)
			check(absf(game.arena.size.x/game.arena.size.y-1000.0/300.0)<0.06,"Board artwork is distorted by viewport aspect")
			game.start();game._process(1)
			check(game.countdown_art.get_index()==game.arena.get_child_count()-1,"Countdown does not cover game controls")
			game._process(2)
			if id=="drinking":
				for i in game.cues.size():
					game.round_time=game._cue_time(i)
					check(is_equal_approx(game.stage_art.drink_note_position(i).y,218),"Cue's scoring instant does not match visual strike line")
					game.round_time+=float(VisitorContestRules.TUNING.drink_window)
					check(is_equal_approx(absf(game.stage_art.drink_note_position(i).y-218),game.stage_art.drink_hit_half_height()),"Visible timing band does not match scoring tolerance")
				check(not game.cue_label.visible,"Numerical countdown still replaces timing indicator")
				game.tipped=true;game.stage_art._process(0.1)
				check(game.stage_art.mug_angles.x>0 and game.stage_art.mug_angles.x<1.25,"Mug tipping does not animate smoothly")
			elif id=="arm_wrestling":
				game.pull=0.6;game.stage_art._process(0.1)
				check(game.stage_art.shown_pull>0 and game.stage_art.shown_pull<0.6,"Arm animation does not follow pressure smoothly")
			elif id=="memory_match":
				game._tick_game(2);game._select(game.pattern[0]);game._select((game.pattern[0]+1)%16);game._submit()
				check(game.stage=="review" and game.round_review.visible,"Reveal overlay missing")
				for tile in game.tiles:check(tile.disabled,"Reveal leaves hidden/active memory inputs")
			elif id=="quick_draw":
				game._tick_game(1.2);game.stage_time=0.25;game._hit();game.stage_time=0.7
				check(is_equal_approx(game.last_reaction,0.25),"Displayed reaction changes after hit")
			game.stage_art.pulse(Vector2(500,140),"GOOD")
			check(not game.stage_art.effects.is_empty(),"Impact feedback not created")
			game.stage_art._process(0.85)
			check(game.stage_art.effects.is_empty(),"Impact animation never expires")
			game.finish();await process_frame;await process_frame
			check(game.panel.position.y>=0 and game.panel.size.y<=viewport_size.y,"Results overflow viewport: %s"%id)
			game.start();check(game.stage_art.effects.is_empty(),"Replay retains old visual effects")
			game.queue_free();await process_frame
	if failures.is_empty():print("VISITOR_CONTESTS_PRESENTATION_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)
