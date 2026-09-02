extends "res://scripts/scenes/forest.gd"

const FIELD_DOORS := {
	"north": Vector2i(8, 1), "east": Vector2i(14, 5),
	"south": Vector2i(8, 9), "west": Vector2i(1, 5),
}
const FARMSTEAD_ENEMIES := ["ash_rat", "possessed_scarecrow", "ember_crow", "blighted_farmhand"]
const FARM_GRASS_1 := preload("res://assets/tile_sets/Free_pixel_tiles_pack/grass_1.png")
const FARM_GRASS_3 := preload("res://assets/tile_sets/Free_pixel_tiles_pack/grass_3.png")
const FARMSTEAD_BACKGROUND_ROOT := "res://assets/field/farmstead/backgrounds/"
const FARMSTEAD_BACKGROUND_IDS := ["crossroads", "farmyard", "barn", "cellar", "storehouse", "harvest_field"]

var field_room_id := 0
var field_room: Dictionary = {}
var field_doors_locked := false
var entrance_direction := ""
var return_gate := Vector2i(8, 5)
var wretch_telegraph: Array[Vector2i] = []
var field_background_id := "farmyard"

func _configure_dungeon_settings() -> void:
	dungeon_id = "ashen_farmstead"
	dungeon_title = "Ashen Farmstead"
	dungeon_floor_label = "Field"
	complete_floor_method = "complete_ashen_farmstead"
	victory_text_template = "The Harvest Wretch falls. You return from the Ashen Farmstead with %d gold."
	grid_w = 16; grid_h = 11; tile_size = TILE_SIZE; use_follow_camera = false
	message = "Cinders drift across fields that should have gone cold years ago."

func _generate() -> void:
	if run_state == null: return
	if run_state.field_run.is_empty():
		var definition := GameBalance.get_dungeon(dungeon_id)
		var count: Dictionary = definition.get("room_count", {"min":10,"max":12})
		run_state.field_run = FieldDungeonGenerator.generate(run_state.get_current_floor_seed(), int(count.get("min",10)), int(count.get("max",12)))
	field_room_id = int(run_state.field_run.get("current_room", 0))
	_load_field_room(field_room_id, int(run_state.field_run.get("previous_room", -1)))

func _load_field_room(room_id: int, previous_id: int) -> void:
	var preserved_companion := companion.duplicate(true)
	_reset_generated_state()
	companion = preserved_companion
	field_room_id = room_id
	run_state.enter_field_room(room_id, previous_id)
	field_room = run_state.get_field_room(room_id)
	var role := String(field_room.get("role", "combat"))
	if not bool(field_room.get("cleared", false)) and role in ["combat", "elite", "boss"]:
		run_state.continue_expedition()
	wretch_telegraph.clear()
	rng.seed = int(run_state.field_run.get("seed", 1)) + room_id * 7919
	layout_type = "field_%s_%s" % [String(field_room.get("role","combat")), String(field_room.get("door_signature",""))]
	_build_field_floor()
	_place_field_content()
	_place_decorations()
	field_doors_locked = not bool(field_room.get("cleared", false)) and String(field_room.get("role", "combat")) in ["combat","elite","boss"]
	message = _floor_intro_message()
	if previous_id >= 0: entrance_direction = _direction_to_neighbor(previous_id)
	player_pos = _entry_position(entrance_direction)
	exit_pos = Vector2i(-50, -50)
	_start_combat()
	if enemies.is_empty(): _enter_free_roam_if_clear()
	_build_board_tiles(); _build_decorations(); _refresh_ui()

func _build_field_floor() -> void:
	for y in range(1, grid_h - 1):
		for x in range(1, grid_w - 1): floor_cells[Vector2i(x,y)] = true
	critical_path = floor_cells.duplicate()
	room_graph = [{"id":field_room_id,"center":Vector2i(8,5),"neighbors":field_room.get("neighbors",{}).values(),"role":field_room.get("role","combat")}]
	critical_room_ids = [field_room_id]

func _add_grass_sprite(tile: Vector2i) -> void:
	var texture: Texture2D = FARM_GRASS_1 if abs(tile.x * 17 + tile.y * 31 + field_room_id) % 4 != 0 else FARM_GRASS_3
	var sprite := Sprite2D.new()
	sprite.name = "FarmGrass_%d_%d" % [tile.x,tile.y]
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(tile) * tile_size
	sprite.scale = Vector2(float(tile_size)/float(texture.get_width()),float(tile_size)/float(texture.get_height()))
	sprite.z_index = 0
	ground_layer.add_child(sprite)

