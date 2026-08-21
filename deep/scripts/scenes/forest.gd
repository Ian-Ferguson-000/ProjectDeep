extends Node2D

const TILE_SIZE := 48
const GRID_W := 16
const GRID_H := 11
const ORIGIN := Vector2(40, 150)
const BoardPieceScene := preload("res://scenes/components/BoardPiece.tscn")
const PLAYER_IDLE_DOWN := preload("res://assets/sprite_packs/Player/IDLE/idle_down.png")
const FIRE_MAGE_SHEET := preload("res://assets/enemies/fire_mage/normalized_sheet.png")
const WOLF_SHEET := preload("res://assets/enemies/feral_wolf/normalized_sheet.png")
const GRASS_TILE_A := preload("res://assets/pixel_art/forest_art/grass1.jpeg")
const GRASS_TILE_B := preload("res://assets/pixel_art/forest_art/grass2.jpg")
const GRASS_TILE_C := preload("res://assets/pixel_art/forest_art/grass3.jpg")
const FREEPACK_ATLAS := preload("res://assets/pixel_art/FreePack.png")
const WOODEN_EXIT_DOOR := preload("res://assets/generated_ui/wooden_exit_door.png")
const PROPS_ATLAS := preload("res://assets/pixel_art/TX Props.png")
const STRUCT_ATLAS := preload("res://assets/pixel_art/TX Struct.png")
const PLANT_ATLAS := preload("res://assets/pixel_art/TX Plant.png")
const UI_BUTTON_NORMAL := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/4 Buttons/1.png")
const UI_BUTTON_HOVER := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/4 Buttons/2.png")
const UI_BUTTON_PRESSED := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/4 Buttons/3.png")
const ATLAS_TILE_SIZE := 32
const GRASS_TILE_DRAW_SIZE := 48.0
const PLAYER_MOVE_ALLOWANCE := 3
const FREE_ROAM_MOVE_ALLOWANCE := 99
const ENEMY_MOVE_ALLOWANCE := 2
const ENEMY_TURN_DELAY := 1.0
const PLAYER_ACTOR_ID := -1
const FIREBALL_FLIGHT := preload("res://assets/effect_packs/fireball/fireball_flight.png")
const FIREBALL_IMPACT := preload("res://assets/effect_packs/fireball/fireball_impact.png")
const AETHER_HIT := preload("res://assets/effect_packs/Aether Effect 01/Aether VFX 1/Ice VFX 1 Hit.png")
# Art handoff: standalone board-object art is fitted in _apply_sprite_to_piece().
# Swap these constants when final transparent props replace prototype images.
const CAMPFIRE_SPRITE := preload("res://assets/pixel_art/Campfire.png")
const ROCK_SPRITE := preload("res://assets/pixel_art/rocks/rock2.png")
const BARREL_SPRITE := preload("res://assets/pixel_art/forest_art/interactables/barrel_generated.png")
const CHEST_SPRITE := preload("res://assets/pixel_art/chests/chest2.png")
const LOOT_SPRITE := preload("res://assets/pixel_art/Gold.png")
const POTION_SPRITE := preload("res://assets/pixel_art/potion.png")
const KEY_SPRITE := preload("res://assets/pixel_art/key.png")
const TRAP_SPRITE := preload("res://assets/pixel_art/trap.png")
const ICON_MOVE := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/2 Icons/1.png")
const ICON_ATTACK := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/2 Icons/2.png")
const ICON_SPECIAL := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/2 Icons/10.png")
const ICON_POTION := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/1 Items/15.png")
const ICON_DEFEND := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/2 Icons/12.png")
const ICON_END_TURN := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/2 Icons/20.png")
const ICON_GOLD := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/1 Items/1.png")
const ICON_KEY := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/1 Items/10.png")
const ICON_BLOCK := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/2 Icons/15.png")
const ICON_FLOOR := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/2 Icons/22.png")
const ICON_MODE := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/2 Icons/7.png")
const ICON_ROUND := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/2 Icons/26.png")
const ICON_SPELL := preload("res://assets/pixel_art/spellnode.png")

var controller: Node
var run_state: RunState
var rng := RandomNumberGenerator.new()
var fog_tile_textures: Array[Texture2D] = []

var floor_cells := {}
var critical_path := {}
var room_graph: Array[Dictionary] = []
var critical_room_ids: Array[int] = []
var layout_type := "linear"
var player_pos := Vector2i(2, 8)
var exit_pos := Vector2i(14, 2)
var facing := Vector2i.RIGHT
var block_stacks := 0
var braced := false
var is_defending := false
var selected_action := "move"
var movement_remaining := PLAYER_MOVE_ALLOWANCE
var has_used_action := false
var is_player_turn := false
var is_resolving_enemy_turn := false
var combat_started := false
var free_roam_started := false
var round_number := 1
var current_actor_index := 0
var initiative_order: Array[Dictionary] = []
var enemy_id_counter := 1
var effects_root: Node2D

var enemies: Array[Dictionary] = []
var props: Array[Dictionary] = []
var loot: Array[Dictionary] = []
var traps: Array[Dictionary] = []
var decorations: Array[Dictionary] = []
var chest := {"pos": Vector2i(10, 4), "opened": false}
var secret := {"pos": Vector2i(6, 7), "found": false}

var message := "The forest arranges itself into a dangerous little board."

@onready var markers_root: Node2D = $Board/Markers
@onready var ground_layer: TileMapLayer = $Board/Tiles
@onready var decorations_root: Node2D = $Board/Decorations
@onready var enemies_root: Node2D = $Board/Enemies
@onready var player_token: BoardPiece = $Board/Tokens/PlayerToken
@onready var exit_door: ExitDoor = $Board/Markers/ExitDoor
@onready var title_label: Label = $UI/Root/Columns/LeftPanel/TitleLabel
@onready var action_label: Label = $UI/Root/Columns/LeftPanel/ActionLabel
@onready var health_bar: ProgressBar = $UI/Root/Columns/RightPanel/HealthPanel/HealthBarRow/HealthBar
@onready var health_value_label: Label = $UI/Root/Columns/RightPanel/HealthPanel/HealthBarRow/HealthValueLabel
@onready var hud_label: Label = $UI/Root/Columns/RightPanel/HudLabel
@onready var minimap_panel: MinimapPanel = $UI/Root/Columns/RightPanel/MinimapPanel
@onready var special_button: Button = $UI/Root/Columns/RightPanel/SpecialButton
@onready var interact_button: Button = $UI/Root/Columns/RightPanel/InteractButton
@onready var potion_button: Button = $UI/Root/Columns/RightPanel/PotionButton
@onready var log_label: Label = $UI/Root/Columns/RightPanel/LogLabel
var move_button: Button
var defend_button: Button
var end_turn_button: Button
var initiative_panel: PanelContainer
var initiative_tracker: HBoxContainer
var compact_status_panel: PanelContainer
var compact_status_body: VBoxContainer
var actions_panel: PanelContainer
var actions_grid: GridContainer
var hover_panel: PanelContainer
var hover_title_label: Label
var hover_detail_label: Label
var hover_actions_box: HBoxContainer
var hovered_tile := Vector2i(-999, -999)
var hovered_object: Dictionary = {}

func setup(game_controller: Node, state: RunState) -> void:
	controller = game_controller
	run_state = state
	if run_state != null and run_state.selected_gear != null:
		block_stacks = run_state.selected_gear.block_limit
	if is_inside_tree():
		_generate()
		_build_board_tiles()
		_build_decorations()
		_refresh_ui()

func _ready() -> void:
	title_label.add_theme_font_size_override("font_size", 24)
	_style_health_bar()
	_setup_combat_layout_ui()
	_setup_action_buttons()
	potion_button.pressed.connect(_drink_potion)
	exit_door.door_entered.connect(_on_exit_door_entered)
	_generate()
	_build_board_tiles()
	_build_decorations()
	_configure_player_sprite()
	_refresh_ui()

func _setup_combat_layout_ui() -> void:
	var ui_layer: CanvasLayer = $UI
	var root: MarginContainer = $UI/Root
	root.add_theme_constant_override("margin_top", 86)

	var right_panel: VBoxContainer = $UI/Root/Columns/RightPanel
	right_panel.add_theme_constant_override("separation", 8)

	initiative_panel = PanelContainer.new()
	initiative_panel.name = "InitiativePanel"
	initiative_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	initiative_panel.offset_left = 24
	initiative_panel.offset_top = 10
	initiative_panel.offset_right = -24
	initiative_panel.offset_bottom = 76
	initiative_panel.add_theme_stylebox_override("panel", _flat_style(Color(0.11, 0.08, 0.05, 0.92), 5, Color(0.71, 0.52, 0.25)))
	ui_layer.add_child(initiative_panel)

	var initiative_margin := MarginContainer.new()
	initiative_margin.add_theme_constant_override("margin_left", 10)
	initiative_margin.add_theme_constant_override("margin_right", 10)
	initiative_margin.add_theme_constant_override("margin_top", 6)
	initiative_margin.add_theme_constant_override("margin_bottom", 6)
	initiative_panel.add_child(initiative_margin)

	initiative_tracker = HBoxContainer.new()
	initiative_tracker.name = "InitiativeTracker"
	initiative_tracker.alignment = BoxContainer.ALIGNMENT_CENTER
	initiative_tracker.add_theme_constant_override("separation", 8)
	initiative_margin.add_child(initiative_tracker)

	hud_label.visible = false
	hud_label.custom_minimum_size = Vector2.ZERO
	compact_status_panel = PanelContainer.new()
	compact_status_panel.name = "CompactStatusPanel"
	compact_status_panel.add_theme_stylebox_override("panel", _flat_style(Color(0.13, 0.09, 0.06, 0.90), 5, Color(0.55, 0.39, 0.20)))
	var hud_index: int = hud_label.get_index()
	right_panel.add_child(compact_status_panel)
	right_panel.move_child(compact_status_panel, hud_index)

	var status_margin := MarginContainer.new()
	status_margin.add_theme_constant_override("margin_left", 8)
	status_margin.add_theme_constant_override("margin_right", 8)
	status_margin.add_theme_constant_override("margin_top", 8)
	status_margin.add_theme_constant_override("margin_bottom", 8)
	compact_status_panel.add_child(status_margin)

	compact_status_body = VBoxContainer.new()
	compact_status_body.name = "CompactStatusBody"
	compact_status_body.add_theme_constant_override("separation", 6)
	status_margin.add_child(compact_status_body)

	var spacer := Control.new()
	spacer.name = "RightPanelFlexSpacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var log_index: int = log_label.get_index()
	right_panel.add_child(spacer)
	right_panel.move_child(spacer, log_index)

	actions_panel = PanelContainer.new()
	actions_panel.name = "ActionsPanel"
	actions_panel.add_theme_stylebox_override("panel", _flat_style(Color(0.14, 0.10, 0.06, 0.96), 5, Color(0.76, 0.55, 0.26)))
	right_panel.add_child(actions_panel)
	right_panel.move_child(actions_panel, log_index + 1)

	var actions_margin := MarginContainer.new()
	actions_margin.add_theme_constant_override("margin_left", 8)
	actions_margin.add_theme_constant_override("margin_right", 8)
	actions_margin.add_theme_constant_override("margin_top", 8)
	actions_margin.add_theme_constant_override("margin_bottom", 8)
	actions_panel.add_child(actions_margin)

	var actions_body := VBoxContainer.new()
	actions_body.add_theme_constant_override("separation", 6)
	actions_margin.add_child(actions_body)

	var actions_title := Label.new()
	actions_title.text = "Actions"
	actions_title.add_theme_font_size_override("font_size", 13)
	actions_title.add_theme_color_override("font_color", Color(0.94, 0.82, 0.58))
	actions_body.add_child(actions_title)

	actions_grid = GridContainer.new()
	actions_grid.name = "ActionsGrid"
	actions_grid.columns = 2
	actions_grid.add_theme_constant_override("h_separation", 6)
	actions_grid.add_theme_constant_override("v_separation", 6)
	actions_body.add_child(actions_grid)

	hover_panel = PanelContainer.new()
	hover_panel.name = "HoverContextPanel"
	hover_panel.visible = false
	hover_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	hover_panel.custom_minimum_size = Vector2(190, 0)
	hover_panel.add_theme_stylebox_override("panel", _flat_style(Color(0.10, 0.07, 0.04, 0.96), 5, Color(0.83, 0.62, 0.31)))
	ui_layer.add_child(hover_panel)

	var hover_margin := MarginContainer.new()
	hover_margin.add_theme_constant_override("margin_left", 8)
	hover_margin.add_theme_constant_override("margin_right", 8)
	hover_margin.add_theme_constant_override("margin_top", 7)
	hover_margin.add_theme_constant_override("margin_bottom", 7)
	hover_panel.add_child(hover_margin)

	var hover_body := VBoxContainer.new()
	hover_body.add_theme_constant_override("separation", 5)
	hover_margin.add_child(hover_body)

	hover_title_label = Label.new()
	hover_title_label.add_theme_font_size_override("font_size", 13)
	hover_title_label.add_theme_color_override("font_color", Color(0.98, 0.87, 0.58))
	hover_body.add_child(hover_title_label)

	hover_detail_label = Label.new()
	hover_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hover_detail_label.add_theme_font_size_override("font_size", 10)
	hover_detail_label.add_theme_color_override("font_color", Color(0.84, 0.77, 0.64))
	hover_body.add_child(hover_detail_label)

	hover_actions_box = HBoxContainer.new()
	hover_actions_box.add_theme_constant_override("separation", 5)
	hover_body.add_child(hover_actions_box)

