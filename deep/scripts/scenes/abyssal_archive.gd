extends "res://scripts/scenes/ember_foundry.gd"

func _configure_dungeon_settings()->void:
	dungeon_id="abyssal_archive";dungeon_title="Abyssal Archive";dungeon_floor_label="Volume";complete_floor_method="complete_strategy_dungeon_floor";victory_text_template="You seal the Abyssal Archive and return with %d gold and forbidden relics.";grid_w=24;grid_h=12;tile_size=40;use_follow_camera=true;camera_ui_right_margin=360.0;camera_ui_top_margin=90.0;message="Shelves move when no one reads them.";if ground_layer!=null:ground_layer.modulate=Color("b184d6")
func _choose_layout_type()->String:return ["conveyor_hall","smelter_crossing","assembly_floor","warforge"][(rng.randi_range(0,3)+_current_floor())%4]
func _enemy_type_for_spawn(index:int)->String:return "necromancer" if index%3==0 else ("armored_skeleton" if index%2==0 else "ghoul")
func _place_traps()->void:
	for i in range(3+int(_current_floor()>=4)):traps.append({"pos":_pick_floor_cell(true),"sprung":false,"hazard_kind":"void_margin" if i%2==0 else "rewritten_room"})
func _place_dungeon_merchant()->void:dungeon_merchant={}
func _floor_intro_message()->String:return "Volume %d/%d: %s"%[_current_floor(),_max_floors(),"The Unwritten Curator closes the final index." if _current_floor()>=_max_floors() else "A forbidden chapter rewrites the room around its readers."]
