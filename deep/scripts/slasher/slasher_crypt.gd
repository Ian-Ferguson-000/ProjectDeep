extends "res://scripts/slasher/slasher_forest.gd"

const CRYPT_ENEMY:=preload("res://scripts/slasher/slasher_crypt_enemy.gd")
const CRYPT_HAZARD:=preload("res://scripts/slasher/slasher_crypt_hazard.gd")
const CRYPT_ART:=preload("res://scripts/slasher/slasher_crypt_art.gd")
const HOSTILE_PROJECTILE:=preload("res://scripts/slasher/slasher_hostile_projectile.gd")

var crypt_hazards:Array[SlasherCryptHazard]=[]

func _build_world()->void:
	super._build_world()
	if show_generated_ground or not authored_visuals_active:
		for child:Node in ground_layer.get_children():child.free()
		for value:Variant in layout.cells:
			var cell:=Vector2i(value);var stone:=CRYPT_ART.make_ground_sprite(cell,TILE);stone.name="CryptStone_%d_%d"%[cell.x,cell.y];stone.position=_world(cell);ground_layer.add_child(stone)
	for child in low_decor_layer.get_children():
		if child is CanvasItem:(child as CanvasItem).modulate=Color("#bbb7ce")

func _build_decorations()->void:
	var cells:Array=layout.cells.keys();cells.sort_custom(func(a:Vector2i,b:Vector2i)->bool:return a.y<b.y or a.y==b.y and a.x<b.x)
	var kinds:=["bone_pile","candles","rubble","grave","coffin"]
	var stride:=maxi(8,13-run_state.current_floor)
	for index:int in range(0,cells.size(),stride):
		var cell:=Vector2i(cells[index]);if cell.distance_to(Vector2(layout.start))<3.0 or cell.distance_to(Vector2(layout.exit))<3.0:continue
		var decor:=CRYPT_ART.make_decoration(kinds[(index/stride+run_state.current_floor)%kinds.size()]);decor.position=_world(cell)+Vector2(0,9);low_decor_layer.add_child(decor)
	for room_value:Variant in layout.get("rooms",[]):
		var room:=Rect2i(room_value);var pillar:=CRYPT_ART.make_decoration("pillar");pillar.position=_world(room.position+Vector2i(1,1));actor_layer.add_child(pillar)

func _build_solid_props()->void:
	for value:Variant in layout.get("solid_props",[]):
		var prop:Dictionary=Dictionary(value)
		if String(prop.get("kind",""))=="_authored_static":continue
		var cell:=Vector2i(prop.get("cell",Vector2i.ZERO));var body:=StaticBody2D.new();body.name="CryptBlocker_%d_%d"%[cell.x,cell.y];body.position=_world(cell)
		var collision:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=17.0;collision.shape=circle;body.add_child(collision)
		var kinds:=["coffin","tomb","pillar"];var decor:=CRYPT_ART.make_decoration(kinds[absi(cell.x*13+cell.y*7)%kinds.size()]);body.add_child(decor);actor_layer.add_child(body)

func _spawn_player()->void:
	super._spawn_player();_spawn_crypt_hazards()

func _spawn_crypt_hazards()->void:
	crypt_hazards.clear();var floor:=run_state.current_floor;var rooms:Array=layout.get("rooms",[])
	for index:int in rooms.size():
		if index==0:continue
		var room:=Rect2i(rooms[index]);var kind:="bone_spikes"
		if floor>=3 and index%3==0:kind="soulflame"
		elif floor>=2 and index%2==0:kind="curse_sigil"
		var positions:Array[Vector2i]=[]
		if floor==7 and index==rooms.size()-1:kind="soulflame";positions.assign([room.get_center()+Vector2i(0,-3),room.get_center()+Vector2i(0,3)])
		elif floor>=5 and room.size.x>=8:positions.assign([room.get_center()+Vector2i(-2,0),room.get_center()+Vector2i(2,0)])
		else:positions.append(room.get_center())
		for hazard_cell in positions:
			if not layout.cells.has(hazard_cell) or Vector2i(hazard_cell).distance_to(Vector2i(layout.start))<3:continue
			var hazard:SlasherCryptHazard=CRYPT_HAZARD.new().setup(kind,player,float(index)*0.63);hazard.position=_world(Vector2i(hazard_cell));hazard.projectile_requested.connect(_on_hazard_projectile);actor_layer.add_child(hazard);crypt_hazards.append(hazard)

