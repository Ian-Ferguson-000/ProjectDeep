extends SceneTree

func _initialize()->void:call_deferred("run")

func run()->void:
	for viewport_size in [Vector2i(1280,720),Vector2i(960,600)]:
		root.size=viewport_size
		root.content_scale_size=viewport_size
		for id in VisitorContestRules.CONTESTS:
			var game:VisitorContest=load("res://scenes/minigames/%s.tscn"%id).instantiate()
			game.setup({"visitor_name":"Brina Vale","portrait":"res://assets/roster_portraits/warrior_0.png","attribute":14,"learning_potential":"quick_learner","seed":413})
			root.add_child(game);await process_frame;await process_frame
			game.set_process(false)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/contest_%s_instructions_%dx%d.png"%[id,viewport_size.x,viewport_size.y])
			game.start();game._process(1.1)
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/contest_%s_countdown_%dx%d.png"%[id,viewport_size.x,viewport_size.y])
			game._process(1.9)
			if id=="quick_draw":game._tick_game(1.2)
			if id=="drinking":game._tick_game(0.5)
			await process_frame;await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/contest_%s_%dx%d.png"%[id,viewport_size.x,viewport_size.y])
			# Complete actual attempts so portraits, scores, board and outcome all agree.
			match String(id):
				"arm_wrestling":
					game.pull=-0.95;game._tick_game(0.5);game.stage_art._process(0.5)
				"memory_match":
					for round_index in 5:
						game._tick_game(2)
						for i in game.pattern.size():
							if i%2==0:game._select(game.pattern[i])
						game._submit()
						if game.phase=="playing":game._advance()
				"quick_draw":
					for i in 12:
						if game.stage=="wait":game._tick_game(1.2)
						game.stage_time=0.22;game._hit();game._tick_game(0.8)
				"drinking":
					for frame in 150:
						if game.phase=="playing":game._process(0.1)
			await create_timer(0.4).timeout
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/contest_%s_results_%dx%d.png"%[id,viewport_size.x,viewport_size.y])
			game.queue_free();await process_frame
		var campaign:=CampaignState.new();campaign.apply_post_tutorial_state("victory")
		var candidate:=campaign.get_candidates()[0]
		campaign.inspect_candidate(candidate.id,"talk")
		campaign.complete_candidate_contest(candidate.id,{"contest_id":"arm_wrestling","outcome":"loss","player_score":0,"visitor_score":1})
		var dialogue:=RecruitmentDialogue.new();root.add_child(dialogue);dialogue.open(candidate);dialogue.contest_choices.show()
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/contest_recruitment_%dx%d.png"%[viewport_size.x,viewport_size.y])
		dialogue.queue_free();await process_frame
	quit(0)
