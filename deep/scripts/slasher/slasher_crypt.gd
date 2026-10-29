extends "res://scripts/slasher/slasher_forest_rooms.gd"

## The Stone Crypt. Plays as rooms like the forest (maps/crypt/rooms/, 1.5x the
## forest's size), with stone walls, iron bars on the doors, stairs down at the
## gate, crypt hazards in fighting rooms and its own foes. The guardian floor's
## gate room holds Big Skelly Boi (slasher_charnel_king.gd).
##
## Merchant interludes still use the old single generated floor, so the code
## for that (the "legacy" functions below) stays.

const CRYPT_HAZARD:=preload("res://scripts/slasher/slasher_crypt_hazard.gd")
const CRYPT_ART:=preload("res://scripts/slasher/slasher_crypt_art.gd")
const HOSTILE_PROJECTILE:=preload("res://scripts/slasher/slasher_hostile_projectile.gd")
## Room map decorations (forest names) -> crypt dressing.
const ROOM_DECOR:={"mossy_rock":"rubble","pebbles":"bone_pile","mushrooms":"candles","low_bush_a":"urn","low_bush_b":"tombstone","rounded_bush":"grave_cross"}
## Drawn in code by SlasherCryptArt rather than cut from a sheet.
const DRAWN_DECOR:=["bone_pile","candles"]
## Plain foes by floor: each floor adds to the mix. Ids are enemies.<id> in slasher_balance.json.
const ROSTER_BY_FLOOR:=[
	["skeleton","grave_rat","ghoul","skeletal_archer"],
	["gravedigger","revenant"],
	["grave_acolyte","tomb_guard"],
	["soul_wisp"],
]
## Enemy id -> sprite used (several reuse art under a new name; see docs/Crypt.md).
const VISUAL_FOR:={"grave_acolyte":"necromancer"}

var crypt_hazards:Array[SlasherCryptHazard]=[]
var _nesting:=false

func _reinforcement_visual_ids()->Array[String]:
	return ["skeletal_archer","necromancer","soul_wisp","revenant","grave_rat"]

func _room_theme()->Dictionary:
	var theme:Dictionary=super._room_theme()
	theme.merge({
		"walls":"stone","gate_name":"Stairs Down","exit_sprite":"stairs_down","exit_glow":"#a58cff",
		"gate_open":"The stairs are open · descend deeper.","room_clear":"Room cleared · the bars lift.",
		"guardian_falls":"The guardian falls · the dead crumble and the stairs open.",
		"prop_kinds":{"tree_large":"coffin"},"hollow_kind":"coffin","hollow_found":"Something rattles inside the broken coffin…",
	},true)
	return theme

# ---------------------------------------------------------------- world

func _build_world()->void:
	super._build_world()
	if rooms_active:return
	if show_generated_ground or not authored_visuals_active:
		for child:Node in ground_layer.get_children():child.free()
		for value:Variant in layout.cells:
			var cell:=Vector2i(value);var stone:=CRYPT_ART.make_ground_sprite(cell,TILE);stone.name="CryptStone_%d_%d"%[cell.x,cell.y];stone.position=_world(cell);ground_layer.add_child(stone)
	for child in low_decor_layer.get_children():
		if child is CanvasItem:(child as CanvasItem).modulate=Color("#bbb7ce")

func _build_decorations()->void:
	if rooms_active:
		for value:Variant in layout.get("decorations",[]):
			var decoration:Dictionary=value;var kind:=String(ROOM_DECOR.get(String(decoration.kind),String(decoration.kind)))
			var node:Node2D=CRYPT_ART.make_decoration(kind) if DRAWN_DECOR.has(kind) else SlasherForestArt.make_sprite(kind)
			node.name="Decor_%s"%kind;node.position=_world(Vector2i(decoration.cell))+Vector2(decoration.get("offset",Vector2.ZERO));low_decor_layer.add_child(node)
		return
	_build_legacy_decorations()

func _build_legacy_decorations()->void:
	var cells:Array=layout.cells.keys();cells.sort_custom(func(a:Vector2i,b:Vector2i)->bool:return a.y<b.y or a.y==b.y and a.x<b.x)
	var kinds:=["bone_pile","candles","rubble","grave","coffin"]
	var stride:=maxi(8,13-run_state.current_floor)
	for index:int in range(0,cells.size(),stride):
		var cell:=Vector2i(cells[index]);if cell.distance_to(Vector2(layout.start))<3.0 or cell.distance_to(Vector2(layout.exit))<3.0:continue
		var decor:=CRYPT_ART.make_decoration(kinds[(index/stride+run_state.current_floor)%kinds.size()]);decor.position=_world(cell)+Vector2(0,9);low_decor_layer.add_child(decor)
	for room_value:Variant in layout.get("rooms",[]):
		var room_rect:=Rect2i(room_value);var pillar:=CRYPT_ART.make_decoration("pillar");pillar.position=_world(room_rect.position+Vector2i(1,1));actor_layer.add_child(pillar)

