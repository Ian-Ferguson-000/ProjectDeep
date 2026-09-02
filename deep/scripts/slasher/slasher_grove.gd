extends "res://scripts/slasher/slasher_mine.gd"
func _build_world()->void:
	super._build_world();for child in low_decor_layer.get_children():if child is Polygon2D:child.color=Color(0.42,0.58,0.94,0.24)
func _mine_enemy_spec(index:int,is_boss:bool,is_elite:bool)->Dictionary:
	if is_boss:return {"visual_id":"moon_court_huntress","behavior_id":""}
	if is_elite:return {"visual_id":"poison_ranger","behavior_id":"elite_guardian"}
	var choices:Array[String]=["dark_druid","ice_mage","spore_beast","poison_ranger"];return {"visual_id":choices[(index+run_state.current_floor)%choices.size()],"behavior_id":""}
func _process(delta:float)->void:super._process(delta)
