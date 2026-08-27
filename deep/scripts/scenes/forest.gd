extends Node2D

const TILE_SIZE := 48
const ORIGIN := Vector2(40, 150)
const BoardPieceScene := preload("res://scenes/components/BoardPiece.tscn")
const PLAYER_IDLE_DOWN := preload("res://assets/sprite_packs/Player/IDLE/idle_down.png")
const FIRE_MAGE_SHEET := preload("res://assets/enemies/fire_mage/normalized_sheet.png")
const WOLF_SHEET := preload("res://assets/enemies/feral_wolf/normalized_sheet.png")
const KOBOLD_IDLE_SHEET := preload("res://assets/sprite_packs/Kobold/Sprites/with_outline/IDLE.png")
const CRYPT_SKELETON := preload("res://assets/enemies/crypt/skeleton.png")
const CRYPT_GHOUL := preload("res://assets/enemies/crypt/ghoul.png")
const CRYPT_NECROMANCER := preload("res://assets/enemies/crypt/necromancer.png")
const CRYPT_BOSS := preload("res://assets/enemies/crypt/crypt_boss.png")
const GRASS_TILE_A := preload("res://assets/pixel_art/forest_art/grass1.jpeg")
const GRASS_TILE_B := preload("res://assets/pixel_art/forest_art/grass2.jpg")
const GRASS_TILE_C := preload("res://assets/pixel_art/forest_art/grass3.jpg")
const CRYPT_STONE_TILE := preload("res://assets/pixel_art/TX Tileset Stone Ground.png")
const FREEPACK_ATLAS := preload("res://assets/pixel_art/FreePack.png")
const WOODEN_EXIT_DOOR := preload("res://assets/generated_ui/wooden_exit_door.png")
const PROPS_ATLAS := preload("res://assets/pixel_art/TX Props.png")
const STRUCT_ATLAS := preload("res://assets/pixel_art/TX Struct.png")
const PLANT_ATLAS := preload("res://assets/pixel_art/TX Plant.png")
const ATLAS_TILE_SIZE := 32
const GRASS_TILE_DRAW_SIZE := 48.0
const PLAYER_MOVE_ALLOWANCE := 3
const FREE_ROAM_MOVE_ALLOWANCE := 99
const ENEMY_MOVE_ALLOWANCE := 2
const ENEMY_TURN_DELAY := 0.5
const RIGHT_HUD_WIDTH := 330.0
const RIGHT_HUD_GUTTER := 24.0
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
# Item-card art handoff: generated fantasy UI assets are wrapped by
# scripts/ui/item_reward_card.gd so future card styling can move out of combat code.
const ACTION_HOTKEYS := {
	"move": "1",
	"attack": "2",
	"special": "3",
	"potion": "4",
	"defend": "5",
	"end": "Enter",
	"cancel": "Esc",
}
# Boss chamber handoff: floor 5 uses these fixed 16x11 character maps instead
# of procedural room graphs. Designers can tune room flow by editing symbols here:
# S player start, E exit, B boss, W wolf, L elite wolf, O blood wolf, D kobold, C chest, R rock,
# A barrel, F campfire, T trap, G gold, P potion, K key, . walkable grass.
const BOSS_CHAMBERS := [
	{
		"id": "heartwood_throne",
		"name": "Heartwood Throne",
		"rows": [
			"################",
			"####....E...####",
			"###..R...R...###",
			"##....DWO.....##",
			"##..R..B..R...##",
			"##.....L......##",
			"###..T...T...###",
			"####...C...#####",
			"#####.S.P.######",
			"######...#######",
			"################",
		],
	},
	{
		"id": "split_root_bridge",
		"name": "Split-Root Bridge",
		"rows": [
			"################",
			"###E....B....###",
			"###.RR...RR..###",
			"###...D.W....###",
			"#####..T..######",
			"##....L....C..##",
			"##.A.....A....##",
			"##....T....G..##",
			"#####..S..######",
			"######...#######",
			"################",
		],
	},
	{
		"id": "moonlit_den",
		"name": "Moonlit Den",
		"rows": [
			"################",
			"####...E....####",
			"###..R...R...###",
			"##...D.B.O....##",
			"##..R.....R...##",
			"##.....L......##",
			"##..T.....T...##",
			"###...C.K....###",
			"####..S.P...####",
			"#####.....######",
			"################",
		],
	},
	{
		"id": "bramble_crossing",
		"name": "Bramble Crossing",
		"rows": [
			"################",
			"##E....R....G###",
			"##..###.###...##",
			"##D..A.B.A..O.##",
			"####...L...#####",
			"##....T.T....###",
			"##..###.###...##",
			"##...C...P....##",
			"####...S...#####",
			"#####.....######",
			"################",
		],
	},
	{
		"id": "fallen_grove",
		"name": "Fallen Grove",
		"rows": [
			"################",
			"###....E.....###",
			"##..R.....R...##",
			"##.D...B...O..##",
			"##....AAA.....##",
			"###..T.L.T...###",
			"##.....F.....###",
			"##..G..C..K...##",
			"###....S....####",
			"#####.....######",
			"################",
		],
	},
]

var controller: Node
var run_state: RunState
var rng := RandomNumberGenerator.new()
var dungeon_id: String = "forest"
var dungeon_title: String = "Forest Dungeon"
var dungeon_floor_label: String = "Floor"
var complete_floor_method: String = "complete_forest_floor"
var victory_text_template: String = "You escape the forest with %d gold. The bartender smiles like he expected it."
var grid_w: int = 16
var grid_h: int = 11
var tile_size: int = TILE_SIZE
var use_follow_camera: bool = false
var camera_ui_right_margin: float = 0.0
var camera_ui_top_margin: float = 0.0

var floor_cells: Dictionary = {}
var critical_path: Dictionary = {}
var room_graph: Array[Dictionary] = []
var critical_room_ids: Array[int] = []
var layout_type := "linear"
var boss_chamber_name := ""
var player_pos := Vector2i(2, 8)
var exit_pos := Vector2i(14, 2)
var facing := Vector2i.RIGHT
var block_stacks := 0
var braced := false
var is_defending := false
var armed_reaction := ""
var empowered := false
var is_hidden := false
var retribution_armed := false
var retribution_stored := 0
var marked_enemy_id := -1
var companion: Dictionary = {}
var player_attack_count := 0
var player_spell_count_floor := 0
var incoming_hit_count := 0
var tiles_moved_this_turn := 0
var last_target_id := -1
var studied_target_ids: Dictionary = {}
var item_limits_used: Dictionary = {}
var next_attack_item_bonuses: Dictionary = {}
var temporary_aegis := 0
var stored_spell_damage := 0
var last_player_hit_round := -1
var was_below_half_health := false
var seen_enemy_types: Dictionary = {}
var selected_action := "move"
var movement_remaining := PLAYER_MOVE_ALLOWANCE
var has_used_action := false
var bonus_actions_remaining := 0
var next_consumable_damage_multiplier := 1
var next_consumable_accuracy_bonus := 0
var is_player_turn := false
var is_resolving_enemy_turn := false
var combat_started := false
var free_roam_started := false
var floor_clear_xp_awarded := false
var round_number := 1
var current_actor_index := 0
var initiative_order: Array[Dictionary] = []
var enemy_id_counter := 1
var effects_root: Node2D
const MAX_COMBAT_LOG_ENTRIES := 200
var combat_log_entries: Array[Dictionary] = []
var combat_log_backdrop: ColorRect
var combat_log_panel: PanelContainer
var combat_log_text: RichTextLabel
var merchant_shop_panel: MerchantShopPanel
var dungeon_merchant: Dictionary = {}

var enemies: Array[Dictionary] = []
var props: Array[Dictionary] = []
var loot: Array[Dictionary] = []
var traps: Array[Dictionary] = []
var decorations: Array[Dictionary] = []
var progression_log_buffer: Array[String] = []
var chest: Dictionary = {"pos": Vector2i(10, 4), "opened": false}
var secret: Dictionary = {"pos": Vector2i(6, 7), "found": false}

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
var cancel_action_button: Button
var initiative_panel: PanelContainer
var initiative_tracker: HBoxContainer
var actions_panel: PanelContainer
var actions_grid: GridContainer
var hover_panel: PanelContainer
var hover_title_label: Label
var hover_detail_label: Label
var hover_actions_box: HBoxContainer
var hovered_tile := Vector2i(-999, -999)
var hovered_object: Dictionary = {}
var character_menu_panel: PlayerCharacterMenu
var chest_choice_backdrop: ColorRect
var chest_choice_panel: PanelContainer
var chest_choice_title_label: Label
var chest_choice_subtitle_label: Label
var chest_choice_cards: HBoxContainer
var reward_choice_source: String = "chest"
var follow_camera: Camera2D
var consumables_backdrop: ColorRect
var consumables_panel: PanelContainer
var consumables_box: VBoxContainer
var hovered_action_preview := ""

func setup(game_controller: Node, state: RunState) -> void:
	controller = game_controller
	run_state = state
	_configure_dungeon_settings()
	block_stacks = 0
	if is_inside_tree():
		_generate()
		_build_board_tiles()
		_build_decorations()
		_refresh_ui()

func _ready() -> void:
	_configure_dungeon_settings()
	_setup_follow_camera()
	title_label.add_theme_font_size_override("font_size", 24)
	_style_health_bar()
	_setup_combat_layout_ui()
	_setup_combat_log_ui()
	_setup_dungeon_shop_ui()
	_setup_consumables_ui()
	_setup_action_buttons()
	potion_button.pressed.connect(_open_consumables)
	exit_door.door_entered.connect(_on_exit_door_entered)
	_generate()
	_build_board_tiles()
	_build_decorations()
	_configure_player_sprite()
	_refresh_ui()

func _process(_delta: float) -> void:
	_update_follow_camera()

func _configure_dungeon_settings() -> void:
	dungeon_id = "forest"
	dungeon_title = "Forest Dungeon"
	dungeon_floor_label = "Floor"
	complete_floor_method = "complete_forest_floor"
	victory_text_template = "You escape the forest with %d gold. The bartender smiles like he expected it."
	grid_w = 16
	grid_h = 11
	tile_size = TILE_SIZE
	use_follow_camera = false
	camera_ui_right_margin = 0.0
	camera_ui_top_margin = 0.0

func _setup_follow_camera() -> void:
	if not use_follow_camera or follow_camera != null:
		return
	follow_camera = Camera2D.new()
	follow_camera.name = "PlayerFollowCamera"
	follow_camera.position_smoothing_enabled = true
	follow_camera.position_smoothing_speed = 8.0
	add_child(follow_camera)
	follow_camera.make_current()
	_update_follow_camera(true)

func _update_follow_camera(force: bool = false) -> void:
	if not use_follow_camera or follow_camera == null:
		return
	var right_margin: float = _effective_camera_right_margin()
	var top_margin: float = _effective_camera_top_margin()
	follow_camera.offset = Vector2.ZERO
	var target: Vector2 = _grid_center(player_pos) + Vector2(right_margin * 0.5, -top_margin * 0.5)
	target = _clamped_camera_position(target)
	if force:
		follow_camera.reset_smoothing()
		follow_camera.position = target
	else:
		follow_camera.position = target

func _clamped_camera_position(target: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var right_margin: float = _effective_camera_right_margin()
	var top_margin: float = _effective_camera_top_margin()
	var full_half_view: Vector2 = viewport_size * 0.5
	var min_world: Vector2 = ORIGIN
	var max_world: Vector2 = ORIGIN + Vector2(grid_w * tile_size, grid_h * tile_size)
	var board_size: Vector2 = max_world - min_world
	var clamped: Vector2 = target
	var visible_width: float = maxf(320.0, viewport_size.x - right_margin)
	var visible_height: float = maxf(260.0, viewport_size.y - top_margin)
	if board_size.x <= visible_width:
		clamped.x = min_world.x + board_size.x * 0.5 + right_margin * 0.5
	else:
		var min_camera_x: float = min_world.x + full_half_view.x
		var max_camera_x: float = max_world.x - full_half_view.x + right_margin
		clamped.x = clampf(target.x, min_camera_x, max_camera_x)
	if board_size.y <= visible_height:
		clamped.y = min_world.y + board_size.y * 0.5 - top_margin * 0.5
	else:
		var min_camera_y: float = min_world.y + full_half_view.y - top_margin
		var max_camera_y: float = max_world.y - full_half_view.y
		clamped.y = clampf(target.y, min_camera_y, max_camera_y)
	return clamped

func _effective_camera_right_margin() -> float:
	var measured_margin: float = 0.0
	var right_panel_node: Node = get_node_or_null("UI/Root/Columns/RightPanel")
	if right_panel_node is Control:
		var right_panel: Control = right_panel_node as Control
		var rect: Rect2 = right_panel.get_global_rect()
		var viewport_width: float = get_viewport_rect().size.x
		if rect.size.x > 1.0 and rect.position.x < viewport_width:
			measured_margin = viewport_width - rect.position.x
	return maxf(camera_ui_right_margin, measured_margin + RIGHT_HUD_GUTTER)

func _effective_camera_top_margin() -> float:
	var measured_margin: float = 0.0
	if initiative_panel != null and initiative_panel.is_inside_tree() and initiative_panel.visible:
		var rect: Rect2 = initiative_panel.get_global_rect()
		measured_margin = rect.position.y + rect.size.y
	return maxf(camera_ui_top_margin, measured_margin + 10.0)

func _setup_combat_layout_ui() -> void:
	var ui_layer: CanvasLayer = $UI
	var root: MarginContainer = $UI/Root
	root.add_theme_constant_override("margin_top", 86)

	var right_panel: VBoxContainer = $UI/Root/Columns/RightPanel
	var left_panel: VBoxContainer = $UI/Root/Columns/LeftPanel
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.custom_minimum_size = Vector2(RIGHT_HUD_WIDTH, 0)
	right_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	right_panel.add_theme_constant_override("separation", 8)
	health_bar.custom_minimum_size = Vector2(210, 18)
	health_value_label.custom_minimum_size = Vector2(64, 18)
	minimap_panel.custom_minimum_size = Vector2(RIGHT_HUD_WIDTH, 154)
	minimap_panel.size = minimap_panel.custom_minimum_size
	log_label.custom_minimum_size = Vector2(RIGHT_HUD_WIDTH, 84)
	log_label.mouse_filter = Control.MOUSE_FILTER_STOP
	log_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	log_label.tooltip_text = "Open the detailed combat log"
	log_label.gui_input.connect(_on_combat_log_input)
	log_label.add_theme_stylebox_override("normal", _flat_style(Color(0.10, 0.075, 0.045, 0.92), 4, Color(0.58, 0.39, 0.17)))
	log_label.add_theme_color_override("font_color", Color(0.94, 0.84, 0.67))
	log_label.add_theme_constant_override("outline_size", 1)
	log_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))

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

	var spacer := Control.new()
	spacer.name = "RightPanelFlexSpacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var log_index: int = log_label.get_index()
	right_panel.add_child(spacer)
	right_panel.move_child(spacer, log_index)

	actions_panel = PanelContainer.new()
	actions_panel.name = "ActionsPanel"
	actions_panel.custom_minimum_size = Vector2(RIGHT_HUD_WIDTH, 0)
	actions_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
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

	# UI handoff: modal surfaces for rewards and character inventory live here.
	# Artists/designers can restyle these panels without touching combat rules.
	_setup_chest_choice_modal(ui_layer)
	_setup_character_menu(ui_layer)

func _setup_combat_log_ui() -> void:
	var ui_layer: CanvasLayer = $UI
	combat_log_backdrop = ColorRect.new()
	combat_log_backdrop.name = "CombatLogBackdrop"
	combat_log_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	combat_log_backdrop.color = Color(0.025, 0.018, 0.012, 0.78)
	combat_log_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	combat_log_backdrop.visible = false
	combat_log_backdrop.gui_input.connect(_on_combat_log_backdrop_input)
	ui_layer.add_child(combat_log_backdrop)

	combat_log_panel = PanelContainer.new()
	combat_log_panel.name = "CombatLogPanel"
	combat_log_panel.set_anchors_preset(Control.PRESET_CENTER)
	combat_log_panel.position = Vector2(-360, -270)
	combat_log_panel.size = Vector2(720, 540)
	combat_log_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	combat_log_panel.add_theme_stylebox_override("panel", _flat_style(Color(0.09, 0.065, 0.04, 0.99), 8, Color(0.84, 0.62, 0.27)))
	combat_log_backdrop.add_child(combat_log_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	combat_log_panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var title := Label.new()
	title.text = "Detailed Combat Log"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42))
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_hide_combat_log)
	_apply_flat_ui_button(close_button, 13, Vector2(82, 34))
	header.add_child(close_button)
	var help := Label.new()
	help.text = "Attack rolls exceed Evasion to hit. Rolls at or below AC can provoke an armed reaction. Penetration reduces Threshold and Aegis."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color(0.76, 0.70, 0.61))
	body.add_child(help)
	combat_log_text = RichTextLabel.new()
	combat_log_text.bbcode_enabled = true
	combat_log_text.fit_content = false
	combat_log_text.scroll_active = true
	combat_log_text.selection_enabled = true
	combat_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	combat_log_text.add_theme_font_size_override("normal_font_size", 14)
	combat_log_text.add_theme_color_override("default_color", Color(0.93, 0.87, 0.77))
	body.add_child(combat_log_text)

func _setup_dungeon_shop_ui() -> void:
	merchant_shop_panel = MerchantShopPanel.new()
	merchant_shop_panel.name = "DungeonMerchantShop"
	merchant_shop_panel.purchase_completed.connect(_on_dungeon_shop_purchase)
	$UI.add_child(merchant_shop_panel)

func _open_dungeon_shop() -> void:
	if merchant_shop_panel == null or run_state == null:
		return
	merchant_shop_panel.setup(run_state, dungeon_id, "dungeon")
	merchant_shop_panel.open()

func _on_dungeon_shop_purchase(purchase_message: String) -> void:
	message = purchase_message
	_refresh_ui()

func _setup_consumables_ui() -> void:
	consumables_backdrop = ColorRect.new()
	consumables_backdrop.name = "ConsumablesBackdrop"
	consumables_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	consumables_backdrop.color = Color(0.025, 0.018, 0.012, 0.76)
	consumables_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	consumables_backdrop.visible = false
	$UI.add_child(consumables_backdrop)
	consumables_panel = PanelContainer.new()
	consumables_panel.set_anchors_preset(Control.PRESET_CENTER)
	consumables_panel.position = Vector2(-270, -230)
	consumables_panel.size = Vector2(540, 460)
	consumables_panel.add_theme_stylebox_override("panel", _flat_style(Color(0.09, 0.065, 0.04, 0.99), 8, Color(0.80, 0.58, 0.26)))
	consumables_backdrop.add_child(consumables_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_%s" % side, 16)
	consumables_panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var title := Label.new()
	title.text = "Choose a Consumable"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.83, 0.43))
	header.add_child(title)
	var close := Button.new()
	close.text = "Cancel"
	close.pressed.connect(_close_consumables)
	_apply_flat_ui_button(close, 13, Vector2(84, 34))
	header.add_child(close)
	var capacity_label := Label.new()
	capacity_label.name = "CapacityLabel"
	capacity_label.add_theme_color_override("font_color", Color(0.78, 0.72, 0.63))
	body.add_child(capacity_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	consumables_box = VBoxContainer.new()
	consumables_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	consumables_box.add_theme_constant_override("separation", 8)
	scroll.add_child(consumables_box)

func _open_consumables() -> void:
	if not is_player_turn or has_used_action:
		message = "Your action is already spent."
		_refresh_ui()
		return
	if run_state.get_consumables().is_empty():
		message = "Your Consumables slots are empty."
		_refresh_ui()
		return
	_rebuild_consumables_menu()
	consumables_backdrop.visible = true
	consumables_backdrop.move_to_front()

func _close_consumables() -> void:
	if consumables_backdrop != null:
		consumables_backdrop.visible = false

func _rebuild_consumables_menu() -> void:
	var ids := run_state.get_consumables()
	var capacity_label := consumables_panel.find_child("CapacityLabel", true, false) as Label
	if capacity_label != null:
		capacity_label.text = "%d/%d slots filled. Using one consumes your action." % [ids.size(), run_state.get_consumable_capacity()]
	for child in consumables_box.get_children(): child.queue_free()
	for index in range(ids.size()):
		var consumable_id := String(ids[index])
		var data := GameBalance.get_consumable(consumable_id)
		var button := Button.new()
		button.text = "%s\n%s" % [String(data.get("name", consumable_id.capitalize())), String(data.get("description", ""))]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 58)
		var icon_path := String(data.get("icon", ""))
		if ResourceLoader.exists(icon_path):
			button.icon = _normalized_consumable_icon(icon_path, 32)
			button.expand_icon = false
		button.pressed.connect(_use_consumable.bind(index))
		_apply_flat_ui_button(button, 13, Vector2.ZERO)
		consumables_box.add_child(button)

