extends "res://scripts/slasher/slasher_forest.gd"

const BACKGROUND_ROOT := "res://assets/field/farmstead/backgrounds/"
const BACKGROUND_IDS := ["crossroads", "farmyard", "barn", "cellar", "storehouse", "harvest_field"]
const ROOM_ORIGIN := Vector2(64, 64)
const ROOM_SIZE := Vector2(768, 528)
const FIELD_DOORS := {"north":Vector2i(8,1), "east":Vector2i(14,5), "south":Vector2i(8,9), "west":Vector2i(1,5)}
const FARM_ENEMIES := ["ash_rat", "possessed_scarecrow", "ember_crow", "blighted_farmhand"]
const FIELD_MINIMAP := preload("res://scripts/slasher/field_slasher_minimap.gd")

var room_id := 0
var room:Dictionary = {}
var room_role := "start"
var door_positions:Dictionary = {}
var transition_cooldown := 0.0
var room_reward_claimed := false
var active_hazards:Array[Area2D]=[]

func _build_floor()->void:
	get_tree().paused=false
	var player_snapshot:=_snapshot_player()
	for child in get_children():child.free()
	room_id=int(run_state.field_run.get("current_room",0));room=run_state.get_field_room(room_id);room_role=String(room.get("role","combat"))
	run_state.enter_field_room(room_id,int(run_state.field_run.get("previous_room",-1)))
	if not bool(room.get("cleared",false)) and room_role in ["combat","elite","boss"]:run_state.continue_expedition()
	layout=_make_room_layout()
	pathfinder=GRID_PATHFINDER.new().configure(Dictionary(layout.cells),Array(layout.solid_props),ORIGIN,float(TILE))
	_build_world();_spawn_player();_restore_player(player_snapshot);_spawn_enemies();_spawn_loot();_build_hud();_refresh_hud();_entry_fade()
	transition_cooldown=0.45

func _make_room_layout()->Dictionary:
	var cells:Dictionary={}
	for y in range(1,10):
		for x in range(1,15):cells[Vector2i(x,y)]=true
	var template:Dictionary={};var templates:=GameBalance.get_field_room_templates(String(room.get("door_signature","")))
	if not templates.is_empty():template=templates[room_id%templates.size()]
	var bg:=_background_for_role(String(template.get("background_id","farmyard")))
	if String(room.get("background_id","")).is_empty():run_state.update_field_room(room_id,{"background_id":bg,"template_id":String(template.get("id","fallback"))});room["background_id"]=bg
	var props:Array=[]
	var destroyed:Array=Array(Dictionary(room.get("slasher",{})).get("destroyed_props",[]))
	for index in range(Array(template.get("obstacles",[])).size()):
		var pos:Array=Array(template.obstacles[index]);var cell:=Vector2i(int(pos[0]),int(pos[1]))
		if not destroyed.has(cell):props.append({"kind":["hay_bale","fence","barrel"][index%3],"cell":cell})
	return {"width":16,"height":11,"cells":cells,"solid_props":props,"enemy_spawns":[],"loot_spawns":[],"start":_entry_cell(),"exit":Vector2i(8,5),"merchant":Vector2i(8,4)}

func _background_for_role(fallback:String)->String:
	match room_role:
		"start":return "crossroads"
		"shop","treasure":return "storehouse"
		"boss":return "harvest_field"
	return fallback if fallback in BACKGROUND_IDS else "farmyard"

