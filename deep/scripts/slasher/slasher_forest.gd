extends Node2D

const TILE:=48
const ORIGIN:=Vector2(64,64)
const CAMERA_DRAG_MARGIN:=0.25
const PLAYER_SCRIPT:=preload("res://scripts/slasher/slasher_player.gd")
const ENEMY_SCRIPT:=preload("res://scripts/slasher/slasher_enemy.gd")
const MERCHANT_PANEL:=preload("res://scripts/ui/merchant_shop_panel.gd")
const CODEX:=preload("res://scripts/slasher/slasher_codex_menu.gd")
const BREAKABLE_PROP:=preload("res://scripts/slasher/slasher_breakable_prop.gd")
const RELIC_MODAL:=preload("res://scripts/slasher/slasher_relic_choice_modal.gd")
const RESOURCE_HUD_FRAME:=preload("res://assets/slasher/ui/slasher_resource_hud_frame.png")
const GOLD_UI_ICON:=preload("res://assets/pixel_art/Gold.png")
const KEY_UI_ICON:=preload("res://assets/pixel_art/key.png")
const POTION_UI_ICON:=preload("res://assets/pixel_art/potion.png")
const GRID_PATHFINDER:=preload("res://scripts/slasher/slasher_grid_pathfinder.gd")
const PARTY_HEALTH_PORTRAIT:=preload("res://scripts/ui/party_health_portrait.gd")
const SETTINGS_SERVICE:=preload("res://scripts/game/game_settings.gd")

var controller:Node
var run_state:RunState
var dungeon_context:Dictionary={}
var layout:Dictionary={}
var player:SlasherPlayer
var pathfinder:SlasherGridPathfinder
var enemies_remaining:=0
var exit_open:=false
var floor_reward_claimed:=false
var loot_nodes:Array[Area2D]=[]
var exit_position:=Vector2.ZERO
var merchant_position:=Vector2.ZERO
var has_dungeon_merchant:=true
var message_label:Label
var objective_label:Label
var health_bar:ProgressBar
var resource_bar:ProgressBar
var health_value_label:Label
var resource_value_label:Label
var gold_value_label:Label
var key_value_label:Label
var potion_value_label:Label
var merchant_shop_panel:MerchantShopPanel
var codex:SlasherCodexMenu
var relic_modal:SlasherRelicChoiceModal
var relic_choice_source:=""
var tutorial_layer:CanvasLayer
var tutorial_origin:Vector2=Vector2.ZERO
var tutorial_elapsed:float=0.0
var ground_layer:Node2D
var low_decor_layer:Node2D
var actor_layer:Node2D
var canopy_layer:Node2D
var suppress_abandon_frames:=0
var party_strip:HBoxContainer
var party_portraits:Dictionary={}
var active_summons:Dictionary={}
var local_settings:Node

func _settings()->Node:
	var singleton:=get_node_or_null("/root/GameSettings")
	if singleton!=null:return singleton
	if local_settings==null:local_settings=SETTINGS_SERVICE.new();local_settings.values=SETTINGS_SERVICE.DEFAULTS.duplicate(true)
	return local_settings

func setup(game_controller:Node,state:RunState,context:Dictionary={})->void:
	controller=game_controller;run_state=state;dungeon_context=context
	if is_inside_tree():_build_floor()

func _ready()->void:
	if run_state!=null:_build_floor()

func _exit_tree()->void:
	if get_tree()!=null:get_tree().paused=false

func _build_floor()->void:
	get_tree().paused=false
	for child in get_children():child.free()
	layout=SlasherForestGenerator.generate(run_state.get_current_floor_seed(),run_state.current_floor)
	pathfinder=GRID_PATHFINDER.new().configure(Dictionary(layout.get("cells",{})),Array(layout.get("solid_props",[])),ORIGIN,float(TILE))
	active_summons.clear();_build_world();_spawn_player();_spawn_enemies();_spawn_loot();_build_hud();_refresh_hud();_entry_fade()
	if player.item_runtime:player.item_runtime.floor_entered()
	if run_state.current_floor==1 and not run_state.starter_reward_claimed:call_deferred("_offer_starter_relic")

func _build_world()->void:
	var profile:=DungeonRuntimeProfile.get_profile(run_state.active_dungeon_id);var underlay:=ColorRect.new();underlay.name="DungeonDepth";underlay.color=Color("#"+String(profile.get("underlay","07100d")));underlay.position=Vector2.ZERO;underlay.size=Vector2(float(layout.width*TILE+128),float(layout.height*TILE+128));underlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;underlay.z_index=-20;add_child(underlay)
	ground_layer=Node2D.new();ground_layer.name="Ground";ground_layer.z_index=-10;add_child(ground_layer)
	low_decor_layer=Node2D.new();low_decor_layer.name="LowDecor";low_decor_layer.z_index=-2;add_child(low_decor_layer)
	actor_layer=Node2D.new();actor_layer.name="Actors";actor_layer.y_sort_enabled=true;add_child(actor_layer)
	canopy_layer=Node2D.new();canopy_layer.name="Canopy";canopy_layer.y_sort_enabled=true;canopy_layer.z_index=8;add_child(canopy_layer)
	var cells:Dictionary=layout.cells
	for value:Variant in cells:
		var cell:Vector2i=value;var base:=SlasherForestArt.make_ground_sprite(cell,TILE);base.name="Ground_%d_%d"%[cell.x,cell.y];base.position=_world(cell);ground_layer.add_child(base)
	for value:Variant in layout.get("edges",{}):
		var cell:Vector2i=value;var edge:Dictionary=layout.edges[cell]
		for missing_value in edge.get("missing",[]):_add_boundary(cell,_direction(String(missing_value)))
	_build_boundary_corners(cells)
	_build_decorations();_build_solid_props();_build_landmarks();_build_mist();_build_vignette()

