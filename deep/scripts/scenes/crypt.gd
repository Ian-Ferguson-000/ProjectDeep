extends "res://scripts/scenes/forest.gd"

# Dungeon handoff: the crypt inherits the tactical dungeon runtime from forest.gd
# and overrides only dungeon identity, generation tuning, spawn tables, and flavor.
# Future dungeon art/layout passes should prefer adding semantic overrides here
# instead of branching core combat or relic systems.

const CRYPT_BOSS_CHAMBERS := [
	{
		"id": "ossuary_gate",
		"name": "Ossuary Gate",
		"rows": [
			"########################",
			"#####......E......######",
			"###....R.....R......####",
			"##..Y....N.B....G....###",
			"##....RR.....RR......###",
			"###..T...A.A...T....####",
			"####......N......C..####",
			"###....R.....R......####",
			"##..G....Y.Y....N....###",
			"###.................####",
			"####..K....F....P..#####",
			"######.....S.....#######",
			"########.......#########",
			"##########...###########",
			"########################",
		],
	},
	{
		"id": "sunken_sarcophagi",
		"name": "Sunken Sarcophagi",
		"rows": [
			"########################",
			"#######....E....########",
			"#####..R.R...R.R..######",
			"###..Y....N.N....Y..####",
			"###....####B####....####",
			"##..G..#......#..G...###",
			"##.....#..A...#......###",
			"###..T....N....T....####",
			"####.....R.R.......#####",
			"#####..C.....K....######",
			"######....F.....########",
			"########..S...##########",
			"#########....###########",
			"##########..############",
			"########################",
		],
	},
	{
		"id": "ritual_well",
		"name": "Ritual Well",
		"rows": [
			"########################",
			"######.....E.....#######",
			"####....R.....R....#####",
			"###..N.....B.....N..####",
			"##......YYY.YYY......###",
			"##..R.....A.....R....###",
			"###....T.....T......####",
			"####..G...N...G....#####",
			"#####.....C.K.....######",
			"######...F.P.....#######",
			"#######...S.....########",
			"########.......#########",
			"##########...###########",
			"###########.############",
			"########################",
		],
	},
]

func _configure_dungeon_settings() -> void:
	dungeon_id = "crypt"
	dungeon_title = "Stone Crypt"
	dungeon_floor_label = "Depth"
	complete_floor_method = "complete_crypt_floor"
	victory_text_template = "You emerge from the Stone Crypt with %d gold. The tavern lanterns seem warmer now."
	grid_w = 24
	grid_h = 15
	tile_size = 40
	use_follow_camera = true
	camera_ui_right_margin = 360.0
	camera_ui_top_margin = 90.0
	message = "Cold stone stairs descend into a patient dark."

func _choose_layout_type() -> String:
	var floor_num := _current_floor()
	if floor_num <= 2:
		var early_layouts: Array[String] = ["catacomb", "burial_hall"]
		return early_layouts[rng.randi_range(0, early_layouts.size() - 1)]
	if floor_num <= 4:
		var mid_layouts: Array[String] = ["catacomb", "ossuary", "ritual"]
		return mid_layouts[rng.randi_range(0, mid_layouts.size() - 1)]
	if floor_num <= 6:
		var late_layouts: Array[String] = ["ossuary", "ritual", "treasure_crypt"]
		return late_layouts[rng.randi_range(0, late_layouts.size() - 1)]
	return "ritual"

