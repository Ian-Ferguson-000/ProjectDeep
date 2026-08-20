extends Node2D

const TILE_SIZE := 48
const GRID_W := 16
const GRID_H := 11
const ORIGIN := Vector2(48, 92)
const BoardPieceScene := preload("res://scenes/components/BoardPiece.tscn")
const PLAYER_IDLE_DOWN := preload("res://assets/sprite_packs/Player/IDLE/idle_down.png")
const WOLF_SHEET := preload("res://assets/enemies/feral_wolf/normalized_sheet.png")
const GRASS_ATLAS := preload("res://assets/pixel_art/TX Tileset Grass.png")
const PROPS_ATLAS := preload("res://assets/pixel_art/TX Props.png")
const STRUCT_ATLAS := preload("res://assets/pixel_art/TX Struct.png")
const PLANT_ATLAS := preload("res://assets/pixel_art/TX Plant.png")
const UI_BUTTON_NORMAL := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/4 Buttons/1.png")
const UI_BUTTON_HOVER := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/4 Buttons/2.png")
const UI_BUTTON_PRESSED := preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/4 Buttons/3.png")
const ATLAS_TILE_SIZE := 32
const GRASS_TILE_SIZE := Vector2i(32, 32)
const GRASS_TILE_SCALE := 1.5
const GRASS_SOURCE_ID := 0

var controller: Node
var run_state: RunState
var rng := RandomNumberGenerator.new()
var grass_tile_set: TileSet

var floor_cells := {}
var critical_path := {}
var player_pos := Vector2i(2, 8)
var exit_pos := Vector2i(14, 2)
var facing := Vector2i.RIGHT
var block_stacks := 0
var braced := false

var enemies: Array[Dictionary] = []
var props: Array[Dictionary] = []
var loot: Array[Dictionary] = []
var traps: Array[Dictionary] = []
var chest := {"pos": Vector2i(10, 4), "opened": false}
var secret := {"pos": Vector2i(6, 7), "found": false}

var message := "The forest arranges itself into a dangerous little board."

@onready var markers_root: Node2D = $Board/Markers
@onready var ground_layer: TileMapLayer = $Board/Tiles
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

func setup(game_controller: Node, state: RunState) -> void:
	controller = game_controller
	run_state = state
	if run_state != null and run_state.selected_gear != null:
		block_stacks = run_state.selected_gear.block_limit
	if is_inside_tree():
		_generate()
		_refresh_ui()

func _ready() -> void:
	title_label.add_theme_font_size_override("font_size", 24)
	_style_health_bar()
	_style_action_buttons()
	special_button.pressed.connect(_use_special)
	interact_button.pressed.connect(_interact)
	potion_button.pressed.connect(_drink_potion)
	exit_door.door_entered.connect(_on_exit_door_entered)
	_generate()
	_build_board_tiles()
	_configure_player_sprite()
	_refresh_ui()

func _generate() -> void:
	if floor_cells.size() > 0:
		return
	var seed_value := 1001
	if run_state != null:
		seed_value = run_state.floor_seed
	rng.seed = seed_value

	var centers := [Vector2i(2, 8), Vector2i(5, 8), Vector2i(8, 6), Vector2i(11, 4), Vector2i(14, 2)]
	for center in centers:
		_carve_room(center, rng.randi_range(2, 3), rng.randi_range(1, 2))
	for i in range(centers.size() - 1):
		_carve_corridor(centers[i], centers[i + 1])

	player_pos = centers[0]
	exit_pos = centers[centers.size() - 1]
	chest = {"pos": _pick_floor_cell(true), "opened": false}
	secret = {"pos": _pick_floor_cell(true), "found": false}

	_place_props()
	_place_loot()
	_place_traps()
	_place_enemies()

func _carve_room(center: Vector2i, radius_x: int, radius_y: int) -> void:
	for y in range(center.y - radius_y, center.y + radius_y + 1):
		for x in range(center.x - radius_x, center.x + radius_x + 1):
			var tile := Vector2i(x, y)
			if _is_inside_grid(tile):
				floor_cells[tile] = true

func _carve_corridor(a: Vector2i, b: Vector2i) -> void:
	var x_step := 1 if b.x >= a.x else -1
	for x in range(a.x, b.x + x_step, x_step):
		var tile := Vector2i(x, a.y)
		floor_cells[tile] = true
		critical_path[tile] = true
	var y_step := 1 if b.y >= a.y else -1
	for y in range(a.y, b.y + y_step, y_step):
		var tile := Vector2i(b.x, y)
		floor_cells[tile] = true
		critical_path[tile] = true