func _build_decorations()->void:
	for value:Variant in layout.get("decorations",[]):
		var decoration:Dictionary=value;var sprite:=SlasherForestArt.make_sprite(String(decoration.kind));sprite.name="Decor_%s"%String(decoration.kind);sprite.position=_world(Vector2i(decoration.cell))+Vector2(decoration.offset)
		if bool(decoration.get("edge",false)) and String(decoration.kind).begins_with("tree"):canopy_layer.add_child(sprite)
		else:low_decor_layer.add_child(sprite)

func _build_solid_props()->void:
	for value:Variant in layout.get("solid_props",[]):
		var prop:Dictionary=value;var body:SlasherBreakableProp=BREAKABLE_PROP.new();body.name="Breakable_%s"%String(prop.kind);body.setup(String(prop.kind),Vector2i(prop.cell));body.position=_world(Vector2i(prop.cell));body.broken.connect(_on_prop_broken);body.opened.connect(_on_chest_opened);actor_layer.add_child(body)

func _build_landmarks()->void:
	exit_position=_world(layout.exit);merchant_position=_world(layout.merchant)
	var exit_root:=Node2D.new();exit_root.name="RootGate";exit_root.position=exit_position;exit_root.z_index=12;exit_root.add_child(_glow(Color("#83d978"),34));var exit_sprite:=SlasherForestArt.make_sprite("exit");exit_sprite.position=Vector2(0,-30);exit_root.add_child(exit_sprite);actor_layer.add_child(exit_root)
	has_dungeon_merchant=not String(GameBalance.get_dungeon(run_state.active_dungeon_id).get("merchant_id","")).is_empty()
	if has_dungeon_merchant:
		var merchant_root:=Node2D.new();merchant_root.name="DungeonMerchant";merchant_root.position=merchant_position;merchant_root.add_child(_glow(Color("#e8b94e"),28));var merchant_sprite:=SlasherForestArt.make_sprite("merchant");merchant_sprite.position=Vector2(0,-28);merchant_root.add_child(merchant_sprite);actor_layer.add_child(merchant_root)

func _build_mist()->void:
	var mist:=CPUParticles2D.new();mist.name="ForestMist";mist.amount=42;mist.lifetime=9.0;mist.preprocess=9.0;mist.emission_shape=CPUParticles2D.EMISSION_SHAPE_RECTANGLE;mist.emission_rect_extents=Vector2(float(layout.width*TILE)/2.0,float(layout.height*TILE)/2.0);mist.position=ORIGIN+Vector2(float(layout.width*TILE)/2.0,float(layout.height*TILE)/2.0);mist.direction=Vector2(1,-0.12);mist.spread=18;mist.initial_velocity_min=3;mist.initial_velocity_max=8;mist.scale_amount_min=3;mist.scale_amount_max=8;mist.color=Color(0.65,0.85,0.72,0.055);mist.z_index=6;add_child(mist)

func _build_vignette()->void:
	var layer:=CanvasLayer.new();layer.name="ForestLighting";layer.layer=0;add_child(layer)
	var vignette:=ColorRect.new();vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);vignette.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material:=ShaderMaterial.new();var shader:=Shader.new();shader.code="shader_type canvas_item; void fragment(){vec2 p=UV-vec2(0.5);float edge=smoothstep(0.28,0.72,length(p));COLOR=vec4(0.01,0.035,0.02,edge*0.48);}";material.shader=shader;vignette.material=material;layer.add_child(vignette)

func _add_boundary(cell:Vector2i,direction:Vector2i)->void:
	var body:=StaticBody2D.new();var shape:=CollisionShape2D.new();var rectangle:=RectangleShape2D.new();rectangle.size=Vector2(TILE,8) if direction.y!=0 else Vector2(8,TILE);shape.shape=rectangle;body.add_child(shape);body.position=_world(cell)+Vector2(direction)*TILE*0.5;add_child(body)
	var outside:Vector2i=cell+direction;var key:int=absi(outside.x*31+outside.y*17)
	var wall:=SlasherForestArt.make_boundary_sprite(direction,key);wall.position=body.position;wall.z_index=2 if direction.y>=0 else -1;actor_layer.add_child(wall)

func _build_boundary_corners(cells:Dictionary)->void:
	var vertices:Dictionary={}
	for cell_value:Variant in cells:
		var cell:Vector2i=Vector2i(cell_value)
		for offset:Vector2i in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]:vertices[cell+offset]=true
	for vertex_value:Variant in vertices:
		var vertex:Vector2i=Vector2i(vertex_value);var quadrants:Array[Vector2i]=[vertex+Vector2i(-1,-1),vertex+Vector2i(0,-1),vertex+Vector2i(-1,0),vertex];var occupied:Array[bool]=[];var occupied_count:=0
		for quadrant:Vector2i in quadrants:
			var present:bool=cells.has(quadrant);occupied.append(present);occupied_count+=1 if present else 0
		if occupied_count not in [1,3]:continue
		var target_state:bool=occupied_count==1;var quadrant_index:=occupied.find(target_state);var corner_index:int=[3,2,1,0][quadrant_index]
		var corner:=SlasherForestArt.make_corner_pillar(corner_index);corner.position=ORIGIN+Vector2(vertex)*TILE;corner.z_index=4;actor_layer.add_child(corner)

func _spawn_player()->void:
	player=PLAYER_SCRIPT.new();player.name="SlasherPlayer";player.position_sanitizer=sanitize_player_position;player.pathfinder=pathfinder;player.setup(run_state);actor_layer.add_child(player);player.global_position=_world(layout.start);player.health_changed.connect(_on_health_changed);player.resource_changed.connect(_on_resource_changed);player.ability_resolved.connect(_on_ability_resolved);player.defeated.connect(_on_player_defeated)
	_restore_active_slasher_state()
	player.add_to_group("slasher_party_target")
	tutorial_origin=player.global_position;tutorial_elapsed=0.0
	if player.item_runtime:player.item_runtime.effect_activated.connect(_show_message)
	var camera:=Camera2D.new();camera.position_smoothing_enabled=true;camera.position_smoothing_speed=7
	# Let the player roam through the central half of the viewport before the camera follows.
	camera.drag_horizontal_enabled=true;camera.drag_vertical_enabled=true
	camera.drag_left_margin=CAMERA_DRAG_MARGIN;camera.drag_right_margin=CAMERA_DRAG_MARGIN;camera.drag_top_margin=CAMERA_DRAG_MARGIN;camera.drag_bottom_margin=CAMERA_DRAG_MARGIN
	player.add_child(camera);player.camera=camera;camera.make_current()
	camera.zoom=Vector2.ONE*_settings().get_float("slasher_zoom",1.30);_settings().settings_changed.connect(_on_game_setting_changed)