func _setup_action_buttons() -> void:
	move_button = Button.new()
	move_button.name = "MoveButton"
	move_button.pressed.connect(_select_action.bind("move"))
	interact_button.pressed.connect(_select_action.bind("attack"))
	special_button.pressed.connect(_select_action.bind("special"))
	defend_button = Button.new()
	defend_button.name = "DefendButton"
	defend_button.pressed.connect(_defend)
	end_turn_button = Button.new()
	end_turn_button.name = "EndTurnButton"
	end_turn_button.pressed.connect(_end_player_turn)
	_configure_action_button(move_button, "Move", ICON_MOVE, "Move up to three grid spaces.")
	_configure_action_button(interact_button, "Attack", ICON_ATTACK, "Target an enemy with your basic attack.")
	_configure_action_button(special_button, "Special", ICON_SPECIAL, "Use your equipped special ability.")
	_configure_action_button(potion_button, "Potion", ICON_POTION, "Drink a potion as your action.")
	_configure_action_button(defend_button, "Defend", ICON_DEFEND, "Hold position and reduce incoming damage.")
	_configure_action_button(end_turn_button, "End", ICON_END_TURN, "Pass to the next actor.")
	for button: Button in _action_buttons():
		_reparent_to_actions_grid(button)
	_style_action_buttons()

func _configure_action_button(button: Button, label: String, icon: Texture2D, tooltip: String) -> void:
	button.text = label
	button.icon = icon
	button.tooltip_text = tooltip
	button.expand_icon = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _reparent_to_actions_grid(button: Button) -> void:
	if actions_grid == null or button == null:
		return
	var old_parent: Node = button.get_parent()
	if old_parent != null:
		old_parent.remove_child(button)
	actions_grid.add_child(button)

func _generate() -> void:
	if floor_cells.size() > 0:
		return
	var seed_value := 1001
	if run_state != null:
		seed_value = run_state.get_current_floor_seed()
	rng.seed = seed_value

	_reset_generated_state()
	layout_type = _choose_layout_type()
	_build_room_graph(layout_type)
	_assign_room_roles()
	_carve_room_graph()
	_assign_start_and_exit()
	message = _floor_intro_message()
	chest = {"pos": _pick_role_cell("treasure", true), "opened": false}
	secret = {"pos": _pick_floor_cell(true), "found": false}

	_place_props()
	_place_loot()
	_place_traps()
	_place_enemies()
	_place_decorations()
	_start_combat()

func _reset_generated_state() -> void:
	floor_cells.clear()
	critical_path.clear()
	room_graph.clear()
	critical_room_ids.clear()
	enemies.clear()
	props.clear()
	loot.clear()
	traps.clear()
	decorations.clear()
	initiative_order.clear()
	enemy_id_counter = 1
	combat_started = false
	free_roam_started = false
	is_player_turn = false
	is_resolving_enemy_turn = false
	selected_action = "move"
	has_used_action = false
	is_defending = false
	movement_remaining = PLAYER_MOVE_ALLOWANCE
	round_number = 1
	current_actor_index = 0
	chest = {"pos": Vector2i(-1, -1), "opened": false}
	secret = {"pos": Vector2i(-1, -1), "found": false}

func _choose_layout_type() -> String:
	var floor_num := _current_floor()
	if floor_num <= 1:
		return "linear"
	if floor_num == 2:
		return ["linear", "branching"][rng.randi_range(0, 1)]
	if floor_num == 3:
		return ["branching", "hub"][rng.randi_range(0, 1)]
	if floor_num == 4:
		return ["hub", "loop"][rng.randi_range(0, 1)]
	return "arena"

func _build_room_graph(kind: String) -> void:
	match kind:
		"branching":
			_add_rooms([
				Vector2i(2, 8), Vector2i(5, 8), Vector2i(8, 6), Vector2i(11, 5), Vector2i(14, 2), Vector2i(8, 2), Vector2i(12, 8)
			])
			_connect_rooms([[0, 1], [1, 2], [2, 3], [3, 4], [2, 5], [3, 6]])
			critical_room_ids = [0, 1, 2, 3, 4]
		"hub":
			_add_rooms([
				Vector2i(2, 8), Vector2i(7, 6), Vector2i(7, 2), Vector2i(3, 4), Vector2i(11, 4), Vector2i(13, 8), Vector2i(14, 2)
			])
			_connect_rooms([[0, 1], [1, 2], [1, 3], [1, 4], [1, 5], [4, 6]])
			critical_room_ids = [0, 1, 4, 6]
		"loop":
			_add_rooms([
				Vector2i(2, 8), Vector2i(5, 8), Vector2i(9, 8), Vector2i(13, 7), Vector2i(13, 3), Vector2i(9, 2), Vector2i(5, 3), Vector2i(14, 2)
			])
			_connect_rooms([[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 1], [4, 7]])
			critical_room_ids = [0, 1, 2, 3, 4, 7]
		"arena":
			_add_rooms([
				Vector2i(2, 8), Vector2i(5, 8), Vector2i(8, 6), Vector2i(8, 3), Vector2i(12, 6), Vector2i(14, 3), Vector2i(5, 3), Vector2i(12, 9)
			])
			_connect_rooms([[0, 1], [1, 2], [2, 3], [2, 4], [3, 5], [4, 5], [2, 6], [4, 7]])
			critical_room_ids = [0, 1, 2, 3, 5]
		_:
			_add_rooms([Vector2i(2, 8), Vector2i(5, 8), Vector2i(8, 6), Vector2i(11, 4), Vector2i(14, 2)])
			_connect_rooms([[0, 1], [1, 2], [2, 3], [3, 4]])
			critical_room_ids = [0, 1, 2, 3, 4]

func _add_rooms(centers: Array) -> void:
	for i in range(centers.size()):
		var radius := Vector2i(rng.randi_range(1, 2), rng.randi_range(1, 2))
		if layout_type == "arena" and i == 2:
			radius = Vector2i(3, 2)
		room_graph.append({
			"id": i,
			"center": Vector2i(centers[i]),
			"radius": radius,
			"neighbors": [],
			"role": "normal",
		})

func _connect_rooms(edges: Array) -> void:
	for edge in edges:
		var a: int = int(edge[0])
		var b: int = int(edge[1])
		room_graph[a]["neighbors"].append(b)
		room_graph[b]["neighbors"].append(a)

func _assign_room_roles() -> void:
	if room_graph.is_empty():
		return
	room_graph[critical_room_ids[0]]["role"] = "start"
	room_graph[critical_room_ids[critical_room_ids.size() - 1]]["role"] = "exit"
	var dead_ends := _dead_end_room_ids()
	var treasure_id := _first_noncritical_room(dead_ends)
	if treasure_id == -1:
		treasure_id = _last_non_endpoint_room()
	if treasure_id != -1:
		room_graph[treasure_id]["role"] = "treasure"
	var trap_id: int = _first_noncritical_room(_room_ids_except([treasure_id]))
	if trap_id != -1:
		room_graph[trap_id]["role"] = "trap"
	var elite_id: int = critical_room_ids[maxi(1, critical_room_ids.size() - 2)]
	if _current_floor() >= 4 or layout_type == "arena":
		room_graph[elite_id]["role"] = "elite"

func _carve_room_graph() -> void:
	for room in room_graph:
		var center: Vector2i = room["center"]
		var radius: Vector2i = room["radius"]
		_carve_room(center, radius.x, radius.y)
		if critical_room_ids.has(int(room["id"])):
			_mark_room_path(center, radius.x, radius.y)
	for room in room_graph:
		var a: int = room["id"]
		var from_center: Vector2i = room["center"]
		for b in room["neighbors"]:
			if int(b) < a:
				continue
			var to_center: Vector2i = room_graph[int(b)]["center"]
			_carve_corridor(from_center, to_center, critical_room_ids.has(a) and critical_room_ids.has(int(b)))

func _assign_start_and_exit() -> void:
	player_pos = room_graph[critical_room_ids[0]]["center"]
	exit_pos = room_graph[critical_room_ids[critical_room_ids.size() - 1]]["center"]

func _carve_room(center: Vector2i, radius_x: int, radius_y: int) -> void:
	for y in range(center.y - radius_y, center.y + radius_y + 1):
		for x in range(center.x - radius_x, center.x + radius_x + 1):
			var tile := Vector2i(x, y)
			if _is_inside_grid(tile):
				floor_cells[tile] = true

func _mark_room_path(center: Vector2i, radius_x: int, radius_y: int) -> void:
	for y in range(center.y - radius_y, center.y + radius_y + 1):
		for x in range(center.x - radius_x, center.x + radius_x + 1):
			var tile := Vector2i(x, y)
			if _is_inside_grid(tile):
				critical_path[tile] = true

func _carve_corridor(a: Vector2i, b: Vector2i, is_critical: bool = true) -> void:
	var x_step := 1 if b.x >= a.x else -1
	for x in range(a.x, b.x + x_step, x_step):
		var tile := Vector2i(x, a.y)
		floor_cells[tile] = true
		if is_critical:
			critical_path[tile] = true
	var y_step := 1 if b.y >= a.y else -1
	for y in range(a.y, b.y + y_step, y_step):
		var tile := Vector2i(b.x, y)
		floor_cells[tile] = true
		if is_critical:
			critical_path[tile] = true

func _place_props() -> void:
	var kinds: Array[String] = ["rock", "barrel", "rock", "barrel", "campfire"]
	if _current_floor() >= 3:
		kinds.append_array(["rock", "barrel"])
	for kind in kinds:
		props.append({"kind": kind, "pos": _pick_floor_cell(false), "hp": 2 if kind != "campfire" else 99})

func _place_loot() -> void:
	loot.append({"kind": "gold", "pos": _pick_floor_cell(true), "amount": 6 + _current_floor() * 2})
	loot.append({"kind": "potion", "pos": _pick_floor_cell(true), "amount": 1})
	loot.append({"kind": "key", "pos": _pick_floor_cell(true), "amount": 1})
	if _current_floor() >= 4:
		loot.append({"kind": "gold", "pos": _pick_floor_cell(true), "amount": 10})

func _place_traps() -> void:
	var count := 1
	if _current_floor() >= 3:
		count += 1
	if _current_floor() >= 5:
		count += 1
	for i in range(count):
		var trap_pos := _pick_role_cell("trap", true) if i == 0 else _pick_floor_cell(true)
		traps.append({"pos": trap_pos, "sprung": false})

func _place_enemies() -> void:
	var count := mini(3 + _current_floor(), 7)
	for i in range(count):
		var elite := i == 0 and (_current_floor() >= 4 or layout_type == "arena")
		var spawn_pos := _pick_role_cell("elite", false) if elite else _pick_floor_cell(true)
		var max_health := 4 + int(floori(float(_current_floor() - 1) * 0.75))
		var damage := 3 if _current_floor() >= 4 else 2
		if elite:
			max_health += 3
			damage += 1
		enemies.append({
			"id": enemy_id_counter,
			"kind": "wolf",
			"pos": spawn_pos,
			"hp": max_health,
			"max_health": max_health,
			"damage": damage,
			"elite": elite,
		})
		enemy_id_counter += 1

