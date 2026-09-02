extends SceneTree

const SLASHER_SCENE := preload("res://scenes/slasher/SlasherForest.tscn")
const SLASHER_RESOURCE_HUD := preload("res://assets/slasher/ui/slasher_resource_hud_frame.png")
const SETTINGS_SERVICE:=preload("res://scripts/game/game_settings.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_ensure_slasher_actions()
	var failures: Array[String] = []
	var forest := GameBalance.get_dungeon("forest")
	_expect(forest.get("supported_modes",[]).has("strategy"),"Forest must support Strategy",failures)
	_expect(forest.get("supported_modes",[]).has("slasher"),"Forest must support Slasher",failures)
	var forest_slasher:Dictionary=Dictionary(forest.get("slasher",{}));_expect(int(forest.get("floors",0))==5 and int(forest_slasher.get("campaign_floors",0))==8,"Strategy must remain five floors while Slasher uses eight",failures);_expect(int(forest_slasher.get("elite_floor_in_cycle",0))==5 and int(forest_slasher.get("cycle_length",0))==8,"Slasher elite/boss cycle tuning is incorrect",failures)
	_expect(GameBalance.get_dungeon("crypt").get("supported_modes",[]).has("slasher") and String(GameBalance.get_dungeon("crypt").get("slasher_runtime",""))=="crypt","Crypt must expose its dedicated Slasher runtime",failures)
	_expect(is_equal_approx(float(SETTINGS_SERVICE.DEFAULTS.get("slasher_zoom",0.0)),1.30),"Default Slasher zoom must be 1.30x",failures)
	_expect(SETTINGS_SERVICE.RESOLUTIONS.size()==4 and SETTINGS_SERVICE.RESOLUTIONS.has(Vector2i(1920,1080)),"Supported display resolutions are incomplete",failures)
	var input_tuning:Dictionary=GameBalance.get_slasher_balance("input");_expect(is_equal_approx(float(input_tuning.get("held_basic_cooldown_multiplier",0.0)),1.5),"Held basic cooldown multiplier is incorrect",failures)
	var options_panel:=GameOptionsPanel.new();root.add_child(options_panel);options_panel.setup(false);_expect(options_panel.resolution_control!=null,"Options panel did not build display controls",failures);options_panel.queue_free()
	var progression_overlay:=SlasherProgressionOverlay.new();root.add_child(progression_overlay);await process_frame;var progression_frame:PanelContainer=progression_overlay.get_child(1) as PanelContainer;_expect(progression_frame!=null and progression_frame.anchor_left==0.5 and progression_frame.offset_left==-510 and progression_frame.offset_right==510,"Slasher progression overlay is not centered",failures);progression_overlay.queue_free()
	var breakable_tuning:Dictionary=GameBalance.get_slasher_balance("breakable_props");_expect(breakable_tuning.has("tree_large") and breakable_tuning.has("barrel") and breakable_tuning.has("rock") and breakable_tuning.has("chest"),"Breakable prop records are incomplete",failures)
	var deterministic_matches:=true;var drop_count:=0;var drop_record:Dictionary=Dictionary(breakable_tuning.get("drops",{}))
	for sample in 1000:
		var first:Dictionary=SlasherBreakableProp.deterministic_gold_drop(9001,2,Vector2i(sample,sample%31),"barrel",drop_record);var second:Dictionary=SlasherBreakableProp.deterministic_gold_drop(9001,2,Vector2i(sample,sample%31),"barrel",drop_record)
		if first!=second:deterministic_matches=false
		if bool(first.get("drops",false)):drop_count+=1;_expect(int(first.get("amount",0)) in [1,2,3],"Breakable gold amount escaped configured bounds",failures)
	_expect(deterministic_matches,"Breakable prop drops are not deterministic",failures);_expect(drop_count>=80 and drop_count<=160,"Breakable prop drop distribution is not near 12%% (%d/1000)"%drop_count,failures)
	var chest_record:Dictionary=Dictionary(breakable_tuning.get("chest",{}));var chest_reward_a:Dictionary=SlasherBreakableProp.deterministic_chest_reward(444,2,Vector2i(7,9),chest_record);var chest_reward_b:Dictionary=SlasherBreakableProp.deterministic_chest_reward(444,2,Vector2i(7,9),chest_record);_expect(chest_reward_a==chest_reward_b and int(chest_reward_a.get("gold",0))>=4 and int(chest_reward_a.get("gold",0))<=8,"Chest rewards are not deterministic or escaped configured bounds",failures)
	var interaction_chest:=SlasherBreakableProp.new();interaction_chest.setup("chest",Vector2i(3,4));root.add_child(interaction_chest);await process_frame;_expect(interaction_chest.is_in_group("slasher_chest"),"Closed chest is missing its interaction group",failures);var closed_chest_height:=interaction_chest.sprite.texture.get_height();_expect(interaction_chest.open_chest(),"Unlocked chest did not open",failures);_expect(interaction_chest.is_open and not interaction_chest.is_in_group("slasher_damageable") and not interaction_chest.open_chest(),"Chest opening was not exactly once",failures);_expect(interaction_chest.sprite.texture.get_height()>closed_chest_height,"Opened chest did not switch to the taller TX open-chest prop",failures);interaction_chest.queue_free()
	var path_cells:Dictionary={}
	for path_y:int in 3:
		for path_x:int in 5:path_cells[Vector2i(path_x,path_y)]=true
	var pathfinder:=SlasherGridPathfinder.new().configure(path_cells,[{"cell":Vector2i(2,1)}],Vector2.ZERO,48.0);var maze_path:=pathfinder.find_cell_path(Vector2i(0,1),Vector2i(4,1));var maze_start:=pathfinder.cell_to_world(Vector2i(0,1));var maze_goal:=pathfinder.cell_to_world(Vector2i(4,1));var detour_waypoint:=pathfinder.next_waypoint(maze_start,maze_goal);var used_detour:=false
	for maze_cell:Vector2i in maze_path:
		if maze_cell.y!=1:used_detour=true
	_expect(maze_path.size()==7 and used_detour and detour_waypoint!=maze_goal,"Shared unit pathfinding did not route around a blocked cell",failures);pathfinder.set_cell_blocked(Vector2i(2,1),false);_expect(pathfinder.next_waypoint(maze_start,maze_goal)==maze_goal,"Path cache did not invalidate when an obstacle was removed",failures)
	for seed in range(100,150):
		var layout:=SlasherForestGenerator.generate(seed,1+(seed%5))
		_expect(SlasherForestGenerator.layout_is_connected(layout),"Seed %d generated a disconnected floor"%seed,failures)
		_expect(layout.cells.has(layout.start) and layout.cells.has(layout.exit),"Seed %d has invalid endpoints"%seed,failures)
		_expect(not layout.edges.is_empty(),"Seed %d did not classify woodland edges"%seed,failures)
		for spawn_record_value:Variant in layout.enemy_spawns:
			var spawn_record:Dictionary=Dictionary(spawn_record_value);_expect(layout.cells.has(Vector2i(spawn_record.get("position",Vector2i(-1,-1)))),"Seed %d placed enemy outside floor"%seed,failures)
		for prop in layout.solid_props:_expect(layout.cells.has(prop.cell),"Seed %d placed solid prop outside floor"%seed,failures)
	var elite_layout:=SlasherForestGenerator.generate(777,5);var boss_layout:=SlasherForestGenerator.generate(999,8);var endless_elite_layout:=SlasherForestGenerator.generate(1777,13);var endless_boss_layout:=SlasherForestGenerator.generate(1999,16)
	_expect(elite_layout.is_elite_floor and not elite_layout.is_boss_floor and elite_layout.enemy_spawns.size()==1,"Floor five must produce one elite miniboss",failures)
	_expect(boss_layout.is_boss_floor and boss_layout.enemy_spawns.size()==3,"Floor eight must produce one campaign boss and two Guardian escorts",failures)
	var boss_count:=0;var boss_guardian_count:=0;var boss_positions:Dictionary={}
	for boss_spawn_value:Variant in boss_layout.enemy_spawns:
		var boss_spawn_record:Dictionary=Dictionary(boss_spawn_value);boss_count+=1 if bool(boss_spawn_record.get("is_boss",false)) else 0;boss_guardian_count+=1 if String(boss_spawn_record.get("behavior_id",""))=="elite_guardian" and bool(boss_spawn_record.get("is_mini_boss",false)) else 0;boss_positions[Vector2i(boss_spawn_record.position)]=true
	_expect(boss_count==1 and boss_guardian_count==2 and boss_positions.size()==3,"Boss encounter spawn records are missing distinct boss or Guardian roles",failures)
	_expect(endless_elite_layout.is_elite_floor and int(endless_elite_layout.cycle_number)==2,"Endless floor thirteen must repeat the elite encounter",failures)
	_expect(endless_boss_layout.is_boss_floor and int(endless_boss_layout.cycle_number)==2,"Endless floor sixteen must repeat the boss encounter",failures)
	var spawn_state:=RunState.new();spawn_state.current_floor=5;var spawn_picker=SLASHER_SCENE.instantiate();spawn_picker.run_state=spawn_state;var first_counts:Dictionary={};var second_counts:Dictionary={};var first_specs:Array=[];var second_specs:Array=[]
	for spawn_index:int in 12:first_specs.append(spawn_picker._normal_enemy_spec(spawn_index,first_counts))
	for spawn_index:int in 12:second_specs.append(spawn_picker._normal_enemy_spec(spawn_index,second_counts))
	_expect(first_specs==second_specs and String(Dictionary(first_specs[0]).get("behavior_id",""))=="wolf_howler","Wolf archetype introductions are not deterministic by floor and spawn index",failures)
	for forest_spec_value:Variant in first_specs:
		var forest_visual_id:=String(Dictionary(forest_spec_value).get("visual_id",""));_expect(forest_visual_id not in ["poison_ranger","fire_mage"],"Slasher Forest still selected forbidden %s art"%forest_visual_id,failures)
	_expect(int(first_counts.get("wolf_hunter",0))<=1 and int(first_counts.get("wolf_howler",0))<=1,"Wolf pack composition exceeded Hunter or Howler caps",failures);spawn_picker.free()
	var xp_rewards:Dictionary=GameBalance.get_slasher_balance("rewards");var pre_boss_xp:=0
	for xp_floor:int in range(1,8):pre_boss_xp+=int(xp_rewards.floor_xp_base)+xp_floor*int(xp_rewards.floor_xp_per_depth)+(int(xp_rewards.elite_floor_bonus) if xp_floor==5 else 0)
	var boss_xp:int=int(xp_rewards.floor_xp_base)+8*int(xp_rewards.floor_xp_per_depth)+int(xp_rewards.campaign_boss_bonus);_expect(pre_boss_xp==510 and pre_boss_xp+boss_xp==665,"Slasher Forest campaign XP no longer reaches level five on the first boss",failures);_expect(is_equal_approx(float(xp_rewards.endless_xp_multiplier),0.35),"Endless XP multiplier must remain data-driven at 35%",failures)
	var xp_state:=RunState.new();xp_state.active_play_mode=RunState.PLAY_MODE_SLASHER;xp_state.gain_xp(pre_boss_xp,"pre-boss pacing test");_expect(xp_state.get_level()==4,"Hero should remain level four before the first Slasher boss",failures);xp_state.gain_xp(boss_xp,"campaign boss pacing test");_expect(xp_state.get_level()==5,"First Slasher boss should naturally raise the hero to level five",failures)
	for art_key in ["tree_large","tree_wide","tree_small","low_bush_a","rounded_bush","grass_tuft_a","mossy_rock","rock","barrel","exit","merchant","gold","potion","key"]:
		var art:=SlasherForestArt.make_sprite(art_key);_expect(art.texture!=null,"Missing Slasher forest art for %s"%art_key,failures);art.free()
	var ground_a:=SlasherForestArt.make_ground_sprite(Vector2i(7,9),48);var ground_b:=SlasherForestArt.make_ground_sprite(Vector2i(8,9),48)
	_expect(ground_a.texture!=null and ground_a.texture==ground_b.texture,"Slasher ground cells do not share the TX grass atlas",failures)
	_expect(ground_a.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"Slasher TX grass sampling is not nearest-neighbor",failures)
	_expect(ground_a.region_enabled and ground_a.region_rect.size==Vector2(32,32),"Slasher ground cell does not use one 32 px TX atlas tile",failures)
	_expect(ground_a.scale==Vector2(1.5,1.5) and ground_a.region_rect.position.y==0.0,"Slasher TX grass tile is not fitted to the 48 px grid or escaped the grass variant row",failures)
	ground_a.free();ground_b.free()
	for direction in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
		var boundary:=SlasherForestArt.make_boundary_sprite(direction,3);var expected_pieces:=1 if direction.x!=0 else 2;_expect(boundary.get_child_count()==expected_pieces,"TX boundary assembly for %s has the wrong layer count"%direction,failures)
		for piece:Node in boundary.get_children():_expect(piece is Sprite2D and (piece as Sprite2D).texture!=null and (piece as Sprite2D).texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"Missing or filtered TX boundary layer for %s"%direction,failures)
		boundary.free()
	var tx_wall_tip:=SlasherForestArt.make_corner_pillar(0);var tip_sprite:=tx_wall_tip.get_child(0) as Sprite2D;_expect(tip_sprite!=null and tip_sprite.texture.get_width()==10 and tip_sprite.texture.get_height()==10,"TX wall junction does not use the small rounded tip crop",failures);tx_wall_tip.free()
	var tx_barrel:=SlasherForestArt.make_sprite("barrel");var tx_rock:=SlasherForestArt.make_sprite("rock");var tx_chest:=SlasherForestArt.make_sprite("chest")
	_expect(tx_barrel.texture.get_width()==31 and tx_barrel.texture.get_height()==55,"TX barrel crop does not follow the full sprite bounds",failures)
	_expect(tx_rock.texture.get_width()==61 and tx_rock.texture.get_height()==55,"TX rock crop does not follow the full sprite bounds",failures)
	_expect(tx_chest.texture.get_width()==33 and tx_chest.texture.get_height()==32,"TX chest crop does not follow the full sprite bounds",failures)
	tx_barrel.free();tx_rock.free();tx_chest.free()
	var tx_open_chest:=SlasherForestArt.make_sprite("chest_open");_expect(tx_open_chest.texture.get_width()==33 and tx_open_chest.texture.get_height()==68,"TX open-chest crop does not follow the full sprite bounds",failures);tx_open_chest.free()
	for tx_prop_kind:String in ["crate","bench","pillar","well"]:
		var tx_prop:=SlasherForestArt.make_sprite(tx_prop_kind);_expect(tx_prop.texture!=null,"Missing centralized TX prop crop for %s"%tx_prop_kind,failures);tx_prop.free()
	for pickup_id in ["gold","potion","key"]:
		var pickup:=SlasherForestArt.make_sprite(pickup_id);var footprint:float=maxf(pickup.texture.get_width()*pickup.scale.x,pickup.texture.get_height()*pickup.scale.y);_expect(footprint<=33.0,"%s pickup is oversized at %.1f px"%[pickup_id,footprint],failures);pickup.free()
	var gate_art:=SlasherForestArt.make_sprite("exit");var gate_size:float=maxf(gate_art.texture.get_width()*gate_art.scale.x,gate_art.texture.get_height()*gate_art.scale.y);_expect(gate_size>=50.0,"Slasher exit art is too small to read",failures);gate_art.free()
	_expect(GameBalance.get_slasher_journal().get("entries",{}).size()==11,"Slasher journal catalog is incomplete",failures)
	var relic_items:Dictionary=GameBalance.get_items();_expect(relic_items.size()==52,"Shared relic catalog no longer contains 52 items",failures)
	for relic_id:Variant in relic_items:
		var slasher_record:Dictionary=GameBalance.get_slasher_item_effects(String(relic_id));_expect(not slasher_record.is_empty() and not GameBalance.get_slasher_item_rules_text(String(relic_id)).is_empty(),"%s is missing its Slasher translation"%String(relic_id),failures)
	var chest_state:=RunState.new();chest_state.active_play_mode=RunState.PLAY_MODE_SLASHER;chest_state.floor_seed=31337
	var chest_choices_a:Array[String]=chest_state.generate_slasher_chest_choices(3,"chest_4_9",0);var chest_choices_b:Array[String]=chest_state.generate_slasher_chest_choices(3,"chest_4_9",0)
	var unique_chest_choices:Dictionary={}
	for chest_choice:String in chest_choices_a:unique_chest_choices[chest_choice]=true
	_expect(chest_choices_a==chest_choices_b and chest_choices_a.size()==3,"Slasher chest choices are not deterministic three-card offerings",failures);_expect(unique_chest_choices.size()==3,"Slasher chest offering contains duplicate cards",failures)
	var floor_five_weights:Dictionary=GameBalance.get_slasher_chest_rarity_weights(5,0);var floor_eight_weights:Dictionary=GameBalance.get_slasher_chest_rarity_weights(8,0);var endless_weights:Dictionary=GameBalance.get_slasher_chest_rarity_weights(8,3)
	_expect(floor_five_weights==floor_eight_weights,"Campaign floors 6-8 must clamp to floor-five relic weights",failures);_expect(int(endless_weights.legendary)<=15 and int(endless_weights.rare)>int(floor_eight_weights.rare),"Endless relic scaling or Legendary cap is incorrect",failures)
	for enemy_kind in ["forest_normal","forest_elite","forest_boss"]:_expect(not GameBalance.get_slasher_enemy_tuning(enemy_kind).is_empty(),"Missing %s balance record"%enemy_kind,failures)
	var wolf_ids:Array[String]=["wolf_vanguard","wolf_lurker","wolf_charger","wolf_hunter","wolf_howler"]
	for wolf_id:String in wolf_ids:
		var wolf_tuning:Dictionary=GameBalance.get_slasher_wolf_archetype(wolf_id);_expect(not wolf_tuning.is_empty() and wolf_tuning.has("unlock_floor") and wolf_tuning.has("color"),"Missing %s archetype tuning"%wolf_id,failures)
		var wolf_frames:=SlasherSpriteLibrary.enemy_frames(wolf_id);_expect(wolf_frames!=null and wolf_frames.has_animation(&"attack_down") and wolf_frames.has_animation(&"attack_left") and wolf_frames.has_animation(&"attack_right") and wolf_frames.has_animation(&"attack_up") and wolf_frames.get_frame_count(&"attack_right")==2,"%s is missing its generated directional attack frames"%wolf_id,failures)
		var configured_wolf:=SlasherEnemy.new();configured_wolf.configure(maxi(1,int(wolf_tuning.get("unlock_floor",1))),false,wolf_id,false,wolf_id);_expect(configured_wolf.is_wolf() and configured_wolf.behavior_id==wolf_id and not configured_wolf.behavior_tuning.is_empty(),"%s did not configure its wolf behavior"%wolf_id,failures);_expect(is_equal_approx(configured_wolf.activation_delay,1.2),"%s is missing the floor-entry reaction buffer"%wolf_id,failures);configured_wolf.free()
	_expect(int(GameBalance.get_slasher_wolfmaster_tuning().get("reinforcement_cap",0))==5,"Wolfmaster reinforcement tuning is missing",failures)
	var mage_basic:Dictionary=GameBalance.get_slasher_ability_tuning("mage","basic");var mage_special:Dictionary=GameBalance.get_slasher_ability_tuning("mage","special");_expect(float(mage_basic.get("area_radius",0.0))>0.0 and float(mage_special.get("area_radius",0.0))>float(mage_basic.get("area_radius",0.0)),"Mage projectile splash tuning is missing",failures)
	var warrior_tuning:Dictionary=GameBalance.get_slasher_class_tuning("warrior");var warrior_charge:Dictionary=GameBalance.get_slasher_ability_tuning("warrior","movement");_expect(float(warrior_tuning.get("sprite_scale",0.0))>=1.0 and float(warrior_charge.get("path_radius",0.0))>0.0 and float(warrior_charge.get("invulnerability",0.0))>0.0 and float(warrior_charge.get("screen_shake_multiplier",0.0))>1.0,"Warrior charge/presentation tuning is incomplete",failures)
	_expect(float(GameBalance.get_slasher_ability_tuning("tank","movement").get("screen_shake_multiplier",0.0))>1.0,"Tank Leap is missing mobility shake scaling",failures)
	for visual_id in ["feral_wolf","thornback_boar","spore_beast","briar_guardian","ice_mage","dark_druid"]:
		var visual_tuning:=GameBalance.get_slasher_enemy_visual_tuning(visual_id);_expect(visual_tuning.has("sprite_offset_y") and visual_tuning.has("sprite_scale"),"Missing %s enemy presentation tuning"%visual_id,failures)
	for forest_enemy_id:String in ["thornback_boar","briar_guardian"]:
		var forest_frames:=SlasherSpriteLibrary.enemy_frames(forest_enemy_id);_expect(forest_frames!=null and forest_frames.has_animation(&"attack_down") and forest_frames.has_animation(&"attack_left") and forest_frames.has_animation(&"attack_right") and forest_frames.has_animation(&"attack_up"),"%s is missing its generated Forest animations"%forest_enemy_id,failures)
	_expect(not GameBalance.get_slasher_companion_tuning("wolf").is_empty(),"Missing wolf balance record",failures)
	_expect(SLASHER_RESOURCE_HUD!=null and SLASHER_RESOURCE_HUD.get_width()>0,"Slasher resource HUD ornament is missing",failures)
	for progression_class:String in GameBalance.get_base_classes().keys():
		var progression:Dictionary=GameBalance.get_slasher_progression(progression_class);_expect(Dictionary(progression).get("branches",[]).size()==3,"%s does not have three Slasher specialization branches"%progression_class,failures)
		var progression_state:=RunState.new();progression_state.set_class(progression_class);var progression_profile:Dictionary=progression_state.hero_profiles[progression_class];progression_profile.level=20;progression_profile.slasher_evolution_path=[];progression_profile.slasher_ability_upgrades=[];progression_profile.pending_slasher_progression_choices=[];progression_state.hero_profiles[progression_class]=progression_profile
		var strategy_before:Array=Array(progression_profile.get("ability_upgrades",[])).duplicate();progression_state.reconcile_slasher_progression();var choice_guard:=0;var saw_branch_choice:=false
		while progression_state.has_pending_slasher_progression_choice() and choice_guard<20:
			choice_guard+=1;var pending:Dictionary=progression_state.get_pending_slasher_progression_choice();var choices:Array=pending.get("choices",[]);var pending_level:int=int(pending.get("level",0));_expect(choices.size()==(3 if pending_level in [3,5] else 2),"%s level %d offered the wrong number of Slasher choices"%[progression_class,pending_level],failures)
			if pending_level==5:saw_branch_choice=true
			if choices.is_empty():break
			progression_state.choose_slasher_progression_choice(String(Dictionary(choices[0]).get("id","")))
		_expect(choice_guard==8 and saw_branch_choice and not progression_state.has_pending_slasher_progression_choice(),"%s did not resolve its complete level-20 Slasher tree"%progression_class,failures)
		var completed_profile:Dictionary=progression_state.hero_profiles[progression_class];_expect(Array(completed_profile.slasher_ability_upgrades).size()==7 and Array(completed_profile.slasher_evolution_path).size()==4,"%s stored incorrect Slasher progression counts"%progression_class,failures);_expect(Array(completed_profile.get("ability_upgrades",[]))==strategy_before,"%s Slasher choices modified Strategy progression"%progression_class,failures)
		var base_basic:Dictionary=GameBalance.get_slasher_ability_tuning(progression_class,"basic");var effective_basic:Dictionary=progression_state.get_effective_slasher_ability_tuning("basic");_expect(effective_basic!=base_basic and effective_basic.has("progression_flags"),"%s progression did not produce effective tuning"%progression_class,failures)
	var tuned_enemy:=SlasherEnemy.new();tuned_enemy.configure(3,false,"feral_wolf");_expect(tuned_enemy.elite and tuned_enemy.max_health==39 and tuned_enemy.damage==7 and tuned_enemy.reward==5,"Forest elite did not consume balance scaling",failures);_expect(is_equal_approx(tuned_enemy.activation_delay,1.2),"Standard enemies are missing the floor-entry reaction buffer",failures);tuned_enemy.free()
	var tuned_mini_boss:=SlasherEnemy.new();tuned_mini_boss.configure(5,false,"briar_guardian",true,"elite_guardian");_expect(tuned_mini_boss.elite and tuned_mini_boss.mini_boss and tuned_mini_boss.visual_id=="briar_guardian" and tuned_mini_boss.behavior_id=="elite_guardian" and tuned_mini_boss.max_health>80 and tuned_mini_boss.reward==12,"Forest Elite Guardian did not consume dedicated scaling",failures)
	var mini_cap:=maxi(1,int(floor(tuned_mini_boss.max_health*0.05)));var mini_first:=tuned_mini_boss.receive_attack({"damage":999});_expect(mini_first==mini_cap and tuned_mini_boss.damage_shield_remaining==0.5 and tuned_mini_boss.guardian_burst_queue.size()==1,"Elite Guardian did not cap damage, activate its shield, and queue retaliation",failures);var mini_second:=tuned_mini_boss.receive_attack({"damage":20});_expect(mini_second==5 and tuned_mini_boss.guardian_burst_queue.size()==2,"Elite Guardian shield did not reduce a subsequent hit or retain every-hit retaliation",failures);tuned_mini_boss.free()
	var tuned_boss:=SlasherEnemy.new();tuned_boss.configure(5,true,"dark_druid");_expect(tuned_boss.max_health==165 and tuned_boss.damage==16 and tuned_boss.reward==18,"Forest boss did not consume balance scaling",failures);_expect(is_equal_approx(tuned_boss.activation_delay,1.2),"Boss enemies are missing the floor-entry reaction buffer",failures);tuned_boss.free()
	var durability:Dictionary=GameBalance.get_slasher_balance("boss_durability");_expect(is_equal_approx(float(durability.get("max_damage_fraction",0.0)),0.05) and is_equal_approx(float(durability.get("shield_reduction",0.0)),0.75) and is_equal_approx(float(durability.get("shield_duration",0.0)),0.5),"Boss durability tuning is incomplete",failures)
	var uncapped_elite:=SlasherEnemy.new();uncapped_elite.configure(3,false,"feral_wolf");var uncapped_damage:=uncapped_elite.receive_attack({"damage":10});_expect(uncapped_elite.elite and not uncapped_elite.mini_boss and uncapped_damage==10,"Ordinary elite-scaled enemies incorrectly received boss durability",failures);uncapped_elite.free()
	for class_id in GameBalance.get_base_classes().keys():
		var class_tuning:=GameBalance.get_slasher_class_tuning(class_id)
		_expect(class_tuning.has("speed") and class_tuning.has("collision_radius"),"%s class tuning is incomplete"%class_id,failures)
		var movement_tuning:=GameBalance.get_slasher_ability_tuning(class_id,"movement")
		_expect(float(movement_tuning.get("invulnerability",0.0))>0.0,"%s movement ability has no invulnerability window"%class_id,failures)
		for slot in ["basic","movement","special","defensive"]:
			var ability_tuning:=GameBalance.get_slasher_ability_tuning(class_id,slot)
			_expect(ability_tuning.has("cooldown") and ability_tuning.has("resource_cost") and ability_tuning.has("animation_lock"),"%s.%s tuning is incomplete"%[class_id,slot],failures)
		var state:=RunState.new();state.set_class(class_id)
		var gear:=GearData.create("test_"+class_id,"Test Gear",3,class_id=="tank",2,"","",class_id,"block" if class_id=="tank" else "none")
		state.start_new_run(gear,"forest","slasher")
		_expect(state.active_play_mode=="slasher" and state.last_play_mode=="slasher","%s did not retain Slasher selection"%class_id,failures)
		var scene=SLASHER_SCENE.instantiate();scene.setup(null,state);root.add_child(scene);await process_frame
		_expect(scene.player!=null and scene.enemies_remaining>0,"%s Slasher scene failed to initialize"%class_id,failures)
		_expect(scene.pathfinder!=null and scene.player.pathfinder==scene.pathfinder,"%s Slasher scene did not share its grid pathfinder with the player"%class_id,failures)
		_expect(scene.player.camera!=null and scene.player.camera.zoom.x>=1.0 and scene.player.camera.zoom.x<=1.5,"%s Slasher camera did not apply configured zoom"%class_id,failures)
		_expect(scene.player.camera.drag_horizontal_enabled and scene.player.camera.drag_vertical_enabled,"%s Slasher camera is missing its player movement dead zone"%class_id,failures)
		_expect(is_equal_approx(scene.player.camera.drag_left_margin,0.25) and is_equal_approx(scene.player.camera.drag_right_margin,0.25) and is_equal_approx(scene.player.camera.drag_top_margin,0.25) and is_equal_approx(scene.player.camera.drag_bottom_margin,0.25),"%s Slasher camera dead zone does not preserve quarter-screen margins"%class_id,failures)
		var resource_hud:Control=scene.find_child("ResourceHUD",true,false) as Control
		_expect(resource_hud!=null and resource_hud.anchor_left==1.0 and resource_hud.anchor_top==1.0,"%s HUD is not anchored to the bottom-right"%class_id,failures)
		_expect(scene.health_bar!=null and scene.resource_bar!=null and scene.gold_value_label!=null and scene.key_value_label!=null and scene.potion_value_label!=null,"%s HUD is missing live health or resource controls"%class_id,failures)
		var found_breakable:=false;var first_breakable:SlasherBreakableProp
		for damageable in scene.get_tree().get_nodes_in_group("slasher_damageable"):
			_expect(damageable.has_method("receive_attack"),"Slasher damageable is missing receive_attack",failures)
			if damageable is SlasherBreakableProp:
				found_breakable=true
				if first_breakable==null:first_breakable=damageable as SlasherBreakableProp
		_expect(found_breakable,"%s Slasher floor did not instantiate generated breakable props"%class_id,failures)
		if first_breakable!=null:
			var resource_before_prop:int=state.class_resource;first_breakable.receive_attack({"damage":999,"screen_shake_multiplier":1.0},scene.player);_expect(first_breakable.destroyed,"%s could not destroy a generated prop"%class_id,failures);_expect(state.class_resource==resource_before_prop,"Breaking a prop granted class resource",failures)
		_expect(scene.player.class_id==class_id,"%s player kit was not selected"%class_id,failures)
		scene.player.cooldowns.movement=0.0;scene.player.aim_direction=Vector2.RIGHT
		var movement_health_before:int=scene.player.health;var movement_result:Dictionary=scene.player.use_action("movement")
		_expect(bool(movement_result.get("started",false)) and float(movement_result.get("invulnerability_granted",0.0))>0.0 and scene.player.invulnerable>0.0,"%s movement did not grant landing invulnerability"%class_id,failures)
		scene.player.receive_damage(3,Vector2.ZERO)
		_expect(scene.player.health==movement_health_before,"%s movement invulnerability did not prevent landing damage"%class_id,failures)
		scene.player.invulnerable=0.0
		_expect(scene.player.sprite!=null and scene.player.sprite.sprite_frames!=null,"%s player animation frames were not integrated"%class_id,failures)
		_expect(scene.player.presentation_ready,"%s presentation was not configured before first frame"%class_id,failures)
		scene.player.apply_movement_slow(0.7,1.0);scene.player.apply_movement_slow(0.5,0.5);_expect(is_equal_approx(scene.player.movement_debuff_multiplier,0.5) and is_equal_approx(scene.player.movement_debuff_time,1.0),"%s player slow did not use strongest-wins duration semantics"%class_id,failures);scene.player.movement_debuff_time=0.0;scene.player.movement_debuff_multiplier=1.0
		if class_id=="warrior":
			var guardian:=SlasherEnemy.new();guardian.configure(5,false,"briar_guardian",true,"elite_guardian");guardian.process_mode=Node.PROCESS_MODE_DISABLED;scene.actor_layer.add_child(guardian);guardian.target=scene.player;guardian.global_position=scene.player.global_position+Vector2(180,0);guardian.receive_attack({"damage":1},scene.player);guardian._process_guardian_bursts(0.3);var hostile_projectiles:=0
			for actor_child:Node in scene.actor_layer.get_children():
				if actor_child is SlasherHostileProjectile:hostile_projectiles+=1
			_expect(hostile_projectiles==int(guardian.behavior_tuning.get("burst_projectiles",0)),"Elite Guardian retaliation did not release the configured hostile projectile burst",failures)
			var lurker:=SlasherEnemy.new();lurker.configure(2,false,"wolf_lurker",false,"wolf_lurker");lurker.process_mode=Node.PROCESS_MODE_DISABLED;scene.actor_layer.add_child(lurker);lurker.target=scene.player;lurker.global_position=scene.player.global_position+Vector2(100,0);lurker._process_lurker(0.0);_expect(lurker.awakened and lurker.ai_state=="windup","Lurker did not wake into its ambush windup",failures)
			var charger:=SlasherEnemy.new();charger.configure(3,false,"wolf_charger",false,"wolf_charger");charger.process_mode=Node.PROCESS_MODE_DISABLED;scene.actor_layer.add_child(charger);charger.target=scene.player;charger.global_position=scene.player.global_position+Vector2(200,0);var sampled_target:Vector2=scene.player.global_position;charger._process_charger(0.0);_expect(charger.ai_state=="windup" and charger.captured_target==sampled_target,"Charger did not snapshot its straight-line charge target",failures)
			var howler:=SlasherEnemy.new();howler.configure(5,false,"wolf_howler",false,"wolf_howler");howler.process_mode=Node.PROCESS_MODE_DISABLED;scene.actor_layer.add_child(howler);howler.global_position=scene.player.global_position+Vector2(40,0);var wounded_wolf:=SlasherEnemy.new();wounded_wolf.configure(5,false,"wolf_vanguard",false,"wolf_vanguard");wounded_wolf.process_mode=Node.PROCESS_MODE_DISABLED;scene.actor_layer.add_child(wounded_wolf);wounded_wolf.global_position=howler.global_position+Vector2(20,0);wounded_wolf.health=maxi(1,wounded_wolf.max_health/2);var wounded_health:=wounded_wolf.health;var howler_health:=howler.health;howler._heal_wolves(245.0,0.16,false);_expect(wounded_wolf.health>wounded_health and howler.health==howler_health,"Howler healing did not affect only nearby allied wolves",failures)
			var boss_signals:Array=[];var wolfmaster:=SlasherEnemy.new();wolfmaster.configure(8,true,"dark_druid");wolfmaster.process_mode=Node.PROCESS_MODE_DISABLED;scene.actor_layer.add_child(wolfmaster);wolfmaster.target=scene.player;wolfmaster.reinforcement_requested.connect(func(archetypes:Array,_origin:Vector2):boss_signals.append(archetypes));wolfmaster.health=int(wolfmaster.max_health*0.69);wolfmaster._process_boss(0.0);wolfmaster.health=int(wolfmaster.max_health*0.34);wolfmaster._process_boss(0.0);_expect(boss_signals.size()==2 and wolfmaster.boss_phase==2,"Wolfmaster reinforcement phases did not trigger once at both thresholds",failures)
			guardian.queue_free();lurker.queue_free();charger.queue_free();howler.queue_free();wounded_wolf.queue_free();wolfmaster.queue_free()
		var basic_tuning:=GameBalance.get_slasher_ability_tuning(class_id,"basic")
		if class_id=="warrior":
			var attack_animation:=SlasherSpriteLibrary.resolved_animation(scene.player.sprite.sprite_frames,"attack",scene.player.facing_name);var attack_cooldown:float=float(basic_tuning.get("cooldown",0.4))
			scene.player._play_action_animation("attack",attack_cooldown)
			var played_duration:float=float(scene.player.sprite.sprite_frames.get_frame_count(attack_animation))/maxf(0.001,scene.player.sprite.sprite_frames.get_animation_speed(attack_animation)*absf(scene.player.sprite.get_playing_speed()))
			_expect(played_duration<=attack_cooldown+0.001,"Warrior attack animation does not complete within its basic cooldown",failures)
			scene.player.sprite.frame=3;scene.player._play_action_animation("attack",attack_cooldown);_expect(scene.player.sprite.frame==0,"Warrior attack animation did not restart for a repeated swing",failures)
		if basic_tuning.has("damage_coefficient"):
			var expected_damage:=maxi(1,int(round((scene.player.spell_power if String(basic_tuning.get("power_stat","attack_power"))=="spell_power" else scene.player.attack_power)*float(basic_tuning.get("damage_coefficient",1.0))))+int(basic_tuning.get("flat_damage",0)))
			_expect(scene.player._scaled_damage(basic_tuning)==expected_damage,"%s coefficient-plus-flat damage calculation is incorrect"%class_id,failures)
		if class_id!="warrior":
			var reference_size:Vector2=Vector2.ZERO
			for animation_name:StringName in [&"idle_right",&"run_right",&"basic_right",&"special_right",&"defensive_right",&"movement_right"]:
				_expect(scene.player.sprite.sprite_frames.has_animation(animation_name),"%s is missing %s animation"%[class_id,animation_name],failures)
				var frame_texture:Texture2D=scene.player.sprite.sprite_frames.get_frame_texture(animation_name,0)
				_expect(frame_texture!=null and not (frame_texture is AtlasTexture),"%s %s was not isolated from its neighboring atlas cells"%[class_id,animation_name],failures)
				if frame_texture!=null:
					if reference_size==Vector2.ZERO:reference_size=frame_texture.get_size()
					_expect(frame_texture.get_size()==reference_size,"%s has inconsistent frame canvases"%class_id,failures)
		var hitbox:=scene.player.get_node_or_null("PlayerHitbox") as CollisionShape2D
		_expect(hitbox!=null and hitbox.shape is CircleShape2D and is_equal_approx(hitbox.shape.radius,18.0),"%s player hitbox was not enlarged"%class_id,failures)
		var field_start:Vector2=scene._world(scene.layout.start)
		scene.player.global_position=field_start
		scene.player.receive_damage(1,Vector2(-10000.0,-10000.0))
		_expect(scene.is_world_position_walkable(scene.player.global_position),"%s knockback escaped the playable field"%class_id,failures)
		if class_id=="mage":
			scene.player.aim_direction=Vector2.RIGHT
			var basic_result:Dictionary=scene.player.use_action("basic")
			_expect(bool(basic_result.get("started",false)),"Mage basic did not start",failures)
			var found_projectile:=false
			for child in scene.actor_layer.get_children():
				if child is SlasherProjectile:found_projectile=true;break
			_expect(found_projectile,"Mage basic did not create an animated projectile",failures)
		for enemy_node in scene.get_tree().get_nodes_in_group("slasher_enemy"):
			if enemy_node is SlasherEnemy:
				var slasher_enemy: SlasherEnemy = enemy_node
				_expect(slasher_enemy.pathfinder==scene.pathfinder,"%s enemy did not receive the shared obstacle-aware pathfinder"%slasher_enemy.visual_id,failures)
				_expect(slasher_enemy.sprite!=null and slasher_enemy.sprite.sprite_frames!=null,"Slasher enemy animation frames were not integrated",failures)
				var enemy_visual:=GameBalance.get_slasher_enemy_visual_tuning(slasher_enemy.visual_id)
				_expect(is_equal_approx(slasher_enemy.sprite.position.y,float(enemy_visual.get("sprite_offset_y",-18.0))),"%s enemy sprite offset was not applied"%slasher_enemy.visual_id,failures)
				slasher_enemy.receive_attack({"damage":1,"knockback":4.0},scene.player)
				_expect(slasher_enemy.hit_stun_timer>0.0,"Enemy hit did not apply mini stun",failures)
				_expect(scene.player.screen_shake_time>0.0,"Enemy hit did not trigger screen shake",failures)
				break
		if class_id=="summoner":scene.player._ensure_companion();_expect(is_instance_valid(scene.player.companion),"Summoner wolf was not created",failures);_expect(scene.player.companion.get("pathfinder")==scene.pathfinder,"Summoner wolf did not receive the shared obstacle-aware pathfinder",failures)
		scene.run_state.record_enemy_defeat("feral_wolf");_expect(scene.run_state.is_enemy_discovered("feral_wolf") and scene.run_state.get_enemy_defeat_count("feral_wolf")>0,"Campaign journal did not persist enemy defeat",failures)
		paused=false;_expect(scene.codex.tabs.has("options"),"Slasher Codex is missing its Options tab",failures);scene._open_codex();_expect(scene.codex.visible and paused,"Slasher Codex did not pause gameplay",failures);scene.codex.close();_expect(not paused,"Slasher Codex did not restore pause state",failures)
		scene.queue_free();await process_frame
	var preference:=RunState.new();preference.start_new_run(GearData.create("test","Test",2,false,0,"",""),"forest","slasher");preference.finish_run("abandon","test");preference.start_new_run(preference.selected_gear,"forest","strategy")
	_expect(preference.active_play_mode=="strategy" and preference.last_play_mode=="strategy","Mode switching leaked previous runtime state",failures)
	if failures.is_empty():print("MULTI_MODE_SLASHER_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)

func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)

func _ensure_slasher_actions()->void:
	for action in ["character_menu","extract_expedition","slasher_up","slasher_down","slasher_left","slasher_right","slasher_aim_left","slasher_aim_right","slasher_aim_up","slasher_aim_down","slasher_controller_basic","slasher_mobility","slasher_special","slasher_defend","slasher_potion","slasher_abandon","slasher_consumable_1","slasher_consumable_2","slasher_consumable_3","slasher_consumable_4"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