func _normalized_consumable_icon(icon_path: String, max_size: int) -> Texture2D:
	var source: Texture2D = load(icon_path)
	if source == null: return null
	var image := source.get_image()
	if image == null or image.is_empty(): return source
	var source_size := image.get_size()
	var scale_factor := minf(1.0, float(max_size) / float(maxi(source_size.x, source_size.y)))
	var target_size := Vector2i(maxi(1, roundi(source_size.x * scale_factor)), maxi(1, roundi(source_size.y * scale_factor)))
	image.resize(target_size.x, target_size.y, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)

func _use_consumable(index: int) -> void:
	var ids := run_state.get_consumables()
	if index < 0 or index >= ids.size():
		return
	var consumable_id := String(ids[index])
	var data := GameBalance.get_consumable(consumable_id)
	var effects: Dictionary = data.get("effects", {})
	var notes: Array[String] = []
	if effects.has("heal"):
		var heal_amount := int(effects["heal"]) + run_state.get_derived_stat("potion_heal_bonus")
		var before := run_state.current_health
		run_state.heal(heal_amount)
		notes.append("restored %d health" % (run_state.current_health - before))
		if before + heal_amount > run_state.max_health:
			_apply_item_trigger("overheal", {"amount": before + heal_amount - run_state.max_health})
	if effects.has("resource"):
		var before_resource := run_state.class_resource
		run_state.gain_class_resource(int(effects["resource"]))
		notes.append("restored %d %s" % [run_state.class_resource - before_resource, run_state.get_class_resource_name()])
	if bool(effects.get("hidden", false)):
		is_hidden = true
		notes.append("granted Hidden")
	if effects.has("temporary_aegis"):
		temporary_aegis += int(effects["temporary_aegis"])
		notes.append("granted %d temporary Aegis" % int(effects["temporary_aegis"]))
	if effects.has("movement"):
		movement_remaining += int(effects["movement"])
		notes.append("granted %d movement" % int(effects["movement"]))
	if effects.has("movement_multiplier"):
		var old_movement := movement_remaining
		movement_remaining *= maxi(1, int(effects["movement_multiplier"]))
		notes.append("doubled movement from %d to %d" % [old_movement, movement_remaining])
	if effects.has("extra_actions"):
		bonus_actions_remaining += maxi(0, int(effects["extra_actions"]))
		notes.append("granted %d additional action" % int(effects["extra_actions"]))
	if effects.has("next_attack_damage_multiplier"):
		next_consumable_damage_multiplier = maxi(next_consumable_damage_multiplier, int(effects["next_attack_damage_multiplier"]))
		notes.append("granted x%d damage to the next attack" % next_consumable_damage_multiplier)
	if bool(effects.get("resource_fill", false)):
		var before_fill := run_state.class_resource
		run_state.gain_class_resource(run_state.get_class_resource_max())
		notes.append("restored %d %s" % [run_state.class_resource - before_fill, run_state.get_class_resource_name()])
	if effects.has("next_attack_accuracy"):
		next_consumable_accuracy_bonus += int(effects["next_attack_accuracy"])
		notes.append("granted +%d Accuracy to the next attack" % int(effects["next_attack_accuracy"]))
	var item_trigger := String(effects.get("item_trigger", ""))
	if not item_trigger.is_empty(): _apply_item_trigger(item_trigger)
	run_state.remove_consumable_at(index)
	_close_consumables()
	message = "Used %s: %s." % [String(data.get("name", consumable_id.capitalize())), ", ".join(notes)]
	_finish_player_action()

func _on_combat_log_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_show_combat_log()

func _on_combat_log_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_hide_combat_log()

func _show_combat_log() -> void:
	if combat_log_backdrop == null:
		return
	_rebuild_combat_log_text()
	combat_log_backdrop.visible = true
	combat_log_backdrop.move_to_front()

func _hide_combat_log() -> void:
	if combat_log_backdrop != null:
		combat_log_backdrop.visible = false

func _rebuild_combat_log_text() -> void:
	if combat_log_text == null:
		return
	if combat_log_entries.is_empty():
		combat_log_text.text = "[color=#b7aa92]No attacks have been resolved on this floor yet.[/color]"
		return
	var lines: Array[String] = []
	for entry in combat_log_entries:
		var tint := String(entry.get("color", "#e7d8bd"))
		lines.append("[color=#9a7b4a]Round %d[/color]  [color=%s][b]%s[/b][/color]\n%s" % [
			int(entry.get("round", round_number)), tint, String(entry.get("summary", "Combat event")), String(entry.get("details", ""))
		])
	combat_log_text.text = "\n\n".join(lines)
	combat_log_text.scroll_to_line(maxi(0, combat_log_text.get_line_count() - 1))

func _record_combat_event(summary: String, details: String, color: String = "#e7d8bd") -> void:
	combat_log_entries.append({"round": round_number, "summary": summary, "details": details, "color": color})
	if combat_log_entries.size() > MAX_COMBAT_LOG_ENTRIES:
		combat_log_entries.pop_front()
	if combat_log_backdrop != null and combat_log_backdrop.visible:
		_rebuild_combat_log_text()

func _setup_chest_choice_modal(ui_layer: CanvasLayer) -> void:
	chest_choice_backdrop = ColorRect.new()
	chest_choice_backdrop.name = "ChestChoiceBackdrop"
	chest_choice_backdrop.visible = false
	chest_choice_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	chest_choice_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	chest_choice_backdrop.color = Color(0.025, 0.018, 0.012, 0.72)
	ui_layer.add_child(chest_choice_backdrop)

	chest_choice_panel = PanelContainer.new()
	chest_choice_panel.name = "ChestChoiceModal"
	chest_choice_panel.visible = false
	chest_choice_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	chest_choice_panel.set_anchors_preset(Control.PRESET_CENTER)
	chest_choice_panel.offset_left = -405
	chest_choice_panel.offset_top = -245
	chest_choice_panel.offset_right = 405
	chest_choice_panel.offset_bottom = 245
	chest_choice_panel.add_theme_stylebox_override("panel", _reward_modal_style())
	ui_layer.add_child(chest_choice_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	chest_choice_panel.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)

	chest_choice_title_label = Label.new()
	chest_choice_title_label.text = "Choose One Relic"
	chest_choice_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chest_choice_title_label.add_theme_font_size_override("font_size", 25)
	chest_choice_title_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.50))
	body.add_child(chest_choice_title_label)

	chest_choice_subtitle_label = Label.new()
	chest_choice_subtitle_label.text = "The chest opens with three offerings. Claim one boon for the road ahead."
	chest_choice_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chest_choice_subtitle_label.add_theme_font_size_override("font_size", 12)
	chest_choice_subtitle_label.add_theme_color_override("font_color", Color(0.78, 0.68, 0.50))
	body.add_child(chest_choice_subtitle_label)

	chest_choice_cards = HBoxContainer.new()
	chest_choice_cards.name = "ChestChoiceCards"
	chest_choice_cards.add_theme_constant_override("separation", 14)
	body.add_child(chest_choice_cards)

func _setup_character_menu(ui_layer: CanvasLayer) -> void:
	character_menu_panel = PlayerCharacterMenu.new()
	character_menu_panel.setup(_toggle_character_menu)
	ui_layer.add_child(character_menu_panel)

func _setup_action_buttons() -> void:
	move_button = Button.new()
	move_button.name = "MoveButton"
	move_button.pressed.connect(_select_action.bind("movement"))
	interact_button.pressed.connect(_select_action.bind("attack"))
	special_button.pressed.connect(_select_action.bind("special"))
	defend_button = Button.new()
	defend_button.name = "DefendButton"
	defend_button.pressed.connect(_defend)
	end_turn_button = Button.new()
	end_turn_button.name = "EndTurnButton"
	end_turn_button.pressed.connect(_end_player_turn)
	cancel_action_button = Button.new()
	cancel_action_button.name = "CancelActionButton"
	cancel_action_button.pressed.connect(_cancel_selected_action)
	_configure_action_button(move_button, "move", "Movement", ICON_MOVE, "Use your class movement ability.")
	_configure_action_button(interact_button, "attack", "Attack", ICON_ATTACK, "Target an enemy with your basic attack.")
	_configure_action_button(special_button, "special", "Special", ICON_SPECIAL, "Spend class resource on your special ability.")
	_configure_action_button(potion_button, "potion", "Consumables", ICON_POTION, "Choose a held consumable to use as your action.")
	_configure_action_button(defend_button, "defend", "Defensive", ICON_DEFEND, "Arm your class reaction until your next turn.")
	_configure_action_button(end_turn_button, "end", "End", ICON_END_TURN, "Pass to the next actor.")
	_configure_action_button(cancel_action_button, "cancel", "Cancel", ICON_MODE, "Cancel targeting without spending your action.")
	for button: Button in _action_buttons():
		_reparent_to_actions_grid(button)
	_style_action_buttons()

func _configure_action_button(button: Button, action_id: String, label: String, icon: Texture2D, tooltip: String) -> void:
	var hotkey: String = String(ACTION_HOTKEYS.get(action_id, ""))
	button.text = "%s %s" % [hotkey, label]
	button.icon = icon
	button.tooltip_text = "%s (%s)" % [tooltip, hotkey]
	button.expand_icon = false
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_constant_override("icon_max_width", 22)
	button.add_theme_constant_override("icon_separation", 4)
	if action_id in ["move", "attack", "special"]:
		button.mouse_entered.connect(_preview_action_range.bind("movement" if action_id == "move" else action_id))
		button.mouse_exited.connect(_clear_action_range_preview)

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
	if _current_floor() >= _max_floors():
		_build_boss_chamber()
	else:
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
	_place_dungeon_merchant()
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
	progression_log_buffer.clear()
	combat_log_entries.clear()
	_hide_combat_log()
	initiative_order.clear()
	enemy_id_counter = 1
	combat_started = false
	free_roam_started = false
	floor_clear_xp_awarded = false
	is_player_turn = false
	is_resolving_enemy_turn = false
	selected_action = "move"
	has_used_action = false
	is_defending = false
	armed_reaction = ""
	empowered = false
	is_hidden = false
	retribution_armed = false
	retribution_stored = 0
	marked_enemy_id = -1
	companion.clear()
	player_attack_count = 0
	player_spell_count_floor = 0
	incoming_hit_count = 0
	tiles_moved_this_turn = 0
	last_target_id = -1
	studied_target_ids.clear()
	item_limits_used.clear()
	next_attack_item_bonuses.clear()
	temporary_aegis = 0
	stored_spell_damage = 0
	last_player_hit_round = -1
	was_below_half_health = false
	seen_enemy_types.clear()
	dungeon_merchant.clear()
	movement_remaining = PLAYER_MOVE_ALLOWANCE
	round_number = 1
	current_actor_index = 0
	chest = {"pos": Vector2i(-1, -1), "opened": false}
	secret = {"pos": Vector2i(-1, -1), "found": false}
	boss_chamber_name = ""

func _build_boss_chamber() -> void:
	var chamber_value: Variant = BOSS_CHAMBERS[rng.randi_range(0, BOSS_CHAMBERS.size() - 1)]
	var chamber: Dictionary = chamber_value if chamber_value is Dictionary else {}
	layout_type = "boss_%s" % String(chamber["id"])
	boss_chamber_name = String(chamber["name"])
	message = _floor_intro_message()
	secret = {"pos": Vector2i(-1, -1), "found": true}
	_carve_boss_chamber(chamber)
	_mark_boss_critical_path()
	_build_boss_room_graph()

func _carve_boss_chamber(chamber: Dictionary) -> void:
	var rows: Array = chamber["rows"]
	for y in range(mini(rows.size(), grid_h)):
		var row: String = String(rows[y])
		for x in range(mini(row.length(), grid_w)):
			var symbol: String = row.substr(x, 1)
			if symbol == "#":
				continue
			var tile := Vector2i(x, y)
			floor_cells[tile] = true
			_apply_boss_chamber_symbol(symbol, tile)

func _apply_boss_chamber_symbol(symbol: String, tile: Vector2i) -> void:
	match symbol:
		"S":
			player_pos = tile
		"E":
			exit_pos = tile
		"B":
			_add_boss_enemy(tile)
		"W":
			_add_floor_enemy(tile, "normal_wolf")
		"L":
			_add_floor_enemy(tile, "elite_wolf")
		"O":
			_add_floor_enemy(tile, "blood_wolf")
		"D":
			_add_floor_enemy(tile, "kobold")
		"C":
			chest = {"pos": tile, "opened": false}
		"R":
			props.append({"kind": "rock", "pos": tile, "hp": GameBalance.get_prop_hp("rock", 1)})
		"A":
			props.append({"kind": "barrel", "pos": tile, "hp": GameBalance.get_prop_hp("barrel", 1)})
		"F":
			props.append({"kind": "campfire", "pos": tile, "hp": GameBalance.get_prop_hp("campfire", 99)})
		"T":
			traps.append({"pos": tile, "sprung": false})
		"G":
			loot.append({"kind": "gold", "pos": tile, "amount": 18})
		"P":
			loot.append({"kind": "potion", "pos": tile, "amount": 1})
		"K":
			loot.append({"kind": "key", "pos": tile, "amount": 1})

func _add_floor_enemy(tile: Vector2i, enemy_type: String) -> void:
	var max_health: int = _enemy_max_health(enemy_type)
	var damage: int = _enemy_damage(enemy_type)
	_add_enemy(tile, enemy_type, max_health, damage, enemy_type == "elite_wolf", false)

func _add_boss_enemy(tile: Vector2i) -> void:
	if dungeon_id == "crypt":
		var crypt_max_health: int = int(GameBalance.get_enemy_value("crypt_boss", "health", 32))
		_add_enemy(tile, "crypt_boss", crypt_max_health, int(GameBalance.get_enemy_value("crypt_boss", "damage", 6)), true, true)
		return
	var max_health: int = int(GameBalance.get_enemy_value("boss_wolf", "health", 16))
	_add_enemy(tile, "boss_wolf", max_health, int(GameBalance.get_enemy_value("boss_wolf", "damage", 5)), true, true)

func _add_enemy(tile: Vector2i, enemy_type: String, max_health: int, damage: int, elite: bool, boss: bool) -> void:
	enemies.append({
		"id": enemy_id_counter,
		"kind": _enemy_kind_for_type(enemy_type),
		"enemy_type": enemy_type,
		"pos": tile,
		"hp": max_health,
		"max_health": max_health,
		"damage": damage,
		"elite": elite,
		"boss": boss,
	})
	enemy_id_counter += 1

func _enemy_kind_for_type(enemy_type: String) -> String:
	match enemy_type:
		"kobold":
			return "kobold"
		"skeleton", "armored_skeleton":
			return "skeleton"
		"ghoul":
			return "ghoul"
		"necromancer":
			return "necromancer"
		"crypt_boss":
			return "boss"
	return "wolf"

func _enemy_max_health(enemy_type: String) -> int:
	if enemy_type == "elite_wolf":
		return _enemy_max_health("normal_wolf") + int(GameBalance.get_enemy_value("elite_wolf", "add_health", 3))
	var base_health: int = int(GameBalance.get_enemy_value(enemy_type, "base_health", 4))
	var health_per_floor: float = float(GameBalance.get_enemy_value(enemy_type, "health_per_floor", 0.75))
	return base_health + int(floori(float(_current_floor() - 1) * health_per_floor))

func _enemy_damage(enemy_type: String) -> int:
	if enemy_type == "elite_wolf":
		return _enemy_damage("normal_wolf") + int(GameBalance.get_enemy_value("elite_wolf", "add_damage", 1))
	if _current_floor() >= 4:
		return int(GameBalance.get_enemy_value(enemy_type, "damage_from_floor_4", 3))
	return int(GameBalance.get_enemy_value(enemy_type, "damage_before_floor", 2))

func _mark_boss_critical_path() -> void:
	var path: Array[Vector2i] = _find_path_through_floor(player_pos, exit_pos)
	for tile in path:
		critical_path[tile] = true
	if path.is_empty():
		for tile in floor_cells.keys():
			critical_path[Vector2i(tile)] = true

func _build_boss_room_graph() -> void:
	room_graph = [
		{"id": 0, "center": player_pos, "radius": Vector2i(1, 1), "neighbors": [1], "role": "start"},
		{"id": 1, "center": Vector2i(8, 5), "radius": Vector2i(4, 3), "neighbors": [0, 2], "role": "elite"},
		{"id": 2, "center": exit_pos, "radius": Vector2i(1, 1), "neighbors": [1], "role": "exit"},
	]
	critical_room_ids = [0, 1, 2]

func _choose_layout_type() -> String:
	var floor_num := _current_floor()
	if floor_num <= 1:
		return "linear"
	if floor_num == 2:
		var floor_two_layouts: Array[String] = ["linear", "branching"]
		return floor_two_layouts[rng.randi_range(0, floor_two_layouts.size() - 1)]
	if floor_num == 3:
		var floor_three_layouts: Array[String] = ["branching", "hub"]
		return floor_three_layouts[rng.randi_range(0, floor_three_layouts.size() - 1)]
	if floor_num == 4:
		var floor_four_layouts: Array[String] = ["hub", "loop"]
		return floor_four_layouts[rng.randi_range(0, floor_four_layouts.size() - 1)]
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
	var x_step: int = 1 if b.x >= a.x else -1
	for x in range(a.x, b.x + x_step, x_step):
		var tile := Vector2i(x, a.y)
		floor_cells[tile] = true
		if is_critical:
			critical_path[tile] = true
	var y_step: int = 1 if b.y >= a.y else -1
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
		props.append({"kind": kind, "pos": _pick_floor_cell(false), "hp": GameBalance.get_prop_hp(kind, 2 if kind != "campfire" else 99)})

func _place_dungeon_merchant() -> void:
	dungeon_merchant = {"id": dungeon_id, "pos": _pick_floor_cell(true)}

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
		var trap_pos: Vector2i = _pick_role_cell("trap", true) if i == 0 else _pick_floor_cell(true)
		traps.append({"pos": trap_pos, "sprung": false})

func _place_enemies() -> void:
	var count := mini(3 + _current_floor(), 7)
	for i in range(count):
		var elite: bool = i == 0 and (_current_floor() >= 4 or layout_type == "arena")
		var spawn_pos: Vector2i = _pick_role_cell("elite", false) if elite else _pick_floor_cell(true)
		var enemy_type: String = "elite_wolf" if elite else _enemy_type_for_spawn(i)
		_add_floor_enemy(spawn_pos, enemy_type)

func _enemy_type_for_spawn(spawn_index: int) -> String:
	var floor_num: int = _current_floor()
	if floor_num <= 1:
		return "normal_wolf"
	if floor_num == 2:
		return "kobold" if spawn_index % 3 == 1 else "normal_wolf"
	if floor_num == 3:
		return "kobold" if spawn_index % 2 == 0 else "normal_wolf"
	if floor_num == 4:
		if spawn_index % 3 == 0:
			return "blood_wolf"
		return "kobold" if spawn_index % 3 == 1 else "normal_wolf"
	if spawn_index % 2 == 0:
		return "blood_wolf"
	return "kobold" if spawn_index % 3 == 0 else "normal_wolf"

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
			var tile := Vector2i(rng.randi_range(0, grid_w - 1), rng.randi_range(0, grid_h - 1))
			if floor_cells.has(tile) or _decoration_at(tile) or not _has_floor_neighbor(tile):
				continue
			_add_decoration(edge_kinds[rng.randi_range(0, edge_kinds.size() - 1)], tile, Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-6.0, 8.0)))
			break

