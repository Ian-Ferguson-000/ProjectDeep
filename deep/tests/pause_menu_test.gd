extends SceneTree

## The Esc pause menu in the dungeon and at the tavern: it opens only when
## nothing else is up, pauses the game, has every option, steps back with Esc,
## and returns to the title screen (the tavern saves first).

func _init() -> void: GameBalance.set_actions_override(GameBalance.ALL_ACTIONS)

const FOREST := preload("res://scenes/slasher/SlasherForest.tscn")
const TAVERN := preload("res://scenes/tavern/Tavern.tscn")
var failures: Array[String] = []

class FakeController extends Node:
	var titles := 0
	func return_to_title() -> void: titles += 1

class MemoryState extends RunState:
	var saves := 0
	func autosave_on_floor_entry() -> bool:
		saves += 1
		return true

func _initialize() -> void: _run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _frames(count: int) -> void:
	for i in count: await process_frame

func _press_escape(menu: GamePauseMenu) -> void:
	var event := InputEventAction.new(); event.action = GamePauseMenu.ACTION; event.pressed = true
	menu._unhandled_input(event)
	await process_frame

func _buttons(menu: GamePauseMenu) -> Array:
	return menu.body.get_children().filter(func(n): return n is Button).map(func(n): return String(n.text))

func _run() -> void:
	root.size = Vector2i(1280,720)
	GamePauseMenu.ensure_action()
	_expect(InputMap.has_action(GamePauseMenu.ACTION),"No pause_menu action")

	# ---- dungeon
	var state := RunState.new()
	state.start_new_run(GearData.create("t","Tester",3,false,0,"","","warrior"),"forest")
	var forest = FOREST.instantiate(); forest._ensure_designer_controls(); forest.run_state = state; root.add_child(forest)
	await _frames(4)
	for node in root.find_children("*","",true,false):
		if node.get_script() and String(node.get_script().resource_path).contains("relic_choice_modal"): node.queue_free()
	paused = false
	await _frames(1)
	var menu: GamePauseMenu = forest.pause_menu
	_expect(menu != null and not menu.visible,"The dungeon has no pause menu")
	var fake := FakeController.new(); root.add_child(fake); menu.controller = fake
	# Not while the codex is open.
	forest.codex.open(state,forest.player)
	await _press_escape(menu)
	_expect(not menu.visible,"The pause menu opened over the codex")
	forest.codex.close(); paused = false
	await _press_escape(menu)
	_expect(menu.visible and paused,"Esc didn't open and pause the dungeon menu")
	var labels := _buttons(menu)
	for wanted in ["Resume","Codex","Options","Controls","Return to Title Screen"]:
		_expect(labels.has(wanted),"Dungeon menu is missing %s: %s" % [wanted,labels])
	menu.show_page("controls"); await process_frame
	_expect(menu.body.find_child("ControlsGrid",true,false) != null,"No controls list")
	await _press_escape(menu)
	_expect(menu.visible and menu.page == "main","Esc on a sub-page should step back to the menu")
	menu.show_page("options"); await process_frame
	_expect(menu.body.get_child(0) is GameOptionsPanel,"Options page has no options panel")
	menu.show_page("confirm_title"); await process_frame
	var note: String = menu._leave_note()
	_expect(note.contains("floor 1"),"The dungeon warning doesn't say where you'll resume: %s" % note)
	(menu.body.find_child("Confirm",true,false) as Button).pressed.emit()
	await process_frame
	_expect(fake.titles == 1 and not paused,"Return to Title didn't reach the game or left it paused")
	# Resume closes and unpauses.
	await _press_escape(menu); (menu.body.find_child("Resume",true,false) as Button).pressed.emit()
	_expect(not menu.visible and not paused,"Resume didn't close the menu")
	forest.queue_free(); await _frames(2)

	# ---- tavern
	var tavern_state := MemoryState.new()
	tavern_state.campaign.apply_post_tutorial_state("victory")
	for candidate in tavern_state.campaign.get_candidates(): tavern_state.campaign.recruit_candidate(candidate.id)
	tavern_state.campaign.last_presented_wave_id = tavern_state.campaign.candidate_wave_id
	var gear_list: Array[GearData] = [HearthCatalog.gear(tavern_state.campaign.living_roster()[0].gear_id)]
	var tavern = TAVERN.instantiate(); tavern.setup(null,tavern_state,gear_list,""); root.add_child(tavern)
	await _frames(3)
	var tavern_menu: GamePauseMenu = tavern.pause_menu
	_expect(tavern_menu != null,"The tavern has no pause menu")
	if tavern_menu != null:
		var tavern_fake := FakeController.new(); root.add_child(tavern_fake); tavern_menu.controller = tavern_fake
		tavern._open_hearth("Company"); await process_frame
		await _press_escape(tavern_menu)
		_expect(not tavern_menu.visible,"The pause menu opened over the Hearth window")
		tavern.management.hide(); await process_frame
		await _press_escape(tavern_menu)
		_expect(tavern_menu.visible,"Esc didn't open the tavern menu")
		_expect(not _buttons(tavern_menu).has("Codex"),"The tavern menu shouldn't offer the dungeon codex")
		var saves_before := tavern_state.saves
		tavern_menu.return_to_title()
		_expect(tavern_state.saves == saves_before + 1 and tavern_fake.titles == 1,"Leaving the tavern didn't save then return to the title")
	paused = false

	if failures.is_empty():
		print("PAUSE_MENU_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures: printerr("FAIL: " + failure)
		quit(1)
