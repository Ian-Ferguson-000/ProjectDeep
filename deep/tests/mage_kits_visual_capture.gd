extends SceneTree

const GROUND := preload("res://scenes/slasher/TestingGround.tscn")
const KITS := preload("res://scripts/slasher/slasher_mage_kits.gd")
var ground: Node

func _initialize() -> void:call_deferred("capture")

func equip(id: String) -> void:
	ground.class_picker.select(1);ground._refresh_class()
	for index in ground.gear_options.size():
		if ground.gear_options[index].id==id:ground.gear_picker.select(index)
	ground.apply_build();ground.set_editor_visible(false)
	await physics_frame;await process_frame
	ground.player.set_physics_process(false)

func save_view(name_value: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/mage_"+name_value+"_1280x720.png")
	ground.player.mage_kit.set_physics_process(false)
	root.size=Vector2i(960,540)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/mage_"+name_value+"_960x540.png")
	root.size=Vector2i(1280,720)

func capture() -> void:
	root.size=Vector2i(1280,720);ground=GROUND.instantiate();root.add_child(ground);await process_frame
	await equip(KITS.WINTERGLASS.GEAR_ID)
	var player: SlasherPlayer=ground.player;var kit: Node=player.mage_kit
	var target: SlasherEnemy=ground.combat_root.get_child(1)
	player.aim_direction=Vector2.RIGHT;player.use_action("defensive");player.use_action("movement")
	for cast in 3:
		player.cooldowns.basic=0;player.use_action("basic")
		for child in ground.combat_root.get_children():
			if child is SlasherProjectile:child.global_position=target.global_position;child._damage_impact(target);ground.combat_root.remove_child(child);child.queue_free()
	player.global_position=Vector2(-80,10);player.aim_direction=player.global_position.direction_to(target.global_position)
	player.use_action("special");kit._physics_process(0.17)
	await save_view("winterglass")
	await equip(KITS.STORMBRINGER.GEAR_ID)
	player=ground.player;kit=player.mage_kit;target=ground.combat_root.get_child(1)
	for index in 3:
		player.cooldowns.special=0;ground.state.class_resource=3;player.use_action("special")
		kit.rods.back().center=Vector2(70+index*140,-40+index*35);kit.rods.back().charged=true
	player.aim_direction=player.global_position.direction_to(target.global_position);player.use_action("defensive");player.use_action("basic")
	await save_view("stormbringer")
	await equip(KITS.GRAVITY.GEAR_ID)
	player=ground.player;kit=player.mage_kit;target=ground.combat_root.get_child(1)
	player.aim_direction=Vector2.RIGHT;player.use_action("movement");player.use_action("special");kit.well.center=Vector2(170,-20)
	player.use_action("defensive");player.aim_direction=player.global_position.direction_to(target.global_position);player.use_action("basic");kit._physics_process(0.11)
	await save_view("gravity")
	await equip(KITS.MIRRORBOUND.GEAR_ID)
	player=ground.player;kit=player.mage_kit;target=ground.combat_root.get_child(1)
	var origin := player.global_position;player.aim_direction=Vector2.RIGHT;player.use_action("movement")
	player.aim_direction=origin.direction_to(target.global_position);player.use_action("basic");player.use_action("defensive")
	await save_view("mirror_recording")
	kit.set_physics_process(true)
	player.aim_direction=player.global_position.direction_to(ground.combat_root.get_child(2).global_position);player.use_action("special")
	kit._physics_process(0.13)
	await save_view("mirror_replay")
	player.cooldowns.basic=0;player.use_action("basic");player.cooldowns.defensive=0;player.use_action("defensive");player.invulnerable=0;player.receive_damage(1,Vector2.ZERO)
	await save_view("mirror_barrier")
	ground.set_editor_visible(true)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/mage_build_editor_1280x720.png")
	root.size=Vector2i(960,540)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/mage_build_editor_960x540.png")
	ground.queue_free();await process_frame;await process_frame;quit()