func _add_decoration(kind: String, tile: Vector2i, offset: Vector2) -> void:
	decorations.append({"kind": kind, "pos": tile, "offset": offset})

func _place_border_decorations(edge_kinds: Array[String]) -> void:
	for y in range(grid_h):
		for x in range(grid_w):
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
	var player_modifier: int = _player_initiative_modifier()
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
		var modifier: int = _enemy_initiative_modifier(enemy)
		var roll := rng.randi_range(1, 20)
		initiative_order.append({
			"kind": "enemy",
			"id": int(enemy["id"]),
			"name": _enemy_display_name(enemy),
			"roll": roll,
			"modifier": modifier,
			"initiative": roll + modifier,
			"tie": 0,
			"spawn": i,
		})
	initiative_order.sort_custom(_sort_initiative)
	combat_started = true
	message = "%s\nInitiative: %s" % [_floor_intro_message(), _initiative_roll_summary()]
	if _open_pending_progression_choice_if_needed():
		return
	if _should_offer_starter_reward():
		_offer_starter_reward()
		return
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
	armed_reaction = ""
	if retribution_armed:
		_release_retribution()
	selected_action = "move"
	has_used_action = false
	bonus_actions_remaining = 0
	movement_remaining = _player_move_allowance()
	tiles_moved_this_turn = 0
	if round_number == 1:
		message = "Initiative: %s\nRound %d: Your turn. Dash up to %d tiles, then choose an action." % [_initiative_roll_summary(), round_number, movement_remaining]
	else:
		message = "Round %d: Your turn. Dash up to %d tiles, then choose an action." % [round_number, movement_remaining]
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
	var current_actor: Dictionary = {}
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
	var xp_logs: Array[String] = _award_floor_clear_xp()
	var logs: Array[String] = _consume_progression_logs()
	logs.append_array(xp_logs)
	var clear_message: String = "The last enemy falls. The path is clear, and you can explore freely."
	if not message.is_empty():
		clear_message = "%s\nThe path is clear, and you can explore freely." % message
	message = _append_log_lines(clear_message, logs)
	_refresh_ui()
	_open_pending_progression_choice_if_needed()
	return true

func _player_initiative_index() -> int:
	for i in range(initiative_order.size()):
		var actor: Dictionary = initiative_order[i]
		if String(actor["kind"]) == "player":
			return i
	return 0

func _prune_initiative_order() -> void:
	var active_enemy_ids: Dictionary = {}
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
		if _is_blocking_modal_open():
			_hide_hover_context()
			return
		_update_hover_context(event.position)

func _unhandled_input(event: InputEvent) -> void:
	if consumables_backdrop != null and consumables_backdrop.visible and event.is_action_pressed("ui_cancel"):
		_close_consumables()
		return
	if consumables_backdrop != null and consumables_backdrop.visible:
		return
	if combat_log_backdrop != null and combat_log_backdrop.visible and event.is_action_pressed("ui_cancel"):
		_hide_combat_log()
		return
	if combat_log_backdrop != null and combat_log_backdrop.visible:
		return
	if event.is_action_pressed("character_menu"):
		_toggle_character_menu()
		return
	if event.is_action_pressed("ui_cancel") and selected_action in ["attack", "special", "movement"]:
		_cancel_selected_action()
		return
	if _is_blocking_modal_open():
		return
	if not is_player_turn or is_resolving_enemy_turn:
		return
	if _handle_combat_hotkey(event):
		return
	if event.is_action_pressed("special"):
		_select_action("special")
	elif event.is_action_pressed("interact"):
		_select_action("attack")
	elif event.is_action_pressed("drink_potion"):
		_open_consumables()
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
		var tile: Vector2i = _screen_to_grid(_viewport_to_world(event.position))
		if _is_inside_grid(tile):
			_hide_hover_context()
			_handle_tile_click(tile)