func _build_board_tiles() -> void:
	field_background_id = _resolve_field_background_id()
	var background_path := FARMSTEAD_BACKGROUND_ROOT + field_background_id + ".png"
	if not FARMSTEAD_BACKGROUND_IDS.has(field_background_id) or not ResourceLoader.exists(background_path):
		super._build_board_tiles()
		return
	ground_layer.position = ORIGIN
	ground_layer.scale = Vector2.ONE
	ground_layer.clear()
	_clear_children_now(ground_layer)
	var backdrop := Polygon2D.new()
	backdrop.name = "DungeonBlackBackdrop"
	backdrop.polygon = PackedVector2Array([Vector2(-100000,-100000),Vector2(100000,-100000),Vector2(100000,100000),Vector2(-100000,100000)])
	backdrop.color = Color.BLACK
	backdrop.z_index = -1
	ground_layer.add_child(backdrop)
	var sprite := Sprite2D.new()
	sprite.name = "FarmsteadRoomBackground"
	sprite.texture = load(background_path)
	sprite.centered = false
	sprite.position = Vector2.ZERO
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 0
	ground_layer.add_child(sprite)
	_build_doorway_overlays()

func _resolve_field_background_id() -> String:
	var role := String(field_room.get("role", "combat"))
	match role:
		"start": return "crossroads"
		"shop", "treasure": return "storehouse"
		"boss": return "harvest_field"
	return String(field_room.get("background_id", "farmyard"))

func _build_doorway_overlays() -> void:
	var neighbors := Dictionary(field_room.get("neighbors", {}))
	for direction in FIELD_DOORS:
		var center := Vector2(FIELD_DOORS[direction]) * tile_size + Vector2(tile_size, tile_size) * 0.5
		if neighbors.has(direction):
			var glow := Polygon2D.new()
			glow.name = "DoorwayGlow_%s" % direction
			var size := Vector2(54, 28) if direction in ["north", "south"] else Vector2(28, 54)
			glow.polygon = _centered_quad(center, size)
			glow.color = Color(0.95, 0.55, 0.20, 0.12)
			glow.z_index = 1
			ground_layer.add_child(glow)
		else:
			var cap := Polygon2D.new()
			cap.name = "DoorwayWallCap_%s" % direction
			var size := Vector2(62, 42) if direction in ["north", "south"] else Vector2(42, 62)
			cap.polygon = _centered_quad(center, size)
			cap.color = Color(0.075, 0.052, 0.038, 0.96)
			cap.z_index = 1
			ground_layer.add_child(cap)

func _centered_quad(center: Vector2, size: Vector2) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([center-half, Vector2(center.x+half.x,center.y-half.y), center+half, Vector2(center.x-half.x,center.y+half.y)])

func _place_field_content() -> void:
	var role := String(field_room.get("role", "combat"))
	chest = {"pos":Vector2i(8,5), "opened":bool(field_room.get("chest_opened", false))} if role == "treasure" else {"pos":Vector2i(-1,-1),"opened":true}
	secret = {"pos":Vector2i(-1,-1),"found":false}
	if role == "shop": dungeon_merchant = {"id":"farmstead","pos":Vector2i(8,4)}
	var templates := GameBalance.get_field_room_templates(String(field_room.get("door_signature", "")))
	var template: Dictionary = templates[field_room_id % templates.size()] if not templates.is_empty() else {}
	var role_background := "crossroads" if role == "start" else "storehouse" if role in ["shop","treasure"] else "harvest_field" if role == "boss" else String(template.get("background_id", "farmyard"))
	field_room["template_id"] = String(template.get("id", "fallback"))
	field_room["background_id"] = role_background
	run_state.update_field_room(field_room_id, {"template_id":field_room["template_id"], "background_id":role_background})
	var obstacle_cells: Array = template.get("obstacles", [])
	for i in range(obstacle_cells.size()):
		var kind: String = ["hay_bale","fence","barrel"][i % 3]
		props.append({"kind":kind,"pos":Vector2i(int(obstacle_cells[i][0]),int(obstacle_cells[i][1])),"hp":2 if kind != "fence" else 3})
	if bool(field_room.get("cleared", false)) or role in ["start","shop","treasure"]: return
	if role == "boss":
		_add_floor_enemy(Vector2i(8,4), "harvest_wretch")
		_add_floor_enemy(Vector2i(5,4), "ash_rat"); _add_floor_enemy(Vector2i(11,4), "ash_rat")
		return
	var count := 4 if role == "elite" else 2 + (field_room_id % 2)
	for i in range(count):
		var enemy_type: String = FARMSTEAD_ENEMIES[(field_room_id + i) % FARMSTEAD_ENEMIES.size()]
		_add_floor_enemy(_pick_field_cell(), enemy_type)
		if role == "elite" and i == 0: enemies[enemies.size()-1]["elite"] = true; enemies[enemies.size()-1]["max_health"] += 5; enemies[enemies.size()-1]["hp"] += 5
	if role in ["combat","elite"]: traps.append({"pos":_pick_field_cell(),"sprung":false})