func _place_props() -> void:
	var kinds := ["rock", "barrel", "rock", "barrel", "campfire"]
	for kind in kinds:
		props.append({"kind": kind, "pos": _pick_floor_cell(false), "hp": 2 if kind != "campfire" else 99})

func _place_loot() -> void:
	loot.append({"kind": "gold", "pos": _pick_floor_cell(true), "amount": 7})
	loot.append({"kind": "potion", "pos": _pick_floor_cell(true), "amount": 1})
	loot.append({"kind": "key", "pos": _pick_floor_cell(true), "amount": 1})

func _place_traps() -> void:
	traps.append({"pos": _pick_floor_cell(true), "sprung": false})

func _place_enemies() -> void:
	for i in range(3):
		enemies.append({"kind": "wolf", "pos": _pick_floor_cell(true), "hp": 4, "max_health": 4, "damage": 2})

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("special"):
		_use_special()
	elif event.is_action_pressed("interact"):
		_interact()
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
		var tile := _screen_to_grid(event.position)
		if _is_inside_grid(tile):
			_handle_tile_click(tile)

func _take_directional_action(delta: Vector2i) -> void:
	facing = delta
	_handle_tile_click(player_pos + delta)

func _handle_tile_click(tile: Vector2i) -> void:
	var distance := _distance(player_pos, tile)
	if distance != 1:
		message = "That is too far for one careful step."
		_refresh_ui()
		return
	facing = tile - player_pos
	var enemy_index := _enemy_at(tile)
	if enemy_index != -1:
		_attack_enemy(enemy_index, run_state.selected_gear.damage)
		_end_player_action()
	elif _prop_at(tile) != -1:
		_hit_prop(_prop_at(tile))
		_end_player_action()
	elif tile == chest["pos"]:
		_open_chest()
		_end_player_action()
	elif tile == exit_pos:
		_complete_floor()
	elif _is_walkable(tile):
		player_pos = tile
		_resolve_tile()
		_end_player_action()
	else:
		message = "Dense trees block the way."
	_refresh_ui()

func _interact() -> void:
	if _distance(player_pos, exit_pos) == 1:
		_complete_floor()
		return
	if _distance(player_pos, chest["pos"]) == 1:
		_open_chest()
		_end_player_action()
		return
	if _distance(player_pos, secret["pos"]) <= 1 and not secret["found"]:
		secret["found"] = true
		run_state.gold += 9
		run_state.potions += 1
		message = "You brush aside leaves and find a hidden cache: 9 gold and a potion."
		_end_player_action()
		return
	for i in range(props.size()):
		if _distance(player_pos, props[i]["pos"]) == 1:
			if props[i]["kind"] == "campfire":
				run_state.heal(2)
				message = "The campfire steadies you. Restored 2 health."
			else:
				_hit_prop(i)
			_end_player_action()
			return
	message = "You find bark, moss, and nothing willing to confess."
	_refresh_ui()

func _use_special() -> void:
	if run_state == null or run_state.selected_gear == null:
		return
	match run_state.selected_gear.special_id:
		"charge":
			_special_charge()
		"sweep":
			_special_sweep()
		"brace":
			braced = true
			message = "You brace. The next enemy that closes in gets punished first."
			_end_player_action()
		_:
			message = "This gear has no special yet."
	_refresh_ui()

func _special_charge() -> void:
	var cursor := player_pos
	for step in range(3):
		cursor += facing
		if not _is_walkable(cursor) and _enemy_at(cursor) == -1:
			break
		var enemy_index := _enemy_at(cursor)
		if enemy_index != -1:
			_attack_enemy(enemy_index, run_state.selected_gear.damage + 1)
			message = "You charge through the brush and crash into an enemy."
			_end_player_action()
			return
		player_pos = cursor
	message = "You charge forward, finding only leaves and momentum."
	_resolve_tile()
	_end_player_action()

func _special_sweep() -> void:
	var hit_count := 0
	for i in range(enemies.size() - 1, -1, -1):
		if _distance(player_pos, enemies[i]["pos"]) == 1:
			_attack_enemy(i, run_state.selected_gear.damage)
			hit_count += 1
	if hit_count == 0:
		message = "You sweep the greatsword through empty air."
	else:
		message = "Your greatsword sweep catches %d foe%s." % [hit_count, "" if hit_count == 1 else "s"]
	_end_player_action()

func _drink_potion() -> void:
	if run_state.potions <= 0:
		message = "No potion waits at your belt."
	else:
		run_state.potions -= 1
		run_state.heal(5)
		message = "You drink a potion and recover 5 health."
		_end_player_action()
	_refresh_ui()

