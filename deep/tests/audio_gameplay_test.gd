extends SceneTree

const MAIN:=preload("res://scenes/main/Main.tscn")
const SHOP:=preload("res://scripts/ui/merchant_shop_panel.gd")
var failures:Array[String]=[]
var heard:Array[String]=[]

class MemoryCampaign extends CampaignState:
	func save_atomic()->bool:return true

func _initialize()->void:call_deferred("_run")
func _expect(condition:bool,message:String)->void:
	if not condition:failures.append(message)
func _hear(event_id:String,_point:Vector2)->void:heard.append(event_id)

func _run()->void:
	var audio:Node=root.get_node("Audio")
	audio.event_played.connect(_hear)
	var main:Node=MAIN.instantiate();root.add_child(main)
	await process_frame
	_expect(audio.context=="menu" and audio.loop_channels.Music.id=="music_menu","Main menu does not select its soundscape")
	var campaign:=MemoryCampaign.new();campaign.tutorial_phase=CampaignState.TUTORIAL_COMPLETE;campaign.ensure_roster();campaign.first_company_recruited=true
	main.campaign=campaign;main.run_state.attach_campaign(campaign);main.run_state.select_active_character(campaign.living_roster()[0].id)
	main.show_tavern();await process_frame
	_expect(audio.context=="tavern" and audio.loop_channels.Music.id=="music_tavern","Tavern does not select its soundscape")
	var tavern:Node=main.current_scene
	audio.last_played.clear();heard.clear();tavern._open_options()
	_expect(heard.has("ui_open"),"Tavern options opening is silent")
	heard.clear();tavern._close_modal(tavern.options_backdrop)
	_expect(heard.has("ui_close"),"Tavern options closing is silent")
	main.open_testing_ground();await process_frame
	_expect(audio.context=="testing_ground","Training does not select its soundscape")
	main.leave_testing_ground();await process_frame
	_expect(audio.context=="tavern","Leaving training does not restore tavern audio")
	for dungeon_id in ["forest","crypt","balors_hell","ashen_farmstead","sunken_mine","ember_foundry","moonlit_grove","abyssal_archive"]:
		main.run_state.start_new_run(main.all_gear_options[0],dungeon_id)
		main.run_state.starter_reward_claimed=true
		main._load_active_dungeon();await process_frame;await process_frame
		var scene:Node=main.current_scene
		_expect(audio.context==dungeon_id,"Dungeon controller context mismatch: "+dungeon_id)
		_expect(scene.player!=null,"Dungeon did not create a player: "+dungeon_id)
		# Keep the actual scene's initial enemies from advancing during assertions.
		scene.set_process(false);scene.player.set_physics_process(false)
		for enemy in get_nodes_in_group("slasher_enemy"):enemy.set_physics_process(false);enemy.position+=Vector2(3000,0)
		var enemy:=SlasherEnemy.new();enemy.configure(1);enemy.target=scene.player;scene.actor_layer.add_child(enemy);enemy.set_physics_process(false);enemy.global_position=scene.player.global_position+Vector2(120,0)
		await process_frame
		audio.combat_check=0;audio._physics_process(.5)
		_expect(audio.loop_channels.Music.id=="music_combat","Nearby threat does not change music: "+dungeon_id)
		enemy.position+=Vector2(3000,0)
		for index in 12:audio.combat_check=0;audio._physics_process(.5)
		_expect(audio.loop_channels.Music.id=="music_dungeon","Music does not return to exploration: "+dungeon_id)
		enemy.queue_free()
		heard.clear();audio.last_played.clear()
		var loot:=Area2D.new();loot.set_meta("kind","gold");loot.set_meta("amount",2);scene.actor_layer.add_child(loot)
		scene._collect_loot(loot)
		_expect(heard.has("coins"),"Loot collection is silent: "+dungeon_id)
		heard.clear();scene.run_state.add_consumable("healing_potion");scene._use_potion()
		_expect(heard.has("potion"),"Potion use is silent: "+dungeon_id)
		var codex:Node=scene.codex
		heard.clear();audio.last_played.clear()
		for voice in audio.voices.duplicate():audio._finish_voice(voice)
		scene._open_codex()
		_expect(paused and heard.has("ui_open"),"Dungeon menu opening is silent: "+dungeon_id)
		heard.clear()
		for voice in audio.voices.duplicate():audio._finish_voice(voice)
		codex.close()
		_expect(not paused and heard.has("ui_close"),"Dungeon menu closing is silent: "+dungeon_id)
		audio.play_event("impact",scene.player.global_position,111)
		main.show_start_screen();await process_frame
		var world_voices:=0
		for voice in audio.voices:
			if voice is AudioStreamPlayer2D:world_voices+=1
		_expect(world_voices==0,"Dungeon voices survive scene replacement: "+dungeon_id)
	# A successful purchase can leave stock available; it must still play coins.
	audio.set_context("tavern")
	var shop:Node=SHOP.new();var state:=RunState.new();state.gold=100;shop.setup(state,"tavern","tavern");root.add_child(shop)
	heard.clear();audio.last_played.clear();shop._purchase("tavern_potion")
	_expect(heard.has("coins"),"Successful purchase is silent while stock remains")
	heard.clear();state.gold=0;shop._purchase("tavern_potion")
	_expect(heard.has("ui_error"),"Failed purchase is silent")
	shop.queue_free();main.queue_free();await process_frame
	# Allow short UI/outcome sounds to finish before shutting down the mixer.
	for player in audio.music_players+audio.ambience_players:player.stop()
	for voice in audio.voices.duplicate():audio._finish_voice(voice)
	await create_timer(.25).timeout
	if failures.is_empty():print("Audio gameplay: PASS (main, tavern, training, eight dungeons, trading)")
	else:
		for failure in failures:push_error(failure)
	quit(0 if failures.is_empty() else 1)
