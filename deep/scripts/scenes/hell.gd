extends "res://scripts/scenes/crypt.gd"

func _configure_dungeon_settings()->void:
	dungeon_id="balors_hell";dungeon_title="Balor's Hell";dungeon_floor_label="Circle";complete_floor_method="complete_strategy_dungeon_floor";victory_text_template="Balor falls and the infernal gate collapses behind you. You carry %d gold from Hell.";grid_w=24;grid_h=15;tile_size=40;use_follow_camera=true;camera_ui_right_margin=360.0;camera_ui_top_margin=90.0;message="The gate opens onto iron, ash, and a sky made of fire."

func _enemy_type_for_spawn(spawn_index:int)->String:
	var roster:=["infernal_caster","rift_stalker"]
	if _current_floor()>=2:roster.append("hellcharger")
	if _current_floor()>=3:roster.append("cinder_bomber")
	return String(roster[(spawn_index+_current_floor())%roster.size()])

func _add_boss_enemy(tile:Vector2i)->void:
	_add_enemy(tile,"balor",int(GameBalance.get_enemy_value("balor","health",48)),int(GameBalance.get_enemy_value("balor","damage",8)),true,true)

func _apply_boss_chamber_symbol(symbol:String,tile:Vector2i)->void:
	match symbol:
		"Y":_add_floor_enemy(tile,"rift_stalker")
		"A":_add_floor_enemy(tile,"hellcharger")
		"G":_add_floor_enemy(tile,"cinder_bomber")
		"N":_add_floor_enemy(tile,"infernal_caster")
		_:super._apply_boss_chamber_symbol(symbol,tile)

func _place_decorations()->void:
	for index:int in 28:
		var kind:="campfire" if index%3==0 else ("rock" if index%3==1 else "bone_pile");_add_decoration(kind,_pick_floor_cell(true),Vector2.ZERO)

func _floor_intro_message()->String:
	return "Circle %d/%d: fire crosses the arena in overlapping waves."%[_current_floor(),_max_floors()]
