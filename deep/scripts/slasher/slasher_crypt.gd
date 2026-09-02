extends "res://scripts/slasher/slasher_mine.gd"

func _build_world()->void:
	super._build_world()
	for child in low_decor_layer.get_children():
		if child is Polygon2D:child.color=Color(0.35,0.30,0.52,0.23)

func _process(delta:float)->void:
	super._process(delta)
	if not is_instance_valid(player):return
	for zone in flooded_zones:
		if zone.has_point(player.global_position):player.apply_movement_slow(0.72,0.18);break

func _mine_enemy_spec(index:int,is_boss:bool,is_elite:bool)->Dictionary:
	if is_boss:return {"visual_id":"crypt_boss","behavior_id":""}
	if is_elite:return {"visual_id":"dark_druid","behavior_id":"elite_guardian"}
	var choices:Array[String]=["dark_druid","ice_mage","spore_beast","briar_guardian"]
	return {"visual_id":choices[(index+run_state.current_floor)%choices.size()],"behavior_id":""}

func _build_mist()->void:
	var dust:=CPUParticles2D.new();dust.name="CryptDust";dust.amount=48;dust.lifetime=7.0;dust.preprocess=7.0;dust.emission_shape=CPUParticles2D.EMISSION_SHAPE_RECTANGLE;dust.emission_rect_extents=Vector2(float(layout.width*TILE)/2.0,float(layout.height*TILE)/2.0);dust.position=ORIGIN+dust.emission_rect_extents;dust.direction=Vector2(0.3,-0.1);dust.spread=30;dust.initial_velocity_min=2;dust.initial_velocity_max=7;dust.color=Color(0.62,0.58,0.76,0.10);dust.z_index=5;add_child(dust)

func _build_vignette()->void:
	var layer:=CanvasLayer.new();layer.name="CryptLighting";layer.layer=0;add_child(layer);var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;shade.color=Color(0.025,0.02,0.08,0.25);layer.add_child(shade)