func _spawn_enemies()->void:
	enemies_remaining=0;var wolf_counts:Dictionary={};var spawn_index:=0
	for spawn_value:Variant in layout.enemy_spawns:
		var spawn_record:Dictionary=Dictionary(spawn_value);var spawn:Vector2i=Vector2i(spawn_record.get("position",Vector2i.ZERO));var visual_id:=String(spawn_record.get("visual_id",""));var behavior_id:=String(spawn_record.get("behavior_id",""))
		if visual_id.is_empty():
			var spec:=_normal_enemy_spec(spawn_index,wolf_counts);visual_id=String(spec.visual_id);behavior_id=String(spec.behavior_id)
		_spawn_enemy(_world(spawn),visual_id,behavior_id,bool(spawn_record.get("is_boss",false)),bool(spawn_record.get("is_mini_boss",false)));spawn_index+=1
	exit_open=enemies_remaining==0

func _normal_enemy_spec(spawn_index:int,wolf_counts:Dictionary)->Dictionary:
	var wolves:Array[String]=["wolf_vanguard","wolf_lurker","wolf_charger","wolf_hunter","wolf_howler"]
	var unlocked:Array[String]=[]
	for wolf_id:String in wolves:
		if run_state.current_floor>=int(GameBalance.get_slasher_wolf_archetype(wolf_id).get("unlock_floor",1)):unlocked.append(wolf_id)
	var use_wolf:bool=spawn_index==0 or (spawn_index+run_state.current_floor)%2==0
	if use_wolf and not unlocked.is_empty():
		var wolf_id:String=unlocked[unlocked.size()-1] if spawn_index==0 else unlocked[(spawn_index+run_state.current_floor)%unlocked.size()]
		if int(wolf_counts.get("wolf_howler",0))>0 and wolf_id=="wolf_lurker":wolf_id="wolf_vanguard"
		if wolf_id in ["wolf_hunter","wolf_howler"] and int(wolf_counts.get(wolf_id,0))>=1:wolf_id="wolf_vanguard" if (spawn_index%2)==0 else "wolf_charger"
		wolf_counts[wolf_id]=int(wolf_counts.get(wolf_id,0))+1;return {"visual_id":wolf_id,"behavior_id":wolf_id}
	var other_enemies:Array[String]=[];other_enemies.assign(DungeonRuntimeProfile.get_profile(run_state.active_dungeon_id).get("slasher_enemies",["thornback_boar","spore_beast","briar_guardian","ice_mage"]))
	return {"visual_id":other_enemies[(spawn_index+run_state.current_floor-1)%other_enemies.size()],"behavior_id":""}

func _spawn_enemy(world_position:Vector2,visual_id:String,behavior_id:String="",is_boss:bool=false,is_mini_boss:bool=false)->SlasherEnemy:
	var enemy:SlasherEnemy=ENEMY_SCRIPT.new();enemy.name="ForestBoss" if is_boss else ("EliteGuardian" if is_mini_boss else visual_id.to_pascal_case());enemy.configure(run_state.current_floor,is_boss,visual_id,is_mini_boss,behavior_id);enemy.pathfinder=pathfinder;actor_layer.add_child(enemy);enemy.global_position=world_position;enemy.target=player;enemy.defeated.connect(_on_enemy_defeated);enemy.reinforcement_requested.connect(_on_reinforcement_requested);enemies_remaining+=1;return enemy

func _on_reinforcement_requested(archetypes:Array,origin:Vector2)->void:
	var cap:int=int(GameBalance.get_slasher_wolfmaster_tuning().get("reinforcement_cap",5));var active_wolves:int=get_tree().get_nodes_in_group("slasher_wolf").size();var available:int=maxi(0,cap-active_wolves)
	for index:int in mini(available,archetypes.size()):
		var angle:float=TAU*float(index)/maxf(1.0,float(archetypes.size()))+0.35;var requested:=origin+Vector2(cos(angle),sin(angle))*110.0;var spawn_position:=sanitize_player_position(requested);var wolf_id:=String(archetypes[index]);_spawn_enemy(spawn_position,wolf_id,wolf_id)

func _spawn_loot()->void:
	loot_nodes.clear();var loot_index:=0
	for spawn_value:Variant in layout.loot_spawns:
		var spawn:Vector2i=spawn_value;var area:=Area2D.new();area.name="ForestCache";area.position=_world(spawn);var shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=14;shape.shape=circle;area.add_child(shape)
		var kind:=String(["gold","potion","key"][loot_index%3]);var sprite:=SlasherForestArt.make_sprite(kind);sprite.position=Vector2(0,-8);area.add_child(sprite);area.add_child(_glow(Color("#f3d366"),18));actor_layer.add_child(area);loot_nodes.append(area);area.set_meta("kind",kind);loot_index+=1

