extends Node2D

const TILE_SIZE := 48
const GRID_W := 12
const GRID_H := 7
const ORIGIN := Vector2(64, 138)
const ATLAS_TILE_SIZE := Vector2i(32, 32)
const TILESCALE := 1.5
const WOOD_TILE_SIZE := Vector2i(1254, 1254)
const WOOD_TILESCALE := 0.03827751
const BoardPieceScene := preload("res://scenes/components/BoardPiece.tscn")
const PLAYER_IDLE_DOWN := preload("res://assets/sprite_packs/Player/IDLE/idle_down.png")
const TAVERN_KEEPER := preload("res://assets/generated_characters/tavern_keeper.png")
const TAVERN_FLOOR_ATLAS := preload("res://assets/generated_maps/tavern_floor_wood.png")
const WOODEN_EXIT_DOOR := preload("res://assets/generated_ui/wooden_exit_door.png")
const STRUCT_ATLAS := preload("res://assets/pixel_art/TX Struct.png")
const PROPS_ATLAS := preload("res://assets/pixel_art/TX Props.png")

var controller: Node
var run_state: RunState
var gear_options: Array[GearData] = []
var selected_gear: GearData
var player_pos := Vector2i(3, 5)
var bartender_pos := Vector2i(6, 2)
var door_pos := Vector2i(10, 2)
var crypt_door_pos := Vector2i(10, 4)
var message := ""

@onready var ground_layer: TileMapLayer = $Board/GroundLayer
@onready var wall_layer: TileMapLayer = $Board/WallLayer
@onready var fixture_layer: TileMapLayer = $Board/FixtureLayer
@onready var prop_sprites: Node2D = $Board/PropSprites
@onready var tokens_root: Node2D = $Board/Tokens
@onready var gear_desk_sprite: Sprite2D = $Board/PropSprites/GearDeskSprite
@onready var player_token: BoardPiece = $Board/Tokens/PlayerToken
@onready var bartender_token: BoardPiece = $Board/Tokens/BartenderToken
@onready var gear_rack_token: BoardPiece = $Board/Tokens/GearRackToken
@onready var forest_door_token: BoardPiece = $Board/Tokens/ForestDoorToken
@onready var ui_root: Control = $UI/Root
@onready var status_label: Label = $UI/Root/StatusLabel
@onready var detail_label: Label = $UI/Root/DialoguePanel/DetailLabel
@onready var title_label: Label = $UI/Root/TitleLabel
@onready var dialogue_panel: Panel = $UI/Root/DialoguePanel
@onready var speaker_label: Label = $UI/Root/DialoguePanel/SpeakerLabel
@onready var dialogue_label: Label = $UI/Root/DialoguePanel/DialogueLabel
@onready var gear_title_label: Label = $UI/Root/DialoguePanel/GearTitleLabel
@onready var gear_box: VBoxContainer = $UI/Root/DialoguePanel/GearButtons
@onready var enter_button: Button = $UI/Root/DialoguePanel/EnterForestButton
var gear_options_panel: PanelContainer
var crypt_door_token: BoardPiece

func setup(game_controller: Node, state: RunState, options: Array[GearData], intro_message: String) -> void:
	controller = game_controller
	run_state = state
	gear_options = options
	message = intro_message
	selected_gear = _remembered_gear_or_default()
	if run_state != null and selected_gear != null:
		run_state.set_selected_gear(selected_gear)
	if is_inside_tree():
		_refresh_ui()

func _ready() -> void:
	title_label.add_theme_font_size_override("font_size", 28)
	gear_title_label.add_theme_font_size_override("font_size", 20)
	speaker_label.add_theme_font_size_override("font_size", 18)
	enter_button.pressed.connect(_enter_forest)
	_style_dialogue_panel()
	_setup_gear_options_panel()
	_style_button(enter_button)
	_setup_crypt_door_token()
	_build_tavern_tilemaps()
	_position_tavern_sprites()
	_configure_token_sprites()
	_update_token_positions()
	_refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("move_up"):
		_try_move(Vector2i.UP)
	elif event.is_action_pressed("move_down"):
		_try_move(Vector2i.DOWN)
	elif event.is_action_pressed("move_left"):
		_try_move(Vector2i.LEFT)
	elif event.is_action_pressed("move_right"):
		_try_move(Vector2i.RIGHT)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var tile := _screen_to_grid(event.position)
		if _is_inside_grid(tile):
			_handle_tile_click(tile)

