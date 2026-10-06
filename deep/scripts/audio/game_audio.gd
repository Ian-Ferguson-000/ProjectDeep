extends Node

signal event_played(event_id:String,point:Vector2)
signal context_changed(context:String)

const CATALOG:=preload("res://scripts/audio/audio_catalog.gd")
const MAX_VOICES:=24
var voices:Array[Node]=[]
var last_played:Dictionary={}
var last_variant:Dictionary={}
var rng:=RandomNumberGenerator.new()
var walkers:Dictionary={}
var music_players:Array[AudioStreamPlayer]=[]
var ambience_players:Array[AudioStreamPlayer]=[]
var loop_channels:Dictionary={}
var context:=""
var combat_remaining:=0.0
var combat_check:=0.0
var ui_started_at:=0
var cleanup_remaining:=0.0

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	ui_started_at=Time.get_ticks_msec()
	for bus in ["Music","SFX","Ambience","UI"]:
		if AudioServer.get_bus_index(bus)<0:
			AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
	for bus in ["Music","Ambience"]:
		var players:Array[AudioStreamPlayer]=[]
		for index in 2:
			var player:=AudioStreamPlayer.new();player.bus=bus;player.volume_db=-60.0
			add_child(player);players.append(player)
		if bus=="Music":music_players=players
		else:ambience_players=players
		loop_channels[bus]={"id":"","index":0,"tween":null}
	get_tree().node_added.connect(_on_node_added)
	_watch_existing(get_tree().root)

func _watch_existing(node:Node)->void:
	_on_node_added(node)
	for child in node.get_children():_watch_existing(child)

func _on_node_added(node:Node)->void:
	if node is BaseButton or node is Range or node is CharacterBody2D:
		_observe_node.call_deferred(weakref(node))

func _observe_node(reference:WeakRef)->void:
	var node:Node=reference.get_ref()
	if not is_instance_valid(node) or not node.is_inside_tree() or node.has_meta("audio_observed"):return
	node.set_meta("audio_observed",true)
	if node is BaseButton:
		node.pressed.connect(_button_pressed.bind(reference))
		if node is OptionButton:node.item_selected.connect(_option_selected)
		node.mouse_entered.connect(_button_focus.bind(reference))
		node.focus_entered.connect(_button_focus.bind(reference))
	elif node is Slider:
		node.drag_ended.connect(_slider_finished)
	if node is CharacterBody2D and (node.is_in_group("slasher_player") or node.is_in_group("tavern_keeper") or node is PlayerCharacter):
		var id:=node.get_instance_id()
		walkers[id]={"ref":reference,"position":node.global_position,"distance":0.0,"time":0.0}
		node.tree_exiting.connect(_forget_walker.bind(id),CONNECT_ONE_SHOT)

func _button_pressed(reference:WeakRef)->void:
	var button:BaseButton=reference.get_ref()
	if not is_instance_valid(button) or button.disabled:return
	# Deferred because a button may save volume/mute settings or change scenes first.
	play_event.call_deferred("ui_click")

func _option_selected(_index:int)->void:play_event.call_deferred("ui_click")
func _slider_finished(changed:bool)->void:
	if changed:play_event("ui_click")

func _button_focus(reference:WeakRef)->void:
	var button:BaseButton=reference.get_ref()
	if not is_instance_valid(button) or button.disabled or not button.is_visible_in_tree():return
	# Do not sonify automatic initial focus when a screen is constructed.
	if Time.get_ticks_msec()-ui_started_at<500:return
	if Input.is_anything_pressed() or button.get_global_rect().has_point(button.get_global_mouse_position()):play_event("ui_focus")

func _forget_walker(id:int)->void:
	walkers.erase(id)
	for key in last_played.keys():
		if String(key).ends_with(":%d"%id):last_played.erase(key)

# One-shots live on the autoload, so deleting their emitter never cuts off a cue.
# Return false for unknown, throttled or lower-priority events.
func play_event(event_id:String,point:Vector2=Vector2.INF,emitter_id:int=0)->bool:
	if not CATALOG.EVENTS.has(event_id):return false
	var definition:Dictionary=CATALOG.EVENTS[event_id]
	var now:=Time.get_ticks_msec()*0.001
	var cooldown_key:="%s:%d"%[event_id,emitter_id]
	if now-float(last_played.get(cooldown_key,-100.0))<float(definition.cooldown):return false
	var matching:=0
	for voice in voices:
		if is_instance_valid(voice) and String(voice.get_meta("event_id"))==event_id:matching+=1
	if matching>=int(definition.max_voices):return false
	if voices.size()>=MAX_VOICES:
		var victim:Node
		for voice in voices:
			if int(voice.get_meta("priority"))<int(definition.priority):
				if victim==null or int(voice.get_meta("priority"))<int(victim.get_meta("priority")):victim=voice
		if victim==null:return false
		_finish_voice(victim)
	var streams:Array=definition.streams
	var variant:=rng.randi_range(0,streams.size()-1)
	if streams.size()>1 and variant==int(last_variant.get(event_id,-1)):variant=(variant+1)%streams.size()
	last_variant[event_id]=variant;last_played[cooldown_key]=now
	var player:Node
	if point!=Vector2.INF:
		var positional:=AudioStreamPlayer2D.new()
		positional.position=point;positional.max_distance=1400.0;positional.attenuation=0.7
		player=positional;player.process_mode=Node.PROCESS_MODE_PAUSABLE
	else:player=AudioStreamPlayer.new();player.process_mode=Node.PROCESS_MODE_ALWAYS
	player.stream=streams[variant];player.bus=String(definition.bus);player.volume_db=float(definition.volume_db)
	player.pitch_scale=1.0+rng.randf_range(-float(definition.pitch_variation),float(definition.pitch_variation))
	player.set_meta("event_id",event_id);player.set_meta("priority",int(definition.priority))
	add_child(player);voices.append(player);player.finished.connect(_finish_voice.bind(player),CONNECT_ONE_SHOT)
	player.play();event_played.emit(event_id,point);return true

