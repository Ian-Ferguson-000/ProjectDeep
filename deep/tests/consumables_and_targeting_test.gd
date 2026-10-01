extends SceneTree

const FOREST:=preload("res://scenes/slasher/SlasherForest.tscn")
func _initialize()->void:call_deferred("_run")
func _run()->void:
	var failures:Array[String]=[];var state:=RunState.new();state.set_class("warrior");state.start_new_run(null,"forest")
	for consumable in ["healing_potion","focus_tonic","smoke_vial","warding_draught"]:_expect(state.add_consumable(consumable),"Could not add %s"%consumable,failures)
	_expect(not state.add_consumable("fleet_draught"),"Consumable capacity allowed a fifth item",failures)
	for new_id in ["haste_potion","fury_potion","resource_elixir","true_strike_tonic"]:_expect(not GameBalance.get_consumable(new_id).is_empty(),"Missing consumable %s"%new_id,failures)
	var scene:=FOREST.instantiate();scene.setup(null,state);root.add_child(scene);await process_frame
	state.current_health=maxi(1,state.max_health-5);_expect(scene._use_potion(),"Healing potion could not be consumed",failures)
	state.class_resource=0;state.consumable_items=["resource_elixir"];_expect(scene._use_consumable_slot(0) and state.class_resource==state.get_class_resource_max(),"Resource Elixir did not fill the class meter",failures)
	state.consumable_items=["fury_potion"];_expect(scene._use_consumable_slot(0) and scene.player.next_attack_multiplier==2.0,"Potion of Fury did not arm double damage",failures)
	state.consumable_items=["haste_potion"];_expect(scene._use_consumable_slot(0) and scene.player.consumable_speed_multiplier>1.0,"Potion of Haste did not increase movement speed",failures)
	_expect(state.get_consumables().is_empty(),"Consumed items remained in the pouch",failures);scene.free()
	if failures.is_empty():print("SLASHER_CONSUMABLE_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)
func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