func _refresh_ui() -> void:
	if status_label == null:
		return
	if crypt_door_token != null and run_state != null:
		crypt_door_token.modulate = Color(0.55, 0.56, 0.68) if run_state.is_crypt_unlocked() else Color(0.28, 0.28, 0.32)
	var gear_name := "None"
	if selected_gear != null:
		gear_name = selected_gear.display_name
	status_label.text = "Runs completed: %d  Deaths: %d\nSelected: %s" % [
		run_state.completed_runs if run_state != null else 0,
		run_state.deaths if run_state != null else 0,
		gear_name,
	]
	if run_state != null:
		status_label.text = "%s\n%s" % [status_label.text, run_state.get_profile_summary()]
		var crypt_state: String = "Crypt: Unlocked" if run_state.is_crypt_unlocked() else "Crypt: Locked - clear Forest and reach Lv 5"
		status_label.text = "%s\n%s" % [status_label.text, crypt_state]
		var evolution_name: String = run_state.get_current_evolution_name()
		if not evolution_name.is_empty():
			status_label.text = "%s\nPath: %s" % [status_label.text, evolution_name]
	dialogue_label.text = message
	if selected_gear != null:
		var stat_damage: int = selected_gear.damage
		if run_state != null:
			var damage_bonus: int = run_state.get_derived_stat(_class_damage_stat())
			stat_damage += damage_bonus
		detail_label.text = "%s | %d dmg\n%s" % [
			selected_gear.display_name,
			stat_damage,
			selected_gear.description,
		]
	_populate_gear_buttons()

func _setup_gear_options_panel() -> void:
	if ui_root == null or gear_options_panel != null:
		return
	gear_options_panel = PanelContainer.new()
	gear_options_panel.name = "GearOptionsPanel"
	gear_options_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	gear_options_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gear_options_panel.offset_left = -560
	gear_options_panel.offset_top = 18
	gear_options_panel.offset_right = -24
	gear_options_panel.offset_bottom = 258
	gear_options_panel.add_theme_stylebox_override("panel", _tavern_panel_style())
	ui_root.add_child(gear_options_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	gear_options_panel.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)

	# UI handoff: these controls are authored in the tavern scene for now, but
	# the runtime panel owns their placement so future tavern layout passes can
	# move the gear/spell selector without changing reward or run-start logic.
	_move_control_to_parent(gear_title_label, body)
	_move_control_to_parent(detail_label, body)
	_move_control_to_parent(gear_box, body)
	_move_control_to_parent(enter_button, body)

	gear_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_label.custom_minimum_size = Vector2(0, 52)
	detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gear_box.custom_minimum_size = Vector2(0, 90)
	gear_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enter_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _move_control_to_parent(control: Control, new_parent: Control) -> void:
	var old_parent: Node = control.get_parent()
	if old_parent != null:
		old_parent.remove_child(control)
	new_parent.add_child(control)
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0

func _populate_gear_buttons() -> void:
	if gear_box == null:
		return
	for child in gear_box.get_children():
		child.queue_free()
	for gear in gear_options:
		var button := Button.new()
		var shown_damage: int = gear.damage
		if run_state != null:
			var damage_bonus: int = run_state.get_derived_stat(_class_damage_stat())
			shown_damage += damage_bonus
		button.text = "%s  (%d dmg)" % [gear.display_name, shown_damage]
		button.toggle_mode = true
		button.button_pressed = selected_gear == gear
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_gear.bind(gear))
		_style_button(button)
		gear_box.add_child(button)

func _select_gear(gear: GearData) -> void:
	selected_gear = gear
	if run_state != null:
		run_state.set_selected_gear(gear)
	var class_type: String = run_state.selected_class_name if run_state != null else "Warrior"
	message = "The bartender nods. '%s. A fair answer for a %s.'" % [gear.display_name, class_type]

func _class_damage_stat() -> String:
	if run_state != null and run_state.selected_class_id in ["mage", "healer", "summoner"]:
		return "spell_potency"
	return "attack_power"
	_refresh_ui()

func _remembered_gear_or_default() -> GearData:
	if run_state != null and run_state.selected_gear != null:
		for gear in gear_options:
			if gear == run_state.selected_gear:
				return gear
			if gear.id == run_state.selected_gear.id:
				return gear
	if gear_options.size() > 0:
		return gear_options[0]
	return null