func _handle_combat_hotkey(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return false
	match key_event.keycode:
		KEY_1:
			if not _can_trigger_action_button(move_button):
				return _reject_combat_hotkey()
			_select_action("movement")
			return true
		KEY_2:
			if not _can_trigger_action_button(interact_button):
				return _reject_combat_hotkey()
			_select_action("attack")
			return true
		KEY_3:
			if not _can_trigger_action_button(special_button):
				return _reject_combat_hotkey()
			_select_action("special")
			return true
		KEY_4:
			if not _can_trigger_action_button(potion_button):
				return _reject_combat_hotkey()
			_open_consumables()
			return true
		KEY_5:
			if not _can_trigger_action_button(defend_button):
				return _reject_combat_hotkey()
			_defend()
			return true
		KEY_ENTER, KEY_KP_ENTER:
			if not _can_trigger_action_button(end_turn_button):
				return _reject_combat_hotkey()
			_end_player_turn()
			return true
	return false

func _can_trigger_action_button(button: Button) -> bool:
	return button != null and not button.disabled

func _reject_combat_hotkey() -> bool:
	message = "That action is not available right now."
	_refresh_ui()
	return true

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
		"movement":
			_try_class_movement(tile)
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
	if _has_closed_chest() and tile == chest["pos"]:
		message = "The chest blocks the way. Use Interact from its menu while adjacent."
		_refresh_ui()
		return
	if not dungeon_merchant.is_empty() and tile == Vector2i(dungeon_merchant["pos"]):
		message = "The merchant's stall blocks the path. Open their shop from the context menu."
		_refresh_ui()
		return
	if not _is_walkable(tile):
		message = "Dense trees block the way."
		_refresh_ui()
		return
	var max_steps: int = FREE_ROAM_MOVE_ALLOWANCE if _is_free_roam() else movement_remaining
	var path := _find_path(player_pos, tile, max_steps)
	if path.is_empty():
		message = "That is beyond your remaining movement."
		_refresh_ui()
		return
	if path.size() > 1:
		facing = path[1] - player_pos
	tiles_moved_this_turn += maxi(0, path.size() - 1)
	player_pos = tile
	if _is_free_roam():
		movement_remaining = FREE_ROAM_MOVE_ALLOWANCE
		message = "You move through the cleared forest."
	else:
		movement_remaining -= maxi(0, path.size() - 1)
		message = "You dash. %d dash movement remaining." % movement_remaining
	_resolve_tile()
	if run_state.current_health <= 0:
		_die()
		return
	if player_pos == exit_pos:
		_complete_floor()
		return
	_refresh_ui()
	_finish_turn_if_exhausted()

func _try_context_interaction(tile: Vector2i) -> bool:
	if not dungeon_merchant.is_empty() and tile == Vector2i(dungeon_merchant["pos"]):
		_open_dungeon_shop()
		return true
	if has_used_action and not _is_free_roam():
		return false
	if _prop_at(tile) != -1:
		var prop_index: int = _prop_at(tile)
		var prop_kind: String = String(props[prop_index]["kind"])
		match prop_kind:
			"campfire":
				_use_campfire()
			"npc":
				message = "They nod, but have nothing more to say yet."
			_:
				message = "You inspect the %s. It blocks the path; attack it to clear the way." % prop_kind
		_finish_player_action()
		return true
	if _has_closed_chest() and tile == chest["pos"]:
		var opened_choices: bool = _open_chest()
		if opened_choices:
			if not _is_free_roam():
				has_used_action = true
			_refresh_ui()
		else:
			_finish_player_action()
		return true
	if tile == exit_pos:
		_complete_floor()
		return true
	if _distance(player_pos, secret["pos"]) <= 1 and not secret["found"]:
		secret["found"] = true
		run_state.gold += 9
		var stored_potion := run_state.add_consumable("healing_potion")
		message = "You brush aside leaves and find a hidden cache: 9 gold%s." % (" and a Healing Potion" if stored_potion else "; the potion is left behind because your slots are full")
		_finish_player_action()
		return true
	return false

func _update_hover_context(screen_pos: Vector2) -> void:
	if hover_panel == null:
		return
	if hover_panel.visible and hover_panel.get_global_rect().has_point(screen_pos):
		return
	var tile: Vector2i = _screen_to_grid(_viewport_to_world(screen_pos))
	if not _is_inside_grid(tile):
		_hide_hover_context()
		return
	var object: Dictionary = _object_at_tile(tile)
	if not object.is_empty() and tile != hovered_tile:
		hovered_tile = tile
		hovered_object = object
		_sync_hover_context(tile, object)
		return
	if object.is_empty():
		_hide_hover_context()
		return
	if hover_panel.visible and hovered_tile == tile:
		return
	hovered_tile = tile
	hovered_object = object
	_sync_hover_context(tile, object)

func _hide_hover_context() -> void:
	if hover_panel != null:
		hover_panel.visible = false
	hovered_tile = Vector2i(-999, -999)
	hovered_object = {}

func _sync_hover_context(tile: Vector2i, object: Dictionary) -> void:
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
	hover_panel.position = _hover_panel_position_for_tile(tile)
	hover_panel.visible = true

func _hover_panel_position_for_tile(tile: Vector2i) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_size: Vector2 = Vector2(320, 150)
	var position: Vector2 = _grid_to_viewport_screen(tile) + Vector2(tile_size, -8)
	position.x = minf(position.x, viewport_size.x - panel_size.x - 12.0)
	position.y = minf(position.y, viewport_size.y - panel_size.y - 12.0)
	position.x = maxf(12.0, position.x)
	position.y = maxf(12.0, position.y)
	return position

func _style_context_button(button: Button) -> void:
	_apply_flat_ui_button(button, 12, Vector2(84, 34))
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
			actions.append({"id": "attack_object", "label": "Attack", "enabled": adjacent and _can_use_player_controls() and not has_used_action and _is_destructible_prop_at(tile), "tooltip": "Move next to it first." if not adjacent else "Strike this obstacle."})
		"npc":
			actions.append({"id": "interact", "label": "Talk", "enabled": adjacent and _can_use_player_controls(), "tooltip": "Move next to them first." if not adjacent else "Start a conversation."})
		"merchant":
			actions.append({"id": "interact", "label": "Shop", "enabled": adjacent and _can_use_player_controls(), "tooltip": "Move next to the stall first." if not adjacent else "Browse this merchant's stock."})
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
		if _apply_loot_item(item):
			loot.erase(item)
		_refresh_ui()
		return
	message = "There is nothing to pick up there."
	_refresh_ui()

func _apply_loot_item(item: Dictionary) -> bool:
	match String(item["kind"]):
		"gold":
			var amount := int(item["amount"])
			run_state.gold += amount
			if amount >= 10:
				_apply_item_trigger("large_gold_pickup", {"amount": amount})
			message = "Picked up %d gold." % amount
		"potion":
			if run_state.add_consumable("healing_potion"):
				message = "Picked up a Healing Potion."
			else:
				message = "Your Consumables slots are full."
				return false
		"key":
			run_state.keys += 1
			message = "Picked up a key."
	return true

func _object_at_tile(tile: Vector2i) -> Dictionary:
	var enemy_index: int = _enemy_at(tile)
	if enemy_index != -1:
		var enemy: Dictionary = enemies[enemy_index]
		var enemy_name: String = _enemy_display_name(enemy)
		return {
			"kind": "enemy",
			"pos": tile,
			"title": enemy_name,
			"detail": "HP %d/%d. Blocks movement and acts in initiative." % [int(enemy["hp"]), int(enemy.get("max_health", enemy["hp"]))],
			"inspect": "%s watches your footing. HP %d/%d." % [enemy_name, int(enemy["hp"]), int(enemy.get("max_health", enemy["hp"]))],
		}
	if not dungeon_merchant.is_empty() and tile == Vector2i(dungeon_merchant["pos"]):
		var merchant := GameBalance.get_merchant(dungeon_id)
		return {
			"kind": "merchant",
			"pos": tile,
			"title": String(merchant.get("name", "Dungeon Merchant")),
			"detail": "%s. Gold %d; Favor %d." % [String(merchant.get("title", "Merchant")), run_state.gold, int(run_state.get_merchant_progress(dungeon_id).get("available_favor", 0))],
			"inspect": String(merchant.get("description", "A merchant waits beside a compact traveling stall.")),
		}
	if _has_closed_chest() and tile == Vector2i(chest["pos"]):
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
			title = "Healing Potion"
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
		if not _is_destructible_prop(prop_index):
			message = "That object is better used than broken."
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
	_execute_class_basic(tile, enemy_index)
	message = _append_log_lines(message, _consume_progression_logs())
	_finish_player_action()

func _try_player_special(tile: Vector2i) -> void:
	if has_used_action:
		message = "Your action is already spent."
		_refresh_ui()
		return
	var action := GameBalance.get_class_action(run_state.selected_class_id, "special")
	var cost := int(action.get("cost", 2))
	if run_state.class_resource < cost:
		message = "%s needs %d %s." % [String(action.get("name", "Special")), cost, run_state.get_class_resource_name()]
		_refresh_ui()
		return
	if _execute_class_special(tile):
		run_state.spend_class_resource(cost)

func _execute_class_basic(tile: Vector2i, enemy_index: int) -> void:
	var class_id := run_state.selected_class_id
	var damage := _player_gear_damage() + (1 if empowered else 0)
	_play_attack_effect(player_pos, tile)
	match class_id:
		"healer":
			var target_id := int(enemies[enemy_index].get("id", -1))
			_attack_enemy(enemy_index, maxi(1, damage - 1))
			var surviving_index := _enemy_index_by_id(target_id)
			if surviving_index != -1:
				enemies[surviving_index]["slowed"] = 2 if empowered else 1
			message = "Binding Light slows its target."
			run_state.gain_class_resource()
		"tank":
			_attack_enemy(enemy_index, damage)
			var pushed := _push_enemy_from(tile, facing, 1)
			if pushed:
				run_state.gain_class_resource()
			message = "Shield Bash staggers%s." % (" and pushes the target" if pushed else " the target")
		"phantom":
			_attack_enemy(enemy_index, damage)
			var behind := tile + facing
			var second := _enemy_at(behind)
			if second != -1:
				_attack_enemy(second, maxi(1, damage - 1))
				run_state.gain_class_resource()
			message = "Pierce slips through armor%s." % (" and the enemy behind" if second != -1 else "")
			is_hidden = false
		"summoner":
			marked_enemy_id = int(enemies[enemy_index].get("id", -1))
			if _companion_active():
				_companion_attack_marked()
			else:
				_attack_enemy(enemy_index, maxi(1, damage - 1))
				run_state.gain_class_resource()
			message = "The target is marked for your bonded wolf."
		"mage":
			_attack_enemy(enemy_index, damage)
			if _distance(player_pos, tile) >= 3:
				run_state.gain_class_resource()
			message = "Arcane Missile strikes across the battlefield."
		_:
			_attack_enemy(enemy_index, damage)
			run_state.gain_class_resource()
			message = "Slash builds Momentum."
	empowered = false

func _execute_class_special(tile: Vector2i) -> bool:
	match run_state.selected_class_id:
		"warrior":
			if tile != player_pos and _distance(player_pos, tile) > 1:
				message = "Cleave uses your current facing or an adjacent direction."
				_refresh_ui()
				return false
			if tile != player_pos:
				facing = _direction_to(tile)
			var side := Vector2i(-facing.y, facing.x)
			var hit := 0
			for target in [player_pos + facing, player_pos + facing + side, player_pos + facing - side]:
				var index := _enemy_at(target)
				if index != -1:
					_attack_enemy(index, _player_gear_damage() + (1 if empowered else 0))
					hit += 1
			message = "Cleave catches %d target%s." % [hit, "" if hit == 1 else "s"]
		"mage":
			var cannon_range := 4 + run_state.get_derived_stat("range") + run_state.get_contextual_item_modifier("range", {"damage_type":"arcane","spell_attack":true,"area_attack":true})
			if not _is_straight_line_target(tile, cannon_range, true):
				message = "Arcane Cannon needs a direction within %d tiles." % cannon_range
				_refresh_ui()
				return false
			facing = _direction_to(tile)
			var hits := 0
			for step in range(1, cannon_range + 1):
				var target := player_pos + facing * step
				if not floor_cells.has(target): break
				_spawn_tile_effect(AETHER_HIT, target)
				var index := _enemy_at(target)
				if index != -1:
					_attack_enemy(index, _player_gear_damage() + 2 + (1 if empowered else 0))
					hits += 1
			message = "Arcane Cannon tears through %d target%s." % [hits, "" if hits == 1 else "s"]
		"healer":
			empowered = true
			message = "Empower charges your next Basic or Special."
		"tank":
			retribution_armed = true
			retribution_stored = 0
			message = "Retribution stores half of incoming damage."
		"phantom":
			var index := _enemy_at(tile)
			if index == -1 or _distance(player_pos, tile) != 1:
				message = "Assassinate requires an adjacent enemy."
				_refresh_ui()
				return false
			var enemy: Dictionary = enemies[index]
			var isolated := _adjacent_enemy_count(tile) <= 1
			var low := int(enemy["hp"]) * 2 <= int(enemy["max_health"])
			var bonus := 3 if isolated or low or is_hidden else 0
			_attack_enemy(index, _player_gear_damage() + 3 + bonus)
			is_hidden = false
			message = "Assassinate exploits a fatal opening."
		"summoner":
			if not _companion_active():
				if _distance(player_pos, tile) > 1 or not _is_walkable(tile):
					message = "Summon the wolf onto an adjacent open tile."
					_refresh_ui()
					return false
				companion = {"pos": tile, "hp": 8, "max_health": 8}
				message = "Your bonded wolf answers the call."
			else:
				if not _companion_attack_marked(true):
					message = "Mark a living target before ordering Pounce."
					_refresh_ui()
					return false
				message = "The bonded wolf pounces on the marked target."
		_:
			return false
	empowered = false
	_finish_player_action()
	return true

func _try_class_movement(tile: Vector2i) -> void:
	if has_used_action:
		message = "Your action is already spent."
		_refresh_ui()
		return
	var distance := _distance(player_pos, tile)
	var movement_origin := player_pos
	var movement_range_bonus := run_state.get_contextual_item_modifier("range", {"movement_ability":true})
	match run_state.selected_class_id:
		"warrior":
			_special_charge_at(tile)
			return
		"mage":
			if distance < 1 or distance > 3 + movement_range_bonus or not _is_walkable(tile):
				message = "Blink needs an open destination within three tiles."
				_refresh_ui(); return
			player_pos = tile
			message = "You Blink through intervening terrain."
		"healer":
			if distance < 1 or distance > 3 + movement_range_bonus or _find_path(player_pos, tile, 3 + movement_range_bonus).is_empty():
				message = "Dash needs a reachable tile within three steps."
				_refresh_ui(); return
			player_pos = tile
			if distance >= 2: run_state.heal(2)
			message = "You Dash and recover vitality."
		"tank":
			if distance < 1 or distance > 3 + movement_range_bonus or not _is_walkable(tile):
				message = "Leap needs an open landing tile within three spaces."
				_refresh_ui(); return
			player_pos = tile
			for i in range(enemies.size() - 1, -1, -1):
				if _distance(player_pos, enemies[i]["pos"]) == 1:
					enemies[i]["taunted"] = 1
					_attack_enemy(i, maxi(1, _player_gear_damage() - 1))
			message = "You Leap into the fray and taunt nearby foes."
		"phantom":
			if distance < 2 or distance > 3 + movement_range_bonus or not _is_walkable(tile):
				message = "Shadowstep needs an open destination two or three spaces away."
				_refresh_ui(); return
			player_pos = tile
			is_hidden = true
			message = "You emerge Hidden from a Shadowstep."
		"summoner":
			if not _companion_active() or distance < 1 or distance > 5 + movement_range_bonus or not _is_walkable(tile):
				message = "Mount needs your wolf and an open destination within five spaces."
				_refresh_ui(); return
			var old := player_pos
			player_pos = tile
			companion["pos"] = old if _is_walkable(old) else _nearest_open_tile(player_pos)
			message = "You Mount and sprint with your bonded wolf."
	_resolve_tile()
	tiles_moved_this_turn += _distance(movement_origin, player_pos)
	_apply_item_trigger("land_unengaged", {"adjacent_enemies": _adjacent_enemy_count(player_pos)})
	_finish_player_action()

func _select_action(action: String) -> void:
	if not is_player_turn:
		return
	if has_used_action and action != "move":
		message = "Your action is already spent."
	else:
		selected_action = action
		message = "Choose a %s target." % action
	_refresh_ui()

func _cancel_selected_action() -> void:
	if selected_action not in ["attack", "special", "movement"]:
		return
	selected_action = "move"
	hovered_action_preview = ""
	message = "Targeting cancelled. Your action is still available."
	_refresh_ui()

func _preview_action_range(action: String) -> void:
	if not is_player_turn or has_used_action:
		return
	hovered_action_preview = action
	_sync_board_nodes()

func _clear_action_range_preview() -> void:
	if hovered_action_preview.is_empty():
		return
	hovered_action_preview = ""
	_sync_board_nodes()

func _dash() -> void:
	if not is_player_turn:
		return
	if _is_free_roam():
		selected_action = "move"
		message = "You move freely through the cleared area."
		_refresh_ui()
		return
	if has_used_action:
		message = "Your action is already spent."
		_refresh_ui()
		return
	var dash_gain: int = _player_move_allowance()
	movement_remaining += dash_gain
	has_used_action = true
	selected_action = "move"
	message = "You Dash, gaining %d extra movement. %d movement remaining." % [dash_gain, movement_remaining]
	_refresh_ui()

func _defend() -> void:
	if not is_player_turn:
		return
	if has_used_action:
		message = "Your action is already spent."
		_refresh_ui()
		return
	is_defending = true
	armed_reaction = String(GameBalance.get_class_action(run_state.selected_class_id, "defensive").get("id", ""))
	message = "%s is armed until your next turn." % String(GameBalance.get_class_action(run_state.selected_class_id, "defensive").get("name", "Defense"))
	_finish_player_action()

func _finish_player_action() -> void:
	has_used_action = true
	selected_action = "move"
	if bonus_actions_remaining > 0:
		bonus_actions_remaining -= 1
		has_used_action = false
	if _enter_free_roam_if_clear():
		_open_pending_progression_choice_if_needed()
		return
	if _open_pending_progression_choice_if_needed():
		return
	if _is_free_roam():
		has_used_action = false
		selected_action = "move"
		_refresh_ui()
		return
	_refresh_ui()
	_finish_turn_if_exhausted()

func _finish_turn_if_exhausted() -> void:
	if is_player_turn and not _is_free_roam() and has_used_action and movement_remaining <= 0:
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
	if _has_closed_chest() and _distance(player_pos, chest["pos"]) == 1:
		var opened_choices: bool = _open_chest()
		if opened_choices:
			if not _is_free_roam():
				has_used_action = true
			_refresh_ui()
		else:
			_finish_player_action()
		return
	if _distance(player_pos, secret["pos"]) <= 1 and not secret["found"]:
		secret["found"] = true
		run_state.gold += 9
		var stored_potion := run_state.add_consumable("healing_potion")
		message = "You brush aside leaves and find a hidden cache: 9 gold%s." % (" and a Healing Potion" if stored_potion else "; the potion is left behind because your slots are full")
		_finish_player_action()
		return
	for i in range(props.size()):
		if _distance(player_pos, props[i]["pos"]) == 1:
			if props[i]["kind"] == "campfire":
				_use_campfire()
			else:
				_hit_prop(i)
			_finish_player_action()
			return
	message = "You find bark, moss, and nothing willing to confess."
	_refresh_ui()

func _use_special() -> void:
	_select_action("special")

func _special_charge_at(tile: Vector2i) -> void:
	var charge_range: int = 3 + _fighter_progression_value("charge_range_bonus")
	if not _is_straight_line_target(tile, charge_range):
		message = "Charge needs a straight path up to %d tiles." % charge_range
		_refresh_ui()
		return
	var direction := _direction_to(tile)
	facing = direction
	var cursor := player_pos
	var charge_damage: int = _player_gear_damage() + 1 + _fighter_progression_value("charge_damage_bonus")
	for step in range(charge_range):
		cursor += direction
		if not floor_cells.has(cursor):
			break
		var enemy_index: int = _enemy_at(cursor)
		if enemy_index != -1:
			_play_attack_effect(player_pos, cursor)
			_attack_enemy(enemy_index, charge_damage)
			message = "You charge through the brush and crash into an enemy."
			message = _append_log_lines(message, _consume_progression_logs())
			_finish_player_action()
			return
		var prop_index: int = _prop_at(cursor)
		if prop_index != -1:
			if _is_destructible_prop(prop_index):
				_play_attack_effect(player_pos, cursor)
				_damage_prop(prop_index, charge_damage)
				message = "You charge forward and splinter the obstacle."
			else:
				message = "Your charge stops short at the object."
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
	var prop_index: int = _prop_at(tile)
	var blast_range: int = 4 + _mage_progression_value("force_blast_range_bonus")
	if not _is_straight_line_target(tile, blast_range, true) or (enemy_index == -1 and not _is_destructible_prop(prop_index)) or not _has_clear_line(player_pos, tile, true):
		message = "Force Blast needs a visible target in a straight line."
		_refresh_ui()
		return
	facing = _direction_to(tile)
	var blast_origin: Vector2i = tile
	_play_projectile_effect(AETHER_HIT, player_pos, blast_origin)
	if enemy_index != -1:
		_attack_enemy(enemy_index, _player_gear_damage() + 2)
	else:
		_damage_prop(prop_index, _player_gear_damage() + 2)
	var pushed := false
	if enemy_index != -1:
		pushed = _push_enemy_from(blast_origin, facing, 2 + _mage_progression_value("force_blast_push_bonus"))
	var splash_hits := 0
	var splash_radius: int = 1 + _mage_progression_value("force_blast_splash_radius_bonus")
	var splash_damage: int = maxi(1, _player_damage_bonus() + _mage_progression_value("force_blast_splash_bonus"))
	for i in range(enemies.size() - 1, -1, -1):
		if _distance(enemies[i]["pos"], blast_origin) <= splash_radius:
			_attack_enemy(i, splash_damage)
			splash_hits += 1
	for i in range(props.size() - 1, -1, -1):
		if _distance(props[i]["pos"], blast_origin) <= splash_radius and _is_destructible_prop(i):
			_spawn_tile_effect(AETHER_HIT, props[i]["pos"])
			_damage_prop(i, splash_damage, false)
			splash_hits += 1
	var push_note: String = ", pushing a foe back" if pushed else ""
	var splash_note := ""
	if splash_hits > 0:
		splash_note = " and splashing %d nearby target%s" % [splash_hits, "" if splash_hits == 1 else "s"]
	message = "Force Blast slams forward%s%s." % [push_note, splash_note]
	message = _append_log_lines(message, _consume_progression_logs())
	_finish_player_action()

func _special_flamethrower_at(tile: Vector2i) -> void:
	var flame_range: int = 3 + _mage_progression_value("flamethrower_range_bonus")
	if not _is_straight_line_target(tile, flame_range, true):
		message = "Flamethrower needs a direction up to %d tiles." % flame_range
		_refresh_ui()
		return
	facing = _direction_to(tile)
	var hit_count := 0
	var flame_damage: int = _player_gear_damage() + _mage_progression_value("flamethrower_damage_bonus")
	for step in range(1, flame_range + 1):
		var target := player_pos + facing * step
		if not floor_cells.has(target):
			break
		_spawn_tile_effect(FIREBALL_IMPACT, target)
		var enemy_index: int = _enemy_at(target)
		if enemy_index != -1:
			_attack_enemy(enemy_index, flame_damage)
			hit_count += 1
		var prop_index: int = _prop_at(target)
		if _is_destructible_prop(prop_index):
			_damage_prop(prop_index, flame_damage, false)
			hit_count += 1
	if hit_count == 0:
		message = "Flamethrower scorches a bright line through empty brush."
	else:
		message = "Flamethrower burns %d target%s in a line." % [hit_count, "" if hit_count == 1 else "s"]
	message = _append_log_lines(message, _consume_progression_logs())
	_finish_player_action()

func _is_valid_basic_attack_target(tile: Vector2i, enemy_index: int) -> bool:
	if enemy_index == -1:
		return false
	var target_data: Dictionary = GameBalance.get_class_action(run_state.selected_class_id, "basic").get("targeting", {}) if run_state != null else {}
	if String(target_data.get("type", "enemy")) in ["line_of_sight_enemy", "enemy_or_tile"]:
		var range_limit := int(target_data.get("range", 1)) + run_state.get_derived_stat("range")
		return _line_distance(player_pos, tile) <= range_limit and _has_clear_line(player_pos, tile, true)
	return _distance(player_pos, tile) == 1

func _is_straight_line_target(tile: Vector2i, max_range: int, allow_diagonal: bool = false) -> bool:
	var distance := _line_distance(player_pos, tile)
	if distance < 1 or distance > max_range:
		return false
	if tile.x == player_pos.x or tile.y == player_pos.y:
		return true
	return allow_diagonal and abs(tile.x - player_pos.x) == abs(tile.y - player_pos.y)

func _has_clear_line(from_tile: Vector2i, to_tile: Vector2i, allow_target_enemy: bool) -> bool:
	var delta := to_tile - from_tile
	var steps := maxi(abs(delta.x), abs(delta.y))
	if steps <= 0:
		return false
	var visited: Dictionary = {}
	for step in range(1, steps):
		var cursor := from_tile + Vector2i(roundi(float(delta.x * step) / float(steps)), roundi(float(delta.y * step) / float(steps)))
		if visited.has(cursor):
			continue
		visited[cursor] = true
		if not floor_cells.has(cursor) or _prop_at(cursor) != -1 or _enemy_at(cursor) != -1:
			return false
	if allow_target_enemy:
		return floor_cells.has(to_tile)
	return _is_walkable(to_tile)

func _find_path(start: Vector2i, goal: Vector2i, max_steps: int) -> Array[Vector2i]:
	if start == goal:
		var same_tile_path: Array[Vector2i] = []
		same_tile_path.append(start)
		return same_tile_path
	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var distance_by_tile: Dictionary = {start: 0}
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

func _find_path_through_floor(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	if start == goal:
		var same_tile_path: Array[Vector2i] = []
		same_tile_path.append(start)
		return same_tile_path
	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var deltas: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for delta in deltas:
			var next: Vector2i = current + delta
			if came_from.has(next) or not floor_cells.has(next):
				continue
			came_from[next] = current
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
	var max_steps: int = FREE_ROAM_MOVE_ALLOWANCE if _is_free_roam() else movement_remaining
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
	for prop in props:
		var tile: Vector2i = prop["pos"]
		if _distance(player_pos, tile) == 1 and _is_destructible_prop_at(tile):
			tiles.append(tile)
	return tiles

func _basic_range_preview_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if run_state == null:
		return tiles
	var target_data: Dictionary = GameBalance.get_class_action(run_state.selected_class_id, "basic").get("targeting", {})
	var ranged := String(target_data.get("type", "enemy")) in ["line_of_sight_enemy", "enemy_or_tile"]
	var range_limit := int(target_data.get("range", 1)) + run_state.get_derived_stat("range") if ranged else 1
	for value in floor_cells.keys():
		var tile := Vector2i(value)
		if tile == player_pos:
			continue
		if ranged:
			if _line_distance(player_pos, tile) <= range_limit and _has_clear_line(player_pos, tile, true): tiles.append(tile)
		elif _distance(player_pos, tile) == 1:
			tiles.append(tile)
	return tiles

func _range_preview_tiles(action: String) -> Array[Vector2i]:
	match action:
		"attack": return _basic_range_preview_tiles()
		"special": return _special_range_preview_tiles()
		"movement": return _valid_class_movement_tiles()
	return []

func _special_range_preview_tiles() -> Array[Vector2i]:
	if run_state == null:
		return []
	if run_state.selected_class_id in ["healer", "tank"]:
		return []
	if run_state.selected_class_id == "warrior":
		var tiles: Array[Vector2i] = []
		for direction in _eight_directions():
			var tile := player_pos + direction
			if floor_cells.has(tile): tiles.append(tile)
		return tiles
	return _valid_special_tiles()

func _valid_special_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if run_state == null:
		return tiles
	match run_state.selected_class_id:
		"warrior", "healer", "tank":
			tiles.append(player_pos)
		"mage":
			var cannon_range := 4 + run_state.get_derived_stat("range") + run_state.get_contextual_item_modifier("range", {"damage_type":"arcane","spell_attack":true,"area_attack":true})
			for direction in _eight_directions():
				for step in range(1, cannon_range + 1):
					var tile := player_pos + direction * step
					if floor_cells.has(tile): tiles.append(tile)
		"phantom":
			for enemy in enemies:
				var tile: Vector2i = enemy["pos"]
				if _distance(player_pos, tile) == 1: tiles.append(tile)
		"summoner":
			if _companion_active():
				var index := _enemy_index_by_id(marked_enemy_id)
				if index != -1: tiles.append(Vector2i(enemies[index]["pos"]))
			else:
				for direction in _eight_directions():
					var tile := player_pos + direction
					if _is_walkable(tile): tiles.append(tile)
	return tiles

func _valid_class_movement_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var max_range := 3
	if run_state.selected_class_id == "summoner": max_range = 5
	max_range += run_state.get_contextual_item_modifier("range", {"movement_ability":true})
	for tile in floor_cells.keys():
		var target := Vector2i(tile)
		if target == player_pos or not _is_walkable(target): continue
		var distance := _distance(player_pos, target)
		if distance > max_range: continue
		if run_state.selected_class_id == "phantom" and distance < 2: continue
		if run_state.selected_class_id in ["mage", "tank", "phantom"] or not _find_path(player_pos, target, max_range).is_empty():
			tiles.append(target)
	return tiles

func _add_highlight_markers() -> void:
	if not is_player_turn:
		return
	if not hovered_action_preview.is_empty() and hovered_action_preview != selected_action:
		var preview_color := Color(0.72, 0.78, 0.92, 0.14)
		match hovered_action_preview:
			"attack": preview_color = Color(0.95, 0.34, 0.24, 0.14)
			"special": preview_color = Color(0.58, 0.38, 0.96, 0.14)
			"movement": preview_color = Color(0.24, 0.76, 0.86, 0.14)
		for preview_tile in _range_preview_tiles(hovered_action_preview):
			_add_highlight_marker(preview_tile, preview_color, "Preview")
		if selected_action == "move":
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
		"movement":
			tiles = _valid_class_movement_tiles()
			color = Color(0.18, 0.70, 0.82, 0.44)
		_:
			if _is_free_roam():
				return
			tiles = _valid_move_tiles()
	for tile in tiles:
		_add_highlight_marker(tile, color)

func _add_highlight_marker(tile: Vector2i, color: Color, prefix: String = "Highlight") -> void:
	var highlight: BoardPiece = _make_piece("%s_%d_%d" % [prefix, tile.x, tile.y], tile, "", color, BoardPiece.PieceShape.SQUARE)
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
	if selected_action == "move":
		return "Dash"
	return selected_action.capitalize()

func _active_actor_name() -> String:
	if initiative_order.is_empty() or current_actor_index >= initiative_order.size():
		return "None"
	return initiative_order[current_actor_index]["name"]

func _initiative_summary() -> String:
	var parts: Array[String] = []
	for i in range(initiative_order.size()):
		var actor: Dictionary = initiative_order[i]
		var prefix: String = ">" if i == current_actor_index else ""
		parts.append("%s%s:%d" % [prefix, actor["name"], int(actor["initiative"])])
	return " ".join(parts)

func _turn_status() -> String:
	if _is_free_roam():
		return "Exploration | Area Clear"
	if is_player_turn:
		return "Round %d | Active: You | Mode: %s | Dash: %d" % [round_number, _action_name(), movement_remaining]
	return "Round %d | Active: %s" % [round_number, _active_actor_name()]

func _can_use_player_controls() -> bool:
	return is_player_turn and not is_resolving_enemy_turn

func _player_damage_bonus() -> int:
	if run_state == null:
		return 0
	if run_state.selected_class_id in ["mage", "healer", "summoner"]:
		return run_state.get_derived_stat("spell_potency")
	return run_state.get_derived_stat("attack_power")

func _player_gear_damage() -> int:
	if run_state == null or run_state.selected_gear == null:
		return 1
	return run_state.selected_gear.damage + _player_damage_bonus()

func _player_initiative_modifier() -> int:
	if run_state == null:
		return 1
	return run_state.get_derived_stat("initiative_modifier")

func _gear_block_limit() -> int:
	if run_state == null or run_state.selected_gear == null:
		return 0
	return run_state.selected_gear.block_limit + run_state.get_derived_stat("defense") + run_state.get_derived_stat("block_bonus")

func _player_move_allowance() -> int:
	if run_state == null:
		return PLAYER_MOVE_ALLOWANCE
	return PLAYER_MOVE_ALLOWANCE + run_state.get_derived_stat("movement")

func _mage_progression_value(flag_id: String) -> int:
	if run_state == null or run_state.selected_class_id != "mage":
		return 0
	return run_state.get_progression_flag_value(flag_id)

func _fighter_progression_value(flag_id: String) -> int:
	if run_state == null or run_state.selected_class_id != "warrior":
		return 0
	return run_state.get_progression_flag_value(flag_id)

func _enemy_xp_reward(enemy: Dictionary) -> int:
	var base_reward: int = int(GameBalance.get_enemy_value(_enemy_type(enemy), "xp", 15))
	if run_state == null:
		return base_reward
	return run_state.apply_reward_bonus(base_reward, "xp")

func _enemy_gold_reward(enemy: Dictionary) -> int:
	var base_reward: int = int(GameBalance.get_enemy_value(_enemy_type(enemy), "gold", 3))
	if run_state == null:
		return base_reward
	return run_state.apply_reward_bonus(base_reward, "gold")

func _award_floor_clear_xp() -> Array[String]:
	if floor_clear_xp_awarded or run_state == null:
		return []
	floor_clear_xp_awarded = true
	var base_reward: int = int(GameBalance.get_combat_value(["xp", "floor_clear"], 40))
	var reward: int = run_state.apply_reward_bonus(base_reward, "xp")
	_apply_item_trigger("floor_clear")
	return run_state.gain_xp(reward, "%s %d cleared" % [dungeon_floor_label, _current_floor()])

func _consume_progression_logs() -> Array[String]:
	var logs: Array[String] = progression_log_buffer.duplicate()
	progression_log_buffer.clear()
	return logs

func _append_log_lines(base: String, lines: Array[String]) -> String:
	if lines.is_empty():
		return base
	return "%s\n%s" % [base, "\n".join(lines)]

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
		potion_button.disabled = run_state == null or run_state.get_consumables().is_empty()
		defend_button.disabled = true
		end_turn_button.disabled = true
		cancel_action_button.disabled = selected_action not in ["attack", "special", "movement"]
		return
	move_button.disabled = has_used_action
	interact_button.disabled = has_used_action
	var special_cost := int(GameBalance.get_class_action(run_state.selected_class_id, "special").get("cost", 2)) if run_state != null else 2
	special_button.disabled = has_used_action or run_state == null or run_state.class_resource < special_cost
	potion_button.disabled = has_used_action or run_state == null or run_state.get_consumables().is_empty()
	defend_button.disabled = has_used_action
	end_turn_button.disabled = false
	cancel_action_button.disabled = selected_action not in ["attack", "special", "movement"]

func _special_sweep() -> void:
	var hit_count := 0
	var sweep_range: int = 1 + _fighter_progression_value("sweep_reach_bonus")
	var sweep_damage: int = _player_gear_damage() + _fighter_progression_value("sweep_damage_bonus")
	for i in range(enemies.size() - 1, -1, -1):
		if _line_distance(player_pos, enemies[i]["pos"]) <= sweep_range:
			_spawn_tile_effect(AETHER_HIT, enemies[i]["pos"])
			_attack_enemy(i, sweep_damage)
			hit_count += 1
	for i in range(props.size() - 1, -1, -1):
		if _line_distance(player_pos, props[i]["pos"]) <= sweep_range and _is_destructible_prop(i):
			_spawn_tile_effect(AETHER_HIT, props[i]["pos"])
			_damage_prop(i, sweep_damage, false)
			hit_count += 1
	if hit_count == 0:
		message = "You sweep the greatsword through empty air."
	else:
		message = "Your greatsword sweep catches %d target%s." % [hit_count, "" if hit_count == 1 else "s"]
	message = _append_log_lines(message, _consume_progression_logs())
	_finish_player_action()

func _special_shockwave() -> void:
	var hit_count := 0
	var stun_turns: int = 1 + _mage_progression_value("shockwave_stun_bonus")
	var shock_damage: int = maxi(1, _player_damage_bonus() + _mage_progression_value("shockwave_damage_bonus"))
	_spawn_tile_effect(AETHER_HIT, player_pos)
	for i in range(enemies.size() - 1, -1, -1):
		if _distance(player_pos, enemies[i]["pos"]) == 1:
			enemies[i]["stunned"] = stun_turns
			_spawn_tile_effect(AETHER_HIT, enemies[i]["pos"])
			_attack_enemy(i, shock_damage)
			hit_count += 1
	for i in range(props.size() - 1, -1, -1):
		if _distance(player_pos, props[i]["pos"]) == 1 and _is_destructible_prop(i):
			_spawn_tile_effect(AETHER_HIT, props[i]["pos"])
			_damage_prop(i, shock_damage, false)
			hit_count += 1
	if hit_count == 0:
		message = "Shockwave cracks around you, but catches no one."
	else:
		message = "Shockwave hits %d adjacent target%s." % [hit_count, "" if hit_count == 1 else "s"]
	message = _append_log_lines(message, _consume_progression_logs())
	_finish_player_action()

func _drink_potion() -> void:
	_open_consumables()

func _attack_enemy(index: int, damage: int, damage_type: String = "", action_slot_override: String = "") -> void:
	if index < 0 or index >= enemies.size():
		return
	var enemy: Dictionary = enemies[index]
	damage *= next_consumable_damage_multiplier
	next_consumable_damage_multiplier = 1
	var enemy_type := _enemy_type(enemy)
	var target_id := int(enemy.get("id", -1))
	var resolved_type := _player_damage_type() if damage_type.is_empty() else damage_type
	var spell_attack := run_state.selected_class_id in ["mage", "healer", "summoner"]
	var context := {
		"attack_index": player_attack_count,
		"spell_index_floor": player_spell_count_floor,
		"damage_type": resolved_type,
		"spell_attack": spell_attack,
		"area_attack": selected_action == "special",
		"distance": _distance(player_pos, Vector2i(enemy["pos"])),
		"moved": tiles_moved_this_turn > 0,
		"tiles_moved": tiles_moved_this_turn,
		"isolated_target": _adjacent_enemy_count(Vector2i(enemy["pos"])) <= 1,
		"elite_target": bool(enemy.get("elite", false)) or bool(enemy.get("boss", false)),
		"unrevealed": is_hidden or player_attack_count == 0,
		"repeated_target": last_target_id == target_id,
		"studied_target": studied_target_ids.has(target_id),
		"first_enemy_type": not seen_enemy_types.has(enemy_type),
		"adjacent_enemies": _adjacent_enemy_count(player_pos),
		"range_bonus": run_state.get_derived_stat("range"),
		"target_slowed": int(enemy.get("slowed", 0)) > 0,
	}
	var contextual_power_stat := "spell_potency" if spell_attack else "attack_power"
	damage += run_state.get_contextual_item_modifier(contextual_power_stat, context)
	damage += int(next_attack_item_bonuses.get(contextual_power_stat, 0))
	if spell_attack:
		damage += stored_spell_damage
		stored_spell_damage = 0
	var defenses := {
		"armor_class": int(GameBalance.get_enemy_combat_stat(enemy_type, "armor_class", 10)),
		"evasion": int(GameBalance.get_enemy_combat_stat(enemy_type, "evasion", 9)),
		"threshold": maxi(0, int(GameBalance.get_enemy_combat_stat(enemy_type, "threshold", 0)) - int(enemy.get("threshold_shred", 0))),
		"aegis_all": int(GameBalance.get_enemy_combat_stat(enemy_type, "aegis_all", 0)),
	}
	defenses["aegis_%s" % resolved_type] = int(GameBalance.get_enemy_combat_stat(enemy_type, "aegis_%s" % resolved_type, 0))
	context["target_threshold"] = int(defenses["threshold"])
	var action_slot := action_slot_override
	var coordinated_wolf_attack := action_slot == "coordinated_basic"
	if coordinated_wolf_attack: action_slot = "basic"
	if action_slot.is_empty(): action_slot = "special" if selected_action == "special" else "basic"
	context["coordinated_wolf_attack"] = coordinated_wolf_attack
	var action_modifiers := run_state.get_action_modifier_breakdown(action_slot, context)
	for ignored_defense in action_modifiers.get("ignore", []):
		if String(ignored_defense) == "threshold": defenses["threshold"] = 0
		elif String(ignored_defense) == "aegis":
			defenses["aegis_all"] = 0; defenses["aegis_%s" % resolved_type] = 0
	var roll := rng.randi_range(1, 20)
	var base_accuracy := run_state.get_derived_stat("accuracy")
	var action_accuracy := int(action_modifiers.get("action_bonus", 0))
	var conditional_accuracy := int(action_modifiers.get("conditional_bonus", 0))
	var item_accuracy := run_state.get_contextual_item_modifier("accuracy", context) + int(next_attack_item_bonuses.get("accuracy", 0)) + next_consumable_accuracy_bonus
	next_consumable_accuracy_bonus = 0
	var accuracy := base_accuracy + action_accuracy + conditional_accuracy + item_accuracy
	var base_penetration := run_state.get_derived_stat("penetration")
	var action_penetration := 0
	if GameBalance.get_class_action(run_state.selected_class_id, action_slot).get("modifiers", []).size() > 0:
		for modifier in GameBalance.get_class_action(run_state.selected_class_id, action_slot).get("modifiers", []):
			if modifier is Dictionary and String(modifier.get("stat", "")) == "penetration":
				action_penetration = int(action_modifiers.get("action_bonus", 0)) + int(action_modifiers.get("conditional_bonus", 0)); action_accuracy = 0; conditional_accuracy = 0; accuracy = base_accuracy + item_accuracy
	var item_penetration := run_state.get_contextual_item_modifier("penetration", context) + int(next_attack_item_bonuses.get("penetration", 0))
	var penetration := base_penetration + action_penetration + item_penetration
	next_attack_item_bonuses.clear()
	var result := CombatResolver.resolve_attack(roll, accuracy, damage, penetration, resolved_type, defenses)
	if not bool(result["hit"]) and int(result["evasion"]) - int(result["attack_total"]) <= 2:
		for effect in run_state.get_active_item_effects("near_miss"):
			result = CombatResolver.resolve_attack(roll, accuracy + int(effect.get("accuracy", 0)), damage, penetration, resolved_type, defenses)
	if not bool(result["hit"]) and _can_use_limited_item_effect("miss", "combat"):
		for effect in run_state.get_active_item_effects("miss"):
			if bool(effect.get("reroll", false)):
				result = CombatResolver.resolve_attack(rng.randi_range(1, 20), accuracy, damage, penetration, resolved_type, defenses)
				_mark_item_effect_used(effect, "combat")
				break
	player_attack_count += 1
	if spell_attack: player_spell_count_floor += 1
	last_target_id = target_id
	if not bool(result["hit"]):
		if roll == 1:
			for effect in run_state.get_active_item_effects("critical_miss"):
				var cost := int(effect.get("spend_gold_reroll", 0))
				if cost > 0 and run_state.gold >= cost:
					run_state.gold -= cost
					result = CombatResolver.resolve_attack(rng.randi_range(1, 20), accuracy, damage, penetration, resolved_type, defenses)
					break
	result["accuracy_breakdown"] = {"base":base_accuracy,"action":action_accuracy,"conditional":conditional_accuracy,"item":item_accuracy,"final":int(result.get("accuracy", accuracy))}
	result["penetration_breakdown"] = {"base":base_penetration,"action":action_penetration,"item":item_penetration,"final":int(result.get("penetration", penetration))}
	result["action_name"] = String(GameBalance.get_class_action(run_state.selected_class_id, action_slot).get("name", action_slot.capitalize()))
	if not bool(result["hit"]):
		message = "%s avoids the attack (%d vs Evasion %d)." % [_enemy_display_name(enemy), int(result["attack_total"]), int(result["evasion"])]
		_record_attack_result("You", _enemy_display_name(enemy), result, 0)
		return
	var dealt := int(result["damage"])
	if dealt <= 0:
		_apply_item_trigger("absorbed_attack", {"enemy_index": index, "damage_type": resolved_type, "prevented": damage})
		if bool(result.get("blocked_by_threshold", false)):
			_apply_item_trigger("threshold_block", {"enemy_index": index, "damage_type": resolved_type})
		message = "%s's defenses absorb the attack." % _enemy_display_name(enemy)
		_record_attack_result("You", _enemy_display_name(enemy), result, 0)
		return
	if last_player_hit_round != round_number:
		last_player_hit_round = round_number
		for effect in run_state.get_active_item_effects("first_hit_round"):
			var bonus_type := String(effect.get("damage_type", resolved_type))
			var bonus_defenses := defenses.duplicate()
			bonus_defenses["aegis_%s" % bonus_type] = int(GameBalance.get_enemy_combat_stat(enemy_type, "aegis_%s" % bonus_type, 0))
			var bonus_result := CombatResolver.resolve_attack(roll, accuracy, int(effect.get("bonus_damage", 0)), penetration, bonus_type, bonus_defenses)
			dealt += int(bonus_result.get("damage", 0))
	studied_target_ids[target_id] = true
	seen_enemy_types[enemy_type] = true
	if roll == 20:
		_apply_item_trigger("critical_hit", {"enemy_index": index})
	if not spell_attack:
		_apply_item_trigger("martial_hit", {"enemy_index": index})
	var target_tile := Vector2i(enemy["pos"])
	enemy["hp"] -= dealt
	_spawn_damage_popup(target_tile, dealt, resolved_type)
	_record_attack_result("You", _enemy_display_name(enemy), result, dealt)
	if enemy["hp"] <= 0:
		var reward: int = _enemy_gold_reward(enemy)
		var xp_reward: int = _enemy_xp_reward(enemy)
		message = "%s falls. You gain %d gold." % [_enemy_display_name(enemy), reward]
		run_state.gold += reward
		_apply_item_trigger("kill_at_full_health" if run_state.current_health == run_state.max_health else "kill", {"enemy_index": index})
		progression_log_buffer.append_array(run_state.gain_xp(xp_reward, "%s defeated" % _enemy_display_name(enemy)))
		enemies.remove_at(index)
	else:
		enemies[index] = enemy
		message = "Hit %s for %d %s damage. It has %d health left." % [_enemy_display_name(enemy), dealt, resolved_type, enemy["hp"]]

func _record_attack_result(attacker: String, defender: String, result: Dictionary, final_damage: int) -> void:
	var hit := bool(result.get("hit", false))
	var blocked := bool(result.get("blocked_by_threshold", false))
	var outcome := "%d damage" % final_damage if final_damage > 0 else ("Threshold blocked" if blocked else ("Miss" if not hit else "No damage"))
	var summary := "%s → %s: %s" % [attacker, defender, outcome]
	var effective_threshold := maxi(0, int(result.get("threshold", 0)) - int(result.get("penetration", 0)))
	var effective_aegis := maxi(0, int(result.get("aegis", 0)) - int(result.get("penetration", 0)))
	var reaction_note := "yes" if bool(result.get("reaction_eligible", false)) else "no"
	var accuracy_parts: Dictionary = result.get("accuracy_breakdown", {})
	var penetration_parts: Dictionary = result.get("penetration_breakdown", {})
	var details := "Action: %s\nRoll: %d + Accuracy %d = %d; Evasion %d; AC %d (reaction eligible: %s).\nAccuracy: base %d + action %d + conditional %d + items %d = %d.\nDamage: %d %s; Penetration %d (base %d + action %d + items %d); effective Threshold %d; effective Aegis %d; final %d." % [
		String(result.get("action_name", "Attack")),
		int(result.get("roll", 0)), int(result.get("accuracy", 0)), int(result.get("attack_total", 0)), int(result.get("evasion", 0)), int(result.get("armor_class", 0)), reaction_note,
		int(accuracy_parts.get("base", result.get("accuracy", 0))), int(accuracy_parts.get("action", 0)), int(accuracy_parts.get("conditional", 0)), int(accuracy_parts.get("item", 0)), int(accuracy_parts.get("final", result.get("accuracy", 0))),
		int(result.get("raw_damage", 0)), String(result.get("damage_type", "physical")), int(result.get("penetration", 0)), int(penetration_parts.get("base", result.get("penetration", 0))), int(penetration_parts.get("action", 0)), int(penetration_parts.get("item", 0)), effective_threshold, effective_aegis, final_damage
	]
	var resolved_damage := int(result.get("damage", 0))
	if final_damage != resolved_damage:
		details += "\nPost-roll reactions, blocks, triggered bonuses, or survival effects changed %d resolved damage to %d applied damage." % [resolved_damage, final_damage]
	_record_combat_event(summary, details, "#f2c15b" if attacker == "You" else "#ef7770")

func _spawn_damage_popup(tile: Vector2i, amount: int, damage_type: String) -> void:
	if amount <= 0:
		return
	var popup := Label.new()
	popup.text = "-%d" % amount
	popup.position = _grid_center(tile) + Vector2(-18, -34)
	popup.z_index = 100
	popup.add_theme_font_size_override("font_size", 22)
	popup.add_theme_constant_override("outline_size", 5)
	popup.add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.02, 0.96))
	popup.add_theme_color_override("font_color", _damage_popup_color(damage_type))
	_get_effects_root().add_child(popup)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "position", popup.position + Vector2(0, -38), 0.85)
	tween.tween_property(popup, "modulate:a", 0.0, 0.85).set_delay(0.18)
	tween.chain().tween_callback(popup.queue_free)

