extends "res://scripts/slasher/slasher_foundry.gd"
func _build_world()->void:
	super._build_world();for child in low_decor_layer.get_children():if child is Polygon2D:child.color=Color(0.38,0.18,0.62,0.30)
func _mine_enemy_spec(index:int,is_boss:bool,is_elite:bool)->Dictionary:
	if is_boss:return {"visual_id":"unwritten_curator","behavior_id":""}
	if is_elite:return {"visual_id":"dark_druid","behavior_id":"elite_guardian"}
	var choices:Array[String]=["dark_druid","fire_mage","ice_mage","briar_guardian"];return {"visual_id":choices[(index+run_state.current_floor)%choices.size()],"behavior_id":""}