func _finish_voice(player:Node)->void:
	voices.erase(player)
	if is_instance_valid(player):player.stop();player.queue_free()

func _exit_tree()->void:
	for channel:Dictionary in loop_channels.values():
		if channel.tween!=null and channel.tween.is_valid():channel.tween.kill()
	for player in voices:
		if is_instance_valid(player):player.stop();player.stream=null
	for player in music_players+ambience_players:
		player.stop();player.stream=null
	loop_channels.clear();walkers.clear();voices.clear()
	# AudioServer retires stopped playback handles on its mixer thread. Give it
	# two buffer intervals before SceneTree shuts down the driver (also in fast tests).
	var drain_ms:=clampi(ceili(AudioServer.get_time_to_next_mix()*2000.0)+30,40,100)
	OS.delay_msec(drain_ms)

func stop_world_sounds()->void:
	for player in voices.duplicate():
		if player is AudioStreamPlayer2D:_finish_voice(player)

func set_context(next_context:String)->void:
	if context==next_context:return
	stop_world_sounds();context=next_context;combat_remaining=0.0;combat_check=0.0
	ui_started_at=Time.get_ticks_msec()
	_update_music(false)
	var ambience_id:=""
	match context:
		"tavern","ashen_farmstead","ember_foundry","balors_hell":ambience_id="ambience_fire"
		"forest","moonlit_grove":ambience_id="ambience_forest"
		"sunken_mine":ambience_id="ambience_water"
		"crypt","testing_ground":ambience_id="ambience_stone"
		"abyssal_archive":ambience_id="ambience_mystic"
	_crossfade("Ambience",ambience_id,-27.0)
	context_changed.emit(context)

func _update_music(combat:bool)->void:
	var music_id:="music_menu"
	if context=="tavern":music_id="music_tavern"
	elif context not in ["","menu","class_selection"]:music_id="music_combat" if combat else "music_dungeon"
	_crossfade("Music",music_id,-20.0 if combat else -24.0)

func _crossfade(bus:String,loop_id:String,volume:float)->void:
	var channel:Dictionary=loop_channels[bus]
	if String(channel.id)==loop_id:return
	if channel.tween!=null and channel.tween.is_valid():channel.tween.kill()
	var players:Array[AudioStreamPlayer]=music_players if bus=="Music" else ambience_players
	var old:AudioStreamPlayer=players[int(channel.index)]
	var next_index:=1-int(channel.index)
	var incoming:AudioStreamPlayer=players[next_index]
	incoming.stop();incoming.volume_db=-60.0
	if not loop_id.is_empty():
		incoming.stream=CATALOG.LOOPS[loop_id];incoming.play()
	var tween:=create_tween().set_parallel(true)
	tween.tween_property(old,"volume_db",-60.0,0.8)
	if not loop_id.is_empty():tween.tween_property(incoming,"volume_db",volume,0.8)
	tween.chain().tween_callback(old.stop)
	channel.id=loop_id;channel.index=next_index;channel.tween=tween

func _physics_process(delta:float)->void:
	cleanup_remaining-=delta
	if cleanup_remaining<=0.0:
		cleanup_remaining=10.0
		var now:=Time.get_ticks_msec()*0.001
		for key in last_played.keys():
			if now-float(last_played[key])>10.0:last_played.erase(key)
	if get_tree().paused:return
	for id in walkers.keys():
		var state:Dictionary=walkers[id]
		var actor:CharacterBody2D=state.ref.get_ref()
		if not is_instance_valid(actor):walkers.erase(id);continue
		var position_now:=actor.global_position
		var distance:float=position_now.distance_to(state.position)
		state.position=position_now;state.time=float(state.time)+delta
		if not actor.is_visible_in_tree() or actor.is_in_group("slasher_companion"):continue
		if actor is SlasherPlayer and (actor.health<=0 or actor.input_locked or actor.warrior_dash_active):continue
		# Ignore teleports/dashes and require real travel; pushing against a wall is silent.
		if distance>0.2 and distance<12.0:state.distance=float(state.distance)+distance
		elif distance<0.2:state.distance=0.0
		if float(state.distance)>=48.0 and float(state.time)>=0.24:
			var surface:="wood" if context=="tavern" else ("grass" if context in ["forest","moonlit_grove","ashen_farmstead"] else "stone")
			play_event("step_"+surface,position_now,id);state.distance=0.0;state.time=0.0
	combat_check-=delta
	if combat_check<=0.0 and context not in ["","menu","tavern","class_selection","testing_ground"]:
		combat_check=0.5
		var threatened:=false
		for state:Dictionary in walkers.values():
			var actor:Node2D=state.ref.get_ref()
			if not is_instance_valid(actor) or not actor is SlasherPlayer or actor.is_in_group("slasher_companion") or actor.health<=0:continue
			for enemy in get_tree().get_nodes_in_group("slasher_enemy"):
				if enemy is Node2D and actor.global_position.distance_squared_to(enemy.global_position)<360.0*360.0:threatened=true;break
		if threatened:combat_remaining=5.0
		else:combat_remaining=maxf(0.0,combat_remaining-0.5)
		_update_music(combat_remaining>0.0)