func _damage_popup_color(damage_type: String) -> Color:
	match damage_type:
		"fire": return Color(1.0, 0.36, 0.12)
		"cold": return Color(0.45, 0.88, 1.0)
		"lightning": return Color(1.0, 0.90, 0.25)
		"arcane": return Color(0.72, 0.45, 1.0)
		"radiant": return Color(1.0, 0.95, 0.62)
		"necrotic": return Color(0.55, 0.90, 0.42)
		"poison": return Color(0.52, 0.92, 0.25)
	return Color(1.0, 0.84, 0.62)

func _hit_prop(index: int) -> void:
	if index < 0 or index >= props.size():
		return
	if not _is_destructible_prop(index):
		var prop: Dictionary = props[index]
		if prop["kind"] == "campfire":
			_use_campfire()
		else:
			message = "That object will not break from a strike."
		return
	_damage_prop(index, 1)

func _is_destructible_prop_at(tile: Vector2i) -> bool:
	return _is_destructible_prop(_prop_at(tile))

func _is_destructible_prop(index: int) -> bool:
	if index < 0 or index >= props.size():
		return false
	var prop: Dictionary = props[index]
	var kind: String = String(prop.get("kind", ""))
	return kind == "barrel" or kind == "rock"

func _damage_prop(index: int, damage: int, announce: bool = true) -> bool:
	if index < 0 or index >= props.size() or not _is_destructible_prop(index):
		return false
	var prop: Dictionary = props[index]
	var prop_kind: String = String(prop["kind"])
	prop["hp"] = int(prop.get("hp", GameBalance.get_prop_hp(prop_kind, 1))) - maxi(1, damage)
	if int(prop["hp"]) <= 0:
		if announce:
			message = "The %s breaks. Something clinks in the grass." % prop_kind
		if run_state != null:
			run_state.gold += int(GameBalance.get_combat_value(["props", "break_gold"], 1))
		props.remove_at(index)
		return true
	props[index] = prop
	if announce:
		message = "The %s cracks." % prop_kind
	return false

func _use_campfire() -> void:
	if _is_free_roam():
		run_state.heal(run_state.max_health)
		message = "The campfire burns bright. You recover to full health."
	else:
		var heal_amount: int = int(GameBalance.get_combat_value(["healing", "campfire_combat"], 2))
		run_state.heal(heal_amount)
		message = "The campfire steadies you. Restored %d health." % heal_amount

func _open_chest() -> bool:
	if chest["opened"]:
		message = "The chest is already open."
		return false
	elif run_state.keys > 0:
		run_state.keys -= 1
		chest["opened"] = true
		run_state.generate_chest_choices(_current_floor(), rng)
		message = "The key turns. Choose one relic from the chest."
		_open_chest_choice_modal()
		return true
	else:
		message = "The chest is locked. Find a key."
		return false

func _resolve_tile() -> void:
	for item in loot.duplicate():
		if item["pos"] == player_pos:
			_apply_loot_item(item)
			loot.erase(item)
	for i in range(traps.size() - 1, -1, -1):
		var trap: Dictionary = traps[i]
		if trap["pos"] == player_pos and not trap["sprung"]:
			_apply_damage(3)
			message = "A root-snare trap snaps shut for 3 damage."
			traps.remove_at(i)

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
		message = "%s is stunned and loses its turn." % _enemy_display_name(enemy)
		_refresh_ui()
		is_resolving_enemy_turn = false
		_advance_to_next_actor()
		return
	if _enemy_can_ranged_cast(index):
		_enemy_ranged_cast(index)
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
		message = "%s advances through the dark." % _enemy_display_name(enemies[index])
	_refresh_ui()
	is_resolving_enemy_turn = false
	_advance_to_next_actor()

func _enemy_move_toward_player(index: int) -> void:
	var movement: int = _enemy_movement(enemies[index]) if index >= 0 and index < enemies.size() else ENEMY_MOVE_ALLOWANCE
	for step in range(movement):
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

func _enemy_display_name(enemy: Dictionary) -> String:
	return String(GameBalance.get_enemy_value(_enemy_type(enemy), "display_name", "Wolf"))

func _enemy_short_name(enemy: Dictionary) -> String:
	return String(GameBalance.get_enemy_value(_enemy_type(enemy), "short_name", _enemy_display_name(enemy)))

func _enemy_type(enemy: Dictionary) -> String:
	return String(enemy.get("enemy_type", "normal_wolf"))

func _enemy_initiative_modifier(enemy: Dictionary) -> int:
	return int(GameBalance.get_enemy_value(_enemy_type(enemy), "initiative_modifier", 0))

func _enemy_movement(enemy: Dictionary) -> int:
	var movement := int(GameBalance.get_enemy_value(_enemy_type(enemy), "movement", ENEMY_MOVE_ALLOWANCE))
	if int(enemy.get("slowed", 0)) > 0:
		movement = maxi(1, movement - 1)
		enemy["slowed"] = int(enemy["slowed"]) - 1
	return movement

func _enemy_can_ranged_cast(index: int) -> bool:
	if index < 0 or index >= enemies.size():
		return false
	var enemy_type: String = _enemy_type(enemies[index])
	if enemy_type != "necromancer" and enemy_type != "crypt_boss":
		return false
	var distance: int = _line_distance(enemies[index]["pos"], player_pos)
	if distance <= 1 or distance > int(GameBalance.get_enemy_value(enemy_type, "range", 4)):
		return false
	var from_tile: Vector2i = enemies[index]["pos"]
	var aligned: bool = from_tile.x == player_pos.x or from_tile.y == player_pos.y or abs(from_tile.x - player_pos.x) == abs(from_tile.y - player_pos.y)
	return aligned and _has_clear_line(from_tile, player_pos, true)