func _place_decorations() -> void:
	var floor_kinds: Array[String] = ["grass_tuft_a", "grass_tuft_b", "grass_tuft_c", "low_bush_a", "low_bush_b", "sapling"]
	for i in range(16):
		for attempt in range(80):
			var tile := _pick_floor_cell(true)
			if _decoration_at(tile) or _distance(tile, player_pos) <= 1 or _distance(tile, exit_pos) <= 1:
				continue
			_add_decoration(floor_kinds[rng.randi_range(0, floor_kinds.size() - 1)], tile, Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-4.0, 5.0)))
			break

	var edge_kinds: Array[String] = ["tree_large", "tree_wide", "tree_small", "low_bush_a", "low_bush_b", "rounded_bush", "mossy_rock"]
	_seed_edge_decorations_near(player_pos, edge_kinds, 5)
	_seed_edge_decorations_near(exit_pos, edge_kinds, 5)
	_place_border_decorations(edge_kinds)
	for i in range(10):
		for attempt in range(160):
			var tile := Vector2i(rng.randi_range(0, GRID_W - 1), rng.randi_range(0, GRID_H - 1))
			if floor_cells.has(tile) or _decoration_at(tile) or not _has_floor_neighbor(tile):
				continue
			_add_decoration(edge_kinds[rng.randi_range(0, edge_kinds.size() - 1)], tile, Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-6.0, 8.0)))
			break

func _add_decoration(kind: String, tile: Vector2i, offset: Vector2) -> void:
	decorations.append({"kind": kind, "pos": tile, "offset": offset})

func _place_border_decorations(edge_kinds: Array[String]) -> void:
	for y in range(GRID_H):
		for x in range(GRID_W):
			var tile := Vector2i(x, y)
			if floor_cells.has(tile) or _decoration_at(tile) or not _has_floor_neighbor(tile):
				continue
			var kind: String = edge_kinds[abs(x * 5 + y * 9) % edge_kinds.size()]
			var offset: Vector2 = Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-5.0, 7.0))
			_add_decoration(kind, tile, offset)

func _seed_edge_decorations_near(center: Vector2i, edge_kinds: Array[String], target_count: int) -> void:
	var placed := 0
	for radius in range(1, 4):
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				if placed >= target_count:
					return
				var tile := Vector2i(x, y)
				if not _is_inside_grid(tile) or floor_cells.has(tile) or _decoration_at(tile) or not _has_floor_neighbor(tile):
					continue
				_add_decoration(edge_kinds[rng.randi_range(0, edge_kinds.size() - 1)], tile, Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-5.0, 7.0)))
				placed += 1

func _start_combat() -> void:
	initiative_order.clear()
	round_number = 1
	current_actor_index = 0
	var player_modifier := 2 if run_state != null and run_state.selected_class_id == "mage" else 1
	var player_roll := rng.randi_range(1, 20)
	initiative_order.append({
		"kind": "player",
		"id": PLAYER_ACTOR_ID,
		"name": "You",
		"roll": player_roll,
		"modifier": player_modifier,
		"initiative": player_roll + player_modifier,
		"tie": 1,
	})
	for i in range(enemies.size()):
		var enemy: Dictionary = enemies[i]
		var modifier: int = 1 if bool(enemy.get("elite", false)) else 0
		var roll := rng.randi_range(1, 20)
		initiative_order.append({
			"kind": "enemy",
			"id": int(enemy["id"]),
			"name": "Elite Wolf" if bool(enemy.get("elite", false)) else "Wolf",
			"roll": roll,
			"modifier": modifier,
			"initiative": roll + modifier,
			"tie": 0,
			"spawn": i,
		})
	initiative_order.sort_custom(_sort_initiative)
	combat_started = true
	message = "%s\nInitiative: %s" % [_floor_intro_message(), _initiative_roll_summary()]
	_begin_current_actor_turn()

func _sort_initiative(a: Dictionary, b: Dictionary) -> bool:
	if int(a["initiative"]) == int(b["initiative"]):
		if int(a["tie"]) == int(b["tie"]):
			return int(a.get("spawn", -1)) < int(b.get("spawn", -1))
		return int(a["tie"]) > int(b["tie"])
	return int(a["initiative"]) > int(b["initiative"])

func _initiative_roll_summary() -> String:
	var parts: Array[String] = []
	for actor in initiative_order:
		parts.append("%s %d+%d=%d" % [actor["name"], int(actor["roll"]), int(actor["modifier"]), int(actor["initiative"])])
	return ", ".join(parts)

func _begin_current_actor_turn() -> void:
	_prune_initiative_order()
	if _enter_free_roam_if_clear():
		return
	if initiative_order.is_empty():
		return
	if current_actor_index >= initiative_order.size():
		current_actor_index = 0
		round_number += 1
	var actor: Dictionary = initiative_order[current_actor_index]
	if actor["kind"] == "player":
		_begin_player_turn()
	else:
		_begin_enemy_turn(actor)

func _begin_player_turn() -> void:
	is_player_turn = true
	is_resolving_enemy_turn = false
	is_defending = false
	selected_action = "move"
	has_used_action = false
	movement_remaining = PLAYER_MOVE_ALLOWANCE
	if round_number == 1:
		message = "Initiative: %s\nRound %d: Your turn. Move up to %d tiles, then choose an action." % [_initiative_roll_summary(), round_number, movement_remaining]
	else:
		message = "Round %d: Your turn. Move up to %d tiles, then choose an action." % [round_number, movement_remaining]
	_refresh_ui()

func _begin_enemy_turn(actor: Dictionary) -> void:
	is_player_turn = false
	selected_action = "wait"
	is_resolving_enemy_turn = true
	if round_number == 1:
		message = "Initiative: %s\nRound %d: %s acts next." % [_initiative_roll_summary(), round_number, actor["name"]]
	else:
		message = "Round %d: %s acts next." % [round_number, actor["name"]]
	_refresh_ui()
	call_deferred("_resolve_enemy_actor_turn", int(actor["id"]))

func _advance_to_next_actor() -> void:
	if run_state != null and run_state.current_health <= 0:
		_die()
		return
	var current_actor := {}
	if current_actor_index >= 0 and current_actor_index < initiative_order.size():
		current_actor = initiative_order[current_actor_index]
	_prune_initiative_order()
	if not current_actor.is_empty():
		var index_after_prune := _initiative_index_for(current_actor)
		if index_after_prune != -1:
			current_actor_index = index_after_prune + 1
	else:
		current_actor_index += 1
	if _enter_free_roam_if_clear():
		return
	_begin_current_actor_turn()

func _enter_free_roam_if_clear() -> bool:
	if free_roam_started or not combat_started or not enemies.is_empty():
		return false
	free_roam_started = true
	_prune_initiative_order()
	is_player_turn = true
	is_resolving_enemy_turn = false
	is_defending = false
	has_used_action = false
	selected_action = "move"
	movement_remaining = FREE_ROAM_MOVE_ALLOWANCE
	current_actor_index = _player_initiative_index()
	message = "The last enemy falls. The path is clear, and you can explore freely."
	_refresh_ui()
	return true

func _player_initiative_index() -> int:
	for i in range(initiative_order.size()):
		var actor: Dictionary = initiative_order[i]
		if String(actor["kind"]) == "player":
			return i
	return 0

func _prune_initiative_order() -> void:
	var active_enemy_ids := {}
	for enemy in enemies:
		active_enemy_ids[int(enemy["id"])] = true
	for i in range(initiative_order.size() - 1, -1, -1):
		var actor: Dictionary = initiative_order[i]
		if actor["kind"] == "enemy" and not active_enemy_ids.has(int(actor["id"])):
			initiative_order.remove_at(i)

func _initiative_index_for(actor: Dictionary) -> int:
	for i in range(initiative_order.size()):
		if initiative_order[i]["kind"] == actor["kind"] and int(initiative_order[i]["id"]) == int(actor["id"]):
			return i
	return -1

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover_context(event.position)

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_turn or is_resolving_enemy_turn:
		return
	if event.is_action_pressed("special"):
		_select_action("special")
	elif event.is_action_pressed("interact"):
		_select_action("attack")
	elif event.is_action_pressed("drink_potion"):
		_drink_potion()
	elif event.is_action_pressed("move_up"):
		_take_directional_action(Vector2i.UP)
	elif event.is_action_pressed("move_down"):
		_take_directional_action(Vector2i.DOWN)
	elif event.is_action_pressed("move_left"):
		_take_directional_action(Vector2i.LEFT)
	elif event.is_action_pressed("move_right"):
		_take_directional_action(Vector2i.RIGHT)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if hover_panel != null and hover_panel.visible and hover_panel.get_global_rect().has_point(event.position):
			return
		var tile: Vector2i = _screen_to_grid(event.position)
		if _is_inside_grid(tile):
			_hide_hover_context()
			_handle_tile_click(tile)

func _take_directional_action(delta: Vector2i) -> void:
	facing = delta
	_handle_tile_click(player_pos + delta)

func _handle_tile_click(tile: Vector2i) -> void:
	if not is_player_turn:
		message = "Wait for your place in the round."
		_refresh_ui()
		return
	match selected_action:
		"attack":
			_try_player_attack(tile)
		"special":
			_try_player_special(tile)
		_:
			_try_player_move_or_interact(tile)

func _try_player_move_or_interact(tile: Vector2i) -> void:
	if _enemy_at(tile) != -1:
		message = "Choose Attack, then target that enemy."
		_refresh_ui()
		return
	if _prop_at(tile) != -1:
		message = "That object blocks the way. Use its menu, or choose Attack and target it."
		_refresh_ui()
		return
	if tile == chest["pos"]:
		message = "The chest blocks the way. Use Interact from its menu while adjacent."
		_refresh_ui()
		return
	if tile == exit_pos:
		message = "Use Interact from the gate menu to leave this floor."
		_refresh_ui()
		return
	if not _is_walkable(tile):
		message = "Dense trees block the way."
		_refresh_ui()
		return
	var max_steps := FREE_ROAM_MOVE_ALLOWANCE if _is_free_roam() else movement_remaining
	var path := _find_path(player_pos, tile, max_steps)
	if path.is_empty():
		message = "That is beyond your remaining movement."
		_refresh_ui()
		return
	if path.size() > 1:
		facing = path[1] - player_pos
	player_pos = tile
	if _is_free_roam():
		movement_remaining = FREE_ROAM_MOVE_ALLOWANCE
		message = "You move through the cleared forest."
	else:
		movement_remaining -= maxi(0, path.size() - 1)
		message = "You move. %d movement remaining." % movement_remaining
	_resolve_tile()
	if run_state.current_health <= 0:
		_die()
		return
	_refresh_ui()

func _try_context_interaction(tile: Vector2i) -> bool:
	if has_used_action and not _is_free_roam():
		return false
	if _prop_at(tile) != -1:
		var prop_index: int = _prop_at(tile)
		var prop_kind: String = String(props[prop_index]["kind"])
		match prop_kind:
			"campfire":
				run_state.heal(2)
				message = "The campfire steadies you. Restored 2 health."
			"npc":
				message = "They nod, but have nothing more to say yet."
			_:
				message = "You inspect the %s. It blocks the path; attack it to clear the way." % prop_kind
		_finish_player_action()
		return true
	if tile == chest["pos"]:
		_open_chest()
		_finish_player_action()
		return true
	if tile == exit_pos:
		_complete_floor()
		return true
	if _distance(player_pos, secret["pos"]) <= 1 and not secret["found"]:
		secret["found"] = true
		run_state.gold += 9
		run_state.potions += 1
		message = "You brush aside leaves and find a hidden cache: 9 gold and a potion."
		_finish_player_action()
		return true
	return false

func _update_hover_context(screen_pos: Vector2) -> void:
	if hover_panel == null:
		return
	if hover_panel.visible and hover_panel.get_global_rect().has_point(screen_pos):
		return
	var tile: Vector2i = _screen_to_grid(screen_pos)
	if not _is_inside_grid(tile):
		_hide_hover_context()
		return
	var object: Dictionary = _object_at_tile(tile)
	if object.is_empty():
		_hide_hover_context()
		return
	hovered_tile = tile
	hovered_object = object
	_sync_hover_context(screen_pos, object)