func _process(delta:float)->void:
	if not is_instance_valid(player):return
	_tick_benched_party(delta)
	var abandon_is_suppressed:bool=suppress_abandon_frames>0
	suppress_abandon_frames=maxi(0,suppress_abandon_frames-1)
	if tutorial_layer!=null:
		tutorial_elapsed+=delta
		if tutorial_elapsed>14.0 or player.global_position.distance_to(tutorial_origin)>150.0:_dismiss_tutorial()
	var codex_open:bool=codex!=null and codex.visible
	var modal_open:bool=(merchant_shop_panel!=null and merchant_shop_panel.visible) or (relic_modal!=null and relic_modal.visible)
	player.input_locked=modal_open or codex_open
	if Input.is_action_just_pressed("character_menu") and not modal_open:
		if run_state.get_active_party_ids().size()>1:_cycle_party_member();return
		_open_codex();return
	# Modal controls consume Escape themselves. Never let the same keypress fall through to abandon.
	if modal_open or codex_open:return
	if Input.is_action_just_pressed("extract_expedition") and run_state.can_extract():
		if controller and controller.has_method("extract_expedition"):controller.extract_expedition()
		return
	var interaction_used:=false;var nearby_chest:SlasherBreakableProp=_nearby_chest()
	if nearby_chest!=null:
		_show_message("Locked chest · find a key." if run_state.keys<=0 else "Chest ready · press E to unlock and open.",0.15)
		if Input.is_action_just_pressed("interact"):
			interaction_used=true;player.basic_mouse_held=false
			if run_state.keys<=0:_show_message("The chest is locked. Find a key.")
			else:run_state.keys-=1;nearby_chest.open_chest();_show_message("The key turns. The chest opens.")
	for loot in loot_nodes.duplicate():
		if is_instance_valid(loot) and player.global_position.distance_to(loot.global_position)<30:_collect_loot(loot);loot_nodes.erase(loot)
	if has_dungeon_merchant and player.global_position.distance_to(merchant_position)<48:
		var merchant_id:=String(GameBalance.get_dungeon(run_state.active_dungeon_id).get("merchant_id",run_state.active_dungeon_id));var merchant:=GameBalance.get_merchant(merchant_id);var merchant_name:=String(merchant.get("name","Dungeon merchant"))
		_show_message("%s · press E to trade."%merchant_name,0.15)
		if not interaction_used and Input.is_action_just_pressed("interact") and merchant_shop_panel:player.basic_mouse_held=false;merchant_shop_panel.setup(run_state,merchant_id,"dungeon");merchant_shop_panel.open()
	if player.global_position.distance_to(exit_position)<42:
		if exit_open:_complete_floor()
		else:_show_message("The way onward is sealed · %d foes remain."%enemies_remaining,0.15)
	if Input.is_action_just_pressed("slasher_potion"):_use_potion()
	for slot_index:int in range(4):
		if Input.is_action_just_pressed("slasher_consumable_%d"%(slot_index+1)):_use_consumable_slot(slot_index);break
	if Input.is_action_just_pressed("slasher_abandon") and not abandon_is_suppressed:_abandon_run()
	_refresh_hud()

func _on_enemy_defeated(enemy:SlasherEnemy,reward:int)->void:
	run_state.record_enemy_defeat(enemy.visual_id);enemies_remaining=maxi(0,enemies_remaining-1);run_state.gold+=run_state.apply_reward_bonus(reward,"gold")
	if player.item_runtime:player.item_runtime.handle_event({"trigger":"boss_kill" if enemy.boss else ("elite_kill" if enemy.elite else "enemy_kill"),"enemy":enemy})
	if enemies_remaining==0:exit_open=true;_show_message("Encounter cleared · the way onward opens.")

func _complete_floor()->void:
	if floor_reward_claimed:return
	floor_reward_claimed=true;_close_codex()
	var rewards:=GameBalance.get_slasher_balance("rewards")
	# TUNING: Campaign, elite, boss, and Endless XP values live together in slasher_balance.json rewards.
	var xp:float=float(rewards.get("floor_xp_base",45))+run_state.current_floor*float(rewards.get("floor_xp_per_depth",5))
	if bool(layout.get("is_elite_floor",false)):xp+=float(rewards.get("elite_floor_bonus",55))
	if bool(layout.get("is_boss_floor",false)):xp+=float(rewards.get("campaign_boss_bonus",70))
	if run_state.slasher_endless_mode:xp*=float(rewards.get("endless_xp_multiplier",0.35))
	run_state.gain_xp(maxi(1,int(round(xp))),"Slasher Forest%s floor %d cleared"%[" Endless" if run_state.slasher_endless_mode else "",run_state.current_floor])
	run_state.mark_extraction_available()
	if controller and controller.has_method("complete_slasher_dungeon_floor"):controller.complete_slasher_dungeon_floor()
	elif controller and controller.has_method("complete_slasher_forest_floor"):controller.complete_slasher_forest_floor()
func _on_player_defeated()->void:
	_close_codex()
	var fallen_id:=run_state.active_character_id;var death_position:=player.global_position;var fallen_summon:Node=player.companion
	_store_active_slasher_state()
	if not is_instance_valid(fallen_summon):fallen_summon=active_summons.get(fallen_id) as Node
	if is_instance_valid(fallen_summon):fallen_summon.queue_free()
	active_summons.erase(fallen_id);player.companion=null
	if run_state.record_active_character_death("Fell in %s (Slasher)" % String(GameBalance.get_dungeon(run_state.active_dungeon_id).get("name", "the dungeon"))):
		player.setup(run_state);_restore_active_slasher_state();player.global_position=sanitize_player_position(death_position);_show_message("A party member has fallen forever. Control passes to %s." % run_state.selected_class_name);_flash_fallen_portrait(fallen_id);_refresh_hud();return
	if controller and controller.has_method("return_to_tavern"):controller.return_to_tavern("death","The last party member falls with %d unbanked gold."%run_state.gold)

func _cycle_party_member()->void:
	var swap_position:=player.global_position;var outgoing_id:=run_state.active_character_id
	_store_active_slasher_state()
	if is_instance_valid(player.companion):active_summons[outgoing_id]=player.companion
	player.companion=null;player.velocity=Vector2.ZERO;player.basic_mouse_held=false
	if not run_state.cycle_active_character():return
	player.setup(run_state);player.companion=active_summons.get(run_state.active_character_id) as CharacterBody2D;_restore_active_slasher_state();player.global_position=sanitize_player_position(swap_position)
	for enemy in get_tree().get_nodes_in_group("slasher_enemy"):
		if enemy is SlasherEnemy:enemy.target=player
	_show_message("Now controlling %s · %s"%[run_state.get_active_character().display_name,run_state.selected_class_name]);_refresh_hud()