func _build_solid_props()->void:
	if rooms_active:
		super._build_solid_props()
		return
	for value:Variant in layout.get("solid_props",[]):
		var prop:Dictionary=Dictionary(value)
		if String(prop.get("kind",""))=="_authored_static":continue
		var cell:=Vector2i(prop.get("cell",Vector2i.ZERO));var body:=StaticBody2D.new();body.name="CryptBlocker_%d_%d"%[cell.x,cell.y];body.position=_world(cell)
		var collision:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=17.0;collision.shape=circle;body.add_child(collision)
		var kinds:=["coffin","tomb","pillar"];var decor:=CRYPT_ART.make_decoration(kinds[absi(cell.x*13+cell.y*7)%kinds.size()]);body.add_child(decor);actor_layer.add_child(body)

## Iron bars across a door while foes remain.
func _dress_door_barrier(barrier:Node2D,direction:String)->void:
	var bars:=IronBars.new();bars.vertical=direction in ["east","west"];barrier.add_child(bars)

func _make_colossus_remains()->Node2D:
	return BoneHeap.new()

# ---------------------------------------------------------------- hazards

func _spawn_player()->void:
	super._spawn_player()
	if rooms_active:_spawn_room_hazards()
	else:_spawn_crypt_hazards()

## Bone spikes, curse sigils and soulflames in rooms that still have foes.
## TUNING: one hazard on floor 1, one more every two floors, three at most.
func _spawn_room_hazards()->void:
	crypt_hazards.clear()
	if bool(room.get("cleared",false)) or not room_role in ["combat","elite","boss"]:return
	if bool(layout.get("is_boss_floor",false)) and room_role=="boss":return
	var floor_number:=run_state.current_floor;var count:=mini(3,1+int(floor_number/2.0))
	var rng:=RandomNumberGenerator.new();rng.seed=hash("%s:%d:hazards"%[String(run_state.field_run.get("forest_floor_key","")),room_id])
	var blocked:={}
	for prop in layout.solid_props:blocked[Vector2i(prop.cell)]=true
	var keep_clear:Array[Vector2i]=[Vector2i(layout.start)]
	for door in Dictionary(layout.door_slots).values():keep_clear.append(Vector2i(door))
	if Vector2i(layout.exit).x>=0:keep_clear.append(Vector2i(layout.exit))
	var candidates:Array[Vector2i]=[]
	for value in layout.cells:
		var cell:Vector2i=value
		if blocked.has(cell):continue
		var clear:=true
		for spot in keep_clear:
			if cell.distance_to(spot)<5.0:clear=false;break
		if clear:candidates.append(cell)
	for index in count:
		if candidates.is_empty():break
		var cell:Vector2i=candidates.pop_at(rng.randi_range(0,candidates.size()-1))
		var kind:="bone_spikes"
		if floor_number>=3 and index==2:kind="soulflame"
		elif floor_number>=2 and index==1:kind="curse_sigil"
		var hazard:SlasherCryptHazard=CRYPT_HAZARD.new().setup(kind,player,float(index)*0.63);hazard.position=_world(cell);hazard.projectile_requested.connect(_on_hazard_projectile);actor_layer.add_child(hazard);crypt_hazards.append(hazard)
		candidates=candidates.filter(func(other:Vector2i)->bool:return other.distance_to(cell)>=6.0)

func _spawn_crypt_hazards()->void:
	crypt_hazards.clear();var floor:=run_state.current_floor;var rooms:Array=layout.get("rooms",[])
	for index:int in rooms.size():
		if index==0:continue
		var room_rect:=Rect2i(rooms[index]);var kind:="bone_spikes"
		if floor>=3 and index%3==0:kind="soulflame"
		elif floor>=2 and index%2==0:kind="curse_sigil"
		var positions:Array[Vector2i]=[]
		if floor==7 and index==rooms.size()-1:kind="soulflame";positions.assign([room_rect.get_center()+Vector2i(0,-3),room_rect.get_center()+Vector2i(0,3)])
		elif floor>=5 and room_rect.size.x>=8:positions.assign([room_rect.get_center()+Vector2i(-2,0),room_rect.get_center()+Vector2i(2,0)])
		else:positions.append(room_rect.get_center())
		for hazard_cell in positions:
			if not layout.cells.has(hazard_cell) or Vector2i(hazard_cell).distance_to(Vector2i(layout.start))<3:continue
			var hazard:SlasherCryptHazard=CRYPT_HAZARD.new().setup(kind,player,float(index)*0.63);hazard.position=_world(Vector2i(hazard_cell));hazard.projectile_requested.connect(_on_hazard_projectile);actor_layer.add_child(hazard);crypt_hazards.append(hazard)