func _enemy_ranged_cast(index: int) -> void:
	var enemy: Dictionary = enemies[index]
	var result := _resolve_enemy_attack_roll(enemy)
	var damage := int(result["damage"])
	if bool(result["reaction_eligible"]):
		damage = _resolve_class_reaction(index, damage, true)
	if not bool(result["hit"]):
		message = "%s's grave-light misses (%d vs Evasion %d)." % [_enemy_display_name(enemy), int(result["attack_total"]), int(result["evasion"])]
		_record_attack_result(_enemy_display_name(enemy), "You", result, 0)
		return
	var health_before := run_state.current_health
	if damage > 0:
		_apply_damage(damage)
	var applied_damage := maxi(0, health_before - run_state.current_health)
	if applied_damage > 0:
		_spawn_damage_popup(player_pos, applied_damage, String(result.get("damage_type", "necrotic")))
	_record_attack_result(_enemy_display_name(enemy), "You", result, applied_damage)
	if _enemy_type(enemy) == "crypt_boss" and rng.randi_range(1, 4) == 1:
		movement_remaining = 0
		var push_direction := Vector2i(_sign_int(player_pos.x - Vector2i(enemy["pos"]).x), _sign_int(player_pos.y - Vector2i(enemy["pos"]).y))
		_apply_forced_player_move(push_direction, 2)
	message = "%s hurls grave-light for %d damage." % [_enemy_display_name(enemy), applied_damage]

func _enemy_sprite_key(enemy: Dictionary) -> String:
	match _enemy_type(enemy):
		"kobold":
			return "kobold"
		"blood_wolf":
			return "blood_wolf"
		"skeleton", "armored_skeleton":
			return "skeleton"
		"ghoul":
			return "ghoul"
		"necromancer":
			return "necromancer"
		"crypt_boss":
			return "crypt_boss"
	return "wolf"

func _enemy_label(enemy: Dictionary) -> String:
	match _enemy_type(enemy):
		"kobold":
			return "K"
		"blood_wolf":
			return "B"
		"elite_wolf":
			return "E"
		"boss_wolf":
			return "W"
		"skeleton":
			return "S"
		"armored_skeleton":
			return "A"
		"ghoul":
			return "G"
		"necromancer":
			return "N"
		"crypt_boss":
			return "C"
	return "W"

func _enemy_color(enemy: Dictionary) -> Color:
	match _enemy_type(enemy):
		"kobold":
			return Color(0.62, 0.36, 0.12)
		"blood_wolf":
			return Color(0.62, 0.05, 0.07)
		"elite_wolf", "boss_wolf":
			return Color(0.56, 0.14, 0.14)
		"skeleton", "armored_skeleton":
			return Color(0.72, 0.70, 0.62)
		"ghoul":
			return Color(0.33, 0.54, 0.34)
		"necromancer", "crypt_boss":
			return Color(0.38, 0.24, 0.58)
	return Color(0.45, 0.12, 0.12)

func _brace_hits_enemy(index: int) -> bool:
	if not braced:
		return false
	braced = false
	_attack_enemy(index, _player_gear_damage() + 1 + _fighter_progression_value("brace_retaliate_bonus"))
	message = "Brace lands before the enemy can strike."
	return true

func _enemy_attack(index: int) -> void:
	if index < 0 or index >= enemies.size():
		return
	var enemy: Dictionary = enemies[index]
	var result := _resolve_enemy_attack_roll(enemy)
	var damage := int(result["damage"])
	if bool(result["reaction_eligible"]):
		damage = _resolve_class_reaction(index, damage, false)
	if not bool(result["hit"]):
		message = "%s misses (%d vs Evasion %d)." % [_enemy_display_name(enemy), int(result["attack_total"]), int(result["evasion"])]
		_record_attack_result(_enemy_display_name(enemy), "You", result, 0)
		return
	if block_stacks > 0:
		block_stacks -= 1
		damage = maxi(0, damage - 1)
		message = "Your shield absorbs part of the blow."
	var health_before := run_state.current_health
	if damage > 0:
		_apply_damage(damage)
	var applied_damage := maxi(0, health_before - run_state.current_health)
	if applied_damage > 0:
		_spawn_damage_popup(player_pos, applied_damage, String(result.get("damage_type", "physical")))
		if retribution_armed:
			retribution_stored += int(ceil(float(applied_damage) * 0.5))
	_record_attack_result(_enemy_display_name(enemy), "You", result, applied_damage)
	if applied_damage > 0 and run_state.current_health > 0:
		message = "%s hits you for %d %s damage." % [_enemy_display_name(enemy), applied_damage, String(result.get("damage_type", "physical"))]

func _resolve_enemy_attack_roll(enemy: Dictionary) -> Dictionary:
	var enemy_type := _enemy_type(enemy)
	var accuracy := int(GameBalance.get_enemy_combat_stat(enemy_type, "accuracy", 2))
	var penetration := int(GameBalance.get_enemy_combat_stat(enemy_type, "penetration", 0))
	var damage_type := String(GameBalance.get_enemy_combat_stat(enemy_type, "damage_type", "physical"))
	return CombatResolver.resolve_attack(rng.randi_range(1, 20), accuracy, int(enemy["damage"]), penetration, damage_type, _player_defenses())

func _player_defenses() -> Dictionary:
	var stats: Dictionary = {}
	var context := {
		"damage_type": "",
		"incoming_hit_index": incoming_hit_count,
		"moved": tiles_moved_this_turn > 0,
		"tiles_moved": tiles_moved_this_turn,
		"unrevealed": is_hidden or player_attack_count == 0,
		"adjacent_enemies": _adjacent_enemy_count(player_pos),
	}
	for key in ["armor_class", "evasion", "threshold", "aegis_all"]:
		stats[key] = run_state.get_derived_stat(key) + run_state.get_contextual_item_modifier(key, context)
	for damage_type in CombatResolver.DAMAGE_TYPES:
		var typed_context := context.duplicate()
		typed_context["damage_type"] = damage_type
		stats["aegis_%s" % damage_type] = run_state.get_derived_stat("aegis_%s" % damage_type) + run_state.get_contextual_item_modifier("aegis_%s" % damage_type, typed_context) + temporary_aegis
	return CombatResolver.defense_snapshot(stats)

func _player_damage_type() -> String:
	match run_state.selected_class_id:
		"mage": return "arcane"
		"healer": return "radiant"
		"phantom": return "necrotic"
	return "physical"

func _apply_damage(amount: int) -> void:
	incoming_hit_count += 1
	var was_low := run_state.current_health * 2 <= run_state.max_health
	if amount >= run_state.current_health:
		for effect in run_state.get_active_item_effects("lethal_damage"):
			var limit := String(effect.get("limit", "floor"))
			if not _can_use_item_effect(effect, limit):
				continue
			run_state.current_health = maxi(1, int(effect.get("survive", 1)))
			_mark_item_effect_used(effect, limit)
			var retaliation := int(effect.get("retaliate", 0))
			for i in range(enemies.size() - 1, -1, -1):
				if _distance(player_pos, Vector2i(enemies[i]["pos"])) == 1:
					_attack_enemy(i, retaliation, String(effect.get("damage_type", "fire")))
			message = "%s prevents a lethal blow." % String(effect.get("source_item_name", "A relic"))
			return
	run_state.hurt(amount)
	temporary_aegis = 0
	var now_low := run_state.current_health * 2 <= run_state.max_health
	if not was_low and now_low:
		_apply_item_trigger("cross_low_health")
	if run_state.current_health <= 0:
		message = "You fall among the crypt stones." if dungeon_id == "crypt" else "You fall beneath the trees."

func _apply_item_trigger(trigger: String, context: Dictionary = {}) -> void:
	for effect in run_state.get_active_item_effects(trigger):
		if effect.has("damage_type") and context.has("damage_type") and String(effect["damage_type"]) != String(context["damage_type"]):
			continue
		if effect.has("minimum") and int(context.get("amount", 0)) < int(effect["minimum"]):
			continue
		var limit := String(effect.get("limit", ""))
		if not limit.is_empty() and not _can_use_item_effect(effect, limit):
			continue
		if effect.has("heal"):
			run_state.heal(int(effect["heal"]))
		if effect.has("resource"):
			run_state.gain_class_resource(int(effect["resource"]))
		if effect.has("gold"):
			run_state.gold += int(effect["gold"])
		if effect.has("xp"):
			progression_log_buffer.append_array(run_state.gain_xp(int(effect["xp"]), String(effect.get("source_item_name", "item effect"))))
		if effect.has("temporary_aegis"):
			temporary_aegis = maxi(temporary_aegis, int(effect["temporary_aegis"]))
		if effect.has("temporary_aegis_cap"):
			temporary_aegis = maxi(temporary_aegis, mini(int(effect["temporary_aegis_cap"]), int(context.get("amount", 0))))
		if effect.has("next_attack") and effect["next_attack"] is Dictionary:
			for stat_id in effect["next_attack"].keys():
				next_attack_item_bonuses[stat_id] = int(next_attack_item_bonuses.get(stat_id, 0)) + int(effect["next_attack"][stat_id])
		if effect.has("store_prevented_spell_damage"):
			stored_spell_damage += int(floor(float(context.get("prevented", 0)) * float(effect["store_prevented_spell_damage"])))
		if effect.has("gold_per_unopened_secret"):
			var unopened := 0
			if _has_closed_chest(): unopened += 1
			if secret.has("found") and not bool(secret.get("found", true)): unopened += 1
			run_state.gold += unopened * int(effect["gold_per_unopened_secret"])
		if String(effect.get("cleanse", "")) == "slow":
			movement_remaining = maxi(movement_remaining, _player_move_allowance())
		var enemy_index := int(context.get("enemy_index", -1))
		if effect.has("retaliate") and enemy_index >= 0 and enemy_index < enemies.size():
			_attack_enemy(enemy_index, int(effect["retaliate"]), String(effect.get("damage_type", "physical")))
		if effect.has("shred_threshold") and enemy_index >= 0 and enemy_index < enemies.size():
			enemies[enemy_index]["threshold_shred"] = int(enemies[enemy_index].get("threshold_shred", 0)) + int(effect["shred_threshold"])
		if not limit.is_empty():
			_mark_item_effect_used(effect, limit)

func _apply_forced_player_move(direction: Vector2i, distance: int) -> int:
	var reduction := 0
	for effect in run_state.get_active_item_effects("forced_move"):
		reduction += int(effect.get("reduce_tiles", 0))
	var remaining := maxi(0, distance - reduction)
	var moved := 0
	for step in range(remaining):
		var target := player_pos + direction
		if not _is_walkable(target):
			break
		player_pos = target
		moved += 1
	return moved

func _item_effect_key(effect: Dictionary, limit: String) -> String:
	return "%s:%s:%s:%d" % [limit, String(effect.get("source_item_id", "")), String(effect.get("trigger", effect.get("condition", ""))), round_number if limit == "turn" else 0]

func _can_use_item_effect(effect: Dictionary, limit: String) -> bool:
	return not item_limits_used.has(_item_effect_key(effect, limit))

func _can_use_limited_item_effect(trigger: String, limit: String) -> bool:
	for effect in run_state.get_active_item_effects(trigger):
		if _can_use_item_effect(effect, limit):
			return true
	return false

func _mark_item_effect_used(effect: Dictionary, limit: String) -> void:
	item_limits_used[_item_effect_key(effect, limit)] = true

func _resolve_class_reaction(enemy_index: int, damage: int, ranged: bool) -> int:
	if armed_reaction.is_empty():
		return damage
	var reaction := armed_reaction
	armed_reaction = ""
	is_defending = false
	for effect in run_state.get_active_item_effects("reaction"):
		if bool(effect.get("double_aegis", false)):
			damage = maxi(0, damage - run_state.get_derived_stat("aegis_all"))
	_apply_item_trigger("reaction", {"enemy_index": enemy_index})
	if not ranged:
		_apply_item_trigger("melee_reaction", {"enemy_index": enemy_index})
	match reaction:
		"parry":
			if not ranged and enemy_index >= 0 and enemy_index < enemies.size():
				_attack_enemy(enemy_index, _player_gear_damage())
				run_state.gain_class_resource()
				message = "Parry negates the blow and counters."
				return 0
			return maxi(0, damage - 1)
		"repel":
			if not ranged and enemy_index >= 0 and enemy_index < enemies.size():
				var enemy_pos: Vector2i = enemies[enemy_index]["pos"]
				_push_enemy_from(enemy_pos, Vector2i(_sign_int(enemy_pos.x - player_pos.x), _sign_int(enemy_pos.y - player_pos.y)), 2)
			message = "Repel throws the threat away."
			return maxi(0, damage - 2)
		"recover":
			var lost := damage
			call_deferred("_recover_recent_damage", int(ceil(float(lost) * 0.5)))
			message = "Recover catches the wound before it settles."
			return damage
		"guard":
			run_state.gain_class_resource()
			message = "Guard absorbs the worst of the hit."
			return maxi(0, damage - 2 - run_state.get_derived_stat("defense"))
		"evade":
			_evade_from_enemy(enemy_index)
			run_state.gain_class_resource()
			message = "Evade leaves the attack cutting empty air."
			return 0
		"cover":
			if _companion_active():
				var absorbed := _damage_companion(damage)
				message = "Your bonded wolf intercepts the hit."
				return maxi(0, damage - absorbed)
	return damage

func _recover_recent_damage(amount: int) -> void:
	if run_state != null and run_state.current_health > 0:
		run_state.heal(amount)
		_refresh_ui()

func _evade_from_enemy(enemy_index: int) -> void:
	if enemy_index < 0 or enemy_index >= enemies.size(): return
	var origin: Vector2i = enemies[enemy_index]["pos"]
	var best := player_pos
	var best_distance := _distance(best, origin)
	for direction in _eight_directions():
		var tile := player_pos + direction
		if _is_walkable(tile) and _distance(tile, origin) > best_distance:
			best = tile
			best_distance = _distance(tile, origin)
	player_pos = best

func _release_retribution() -> void:
	retribution_armed = false
	if retribution_stored <= 0: return
	for i in range(enemies.size() - 1, -1, -1):
		if _distance(player_pos, enemies[i]["pos"]) == 1:
			_attack_enemy(i, retribution_stored)
	message = "Retribution releases %d stored damage." % retribution_stored
	retribution_stored = 0

func _complete_floor() -> void:
	if exit_door != null:
		exit_door.enter()
		return
	_finish_floor()

func _on_exit_door_entered(_door: ExitDoor) -> void:
	_finish_floor()

func _finish_floor() -> void:
	if controller != null and controller.has_method(complete_floor_method):
		controller.call(complete_floor_method)
		return
	var final_gold := run_state.gold
	controller.return_to_tavern("victory", victory_text_template % final_gold)

func _die() -> void:
	controller.return_to_tavern("death", "You wake at the tavern table. The bartender says, 'Again, then?'")

func _build_board_tiles() -> void:
	if ground_layer == null:
		return
	ground_layer.position = ORIGIN
	ground_layer.scale = Vector2.ONE
	ground_layer.clear()
	_clear_children_now(ground_layer)
	var backdrop := Polygon2D.new()
	backdrop.name = "DungeonBlackBackdrop"
	backdrop.polygon = PackedVector2Array([
		Vector2(-100000, -100000),
		Vector2(100000, -100000),
		Vector2(100000, 100000),
		Vector2(-100000, 100000),
	])
	backdrop.color = Color.BLACK
	backdrop.z_index = -1
	ground_layer.add_child(backdrop)
	for tile_value: Variant in floor_cells.keys():
		var tile: Vector2i = tile_value
		if dungeon_id == "crypt":
			_add_crypt_stone_sprite(tile)
		else:
			_add_grass_sprite(tile)

func _add_crypt_stone_sprite(tile: Vector2i) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "CryptStone_%d_%d" % [tile.x, tile.y]
	sprite.texture = CRYPT_STONE_TILE
	sprite.region_enabled = true
	var atlas_x: int = abs(tile.x * 3 + tile.y * 5) % 4
	var atlas_y: int = abs(tile.x * 7 + tile.y * 2) % 2
	sprite.region_rect = Rect2(atlas_x * ATLAS_TILE_SIZE, atlas_y * ATLAS_TILE_SIZE, ATLAS_TILE_SIZE, ATLAS_TILE_SIZE)
	sprite.centered = false
	sprite.position = Vector2(tile) * tile_size
	sprite.scale = Vector2(float(tile_size) / float(ATLAS_TILE_SIZE), float(tile_size) / float(ATLAS_TILE_SIZE))
	sprite.modulate = Color(0.58, 0.60, 0.64)
	sprite.z_index = 0
	ground_layer.add_child(sprite)

func _add_grass_sprite(tile: Vector2i) -> void:
	var texture: Texture2D = _grass_texture_for(tile)
	var sprite := Sprite2D.new()
	sprite.name = "Grass_%d_%d" % [tile.x, tile.y]
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(tile) * tile_size
	sprite.scale = Vector2(float(tile_size) / float(texture.get_width()), float(tile_size) / float(texture.get_height()))
	sprite.z_index = 0
	ground_layer.add_child(sprite)

func _grass_texture_for(tile: Vector2i) -> Texture2D:
	var index: int = abs(tile.x * 7 + tile.y * 11) % 2
	match index:
		0:
			return GRASS_TILE_A
		1:
			return GRASS_TILE_B
	return GRASS_TILE_C

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
		"crypt_pillar":
			sprite.texture = STRUCT_ATLAS
			sprite.region_rect = _atlas_region(2, 0)
			sprite.scale = Vector2(1.32, 1.32)
			sprite.modulate = Color(0.66, 0.68, 0.72)
			sprite.offset = Vector2(0, -3)
		"bone_pile":
			sprite.texture = PROPS_ATLAS
			sprite.region_rect = _atlas_region(0, 8)
			sprite.scale = Vector2(1.15, 1.15)
			sprite.modulate = Color(0.82, 0.78, 0.66)
			sprite.offset = Vector2(0, 8)
		_:
			sprite.region_rect = Rect2(96, 196, 32, 29)
			sprite.scale = Vector2(0.72, 0.72)
			sprite.offset = Vector2(0, 7)

func _configure_player_sprite() -> void:
	var class_data := GameBalance.get_base_class(run_state.selected_class_id) if run_state != null else {}
	var sprite_path := String(class_data.get("sprite", ""))
	player_token.sprite_texture = load(sprite_path) if not sprite_path.is_empty() else PLAYER_IDLE_DOWN
	player_token.sprite_region_enabled = true
	player_token.sprite_region = Rect2(0, 0, 96, 80)
	player_token.sprite_scale = Vector2(0.58, 0.58)
	player_token.show_label = false
	player_token.show_panel = false

func _refresh_ui() -> void:
	if hud_label == null or run_state == null:
		return
	_update_follow_camera()
	health_bar.max_value = run_state.max_health
	health_bar.value = run_state.current_health
	health_value_label.text = "%d/%d" % [run_state.current_health, run_state.max_health]
	title_label.text = "%s - %s %d/%d" % [dungeon_title, dungeon_floor_label, _current_floor(), _max_floors()]
	var resource_text := "%s %d/%d" % [run_state.get_class_resource_name(), run_state.class_resource, run_state.get_class_resource_max()]
	var states: Array[String] = []
	if not armed_reaction.is_empty(): states.append("Reaction: %s" % armed_reaction.capitalize())
	if empowered: states.append("Empowered")
	if is_hidden: states.append("Hidden")
	action_label.text = "%s | %s | %s%s" % [_turn_status(), _layout_display_name(), resource_text, " | " + ", ".join(states) if not states.is_empty() else ""]
	hud_label.text = ""
	hud_label.visible = false
	log_label.text = _compact_combat_log_text()
	_sync_initiative_tracker()
	_sync_action_panel()
	_sync_board_nodes()
	if character_menu_panel != null and character_menu_panel.visible:
		_sync_character_menu()