func _build_room_graph(kind: String) -> void:
	match kind:
		"catacomb":
			_add_rooms([
				Vector2i(2, 12), Vector2i(5, 12), Vector2i(8, 10), Vector2i(12, 10), Vector2i(15, 7), Vector2i(18, 5), Vector2i(21, 3), Vector2i(10, 5), Vector2i(5, 5)
			])
			_connect_rooms([[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [3, 7], [7, 8]])
			critical_room_ids = [0, 1, 2, 3, 4, 5, 6]
		"burial_hall":
			_add_rooms([
				Vector2i(2, 12), Vector2i(6, 10), Vector2i(10, 10), Vector2i(14, 8), Vector2i(18, 6), Vector2i(21, 3), Vector2i(10, 4), Vector2i(4, 4), Vector2i(17, 12)
			])
			_connect_rooms([[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [2, 6], [6, 7], [3, 8]])
			critical_room_ids = [0, 1, 2, 3, 4, 5]
		"ossuary":
			_add_rooms([
				Vector2i(2, 12), Vector2i(5, 10), Vector2i(8, 7), Vector2i(12, 7), Vector2i(16, 7), Vector2i(20, 4), Vector2i(12, 3), Vector2i(6, 3), Vector2i(20, 11), Vector2i(15, 12)
			])
			_connect_rooms([[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [4, 8], [8, 9], [3, 6], [6, 7], [7, 2]])
			critical_room_ids = [0, 1, 2, 3, 4, 5]
		"ritual":
			_add_rooms([
				Vector2i(2, 12), Vector2i(6, 11), Vector2i(10, 9), Vector2i(12, 6), Vector2i(16, 6), Vector2i(21, 3), Vector2i(7, 5), Vector2i(14, 12), Vector2i(20, 11)
			])
			_connect_rooms([[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [3, 6], [2, 7], [7, 8], [8, 4]])
			critical_room_ids = [0, 1, 2, 3, 4, 5]
		"treasure_crypt":
			_add_rooms([
				Vector2i(2, 12), Vector2i(5, 10), Vector2i(9, 10), Vector2i(13, 8), Vector2i(17, 6), Vector2i(21, 3), Vector2i(13, 12), Vector2i(18, 12), Vector2i(8, 4), Vector2i(14, 3)
			])
			_connect_rooms([[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [2, 6], [6, 7], [3, 9], [9, 8]])
			critical_room_ids = [0, 1, 2, 3, 4, 5]
		_:
			super._build_room_graph(kind)

func _add_rooms(centers: Array) -> void:
	super._add_rooms(centers)
	for i in range(room_graph.size()):
		var room_value: Variant = room_graph[i]
		var room: Dictionary = room_value if room_value is Dictionary else {}
		if i == 3 or i == 4:
			room["radius"] = Vector2i(2, 2)
		room_graph[i] = room

func _build_boss_chamber() -> void:
	var chamber_value: Variant = CRYPT_BOSS_CHAMBERS[rng.randi_range(0, CRYPT_BOSS_CHAMBERS.size() - 1)]
	var chamber: Dictionary = chamber_value if chamber_value is Dictionary else {}
	layout_type = "boss_%s" % String(chamber["id"])
	boss_chamber_name = String(chamber["name"])
	message = _floor_intro_message()
	secret = {"pos": Vector2i(-1, -1), "found": true}
	_carve_boss_chamber(chamber)
	_mark_boss_critical_path()
	_build_boss_room_graph()

func _apply_boss_chamber_symbol(symbol: String, tile: Vector2i) -> void:
	match symbol:
		"S":
			player_pos = tile
		"E":
			exit_pos = tile
		"B":
			_add_boss_enemy(tile)
		"Y":
			_add_floor_enemy(tile, "skeleton")
		"A":
			_add_floor_enemy(tile, "armored_skeleton")
		"G":
			_add_floor_enemy(tile, "ghoul")
		"N":
			_add_floor_enemy(tile, "necromancer")
		"C":
			chest = {"pos": tile, "opened": false}
		"R":
			props.append({"kind": "rock", "pos": tile, "hp": GameBalance.get_prop_hp("rock", 1)})
		"F":
			props.append({"kind": "campfire", "pos": tile, "hp": GameBalance.get_prop_hp("campfire", 99)})
		"T":
			traps.append({"pos": tile, "sprung": false})
		"K":
			loot.append({"kind": "key", "pos": tile, "amount": 1})
		"P":
			loot.append({"kind": "potion", "pos": tile, "amount": 1})

func _build_boss_room_graph() -> void:
	room_graph = [
		{"id": 0, "center": player_pos, "radius": Vector2i(1, 1), "neighbors": [1], "role": "start"},
		{"id": 1, "center": Vector2i(12, 7), "radius": Vector2i(6, 4), "neighbors": [0, 2], "role": "elite"},
		{"id": 2, "center": exit_pos, "radius": Vector2i(1, 1), "neighbors": [1], "role": "exit"},
	]
	critical_room_ids = [0, 1, 2]

func _place_props() -> void:
	var kinds: Array[String] = ["rock", "rock", "barrel", "campfire", "barrel", "rock"]
	if _current_floor() >= 4:
		kinds.append_array(["rock", "barrel"])
	for kind in kinds:
		props.append({"kind": kind, "pos": _pick_floor_cell(true), "hp": GameBalance.get_prop_hp(kind, 2 if kind != "campfire" else 99)})

func _place_enemies() -> void:
	var count := mini(5 + _current_floor() * 2, 14)
	for i in range(count):
		var spawn_pos: Vector2i = _pick_role_cell("elite", false) if i == 0 and _current_floor() >= 4 else _pick_floor_cell(true)
		_add_floor_enemy(spawn_pos, _enemy_type_for_spawn(i))

func _enemy_type_for_spawn(spawn_index: int) -> String:
	var floor_num: int = _current_floor()
	if floor_num <= 1:
		return "ghoul" if spawn_index % 4 == 1 else "skeleton"
	if floor_num <= 2:
		return "ghoul" if spawn_index % 3 == 1 else "skeleton"
	if floor_num <= 4:
		if spawn_index % 5 == 0:
			return "necromancer"
		return "ghoul" if spawn_index % 3 == 1 else "skeleton"
	if spawn_index % 5 == 0:
		return "necromancer"
	if spawn_index % 4 == 0:
		return "armored_skeleton"
	return "ghoul" if spawn_index % 3 == 1 else "skeleton"

func _place_decorations() -> void:
	var floor_kinds: Array[String] = ["bone_pile", "crypt_pillar", "mossy_rock"]
	for i in range(24):
		for attempt in range(80):
			var tile := _pick_floor_cell(true)
			if _decoration_at(tile) or _distance(tile, player_pos) <= 1 or _distance(tile, exit_pos) <= 1:
				continue
			_add_decoration(floor_kinds[rng.randi_range(0, floor_kinds.size() - 1)], tile, Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-4.0, 5.0)))
			break
	var edge_kinds: Array[String] = ["crypt_pillar", "mossy_rock", "bone_pile"]
	_seed_edge_decorations_near(player_pos, edge_kinds, 6)
	_seed_edge_decorations_near(exit_pos, edge_kinds, 6)
	_place_border_decorations(edge_kinds)

func _floor_intro_message() -> String:
	if layout_type.begins_with("boss_"):
		return "Depth %d/%d: %s waits behind a sealed bone gate." % [_current_floor(), _max_floors(), boss_chamber_name]
	var room_note := "Narrow catacombs bend through cold stone."
	match layout_type:
		"burial_hall":
			room_note = "Burial halls open into long chambers lined with sarcophagi."
		"ossuary":
			room_note = "Ossuary chambers stack bones where shadows should be."
		"ritual":
			room_note = "Ritual rooms pulse with old grave-light."
		"treasure_crypt":
			room_note = "A treasure crypt branches around guarded vaults."
	return "Depth %d/%d: %s" % [_current_floor(), _max_floors(), room_note]

func _layout_display_name() -> String:
	if layout_type.begins_with("boss_"):
		return "%s boss chamber" % boss_chamber_name
	return "%s layout" % layout_type.replace("_", " ").capitalize()
