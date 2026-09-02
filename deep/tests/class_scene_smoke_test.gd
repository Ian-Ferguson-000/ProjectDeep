extends SceneTree

const CLASS_IDS := ["warrior", "mage", "healer", "tank", "rogue", "summoner"]
const FOREST := preload("res://scenes/forest/Forest.tscn")
const CRYPT := preload("res://scenes/crypt/Crypt.tscn")
const CLASS_SELECTION := preload("res://scenes/class_selection/ClassSelection.tscn")

class SelectionController extends Node:
	var chosen_class := ""
	func choose_class(class_id: String) -> void: chosen_class = class_id

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var selection_controller := SelectionController.new()
	root.add_child(selection_controller)
	var selection := CLASS_SELECTION.instantiate()
	selection.setup(selection_controller)
	root.add_child(selection)
	await process_frame
	if selection.detail_text == null or not selection.detail_text.text.contains("Warrior"):
		push_error("Class selection did not default to Warrior details"); quit(1); return
	selection._show_details("mage")
	if not selection.detail_text.text.contains("+10 Accuracy"):
		push_error("Class details omit Arcane Missile signature rule"); quit(1); return
	for class_id in CLASS_IDS:
		var card: Button = selection.cards[CLASS_IDS.find(class_id)]
		if not (card is Button) or card.find_child("%sCardArt" % class_id.capitalize(), true, false) == null:
			push_error("Class card %s is not a complete clickable card" % class_id); quit(1); return
		if card.find_child("%sSelectButton" % class_id.capitalize(), true, false) != null:
			push_error("Class card %s still contains a redundant Choose button" % class_id); quit(1); return
	selection.cards[CLASS_IDS.find("rogue")].pressed.emit()
	if selection_controller.chosen_class != "rogue":
		push_error("Clicking a class card did not select it"); quit(1); return
	selection.size = Vector2(700, 800); selection._update_responsive_layout()
	if selection.class_grid.columns != 1:
		push_error("Class selection one-column breakpoint failed"); quit(1); return
	selection.free()
	selection_controller.free()
	var crypt_state := RunState.new(); crypt_state.set_class("warrior")
	crypt_state.start_new_run(GearData.create("test_crypt", "Test Gear", 2, true, 1, "", "", "warrior", "none"), "crypt")
	var crypt_scene := CRYPT.instantiate(); crypt_scene.setup(null, crypt_state); root.add_child(crypt_scene)
	await process_frame
	if crypt_scene.run_state.active_dungeon_id != "crypt": push_error("Crypt startup failed"); quit(1); return
	crypt_scene.free()
	for class_id in CLASS_IDS:
		var state := RunState.new()
		state.set_class(class_id)
		var gear := GearData.create("test_" + class_id, "Test Gear", 2, class_id == "tank", 1, "", "", class_id, "none")
		state.start_new_run(gear)
		var scene := FOREST.instantiate()
		scene.setup(null, state)
		root.add_child(scene)
		await process_frame
		if scene.run_state.selected_class_id != class_id:
			push_error("Forest failed to initialize %s" % class_id)
			quit(1)
			return
		if scene.combat_log_panel == null or scene.combat_log_text == null:
			push_error("Combat log modal failed to initialize for %s" % class_id)
			quit(1)
			return
		scene._record_combat_event("Test attack", "Roll: 10 + Accuracy 2 = 12")
		scene._show_combat_log()
		if not scene.combat_log_backdrop.visible or not scene.combat_log_text.text.contains("Test attack"):
			push_error("Detailed combat log failed to display for %s" % class_id)
			quit(1)
			return
		scene._spawn_damage_popup(scene.player_pos, 3, "physical")
		if scene._get_effects_root().get_child_count() == 0:
			push_error("Damage popup failed to spawn for %s" % class_id)
			quit(1)
			return
		scene.free()
	print("Six-class forest scene smoke test passed.")
	quit(0)
