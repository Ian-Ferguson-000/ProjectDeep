extends SceneTree
const GROUND := preload("res://scenes/slasher/TestingGround.tscn")
const KITS := preload("res://scripts/slasher/slasher_warrior_kits.gd")
var ground: Node
func _initialize() -> void:call_deferred("capture")
func save_view(name_value: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/warrior_"+name_value+"_1280x720.png")
	root.size=Vector2i(960,540);await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/warrior_"+name_value+"_960x540.png")
	root.size=Vector2i(1280,720)
func capture() -> void:
	root.size=Vector2i(1280,720);ground=GROUND.instantiate();root.add_child(ground);await process_frame
	for id in KITS.DATA:
		ground.class_picker.select(0);ground._refresh_class()
		for index in ground.gear_options.size():
			if ground.gear_options[index].id==id:ground.gear_picker.select(index)
		ground.apply_build();ground.set_editor_visible(false);await physics_frame;await process_frame
		var player: SlasherPlayer=ground.player;var kit: Node=player.warrior_kit
		player.set_physics_process(false);kit.set_physics_process(false);player.warrior_combo_effects.set_physics_process(false)
		player.global_position=Vector2(-80,10);player.aim_direction=Vector2.RIGHT
		var enemy: SlasherEnemy=ground.combat_root.get_child(1);enemy.global_position=player.global_position+Vector2(210 if id=="borderkeepers_spear" else 95,0)
		player.use_action("basic")
		if id=="headsmans_greatsword":kit._physics_process(0.13)
		ground.state.class_resource=3;player.use_action("special");player.use_action("defensive")
		if id=="banner_of_the_vanguard":kit.banner.center=Vector2(160,10);player.global_position=kit.banner.center-Vector2(60,30);kit._physics_process(0.01)
		if id=="chain_of_the_siege_breaker":enemy.global_position=player.global_position+Vector2(240,0);player.cooldowns.basic=0;player.use_action("basic")
		if id=="duelists_paired_sabres":player.invulnerable=0;player.receive_damage(1,Vector2.ZERO,enemy)
		ground.combo_panel.visible=true
		await save_view(id)
		kit._physics_process(0.1);kit.foreground.queue_redraw()
		await save_view(id+"_followthrough")
		# Exercise a full-circle finisher and its tapered fade with real strike history.
		player.warrior_combo_effects.strike(player.global_position,Vector2.RIGHT,180,360,1,"Visual sweep")
		player.warrior_combo_effects._physics_process(0.14)
		await save_view(id+"_circle")
	for class_index in [0,4,3]:
		ground.class_picker.select(class_index);ground._refresh_class();ground.gear_picker.select(0)
		ground.apply_build();ground.set_editor_visible(false);await process_frame
		var player: SlasherPlayer=ground.player
		player.set_physics_process(false);player.weapon_trails.set_physics_process(false)
		player.global_position=Vector2(-80,10);player.aim_direction=Vector2.RIGHT
		player.use_action("basic");player.weapon_trails._physics_process(0.08)
		await save_view("standard_"+player.class_id)
	ground.set_editor_visible(true)
	await save_view("editor")
	ground.queue_free();await process_frame;await process_frame;quit()