func _build_world()->void:
	var underlay:=ColorRect.new();underlay.color=Color.BLACK;underlay.position=Vector2.ZERO;underlay.size=Vector2(900,660);underlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;underlay.z_index=-20;add_child(underlay)
	ground_layer=Node2D.new();ground_layer.z_index=-10;add_child(ground_layer);low_decor_layer=Node2D.new();add_child(low_decor_layer);actor_layer=Node2D.new();actor_layer.y_sort_enabled=true;add_child(actor_layer);canopy_layer=Node2D.new();add_child(canopy_layer)
	var bg_id:=_background_for_role(String(room.get("background_id","farmyard")));var path:=BACKGROUND_ROOT+bg_id+".png"
	if ResourceLoader.exists(path):
		var sprite:=Sprite2D.new();sprite.texture=load(path);sprite.centered=false;sprite.position=ROOM_ORIGIN;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;ground_layer.add_child(sprite)
	_build_room_boundaries();_build_solid_props();_build_landmarks();_build_vignette()

func _build_room_boundaries()->void:
	var neighbors:Dictionary=room.get("neighbors",{});door_positions.clear()
	for direction in FIELD_DOORS:
		var cell:Vector2i=FIELD_DOORS[direction];door_positions[direction]=_world(cell)
		var marker:=Polygon2D.new();marker.position=_world(cell);marker.polygon=PackedVector2Array([Vector2(-22,-12),Vector2(22,-12),Vector2(22,12),Vector2(-22,12)]);marker.color=Color(0.95,0.5,0.16,0.18) if neighbors.has(direction) else Color(0.05,0.03,0.02,0.92);marker.z_index=-1;actor_layer.add_child(marker)
	# Collision rails frame the 14x9 arena; open doorway bays are enforced by clamping in the player.
	for record in [[Vector2(448,106),Vector2(672,12)],[Vector2(448,550),Vector2(672,12)],[Vector2(106,328),Vector2(12,336)],[Vector2(790,328),Vector2(12,336)]]:
		var body:=StaticBody2D.new();body.position=record[0];var shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=record[1];shape.shape=rect;body.add_child(shape);add_child(body)

func _build_landmarks()->void:
	merchant_position=_world(Vector2i(8,4)) if room_role=="shop" else Vector2(-9999,-9999)
	if room_role=="shop":
		var sprite:=Sprite2D.new();sprite.texture=load("res://assets/field/farmstead/merchant_orin.png");sprite.position=merchant_position;sprite.scale=Vector2.ONE*0.45;actor_layer.add_child(sprite)
	exit_position=_world(Vector2i(8,5)) if room_role=="boss" and bool(room.get("cleared",false)) else Vector2(-9999,-9999)
	if exit_position.x>0.0:
		var gate:=Sprite2D.new();gate.texture=load("res://assets/field/farmstead/return_gate.png");gate.position=exit_position;gate.scale=Vector2.ONE*0.55;gate.add_child(_glow(Color("#f5a44b"),34));actor_layer.add_child(gate)

func _spawn_enemies()->void:
	enemies_remaining=0
	if bool(room.get("cleared",false)) or room_role in ["start","shop","treasure"]:exit_open=true;return
	var records:Array=Array(Dictionary(room.get("slasher",{})).get("surviving_enemies",[]))
	if records.is_empty():records=_initial_enemy_records()
	for record_value in records:
		var record:Dictionary=record_value;var enemy:=_spawn_enemy(Vector2(record.position),String(record.type),String(record.type),String(record.type)=="harvest_wretch",bool(record.get("elite",false)))
		if record.has("health"):enemy.health=mini(enemy.max_health,int(record.health))
	exit_open=enemies_remaining==0
	for hazard_value in Array(Dictionary(room.get("slasher",{})).get("hazards",[])):
		var hazard:Dictionary=hazard_value;_spawn_fire_hazard(Vector2(hazard.get("position",Vector2.ZERO)),float(hazard.get("radius",42.0)),float(hazard.get("lifetime",2.0)))

func _spawn_enemy(world_position:Vector2,visual_id:String,behavior_id:String="",is_boss:bool=false,is_mini_boss:bool=false)->SlasherEnemy:
	var enemy:SlasherEnemy=super._spawn_enemy(world_position,visual_id,behavior_id,is_boss,is_mini_boss)
	enemy.farmstead_effect_requested.connect(_on_farmstead_effect)
	return enemy