func _compact_combat_log_text() -> String:
	var lines: Array[String] = [message]
	var start := maxi(0, combat_log_entries.size() - 2)
	for i in range(start, combat_log_entries.size()):
		lines.append(String(combat_log_entries[i].get("summary", "")))
	lines.append("[ Click for attack rolls and calculations ]")
	return "\n".join(lines)

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
	image.modulate = _actor_portrait_modulate(actor)
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
	var actions: Dictionary = GameBalance.get_base_class(run_state.selected_class_id).get("actions", {}) if run_state != null else {}
	if not actions.is_empty():
		move_button.text = "1 %s" % _class_action_name(actions, "movement")
		interact_button.text = "2 %s" % _class_action_name(actions, "basic")
		var special_data: Dictionary = actions.get("special", {})
		special_button.text = "3 %s (%d)" % [String(special_data.get("name", "Special")), int(special_data.get("cost", 2))]
		defend_button.text = "5 %s" % _class_action_name(actions, "defensive")
		move_button.tooltip_text = _class_action_tooltip(actions, "movement", "1")
		interact_button.tooltip_text = _class_action_tooltip(actions, "basic", "2")
		special_button.tooltip_text = _class_action_tooltip(actions, "special", "3")
		defend_button.tooltip_text = _class_action_tooltip(actions, "defensive", "5")
	potion_button.text = "4 Consumables (%d/%d)" % [run_state.get_consumables().size(), run_state.get_consumable_capacity()]
	potion_button.tooltip_text = "Choose a held consumable. Using one spends your action. (4)"
	end_turn_button.tooltip_text = "End your turn and surrender any unused action or movement. (Enter)"
	_set_combat_buttons_enabled()
	_set_button_selected(move_button, selected_action == "movement")
	_set_button_selected(interact_button, selected_action == "attack")
	_set_button_selected(special_button, selected_action == "special")
	_set_button_selected(potion_button, false)
	_set_button_selected(defend_button, not armed_reaction.is_empty())
	_set_button_selected(end_turn_button, false)
	_set_button_selected(cancel_action_button, false)

func _class_action_name(actions: Dictionary, slot: String) -> String:
	var value: Variant = actions.get(slot, {})
	return String(value.get("name", slot.capitalize())) if value is Dictionary else slot.capitalize()

func _class_action_tooltip(actions: Dictionary, slot: String, hotkey: String) -> String:
	return "%s\nHotkey: %s" % [GameBalance.get_action_tooltip(run_state.selected_class_id, slot), hotkey]

func _is_blocking_modal_open() -> bool:
	return (consumables_backdrop != null and consumables_backdrop.visible) or (merchant_shop_panel != null and merchant_shop_panel.visible) or (combat_log_backdrop != null and combat_log_backdrop.visible) or (chest_choice_panel != null and chest_choice_panel.visible) or (character_menu_panel != null and character_menu_panel.visible)

func _toggle_character_menu() -> void:
	if chest_choice_panel != null and chest_choice_panel.visible:
		return
	if character_menu_panel == null:
		return
	character_menu_panel.visible = not character_menu_panel.visible
	if character_menu_panel.visible:
		_hide_hover_context()
		_sync_character_menu()

func _sync_character_menu() -> void:
	if character_menu_panel == null or run_state == null:
		return
	var profile_value: Variant = run_state.hero_profiles.get(run_state.selected_class_id, {})
	var profile: Dictionary = profile_value if profile_value is Dictionary else {}
	var derived_value: Variant = profile.get("derived_stats", {})
	var derived: Dictionary = derived_value if derived_value is Dictionary else {}
	var gear_name := "None"
	if run_state.selected_gear != null:
		gear_name = run_state.selected_gear.display_name
	character_menu_panel.sync(run_state, _player_portrait_texture(), gear_name, derived, run_state.get_inventory_items())

func _open_chest_choice_modal() -> void:
	if chest_choice_panel == null or chest_choice_cards == null or run_state == null:
		return
	_hide_hover_context()
	_sync_reward_choice_copy()
	_clear_children_now(chest_choice_cards)
	if reward_choice_source == "progression":
		var pending_choice: Dictionary = run_state.get_pending_progression_choice()
		var choices_value: Variant = pending_choice.get("choices", [])
		if choices_value is Array:
			for choice in choices_value:
				if choice is Dictionary:
					chest_choice_cards.add_child(_make_progression_choice_card(choice))
	else:
		for item_id in run_state.pending_chest_choices:
			chest_choice_cards.add_child(_make_chest_choice_card(String(item_id)))
	if chest_choice_backdrop != null:
		chest_choice_backdrop.visible = true
	chest_choice_panel.visible = true

func _open_pending_progression_choice_if_needed() -> bool:
	if run_state == null or not run_state.has_pending_progression_choice():
		return false
	if chest_choice_panel != null and chest_choice_panel.visible:
		return false
	reward_choice_source = "progression"
	_open_chest_choice_modal()
	return true

func _should_offer_starter_reward() -> bool:
	return run_state != null and not run_state.starter_reward_claimed and _current_floor() == 1

func _offer_starter_reward() -> void:
	reward_choice_source = "starter"
	run_state.generate_chest_choices(_current_floor(), rng)
	message = "Before the first chamber, the forest offers a relic."
	_open_chest_choice_modal()
	_refresh_ui()

func _sync_reward_choice_copy() -> void:
	if chest_choice_title_label == null or chest_choice_subtitle_label == null:
		return
	if reward_choice_source == "starter":
		chest_choice_title_label.text = "Choose Your Opening Relic"
		chest_choice_subtitle_label.text = "Before the first chamber, claim one boon to shape this dungeon run."
	elif reward_choice_source == "progression":
		var pending_choice: Dictionary = run_state.get_pending_progression_choice() if run_state != null else {}
		var choice_type: String = String(pending_choice.get("type", "ability"))
		var level: int = int(pending_choice.get("level", run_state.get_level() if run_state != null else 1))
		var class_type: String = run_state.selected_class_name if run_state != null else "Hero"
		chest_choice_title_label.text = "Choose %s Evolution" % class_type if choice_type == "evolution" else "Choose Ability Upgrade"
		chest_choice_subtitle_label.text = "Level %d unlock. Choose one path; it will persist on this %s." % [level, class_type]
	else:
		chest_choice_title_label.text = "Choose One Relic"
		chest_choice_subtitle_label.text = "The chest opens with three offerings. Claim one boon for the road ahead."

func _make_chest_choice_card(item_id: String) -> PanelContainer:
	var item: Dictionary = GameBalance.get_item(item_id)
	var rarity: String = String(item.get("rarity", "common"))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(246, 398)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_theme_stylebox_override("panel", _reward_card_style())
	card.gui_input.connect(_on_reward_card_gui_input.bind(item_id))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	card.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	margin.add_child(body)

	body.add_child(_make_reward_card_banner(item, rarity))

	var name_label := Label.new()
	var item_name: String = String(item.get("name", item_id))
	name_label.text = item_name.to_upper()
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(0, 50)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_relic_title_style(name_label, item_name)
	body.add_child(name_label)

	body.add_child(_make_reward_ornament(rarity))

	body.add_child(_make_reward_modifier_section(item, rarity))

	var description := Label.new()
	var flavor := String(item.get("description", "A strange relic."))
	var rules_text := String(item.get("rules_text", ""))
	description.text = flavor if rules_text.is_empty() else "%s\n\n%s" % [flavor, rules_text]
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(0, 96)
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_font_size_override("font_size", 10)
	description.add_theme_color_override("font_color", Color(0.82, 0.76, 0.63))
	body.add_child(description)

	var choose_button := Button.new()
	choose_button.text = "Claim Relic"
	choose_button.custom_minimum_size = Vector2(0, 34)
	choose_button.pressed.connect(_choose_chest_reward.bind(item_id))
	_style_reward_choose_button(choose_button, rarity)
	body.add_child(choose_button)
	_make_card_body_click_through(card)
	return card

func _make_progression_choice_card(choice: Dictionary) -> PanelContainer:
	var rarity := "rare"
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(246, 398)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_theme_stylebox_override("panel", _reward_card_style())
	card.gui_input.connect(_on_progression_card_gui_input.bind(String(choice.get("id", ""))))

	var margin := MarginContainer.new()
	card.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)
	body.add_child(_make_progression_card_banner(choice, rarity))

	var name_label := Label.new()
	var choice_name: String = String(choice.get("name", "Mage Upgrade"))
	name_label.text = choice_name.to_upper()
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(0, 64)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_relic_title_style(name_label, choice_name)
	body.add_child(name_label)
	body.add_child(_make_reward_ornament(rarity))
	body.add_child(_make_reward_modifier_section(choice, rarity))

	var description := Label.new()
	description.text = String(choice.get("description", "Your magic changes shape."))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(0, 86)
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_font_size_override("font_size", 10)
	description.add_theme_color_override("font_color", Color(0.82, 0.76, 0.63))
	body.add_child(description)

	var choose_button := Button.new()
	choose_button.text = "Choose"
	choose_button.custom_minimum_size = Vector2(0, 34)
	choose_button.pressed.connect(_choose_progression_reward.bind(String(choice.get("id", ""))))
	_style_reward_choose_button(choose_button, rarity)
	body.add_child(choose_button)
	_make_card_body_click_through(card)
	return card

func _make_progression_card_banner(choice: Dictionary, rarity: String) -> PanelContainer:
	var banner := PanelContainer.new()
	banner.custom_minimum_size = Vector2(0, 36)
	banner.add_theme_stylebox_override("panel", _reward_metadata_style(rarity))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	banner.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)
	var icon := TextureRect.new()
	icon.texture = ICON_SPELL
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)
	var type_label := Label.new()
	var pending_choice: Dictionary = run_state.get_pending_progression_choice() if run_state != null else {}
	type_label.text = "Evolution" if String(pending_choice.get("type", "ability")) == "evolution" else "Ability"
	type_label.add_theme_font_size_override("font_size", 9)
	type_label.add_theme_color_override("font_color", _rarity_color(rarity).lightened(0.06))
	labels.add_child(type_label)
	var level_label := Label.new()
	level_label.text = "Level %d" % int(choice.get("level", 1))
	level_label.add_theme_font_size_override("font_size", 8)
	level_label.add_theme_color_override("font_color", Color(0.86, 0.78, 0.62))
	labels.add_child(level_label)
	var badge := TextureRect.new()
	badge.texture = _rarity_medallion_texture(rarity)
	badge.custom_minimum_size = Vector2(32, 32)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(badge)
	return banner

func _make_reward_card_banner(item: Dictionary, rarity: String) -> PanelContainer:
	var banner := PanelContainer.new()
	banner.custom_minimum_size = Vector2(0, 36)
	banner.add_theme_stylebox_override("panel", _reward_metadata_style(rarity))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	banner.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.texture = _item_icon_texture(String(item.get("icon_key", "special")))
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)
	var rarity_label := Label.new()
	rarity_label.text = _rarity_name(rarity)
	rarity_label.add_theme_font_size_override("font_size", 9)
	rarity_label.add_theme_color_override("font_color", _rarity_color(rarity).lightened(0.06))
	labels.add_child(rarity_label)

	var duration_label := Label.new()
	duration_label.text = _duration_text_for_item(item)
	duration_label.add_theme_font_size_override("font_size", 8)
	duration_label.add_theme_color_override("font_color", Color(0.86, 0.78, 0.62))
	labels.add_child(duration_label)

	var badge := TextureRect.new()
	badge.texture = _rarity_medallion_texture(rarity)
	badge.custom_minimum_size = Vector2(32, 32)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(badge)
	return banner

func _choose_chest_reward(item_id: String) -> void:
	if run_state == null:
		return
	var is_starter_reward: bool = reward_choice_source == "starter"
	var logs: Array[String] = run_state.choose_starter_item(item_id) if is_starter_reward else run_state.choose_chest_item(item_id)
	if not is_starter_reward:
		_clear_claimed_chest()
	message = _append_log_lines("The relic settles into your pack.", logs)
	if chest_choice_backdrop != null:
		chest_choice_backdrop.visible = false
	if chest_choice_panel != null:
		chest_choice_panel.visible = false
	reward_choice_source = "chest"
	if character_menu_panel != null and character_menu_panel.visible:
		_sync_character_menu()
	if is_starter_reward:
		_begin_current_actor_turn()
		message = _append_log_lines(message, logs)
		_refresh_ui()
		return
	_refresh_ui()
	if not is_starter_reward and not _is_free_roam():
		_finish_player_action()

func _clear_claimed_chest() -> void:
	chest = {"pos": Vector2i(-1, -1), "opened": true}

func _has_closed_chest() -> bool:
	return chest.has("pos") and not bool(chest.get("opened", false)) and Vector2i(chest["pos"]) != Vector2i(-1, -1)

func _choose_progression_reward(choice_id: String) -> void:
	if run_state == null:
		return
	var logs: Array[String] = run_state.choose_progression_choice(choice_id)
	message = _append_log_lines("Your spellbook rewrites itself.", logs)
	if chest_choice_backdrop != null:
		chest_choice_backdrop.visible = false
	if chest_choice_panel != null:
		chest_choice_panel.visible = false
	reward_choice_source = "chest"
	if character_menu_panel != null and character_menu_panel.visible:
		_sync_character_menu()
	if _open_pending_progression_choice_if_needed():
		_refresh_ui()
		return
	_refresh_ui()
	if combat_started and not is_player_turn and not is_resolving_enemy_turn:
		_begin_current_actor_turn()
		return
	_finish_turn_if_exhausted()

func _rarity_name(rarity: String) -> String:
	var rarities: Dictionary = GameBalance.get_item_rarities()
	var rarity_value: Variant = rarities.get(rarity, {})
	if rarity_value is Dictionary:
		return String(rarity_value.get("name", rarity.capitalize()))
	return rarity.capitalize()

func _rarity_abbrev(rarity: String) -> String:
	match rarity:
		"common":
			return "C"
		"uncommon":
			return "U"
		"rare":
			return "R"
		"very_rare":
			return "VR"
		"legendary":
			return "L"
	return "?"

func _rarity_medallion_texture(rarity: String) -> Texture2D:
	return ItemRewardCard.rarity_medallion(rarity)

func _rarity_color(rarity: String) -> Color:
	var rarities: Dictionary = GameBalance.get_item_rarities()
	var rarity_value: Variant = rarities.get(rarity, {})
	var color_string := ""
	if rarity_value is Dictionary:
		color_string = String(rarity_value.get("color", ""))
	if not color_string.is_empty():
		return Color.html(color_string)
	match rarity:
		"uncommon":
			return Color(0.44, 0.82, 0.51)
		"rare":
			return Color(0.40, 0.65, 1.0)
		"very_rare":
			return Color(0.76, 0.49, 1.0)
		"legendary":
			return Color(1.0, 0.70, 0.30)
	return Color(0.79, 0.76, 0.67)

func _duration_text(entry: Dictionary) -> String:
	var duration_type: String = String(entry.get("duration_type", "dungeon_bound"))
	match duration_type:
		"temporary":
			var remaining_floors: int = int(entry.get("remaining_floors", 0))
			return "%d Floor%s" % [remaining_floors, "" if remaining_floors == 1 else "s"]
		"dungeon_bound":
			return "This Run"
		"permanent":
			return "Permanent"
	return duration_type.capitalize()

func _duration_text_for_item(item: Dictionary) -> String:
	var duration_type: String = String(item.get("duration_type", "dungeon_bound"))
	match duration_type:
		"temporary":
			var floor_count: int = int(item.get("duration_floors", 2))
			return "%d Floor%s" % [floor_count, "" if floor_count == 1 else "s"]
		"dungeon_bound":
			return "This Run"
		"permanent":
			return "Permanent"
	return duration_type.capitalize()

func _modifier_text(item: Dictionary) -> String:
	var modifiers_value: Variant = item.get("modifiers", {})
	if not (modifiers_value is Dictionary):
		return "No visible effect"
	var modifiers: Dictionary = modifiers_value
	var parts: Array[String] = []
	for key in modifiers.keys():
		var value: int = int(modifiers[key])
		var label: String = _modifier_label(String(key))
		var prefix: String = "+" if value >= 0 else ""
		parts.append("%s%s %s" % [prefix, value, label])
	if parts.is_empty():
		return "No visible effect"
	return ", ".join(parts)

func _modifier_chip_texts(item: Dictionary) -> Array[String]:
	var modifiers_value: Variant = item.get("modifiers", {})
	var chips: Array[String] = []
	if not (modifiers_value is Dictionary):
		return ["No visible effect"]
	var modifiers: Dictionary = modifiers_value
	for key in modifiers.keys():
		var value: int = int(modifiers[key])
		var prefix: String = "+" if value >= 0 else ""
		chips.append("%s%s %s" % [prefix, value, _modifier_label(String(key))])
	if chips.is_empty():
		chips.append("No visible effect")
	return chips

func _modifier_rows(item: Dictionary) -> Array[Dictionary]:
	var modifiers_value: Variant = item.get("modifiers", {})
	var rows: Array[Dictionary] = []
	if modifiers_value is Dictionary:
		var modifiers: Dictionary = modifiers_value
		for key in modifiers.keys():
			var value: int = int(modifiers[key])
			rows.append({
				"value": value,
				"label": _modifier_label(String(key)).to_upper(),
			})
	var flags_value: Variant = item.get("flags", {})
	if flags_value is Dictionary:
		var flags: Dictionary = flags_value
		for key in flags.keys():
			var value: int = int(flags[key])
			rows.append({
				"value": value,
				"label": _progression_flag_label(String(key)).to_upper(),
			})
	return rows

func _modifier_label(stat_id: String) -> String:
	match stat_id:
		"max_health":
			return "Max HP"
		"attack_bonus":
			return "Attack"
		"accuracy": return "Accuracy"
		"penetration": return "Penetration"
		"attack_power": return "Attack Power"
		"spell_potency": return "Spell Potency"
		"armor_class": return "Armor Class"
		"evasion": return "Evasion"
		"threshold": return "Threshold"
		"aegis_all": return "Aegis"
		"aegis_physical": return "Physical Aegis"
		"aegis_fire": return "Fire Aegis"
		"aegis_cold": return "Cold Aegis"
		"aegis_lightning": return "Lightning Aegis"
		"aegis_arcane": return "Arcane Aegis"
		"aegis_radiant": return "Radiant Aegis"
		"aegis_necrotic": return "Necrotic Aegis"
		"aegis_poison": return "Poison Aegis"
		"range": return "Range"
		"spell_power":
			return "Spell"
		"defense":
			return "Defense"
		"initiative_modifier":
			return "Initiative"
		"potion_heal_bonus":
			return "Potion Heal"
		"movement":
			return "Move"
		"block_bonus":
			return "Block"
		"gold_bonus_percent":
			return "Gold%"
		"xp_bonus_percent":
			return "XP%"
	return stat_id.capitalize()

func _progression_flag_label(flag_id: String) -> String:
	match flag_id:
		"fire_shield_retaliate_bonus":
			return "Fire Shield"
		"flamethrower_damage_bonus":
			return "Flame Damage"
		"flamethrower_range_bonus":
			return "Flame Range"
		"shockwave_damage_bonus":
			return "Shock Damage"
		"shockwave_stun_bonus":
			return "Stun"
		"force_blast_push_bonus":
			return "Force Push"
		"force_blast_splash_bonus":
			return "Splash Damage"
		"force_blast_splash_radius_bonus":
			return "Splash Radius"
		"force_blast_range_bonus":
			return "Force Range"
		"charge_damage_bonus":
			return "Charge Damage"
		"charge_range_bonus":
			return "Charge Range"
		"sweep_damage_bonus":
			return "Sweep Damage"
		"sweep_reach_bonus":
			return "Sweep Reach"
		"brace_retaliate_bonus":
			return "Brace Strike"
		"brace_block_bonus":
			return "Brace Block"
	return flag_id.capitalize()

func _item_icon_texture(icon_key: String) -> Texture2D:
	match icon_key:
		"attack":
			return ICON_ATTACK
		"defense":
			return ICON_DEFEND
		"potion", "health":
			return ICON_POTION
		"move":
			return ICON_MOVE
		"gold":
			return ICON_GOLD
		"spell":
			return ICON_SPELL
		"mode":
			return ICON_MODE
	return ICON_SPECIAL

