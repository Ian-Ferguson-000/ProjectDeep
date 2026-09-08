extends SceneTree

const HELL:=preload("res://scenes/slasher/SlasherHell.tscn")
const HELL_ENEMY:=preload("res://scripts/slasher/slasher_hell_enemy.gd")

func _initialize()->void:call_deferred("_run")

func _run()->void:
	var failures:Array[String]=[];var definition:=GameBalance.get_dungeon("balors_hell")
	_expect(GameBalance.get_dungeon_order()[2]=="balors_hell","Balor's Hell is not the third dungeon",failures)
	_expect(String(definition.slasher_runtime)=="balors_hell" and Array(definition.supported_modes).has("slasher"),"Balor's Hell runtime routing is incomplete",failures)
	_expect(String(GameBalance.get_dungeon("crypt").continuous_next)=="balors_hell" and String(definition.unlock.dungeon_id)=="crypt","Crypt does not unlock and descend into Balor's Hell",failures)
	var profile:=DungeonRuntimeProfile.get_profile("balors_hell");_expect(Array(profile.slasher_enemies)==["infernal_caster","rift_stalker","hellcharger","cinder_bomber"] and String(profile.boss)=="balor","Hell-only roster or boss profile is incomplete",failures);_expect(String(profile.wall_profile)=="hell_wall","Balor's Hell still uses the normal stone wall profile",failures)
	for enemy_id:String in ["infernal_caster","rift_stalker","hellcharger","cinder_bomber","fire_spirit","infernal_legate","balor"]:_expect(not GameBalance.get_slasher_enemy_tuning(enemy_id).is_empty(),"Missing Hell tuning for %s"%enemy_id,failures)
	for enemy_id:String in ["infernal_caster","rift_stalker","hellcharger","cinder_bomber","fire_spirit","infernal_legate","balor"]:
		var frames:=SlasherSpriteLibrary.enemy_frames(enemy_id);_expect(frames!=null and frames.has_animation("idle_down") and frames.has_animation("run_left") and frames.has_animation("attack_up"),"Hell animation board is incomplete for %s"%enemy_id,failures)
	for asset:String in ["res://assets/pixel_art/TX tileset Hellfloor.png","res://assets/pixel_art/TX tileset Hellwall.png","res://scenes/slasher/SlasherHell.tscn"]:_expect(ResourceLoader.exists(asset),"Missing Hell asset: %s"%asset,failures)
	var elite_layout:=SlasherForestGenerator.generate(3303,3,"balors_hell");var boss_layout:=SlasherForestGenerator.generate(6606,6,"balors_hell");_expect(bool(elite_layout.is_elite_floor),"Circle three is not the elite encounter",failures);_expect(bool(boss_layout.is_boss_floor),"Circle six is not Balor's boss floor",failures)
	var state:=RunState.new();state.set_class("warrior");state.start_new_run(GearData.create("hell_test","Hell Test",3,true,1,"","","warrior"),"balors_hell","slasher");state.current_floor=3
	var scene=HELL.instantiate();get_root().add_child(scene);scene._ensure_designer_controls();scene.setup(null,state);await process_frame;await process_frame
	_expect(scene.wall_generator!=null and scene.wall_generator.profile_id=="hell_wall","Hell generator did not instantiate the Hellwall topology profile",failures)
	_expect(not scene.hell_hazards.is_empty(),"Hell floor did not install burning ground hazards",failures)
	var behaviors:Dictionary={}
	for node:Node in get_nodes_in_group("slasher_enemy"):
		if node is SlasherHellEnemy:behaviors[(node as SlasherHellEnemy).behavior_id]=true
	_expect(behaviors.has("infernal_legate"),"Elite floor did not spawn the spirit-summoning Infernal Legate",failures)
	var stalker:SlasherHellEnemy=HELL_ENEMY.new();stalker.configure(2,false,"rift_stalker",false,"rift_stalker");scene.actor_layer.add_child(stalker);stalker.global_position=scene.player.global_position+Vector2(220,0);stalker.target=scene.player;stalker.pathfinder=scene.pathfinder;stalker.activation_delay=0.0;stalker.special_cooldown=0.0;stalker._process_stalker()
	_expect(stalker.ai_state=="teleport_windup" and stalker.visible and stalker.state_timer>=0.99,"Rift Stalker did not remain visible during its one-second teleport warning",failures)
	_expect(not get_nodes_in_group("teleport_indicator").is_empty(),"Rift Stalker did not mark its teleport destination",failures)
	var expected_destination:=stalker.teleport_target;stalker.state_timer=0.0;stalker._process_stalker();_expect(stalker.visible and stalker.global_position.is_equal_approx(expected_destination),"Rift Stalker did not reappear at its marked destination",failures)
	_expect(stalker.ai_state=="teleport_recovery" and stalker.state_timer>=1.49,"Rift Stalker did not enter its stationary post-teleport recovery",failures)
	var recovery_position:=stalker.global_position;stalker._process_stalker();_expect(stalker.velocity.is_zero_approx() and stalker.global_position.is_equal_approx(recovery_position),"Rift Stalker moved during its post-teleport punish window",failures)
	var boss:SlasherHellEnemy=HELL_ENEMY.new();boss.configure(6,true,"balor",false,"balor");boss.hell_effect_requested.connect(scene._on_hell_effect_requested);scene.actor_layer.add_child(boss);boss.target=scene.player;boss.pathfinder=scene.pathfinder;boss.activation_delay=0.0
	var starting_hazards:=get_nodes_in_group("hell_hazard").size()
	for pattern:int in 3:boss.pattern_index=pattern;boss.queued_pattern=pattern;boss._release_balor_wave()
	var hell_projectiles:=get_nodes_in_group("hell_projectile");_expect(hell_projectiles.size()>0,"Balor's barrage wave produced no projectiles",failures)
	for projectile:Node in hell_projectiles:
		if projectile.source==boss:_expect(projectile.visual_type=="flaming_disk","Balor emitted a projectile without his flaming-disk visual",failures)
	_expect(get_nodes_in_group("hell_hazard").size()>starting_hazards,"Balor's ground wave produced no temporary hazards",failures)
	for visual_type:String in ["flaming_disk","necrotic_skull","soul","arrow","hellfire_orb","rift_shard"]:
		var projectile_frames:=SlasherSpriteLibrary.hostile_projectile_frames(visual_type);_expect(projectile_frames!=null and projectile_frames.has_animation("flight") and projectile_frames.get_frame_count("flight")==8,"Projectile animation is incomplete for %s"%visual_type,failures)
	if failures.is_empty():print("BALORS_HELL_TESTS_PASSED");quit(0)
	else:
		for failure:String in failures:push_error(failure)
		quit(1)

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