func _attack_enemy(index: int, damage: int) -> void:
	var enemy := enemies[index]
	enemy["hp"] -= damage
	if enemy["hp"] <= 0:
		message = "The forest token falls. You gain 3 gold."
		run_state.gold += 3
		enemies.remove_at(index)
	else:
		enemies[index] = enemy
		message = "Hit for %d. The enemy has %d health left." % [damage, enemy["hp"]]

func _hit_prop(index: int) -> void:
	var prop := props[index]
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
			match item["kind"]:
				"gold":
					run_state.gold += item["amount"]
					message = "Picked up %d gold." % item["amount"]
				"potion":
					run_state.potions += 1
					message = "Picked up a potion."
				"key":
					run_state.keys += 1
					message = "Picked up a key."
			loot.erase(item)
	for trap in traps:
		if trap["pos"] == player_pos and not trap["sprung"]:
			trap["sprung"] = true
			_apply_damage(3)
			message = "A root-snare trap snaps shut for 3 damage."

func _end_player_action() -> void:
	if run_state.current_health <= 0:
		_die()
		return
	_enemy_turn()
	if run_state.current_health <= 0:
		_die()

func _enemy_turn() -> void:
	var i := 0
	while i < enemies.size():
		var enemy := enemies[i]
		if enemy["hp"] <= 0:
			i += 1
			continue
		if _distance(enemy["pos"], player_pos) == 1:
			if _brace_hits_enemy(i):
				i += 1
				continue
			_enemy_attack(enemy)
		else:
			var next := _step_toward(enemy["pos"], player_pos)
			if next != enemy["pos"] and _enemy_at(next) == -1:
				enemy["pos"] = next
				enemies[i] = enemy
				if _distance(enemy["pos"], player_pos) == 1:
					if _brace_hits_enemy(i):
						i += 1
						continue
					_enemy_attack(enemy)
		i += 1

func _brace_hits_enemy(index: int) -> bool:
	if not braced:
		return false
	braced = false
	_attack_enemy(index, run_state.selected_gear.damage + 1)
	message = "Brace lands before the enemy can strike."
	return true

func _enemy_attack(enemy: Dictionary) -> void:
	var damage := int(enemy["damage"])
	if block_stacks > 0:
		block_stacks -= 1
		damage = maxi(0, damage - 1)
		message = "Your shield absorbs part of the blow."
	if damage > 0:
		_apply_damage(damage)

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
	var final_gold := run_state.gold
	controller.return_to_tavern("victory", "You escape the forest with %d gold. The bartender smiles like he expected it." % final_gold)

func _die() -> void:
	controller.return_to_tavern("death", "You wake at the tavern table. The bartender says, 'Again, then?'")

func _build_board_tiles() -> void:
	if ground_layer == null:
		return
	if grass_tile_set == null:
		grass_tile_set = _make_grass_tile_set()
	ground_layer.tile_set = grass_tile_set
	ground_layer.position = ORIGIN
	ground_layer.scale = Vector2(GRASS_TILE_SCALE, GRASS_TILE_SCALE)
	ground_layer.clear()
	var grass_tiles: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(2, 0),
		Vector2i(3, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
	]
	for y in range(GRID_H):
		for x in range(GRID_W):
			var tile := Vector2i(x, y)
			if floor_cells.has(tile):
				var atlas_tile := grass_tiles[abs(x * 3 + y * 5) % grass_tiles.size()]
				ground_layer.set_cell(tile, GRASS_SOURCE_ID, atlas_tile)
			else:
				ground_layer.erase_cell(tile)

func _make_grass_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = GRASS_TILE_SIZE
	var source := TileSetAtlasSource.new()
	source.texture = GRASS_ATLAS
	source.texture_region_size = GRASS_TILE_SIZE
	for y in range(int(GRASS_ATLAS.get_height() / GRASS_TILE_SIZE.y)):
		for x in range(int(GRASS_ATLAS.get_width() / GRASS_TILE_SIZE.x)):
			source.create_tile(Vector2i(x, y))
	tile_set.add_source(source, GRASS_SOURCE_ID)
	return tile_set

func _configure_player_sprite() -> void:
	player_token.sprite_texture = PLAYER_IDLE_DOWN
	player_token.sprite_region_enabled = true
	player_token.sprite_region = Rect2(0, 0, 96, 80)
	player_token.sprite_scale = Vector2(0.58, 0.58)
	player_token.show_label = false
	player_token.show_panel = false