func _hide_hover_context() -> void:
	if hover_panel != null:
		hover_panel.visible = false
	hovered_tile = Vector2i(-999, -999)
	hovered_object = {}

func _sync_hover_context(screen_pos: Vector2, object: Dictionary) -> void:
	hover_title_label.text = String(object["title"])
	hover_detail_label.text = String(object["detail"])
	_clear_children_now(hover_actions_box)
	for action: Dictionary in _context_actions_for(object):
		var action_id: String = action["id"]
		var button: Button = Button.new()
		button.text = String(action["label"])
		button.icon = _context_action_icon(action_id)
		button.expand_icon = true
		button.disabled = not bool(action["enabled"])
		button.tooltip_text = String(action["tooltip"])
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.custom_minimum_size = Vector2(84, 34)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_context_button(button)
		button.pressed.connect(_choose_context_action.bind(action_id))
		hover_actions_box.add_child(button)
	hover_panel.position = _hover_panel_position(screen_pos)
	hover_panel.visible = true

func _hover_panel_position(screen_pos: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_size: Vector2 = Vector2(320, 150)
	var position: Vector2 = screen_pos + Vector2(18, 18)
	position.x = minf(position.x, viewport_size.x - panel_size.x - 12.0)
	position.y = minf(position.y, viewport_size.y - panel_size.y - 12.0)
	position.x = maxf(12.0, position.x)
	position.y = maxf(12.0, position.y)
	return position

func _style_context_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color(0.98, 0.90, 0.68))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.78))
	button.add_theme_color_override("font_pressed_color", Color(0.12, 0.08, 0.04))
	button.add_theme_color_override("font_disabled_color", Color(0.50, 0.46, 0.38))
	button.add_theme_stylebox_override("normal", _flat_style(Color(0.18, 0.13, 0.08, 0.96), 4, Color(0.78, 0.58, 0.29)))
	button.add_theme_stylebox_override("hover", _flat_style(Color(0.28, 0.20, 0.11, 0.98), 4, Color(0.98, 0.78, 0.36)))
	button.add_theme_stylebox_override("pressed", _flat_style(Color(0.82, 0.60, 0.28, 1.0), 4, Color(1.0, 0.86, 0.50)))
	button.add_theme_stylebox_override("disabled", _flat_style(Color(0.10, 0.08, 0.06, 0.78), 4, Color(0.26, 0.22, 0.17)))

func _context_action_icon(action_id: String) -> Texture2D:
	match action_id:
		"inspect":
			return ICON_MODE
		"pickup":
			return ICON_GOLD
		"interact":
			return ICON_SPECIAL
		"attack", "attack_object":
			return ICON_ATTACK
	return ICON_MODE

func _context_actions_for(object: Dictionary) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	actions.append({"id": "inspect", "label": "Inspect", "enabled": true, "tooltip": "Look closer."})
	var kind: String = String(object["kind"])
	var tile: Vector2i = object["pos"]
	var adjacent: bool = _distance(player_pos, tile) <= 1
	match kind:
		"loot":
			actions.append({"id": "pickup", "label": "Pick Up", "enabled": adjacent, "tooltip": "Move next to it first." if not adjacent else "Collect this item."})
		"chest", "exit", "secret":
			actions.append({"id": "interact", "label": "Interact", "enabled": adjacent and _can_use_player_controls(), "tooltip": "Move next to it first." if not adjacent else "Use this object."})
		"prop":
			actions.append({"id": "interact", "label": "Interact", "enabled": adjacent and _can_use_player_controls(), "tooltip": "Move next to it first." if not adjacent else "Inspect or use this object."})
			actions.append({"id": "attack_object", "label": "Attack", "enabled": adjacent and _can_use_player_controls() and not has_used_action, "tooltip": "Move next to it first." if not adjacent else "Strike this obstacle."})
		"npc":
			actions.append({"id": "interact", "label": "Talk", "enabled": adjacent and _can_use_player_controls(), "tooltip": "Move next to them first." if not adjacent else "Start a conversation."})
		"enemy":
			var enemy_index: int = _enemy_at(tile)
			actions.append({"id": "attack", "label": "Attack", "enabled": _can_use_player_controls() and _is_valid_basic_attack_target(tile, enemy_index), "tooltip": "Select a valid target."})
		"trap":
			actions.append({"id": "interact", "label": "Interact", "enabled": false, "tooltip": "No disarm action is available yet."})
	return actions

func _choose_context_action(action_id: String) -> void:
	if hovered_object.is_empty():
		return
	var tile: Vector2i = hovered_object["pos"]
	match action_id:
		"inspect":
			message = String(hovered_object["inspect"])
			_refresh_ui()
		"pickup":
			_pickup_loot_at(tile)
		"interact":
			_try_context_interaction(tile)
			_refresh_ui()
		"attack":
			selected_action = "attack"
			_try_player_attack(tile)
		"attack_object":
			selected_action = "attack"
			_try_player_attack(tile)
	_hide_hover_context()

func _pickup_loot_at(tile: Vector2i) -> void:
	if _distance(player_pos, tile) > 1:
		message = "Move next to it first."
		_refresh_ui()
		return
	for item in loot.duplicate():
		var item_pos: Vector2i = item["pos"]
		if item_pos != tile:
			continue
		_apply_loot_item(item)
		loot.erase(item)
		_refresh_ui()
		return
	message = "There is nothing to pick up there."
	_refresh_ui()

func _apply_loot_item(item: Dictionary) -> void:
	match String(item["kind"]):
		"gold":
			run_state.gold += int(item["amount"])
			message = "Picked up %d gold." % int(item["amount"])
		"potion":
			run_state.potions += 1
			message = "Picked up a potion."
		"key":
			run_state.keys += 1
			message = "Picked up a key."

func _object_at_tile(tile: Vector2i) -> Dictionary:
	var enemy_index: int = _enemy_at(tile)
	if enemy_index != -1:
		var enemy: Dictionary = enemies[enemy_index]
		var enemy_name: String = "Elite Wolf" if bool(enemy.get("elite", false)) else "Wolf"
		return {
			"kind": "enemy",
			"pos": tile,
			"title": enemy_name,
			"detail": "HP %d/%d. Blocks movement and acts in initiative." % [int(enemy["hp"]), int(enemy.get("max_health", enemy["hp"]))],
			"inspect": "%s watches your footing. HP %d/%d." % [enemy_name, int(enemy["hp"]), int(enemy.get("max_health", enemy["hp"]))],
		}
	if not bool(chest["opened"]) and tile == Vector2i(chest["pos"]):
		return {
			"kind": "chest",
			"pos": tile,
			"title": "Locked Chest",
			"detail": "Requires a key. Stand next to it to open.",
			"inspect": "A travel-worn chest sits tucked between the roots.",
		}
	if tile == exit_pos:
		return {
			"kind": "exit",
			"pos": tile,
			"title": "Forest Gate",
			"detail": "Leave this floor from an adjacent tile.",
			"inspect": "The door hums with a path to the next floor.",
		}
	for item in loot:
		var item_pos: Vector2i = item["pos"]
		if item_pos == tile:
			return _loot_object(item)
	for trap in traps:
		var trap_pos: Vector2i = trap["pos"]
		if trap_pos == tile:
			var sprung: bool = bool(trap["sprung"])
			return {
				"kind": "trap",
				"pos": tile,
				"title": "Sprung Trap" if sprung else "Root-Snare Trap",
				"detail": "Already triggered." if sprung else "Dangerous terrain. Step carefully.",
				"inspect": "The roots are twisted into a cruel little mechanism.",
			}
	for i in range(props.size()):
		var prop: Dictionary = props[i]
		var prop_pos: Vector2i = prop["pos"]
		if prop_pos == tile:
			var prop_name: String = String(prop["kind"]).capitalize()
			if String(prop["kind"]) == "npc":
				return {
					"kind": "npc",
					"pos": tile,
					"title": "Forest Stranger",
					"detail": "Stand next to them to talk.",
					"inspect": "Someone waits here with something to say.",
				}
			return {
				"kind": "prop",
				"pos": tile,
				"title": prop_name,
				"detail": "Can be interacted with from an adjacent tile.",
				"inspect": "The %s may hide supplies or block a path." % String(prop["kind"]),
			}
	if bool(secret["found"]) and tile == Vector2i(secret["pos"]):
		return {
			"kind": "secret",
			"pos": tile,
			"title": "Hidden Cache",
			"detail": "A discovered stash among the leaves.",
			"inspect": "The cache has already yielded its best secrets.",
		}
	return {}

func _loot_object(item: Dictionary) -> Dictionary:
	var kind: String = String(item["kind"])
	var title: String = "Gold"
	var detail: String = "Pick up from this tile or an adjacent tile."
	var inspect: String = "A small glint of coin catches the light."
	match kind:
		"gold":
			title = "%d Gold" % int(item["amount"])
		"potion":
			title = "Potion"
			inspect = "A corked potion waits in the grass."
		"key":
			title = "Key"
			inspect = "A small key lies half-hidden under leaves."
	return {"kind": "loot", "pos": item["pos"], "title": title, "detail": detail, "inspect": inspect}

func _try_player_attack(tile: Vector2i) -> void:
	if has_used_action:
		message = "Your action is already spent."
		_refresh_ui()
		return
	var enemy_index: int = _enemy_at(tile)
	var prop_index: int = _prop_at(tile)
	if prop_index != -1:
		if _distance(player_pos, tile) != 1:
			message = "Move next to that object before attacking it."
			_refresh_ui()
			return
		facing = _direction_to(tile)
		_hit_prop(prop_index)
		_finish_player_action()
		return
	if not _is_valid_basic_attack_target(tile, enemy_index):
		message = "Choose a valid attack target."
		_refresh_ui()
		return
	facing = _direction_to(tile)
	_play_attack_effect(player_pos, tile)
	_attack_enemy(enemy_index, run_state.selected_gear.damage)
	if run_state.selected_class_id == "mage":
		message = "Your spell strikes from across the clearing."
	_finish_player_action()

func _try_player_special(tile: Vector2i) -> void:
	if has_used_action:
		message = "Your action is already spent."
		_refresh_ui()
		return
	match run_state.selected_gear.special_id:
		"charge":
			_special_charge_at(tile)
		"sweep":
			_special_sweep()
		"brace":
			braced = true
			message = "You brace. The next enemy that closes in gets punished first."
			_finish_player_action()
		"force_blast":
			_special_force_blast_at(tile)
		"flamethrower":
			_special_flamethrower_at(tile)
		"shockwave":
			_special_shockwave()
		_:
			message = "This gear has no special yet."
			_refresh_ui()

func _select_action(action: String) -> void:
	if not is_player_turn:
		return
	if has_used_action and action != "move":
		message = "Your action is already spent."
	else:
		selected_action = action
		message = "Choose a %s target." % action
	_refresh_ui()

func _defend() -> void:
	if not is_player_turn:
		return
	if has_used_action:
		message = "Your action is already spent."
		_refresh_ui()
		return
	is_defending = true
	if run_state.selected_gear != null and run_state.selected_gear.defense_id == "block":
		block_stacks = maxi(block_stacks, run_state.selected_gear.block_limit)
	if run_state.selected_gear != null and run_state.selected_gear.special_id == "brace":
		braced = true
	message = "You defend and hold your ground."
	_finish_player_action()

func _finish_player_action() -> void:
	has_used_action = true
	if _enter_free_roam_if_clear():
		return
	if _is_free_roam():
		has_used_action = false
		selected_action = "move"
		_refresh_ui()
		return
	_end_player_turn()

func _end_player_turn() -> void:
	if not is_player_turn:
		return
	is_player_turn = false
	selected_action = "wait"
	message = "You end your turn."
	_refresh_ui()
	_advance_to_next_actor()

