extends "res://scripts/scenes/sunken_mine.gd"

func _configure_dungeon_settings()->void:
	dungeon_id="moonlit_grove";dungeon_title="Moonlit Grove";dungeon_floor_label="Promise";complete_floor_method="complete_strategy_dungeon_floor";victory_text_template="You step out of the Moonlit Grove with %d gold and fate clinging to your shadows.";grid_w=24;grid_h=12;tile_size=40;use_follow_camera=true;camera_ui_right_margin=360.0;camera_ui_top_margin=90.0;message="Moonlit paths rearrange themselves behind the party.";if ground_layer!=null:ground_layer.modulate=Color("a7bcec")
func _choose_layout_type()->String:return ["flooded_gallery","collapsed_switchback","pump_station"][(rng.randi_range(0,2)+_current_floor())%3]
func _enemy_type_for_spawn(index:int)->String:return "necromancer" if index%5==0 else ("blood_wolf" if index%2==0 else "ghoul")
func _place_traps()->void:
	for i in range(2+int(_current_floor()>=3)):traps.append({"pos":_pick_floor_cell(true),"sprung":false,"hazard_kind":"fate_path" if i%2==0 else "fae_bargain"})
func _place_dungeon_merchant()->void:dungeon_merchant={}
func _floor_intro_message()->String:return "Promise %d/%d: %s"%[_current_floor(),_max_floors(),"The Moon Court's hunt closes in." if _current_floor()>=_max_floors() else "Silver paths answer choices the party has not made yet."]