func _refresh_ui() -> void:
	if hud_label == null or run_state == null:
		return
	var gear := run_state.selected_gear
	var gear_name := gear.display_name if gear != null else "None"
	var special := gear.special_id.capitalize() if gear != null else "None"
	health_bar.max_value = run_state.max_health
	health_bar.value = run_state.current_health
	health_value_label.text = "%d/%d" % [run_state.current_health, run_state.max_health]
	hud_label.text = "Gear: %s\nSpecial: %s\nGold: %d  Keys: %d  Potions: %d\nBlock: %d  Braced: %s\nSeed: %d" % [
		gear_name,
		special,
		run_state.gold,
		run_state.keys,
		run_state.potions,
		block_stacks,
		"yes" if braced else "no",
		run_state.floor_seed,
	]
	log_label.text = message
	_sync_board_nodes()

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
		var trap_label := "!" if trap["sprung"] else "?"
		var trap_color := Color(0.55, 0.08, 0.08) if trap["sprung"] else Color(0.46, 0.33, 0.13)
		_add_marker("Trap", trap["pos"], trap_label, trap_color, "trap")
	for item in loot:
		_add_marker(item["kind"].capitalize(), item["pos"], _loot_label(item["kind"]), Color(0.93, 0.75, 0.28), item["kind"])
	for prop in props:
		_add_marker(prop["kind"].capitalize(), prop["pos"], _prop_label(prop["kind"]), _prop_color(prop["kind"]), prop["kind"])
	if not chest["opened"]:
		_add_marker("LockedChest", chest["pos"], "C", Color(0.63, 0.38, 0.14), "chest")
	if secret["found"]:
		_add_marker("HiddenCache", secret["pos"], "$", Color(0.78, 0.73, 0.43), "secret")
	for i in range(enemies.size()):
		var enemy_piece := _make_piece("Wolf_%d" % i, enemies[i]["pos"], "W", Color(0.56, 0.14, 0.14), BoardPiece.PieceShape.CIRCLE, "wolf")
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
			_set_piece_sprite(piece, STRUCT_ATLAS, _atlas_region(1, 1), Vector2(1.45, 1.45))
		"barrel":
			_set_piece_sprite(piece, PROPS_ATLAS, _atlas_region(2, 0), Vector2(1.55, 1.55))
		"campfire":
			_set_piece_sprite(piece, PROPS_ATLAS, _atlas_region(3, 0), Vector2(1.6, 1.6))
		"gold":
			_set_piece_sprite(piece, PROPS_ATLAS, _atlas_region(5, 0), Vector2(1.45, 1.45))
		"potion":
			_set_piece_sprite(piece, PROPS_ATLAS, _atlas_region(6, 0), Vector2(1.45, 1.45))
		"key":
			_set_piece_sprite(piece, PROPS_ATLAS, _atlas_region(7, 0), Vector2(1.45, 1.45))
		"chest":
			_set_piece_sprite(piece, PROPS_ATLAS, _atlas_region(0, 1), Vector2(1.6, 1.6))
		"trap":
			_set_piece_sprite(piece, PLANT_ATLAS, _atlas_region(2, 1), Vector2(1.5, 1.5))
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

func _configure_exit_sprite() -> void:
	exit_door.sprite_texture = STRUCT_ATLAS
	exit_door.sprite_region_enabled = true
	exit_door.sprite_region = _atlas_region(5, 0)
	exit_door.sprite_scale = Vector2(1.6, 1.7)
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
	for button in [special_button, interact_button, potion_button]:
		button.custom_minimum_size = Vector2(0, 42)
		button.add_theme_stylebox_override("normal", _button_style(UI_BUTTON_NORMAL))
		button.add_theme_stylebox_override("hover", _button_style(UI_BUTTON_HOVER))
		button.add_theme_stylebox_override("pressed", _button_style(UI_BUTTON_PRESSED))
		button.add_theme_stylebox_override("focus", _button_style(UI_BUTTON_HOVER))
		button.add_theme_color_override("font_color", Color(0.20, 0.12, 0.07))
		button.add_theme_color_override("font_hover_color", Color(0.10, 0.07, 0.04))
		button.add_theme_color_override("font_pressed_color", Color(0.08, 0.05, 0.03))
		button.add_theme_font_size_override("font_size", 15)

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
	}

func _pick_floor_cell(avoid_path: bool) -> Vector2i:
	var cells := floor_cells.keys()
	for attempt in range(300):
		var tile := Vector2i(cells[rng.randi_range(0, cells.size() - 1)])
		if _reserved(tile):
			continue
		if avoid_path and critical_path.has(tile):
			continue
		return tile
	return Vector2i(cells[0])

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