func _initial_enemy_records()->Array:
	var result:Array=[];var count:=4 if room_role=="elite" else 2+(room_id%2)
	if room_role=="boss":return [{"type":"harvest_wretch","position":_world(Vector2i(8,4))},{"type":"ash_rat","position":_world(Vector2i(5,5))},{"type":"ash_rat","position":_world(Vector2i(11,5))}]
	var spots:=[Vector2i(5,3),Vector2i(11,3),Vector2i(5,7),Vector2i(11,7)]
	for i in count:result.append({"type":FARM_ENEMIES[(room_id+i)%FARM_ENEMIES.size()],"position":_world(spots[i]),"elite":room_role=="elite"})
	return result

func _spawn_loot()->void:
	loot_nodes.clear()
	if room_role=="treasure" and not bool(room.get("reward_claimed",false)):
		var area:=Area2D.new();area.position=_world(Vector2i(8,5));area.name="FarmsteadTreasure";var shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=25;shape.shape=circle;area.add_child(shape);area.set_meta("field_treasure",true);actor_layer.add_child(area);loot_nodes.append(area)

func _process(delta:float)->void:
	if not is_instance_valid(player):return
	transition_cooldown=maxf(0.0,transition_cooldown-delta)
	var modal_open:bool=(merchant_shop_panel!=null and merchant_shop_panel.visible) or (relic_modal!=null and relic_modal.visible);var codex_open:=codex!=null and codex.visible;player.input_locked=modal_open or codex_open
	if Input.is_action_just_pressed("character_menu") and not modal_open:_open_codex();return
	if modal_open or codex_open:return
	for loot in loot_nodes.duplicate():
		if is_instance_valid(loot) and player.global_position.distance_to(loot.global_position)<38:_open_field_treasure(loot)
	if room_role=="shop" and player.global_position.distance_to(merchant_position)<56:
		_show_message("Orin Cinder · press E to trade.",0.15)
		if Input.is_action_just_pressed("interact"):merchant_shop_panel.setup(run_state,"farmstead","dungeon");merchant_shop_panel.open()
	if room_role=="boss" and bool(room.get("cleared",false)) and player.global_position.distance_to(_world(Vector2i(8,5)))<45:_complete_farmstead()
	if Input.is_action_just_pressed("extract_expedition") and run_state.can_extract():
		_snapshot_room();_close_codex()
		if controller and controller.has_method("extract_expedition"):controller.extract_expedition()
		return
	if Input.is_action_just_pressed("slasher_potion"):_use_potion()
	for index in range(4):
		if Input.is_action_just_pressed("slasher_consumable_%d"%(index+1)):_use_consumable_slot(index)
	if Input.is_action_just_pressed("slasher_abandon"):_abandon_run()
	_process_hazards(delta);_check_door_transition();_refresh_hud()

func _on_farmstead_effect(kind:String,origin:Vector2,payload:Dictionary)->void:
	match kind:
		"summon_rats":
			var cap:=int(Dictionary(GameBalance.get_dungeon("ashen_farmstead").get("slasher",{})).get("summon_cap",5));var available:=maxi(0,cap-get_tree().get_nodes_in_group("farmstead_summon").size())
			for index in mini(available,int(payload.get("count",2))):
				var rat:=_spawn_enemy(sanitize_player_position(origin+Vector2.RIGHT.rotated(TAU*index/maxf(1.0,float(available)))*75.0),"ash_rat","ash_rat");rat.add_to_group("farmstead_summon")
		"fire_patch","scorched_zone":_spawn_fire_hazard(origin,float(payload.get("radius",42.0)),float(payload.get("lifetime",4.0)))
		"ash_burst":
			if player.global_position.distance_to(origin)<125.0:player.receive_damage(int(payload.get("damage",2)),origin.direction_to(player.global_position)*75.0,null)

