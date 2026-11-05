extends SceneTree

## The Codex's Bestiary tab: every creature has an entry with a dungeon and
## tactics, unknown ones are silhouettes, defeating one fills in its page (rank,
## health seen, how it fights, how to beat it, drops), and the dungeon filters work.

const FOREST := preload("res://scenes/slasher/SlasherForest.tscn")
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _frames(count: int) -> void:
	for i in count: await process_frame

func _run() -> void:
	root.size = Vector2i(1280,720)
	var journal: Dictionary = GameBalance.get_slasher_journal()
	var order: Array = journal.get("order",[])
	for id in order:
		var entry: Dictionary = GameBalance.get_slasher_journal_entry(String(id))
		_expect(String(entry.get("dungeon","")) in SlasherCodexMenu.BESTIARY_FILTERS,"%s has no dungeon" % id)
		_expect(not String(entry.get("tactics","")).is_empty(),"%s has no tactics" % id)
	_expect(SlasherCodexMenu.enemy_rank(GameBalance.get_slasher_journal_entry("dark_druid")) == "boss","The druid should be a boss")
	_expect(SlasherCodexMenu.enemy_rank(GameBalance.get_slasher_journal_entry("briar_guardian")) == "mini_boss","The briar guardian should be a mini boss")
	_expect(SlasherCodexMenu.drops_text("sporeling",GameBalance.get_slasher_journal_entry("sporeling")).contains("Spore Sac"),"Sporeling drops should name spore sacs")
	_expect(SlasherCodexMenu.drops_text("briar_guardian",GameBalance.get_slasher_journal_entry("briar_guardian")).contains("relic"),"Mini boss drops should mention a relic chance")

	var state := RunState.new()
	state.start_new_run(GearData.create("t","Tester",3,false,0,"","","warrior"),"forest")
	state.record_enemy_defeat("wolf_charger",6); state.record_enemy_defeat("wolf_charger",4)
	_expect(state.get_enemy_health_seen("wolf_charger") == 6,"The bestiary should keep the most health seen")
	var forest = FOREST.instantiate(); forest._ensure_designer_controls(); forest.run_state = state; root.add_child(forest)
	await _frames(4)
	for node in root.find_children("*","",true,false):
		if node.get_script() and String(node.get_script().resource_path).contains("relic_choice_modal"): node.queue_free()
	paused = false
	var codex: SlasherCodexMenu = forest.codex
	codex.open(state,forest.player); codex._select_tab("journal"); await _frames(2)
	_expect((codex.tabs["journal"] as Button).text == "Bestiary","The tab should be called Bestiary")
	_expect(codex.bestiary_grid.get_child_count() == order.size(),"The grid should show every creature under All")
	var charger := codex.bestiary_grid.find_child("Beast_wolf_charger",false,false)
	var unknown := codex.bestiary_grid.find_child("Beast_balor",false,false)
	_expect(charger != null and unknown != null,"Tiles are missing")
	if unknown != null:
		_expect(unknown.find_children("*","Label",true,false).any(func(l): return l.text == "???"),"An undefeated creature should be ???")
	_expect(codex.bestiary_selected == "wolf_charger","The page should open on a discovered creature")
	var page_text := codex.journal_detail.text
	_expect(page_text.contains("Charger Wolf") and page_text.contains("6 health") and page_text.contains("Basic"),"The page is missing its name, health or rank: %s" % page_text)
	for section in ["Howitfights","Howtobeatit","Drops","Found"]:
		_expect(codex.bestiary_page.find_child(section,true,false) != null,"The page has no %s section" % section)
	_expect((codex.bestiary_page.find_child("Drops",true,false) as RichTextLabel).text.contains("Wolf Pelt"),"Wolves should drop pelts on the page")
	codex._show_journal_entry("balor"); await process_frame
	_expect(codex.journal_detail.text.contains("Unknown Creature") and codex.bestiary_page.find_child("Howtobeatit",true,false) == null,"An unknown creature's page gave its secrets away")
	# The portrait animates.
	codex._show_journal_entry("wolf_charger")
	var first := codex.journal_portrait.texture
	for i in 40: codex._process(0.1)
	_expect(codex.journal_portrait.texture != first,"The portrait doesn't animate")
	# Filters.
	(codex.content.find_child("Filter_StoneCrypt",true,false) as Button).pressed.emit(); await _frames(2)
	var crypt_count := order.filter(func(id): return String(GameBalance.get_slasher_journal_entry(String(id)).get("dungeon","")) == "Stone Crypt").size()
	_expect(codex.bestiary_filter == "Stone Crypt" and codex.bestiary_grid.get_child_count() == crypt_count,"The crypt filter showed %d, wanted %d" % [codex.bestiary_grid.get_child_count(),crypt_count])
	codex.bestiary_filter = "All"
	codex.close(); paused = false
	forest.queue_free(); await _frames(2)

	if failures.is_empty():
		print("BESTIARY_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures: printerr("FAIL: " + failure)
		quit(1)