func _make_reward_ornament(rarity: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	row.add_child(_make_reward_rule(rarity))
	var gem := Label.new()
	gem.text = "<>"
	gem.add_theme_font_size_override("font_size", 9)
	gem.add_theme_color_override("font_color", _rarity_color(rarity).lightened(0.10))
	row.add_child(gem)
	row.add_child(_make_reward_rule(rarity))
	return row

func _make_reward_rule(rarity: String) -> ColorRect:
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(54, 1)
	divider.color = _rarity_color(rarity).darkened(0.08)
	return divider

func _make_reward_modifier_section(item: Dictionary, rarity: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.custom_minimum_size = Vector2(0, 72)
	section.add_theme_constant_override("separation", 2)
	var rows: Array[Dictionary] = _modifier_rows(item)
	if rows.is_empty():
		var empty_label := Label.new()
		empty_label.text = "NO VISIBLE EFFECT"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 10)
		empty_label.add_theme_color_override("font_color", Color(0.92, 0.84, 0.68))
		section.add_child(empty_label)
		return section
	if rows.size() == 1:
		var single_value: Variant = rows[0]
		var single_row: Dictionary = single_value if single_value is Dictionary else {}
		section.add_child(_make_reward_primary_modifier(single_row, rarity))
		return section
	for row_value in rows:
		var row_data: Dictionary = row_value if row_value is Dictionary else {}
		section.add_child(_make_reward_modifier_row(row_data, rarity, rows.size()))
	return section

func _make_reward_primary_modifier(row_data: Dictionary, rarity: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(0, 72)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)

	var value: int = int(row_data.get("value", 0))
	var prefix: String = "+" if value >= 0 else ""
	var value_label := Label.new()
	value_label.text = "%s%d" % [prefix, value]
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 30)
	value_label.add_theme_color_override("font_color", _rarity_color(rarity).lightened(0.10))
	column.add_child(value_label)

	var stat_label := Label.new()
	stat_label.text = String(row_data.get("label", "EFFECT"))
	stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stat_label.add_theme_font_size_override("font_size", 13)
	stat_label.add_theme_color_override("font_color", Color(0.96, 0.89, 0.72))
	column.add_child(stat_label)
	return column

func _make_reward_modifier_row(row_data: Dictionary, rarity: String, row_count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	var row_height := 54
	if row_count == 2:
		row_height = 34
	elif row_count > 2:
		row_height = 22
	row.custom_minimum_size = Vector2(0, row_height)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var value_font_size := 25
	var stat_font_size := 13
	if row_count == 2:
		value_font_size = 16
		stat_font_size = 10
	elif row_count > 2:
		value_font_size = 13
		stat_font_size = 8

	var value: int = int(row_data.get("value", 0))
	var prefix: String = "+" if value >= 0 else ""
	var value_label := Label.new()
	value_label.text = "%s%d" % [prefix, value]
	value_label.custom_minimum_size = Vector2(52, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", value_font_size)
	value_label.add_theme_color_override("font_color", _rarity_color(rarity).lightened(0.10))
	row.add_child(value_label)

	var stat_label := Label.new()
	stat_label.text = String(row_data.get("label", "EFFECT"))
	stat_label.clip_text = true
	stat_label.custom_minimum_size = Vector2(112, 0)
	stat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stat_label.add_theme_font_size_override("font_size", stat_font_size)
	stat_label.add_theme_color_override("font_color", Color(0.96, 0.89, 0.72))
	row.add_child(stat_label)
	return row

func _make_reward_chip(text: String, rarity: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.custom_minimum_size = Vector2(0, 30)
	chip.add_theme_stylebox_override("panel", _reward_chip_style(rarity))

	var label := Label.new()
	label.text = text
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.26, 0.15, 0.07))
	chip.add_child(label)
	return chip

func _style_reward_choose_button(button: Button, _rarity: String) -> void:
	FantasyButton.apply_dark(button, 12)

func _reward_modal_style() -> StyleBoxFlat:
	var style := _ornate_style(Color(0.095, 0.062, 0.037, 0.98), Color(0.90, 0.63, 0.28), 2, 7)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 5)
	return style

func _reward_card_style() -> StyleBox:
	return ItemRewardCard.card_style()

func _reward_banner_style(rarity: String) -> StyleBoxFlat:
	var rarity_color: Color = _rarity_color(rarity)
	return _ornate_style(Color(0.16, 0.09, 0.045, 0.96).lerp(rarity_color, 0.15), rarity_color, 1, 4)

func _reward_metadata_style(rarity: String) -> StyleBoxFlat:
	var rarity_color: Color = _rarity_color(rarity)
	return _ornate_style(Color(0.07, 0.055, 0.04, 0.70), rarity_color.darkened(0.08), 1, 4)

func _reward_icon_seal_style(rarity: String) -> StyleBoxFlat:
	var rarity_color: Color = _rarity_color(rarity)
	return _ornate_style(Color(0.86, 0.78, 0.48, 0.90).lerp(rarity_color, 0.12), Color(0.30, 0.16, 0.06), 2, 22)

func _reward_badge_style(rarity: String) -> StyleBoxFlat:
	return _ornate_style(_rarity_color(rarity).lightened(0.12), Color(0.22, 0.12, 0.05), 1, 12)

func _reward_inner_style() -> StyleBox:
	return ItemRewardCard.parchment_style()

func _reward_readable_panel_style(color: Color = Color(0.88, 0.76, 0.51, 0.84), border_color: Color = Color(0.50, 0.30, 0.12), radius: int = 4) -> StyleBoxFlat:
	var style := _ornate_style(color, border_color.darkened(0.12), 1, radius)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 4.0)
	return style

func _reward_chip_style(rarity: String) -> StyleBoxFlat:
	var rarity_color: Color = _rarity_color(rarity)
	return _ornate_style(Color(0.90, 0.78, 0.50, 0.90).lerp(rarity_color, 0.08), Color(0.48, 0.29, 0.12), 1, 4)

func _reward_title_color() -> Color:
	return Color(1.0, 0.90, 0.68)

func _apply_relic_title_style(label: Label, item_name: String) -> void:
	# Font handoff: no fantasy serif is currently checked into the repo.
	# Replace this helper with a Theme variation or FontFile override when one is added.
	var title_size := 17
	if item_name.length() > 22:
		title_size = 15
	if item_name.length() > 30:
		title_size = 13
	label.add_theme_font_size_override("font_size", title_size)
	label.add_theme_color_override("font_color", _reward_title_color())
	label.add_theme_color_override("font_shadow_color", Color(0.08, 0.045, 0.02, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)

func _ornate_style(color: Color, border_color: Color, border_width: int, corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 6.0)
	return style

func _set_button_selected(button: Button, selected: bool) -> void:
	if button == null:
		return
	if selected and not button.disabled:
		button.modulate = Color(1.0, 0.95, 0.68)
	else:
		button.modulate = Color(1.0, 1.0, 1.0)

func _player_portrait_texture() -> Texture2D:
	if run_state != null:
		var class_data := GameBalance.get_base_class(run_state.selected_class_id)
		var texture: Texture2D = load(String(class_data.get("sprite", "")))
		if texture != null:
			return _make_atlas_texture(texture, Rect2(0, 0, 96, 80))
	return _make_atlas_texture(PLAYER_IDLE_DOWN, Rect2(0, 0, 96, 80))

func _actor_portrait_texture(actor: Dictionary) -> Texture2D:
	if String(actor["kind"]) == "player":
		return _player_portrait_texture()
	var enemy_index: int = _enemy_index_by_id(int(actor["id"]))
	if enemy_index != -1:
		match _enemy_type(enemies[enemy_index]):
			"kobold":
				return _make_atlas_texture(KOBOLD_IDLE_SHEET, Rect2(0, 0, 74, 96))
			"skeleton", "armored_skeleton":
				return CRYPT_SKELETON
			"ghoul":
				return CRYPT_GHOUL
			"necromancer":
				return CRYPT_NECROMANCER
			"crypt_boss":
				return CRYPT_BOSS
	return _make_atlas_texture(WOLF_SHEET, Rect2(0, 0, 96, 80))

func _actor_portrait_modulate(actor: Dictionary) -> Color:
	if String(actor["kind"]) != "enemy":
		return Color.WHITE
	var enemy_index: int = _enemy_index_by_id(int(actor["id"]))
	if enemy_index != -1 and _enemy_type(enemies[enemy_index]) == "blood_wolf":
		return Color(1.15, 0.45, 0.45)
	if enemy_index != -1 and _enemy_type(enemies[enemy_index]) == "armored_skeleton":
		return Color(0.88, 0.94, 1.05)
	return Color.WHITE

func _make_atlas_texture(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return atlas

func _short_actor_name(actor: Dictionary) -> String:
	if String(actor["kind"]) == "player":
		return "You"
	var enemy_index: int = _enemy_index_by_id(int(actor["id"]))
	if enemy_index != -1:
		return _enemy_short_name(enemies[enemy_index])
	return String(actor["name"])

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
	if not bool(chest.get("opened", false)):
		_add_marker("LockedChest", chest["pos"], "C", Color(0.63, 0.38, 0.14), "chest")
	if secret["found"]:
		_add_marker("HiddenCache", secret["pos"], "$", Color(0.78, 0.73, 0.43), "secret")
	_add_highlight_markers()
	for i in range(enemies.size()):
		var enemy_piece: BoardPiece = _make_piece("Enemy_%d" % i, enemies[i]["pos"], _enemy_label(enemies[i]), _enemy_color(enemies[i]), BoardPiece.PieceShape.CIRCLE, _enemy_sprite_key(enemies[i]))
		_add_enemy_health_bar(enemy_piece, enemies[i])
		enemies_root.add_child(enemy_piece)
	if _companion_active():
		var companion_piece := _make_piece("BondedWolf", Vector2i(companion["pos"]), "W", Color(0.83, 0.62, 0.24), BoardPiece.PieceShape.CIRCLE, "bonded_wolf")
		_add_enemy_health_bar(companion_piece, companion)
		enemies_root.add_child(companion_piece)
	if not dungeon_merchant.is_empty():
		var merchant_id := String(dungeon_merchant.get("id", dungeon_id))
		var merchant_data := GameBalance.get_merchant(merchant_id)
		var merchant_piece := _make_piece("DungeonMerchant", Vector2i(dungeon_merchant["pos"]), "$", Color(0.76, 0.58, 0.25), BoardPiece.PieceShape.CIRCLE)
		var portrait_path := String(merchant_data.get("portrait", ""))
		if ResourceLoader.exists(portrait_path):
			_set_fitted_piece_sprite(merchant_piece, load(portrait_path), Vector2(38, 44))
			merchant_piece.show_label = false
			merchant_piece.show_panel = false
		enemies_root.add_child(merchant_piece)
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
		"bonded_wolf":
			var wolf_texture: Texture2D = load("res://assets/classes/wolf_companion/sheet.png")
			_set_piece_sprite(piece, wolf_texture, Rect2(0, 0, 96, 80), Vector2(0.58, 0.58))
		"wolf":
			_set_piece_sprite(piece, WOLF_SHEET, Rect2(0, 0, 96, 80), Vector2(0.58, 0.58))
		"blood_wolf":
			_set_piece_sprite(piece, WOLF_SHEET, Rect2(0, 0, 96, 80), Vector2(0.74, 0.74))
			piece.modulate = Color(1.15, 0.45, 0.45)
		"kobold":
			_set_piece_sprite(piece, KOBOLD_IDLE_SHEET, Rect2(0, 0, 74, 96), Vector2(0.50, 0.50))
		"skeleton":
			# Sprite fit targets are presentation-only tile footprints.
			# Replace enemy PNGs freely, then tune these sizes so art stays inside one map tile.
			_set_fitted_piece_sprite(piece, CRYPT_SKELETON, Vector2(28, 31))
		"armored_skeleton":
			_set_fitted_piece_sprite(piece, CRYPT_SKELETON, Vector2(30, 33))
			piece.modulate = Color(0.88, 0.94, 1.05)
		"ghoul":
			_set_fitted_piece_sprite(piece, CRYPT_GHOUL, Vector2(32, 31))
		"necromancer":
			_set_fitted_piece_sprite(piece, CRYPT_NECROMANCER, Vector2(30, 35))
		"crypt_boss":
			_set_fitted_piece_sprite(piece, CRYPT_BOSS, Vector2(36, 36))
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
		clampf(target_size.x, 8.0, tile_size),
		clampf(target_size.y, 8.0, tile_size)
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
	var bar_width: float = clampf(tile_size * 0.62, 24.0, 34.0)
	var bar_height: float = 2.0
	var max_health: int = max(1, int(enemy.get("max_health", 4)))
	var current_health: int = clampi(int(enemy.get("hp", max_health)), 0, max_health)
	var health_ratio: float = float(current_health) / float(max_health)
	var fill_width: float = 0.0 if current_health <= 0 else maxf(1.0, floorf(bar_width * health_ratio))

	var bar_root := Node2D.new()
	bar_root.name = "HealthBar"
	bar_root.position = Vector2(-bar_width * 0.5, -tile_size * 0.38)

	var background := ColorRect.new()
	background.name = "Background"
	background.position = Vector2.ZERO
	background.size = Vector2(bar_width, bar_height)
	background.color = Color(0.10, 0.02, 0.02, 0.62)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_root.add_child(background)

	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.position = Vector2.ZERO
	fill.size = Vector2(fill_width, bar_height)
	fill.color = Color(0.86, 0.08, 0.06, 0.90)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_root.add_child(fill)

	piece.add_child(bar_root)

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
		_apply_flat_ui_button(button, 13, Vector2(0, 38))

func _action_buttons() -> Array[Button]:
	return [move_button, interact_button, special_button, potion_button, defend_button, end_turn_button, cancel_action_button]

func _on_reward_card_gui_input(event: InputEvent, item_id: String) -> void:
	if reward_choice_source == "progression":
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_choose_chest_reward(item_id)

func _on_progression_card_gui_input(event: InputEvent, choice_id: String) -> void:
	if reward_choice_source != "progression":
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_choose_progression_reward(choice_id)

func _make_card_body_click_through(node: Node) -> void:
	for child in node.get_children():
		if child is Control and not (child is Button):
			var control: Control = child
			control.mouse_filter = Control.MOUSE_FILTER_PASS if child is Container else Control.MOUSE_FILTER_IGNORE
		_make_card_body_click_through(child)

func _apply_flat_ui_button(button: Button, font_size: int, minimum_size: Vector2) -> void:
	if minimum_size != Vector2.ZERO:
		button.custom_minimum_size = minimum_size
	button.add_theme_stylebox_override("normal", _button_flat_style(Color(0.11, 0.085, 0.055, 0.86), Color(0.58, 0.39, 0.17), 1))
	button.add_theme_stylebox_override("hover", _button_flat_style(Color(0.18, 0.13, 0.075, 0.94), Color(0.86, 0.62, 0.26), 1))
	button.add_theme_stylebox_override("pressed", _button_flat_style(Color(0.27, 0.18, 0.08, 0.98), Color(1.0, 0.76, 0.36), 2))
	button.add_theme_stylebox_override("focus", _button_flat_style(Color(0.15, 0.10, 0.055, 0.92), Color(0.96, 0.78, 0.42), 1))
	button.add_theme_stylebox_override("disabled", _button_flat_style(Color(0.07, 0.06, 0.05, 0.62), Color(0.24, 0.20, 0.16), 1))
	button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.74))
	button.add_theme_color_override("font_pressed_color", Color(0.82, 0.68, 0.42))
	button.add_theme_color_override("font_disabled_color", Color(0.50, 0.46, 0.38))
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_constant_override("h_separation", 4)

func _button_flat_style(color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := _flat_style(color, 4, border_color)
	style.set_border_width_all(border_width)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 5.0)
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
		"width": grid_w,
		"height": grid_h,
		"floor_cells": floor_cells.keys(),
		"player": player_pos,
		"exit": exit_pos,
		"enemies": enemy_tiles,
		"props": prop_tiles,
		"loot": loot_tiles,
		"traps": trap_tiles,
		"chest": chest["pos"] if _has_closed_chest() else Vector2i(-1, -1),
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
		var room_index: int = int(room_ids[rng.randi_range(0, room_ids.size() - 1)])
		var room_value: Variant = room_graph[room_index]
		var room: Dictionary = room_value if room_value is Dictionary else {}
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
	if chest.has("pos") and not bool(chest.get("opened", false)) and tile == chest["pos"]:
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
	var chest_blocks: bool = chest.has("pos") and not bool(chest.get("opened", false)) and tile == chest["pos"]
	var companion_blocks := _companion_active() and Vector2i(companion["pos"]) == tile
	var merchant_blocks := not dungeon_merchant.is_empty() and Vector2i(dungeon_merchant["pos"]) == tile
	return floor_cells.has(tile) and _prop_at(tile) == -1 and not chest_blocks and _enemy_at(tile) == -1 and not companion_blocks and not merchant_blocks

func _companion_active() -> bool:
	return not companion.is_empty() and int(companion.get("hp", 0)) > 0 and companion.has("pos")

func _damage_companion(amount: int) -> int:
	if not _companion_active(): return 0
	var reduction := 1 if _distance(Vector2i(companion["pos"]), player_pos) == 1 else 0
	var applied := maxi(0, amount - reduction)
	companion["hp"] = maxi(0, int(companion["hp"]) - applied)
	if int(companion["hp"]) <= 0:
		companion.clear()
	return amount

func _companion_attack_marked(pounce: bool = false) -> bool:
	if not _companion_active(): return false
	var index := _enemy_index_by_id(marked_enemy_id)
	if index == -1: return false
	var target: Vector2i = enemies[index]["pos"]
	var wolf_pos: Vector2i = companion["pos"]
	if pounce and _distance(wolf_pos, target) <= 4:
		companion["pos"] = _nearest_open_adjacent(target)
	elif _distance(wolf_pos, target) > 1:
		var next := _step_toward(wolf_pos, target)
		if next != wolf_pos: companion["pos"] = next
	if _distance(Vector2i(companion["pos"]), target) == 1:
		# The override identifies this as Mark / Command for data-driven bonuses.
		_attack_enemy(index, 3 if pounce else 2, "physical", "coordinated_basic")
		run_state.gain_class_resource()
		return true
	return pounce

func _nearest_open_adjacent(origin: Vector2i) -> Vector2i:
	for direction in _eight_directions():
		var tile := origin + direction
		if _is_walkable(tile): return tile
	return Vector2i(companion.get("pos", player_pos))

func _nearest_open_tile(origin: Vector2i) -> Vector2i:
	for direction in _eight_directions():
		var tile := origin + direction
		if _is_walkable(tile): return tile
	return origin

func _adjacent_enemy_count(origin: Vector2i) -> int:
	var count := 0
	for enemy in enemies:
		if _distance(origin, Vector2i(enemy["pos"])) == 1: count += 1
	return count

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
	return Vector2i(floori(local.x / float(tile_size)), floori(local.y / float(tile_size)))

func _viewport_to_world(pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * pos

func _grid_to_viewport_screen(tile: Vector2i) -> Vector2:
	return get_viewport().get_canvas_transform() * _grid_to_screen(tile)

func _grid_to_screen(tile: Vector2i) -> Vector2:
	return ORIGIN + Vector2(tile) * tile_size

func _grid_center(tile: Vector2i) -> Vector2:
	return _grid_to_screen(tile) + Vector2(tile_size, tile_size) * 0.5

func _is_inside_grid(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < grid_w and tile.y < grid_h

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
	if layout_type.begins_with("boss_"):
		return "Floor %d/%d: %s waits beyond the roots." % [_current_floor(), _max_floors(), boss_chamber_name]
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

func _layout_display_name() -> String:
	if layout_type.begins_with("boss_"):
		return "%s boss chamber" % boss_chamber_name
	return "%s layout" % layout_type.capitalize()

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