# ---------------------------------------------------------------- foes

func _spawn_enemies()->void:
	if rooms_active:
		super._spawn_enemies()
		return
	enemies_remaining=0;var spawn_index:=0
	for spawn_value:Variant in layout.enemy_spawns:
		var record:Dictionary=Dictionary(spawn_value);var spawn:=Vector2i(record.get("position",Vector2i.ZERO));var is_boss:=bool(record.get("is_boss",false));var is_elite:=bool(record.get("is_mini_boss",false));var spec:=_crypt_enemy_spec(spawn_index,is_boss,is_elite)
		if use_authored_layout and not String(record.get("visual_id","")).is_empty():spec.visual_id=String(record.visual_id)
		if use_authored_layout and not String(record.get("behavior_id","")).is_empty():spec.behavior_id=String(record.behavior_id)
		_spawn_enemy(_world(spawn),String(spec.visual_id),String(spec.behavior_id),is_boss,is_elite);spawn_index+=1
	exit_open=enemies_remaining==0
	_attach_boss_bar()

## Rooms: plain foes come from the crypt's roster, growing with depth.
func _normal_enemy_spec(spawn_index:int,_wolf_counts:Dictionary)->Dictionary:
	var roster:Array[String]=[]
	for tier in mini(ROSTER_BY_FLOOR.size(),run_state.current_floor):roster.append_array(ROSTER_BY_FLOOR[tier])
	var id:=roster[(spawn_index*5+run_state.current_floor+room_id*3)%roster.size()]
	# Plain skeletons use the shared melee behaviour (no behaviour id of their own).
	return {"visual_id":String(VISUAL_FOR.get(id,id)),"behavior_id":"" if id=="skeleton" else id}

func _crypt_enemy_spec(index:int,is_boss:bool,is_elite:bool)->Dictionary:
	if is_boss:return {"visual_id":"crypt_boss","behavior_id":"crypt_lord"}
	if is_elite:return {"visual_id":"necromancer","behavior_id":"grave_acolyte"}
	var floor:=run_state.current_floor;var roster:Array[Dictionary]=[{"visual_id":"skeletal_archer","behavior_id":"skeletal_archer"}]
	if floor>=2:roster.append({"visual_id":"necromancer","behavior_id":"grave_acolyte"})
	if floor>=3:roster.append({"visual_id":"soul_wisp","behavior_id":"soul_wisp"})
	if index%3==0:roster.append({"visual_id":"skeleton","behavior_id":""})
	return roster[(index+floor)%roster.size()]

func _spawn_enemy(world_position:Vector2,visual_id:String,behavior_id:String="",is_boss:bool=false,is_mini_boss:bool=false)->SlasherEnemy:
	var enemy:SlasherEnemy=_instantiate_enemy(visual_id)
	enemy.name=("CryptLord" if visual_id=="crypt_boss" else visual_id.to_pascal_case()) if (is_boss or is_mini_boss) else visual_id.to_pascal_case();enemy.configure(run_state.current_floor,is_boss,visual_id,is_mini_boss,behavior_id);enemy.pathfinder=pathfinder;actor_layer.add_child(enemy);enemy.global_position=world_position;enemy.target=player;enemy.defeated.connect(_on_enemy_defeated);enemy.reinforcement_requested.connect(_on_reinforcement_requested);enemies_remaining+=1
	if enemy is SlasherColossus:(enemy as SlasherColossus).arena=room_arena()
	if is_boss:call_deferred("_warm_reinforcement_visuals",_reinforcement_visual_ids())
	# Grave rats come in nests of three.
	if rooms_active and behavior_id=="grave_rat" and not _nesting:
		_nesting=true
		for index in 2:_spawn_enemy(sanitize_player_position(world_position+Vector2.RIGHT.rotated(TAU*index/2.0+0.8)*30.0),"grave_rat","grave_rat")
		_nesting=false
	return enemy

func _on_reinforcement_requested(archetypes:Array,origin:Vector2)->void:
	var active:=get_tree().get_nodes_in_group("slasher_enemy").size();var available:=maxi(0,8-active)
	for index:int in mini(available,archetypes.size()):
		var id:=String(archetypes[index]);var visual:=String(VISUAL_FOR.get(id,id));var requested:=origin+Vector2.RIGHT.rotated(TAU*float(index)/maxf(1.0,float(archetypes.size())))*115.0
		_nesting=true;_spawn_enemy(sanitize_player_position(requested),visual,id);_nesting=false

