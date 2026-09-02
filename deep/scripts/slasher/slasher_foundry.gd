extends "res://scripts/slasher/slasher_mine.gd"

func _build_world()->void:
	super._build_world()
	for child in low_decor_layer.get_children():
		if child is Polygon2D:child.color=Color(0.88,0.22,0.05,0.30) if child.name=="DeepWater" else Color(0.95,0.55,0.12,0.24)

func _process(delta:float)->void:
	super._process(delta)
	# In the Foundry, the inherited flooded lanes are molten channels: they burn
	# rather than merely slowing movement.
	if not is_instance_valid(player):return
	for zone in flooded_zones:
		if zone.has_point(player.global_position) and machinery_tick<=0.0:player.receive_damage(2,Vector2.ZERO);machinery_tick=1.5;_show_message("Molten runoff burns for 2 damage.");break

func _mine_enemy_spec(index:int,is_boss:bool,is_elite:bool)->Dictionary:
	if is_boss:return {"visual_id":"last_warmachine","behavior_id":""}
	if is_elite:return {"visual_id":"briar_guardian","behavior_id":"elite_guardian"}
	var enemies:Array[String]=["fire_mage","ember_crow","blighted_farmhand","briar_guardian"]
	return {"visual_id":enemies[(index+run_state.current_floor)%enemies.size()],"behavior_id":""}

func _build_mist()->void:
	var sparks:=CPUParticles2D.new();sparks.name="ForgeSparks";sparks.amount=75;sparks.lifetime=3.0;sparks.preprocess=3.0;sparks.emission_shape=CPUParticles2D.EMISSION_SHAPE_RECTANGLE;sparks.emission_rect_extents=Vector2(float(layout.width*TILE)/2.0,float(layout.height*TILE)/2.0);sparks.position=ORIGIN+sparks.emission_rect_extents;sparks.direction=Vector2(-0.2,-1);sparks.spread=35;sparks.initial_velocity_min=18;sparks.initial_velocity_max=42;sparks.color=Color(1.0,0.42,0.08,0.42);sparks.z_index=5;add_child(sparks)

func _build_vignette()->void:
	var layer:=CanvasLayer.new();layer.name="FoundryLighting";layer.layer=0;add_child(layer);var heat:=ColorRect.new();heat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);heat.mouse_filter=Control.MOUSE_FILTER_IGNORE;heat.color=Color(0.16,0.025,0.005,0.20);layer.add_child(heat)
