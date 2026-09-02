extends "res://scripts/slasher/slasher_forest.gd"

var flooded_zones:Array[Rect2]=[]
var machinery_zones:Array[Rect2]=[]
var machinery_tick:=0.0

func _build_world()->void:
	super._build_world();flooded_zones.clear();machinery_zones.clear()
	var rooms:Array=layout.get("rooms",[])
	for index in range(rooms.size()):
		var room:Rect2i=rooms[index];var center:=_world(room.get_center());var size:=Vector2(maxf(TILE*2.0,room.size.x*TILE*0.52),maxf(TILE*1.5,room.size.y*TILE*0.38));var zone:=Rect2(center-size*0.5,size)
		if index%3==1:machinery_zones.append(zone);_add_hazard_visual(zone,Color(0.55,0.72,0.68,0.20),"OreMachinery")
		elif index%2==0:flooded_zones.append(zone);_add_hazard_visual(zone,Color(0.12,0.48,0.62,0.28),"DeepWater")

func _add_hazard_visual(zone:Rect2,color:Color,label:String)->void:
	var polygon:=Polygon2D.new();polygon.name=label;polygon.polygon=PackedVector2Array([zone.position,Vector2(zone.end.x,zone.position.y),zone.end,Vector2(zone.position.x,zone.end.y)]);polygon.color=color;polygon.z_index=-3;low_decor_layer.add_child(polygon)

func _process(delta:float)->void:
	super._process(delta)
	if not is_instance_valid(player):return
	var in_water:=false
	for zone in flooded_zones:
		if zone.has_point(player.global_position):in_water=true;break
	if in_water:player.apply_movement_slow(0.62,0.18)
	machinery_tick=maxf(0.0,machinery_tick-delta)
	if machinery_tick<=0.0:
		for zone in machinery_zones:
			if zone.has_point(player.global_position):player.receive_damage(1,Vector2.ZERO);machinery_tick=2.0;_show_message("Ore machinery catches the party for 1 damage.");break

func _spawn_enemies()->void:
	enemies_remaining=0;var spawn_index:=0
	for spawn_value:Variant in layout.enemy_spawns:
		var record:Dictionary=Dictionary(spawn_value);var spawn:=Vector2i(record.get("position",Vector2i.ZERO));var is_boss:=bool(record.get("is_boss",false));var is_elite:=bool(record.get("is_mini_boss",false));var spec:=_mine_enemy_spec(spawn_index,is_boss,is_elite)
		_spawn_enemy(_world(spawn),String(spec.visual_id),String(spec.behavior_id),is_boss,is_elite);spawn_index+=1
	exit_open=enemies_remaining==0

func _mine_enemy_spec(index:int,is_boss:bool,is_elite:bool)->Dictionary:
	if is_boss:return {"visual_id":"drowned_foreman","behavior_id":""}
	if is_elite:return {"visual_id":"ice_mage","behavior_id":"elite_guardian"}
	var enemies:Array[String]=["ice_mage","spore_beast","thornback_boar","briar_guardian"]
	return {"visual_id":enemies[(index+run_state.current_floor)%enemies.size()],"behavior_id":""}

func _build_mist()->void:
	var mist:=CPUParticles2D.new();mist.name="MineDrizzle";mist.amount=60;mist.lifetime=5.0;mist.preprocess=5.0;mist.emission_shape=CPUParticles2D.EMISSION_SHAPE_RECTANGLE;mist.emission_rect_extents=Vector2(float(layout.width*TILE)/2.0,float(layout.height*TILE)/2.0);mist.position=ORIGIN+mist.emission_rect_extents;mist.direction=Vector2(0,1);mist.spread=8;mist.initial_velocity_min=12;mist.initial_velocity_max=24;mist.scale_amount_min=1;mist.scale_amount_max=2;mist.color=Color(0.55,0.78,0.86,0.12);mist.z_index=5;add_child(mist)

func _build_vignette()->void:
	var layer:=CanvasLayer.new();layer.name="MineLighting";layer.layer=0;add_child(layer);var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;shade.color=Color(0.01,0.06,0.08,0.22);layer.add_child(shade)
