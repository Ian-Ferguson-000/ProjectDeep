extends "res://scripts/slasher/slasher_forest.gd"

const HELL_ENEMY:=preload("res://scripts/slasher/slasher_hell_enemy.gd")
const HELL_HAZARD:=preload("res://scripts/slasher/slasher_hell_hazard.gd")
const HELL_ART:=preload("res://scripts/slasher/slasher_hell_art.gd")

var hell_hazards:Array[SlasherHellHazard]=[]

func _build_world()->void:
	super._build_world()
	if show_generated_ground or not authored_visuals_active:
		for child:Node in ground_layer.get_children():child.free()
		for value:Variant in layout.cells:
			var cell:=Vector2i(value);var tile:=HELL_ART.make_ground_sprite(cell,TILE);tile.name="HellFloor_%d_%d"%[cell.x,cell.y];tile.position=_world(cell);ground_layer.add_child(tile)
	# The Hellwall sheet is an object atlas, so mount its masonry panels along
	# generated boundary cells while topology continues to own exact collision.
	var boundary:Array=layout.get("edges",{}).keys() if layout.get("edges",{}) is Dictionary else []
	for index:int in range(0,boundary.size(),maxi(1,int(boundary.size()/18.0))):
		var cell:=Vector2i(boundary[index]);var panel:=HELL_ART.make_wall_panel(index);panel.position=_world(cell)+Vector2(0,-30);panel.z_index=-1;low_decor_layer.add_child(panel)

func _build_decorations()->void:
	var cells:Array=layout.cells.keys();cells.sort_custom(func(a:Vector2i,b:Vector2i)->bool:return a.y<b.y or a.y==b.y and a.x<b.x)
	var kinds:=["brazier","skull","chain","slag"]
	for index:int in range(0,cells.size(),11):
		var cell:=Vector2i(cells[index]);if cell.distance_to(Vector2(layout.start))<3.0 or cell.distance_to(Vector2(layout.exit))<3.0:continue
		var decor:=HELL_ART.make_decoration(kinds[(index/11+run_state.current_floor)%kinds.size()]);decor.position=_world(cell)+Vector2(0,8);low_decor_layer.add_child(decor)

func _build_solid_props()->void:pass

func _spawn_player()->void:
	super._spawn_player();_spawn_floor_hazards()

func _spawn_floor_hazards()->void:
	hell_hazards.clear()
	for index:int in layout.get("rooms",[]).size():
		if index==0:continue
		var room:=Rect2i(layout.rooms[index]);var count:=1+(1 if run_state.current_floor>=4 and index%2==0 else 0)
		for offset:int in count:
			var point:=_world(room.get_center()+Vector2i((offset*2)-1,0));_spawn_hazard(null,point,{"radius":42.0,"lifetime":1.8,"telegraph":1.1+index*0.07,"damage":maxi(1,run_state.current_floor/3),"repeating":true})

func _spawn_enemies()->void:
	enemies_remaining=0;var spawn_index:=0
	for spawn_value:Variant in layout.enemy_spawns:
		var record:=Dictionary(spawn_value);var spec:=_hell_enemy_spec(spawn_index,bool(record.get("is_boss",false)),bool(record.get("is_mini_boss",false)));_spawn_enemy(_world(Vector2i(record.position)),String(spec.visual_id),String(spec.behavior_id),bool(record.get("is_boss",false)),bool(record.get("is_mini_boss",false)));spawn_index+=1
	exit_open=enemies_remaining==0

func _hell_enemy_spec(index:int,is_boss:bool,is_elite:bool)->Dictionary:
	if is_boss:return {"visual_id":"balor","behavior_id":"balor"}
	if is_elite:return {"visual_id":"infernal_legate","behavior_id":"infernal_legate"}
	var roster:=["infernal_caster","rift_stalker"]
	if run_state.current_floor>=2:roster.append("hellcharger")
	if run_state.current_floor>=3:roster.append("cinder_bomber")
	var id:=String(roster[(index+run_state.current_floor)%roster.size()]);return {"visual_id":id,"behavior_id":id}

func _spawn_enemy(world_position:Vector2,visual_id:String,behavior_id:String="",is_boss:bool=false,is_mini_boss:bool=false)->SlasherEnemy:
	var enemy:SlasherHellEnemy=HELL_ENEMY.new();enemy.name="Balor" if is_boss else visual_id.to_pascal_case();enemy.configure(run_state.current_floor,is_boss,visual_id,is_mini_boss,behavior_id);enemy.pathfinder=pathfinder;actor_layer.add_child(enemy);enemy.global_position=world_position;enemy.target=player;enemy.defeated.connect(_on_enemy_defeated);enemy.hell_effect_requested.connect(_on_hell_effect_requested);enemies_remaining+=1;return enemy

func _on_hell_effect_requested(kind:String,origin:Vector2,payload:Dictionary)->void:
	match kind:
		"summon_spirits":_summon_hell_units(origin,"fire_spirit",int(payload.get("count",3)),6)
		"summon_minions":_summon_hell_units(origin,"fire_spirit",int(payload.get("count",5)),9)
		_:_spawn_hazard(null,origin,payload)

func _summon_hell_units(origin:Vector2,id:String,count:int,cap:int)->void:
	var active:=get_tree().get_nodes_in_group("slasher_enemy").size();var available:=maxi(0,cap-active)
	for index:int in mini(count,available):
		var point:=sanitize_player_position(origin+Vector2.RIGHT.rotated(TAU*float(index)/maxf(1.0,float(count)))*105.0);_spawn_enemy(point,id,id)

func _spawn_hazard(source:SlasherEnemy,point:Vector2,config:Dictionary)->void:
	var hazard:SlasherHellHazard=HELL_HAZARD.new().setup(source,player,point,config);actor_layer.add_child(hazard);hell_hazards.append(hazard)

func _on_enemy_defeated(enemy:SlasherEnemy,reward:int)->void:
	super._on_enemy_defeated(enemy,reward)
	if enemies_remaining==0:_disable_hell_threats()

func _disable_hell_threats()->void:
	for hazard:SlasherHellHazard in hell_hazards:
		if is_instance_valid(hazard):hazard.disable()
	for projectile:Node in get_tree().get_nodes_in_group("hell_projectile"):
		if is_instance_valid(projectile):projectile.queue_free()

func _build_mist()->void:
	var embers:=CPUParticles2D.new();embers.name="HellEmbers";embers.amount=90;embers.lifetime=5.5;embers.preprocess=5.5;embers.emission_shape=CPUParticles2D.EMISSION_SHAPE_RECTANGLE;embers.emission_rect_extents=Vector2(float(layout.width*TILE)/2.0,float(layout.height*TILE)/2.0);embers.position=ORIGIN+embers.emission_rect_extents;embers.direction=Vector2(0,-1);embers.spread=22;embers.initial_velocity_min=18;embers.initial_velocity_max=42;embers.color=Color("#ff641f99");embers.z_index=6;add_child(embers)

func _build_vignette()->void:
	var layer:=CanvasLayer.new();layer.name="HellLighting";layer.layer=0;add_child(layer);var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material:=ShaderMaterial.new();var shader:=Shader.new();shader.code="shader_type canvas_item; void fragment(){vec2 p=UV-vec2(0.5);float edge=smoothstep(0.22,0.72,length(p));COLOR=vec4(0.16,0.01,0.005,0.08+edge*0.52);}";material.shader=shader;shade.material=material;layer.add_child(shade)