func _on_hazard_projectile(origin:Vector2,direction:Vector2,config:Dictionary)->void:
	AudioCue.play_at_from(self,"cast_aether",origin)
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

# ---------------------------------------------------------------- atmosphere

func _build_mist()->void:
	var dust:=CPUParticles2D.new();dust.name="CryptDust";dust.amount=56;dust.lifetime=7.0;dust.preprocess=7.0;dust.emission_shape=CPUParticles2D.EMISSION_SHAPE_RECTANGLE;dust.emission_rect_extents=Vector2(float(layout.width*TILE)/2.0,float(layout.height*TILE)/2.0);dust.position=ORIGIN+dust.emission_rect_extents;dust.direction=Vector2(0.3,-0.1);dust.spread=35;dust.initial_velocity_min=2;dust.initial_velocity_max=8;dust.color=Color(0.57,0.53,0.78,0.12);dust.z_index=5;add_child(dust)

func _build_vignette()->void:
	var layer:=CanvasLayer.new();layer.name="CryptLighting";layer.layer=0;add_child(layer);var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material:=ShaderMaterial.new();var shader:=Shader.new();shader.code="shader_type canvas_item; void fragment(){vec2 p=UV-vec2(0.5);float edge=smoothstep(0.25,0.72,length(p));COLOR=vec4(0.035,0.02,0.09,0.16+edge*0.46);}";material.shader=shader;shade.material=material;layer.add_child(shade)

# ---------------------------------------------------------------- drawn pieces

## Iron bars across a doorway.
class IronBars extends Node2D:
	var vertical:=false
	func _ready()->void:z_index=2
	func _draw()->void:
		var iron:=Color("#3a3640");var shine:=Color("#77707f")
		for index in 5:
			var offset:=-18.0+index*9.0
			var a:=Vector2(offset,-26) if not vertical else Vector2(-22,offset)
			var b:=Vector2(offset,20) if not vertical else Vector2(22,offset)
			draw_line(a,b,iron,5.0);draw_line(a+Vector2(-1,0),b+Vector2(-1,0),shine,1.0)
		var bar_a:=Vector2(-24,-14) if not vertical else Vector2(-12,-24)
		var bar_b:=Vector2(24,-14) if not vertical else Vector2(-12,24)
		draw_line(bar_a,bar_b,iron,6.0);draw_line(bar_a+Vector2(0,24) if not vertical else bar_a+Vector2(24,0),bar_b+Vector2(0,24) if not vertical else bar_b+Vector2(24,0),iron,6.0)

## What's left of Big Skelly Boi: a heap of bones and a cracked crown.
class BoneHeap extends Node2D:
	func _draw()->void:
		var half:=Vector2(ForestRoomLibrary.COLOSSUS_SIZE)*24.0
		draw_set_transform(Vector2(0,half.y*0.45),0.0,Vector2(1.0,0.4));draw_circle(Vector2.ZERO,half.x,Color(0,0,0,0.3));draw_set_transform(Vector2.ZERO)
		var bone:=Color("#b9b1a0");var dark:=Color("#4a4550")
		var rng:=RandomNumberGenerator.new();rng.seed=777
		for index in 26:
			var at:=Vector2(rng.randf_range(-half.x*0.8,half.x*0.8),rng.randf_range(-half.y*0.5,half.y*0.7))
			var angle:=rng.randf_range(0,TAU);var length:=rng.randf_range(18,40)
			var tip:=Vector2.RIGHT.rotated(angle)*length*0.5
			draw_line(at-tip,at+tip,dark,8.0);draw_line(at-tip,at+tip,bone,5.0)
			draw_circle(at-tip,5,bone);draw_circle(at+tip,5,bone)
		# The skull, split.
		draw_circle(Vector2(-6,-half.y*0.1),46,dark);draw_circle(Vector2(-6,-half.y*0.1),42,bone.darkened(0.1))
		draw_circle(Vector2(-22,-half.y*0.15),11,Color("#120d16"));draw_circle(Vector2(10,-half.y*0.15),11,Color("#120d16"))
		draw_line(Vector2(-6,-half.y*0.1-42),Vector2(4,-half.y*0.1+20),Color("#120d16"),3.0)
		for index in 5:
			var x:=-34.0+index*17.0
			draw_colored_polygon(PackedVector2Array([Vector2(x-6,-half.y*0.1-34),Vector2(x,-half.y*0.1-58+(8 if index==2 else 0)),Vector2(x+6,-half.y*0.1-34)]),Color("#8a7038"))