func _resolve_tile() -> void:
	for item in loot.duplicate():
		if item["pos"] == player_pos: _apply_loot_item(item); loot.erase(item)
	for i in range(traps.size()-1,-1,-1):
		if Vector2i(traps[i]["pos"]) == player_pos:
			_apply_damage(2); _spawn_damage_popup(player_pos,2,"fire"); traps.remove_at(i); message = "Cinders flare beneath you for 2 fire damage."

func _enemy_attack(index: int) -> void:
	var is_wretch := index >= 0 and index < enemies.size() and _enemy_type(enemies[index]) == "harvest_wretch"
	super._enemy_attack(index)
	if not is_wretch or index < 0 or index >= enemies.size(): return
	var boss: Dictionary = enemies[index]
	if not bool(boss.get("rat_wave",false)) and int(boss.get("hp",0))*2 <= int(boss.get("max_health",1)):
		boss["rat_wave"] = true; enemies[index] = boss
		var spawn := _nearest_open_adjacent(Vector2i(boss["pos"])); _add_floor_enemy(spawn,"ash_rat"); message += " The Wretch shakes an ash rat from its mantle."
	var fire_tile := _nearest_open_adjacent(player_pos)
	if fire_tile != player_pos and not _trap_at(fire_tile): traps.append({"pos":fire_tile,"sprung":false}); message += " Fire spreads beside you."

func _resolve_enemy_actor_turn(enemy_id: int) -> void:
	var initial_index := _enemy_index_by_id(enemy_id)
	if initial_index == -1 or _enemy_type(enemies[initial_index]) != "harvest_wretch":
		await super._resolve_enemy_actor_turn(enemy_id)
		return
	await get_tree().create_timer(ENEMY_TURN_DELAY).timeout
	var index := _enemy_index_by_id(enemy_id)
	if index == -1: is_resolving_enemy_turn=false; _advance_to_next_actor(); return
	if not wretch_telegraph.is_empty():
		if wretch_telegraph.has(player_pos):
			var sweep := CombatResolver.resolve_attack(20,99,5,0,"fire",_player_defenses())
			var before := run_state.current_health; _apply_damage(int(sweep.damage)); var dealt := maxi(0,before-run_state.current_health)
			if dealt > 0: _spawn_damage_popup(player_pos,dealt,"fire")
			message = "The Harvest Wretch reaps the marked ground for %d damage." % dealt
			_record_combat_event("Harvest sweep hits for %d"%dealt,"Telegraphed sweep: 5 fire damage; Threshold and fire Aegis reduce the final damage. Armed reactions do not trigger against room hazards.")
		else: message = "The Harvest Wretch's scythe tears through the marked ground, but you escaped."
		wretch_telegraph.clear()
	else:
		wretch_telegraph = [player_pos]
		for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var tile: Vector2i = player_pos + Vector2i(delta)
			if floor_cells.has(tile): wretch_telegraph.append(tile)
		message = "The Harvest Wretch raises its scythe. Glowing furrows mark next turn's sweep."
		_record_combat_event("Harvest sweep telegraphed","Marked tiles: %s. Move clear before the Wretch acts again." % str(wretch_telegraph))
	_refresh_ui(); is_resolving_enemy_turn=false; _advance_to_next_actor()

func _trap_at(tile: Vector2i) -> bool:
	for trap in traps:
		if Vector2i(trap.get("pos",Vector2i(-1,-1))) == tile: return true
	return false

func _pick_field_cell() -> Vector2i:
	for attempt in range(100):
		var tile := Vector2i(rng.randi_range(3,12),rng.randi_range(3,7))
		if not _reserved(tile): return tile
	return Vector2i(8,5)

func _enter_free_roam_if_clear() -> bool:
	var entered := super._enter_free_roam_if_clear()
	if entered:
		field_doors_locked = false
		var role := String(field_room.get("role", "combat"))
		var reward := not bool(field_room.get("reward_claimed", false)) and role in ["combat","elite","boss"]
		run_state.update_field_room(field_room_id, {"cleared":true,"reward_claimed":true})
		field_room = run_state.get_field_room(field_room_id)
		if reward:
			var room_gold := 10 if role == "elite" else (25 if role == "boss" else 4)
			run_state.gold += room_gold; message += "\nRoom clear: +%d gold." % room_gold
			run_state.mark_extraction_available("room_%d" % field_room_id, run_state.get_field_cleared_count())
			run_state.autosave_campaign()
			message += "\nSafe checkpoint reached. Press X to extract or choose a door."
		if role == "boss": run_state.field_run["boss_defeated"] = true; message += "\nA hearth-gate blooms from the Wretch's ashes."
	return entered