func _store_active_slasher_state()->void:
	if run_state==null or run_state.campaign==null or not run_state.campaign.expedition.active or not is_instance_valid(player):return
	var character_id:=run_state.active_character_id;var runtime:Dictionary=run_state.campaign.expedition.member_runtime.get(character_id,{})
	runtime["health"]=player.health;runtime["resource"]=run_state.class_resource;runtime["slasher"]=player.snapshot_party_state();run_state.campaign.expedition.member_runtime[character_id]=runtime
	var member:=run_state.campaign.character(character_id)
	if member!=null:member.current_health=player.health

func _restore_active_slasher_state()->void:
	if run_state==null or run_state.campaign==null or not is_instance_valid(player):return
	var runtime:Dictionary=run_state.campaign.expedition.member_runtime.get(run_state.active_character_id,{})
	if int(runtime.get("health",-1))>=0:player.health=clampi(int(runtime.health),0,player.max_health);run_state.current_health=player.health
	if runtime.has("resource"):run_state.class_resource=clampi(int(runtime.resource),0,run_state.get_class_resource_max())
	player.restore_party_state(Dictionary(runtime.get("slasher",{})))

func _tick_benched_party(delta:float)->void:
	if run_state==null or run_state.campaign==null or not run_state.campaign.expedition.active:return
	for character_id in run_state.get_active_party_ids():
		if character_id==run_state.active_character_id:continue
		var runtime:Dictionary=run_state.campaign.expedition.member_runtime.get(character_id,{})
		var state:Dictionary=Dictionary(runtime.get("slasher",{}))
		var cooldowns:Dictionary=Dictionary(state.get("cooldowns",{}))
		for key in cooldowns:cooldowns[key]=maxf(0.0,float(cooldowns[key])-delta)
		state["cooldowns"]=cooldowns
		for timer_name in ["invulnerable","defense_window","hidden_time","consumable_speed_time","movement_debuff_time"]:state[timer_name]=maxf(0.0,float(state.get(timer_name,0.0))-delta)
		if float(state.get("hidden_time",0.0))<=0.0:state["is_hidden"]=false
		if float(state.get("consumable_speed_time",0.0))<=0.0:state["consumable_speed_multiplier"]=1.0
		if float(state.get("movement_debuff_time",0.0))<=0.0:state["movement_debuff_multiplier"]=1.0
		if float(state.get("defense_window",0.0))<=0.0 and String(state.get("defense_kind",""))!="retribution_ready":state["defense_kind"]=""
		var item_state:Dictionary=Dictionary(state.get("item_runtime",{}))
		var item_cooldowns:Dictionary=Dictionary(item_state.get("cooldowns",{}))
		for key in item_cooldowns:item_cooldowns[key]=maxf(0.0,float(item_cooldowns[key])-delta)
		item_state["cooldowns"]=item_cooldowns;state["item_runtime"]=item_state
		runtime["slasher"]=state;run_state.campaign.expedition.member_runtime[character_id]=runtime
func _abandon_run()->void:
	_close_codex()
	if controller and controller.has_method("return_to_tavern"):controller.return_to_tavern("abandon","You abandon the Slasher expedition and return with %d gold."%run_state.gold)

func _use_potion()->void:
	var consumables:=run_state.get_consumables();var index:=consumables.find("healing_potion")
	if index<0:_show_message("No healing potion available.");return
	run_state.remove_consumable_at(index);player.heal(6+run_state.get_derived_stat("potion_heal_bonus"));player.item_runtime.handle_event({"trigger":"potion_use"});_show_message("Healing potion consumed.")

func _use_consumable_slot(index:int)->void:
	var consumables:Array[String]=run_state.get_consumables()
	if index<0 or index>=consumables.size():_show_message("Consumable slot %d is empty."%(index+1));return
	var consumable_id:String=consumables[index];var record:Dictionary=GameBalance.get_consumable(consumable_id);var effects:Dictionary=Dictionary(record.get("effects",{}))
	run_state.remove_consumable_at(index);player.apply_consumable(effects)
	if String(effects.get("item_trigger",""))=="potion" and player.item_runtime:player.item_runtime.handle_event({"trigger":"potion_use"})
	_show_message("Used %s from slot %d."%[String(record.get("name",consumable_id.capitalize())),index+1]);_refresh_hud()
func _collect_loot(loot:Area2D)->void:
	loot.set_deferred("monitoring",false)
	match String(loot.get_meta("kind","gold")):
		"potion":
			if run_state.add_consumable("healing_potion"):_show_message("Healing potion collected.")
			else:_show_message("Consumable pouch is full.")
		"key":run_state.keys+=1;_show_message("Forest key collected.")
		_:
			var rewards:=GameBalance.get_slasher_balance("rewards");var raw_amount:int=int(loot.get_meta("amount",int(rewards.get("loot_gold_base",5))+run_state.current_floor));var amount:=run_state.apply_reward_bonus(raw_amount,"gold");run_state.gold+=amount;_show_message("Collected %d gold."%amount)
	var tween:=create_tween();tween.set_parallel(true);tween.tween_property(loot,"global_position",player.global_position-Vector2(0,28),0.22).set_trans(Tween.TRANS_QUAD);tween.tween_property(loot,"scale",Vector2(1.35,1.35),0.16);tween.tween_property(loot,"modulate:a",0.0,0.22);tween.chain().tween_callback(loot.queue_free)

func _on_prop_broken(_prop:SlasherBreakableProp,kind:String,cell:Vector2i)->void:
	if pathfinder!=null:pathfinder.set_cell_blocked(cell,false)
	var prop_tuning:Dictionary=GameBalance.get_slasher_balance("breakable_props");var drop_tuning:Dictionary=Dictionary(prop_tuning.get("drops",{}));var outcome:Dictionary=SlasherBreakableProp.deterministic_gold_drop(run_state.get_current_floor_seed(),run_state.current_floor,cell,kind,drop_tuning)
	if bool(outcome.get("drops",false)):_spawn_gold_drop(_world(cell),int(outcome.get("amount",1)))

