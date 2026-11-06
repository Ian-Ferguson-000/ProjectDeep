extends SceneTree
## Guardian arenas: the guardian is a goliath built into the north wall, the
## arena is never entered from the north, and when it falls a passage opens
## through its body to the way on, with a portal home beside it.
## Run with `-- --capture` (not headless) for build/visual_checks/guardian_*.png.
const SCENES := {"forest":preload("res://scenes/forest3d/Forest3D.tscn"),"crypt":preload("res://scenes/crypt3d/Crypt3D.tscn")}
class MemoryCampaign extends CampaignState:
	func save_atomic() -> bool: return true
class FakeMain extends Node:
	var guardian_choice := ""
	var completed := 0
	var onward := true
	func can_press_on() -> bool: return onward
	func complete_slasher_dungeon_floor() -> void: completed += 1
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)

func _run() -> void:
	root.size = Vector2i(1600,1000)
	# Never in from the north, over many floors.
	for seed_value in 400:
		var run := FieldDungeonGenerator.generate(seed_value * 7919 + 13,7,13)
		for room in run.rooms:
			if String(room.role) == "boss": expect(not Dictionary(room.neighbors).has("north"),"Seed %d: the boss room is entered from the north" % seed_value)
	for dungeon in ["forest","crypt"]:
		await _arena(dungeon,true)
	await _arena("crypt",false)
	if failures.is_empty(): print("GUARDIAN_ARENA_TESTS_PASSED")
	quit(0 if failures.is_empty() else 1)

func _arena(dungeon: String, onward: bool) -> void:
	var fake := FakeMain.new(); fake.onward = onward; root.add_child(fake)
	var scene = SCENES[dungeon].instantiate()
	scene._ensure_designer_controls()
	var state := RunState.new()
	state.campaign = MemoryCampaign.new()
	state.requested_seed = 4242
	state.start_new_run(GearData.create("arena","Arena",3,false,0,"","","warrior"),dungeon)
	state.current_floor = 5
	scene.controller = fake
	scene.run_state = state
	root.add_child(scene)
	for i in 6: await process_frame
	paused = false
	for record in state.field_run.rooms:
		if String(record.role) != "boss": continue
		state.enter_field_room(int(record.id),-1)
		scene._build_floor()
		break
	for i in 6: await process_frame
	var layout: Dictionary = scene.layout
	expect(bool(layout.get("exit_under_body",false)),"%s: the guardian room has no hidden way" % dungeon)
	expect(not Dictionary(layout.doors).has("north"),"%s: the guardian room has a north door" % dungeon)
	expect(Vector2i(layout.colossus).y == ForestRoomLibrary.COLOSSUS_SIZE.y/2,"%s: the guardian isn't against the north wall" % dungeon)
	var boss: SlasherColossus
	for actor in scene.actor_layer.get_children():
		if actor is SlasherColossus: boss = actor
	expect(boss != null,"%s: no guardian" % dungeon)
	if boss == null:
		scene.queue_free(); fake.queue_free(); return
	expect(boss.half.x >= 13 * 24.0 - 1,"%s: the guardian isn't goliath sized" % dungeon)
	var model = scene.world_3d.actors.get(boss)
	expect(model != null and model.scale.x > 2.0,"%s: the 3D guardian isn't goliath sized" % dungeon)
	expect(scene.exit_position.x < -9000,"%s: the way on is open while the guardian lives" % dungeon)
	expect(scene.actor_layer.get_node_or_null("TavernPortal") == null,"%s: the portal is open while the guardian lives" % dungeon)
	for cell in layout.passage_cells: expect(not Dictionary(layout.cells).has(cell),"%s: the passage is open while the guardian lives" % dungeon)
	scene.player.position = boss.position + Vector2(260,420)
	boss.set_physics_process(false)
	await capture("%s_alive" % dungeon)
	# Kill it.
	boss.health = 1
	boss.heart.open_for(5)
	boss.heart.receive_attack({"damage":50},scene.player)
	for i in 6: await process_frame
	expect(not is_instance_valid(boss) or boss.dead,"%s: the guardian didn't die" % dungeon)
	var portal: Node2D = scene.actor_layer.get_node_or_null("TavernPortal")
	expect(portal != null,"%s: no portal home after the kill" % dungeon)
	expect(scene.world_3d.actors.has(portal) and scene.world_3d.actors[portal].name == "TavernPortal","%s: the portal has no 3D model" % dungeon)
	if onward:
		for cell in layout.passage_cells: expect(Dictionary(scene.layout.cells).has(cell),"%s: the passage through the body didn't open" % dungeon)
		expect(scene.exit_position.distance_to(scene._world(Vector2i(layout.exit))) < 1.0,"%s: the way on isn't inside the body" % dungeon)
		var mouth: Vector2i = Array(layout.passage_cells).back()
		expect(scene.pathfinder != null and scene.is_world_position_walkable(scene._world(mouth)),"%s: you can't walk into the fallen guardian" % dungeon)
	else:
		expect(scene.exit_position.x < -9000,"%s: the way on opened with nowhere to go" % dungeon)
	await capture("%s_fallen" % dungeon)
	# Through the body = onward; the portal = home.
	if onward:
		scene.player.position = scene.exit_position
		scene.floor_reward_claimed = false
		scene._process(0.016)
		expect(fake.completed == 1 and fake.guardian_choice == "onward","%s: walking through the body didn't press on (%d, %s)" % [dungeon,fake.completed,fake.guardian_choice])
	fake.guardian_choice = ""; fake.completed = 0
	scene.floor_reward_claimed = false
	scene.player.position = portal.position
	scene._process(0.016)
	expect(fake.completed == 1 and fake.guardian_choice == "home","%s: the portal didn't take you home (%d, %s)" % [dungeon,fake.completed,fake.guardian_choice])
	# Coming back into the cleared arena: everything is still open.
	scene._build_floor()
	for i in 4: await process_frame
	expect(scene.actor_layer.get_node_or_null("TavernPortal") != null,"%s: the portal is gone on return" % dungeon)
	if onward: expect(Dictionary(scene.layout.cells).has(Array(layout.passage_cells)[0]),"%s: the passage closed on return" % dungeon)
	scene.queue_free(); fake.queue_free()
	for i in 3: await process_frame

func capture(suffix: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	await create_timer(2.5).timeout
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/claude-0/-home-claude/71d28840-11bc-5f02-a8e3-5ebbef695df9/scratchpad/guardian_"+suffix+".png")