func _handle_tile_click(tile: Vector2i) -> void:
	if tile == player_pos:
		_interact()
		return
	var delta := tile - player_pos
	if abs(delta.x) + abs(delta.y) == 1:
		if tile == bartender_pos or tile == door_pos or tile == crypt_door_pos:
			_interact()
		else:
			_try_move(delta)

func _try_move(delta: Vector2i) -> void:
	var target := player_pos + delta
	if not _is_inside_grid(target):
		return
	if target == bartender_pos:
		message = "The bartender says, '%s'" % _selection_prompt()
	elif target == door_pos:
		_enter_forest()
	elif target == crypt_door_pos:
		_enter_crypt()
	else:
		player_pos = target
	_update_token_positions()
	_refresh_ui()

func _interact() -> void:
	if _is_adjacent(player_pos, bartender_pos):
		message = "The bartender says, '%s'" % _selection_prompt()
	elif _is_adjacent(player_pos, Vector2i(2, 2)):
		message = "The class armory presents equipment suited to %s." % run_state.selected_class_name
	elif _is_adjacent(player_pos, door_pos):
		_enter_forest()
	elif _is_adjacent(player_pos, crypt_door_pos):
		_enter_crypt()
	else:
		message = "The tavern floorboards creak. Somewhere, a contract waits."
	_refresh_ui()

func _enter_forest() -> void:
	if controller == null or selected_gear == null:
		return
	controller.start_forest(selected_gear)

func _enter_crypt() -> void:
	if controller == null or selected_gear == null or run_state == null:
		return
	if not run_state.is_crypt_unlocked():
		message = "The crypt door is sealed. Clear the Forest Dungeon and reach level 5."
		_refresh_ui()
		return
	controller.start_crypt(selected_gear)

func _selection_prompt() -> String:
	if _selected_class_id() == "mage":
		return "Choose a spell book, then make the forest answer in kind."
	return "Pick a blade, then let the forest judge your footwork."

func _selected_class_id() -> String:
	if run_state == null:
		return "warrior"
	return run_state.selected_class_id

func _build_tavern_tilemaps() -> void:
	var wall_tiles: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(2, 0),
		Vector2i(3, 0),
	]
	var fixture_tiles: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(2, 0),
		Vector2i(3, 0),
		Vector2i(4, 0),
		Vector2i(5, 0),
		Vector2i(6, 0),
	]
	_setup_layer(ground_layer, TAVERN_FLOOR_ATLAS, [Vector2i.ZERO], WOOD_TILE_SIZE, WOOD_TILESCALE)
	_setup_layer(wall_layer, STRUCT_ATLAS, wall_tiles)
	_setup_layer(fixture_layer, PROPS_ATLAS, fixture_tiles)

	for y in range(GRID_H):
		for x in range(GRID_W):
			ground_layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)

	for x in range(GRID_W):
		wall_layer.set_cell(Vector2i(x, 0), 0, wall_tiles[0])
		wall_layer.set_cell(Vector2i(x, GRID_H - 1), 0, wall_tiles[1])
	for y in range(GRID_H):
		wall_layer.set_cell(Vector2i(0, y), 0, wall_tiles[2])
		wall_layer.set_cell(Vector2i(GRID_W - 1, y), 0, wall_tiles[3])

	_paint_rect(fixture_layer, Rect2i(4, 1, 5, 1), Vector2i(0, 0))
	_paint_rect(fixture_layer, Rect2i(2, 3, 2, 2), Vector2i(1, 0))
	_paint_rect(fixture_layer, Rect2i(8, 4, 2, 1), Vector2i(2, 0))
	_paint_rect(fixture_layer, Rect2i(5, 5, 3, 1), Vector2i(2, 0))
	fixture_layer.set_cell(Vector2i(2, 2), 0, Vector2i(4, 0))

func _setup_layer(
	layer: TileMapLayer,
	texture: Texture2D,
	atlas_tiles: Array[Vector2i],
	tile_size: Vector2i = ATLAS_TILE_SIZE,
	tile_scale: float = TILESCALE
) -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = tile_size
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = tile_size
	for tile in atlas_tiles:
		source.create_tile(tile)
	tile_set.add_source(source, 0)
	layer.tile_set = tile_set
	layer.position = ORIGIN
	layer.scale = Vector2(tile_scale, tile_scale)
	layer.clear()

func _paint_rect(layer: TileMapLayer, rect: Rect2i, atlas_tile: Vector2i) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			layer.set_cell(Vector2i(x, y), 0, atlas_tile)

