extends "res://scripts/scenes/forest.gd"

# Sunken Mine owns its generation and encounter identity while reusing the
# tactical combat, party, extraction, loot, and HUD contracts from Forest.

const MINE_BOSS_CHAMBER := {
	"id":"drowned_engine",
	"name":"The Drowned Engine",
	"rows":[
		"########################",
		"######.....E.....#######",
		"####...R..T.T..R...#####",
		"###..K....B....G.....###",
		"##.....RR...RR.........#",
		"##..W....T.T....W......#",
		"###....A.....A.......###",
		"####..G...C...P.....####",
		"#####....R.R.......#####",
		"######.....S.....#######",
		"########.......#########",
		"########################",
	],
}

func _configure_dungeon_settings() -> void:
	dungeon_id="sunken_mine";dungeon_title="Sunken Mine";dungeon_floor_label="Shaft"
	complete_floor_method="complete_strategy_dungeon_floor"
	victory_text_template="You surface from the Sunken Mine with %d gold and ore-stained gear."
	grid_w=24;grid_h=12;tile_size=40;use_follow_camera=true;camera_ui_right_margin=360.0;camera_ui_top_margin=90.0
	message="Cold water runs over the rails. Somewhere below, old machinery turns."
	if ground_layer!=null:ground_layer.modulate=Color("8fc2cb")

func _choose_layout_type() -> String:
	var layouts:Array[String]=["flooded_gallery","collapsed_switchback"]
	if _current_floor()>=3:layouts.append("pump_station")
	if _current_floor()>=4:layouts.append("ore_works")
	return layouts[rng.randi_range(0,layouts.size()-1)]

func _build_room_graph(kind:String)->void:
	match kind:
		"flooded_gallery":
			_add_rooms([Vector2i(2,9),Vector2i(6,9),Vector2i(10,7),Vector2i(14,7),Vector2i(18,4),Vector2i(21,2),Vector2i(9,2),Vector2i(17,10)])
			_connect_rooms([[0,1],[1,2],[2,3],[3,4],[4,5],[2,6],[3,7]]);critical_room_ids=[0,1,2,3,4,5]
		"collapsed_switchback":
			_add_rooms([Vector2i(2,9),Vector2i(5,6),Vector2i(8,3),Vector2i(12,3),Vector2i(15,6),Vector2i(19,8),Vector2i(22,3),Vector2i(11,9)])
			_connect_rooms([[0,1],[1,2],[2,3],[3,4],[4,5],[5,6],[3,7],[7,5]]);critical_room_ids=[0,1,2,3,4,5,6]
		"pump_station":
			_add_rooms([Vector2i(2,9),Vector2i(6,8),Vector2i(10,8),Vector2i(13,5),Vector2i(17,5),Vector2i(21,2),Vector2i(8,2),Vector2i(18,10)])
			_connect_rooms([[0,1],[1,2],[2,3],[3,4],[4,5],[3,6],[4,7]]);critical_room_ids=[0,1,2,3,4,5]
		"ore_works":
			_add_rooms([Vector2i(2,9),Vector2i(5,9),Vector2i(9,6),Vector2i(13,6),Vector2i(17,3),Vector2i(22,2),Vector2i(9,2),Vector2i(14,10),Vector2i(20,9)])
			_connect_rooms([[0,1],[1,2],[2,3],[3,4],[4,5],[2,6],[3,7],[7,8],[8,4]]);critical_room_ids=[0,1,2,3,4,5]
		_:super._build_room_graph(kind)

func _build_boss_chamber()->void:
	layout_type="boss_drowned_engine";boss_chamber_name=String(MINE_BOSS_CHAMBER.name);message=_floor_intro_message();secret={"pos":Vector2i(-1,-1),"found":true}
	_carve_boss_chamber(MINE_BOSS_CHAMBER);_mark_boss_critical_path()
	room_graph=[{"id":0,"center":player_pos,"radius":Vector2i(1,1),"neighbors":[1],"role":"start"},{"id":1,"center":Vector2i(12,5),"radius":Vector2i(6,4),"neighbors":[0,2],"role":"elite"},{"id":2,"center":exit_pos,"radius":Vector2i(1,1),"neighbors":[1],"role":"exit"}];critical_room_ids=[0,1,2]

func _apply_boss_chamber_symbol(symbol:String,tile:Vector2i)->void:
	match symbol:
		"S":player_pos=tile
		"E":exit_pos=tile
		"B":_add_enemy(tile,"crypt_boss",40,7,true,true)
		"W":_add_floor_enemy(tile,"armored_skeleton")
		"A":_add_floor_enemy(tile,"ghoul")
		"G":loot.append({"kind":"gold","pos":tile,"amount":16})
		"C":chest={"pos":tile,"opened":false}
		"R":props.append({"kind":"rock","pos":tile,"hp":GameBalance.get_prop_hp("rock",2)})
		"T":traps.append({"pos":tile,"sprung":false,"hazard_kind":"flooded_rail"})
		"K":loot.append({"kind":"key","pos":tile,"amount":1})
		"P":loot.append({"kind":"potion","pos":tile,"amount":1})

func _place_enemies()->void:
	var count:=mini(4+_current_floor(),10)
	for i in range(count):_add_floor_enemy(_pick_floor_cell(true),_enemy_type_for_spawn(i))

func _enemy_type_for_spawn(spawn_index:int)->String:
	if _current_floor()<=2:return "kobold" if spawn_index%3==0 else "skeleton"
	if _current_floor()<=4:return "armored_skeleton" if spawn_index%4==0 else ("ghoul" if spawn_index%2==0 else "kobold")
	return "necromancer" if spawn_index%5==0 else ("armored_skeleton" if spawn_index%2==0 else "ghoul")

func _place_traps()->void:
	var kinds:Array[String]=["deep_water","cave_in","ore_machinery"]
	for i in range(2+int(_current_floor()>=3)+int(_current_floor()>=5)):
		traps.append({"pos":_pick_role_cell("trap",true) if i==0 else _pick_floor_cell(true),"sprung":false,"hazard_kind":kinds[i%kinds.size()]})

func _place_props()->void:
	for kind in ["rock","barrel","rock","barrel","rock","campfire"]:
		props.append({"kind":kind,"pos":_pick_floor_cell(false),"hp":GameBalance.get_prop_hp(kind,99 if kind=="campfire" else 2)})

func _place_decorations()->void:
	var kinds:Array[String]=["mossy_rock","crypt_pillar","bone_pile"]
	for i in range(22):
		var tile:=_pick_floor_cell(true)
		if not _decoration_at(tile) and _distance(tile,player_pos)>1 and _distance(tile,exit_pos)>1:_add_decoration(kinds[i%kinds.size()],tile,Vector2(rng.randf_range(-4.0,4.0),rng.randf_range(-3.0,4.0)))
	_place_border_decorations(kinds)

func _floor_intro_message()->String:
	if layout_type.begins_with("boss_"):return "Shaft %d/%d: the Drowned Engine shudders awake."%[_current_floor(),_max_floors()]
	var notes:={"flooded_gallery":"Floodwater hides the rails and every safe foothold.","collapsed_switchback":"Fresh cave-ins split the old switchback tunnels.","pump_station":"Corroded pumps hammer against the rising water.","ore_works":"Ore carts and crushing machinery choke the main works."}
	return "Shaft %d/%d: %s"%[_current_floor(),_max_floors(),String(notes.get(layout_type,"The drowned veins descend."))]

func _layout_display_name()->String:return "Drowned Engine" if layout_type.begins_with("boss_") else layout_type.replace("_"," ").capitalize()