func _interact() -> void:
	if not is_player_turn:
		return
	if has_used_action:
		message = "Your action is already spent."
		_refresh_ui()
		return
	if _distance(player_pos, exit_pos) == 1:
		_complete_floor()
		return
	if _distance(player_pos, chest["pos"]) == 1:
		_open_chest()
		_finish_player_action()
		return
	if _distance(player_pos, secret["pos"]) <= 1 and not secret["found"]:
		secret["found"] = true
		run_state.gold += 9
		run_state.potions += 1
		message = "You brush aside leaves and find a hidden cache: 9 gold and a potion."
		_finish_player_action()
		return
	for i in range(props.size()):
		if _distance(player_pos, props[i]["pos"]) == 1:
			if props[i]["kind"] == "campfire":
				run_state.heal(2)
				message = "The campfire steadies you. Restored 2 health."
			else:
				_hit_prop(i)
			_finish_player_action()
			return
	message = "You find bark, moss, and nothing willing to confess."
	_refresh_ui()

func _use_special() -> void:
	_select_action("special")

func _special_charge_at(tile: Vector2i) -> void:
	if not _is_straight_line_target(tile, 3):
		message = "Charge needs a straight path up to 3 tiles."
		_refresh_ui()
		return
	var direction := _direction_to(tile)
	facing = direction
	var cursor := player_pos
	for step in range(3):
		cursor += direction
		if not floor_cells.has(cursor):
			break
		var enemy_index: int = _enemy_at(cursor)
		if enemy_index != -1:
			_play_attack_effect(player_pos, cursor)
			_attack_enemy(enemy_index, run_state.selected_gear.damage + 1)
			message = "You charge through the brush and crash into an enemy."
			_finish_player_action()
			return
		if not _is_walkable(cursor):
			break
		player_pos = cursor
		_resolve_tile()
	message = "You charge forward, finding only leaves and momentum."
	_finish_player_action()

func _special_force_blast_at(tile: Vector2i) -> void:
	var enemy_index: int = _enemy_at(tile)
	if not _is_straight_line_target(tile, 4, true) or enemy_index == -1 or not _has_clear_line(player_pos, tile, true):
		message = "Force Blast needs a visible enemy in a straight line."
		_refresh_ui()
		return
	facing = _direction_to(tile)
	var blast_origin: Vector2i = enemies[enemy_index]["pos"]
	_play_projectile_effect(AETHER_HIT, player_pos, blast_origin)
	_attack_enemy(enemy_index, run_state.selected_gear.damage + 2)
	var pushed := _push_enemy_from(blast_origin, facing, 2)
	var splash_hits := 0
	for i in range(enemies.size() - 1, -1, -1):
		if _distance(enemies[i]["pos"], blast_origin) == 1:
			_attack_enemy(i, 1)
			splash_hits += 1
	var push_note := ", pushing a foe back" if pushed else ""
	var splash_note := ""
	if splash_hits > 0:
		splash_note = " and splashing %d nearby foe%s" % [splash_hits, "" if splash_hits == 1 else "s"]
	message = "Force Blast slams forward%s%s." % [push_note, splash_note]
	_finish_player_action()

func _special_flamethrower_at(tile: Vector2i) -> void:
	if not _is_straight_line_target(tile, 3, true):
		message = "Flamethrower needs a direction up to 3 tiles."
		_refresh_ui()
		return
	facing = _direction_to(tile)
	var hit_count := 0
	for step in range(1, 4):
		var target := player_pos + facing * step
		if not floor_cells.has(target):
			break
		_spawn_tile_effect(FIREBALL_IMPACT, target)
		var enemy_index: int = _enemy_at(target)
		if enemy_index != -1:
			_attack_enemy(enemy_index, run_state.selected_gear.damage)
			hit_count += 1
	if hit_count == 0:
		message = "Flamethrower scorches a bright line through empty brush."
	else:
		message = "Flamethrower burns %d foe%s in a line." % [hit_count, "" if hit_count == 1 else "s"]
	_finish_player_action()

func _is_valid_basic_attack_target(tile: Vector2i, enemy_index: int) -> bool:
	if enemy_index == -1:
		return false
	if run_state != null and run_state.selected_class_id == "mage":
		return _can_ranged_attack(tile, enemy_index)
	return _distance(player_pos, tile) == 1

func _is_straight_line_target(tile: Vector2i, max_range: int, allow_diagonal: bool = false) -> bool:
	var distance := _line_distance(player_pos, tile)
	if distance < 1 or distance > max_range:
		return false
	if tile.x == player_pos.x or tile.y == player_pos.y:
		return true
	return allow_diagonal and abs(tile.x - player_pos.x) == abs(tile.y - player_pos.y)

func _has_clear_line(from_tile: Vector2i, to_tile: Vector2i, allow_target_enemy: bool) -> bool:
	var direction := Vector2i(_sign_int(to_tile.x - from_tile.x), _sign_int(to_tile.y - from_tile.y))
	var cursor := from_tile + direction
	while cursor != to_tile:
		if not floor_cells.has(cursor) or _prop_at(cursor) != -1 or _enemy_at(cursor) != -1:
			return false
		cursor += direction
	if allow_target_enemy:
		return floor_cells.has(to_tile)
	return _is_walkable(to_tile)

func _find_path(start: Vector2i, goal: Vector2i, max_steps: int) -> Array[Vector2i]:
	if start == goal:
		var same_tile_path: Array[Vector2i] = []
		same_tile_path.append(start)
		return same_tile_path
	var frontier: Array[Vector2i] = [start]
	var came_from := {start: start}
	var distance_by_tile := {start: 0}
	var deltas: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for delta in deltas:
			var next: Vector2i = current + delta
			if came_from.has(next):
				continue
			if not _is_walkable(next):
				continue
			var next_distance: int = int(distance_by_tile[current]) + 1
			if next_distance > max_steps:
				continue
			came_from[next] = current
			distance_by_tile[next] = next_distance
			if next == goal:
				var path: Array[Vector2i] = [goal]
				var cursor := goal
				while cursor != start:
					cursor = came_from[cursor]
					path.push_front(cursor)
				return path
			frontier.append(next)
	return []

func _valid_move_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var max_steps := FREE_ROAM_MOVE_ALLOWANCE if _is_free_roam() else movement_remaining
	for tile in floor_cells.keys():
		var cell := Vector2i(tile)
		if cell != player_pos and _find_path(player_pos, cell, max_steps).size() > 0:
			tiles.append(cell)
	return tiles

func _valid_attack_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for enemy in enemies:
		var tile: Vector2i = enemy["pos"]
		if _is_valid_basic_attack_target(tile, _enemy_at(tile)):
			tiles.append(tile)
	return tiles

func _valid_special_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if run_state == null or run_state.selected_gear == null:
		return tiles
	match run_state.selected_gear.special_id:
		"sweep", "brace", "shockwave":
			tiles.append(player_pos)
		"charge", "flamethrower":
			var directions: Array[Vector2i] = _cardinal_directions()
			if run_state.selected_gear.special_id == "flamethrower":
				directions = _eight_directions()
			for direction in directions:
				for step in range(1, 4):
					var tile: Vector2i = player_pos + direction * step
					if floor_cells.has(tile):
						tiles.append(tile)
		"force_blast":
			for enemy in enemies:
				var tile: Vector2i = enemy["pos"]
				if _is_straight_line_target(tile, 4, true) and _has_clear_line(player_pos, tile, true):
					tiles.append(tile)
	return tiles

func _add_highlight_markers() -> void:
	if not is_player_turn:
		return
	var tiles: Array[Vector2i] = []
	var color := Color(0.24, 0.52, 0.95, 0.42)
	match selected_action:
		"attack":
			tiles = _valid_attack_tiles()
			color = Color(0.95, 0.23, 0.18, 0.48)
		"special":
			tiles = _valid_special_tiles()
			color = Color(0.48, 0.28, 0.95, 0.46)
		_:
			if _is_free_roam():
				return
			tiles = _valid_move_tiles()
	for tile in tiles:
		_add_highlight_marker(tile, color)

func _add_highlight_marker(tile: Vector2i, color: Color) -> void:
	var highlight: BoardPiece = _make_piece("Highlight_%d_%d" % [tile.x, tile.y], tile, "", color, BoardPiece.PieceShape.SQUARE)
	highlight.size = Vector2(42, 42)
	highlight.show_label = false
	highlight.show_panel = true
	markers_root.add_child(highlight)

func _play_attack_effect(from_tile: Vector2i, to_tile: Vector2i) -> void:
	if run_state != null and run_state.selected_class_id == "mage":
		_play_projectile_effect(FIREBALL_FLIGHT, from_tile, to_tile)
	else:
		_spawn_tile_effect(AETHER_HIT, to_tile)

func _play_projectile_effect(texture: Texture2D, from_tile: Vector2i, to_tile: Vector2i) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.position = _grid_center(from_tile)
	sprite.scale = Vector2(0.22, 0.22)
	_get_effects_root().add_child(sprite)
	var tween := create_tween()
	tween.tween_property(sprite, "position", _grid_center(to_tile), 0.22)
	tween.tween_callback(sprite.queue_free)
	_spawn_tile_effect(AETHER_HIT, to_tile)

func _spawn_tile_effect(texture: Texture2D, tile: Vector2i) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.position = _grid_center(tile)
	sprite.scale = Vector2(0.28, 0.28)
	_get_effects_root().add_child(sprite)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.tween_callback(sprite.queue_free)

func _get_effects_root() -> Node2D:
	if effects_root == null or not is_instance_valid(effects_root):
		effects_root = Node2D.new()
		effects_root.name = "RuntimeEffects"
		$Board.add_child(effects_root)
	return effects_root

func _action_name() -> String:
	return selected_action.capitalize()

func _active_actor_name() -> String:
	if initiative_order.is_empty() or current_actor_index >= initiative_order.size():
		return "None"
	return initiative_order[current_actor_index]["name"]

func _initiative_summary() -> String:
	var parts: Array[String] = []
	for i in range(initiative_order.size()):
		var actor: Dictionary = initiative_order[i]
		var prefix := ">" if i == current_actor_index else ""
		parts.append("%s%s:%d" % [prefix, actor["name"], int(actor["initiative"])])
	return " ".join(parts)

func _turn_status() -> String:
	if _is_free_roam():
		return "Exploration | Area Clear"
	if is_player_turn:
		return "Round %d | Active: You | Mode: %s | Move: %d" % [round_number, _action_name(), movement_remaining]
	return "Round %d | Active: %s" % [round_number, _active_actor_name()]

func _can_use_player_controls() -> bool:
	return is_player_turn and not is_resolving_enemy_turn

func _set_combat_buttons_enabled() -> void:
	var enabled := _can_use_player_controls()
	for button: Button in _action_buttons():
		if button != null:
			button.disabled = not enabled
	if not enabled:
		return
	if _is_free_roam():
		move_button.disabled = false
		interact_button.disabled = false
		special_button.disabled = true
		potion_button.disabled = run_state == null or run_state.potions <= 0
		defend_button.disabled = true
		end_turn_button.disabled = true
		return
	move_button.disabled = movement_remaining <= 0
	interact_button.disabled = has_used_action
	special_button.disabled = has_used_action
	potion_button.disabled = has_used_action or run_state == null or run_state.potions <= 0
	defend_button.disabled = has_used_action
	end_turn_button.disabled = false

func _special_sweep() -> void:
	var hit_count := 0
	for i in range(enemies.size() - 1, -1, -1):
		if _distance(player_pos, enemies[i]["pos"]) == 1:
			_spawn_tile_effect(AETHER_HIT, enemies[i]["pos"])
			_attack_enemy(i, run_state.selected_gear.damage)
			hit_count += 1
	if hit_count == 0:
		message = "You sweep the greatsword through empty air."
	else:
		message = "Your greatsword sweep catches %d foe%s." % [hit_count, "" if hit_count == 1 else "s"]
	_finish_player_action()

func _special_shockwave() -> void:
	var hit_count := 0
	_spawn_tile_effect(AETHER_HIT, player_pos)
	for i in range(enemies.size() - 1, -1, -1):
		if _distance(player_pos, enemies[i]["pos"]) == 1:
			enemies[i]["stunned"] = 1
			_spawn_tile_effect(AETHER_HIT, enemies[i]["pos"])
			_attack_enemy(i, 1)
			hit_count += 1
	if hit_count == 0:
		message = "Shockwave cracks around you, but catches no one."
	else:
		message = "Shockwave stuns %d adjacent foe%s." % [hit_count, "" if hit_count == 1 else "s"]
	_finish_player_action()