func _position_tavern_sprites() -> void:
	gear_desk_sprite.position = _grid_center(Vector2i(2, 3)) + Vector2(0, 2)
	gear_desk_sprite.scale = Vector2(0.085, 0.085)
	gear_desk_sprite.modulate = Color(0.95, 0.82, 0.58, 0.90)

func _setup_crypt_door_token() -> void:
	if tokens_root == null or crypt_door_token != null:
		return
	crypt_door_token = BoardPieceScene.instantiate()
	crypt_door_token.name = "CryptDoorToken"
	tokens_root.add_child(crypt_door_token)

func _configure_token_sprites() -> void:
	player_token.sprite_texture = PLAYER_IDLE_DOWN
	player_token.sprite_region_enabled = true
	player_token.sprite_region = Rect2(0, 0, 96, 80)
	player_token.sprite_scale = Vector2(0.62, 0.62)
	player_token.show_label = false
	player_token.show_panel = false

	bartender_token.sprite_texture = TAVERN_KEEPER
	bartender_token.sprite_region_enabled = false
	bartender_token.sprite_scale = Vector2(0.036, 0.036)
	bartender_token.show_label = false
	bartender_token.show_panel = false

	gear_rack_token.shape = BoardPiece.PieceShape.SQUARE
	gear_rack_token.size = Vector2(42, 42)
	gear_rack_token.sprite_texture = PROPS_ATLAS
	gear_rack_token.sprite_region_enabled = true
	gear_rack_token.sprite_region = Rect2(4 * ATLAS_TILE_SIZE.x, 0, ATLAS_TILE_SIZE.x, ATLAS_TILE_SIZE.y)
	gear_rack_token.sprite_scale = Vector2(1.25, 1.25)
	gear_rack_token.show_label = false
	gear_rack_token.show_panel = false

	forest_door_token.shape = BoardPiece.PieceShape.SQUARE
	forest_door_token.size = Vector2(42, 48)
	forest_door_token.sprite_texture = WOODEN_EXIT_DOOR
	forest_door_token.sprite_region_enabled = false
	forest_door_token.sprite_scale = Vector2(0.80, 0.80)
	forest_door_token.show_label = false
	forest_door_token.show_panel = false

	if crypt_door_token != null:
		crypt_door_token.shape = BoardPiece.PieceShape.SQUARE
		crypt_door_token.size = Vector2(42, 48)
		crypt_door_token.sprite_texture = WOODEN_EXIT_DOOR
		crypt_door_token.sprite_region_enabled = false
		crypt_door_token.sprite_scale = Vector2(0.80, 0.80)
		crypt_door_token.show_label = false
		crypt_door_token.show_panel = false
		crypt_door_token.modulate = Color(0.55, 0.56, 0.68) if run_state != null and run_state.is_crypt_unlocked() else Color(0.28, 0.28, 0.32)

func _update_token_positions() -> void:
	if player_token == null:
		return
	player_token.position = _grid_center(player_pos)
	bartender_token.position = _grid_center(bartender_pos)
	gear_rack_token.position = _grid_center(Vector2i(2, 2))
	forest_door_token.position = _grid_center(door_pos)
	if crypt_door_token != null:
		crypt_door_token.position = _grid_center(crypt_door_pos)

func _screen_to_grid(pos: Vector2) -> Vector2i:
	var local := pos - ORIGIN
	return Vector2i(floori(local.x / TILE_SIZE), floori(local.y / TILE_SIZE))

func _grid_to_screen(tile: Vector2i) -> Vector2:
	return ORIGIN + Vector2(tile) * TILE_SIZE

func _grid_center(tile: Vector2i) -> Vector2:
	return _grid_to_screen(tile) + Vector2(TILE_SIZE, TILE_SIZE) * 0.5

func _style_dialogue_panel() -> void:
	dialogue_panel.add_theme_stylebox_override("panel", _tavern_panel_style())

func _tavern_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.045, 0.92)
	style.border_color = Color(0.62, 0.43, 0.24)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin(SIDE_LEFT, 12)
	style.set_content_margin(SIDE_RIGHT, 12)
	style.set_content_margin(SIDE_TOP, 10)
	style.set_content_margin(SIDE_BOTTOM, 10)
	return style

func _style_button(button: Button) -> void:
	FantasyButton.apply_light(button, 15, Vector2(260, 34))

func _is_inside_grid(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < GRID_W and tile.y < GRID_H

func _is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return abs(a.x - b.x) + abs(a.y - b.y) <= 1