func _spawn_gold_drop(world_position:Vector2,amount:int)->void:
	var area:=Area2D.new();area.name="PropGoldDrop";area.position=world_position;var shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=14;shape.shape=circle;area.add_child(shape);var sprite:=SlasherForestArt.make_sprite("gold");sprite.position=Vector2(0,-8);area.add_child(sprite);area.add_child(_glow(Color("#f3d366"),16));area.set_meta("kind","gold");area.set_meta("amount",amount);actor_layer.add_child(area);loot_nodes.append(area)

func _on_chest_opened(_chest:SlasherBreakableProp,cell:Vector2i)->void:
	if pathfinder!=null:pathfinder.set_cell_blocked(cell,false)
	relic_choice_source="chest";var cycle:int=maxi(0,run_state.get_slasher_cycle_number()-1) if run_state.slasher_endless_mode else 0
	var choices:Array[String]=run_state.generate_slasher_chest_choices(run_state.current_floor,"chest_%d_%d"%[cell.x,cell.y],cycle);relic_modal.open(run_state,choices,true)

func _offer_starter_relic()->void:
	if relic_modal==null or relic_modal.visible:return
	relic_choice_source="starter";var choices:Array[String]=run_state.generate_slasher_chest_choices(1,"starter",0);relic_modal.open(run_state,choices,true)

func _claim_relic(item_id:String)->void:
	var logs:Array[String]=run_state.choose_starter_item(item_id) if relic_choice_source=="starter" else run_state.choose_chest_item(item_id)
	if player.item_runtime:player.item_runtime.refresh()
	player.setup(run_state);relic_modal.finish();relic_choice_source="";_refresh_hud()
	_show_message(" ".join(logs))

func _spawn_pickup_drop(kind:String,world_position:Vector2)->void:
	var area:=Area2D.new();area.name="Chest%sDrop"%kind.capitalize();area.position=world_position;var shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=14;shape.shape=circle;area.add_child(shape);var sprite:=SlasherForestArt.make_sprite(kind);sprite.position=Vector2(0,-8);area.add_child(sprite);area.add_child(_glow(Color("#f3d366"),16));area.set_meta("kind",kind);actor_layer.add_child(area);loot_nodes.append(area)

func _nearby_chest()->SlasherBreakableProp:
	var prop_tuning:Dictionary=GameBalance.get_slasher_balance("breakable_props");var chest_tuning:Dictionary=Dictionary(prop_tuning.get("chest",{}));var interaction_radius:float=float(chest_tuning.get("interaction_radius",52.0))
	for node_value:Variant in get_tree().get_nodes_in_group("slasher_chest"):
		var chest:SlasherBreakableProp=node_value as SlasherBreakableProp
		if is_instance_valid(chest) and not chest.is_open and not chest.destroyed and player.global_position.distance_to(chest.global_position)<=interaction_radius:return chest
	return null

func _build_hud()->void:
	var canvas:=CanvasLayer.new();canvas.name="HUD";canvas.layer=10;add_child(canvas)
	_build_party_strip(canvas)
	var panel:=PanelContainer.new();panel.set_anchors_preset(Control.PRESET_TOP_WIDE);panel.offset_left=340;panel.offset_top=18;panel.offset_right=-340;panel.offset_bottom=72;panel.add_theme_stylebox_override("panel",_panel_style(Color("#101c18e8"),Color("#557c54")));canvas.add_child(panel)
	var status:=VBoxContainer.new();status.add_theme_constant_override("separation",2);panel.add_child(status)
	objective_label=_label(Vector2.ZERO,Vector2(360,26),17);objective_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;status.add_child(objective_label)
	_build_resource_hud(canvas)
	message_label=Label.new();message_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM);message_label.position=Vector2(-360,-150);message_label.size=Vector2(720,42);message_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;message_label.add_theme_font_size_override("font_size",17);message_label.add_theme_color_override("font_color",Color("#ffe4a1"));canvas.add_child(message_label)
	merchant_shop_panel=MERCHANT_PANEL.new();merchant_shop_panel.name="SlasherMerchantShop";merchant_shop_panel.purchase_completed.connect(_show_message);merchant_shop_panel.closed.connect(_suppress_abandon_once);canvas.add_child(merchant_shop_panel)
	codex=CODEX.new();codex.name="SlasherCodex";codex.closed.connect(_suppress_abandon_once);canvas.add_child(codex)
	relic_modal=RELIC_MODAL.new();relic_modal.name="SlasherRelicChoice";relic_modal.relic_selected.connect(_claim_relic);canvas.add_child(relic_modal)
	if run_state.current_floor==1:_build_control_tutorial()

func _refresh_hud()->void:
	if not is_instance_valid(player) or objective_label==null:return
	_store_active_slasher_state();_refresh_party_strip()
	var depth_text:String="ENDLESS CYCLE %d · FLOOR %d"%[run_state.get_slasher_cycle_number(),run_state.current_floor] if run_state.slasher_endless_mode else "FLOOR %d/%d"%[run_state.current_floor,run_state.max_floors]
	var encounter_text:String="BOSS" if bool(layout.get("is_boss_floor",false)) else ("ELITE GUARDIAN" if bool(layout.get("is_elite_floor",false)) else ("GATE OPEN" if exit_open else "%d FOES"%enemies_remaining))
	objective_label.text="VERDANT FOREST  ·  %s  ·  %s"%[depth_text,encounter_text]
	health_bar.max_value=maxi(1,player.max_health);health_bar.value=player.health;health_value_label.text="%d / %d"%[player.health,player.max_health]
	resource_bar.max_value=maxi(1,run_state.get_class_resource_max());resource_bar.value=run_state.class_resource;resource_value_label.text="%s  %d / %d"%[run_state.get_class_resource_name(),run_state.class_resource,run_state.get_class_resource_max()]
	gold_value_label.text=str(run_state.gold);key_value_label.text=str(run_state.keys);potion_value_label.text=str(run_state.get_consumables().count("healing_potion"))