func _award_floor_clear_xp() -> Array[String]:
	if floor_clear_xp_awarded or run_state == null: return []
	var role := String(field_room.get("role","combat"))
	if role in ["start","shop","treasure"]: floor_clear_xp_awarded=true; return []
	floor_clear_xp_awarded = true
	var base_reward := 100 if role == "boss" else (35 if role == "elite" else 18)
	return run_state.gain_xp(run_state.apply_reward_bonus(base_reward,"xp"),"%s room cleared"%role.capitalize())

func _open_chest() -> bool:
	var opened := super._open_chest()
	if opened: run_state.update_field_room(field_room_id,{"chest_opened":true})
	return opened

func _try_player_move_or_interact(tile: Vector2i) -> void:
	super._try_player_move_or_interact(tile)
	if player_pos == return_gate and bool(run_state.field_run.get("boss_defeated", false)) and String(field_room.get("role","")) == "boss":
		_complete_floor(); return
	if field_doors_locked: return
	for direction in FIELD_DOORS:
		if player_pos == Vector2i(FIELD_DOORS[direction]) and Dictionary(field_room.get("neighbors",{})).has(direction):
			_transition_through(direction); return

func _transition_through(direction: String) -> void:
	var next_id := int(Dictionary(field_room["neighbors"])[direction])
	run_state.update_field_room(field_room_id, {"chest_opened":bool(chest.get("opened",false))})
	_load_field_room(next_id, field_room_id)

func _direction_to_neighbor(neighbor_id: int) -> String:
	for direction in Dictionary(field_room.get("neighbors",{})):
		if int(field_room["neighbors"][direction]) == neighbor_id: return String(direction)
	return ""

func _entry_position(direction: String) -> Vector2i:
	match direction:
		"north": return Vector2i(8,2)
		"east": return Vector2i(13,5)
		"south": return Vector2i(8,8)
		"west": return Vector2i(2,5)
	return Vector2i(8,8)

func _finish_floor() -> void:
	if not bool(run_state.field_run.get("boss_defeated", false)): message = "The harvest still bars your return."; _refresh_ui(); return
	if controller != null and controller.has_method("complete_ashen_farmstead"): controller.complete_ashen_farmstead()

func _floor_intro_message() -> String:
	return "%s · Room %d/%d · %s" % [dungeon_title, field_room_id + 1, int(run_state.field_run.get("room_count", 1)), String(field_room.get("role","combat")).capitalize()]

func _layout_display_name() -> String:
	return "%s room · %s" % [String(field_room.get("role","combat")).capitalize(), run_state.get_field_progress_summary()]

func _build_minimap_state() -> Dictionary:
	return {"mode":"field","rooms":run_state.field_run.get("rooms",[]),"current_room":field_room_id,"doors_locked":field_doors_locked}

func _sync_board_nodes() -> void:
	super._sync_board_nodes()
	exit_door.visible = false
	for direction in FIELD_DOORS:
		if Dictionary(field_room.get("neighbors",{})).has(direction):
			_add_marker("FieldDoor%s"%direction.capitalize(),FIELD_DOORS[direction],"X" if field_doors_locked else direction.substr(0,1).to_upper(),Color(0.55,0.22,0.08) if field_doors_locked else Color(0.86,0.58,0.22),"door")
	if String(field_room.get("role","")) == "boss" and bool(run_state.field_run.get("boss_defeated",false)):
		_add_marker("ReturnGate",return_gate,"H",Color(0.96,0.72,0.26),"door")
	for tile in wretch_telegraph: _add_highlight_marker(tile,Color(1.0,0.18,0.04,0.58),"HarvestWarning")

func _apply_sprite_to_piece(piece: BoardPiece, sprite_key: String) -> void:
	if sprite_key == "trap":
		_set_fitted_piece_sprite(piece,load("res://assets/field/farmstead/fire_patch.png"),Vector2(48,40)); piece.show_label=false; piece.show_panel=false; return
	super._apply_sprite_to_piece(piece,sprite_key)

func _enemy_sprite_key(enemy: Dictionary) -> String:
	var kind := _enemy_type(enemy)
	if kind in FARMSTEAD_ENEMIES or kind == "harvest_wretch": return kind
	return super._enemy_sprite_key(enemy)

func _enemy_label(enemy: Dictionary) -> String:
	match _enemy_type(enemy):
		"ash_rat": return "R"
		"possessed_scarecrow": return "S"
		"ember_crow": return "C"
		"blighted_farmhand": return "F"
		"harvest_wretch": return "W"
	return super._enemy_label(enemy)

func _place_decorations() -> void:
	for i in range(10): _add_decoration("grass_tuft_a",Vector2i(rng.randi_range(1,14),rng.randi_range(1,9)),Vector2.ZERO)