func _spawn_fire_hazard(position_value:Vector2,radius:float,lifetime:float)->void:
	var area:=Area2D.new();area.position=position_value;area.set_meta("life",lifetime);area.set_meta("tick",0.0);var shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=radius;shape.shape=circle;area.add_child(shape);var visual:=Polygon2D.new();var points:=PackedVector2Array();for i in 24:points.append(Vector2.RIGHT.rotated(TAU*i/24.0)*radius);visual.polygon=points;visual.color=Color(0.95,0.22,0.04,0.28);area.add_child(visual);actor_layer.add_child(area);active_hazards.append(area)

func _process_hazards(delta:float)->void:
	for index in range(active_hazards.size()-1,-1,-1):
		var hazard:=active_hazards[index]
		if not is_instance_valid(hazard):active_hazards.remove_at(index);continue
		hazard.set_meta("life",float(hazard.get_meta("life"))-delta);hazard.set_meta("tick",maxf(0.0,float(hazard.get_meta("tick"))-delta))
		if float(hazard.get_meta("life"))<=0.0:hazard.queue_free();active_hazards.remove_at(index)
		elif float(hazard.get_meta("tick"))<=0.0 and player.global_position.distance_to(hazard.global_position)<=float((hazard.get_child(0) as CollisionShape2D).shape.radius):player.receive_damage(2,Vector2.ZERO,null);hazard.set_meta("tick",0.75)

func _check_door_transition()->void:
	if transition_cooldown>0.0 or not exit_open:return
	var neighbors:Dictionary=room.get("neighbors",{})
	for direction in neighbors:
		if player.global_position.distance_to(Vector2(door_positions.get(direction,Vector2.ZERO)))<34:
			_snapshot_room();run_state.enter_field_room(int(neighbors[direction]),room_id);call_deferred("_build_floor");return

func _on_enemy_defeated(enemy:SlasherEnemy,reward:int)->void:
	super._on_enemy_defeated(enemy,reward)
	if enemies_remaining==0:
		exit_open=true;room_reward_claimed=true;run_state.update_field_room(room_id,{"cleared":true,"reward_claimed":true,"slasher":{"activated":true,"surviving_enemies":[]}})
		run_state.mark_extraction_available("room_%d"%room_id,run_state.get_field_cleared_count());run_state.autosave_campaign()
		if room_role=="boss":run_state.field_run["boss_defeated"]=true;_build_landmarks();_show_message("The Harvest Wretch falls · enter the return gate.")
		else:
			var amount:=run_state.apply_reward_bonus(int(Dictionary(GameBalance.get_dungeon("ashen_farmstead").get("slasher",{})).get("room_clear_gold",5)),"gold");run_state.gold+=amount;_show_message("Room cleared · doors open · +%d gold · X extracts."%amount)

func _open_field_treasure(area:Area2D)->void:
	loot_nodes.erase(area);area.queue_free();run_state.update_field_room(room_id,{"reward_claimed":true});relic_choice_source="field_treasure";var choices:=run_state.generate_slasher_chest_choices(1,"farmstead_room_%d"%room_id,0);relic_modal.open(run_state,choices,true)

func _snapshot_room()->void:
	var survivors:Array=[]
	for node in get_tree().get_nodes_in_group("slasher_enemy"):
		if node is SlasherEnemy and not node.dead:survivors.append({"type":node.visual_id,"health":node.health,"position":node.global_position,"elite":node.elite})
	var old_state:Dictionary=Dictionary(room.get("slasher",{}));var hazards:Array=[]
	for hazard in active_hazards:
		if is_instance_valid(hazard):hazards.append({"position":hazard.global_position,"radius":float((hazard.get_child(0) as CollisionShape2D).shape.radius),"lifetime":float(hazard.get_meta("life"))})
	old_state["activated"]=true;old_state["surviving_enemies"]=survivors;old_state["hazards"]=hazards
	run_state.update_field_room(room_id,{"slasher":old_state})