func _drink_potion() -> void:
	if not is_player_turn:
		return
	if has_used_action:
		message = "Your action is already spent."
		_refresh_ui()
		return
	if run_state.potions <= 0:
		message = "No potion waits at your belt."
	else:
		run_state.potions -= 1
		run_state.heal(5)
		message = "You drink a potion and recover 5 health."
		_finish_player_action()
	_refresh_ui()

func _attack_enemy(index: int, damage: int) -> void:
	var enemy: Dictionary = enemies[index]
	enemy["hp"] -= damage
	if enemy["hp"] <= 0:
		message = "The forest token falls. You gain 3 gold."
		run_state.gold += 3
		enemies.remove_at(index)
	else:
		enemies[index] = enemy
		message = "Hit for %d. The enemy has %d health left." % [damage, enemy["hp"]]

func _hit_prop(index: int) -> void:
	var prop: Dictionary = props[index]
	if prop["kind"] == "campfire":
		run_state.heal(2)
		message = "The campfire steadies you. Restored 2 health."
		return
	prop["hp"] -= 1
	if prop["hp"] <= 0:
		message = "The %s breaks. Something clinks in the grass." % prop["kind"]
		run_state.gold += 1
		props.remove_at(index)
	else:
		props[index] = prop
		message = "The %s cracks." % prop["kind"]

func _open_chest() -> void:
	if chest["opened"]:
		message = "The chest is already open."
	elif run_state.keys > 0:
		run_state.keys -= 1
		chest["opened"] = true
		run_state.gold += 15
		run_state.potions += 1
		message = "The key turns. Inside: 15 gold and a potion."
	else:
		message = "The chest is locked. Find a key."

func _resolve_tile() -> void:
	for item in loot.duplicate():
		if item["pos"] == player_pos:
			_apply_loot_item(item)
			loot.erase(item)
	for trap in traps:
		if trap["pos"] == player_pos and not trap["sprung"]:
			trap["sprung"] = true
			_apply_damage(3)
			message = "A root-snare trap snaps shut for 3 damage."

func _resolve_enemy_actor_turn(enemy_id: int) -> void:
	await get_tree().create_timer(ENEMY_TURN_DELAY).timeout
	var index := _enemy_index_by_id(enemy_id)
	if index == -1:
		is_resolving_enemy_turn = false
		_advance_to_next_actor()
		return
	var enemy: Dictionary = enemies[index]
	if int(enemy.get("stunned", 0)) > 0:
		enemy["stunned"] = int(enemy["stunned"]) - 1
		enemies[index] = enemy
		message = "%s is stunned and loses its turn." % ("Elite Wolf" if bool(enemy.get("elite", false)) else "Wolf")
		_refresh_ui()
		is_resolving_enemy_turn = false
		_advance_to_next_actor()
		return
	_enemy_move_toward_player(index)
	index = _enemy_index_by_id(enemy_id)
	if index != -1 and _distance(enemies[index]["pos"], player_pos) == 1:
		if not _brace_hits_enemy(index):
			_enemy_attack(index)
	elif index != -1:
		message = "%s prowls closer." % ("Elite Wolf" if bool(enemies[index].get("elite", false)) else "Wolf")
	_refresh_ui()
	is_resolving_enemy_turn = false
	_advance_to_next_actor()

func _enemy_move_toward_player(index: int) -> void:
	for step in range(ENEMY_MOVE_ALLOWANCE):
		if index < 0 or index >= enemies.size():
			return
		if _distance(enemies[index]["pos"], player_pos) == 1:
			return
		var enemy: Dictionary = enemies[index]
		var next: Vector2i = _step_toward(enemy["pos"], player_pos)
		if next == enemy["pos"] or _enemy_at(next) != -1:
			return
		enemy["pos"] = next
		enemies[index] = enemy

func _enemy_index_by_id(enemy_id: int) -> int:
	for i in range(enemies.size()):
		if int(enemies[i]["id"]) == enemy_id:
			return i
	return -1

func _brace_hits_enemy(index: int) -> bool:
	if not braced:
		return false
	braced = false
	_attack_enemy(index, run_state.selected_gear.damage + 1)
	message = "Brace lands before the enemy can strike."
	return true

func _enemy_attack(index: int) -> void:
	if index < 0 or index >= enemies.size():
		return
	var enemy: Dictionary = enemies[index]
	var damage: int = int(enemy["damage"])
	var attack_direction: Vector2i = Vector2i(_sign_int(enemy["pos"].x - player_pos.x), _sign_int(enemy["pos"].y - player_pos.y))
	if is_defending:
		damage = maxi(0, damage - 1)
		message = "Your defensive stance softens the hit."
	if block_stacks > 0:
		block_stacks -= 1
		damage = maxi(0, damage - 1)
		message = "Your shield absorbs part of the blow."
	if damage > 0:
		_apply_damage(damage)
	if run_state != null and run_state.selected_gear != null:
		match run_state.selected_gear.defense_id:
			"retaliate":
				_attack_enemy(index, 1)
				message = "Fire Shield lashes back for 1 damage."
			"flash_step":
				if _flash_step_back(attack_direction):
					message = "Flash Step snaps you backward from the blow."

func _apply_damage(amount: int) -> void:
	run_state.hurt(amount)
	if run_state.current_health <= 0:
		message = "You fall beneath the trees."

func _complete_floor() -> void:
	if exit_door != null:
		exit_door.enter()
		return
	_finish_floor()

func _on_exit_door_entered(_door: ExitDoor) -> void:
	_finish_floor()

func _finish_floor() -> void:
	if controller != null and controller.has_method("complete_forest_floor"):
		controller.complete_forest_floor()
		return
	var final_gold := run_state.gold
	controller.return_to_tavern("victory", "You escape the forest with %d gold. The bartender smiles like he expected it." % final_gold)

func _die() -> void:
	controller.return_to_tavern("death", "You wake at the tavern table. The bartender says, 'Again, then?'")

func _build_board_tiles() -> void:
	if ground_layer == null:
		return
	ground_layer.position = ORIGIN
	ground_layer.scale = Vector2.ONE
	ground_layer.clear()
	_clear_children_now(ground_layer)
	# Art handoff: this paints ambient ground across the full dungeon rectangle.
	# Walkability stays in floor_cells; border decorations communicate playable paths.
	# Non-walkable cells get a fog overlay below decor to separate overgrowth from path.
	for y in range(GRID_H):
		for x in range(GRID_W):
			var tile := Vector2i(x, y)
			_add_grass_sprite(tile)
			if not floor_cells.has(tile):
				_add_fog_sprite(tile)

func _add_grass_sprite(tile: Vector2i) -> void:
	var texture: Texture2D = _grass_texture_for(tile)
	var sprite := Sprite2D.new()
	sprite.name = "Grass_%d_%d" % [tile.x, tile.y]
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(tile) * TILE_SIZE
	sprite.scale = Vector2(GRASS_TILE_DRAW_SIZE / float(texture.get_width()), GRASS_TILE_DRAW_SIZE / float(texture.get_height()))
	sprite.z_index = 0
	ground_layer.add_child(sprite)

func _add_fog_sprite(tile: Vector2i) -> void:
	var texture: Texture2D = _fog_texture_for(tile)
	var sprite := Sprite2D.new()
	sprite.name = "Fog_%d_%d" % [tile.x, tile.y]
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(tile) * TILE_SIZE
	sprite.z_index = 1
	ground_layer.add_child(sprite)

func _grass_texture_for(tile: Vector2i) -> Texture2D:
	var index: int = abs(tile.x * 7 + tile.y * 11) % 2
	match index:
		0:
			return GRASS_TILE_A
		1:
			return GRASS_TILE_B
	return GRASS_TILE_C

func _fog_texture_for(tile: Vector2i) -> Texture2D:
	if fog_tile_textures.is_empty():
		_build_fog_tile_textures()
	var index: int = abs(tile.x * 13 + tile.y * 17) % fog_tile_textures.size()
	return fog_tile_textures[index]

func _build_fog_tile_textures() -> void:
	for variant in range(3):
		var image: Image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
		for y in range(TILE_SIZE):
			for x in range(TILE_SIZE):
				var wave: float = sin(float(x + variant * 17) * 0.17) + cos(float(y + variant * 23) * 0.13)
				var drift: float = sin(float(x + y + variant * 31) * 0.07)
				var alpha: float = 0.36 + wave * 0.035 + drift * 0.025
				image.set_pixel(x, y, Color(0.03, 0.04, 0.04, clampf(alpha, 0.28, 0.46)))
		fog_tile_textures.append(ImageTexture.create_from_image(image))

func _build_decorations() -> void:
	if decorations_root == null:
		return
	_clear_children(decorations_root)
	for decoration in decorations:
		var decoration_kind: String = decoration["kind"]
		var decoration_pos: Vector2i = decoration["pos"]
		var decoration_offset: Vector2 = decoration["offset"]
		var sprite := Sprite2D.new()
		sprite.name = "Decor_%s_%d_%d" % [decoration_kind, decoration_pos.x, decoration_pos.y]
		sprite.region_enabled = true
		sprite.centered = true
		sprite.position = _grid_center(decoration_pos) + decoration_offset
		_apply_decoration_sprite(sprite, decoration_kind)
		decorations_root.add_child(sprite)

func _apply_decoration_sprite(sprite: Sprite2D, kind: String) -> void:
	sprite.texture = PLANT_ATLAS
	sprite.region_enabled = true
	# Art handoff: forest decoration styling is intentionally centralized here.
	# Replace these named regions/scales when final foliage art arrives; generation
	# code should keep using semantic keys like "tree_large" or "grass_tuft_a".
	match kind:
		"tree_large":
			sprite.region_rect = Rect2(23, 16, 105, 138)
			sprite.scale = Vector2(0.36, 0.36)
			sprite.offset = Vector2(0, -14)
		"tree_wide":
			sprite.region_rect = Rect2(161, 18, 83, 137)
			sprite.scale = Vector2(0.34, 0.34)
			sprite.offset = Vector2(0, -13)
		"tree_small":
			sprite.region_rect = Rect2(295, 30, 74, 122)
			sprite.scale = Vector2(0.36, 0.36)
			sprite.offset = Vector2(0, -12)
		"low_bush_a":
			sprite.region_rect = Rect2(96, 196, 32, 29)
			sprite.scale = Vector2(0.72, 0.72)
			sprite.offset = Vector2(0, 7)
		"low_bush_b":
			sprite.region_rect = Rect2(155, 187, 41, 38)
			sprite.scale = Vector2(0.64, 0.64)
			sprite.offset = Vector2(0, 7)
		"rounded_bush":
			sprite.region_rect = Rect2(216, 184, 49, 42)
			sprite.scale = Vector2(0.58, 0.58)
			sprite.offset = Vector2(0, 7)
		"sapling":
			sprite.region_rect = Rect2(292, 177, 36, 48)
			sprite.scale = Vector2(0.62, 0.62)
			sprite.offset = Vector2(0, 5)
		"grass_tuft_a":
			sprite.region_rect = Rect2(8, 337, 15, 15)
			sprite.scale = Vector2(1.18, 1.18)
			sprite.offset = Vector2(0, 8)
		"grass_tuft_b":
			sprite.region_rect = Rect2(28, 337, 16, 15)
			sprite.scale = Vector2(1.12, 1.12)
			sprite.offset = Vector2(0, 8)
		"grass_tuft_c":
			sprite.region_rect = Rect2(47, 337, 17, 15)
			sprite.scale = Vector2(1.12, 1.12)
			sprite.offset = Vector2(0, 8)
		"mossy_rock":
			sprite.texture = PROPS_ATLAS
			sprite.region_rect = Rect2(4, 431, 33, 30)
			sprite.scale = Vector2(0.82, 0.82)
			sprite.offset = Vector2(0, 8)
		_:
			sprite.region_rect = Rect2(96, 196, 32, 29)
			sprite.scale = Vector2(0.72, 0.72)
			sprite.offset = Vector2(0, 7)

func _configure_player_sprite() -> void:
	var is_mage := run_state != null and run_state.selected_class_id == "mage"
	player_token.sprite_texture = FIRE_MAGE_SHEET if is_mage else PLAYER_IDLE_DOWN
	player_token.sprite_region_enabled = true
	player_token.sprite_region = Rect2(0, 0, 96, 80)
	player_token.sprite_scale = Vector2(0.58, 0.58)
	player_token.show_label = false
	player_token.show_panel = false