func _build_party_strip(canvas:CanvasLayer)->void:
	var panel:=PanelContainer.new();panel.name="PartyStripPanel";panel.position=Vector2(18,12);panel.custom_minimum_size=Vector2(300,84);panel.add_theme_stylebox_override("panel",_panel_style(Color("#101713e8"),Color("#80602d")));canvas.add_child(panel)
	var body:=VBoxContainer.new();body.add_theme_constant_override("separation",0);panel.add_child(body);party_strip=HBoxContainer.new();party_strip.name="PartyStrip";party_strip.add_theme_constant_override("separation",2);body.add_child(party_strip)
	var hint:=Label.new();hint.text="TAB / LB  ·  SWAP";hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.add_theme_font_size_override("font_size",10);hint.add_theme_color_override("font_color",Color("c9aa6a"));body.add_child(hint);_rebuild_party_strip()

func _rebuild_party_strip()->void:
	if party_strip==null:return
	for child in party_strip.get_children():child.free()
	party_portraits.clear()
	for character_id in run_state.get_active_party_ids():
		var member:=run_state.campaign.character(character_id)
		if member==null:continue
		var path:="res://assets/roster_portraits/%s_%d.png"%[member.class_id,member.portrait_variant];var texture:Texture2D=load(path) if ResourceLoader.exists(path) else null
		var portrait:PartyHealthPortrait=PARTY_HEALTH_PORTRAIT.new();portrait.name="PartyPortrait_%s"%character_id;portrait.setup(character_id,member.display_name,texture);party_strip.add_child(portrait);party_portraits[character_id]=portrait

func _refresh_party_strip()->void:
	for character_id in party_portraits:
		var member:=run_state.campaign.character(character_id);var portrait:PartyHealthPortrait=party_portraits[character_id]
		if member!=null and is_instance_valid(portrait):portrait.update_state(member.current_health,member.max_health,character_id==run_state.active_character_id)

func _flash_fallen_portrait(character_id:String)->void:
	var portrait:PartyHealthPortrait=party_portraits.get(character_id) as PartyHealthPortrait
	if not is_instance_valid(portrait):_rebuild_party_strip();return
	portrait.update_state(0,maxi(1,portrait.maximum),false);var tween:=create_tween();tween.tween_property(portrait,"modulate",Color(1.0,0.22,0.18,0.9),0.16);tween.tween_interval(0.35);tween.tween_property(portrait,"modulate:a",0.0,0.28);tween.tween_callback(_rebuild_party_strip)

func _build_resource_hud(canvas:CanvasLayer)->void:
	var hud:=Control.new();hud.name="ResourceHUD";hud.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT);hud.position=Vector2(-358,-385);hud.size=Vector2(340,367);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(hud)
	var frame:=TextureRect.new();frame.name="Ornament";frame.texture=RESOURCE_HUD_FRAME;frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);frame.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;frame.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;frame.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.add_child(frame)
	gold_value_label=_add_resource_counter(hud,GOLD_UI_ICON,Vector2(253,39),"Gold")
	key_value_label=_add_resource_counter(hud,KEY_UI_ICON,Vector2(253,114),"Keys")
	potion_value_label=_add_resource_counter(hud,POTION_UI_ICON,Vector2(253,186),"Potions")
	health_bar=_add_hud_bar(hud,Vector2(66,270),Vector2(198,24),Color("#bd1724"),Color("#ff5960"))
	resource_bar=_add_hud_bar(hud,Vector2(66,321),Vector2(198,24),_class_resource_color(),Color("#6ec8ff"))
	health_value_label=_bar_value_label(hud,Vector2(66,266),Vector2(198,32));resource_value_label=_bar_value_label(hud,Vector2(66,317),Vector2(198,32))

func _add_resource_counter(parent:Control,texture:Texture2D,position_value:Vector2,tooltip:String)->Label:
	var icon:=TextureRect.new();icon.texture=texture;icon.position=position_value;icon.size=Vector2(48,48);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.tooltip_text=tooltip;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(icon)
	var value:=_label(position_value+Vector2(-70,8),Vector2(66,32),18);value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;value.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;value.add_theme_color_override("font_outline_color",Color("#080b10"));value.add_theme_constant_override("outline_size",5);parent.add_child(value);return value

func _add_hud_bar(parent:Control,position_value:Vector2,size_value:Vector2,fill_color:Color,highlight:Color)->ProgressBar:
	var bar:=ProgressBar.new();bar.position=position_value;bar.size=size_value;bar.show_percentage=false;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var background:=StyleBoxFlat.new();background.bg_color=Color("#080b10e8");background.corner_radius_top_left=6;background.corner_radius_top_right=6;background.corner_radius_bottom_left=6;background.corner_radius_bottom_right=6
	var fill:=StyleBoxFlat.new();fill.bg_color=fill_color;fill.border_color=highlight;fill.border_width_top=2;fill.corner_radius_top_left=6;fill.corner_radius_top_right=6;fill.corner_radius_bottom_left=6;fill.corner_radius_bottom_right=6
	bar.add_theme_stylebox_override("background",background);bar.add_theme_stylebox_override("fill",fill);parent.add_child(bar);return bar

func _bar_value_label(parent:Control,position_value:Vector2,size_value:Vector2)->Label:
	var label:=_label(position_value,size_value,15);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.add_theme_color_override("font_outline_color",Color("#080b10"));label.add_theme_constant_override("outline_size",4);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(label);return label

func _class_resource_color()->Color:
	match run_state.selected_class_id:
		"warrior":return Color("#d88322")
		"healer":return Color("#d7b944")
		"tank":return Color("#7994a8")
		"rogue":return Color("#8c4ac7")
		"summoner":return Color("#4ba866")
		_:return Color("#245ee8")