func _on_prop_broken(prop:SlasherBreakableProp,kind:String,cell:Vector2i)->void:
	super._on_prop_broken(prop,kind,cell)
	var state:Dictionary=Dictionary(room.get("slasher",{}));var destroyed:Array=Array(state.get("destroyed_props",[]))
	if not destroyed.has(cell):destroyed.append(cell)
	state["destroyed_props"]=destroyed;room["slasher"]=state;run_state.update_field_room(room_id,{"slasher":state})

func _snapshot_player()->Dictionary:
	if not is_instance_valid(player):return {}
	return {"cooldowns":player.cooldowns.duplicate(),"invulnerable":player.invulnerable,"defense_window":player.defense_window,"defense_kind":player.defense_kind,"consumable_speed_time":player.consumable_speed_time,"consumable_speed_multiplier":player.consumable_speed_multiplier}

func _restore_player(snapshot:Dictionary)->void:
	if snapshot.is_empty():return
	player.cooldowns=Dictionary(snapshot.get("cooldowns",player.cooldowns));player.invulnerable=float(snapshot.get("invulnerable",0));player.defense_window=float(snapshot.get("defense_window",0));player.defense_kind=String(snapshot.get("defense_kind",""));player.consumable_speed_time=float(snapshot.get("consumable_speed_time",0));player.consumable_speed_multiplier=float(snapshot.get("consumable_speed_multiplier",1))

func _entry_cell()->Vector2i:
	var previous:=int(run_state.field_run.get("previous_room",-1));var neighbors:Dictionary=room.get("neighbors",{})
	for direction in neighbors:
		if int(neighbors[direction])==previous:
			match direction:
				"north":return Vector2i(8,2)
				"south":return Vector2i(8,8)
				"east":return Vector2i(13,5)
				"west":return Vector2i(2,5)
	return Vector2i(8,8)

func _refresh_hud()->void:
	if not is_instance_valid(player) or objective_label==null:return
	var state_text:="BOSS" if room_role=="boss" else ("SAFE" if exit_open else "%d FOES"%enemies_remaining)
	objective_label.text="ASHEN FARMSTEAD · %s · %d/%d EXPLORED · %d CLEARED · %s"%[room_role.to_upper(),run_state.get_field_discovered_count(),int(run_state.field_run.get("room_count",0)),run_state.get_field_cleared_count(),state_text]
	health_bar.max_value=maxi(1,player.max_health);health_bar.value=player.health;health_value_label.text="%d / %d"%[player.health,player.max_health];resource_bar.max_value=maxi(1,run_state.get_class_resource_max());resource_bar.value=run_state.class_resource;resource_value_label.text="%s  %d / %d"%[run_state.get_class_resource_name(),run_state.class_resource,run_state.get_class_resource_max()];gold_value_label.text=str(run_state.gold);key_value_label.text=str(run_state.keys);potion_value_label.text=str(run_state.get_consumables().count("healing_potion"))
	var map:=get_node_or_null("HUD/FieldMinimap")
	if map:map.queue_redraw()

func _build_hud()->void:
	super._build_hud()
	var map:=FIELD_MINIMAP.new();map.name="FieldMinimap";map.position=Vector2(18,82);map.size=Vector2(220,160);map.setup(run_state);get_node("HUD").add_child(map)

func _complete_farmstead()->void:
	_snapshot_room();_close_codex()
	if controller and controller.has_method("complete_slasher_farmstead"):controller.complete_slasher_farmstead()

func _on_player_defeated()->void:
	_snapshot_room();_close_codex()
	if controller and controller.has_method("return_to_tavern"):controller.return_to_tavern("death","You fall in the Ashen Farmstead with %d gold."%run_state.gold)

func _abandon_run()->void:
	_snapshot_room();_close_codex()
	if controller and controller.has_method("return_to_tavern"):controller.return_to_tavern("abandon","You abandon the Ashen Farmstead and return with %d gold."%run_state.gold)
