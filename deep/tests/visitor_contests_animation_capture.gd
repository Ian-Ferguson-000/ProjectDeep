extends SceneTree
## Deterministic animated previews use live game state and the real drawing pipeline.

func _initialize()->void:call_deferred("run")

func run()->void:
	root.size=Vector2i(960,600);root.content_scale_size=Vector2i(960,600)
	DirAccess.make_dir_recursive_absolute("res://build/contest_animation")
	var selected:=OS.get_cmdline_user_args()
	for id in VisitorContestRules.CONTESTS:
		if not selected.is_empty() and not selected.has(id):continue
		var game:VisitorContest=load("res://scenes/minigames/%s.tscn"%id).instantiate()
		game.setup({"visitor_name":"Brina Vale","portrait":"res://assets/roster_portraits/warrior_0.png","attribute":12,"learning_potential":"steady","seed":413})
		root.add_child(game);await process_frame;await process_frame
		game.set_process(false);game.stage_art.set_process(false);game.start();game._process(3)
		for frame in 60:
			game._process(1.0/15)
			match String(id):
				"arm_wrestling":
					if frame%2==0:game._game_key(KEY_Q if frame%4==0 else KEY_E)
				"memory_match":
					if game.stage=="select" and frame in [33,39,45]:game._select(game.pattern[(frame-33)/6])
					if frame==51:game._submit()
				"quick_draw":
					if game.stage=="target" and game.stage_time>0.2:game._hit()
				"drinking":
					for i in game.cues.size():
						if not game.resolved[i] and absf(game.round_time-game._cue_time(i))<0.04:
							game._game_key(game.cues[i] if i!=1 else KEY_R if game.cues[i]!=KEY_R else KEY_Q)
			if id=="drinking" and frame==40:
				game._game_key(KEY_Q);game._game_key(KEY_Q)
			game.stage_art._process(1.0/15)
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/contest_animation/%s_%03d.png"%[id,frame])
		game.queue_free();await process_frame
	quit(0)