func _refresh_ui() -> void:
	if hud_label == null or run_state == null:
		return
	health_bar.max_value = run_state.max_health
	health_bar.value = run_state.current_health
	health_value_label.text = "%d/%d" % [run_state.current_health, run_state.max_health]
	title_label.text = "Forest Dungeon - Floor %d/%d" % [_current_floor(), _max_floors()]
	action_label.text = "%s | %s layout" % [_turn_status(), layout_type.capitalize()]
	hud_label.text = ""
	hud_label.visible = false
	log_label.text = message
	_sync_compact_status_panel()
	_sync_initiative_tracker()
	_sync_action_panel()
	_sync_board_nodes()

func _sync_compact_status_panel() -> void:
	if compact_status_body == null or run_state == null:
		return
	_clear_children_now(compact_status_body)
	var gear: GearData = run_state.selected_gear
	var gear_name := "None"
	var special_name := "None"
	if gear != null:
		gear_name = gear.display_name
		special_name = gear.special_id.capitalize()

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	compact_status_body.add_child(header)

	var portrait := TextureRect.new()
	portrait.texture = _player_portrait_texture()
	portrait.custom_minimum_size = Vector2(42, 42)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(portrait)

	var gear_icon := TextureRect.new()
	gear_icon.texture = ICON_SPELL if run_state.selected_class_id == "mage" else ICON_ATTACK
	gear_icon.custom_minimum_size = Vector2(24, 24)
	gear_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gear_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(gear_icon)

	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(identity)
	_add_small_label(identity, run_state.selected_class_name, 14, Color(0.97, 0.87, 0.62))
	_add_small_label(identity, gear_name, 11, Color(0.82, 0.73, 0.58))
	_add_small_label(identity, special_name, 10, Color(0.67, 0.86, 0.95))

	var stats_grid := GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 6)
	stats_grid.add_theme_constant_override("v_separation", 4)
	compact_status_body.add_child(stats_grid)
	stats_grid.add_child(_make_icon_stat_row(ICON_GOLD, "Gold", str(run_state.gold)))
	stats_grid.add_child(_make_icon_stat_row(ICON_KEY, "Keys", str(run_state.keys)))
	stats_grid.add_child(_make_icon_stat_row(ICON_POTION, "Potions", str(run_state.potions)))
	stats_grid.add_child(_make_icon_stat_row(ICON_BLOCK, "Block", str(block_stacks)))
	stats_grid.add_child(_make_icon_stat_row(ICON_MOVE, "Move", "Free" if _is_free_roam() else str(movement_remaining)))
	stats_grid.add_child(_make_icon_stat_row(ICON_MODE, "Mode", _action_name()))
	stats_grid.add_child(_make_icon_stat_row(ICON_FLOOR, "Floor", "%d/%d" % [_current_floor(), _max_floors()]))
	stats_grid.add_child(_make_icon_stat_row(ICON_ROUND, "Round", str(round_number)))

func _make_icon_stat_row(icon: Texture2D, label: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(118, 26)
	row.add_theme_constant_override("separation", 5)

	var image := TextureRect.new()
	image.texture = icon
	image.custom_minimum_size = Vector2(18, 18)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(image)

	var text := Label.new()
	text.text = "%s %s" % [label, value]
	text.clip_text = true
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", 11)
	text.add_theme_color_override("font_color", Color(0.90, 0.82, 0.68))
	row.add_child(text)
	return row

func _sync_initiative_tracker() -> void:
	if initiative_tracker == null:
		return
	_clear_children_now(initiative_tracker)
	if _is_free_roam():
		var clear_label := Label.new()
		clear_label.text = "Area Clear - Free Exploration"
		clear_label.add_theme_font_size_override("font_size", 14)
		clear_label.add_theme_color_override("font_color", Color(0.95, 0.84, 0.56))
		initiative_tracker.add_child(clear_label)
		return
	if initiative_order.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Initiative pending"
		empty_label.add_theme_font_size_override("font_size", 13)
		empty_label.add_theme_color_override("font_color", Color(0.86, 0.76, 0.55))
		initiative_tracker.add_child(empty_label)
		return
	for i in range(initiative_order.size()):
		var actor: Dictionary = initiative_order[i]
		initiative_tracker.add_child(_make_initiative_token(actor, i == current_actor_index))

func _make_initiative_token(actor: Dictionary, active: bool) -> PanelContainer:
	var token := PanelContainer.new()
	token.custom_minimum_size = Vector2(96, 52) if active else Vector2(88, 48)
	token.add_theme_stylebox_override("panel", _flat_style(
		Color(0.28, 0.20, 0.11, 0.96) if active else Color(0.10, 0.08, 0.06, 0.88),
		4,
		Color(0.98, 0.82, 0.34) if active else Color(0.42, 0.31, 0.18)
	))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	token.add_child(row)

	var image := TextureRect.new()
	image.texture = _actor_portrait_texture(actor)
	image.custom_minimum_size = Vector2(32, 32)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(image)

	var details := VBoxContainer.new()
	details.custom_minimum_size = Vector2(42, 0)
	row.add_child(details)

	var name_label := Label.new()
	name_label.text = _short_actor_name(actor)
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 10 if active else 9)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.62) if active else Color(0.78, 0.70, 0.58))
	details.add_child(name_label)

	var status_label := Label.new()
	status_label.text = "%d %s" % [int(actor["initiative"]), _actor_status_marker(actor)]
	status_label.clip_text = true
	status_label.add_theme_font_size_override("font_size", 9)
	status_label.add_theme_color_override("font_color", Color(0.82, 0.92, 0.95))
	details.add_child(status_label)
	return token

func _sync_action_panel() -> void:
	_set_combat_buttons_enabled()
	_set_button_selected(move_button, selected_action == "move")
	_set_button_selected(interact_button, selected_action == "attack")
	_set_button_selected(special_button, selected_action == "special")
	_set_button_selected(potion_button, false)
	_set_button_selected(defend_button, is_defending)
	_set_button_selected(end_turn_button, false)

func _set_button_selected(button: Button, selected: bool) -> void:
	if button == null:
		return
	if selected and not button.disabled:
		button.modulate = Color(1.0, 0.95, 0.68)
	else:
		button.modulate = Color(1.0, 1.0, 1.0)

func _player_portrait_texture() -> Texture2D:
	if run_state != null and run_state.selected_class_id == "mage":
		return _make_atlas_texture(FIRE_MAGE_SHEET, Rect2(0, 0, 96, 80))
	return _make_atlas_texture(PLAYER_IDLE_DOWN, Rect2(0, 0, 96, 80))

func _actor_portrait_texture(actor: Dictionary) -> Texture2D:
	if String(actor["kind"]) == "player":
		return _player_portrait_texture()
	return _make_atlas_texture(WOLF_SHEET, Rect2(0, 0, 96, 80))

func _make_atlas_texture(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return atlas

func _short_actor_name(actor: Dictionary) -> String:
	if String(actor["kind"]) == "player":
		return "You"
	if String(actor["name"]).begins_with("Elite"):
		return "Elite"
	return "Wolf"

func _actor_status_marker(actor: Dictionary) -> String:
	if String(actor["kind"]) == "player":
		if is_defending or braced:
			return "DEF"
		return ""
	var enemy_index: int = _enemy_index_by_id(int(actor["id"]))
	if enemy_index != -1 and int(enemies[enemy_index].get("stunned", 0)) > 0:
		return "STN"
	return ""

func _add_small_label(parent: Control, text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)

func _sync_board_nodes() -> void:
	if player_token == null or markers_root == null or enemies_root == null:
		return
	player_token.position = _grid_center(player_pos)
	_clear_generated_markers()
	_clear_children(enemies_root)

	exit_door.position = _grid_center(exit_pos)
	exit_door.setup(exit_pos, true)
	_configure_exit_sprite()
	for trap in traps:
		var trap_label: String = "!" if trap["sprung"] else "?"
		var trap_color: Color = Color(0.55, 0.08, 0.08) if trap["sprung"] else Color(0.46, 0.33, 0.13)
		_add_marker("Trap", trap["pos"], trap_label, trap_color, "trap")
	for item in loot:
		_add_marker(item["kind"].capitalize(), item["pos"], _loot_label(item["kind"]), Color(0.93, 0.75, 0.28), item["kind"])
	for prop in props:
		_add_marker(prop["kind"].capitalize(), prop["pos"], _prop_label(prop["kind"]), _prop_color(prop["kind"]), prop["kind"])
	if not chest["opened"]:
		_add_marker("LockedChest", chest["pos"], "C", Color(0.63, 0.38, 0.14), "chest")
	if secret["found"]:
		_add_marker("HiddenCache", secret["pos"], "$", Color(0.78, 0.73, 0.43), "secret")
	_add_highlight_markers()
	for i in range(enemies.size()):
		var enemy_piece: BoardPiece = _make_piece("Wolf_%d" % i, enemies[i]["pos"], "W", Color(0.56, 0.14, 0.14), BoardPiece.PieceShape.CIRCLE, "wolf")
		_add_enemy_health_bar(enemy_piece, enemies[i])
		enemies_root.add_child(enemy_piece)
	if minimap_panel != null:
		minimap_panel.set_map_state(_build_minimap_state())

func _add_marker(node_name: String, tile: Vector2i, label: String, color: Color, sprite_key: String) -> void:
	var marker := _make_piece(node_name, tile, label, color, BoardPiece.PieceShape.SQUARE, sprite_key)
	markers_root.add_child(marker)

func _make_piece(node_name: String, tile: Vector2i, label: String, color: Color, shape: int, sprite_key: String = "") -> BoardPiece:
	var piece: BoardPiece = BoardPieceScene.instantiate()
	piece.name = node_name
	piece.position = _grid_center(tile)
	piece.configure(label, color, shape)
	_apply_sprite_to_piece(piece, sprite_key)
	return piece

func _apply_sprite_to_piece(piece: BoardPiece, sprite_key: String) -> void:
	match sprite_key:
		"wolf":
			_set_piece_sprite(piece, WOLF_SHEET, Rect2(0, 0, 96, 80), Vector2(0.58, 0.58))
		"rock":
			_set_fitted_piece_sprite(piece, ROCK_SPRITE, Vector2(38, 34))
		"barrel":
			_set_fitted_piece_sprite(piece, BARREL_SPRITE, Vector2(36, 42))
		"campfire":
			_set_fitted_piece_sprite(piece, CAMPFIRE_SPRITE, Vector2(42, 40))
		"gold":
			_set_fitted_piece_sprite(piece, LOOT_SPRITE, Vector2(34, 42))
		"potion":
			_set_fitted_piece_sprite(piece, POTION_SPRITE, Vector2(26, 34))
		"key":
			_set_fitted_piece_sprite(piece, KEY_SPRITE, Vector2(32, 32))
		"chest":
			_set_fitted_piece_sprite(piece, CHEST_SPRITE, Vector2(46, 38))
		"trap":
			_set_fitted_piece_sprite(piece, TRAP_SPRITE, Vector2(34, 34))
		"secret":
			_set_piece_sprite(piece, PROPS_ATLAS, _atlas_region(1, 1), Vector2(1.5, 1.5))
		_:
			pass

func _set_piece_sprite(piece: BoardPiece, texture: Texture2D, region: Rect2, scale: Vector2) -> void:
	piece.sprite_texture = texture
	piece.sprite_region_enabled = true
	piece.sprite_region = region
	piece.sprite_scale = scale
	piece.show_label = false
	piece.show_panel = false

func _set_full_piece_sprite(piece: BoardPiece, texture: Texture2D, scale: Vector2) -> void:
	piece.sprite_texture = texture
	piece.sprite_region_enabled = false
	piece.sprite_scale = scale
	piece.show_label = false
	piece.show_panel = false

func _set_fitted_piece_sprite(piece: BoardPiece, texture: Texture2D, target_size: Vector2) -> void:
	var safe_size: Vector2 = Vector2(
		clampf(target_size.x, 8.0, TILE_SIZE),
		clampf(target_size.y, 8.0, TILE_SIZE)
	)
	var scale: Vector2 = Vector2(
		safe_size.x / float(texture.get_width()),
		safe_size.y / float(texture.get_height())
	)
	_set_full_piece_sprite(piece, texture, scale)

func _configure_exit_sprite() -> void:
	exit_door.sprite_texture = WOODEN_EXIT_DOOR
	exit_door.sprite_region_enabled = false
	exit_door.sprite_scale = Vector2(0.82, 0.82)
	exit_door.show_label = false
	exit_door.show_panel = false

func _atlas_region(x: int, y: int) -> Rect2:
	return Rect2(x * ATLAS_TILE_SIZE, y * ATLAS_TILE_SIZE, ATLAS_TILE_SIZE, ATLAS_TILE_SIZE)

func _add_enemy_health_bar(piece: BoardPiece, enemy: Dictionary) -> void:
	var bar := ProgressBar.new()
	bar.name = "HealthBar"
	bar.position = Vector2(-22, -32)
	bar.size = Vector2(44, 7)
	bar.max_value = int(enemy.get("max_health", 4))
	bar.value = int(enemy["hp"])
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _flat_style(Color(0.13, 0.04, 0.03), 1, Color(0.04, 0.02, 0.02)))
	bar.add_theme_stylebox_override("fill", _flat_style(Color(0.76, 0.12, 0.10), 1, Color(0.97, 0.45, 0.33)))
	piece.add_child(bar)

