extends SceneTree

const CATALOG:=preload("res://scripts/audio/audio_catalog.gd")
var failures:Array[String]=[]
var heard:Array[String]=[]
var audio:Node

func _initialize()->void:call_deferred("_run")
func _expect(condition:bool,message:String)->void:
	if not condition:failures.append(message)
func _hear(event_id:String,_point:Vector2)->void:heard.append(event_id)
func _clear_voices()->void:
	for voice in audio.voices.duplicate():audio._finish_voice(voice)
	audio.last_played.clear()

func _run()->void:
	audio=root.get_node_or_null("Audio")
	_expect(audio!=null,"Audio autoload missing")
	if audio==null:quit(1);return
	audio.event_played.connect(_hear)
	var settings:Node=root.get_node("GameSettings")
	var saved_values:Dictionary=settings.values.duplicate(true)
	settings.values=settings.DEFAULTS.duplicate(true);settings.apply_audio()
	for name in ["Master","Music","SFX","Ambience","UI"]:
		var index:=AudioServer.get_bus_index(name)
		_expect(index>=0,"Missing bus "+name)
		if index>0:_expect(AudioServer.get_bus_send(index)==&"Master","Bus does not route to Master: "+name)
	_expect(AudioServer.get_bus_effect(0,0) is AudioEffectHardLimiter,"Master limiter missing")
	for event_id:String in CATALOG.EVENTS:
		for stream:AudioStream in CATALOG.EVENTS[event_id].streams:
			_expect(stream!=null and stream.get_length()>0.01,"Missing or empty cue: "+event_id)
	for loop_id:String in CATALOG.LOOPS:
		var stream:AudioStreamWAV=CATALOG.LOOPS[loop_id]
		_expect(stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and stream.get_length()>=16.0,"Loop was not imported correctly: "+loop_id)
	_expect(not audio.play_event("unknown_event"),"Unknown event accepted")
	_expect(audio.play_event("impact",Vector2(40,40),12),"Impact did not play")
	_expect(not audio.play_event("impact",Vector2(40,40),12),"Emitter cooldown failed")
	var first:AudioStream=audio.voices.back().stream
	_expect(audio.play_event("impact",Vector2(60,40),13),"Distinct emitter suppressed")
	_expect(audio.voices.back().stream!=first,"Repeated variant on consecutive impacts")
	for index in 12:audio.play_event("impact",Vector2.ZERO,100+index)
	_expect(audio.voices.size()==6,"Per-event voice cap failed")
	_clear_voices()
	# Fill the mix with low/mid-priority voices, then preserve a critical player cue.
	for event_id:String in ["step_grass","step_stone","step_wood","sword_swing","prop_break","rock_break","enemy_attack","impact"]:
		for index in 6:audio.play_event(event_id,Vector2.ZERO,200+index)
	_expect(audio.voices.size()==24,"Global voice cap failed")
	_expect(audio.play_event("player_hurt",Vector2.ZERO,901),"Priority cue did not replace a lower-priority voice")
	_expect(audio.voices.size()==24,"Voice stealing exceeded global cap")
	_clear_voices()
	# UI remains processable during pause while world voices pause.
	paused=true
	audio.play_event("ui_click");audio.play_event("impact",Vector2.ZERO)
	_expect(audio.voices[0].process_mode==Node.PROCESS_MODE_ALWAYS,"UI does not play while paused")
	_expect(audio.voices[1].process_mode==Node.PROCESS_MODE_PAUSABLE,"World sounds do not respect pause")
	paused=false;_clear_voices()
	for next_context in ["menu","tavern","forest","crypt","balors_hell","ashen_farmstead","sunken_mine","ember_foundry","moonlit_grove","abyssal_archive","testing_ground"]:
		audio.set_context(next_context)
		_expect(audio.context==next_context,"Context did not change: "+next_context)
		_expect(audio.music_players[int(audio.loop_channels.Music.index)].playing,"Music did not start: "+next_context)
		if next_context!="menu":_expect(audio.ambience_players[int(audio.loop_channels.Ambience.index)].playing,"Ambience did not start: "+next_context)
	await create_timer(0.9).timeout
	_expect(not audio.music_players[1-int(audio.loop_channels.Music.index)].playing,"Outgoing music survives the crossfade")
	audio._update_music(true)
	_expect(audio.loop_channels.Music.id=="music_combat","Combat music failed")
	audio._update_music(false)
	# Real gameplay calls must reach playback; immunity must remain silent.
	var state:=RunState.new();state.set_class("warrior");state.start_new_run(GearData.create("audio_test","Audio Test",3,false,0,"","","warrior"),"forest")
	state.class_resource=state.get_class_resource_max()
	var player:=SlasherPlayer.new();player.setup(state);root.add_child(player);player.set_physics_process(false)
	await process_frame
	heard.clear();_clear_voices()
	var result:Dictionary=player.use_action("basic")
	_expect(bool(result.started) and heard.has("sword_swing"),"Successful basic attack is silent")
	heard.clear();player.use_action("basic")
	_expect(not heard.has("sword_swing"),"Rejected attack plays a swing")
	heard.clear();player.invulnerable=0;player.defense_window=0;player.receive_damage(2,Vector2.ZERO)
	_expect(heard.has("player_hurt"),"Player damage is silent")
	heard.clear();player.invulnerable=1;player.receive_damage(2,Vector2.ZERO)
	_expect(not heard.has("player_hurt"),"Invulnerable damage is audible")
	player.invulnerable=0;player.defense_kind="parry";player.defense_window=1;heard.clear();_clear_voices()
	player.receive_damage(2,Vector2.ZERO)
	_expect(heard.has("block") and not heard.has("player_hurt"),"Fully prevented damage uses the wrong cue")
	heard.clear();player.heal(2)
	_expect(heard.has("heal"),"Healing is silent")
	var enemy:=SlasherEnemy.new();enemy.configure(1);enemy.target=player;root.add_child(enemy);enemy.set_physics_process(false)
	heard.clear();_clear_voices();enemy.receive_attack({"damage":1,"damage_type":"ice"},player)
	_expect(heard.has("impact_ice"),"Elemental impact is silent")
	heard.clear();enemy.receive_hit(999)
	_expect(heard.has("enemy_death"),"Enemy death is silent")
	var prop:=SlasherBreakableProp.new();prop.setup("chest",Vector2i.ZERO);root.add_child(prop)
	heard.clear();prop.open_chest();_expect(heard.has("chest_open"),"Chest opening is silent")
	heard.clear();prop.open_chest();_expect(not heard.has("chest_open"),"Already-open chest emits audio")
	prop.queue_free()
	# Real displacement creates steps; standing still and teleporting do not.
	audio.set_context("forest");heard.clear();_clear_voices()
	for index in 18:
		player.position.x+=4;audio._physics_process(1.0/60.0)
	_expect(heard.has("step_grass"),"Actual movement is silent")
	heard.clear();audio._physics_process(.3);player.position.x+=400;audio._physics_process(.3)
	_expect(not heard.has("step_grass"),"Teleport or stationary actor produces footsteps")
	# The UI is created dynamically; both controller/keyboard activation and pointer use
	# share the same button signal, including buttons added after the autoload is ready.
	var button:=Button.new();root.add_child(button);await process_frame
	heard.clear();_clear_voices();button.pressed.emit();await process_frame
	_expect(heard.has("ui_click"),"Dynamic button activation is silent")
	button.queue_free();player.queue_free();await process_frame
	_expect(audio.walkers.is_empty(),"Deleted walkers remain tracked")
	# Settings apply independently and old saves fall back to the new defaults.
	settings.values.ui_volume=.35;settings.values.ambience_mute=true;settings.apply_audio()
	_expect(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("UI")),linear_to_db(.35)),"UI volume not applied")
	_expect(AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambience")),"Ambience mute not applied")
	settings.values.erase("ambience_volume")
	_expect(is_equal_approx(settings.get_float("ambience_volume"),.65),"Old settings do not receive ambience defaults")
	settings.values=settings.DEFAULTS.duplicate(true);settings.apply_audio()
	# Verify the actual mixed PCM signal, rather than only player state.
	for music in audio.music_players:music.stop()
	for ambience in audio.ambience_players:ambience.stop()
	_clear_voices();await create_timer(.2).timeout
	var capture:=AudioEffectCapture.new();capture.buffer_length=1.0
	var master:=AudioServer.get_bus_index("Master");var effect_index:=AudioServer.get_bus_effect_count(master)
	AudioServer.add_bus_effect(master,capture)
	audio.play_event("cast_aether")
	await create_timer(.65).timeout
	var frames:=capture.get_buffer(capture.get_frames_available())
	var peak:=0.0
	for frame in frames:peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
	_expect(frames.size()>0 and peak>0.001,"Playback produced no mixed audio samples")
	print("Audio mixer: %d stereo frames, peak %.5f"%[frames.size(),peak])
	AudioServer.remove_bus_effect(master,effect_index)
	_clear_voices();settings.values=saved_values;settings.apply_audio()
	await process_frame
	if failures.is_empty():print("Audio integration: PASS (%d events, %d loops)"%[CATALOG.EVENTS.size(),CATALOG.LOOPS.size()])
	else:
		for failure in failures:push_error(failure)
	quit(0 if failures.is_empty() else 1)