func _spawn_enemies()->void:
	enemies_remaining=0;var spawn_index:=0
	for spawn_value:Variant in layout.enemy_spawns:
		var record:Dictionary=Dictionary(spawn_value);var spawn:=Vector2i(record.get("position",Vector2i.ZERO));var is_boss:=bool(record.get("is_boss",false));var is_elite:=bool(record.get("is_mini_boss",false));var spec:=_crypt_enemy_spec(spawn_index,is_boss,is_elite)
		if use_authored_layout and not String(record.get("visual_id","")).is_empty():spec.visual_id=String(record.visual_id)
		if use_authored_layout and not String(record.get("behavior_id","")).is_empty():spec.behavior_id=String(record.behavior_id)
		_spawn_enemy(_world(spawn),String(spec.visual_id),String(spec.behavior_id),is_boss,is_elite);spawn_index+=1
	exit_open=enemies_remaining==0

func _crypt_enemy_spec(index:int,is_boss:bool,is_elite:bool)->Dictionary:
	if is_boss:return {"visual_id":"crypt_boss","behavior_id":"crypt_lord"}
	if is_elite:return {"visual_id":"necromancer","behavior_id":"grave_acolyte"}
	var floor:=run_state.current_floor;var roster:Array[Dictionary]=[{"visual_id":"skeletal_archer","behavior_id":"skeletal_archer"}]
	if floor>=2:roster.append({"visual_id":"necromancer","behavior_id":"grave_acolyte"})
	if floor>=3:roster.append({"visual_id":"soul_wisp","behavior_id":"soul_wisp"})
	if index%3==0:roster.append({"visual_id":"skeleton","behavior_id":""})
	return roster[(index+floor)%roster.size()]

func _spawn_enemy(world_position:Vector2,visual_id:String,behavior_id:String="",is_boss:bool=false,is_mini_boss:bool=false)->SlasherEnemy:
	var enemy:SlasherEnemy
	if behavior_id in ["skeletal_archer","grave_acolyte","soul_wisp","crypt_lord"] or is_boss:enemy=CRYPT_ENEMY.new()
	else:enemy=ENEMY_SCRIPT.new()
	enemy.name="CryptLord" if is_boss else visual_id.to_pascal_case();enemy.configure(run_state.current_floor,is_boss,visual_id,is_mini_boss,behavior_id);enemy.pathfinder=pathfinder;actor_layer.add_child(enemy);enemy.global_position=world_position;enemy.target=player;enemy.defeated.connect(_on_enemy_defeated);enemy.reinforcement_requested.connect(_on_reinforcement_requested);enemies_remaining+=1;return enemy

func _on_reinforcement_requested(archetypes:Array,origin:Vector2)->void:
	var active:=get_tree().get_nodes_in_group("slasher_enemy").size();var available:=maxi(0,6-active)
	for index:int in mini(available,archetypes.size()):
		var id:=String(archetypes[index]);var visual:="necromancer" if id=="grave_acolyte" else id;var requested:=origin+Vector2.RIGHT.rotated(TAU*float(index)/maxf(1.0,float(archetypes.size())))*115.0;_spawn_enemy(sanitize_player_position(requested),visual,id)

func _on_hazard_projectile(origin:Vector2,direction:Vector2,config:Dictionary)->void:
	if get_tree().get_nodes_in_group("crypt_projectile").size()>=72:return
	var projectile:=HOSTILE_PROJECTILE.new().setup(null,player,origin,direction,maxi(1,run_state.current_floor/2),config);actor_layer.add_child(projectile);projectile.add_to_group("crypt_projectile")

func _on_enemy_defeated(enemy:SlasherEnemy,reward:int)->void:
	super._on_enemy_defeated(enemy,reward)
	if enemies_remaining==0:_disable_crypt_threats()

func _disable_crypt_threats()->void:
	for hazard:SlasherCryptHazard in crypt_hazards:
		if is_instance_valid(hazard):hazard.disable()
	for projectile:Node in get_tree().get_nodes_in_group("crypt_projectile"):
		if is_instance_valid(projectile):projectile.queue_free()

func _build_mist()->void:
	var dust:=CPUParticles2D.new();dust.name="CryptDust";dust.amount=56;dust.lifetime=7.0;dust.preprocess=7.0;dust.emission_shape=CPUParticles2D.EMISSION_SHAPE_RECTANGLE;dust.emission_rect_extents=Vector2(float(layout.width*TILE)/2.0,float(layout.height*TILE)/2.0);dust.position=ORIGIN+dust.emission_rect_extents;dust.direction=Vector2(0.3,-0.1);dust.spread=35;dust.initial_velocity_min=2;dust.initial_velocity_max=8;dust.color=Color(0.57,0.53,0.78,0.12);dust.z_index=5;add_child(dust)

func _build_vignette()->void:
	var layer:=CanvasLayer.new();layer.name="CryptLighting";layer.layer=0;add_child(layer);var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material:=ShaderMaterial.new();var shader:=Shader.new();shader.code="shader_type canvas_item; void fragment(){vec2 p=UV-vec2(0.5);float edge=smoothstep(0.25,0.72,length(p));COLOR=vec4(0.035,0.02,0.09,0.16+edge*0.46);}";material.shader=shader;shade.material=material;layer.add_child(shade)