func _style_health_bar() -> void:
	if health_bar == null:
		return
	health_bar.add_theme_stylebox_override("background", _flat_style(Color(0.20, 0.07, 0.05), 4, Color(0.08, 0.04, 0.03)))
	health_bar.add_theme_stylebox_override("fill", _flat_style(Color(0.72, 0.08, 0.07), 4, Color(0.96, 0.42, 0.24)))
	health_bar.add_theme_font_size_override("font_size", 14)
	health_value_label.add_theme_color_override("font_color", Color(0.97, 0.89, 0.76))
	health_value_label.add_theme_font_size_override("font_size", 14)

func _style_action_buttons() -> void:
	for button: Button in _action_buttons():
		if button == null:
			continue
		button.custom_minimum_size = Vector2(0, 42)
		button.add_theme_stylebox_override("normal", _button_style(UI_BUTTON_NORMAL))
		button.add_theme_stylebox_override("hover", _button_style(UI_BUTTON_HOVER))
		button.add_theme_stylebox_override("pressed", _button_style(UI_BUTTON_PRESSED))
		button.add_theme_stylebox_override("focus", _button_style(UI_BUTTON_HOVER))
		button.add_theme_color_override("font_color", Color(0.20, 0.12, 0.07))
		button.add_theme_color_override("font_hover_color", Color(0.10, 0.07, 0.04))
		button.add_theme_color_override("font_pressed_color", Color(0.08, 0.05, 0.03))
		button.add_theme_font_size_override("font_size", 15)

func _action_buttons() -> Array[Button]:
	return [move_button, interact_button, special_button, potion_button, defend_button, end_turn_button]

func _button_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 8.0)
		style.set_content_margin(side, 10.0)
	return style

func _flat_style(color: Color, corner_radius: int, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(corner_radius)
	return style

func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()

func _clear_children_now(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _clear_generated_markers() -> void:
	for child in markers_root.get_children():
		if child != exit_door:
			child.queue_free()

func _build_minimap_state() -> Dictionary:
	var enemy_tiles: Array[Vector2i] = []
	for enemy in enemies:
		enemy_tiles.append(enemy["pos"])
	var prop_tiles: Array[Vector2i] = []
	for prop in props:
		prop_tiles.append(prop["pos"])
	var loot_tiles: Array[Vector2i] = []
	for item in loot:
		loot_tiles.append(item["pos"])
	var trap_tiles: Array[Vector2i] = []
	for trap in traps:
		trap_tiles.append(trap["pos"])
	return {
		"width": GRID_W,
		"height": GRID_H,
		"floor_cells": floor_cells.keys(),
		"player": player_pos,
		"exit": exit_pos,
		"enemies": enemy_tiles,
		"props": prop_tiles,
		"loot": loot_tiles,
		"traps": trap_tiles,
		"chest": chest["pos"],
		"secret": secret["pos"],
		"secret_found": secret["found"],
		"layout": layout_type,
	}

func _pick_floor_cell(avoid_path: bool) -> Vector2i:
	var cells := floor_cells.keys()
	for attempt in range(300):
		var tile: Vector2i = Vector2i(cells[rng.randi_range(0, cells.size() - 1)])
		if _reserved(tile):
			continue
		if avoid_path and critical_path.has(tile):
			continue
		return tile
	for attempt in range(300):
		var tile: Vector2i = Vector2i(cells[rng.randi_range(0, cells.size() - 1)])
		if not _reserved(tile):
			return tile
	return Vector2i(cells[0])

func _pick_role_cell(role: String, avoid_path: bool) -> Vector2i:
	var room_ids: Array[int] = []
	for room in room_graph:
		if str(room["role"]) == role:
			room_ids.append(int(room["id"]))
	if room_ids.is_empty():
		return _pick_floor_cell(avoid_path)
	return _pick_cell_in_rooms(room_ids, avoid_path)

func _pick_cell_in_rooms(room_ids: Array, avoid_path: bool) -> Vector2i:
	for attempt in range(120):
		var room: Dictionary = room_graph[room_ids[rng.randi_range(0, room_ids.size() - 1)]]
		var center: Vector2i = room["center"]
		var radius: Vector2i = room["radius"]
		var tile := Vector2i(
			rng.randi_range(center.x - radius.x, center.x + radius.x),
			rng.randi_range(center.y - radius.y, center.y + radius.y)
		)
		if not floor_cells.has(tile) or _reserved(tile):
			continue
		if avoid_path and critical_path.has(tile):
			continue
		return tile
	return _pick_floor_cell(avoid_path)

func _push_enemy_from(start_tile: Vector2i, direction: Vector2i, max_steps: int) -> bool:
	var enemy_index: int = _enemy_at(start_tile)
	if enemy_index == -1:
		return false
	var pushed := false
	for step in range(max_steps):
		var next: Vector2i = enemies[enemy_index]["pos"] + direction
		if not _is_walkable(next):
			break
		enemies[enemy_index]["pos"] = next
		pushed = true
	return pushed

func _flash_step_back(attack_direction: Vector2i) -> bool:
	var target := player_pos - attack_direction * 2
	if _is_walkable(target):
		player_pos = target
		return true
	target = player_pos - attack_direction
	if _is_walkable(target):
		player_pos = target
		return true
	return false

func _reserved(tile: Vector2i) -> bool:
	if tile == player_pos or tile == exit_pos:
		return true
	if chest.has("pos") and tile == chest["pos"]:
		return true
	if secret.has("pos") and tile == secret["pos"]:
		return true
	for prop in props:
		if prop["pos"] == tile:
			return true
	for item in loot:
		if item["pos"] == tile:
			return true
	for trap in traps:
		if trap["pos"] == tile:
			return true
	for enemy in enemies:
		if enemy["pos"] == tile:
			return true
	return false

func _decoration_at(tile: Vector2i) -> bool:
	for decoration in decorations:
		var decoration_pos: Vector2i = decoration["pos"]
		if decoration_pos == tile:
			return true
	return false

func _has_floor_neighbor(tile: Vector2i) -> bool:
	var deltas: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for delta in deltas:
		if floor_cells.has(tile + delta):
			return true
	return false

func _step_toward(from_tile: Vector2i, to_tile: Vector2i) -> Vector2i:
	var options: Array[Vector2i] = []
	var dx := _sign_int(to_tile.x - from_tile.x)
	var dy := _sign_int(to_tile.y - from_tile.y)
	if abs(to_tile.x - from_tile.x) >= abs(to_tile.y - from_tile.y):
		options = [Vector2i(dx, 0), Vector2i(0, dy), Vector2i(-dx, 0), Vector2i(0, -dy)]
	else:
		options = [Vector2i(0, dy), Vector2i(dx, 0), Vector2i(0, -dy), Vector2i(-dx, 0)]
	for delta in options:
		if delta == Vector2i.ZERO:
			continue
		var candidate: Vector2i = from_tile + delta
		if _is_walkable(candidate) and candidate != player_pos:
			return candidate
	return from_tile

func _is_walkable(tile: Vector2i) -> bool:
	return floor_cells.has(tile) and _prop_at(tile) == -1 and tile != chest["pos"] and _enemy_at(tile) == -1

func _prop_at(tile: Vector2i) -> int:
	for i in range(props.size()):
		if props[i]["pos"] == tile:
			return i
	return -1

func _enemy_at(tile: Vector2i) -> int:
	for i in range(enemies.size()):
		if enemies[i]["pos"] == tile:
			return i
	return -1

func _screen_to_grid(pos: Vector2) -> Vector2i:
	var local := pos - ORIGIN
	return Vector2i(floori(local.x / TILE_SIZE), floori(local.y / TILE_SIZE))

func _grid_to_screen(tile: Vector2i) -> Vector2:
	return ORIGIN + Vector2(tile) * TILE_SIZE

func _grid_center(tile: Vector2i) -> Vector2:
	return _grid_to_screen(tile) + Vector2(TILE_SIZE, TILE_SIZE) * 0.5

func _is_inside_grid(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < GRID_W and tile.y < GRID_H

func _distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func _line_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(abs(a.x - b.x), abs(a.y - b.y))

func _can_ranged_attack(tile: Vector2i, enemy_index: int) -> bool:
	if enemy_index == -1 or run_state == null or run_state.selected_class_id != "mage":
		return false
	var distance := _line_distance(player_pos, tile)
	if distance <= 1 or distance > 4:
		return false
	if not _is_straight_line_target(tile, 4, true):
		return false
	return _has_clear_line(player_pos, tile, true)

func _direction_to(tile: Vector2i) -> Vector2i:
	return Vector2i(_sign_int(tile.x - player_pos.x), _sign_int(tile.y - player_pos.y))

func _cardinal_directions() -> Array[Vector2i]:
	return [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

func _eight_directions() -> Array[Vector2i]:
	return [
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i(-1, -1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(1, 1),
	]

func _is_free_roam() -> bool:
	return free_roam_started

func _current_floor() -> int:
	if run_state == null:
		return 1
	return run_state.current_floor

func _max_floors() -> int:
	if run_state == null:
		return 5
	return run_state.max_floors

func _floor_intro_message() -> String:
	var room_note := "The path is direct, but the trees still listen."
	match layout_type:
		"branching":
			room_note = "Side paths split away toward caches and snares."
		"hub":
			room_note = "A tangled clearing acts as the heart of this floor."
		"loop":
			room_note = "The trail bends back on itself with uneasy shortcuts."
		"arena":
			room_note = "The final grove opens wide, daring you to cross it."
	return "Floor %d/%d: %s" % [_current_floor(), _max_floors(), room_note]

func _dead_end_room_ids() -> Array[int]:
	var ids: Array[int] = []
	for room in room_graph:
		if room["neighbors"].size() == 1:
			ids.append(int(room["id"]))
	return ids

func _room_ids_except(excluded: Array) -> Array[int]:
	var ids: Array[int] = []
	for room in room_graph:
		var id: int = int(room["id"])
		if excluded.has(id):
			continue
		if str(room["role"]) != "normal":
			continue
		ids.append(id)
	return ids

func _first_noncritical_room(ids: Array) -> int:
	for id in ids:
		if id == -1:
			continue
		if not critical_room_ids.has(id):
			return id
	for id in ids:
		if id == -1:
			continue
		if room_graph[id]["role"] == "normal":
			return id
	return -1

func _last_non_endpoint_room() -> int:
	for i in range(room_graph.size() - 1, -1, -1):
		if room_graph[i]["role"] == "normal":
			return i
	return -1

func _sign_int(value: int) -> int:
	if value > 0:
		return 1
	if value < 0:
		return -1
	return 0

func _loot_label(kind: String) -> String:
	match kind:
		"gold":
			return "G"
		"potion":
			return "P"
		"key":
			return "K"
	return "?"

func _prop_label(kind: String) -> String:
	match kind:
		"rock":
			return "R"
		"barrel":
			return "B"
		"campfire":
			return "F"
	return "?"

func _prop_color(kind: String) -> Color:
	match kind:
		"rock":
			return Color(0.38, 0.41, 0.39)
		"barrel":
			return Color(0.47, 0.27, 0.12)
		"campfire":
			return Color(0.86, 0.28, 0.10)
	return Color(0.5, 0.5, 0.5)
