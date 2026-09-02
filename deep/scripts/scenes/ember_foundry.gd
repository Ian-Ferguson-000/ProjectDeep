extends "res://scripts/scenes/sunken_mine.gd"

func _configure_dungeon_settings()->void:
	dungeon_id="ember_foundry";dungeon_title="Ember Foundry";dungeon_floor_label="Forge"
	complete_floor_method="complete_strategy_dungeon_floor";victory_text_template="You leave the Ember Foundry with %d gold as its furnaces finally cool."
	grid_w=24;grid_h=12;tile_size=40;use_follow_camera=true;camera_ui_right_margin=360.0;camera_ui_top_margin=90.0;message="Conveyors grind forward beneath a ceiling red with heat."
	if ground_layer!=null:ground_layer.modulate=Color("e89b72")

func _choose_layout_type()->String:
	var layouts:Array[String]=["conveyor_hall","smelter_crossing","assembly_floor"]
	if _current_floor()>=4:layouts.append("warforge")
	return layouts[rng.randi_range(0,layouts.size()-1)]

func _build_room_graph(kind:String)->void:
	match kind:
		"conveyor_hall":_add_rooms([Vector2i(2,9),Vector2i(6,9),Vector2i(10,9),Vector2i(14,6),Vector2i(18,4),Vector2i(22,2),Vector2i(10,3),Vector2i(18,10)]);_connect_rooms([[0,1],[1,2],[2,3],[3,4],[4,5],[2,6],[3,7]]);critical_room_ids=[0,1,2,3,4,5]
		"smelter_crossing":_add_rooms([Vector2i(2,9),Vector2i(6,6),Vector2i(10,6),Vector2i(14,6),Vector2i(18,6),Vector2i(22,2),Vector2i(10,2),Vector2i(14,10)]);_connect_rooms([[0,1],[1,2],[2,3],[3,4],[4,5],[2,6],[3,7]]);critical_room_ids=[0,1,2,3,4,5]
		"assembly_floor":_add_rooms([Vector2i(2,9),Vector2i(5,9),Vector2i(9,7),Vector2i(13,4),Vector2i(17,4),Vector2i(22,2),Vector2i(12,10),Vector2i(19,9)]);_connect_rooms([[0,1],[1,2],[2,3],[3,4],[4,5],[2,6],[6,7],[7,4]]);critical_room_ids=[0,1,2,3,4,5]
		"warforge":_add_rooms([Vector2i(2,9),Vector2i(6,9),Vector2i(9,5),Vector2i(13,5),Vector2i(17,5),Vector2i(22,2),Vector2i(9,2),Vector2i(13,10),Vector2i(19,10)]);_connect_rooms([[0,1],[1,2],[2,3],[3,4],[4,5],[2,6],[3,7],[7,8],[8,4]]);critical_room_ids=[0,1,2,3,4,5]
		_:super._build_room_graph(kind)

func _build_boss_chamber()->void:
	layout_type="boss_last_warmachine";boss_chamber_name="The Last Warmachine";message=_floor_intro_message();secret={"pos":Vector2i(-1,-1),"found":true}
	var chamber:Dictionary={"rows":["########################","######.....E.....#######","####...T..T.T..T...#####","###..G....B....G.....###","##.....RR...RR.........#","##..A....T.T....A......#","###....A.....A.......###","####..G...C...P.....####","#####....R.R.......#####","######.....S.....#######","########.......#########","########################"]}
	_carve_boss_chamber(chamber);_mark_boss_critical_path();room_graph=[{"id":0,"center":player_pos,"neighbors":[1],"role":"start"},{"id":1,"center":Vector2i(12,5),"neighbors":[0,2],"role":"elite"},{"id":2,"center":exit_pos,"neighbors":[1],"role":"exit"}];critical_room_ids=[0,1,2]

func _apply_boss_chamber_symbol(symbol:String,tile:Vector2i)->void:
	match symbol:
		"S":player_pos=tile
		"E":exit_pos=tile
		"B":_add_enemy(tile,"crypt_boss",52,9,true,true)
		"A":_add_floor_enemy(tile,"armored_skeleton")
		"G":loot.append({"kind":"gold","pos":tile,"amount":20})
		"C":chest={"pos":tile,"opened":false}
		"R":props.append({"kind":"barrel","pos":tile,"hp":GameBalance.get_prop_hp("barrel",2)})
		"T":traps.append({"pos":tile,"sprung":false,"hazard_kind":"forge_burst"})
		"P":loot.append({"kind":"potion","pos":tile,"amount":1})

func _enemy_type_for_spawn(index:int)->String:
	if _current_floor()<=2:return "armored_skeleton" if index%3==0 else "kobold"
	return "necromancer" if index%5==0 else ("armored_skeleton" if index%2==0 else "blood_wolf")

func _place_traps()->void:
	var kinds:Array[String]=["molten_channel","conveyor","forge_burst"]
	for i in range(3+int(_current_floor()>=4)):traps.append({"pos":_pick_floor_cell(true),"sprung":false,"hazard_kind":kinds[i%3]})

func _floor_intro_message()->String:
	if layout_type.begins_with("boss_"):return "Forge %d/%d: the Last Warmachine tears free of its cradle."%[_current_floor(),_max_floors()]
	return "Forge %d/%d: %s"%[_current_floor(),_max_floors(),{"conveyor_hall":"Loaded belts drag everything toward the furnace.","smelter_crossing":"Molten channels divide the smelter floor.","assembly_floor":"Half-built constructs twitch along the line.","warforge":"The oldest forge hammers without a smith."}.get(layout_type,"Heat rolls through the ruined works.")]