func _build_control_tutorial()->void:
	tutorial_layer=CanvasLayer.new();tutorial_layer.name="FirstFloorControls";tutorial_layer.layer=3;add_child(tutorial_layer)
	var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0.01,0.04,0.025,0.16);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;tutorial_layer.add_child(shade)
	_add_tutorial_label("MOVE\n[ W ]\n[A][S][D]",Vector2(-90,88),Vector2(180,112))
	_add_tutorial_label("BASIC ATTACK\n[ LEFT MOUSE ] / [ A ]",Vector2(105,12),Vector2(285,64))
	_add_tutorial_label("MOBILITY\n[ RIGHT MOUSE ] / [ B ]",Vector2(105,82),Vector2(285,64))
	_add_tutorial_label("SPECIAL\n[ SPACE ] / [ X ]",Vector2(105,-58),Vector2(285,64))
	_add_tutorial_label("DEFEND\n[ SHIFT + LEFT MOUSE ] / [ Y ]",Vector2(-390,22),Vector2(300,72))
	_add_tutorial_label("CHARACTER & JOURNAL\n[ M ] or [ TAB ] / [ START ]",Vector2(-390,-64),Vector2(300,72))
	_add_tutorial_label("USE CONSUMABLE SLOTS\n[ 1 ] [ 2 ] [ 3 ] [ 4 ]",Vector2(-90,-62),Vector2(240,64))

func _add_tutorial_label(text:String,offset:Vector2,size:Vector2)->void:
	var label:=Label.new();label.set_anchors_preset(Control.PRESET_CENTER);label.position=offset;label.size=size;label.text=text;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",16);label.add_theme_color_override("font_color",Color(0.82,0.94,0.84,0.78));label.add_theme_color_override("font_outline_color",Color(0.02,0.08,0.04,0.9));label.add_theme_constant_override("outline_size",5);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;tutorial_layer.add_child(label)

func _dismiss_tutorial()->void:
	if tutorial_layer==null:return
	var departing:CanvasLayer=tutorial_layer;tutorial_layer=null;var tween:=create_tween();tween.set_parallel(true)
	for child_value:Variant in departing.get_children():
		var child:CanvasItem=child_value as CanvasItem
		if child!=null:tween.tween_property(child,"modulate:a",0.0,0.45)
	tween.chain().tween_callback(departing.queue_free)

func _open_codex()->void:
	if codex==null or merchant_shop_panel.visible:return
	player.basic_mouse_held=false;codex.open(run_state,player)
func _close_codex()->void:
	if codex!=null and codex.visible:codex.close()
	elif get_tree()!=null:get_tree().paused=false
func _suppress_abandon_once()->void:suppress_abandon_frames=2
func _on_health_changed(_current:int,_maximum:int)->void:_refresh_hud()
func _on_resource_changed(_current:int,_maximum:int)->void:_refresh_hud()
func _on_game_setting_changed(key:String,value:Variant)->void:
	if key in ["slasher_zoom","reset"] and is_instance_valid(player) and player.camera!=null:player.camera.zoom=Vector2.ONE*(_settings().get_float("slasher_zoom",1.30) if key=="reset" else float(value))
func _on_ability_resolved(result:Dictionary)->void:
	if bool(result.get("started",false)):_dismiss_tutorial()
	var failure:=String(result.get("failure",""))
	if not failure.is_empty():_show_message(failure)
func _show_message(text:String,duration:float=2.5)->void:
	if message_label==null:return
	message_label.text=text
	if duration>0.2:
		var tween:=create_tween();tween.tween_interval(duration);tween.tween_callback(func():
			if is_instance_valid(message_label) and message_label.text==text:message_label.text="")
func _entry_fade()->void:
	var layer:=CanvasLayer.new();layer.layer=50;layer.process_mode=Node.PROCESS_MODE_ALWAYS;add_child(layer)
	var fade:=ColorRect.new();fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);fade.color=Color.BLACK;fade.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(fade)
	# The floor-one relic choice pauses immediately, so this transition must continue while paused.
	var tween:=create_tween();tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS);tween.tween_property(fade,"modulate:a",0.0,0.65);tween.tween_callback(layer.queue_free)
func _glow(color:Color,radius:float)->Polygon2D:
	var glow:=Polygon2D.new();var points:=PackedVector2Array()
	for index in 20:var angle:=TAU*index/20.0;points.append(Vector2(cos(angle),sin(angle))*radius)
	glow.polygon=points;glow.color=Color(color.r,color.g,color.b,0.18);glow.z_index=-1;return glow
func _panel_style(fill:Color,border:Color)->StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=fill;style.border_color=border;style.set_border_width_all(2);style.set_corner_radius_all(8);style.set_content_margin_all(10);return style
func _label(pos:Vector2,size:Vector2,font_size:int)->Label:
	var label:=Label.new();label.position=pos;label.custom_minimum_size=size;label.add_theme_font_size_override("font_size",font_size);return label
func _direction(name:String)->Vector2i:
	match name:
		"up":return Vector2i.UP
		"right":return Vector2i.RIGHT
		"down":return Vector2i.DOWN
		_:return Vector2i.LEFT
func _world(cell:Vector2i)->Vector2:return ORIGIN+Vector2(cell)*TILE+Vector2(TILE/2,TILE/2)
func _world_cell(point:Vector2)->Vector2i:return Vector2i(floori((point.x-ORIGIN.x)/TILE),floori((point.y-ORIGIN.y)/TILE))
func is_world_position_walkable(point:Vector2)->bool:return Dictionary(layout.get("cells",{})).has(_world_cell(point))
func sanitize_player_position(point:Vector2)->Vector2:
	if is_world_position_walkable(point):return point
	var nearest:Vector2=Vector2.ZERO;var nearest_distance:float=INF;var cells:Dictionary=layout.get("cells",{})
	for cell_value:Variant in cells:
		var center:Vector2=_world(Vector2i(cell_value));var distance:float=point.distance_squared_to(center)
		if distance<nearest_distance:nearest_distance=distance;nearest=center
	return nearest
