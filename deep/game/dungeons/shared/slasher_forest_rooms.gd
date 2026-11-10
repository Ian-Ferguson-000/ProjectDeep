extends "res://game/dungeons/shared/slasher_forest.gd"

## Dungeons as interconnected rooms. The Verdant Forest
## uses this scene directly; the Stone Crypt extends it and swaps the look
## through _room_theme() (stone walls, iron bars, stairs down).
##
## Each floor is a graph of painted rooms (maps/<dungeon>/rooms/*.tscn) laid out
## by FieldDungeonGenerator. Doors sit on the centre of each room edge, stay
## barred by brambles while foes remain, and open once the room is cleared. The
## gate room holds the root gate down to the next floor, so the existing descent,
## elite and boss cadence, and endless depth all carry on unchanged.
##
## The tutorial expedition, merchant interludes and authored template scenes keep
## using the single generated floor from slasher_forest.gd.

const ROOMS := preload("res://game/dungeons/shared/forest_room_library.gd")
const ROOM_MINIMAP := preload("res://game/dungeons/shared/forest_room_minimap.gd")
const DOOR_TRIGGER_RADIUS := 30.0
const THICKET_KINDS := [
	"tree_wide", "tree_small", "tree_wide", "rounded_bush", "tree_small", "low_bush_a"
]
const TEMPLATE_ROLE := {
	"start": "start",
	"combat": "combat",
	"elite": "elite",
	"treasure": "treasure",
	"shop": "shop",
	"rest": "rest",
	"boss": "boss"
}
const CAMPFIRE_HEIGHT := 64.0
# TUNING: share of maximum health restored by resting once at a campfire.
const REST_HEAL_SHARE := 0.35

var room_id := 0
var room: Dictionary = {}
var room_role := "start"
var door_nodes: Dictionary = {}
var transition_cooldown := 0.0
var treasure_area: Area2D
var campfire_position := Vector2(-99999, -99999)
var rooms_active := false
var active_pedestal: Node2D
## Walking away re-arms the pedestal, so a swap doesn't immediately swap back.
var _pedestal_armed := true


func uses_room_layout() -> bool:
	if (
		run_state == null
		or use_authored_layout
		or run_state.slasher_merchant_interlude
		or _is_tutorial_expedition()
	):
		return false
	return (
		String(
			Dictionary(GameBalance.get_dungeon(run_state.active_dungeon_id).get("slasher", {})).get(
				"layout", ""
			)
		)
		== "rooms"
	)


func _build_floor() -> void:
	rooms_active = uses_room_layout()
	if not rooms_active:
		super._build_floor()
		return
	ROOMS.use_dungeon(run_state.active_dungeon_id)
	get_tree().paused = false
	secret_door_available = false
	secret_door_node = null
	merchant_offer_nodes.clear()
	has_dungeon_merchant = false
	treasure_area = null
	var new_floor := _ensure_floor_graph()
	var snapshot := _snapshot_player()
	if is_instance_valid(player):
		_store_active_slasher_state()
	for child in get_children():
		child.free()
	room_id = int(run_state.field_run.get("current_room", 0))
	_drop_rng = null
	run_state.enter_field_room(room_id, int(run_state.field_run.get("previous_room", -1)))
	room = run_state.get_field_room(room_id)
	room_role = String(room.get("role", "combat"))
	layout = _room_layout()
	if room_role == "shop":
		_arrange_shop(layout)
	pathfinder = GRID_PATHFINDER.new().configure(
		Dictionary(layout.cells), Array(layout.solid_props), ORIGIN, float(TILE)
	)
	active_summons.clear()
	_build_world()
	_spawn_player()
	_restore_player(snapshot)
	if new_floor:
		player.reset_combo_progress()
	_spawn_enemies()
	_spawn_loot()
	_build_hud()
	_refresh_hud()
	_entry_fade()
	if new_floor and player.item_runtime:
		player.item_runtime.floor_entered()
	if new_floor:
		_show_floor_banner()
	if (
		room_role == "boss"
		and not bool(room.get("cleared", false))
		and bool(layout.get("is_guarded", false))
	):
		_show_guardian_banner()
	if new_floor and run_state.current_floor == 1 and not run_state.starter_reward_claimed:
		call_deferred("_offer_starter_relic")
	transition_cooldown = 0.5
	_save_checkpoint()


# --- The shop: wares laid out on the floor ---------------------------------
# The trader stands back at their stall; every offer sits on the ground in a
# row. Stand on one to see its name, price and effect, press E to buy it.
# Spacing and where the row sits: slasher_balance.json → shop_floor.
var shop_offer_nodes: Array[Area2D] = []
var shop_tag: PanelContainer
var _shop_tag_label: RichTextLabel


func _shop_rules() -> Dictionary:
	return GameBalance.get_slasher_balance("shop_floor")


## Moves the trader to the back of the room and picks a floor spot per offer.
func _arrange_shop(target: Dictionary) -> void:
	var rules := _shop_rules()
	var cells: Dictionary = target.cells
	var paths: Dictionary = target.get("path_cells", {})
	var center: Vector2i = target.get(
		"center", Vector2i(int(target.width) / 2, int(target.height) / 2)
	)
	var blocked := {}
	for prop in Array(target.get("solid_props", [])):
		blocked[Vector2i(prop.cell)] = true
	for key in ["campfire", "treasure", "exit"]:
		var marker := Vector2i(target.get(key, Vector2i(-100, -100)))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				blocked[marker + Vector2i(dx, dy)] = true
	var stall_want := center + Vector2i(int(rules.get("stall_offset_x", -7)), 0)
	stall_want.y = int(rules.get("stall_row", 2))
	target.merchant = _nearest_free_cell(cells, blocked, stall_want, paths)
	blocked[Vector2i(target.merchant)] = true
	var count := run_state.get_merchant_offers(_dungeon_merchant_id(), "dungeon").size()
	var spacing := int(rules.get("spacing", 3))
	var row := center.y + int(rules.get("row_offset", 2))
	var spots: Array = []
	for index in count:
		var want := Vector2i(center.x + int(round((index - (count - 1) * 0.5) * spacing)), row)
		var spot := _nearest_free_cell(cells, blocked, want, {})
		blocked[spot] = true
		spots.append(spot)
	target["shop_slots"] = spots


func _nearest_free_cell(
	cells: Dictionary, blocked: Dictionary, want: Vector2i, avoid: Dictionary
) -> Vector2i:
	var best := want
	var best_score := 1 << 30
	for value in cells:
		var cell: Vector2i = value
		if blocked.has(cell):
			continue
		# Keep clear of the walls so the stall and wares never touch the thicket.
		var crowded := 0
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if not cells.has(cell + direction):
				crowded += 1
		var score := (
			(cell - want).length_squared() * 4 + crowded * 40 + (6 if avoid.has(cell) else 0)
		)
		if score < best_score:
			best_score = score
			best = cell
	return best


func _build_shop_floor() -> void:
	shop_offer_nodes.clear()
	var spots: Array = layout.get("shop_slots", [])
	var offers := run_state.get_merchant_offers(_dungeon_merchant_id(), "dungeon")
	for index in mini(spots.size(), offers.size()):
		var offer: Dictionary = offers[index]
		if bool(offer.get("sold", false)):
			continue
		var area := Area2D.new()
		area.name = "ShopOffer_%d" % index
		area.position = _world(Vector2i(spots[index]))
		area.set_meta("offer_id", String(offer.get("offer_id", "")))
		area.set_meta("display", _offer_display_kind(offer))
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 24
		shape.shape = circle
		area.add_child(shape)
		area.add_child(_glow(_rarity_color(String(offer.get("rarity", "uncommon"))), 22))
		var icon := Sprite2D.new()
		icon.name = "Ware"
		icon.texture = _offer_texture(offer)
		if icon.texture != null:
			icon.scale = (
				Vector2.ONE
				* (
					34.0
					/ maxf(1.0, float(maxi(icon.texture.get_width(), icon.texture.get_height())))
				)
			)
		icon.position = Vector2(0, -12)
		area.add_child(icon)
		var price := Label.new()
		price.name = "Price"
		price.text = "%d¢" % int(offer.get("gold", 0))
		price.position = Vector2(-50, 12)
		price.size = Vector2(100, 28)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.add_theme_font_size_override("font_size", 22)
		price.add_theme_color_override("font_color", Color("#ffe6a3"))
		price.add_theme_color_override("font_outline_color", Color("#140e08"))
		price.add_theme_constant_override("outline_size", 5)
		area.add_child(price)
		actor_layer.add_child(area)
		shop_offer_nodes.append(area)


## Removes wares the list panel sold.
func _sync_shop_floor() -> void:
	for area in shop_offer_nodes.duplicate():
		if not is_instance_valid(area):
			shop_offer_nodes.erase(area)
			continue
		if bool(
			_find_merchant_offer(_dungeon_merchant_id(), String(area.get_meta("offer_id", ""))).get(
				"sold", true
			)
		):
			shop_offer_nodes.erase(area)
			area.queue_free()


func _offer_display_kind(offer: Dictionary) -> String:
	return String(offer.get("kind", "item"))


func _offer_texture(offer: Dictionary) -> Texture2D:
	var item := GameBalance.get_item(String(offer.get("item_id", "")))
	return DungeonHud.item_icon(String(item.get("icon", "special")))


static func _rarity_color(rarity: String) -> Color:
	match rarity:
		"rare":
			return Color("#6fa8ff")
		"very_rare":
			return Color("#c27bff")
		"legendary":
			return Color("#ffb347")
		"pickup":
			return Color("#f2d27a")
	return Color("#8fd88a")


## The offer the player stands on, or null.
func shop_offer_under_player() -> Area2D:
	if not is_instance_valid(player):
		return null
	var reach := float(_shop_rules().get("stand_radius", 34.0))
	var best: Area2D = null
	var best_gap := reach
	for area in shop_offer_nodes:
		if not is_instance_valid(area):
			continue
		var gap := player.global_position.distance_to(area.global_position)
		if gap < best_gap:
			best_gap = gap
			best = area
	return best


func _shop_floor_interaction(used: bool) -> bool:
	if shop_offer_nodes.is_empty():
		_hide_shop_tag()
		return false
	var area := shop_offer_under_player()
	if area == null:
		_hide_shop_tag()
		return false
	var offer := _find_merchant_offer(_dungeon_merchant_id(), String(area.get_meta("offer_id", "")))
	if offer.is_empty() or bool(offer.get("sold", false)):
		_hide_shop_tag()
		return false
	_show_shop_tag(area, offer)
	if not used and Input.is_action_just_pressed("interact"):
		player.basic_mouse_held = false
		var logs := run_state.purchase_merchant_offer(
			_dungeon_merchant_id(), String(offer.offer_id), "dungeon"
		)
		_show_message(" ".join(logs))
		if bool(
			_find_merchant_offer(_dungeon_merchant_id(), String(offer.offer_id)).get("sold", false)
		):
			shop_offer_nodes.erase(area)
			area.queue_free()
			_hide_shop_tag()
		_after_purchase()
		return true
	return false


static func offer_effect_text(offer: Dictionary) -> String:
	var text := String(offer.get("rules_text", ""))
	return text if not text.is_empty() else String(offer.get("description", ""))


func _show_shop_tag(area: Area2D, offer: Dictionary) -> void:
	if shop_tag == null or not is_instance_valid(shop_tag):
		var canvas := get_node_or_null("HUD")
		if canvas == null:
			return
		shop_tag = PanelContainer.new()
		shop_tag.name = "ShopTag"
		shop_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.07, 0.05, 0.04, 0.92)
		style.border_color = Color("#c9a45c")
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		shop_tag.add_theme_stylebox_override("panel", style)
		_shop_tag_label = RichTextLabel.new()
		_shop_tag_label.bbcode_enabled = true
		_shop_tag_label.fit_content = true
		_shop_tag_label.scroll_active = false
		_shop_tag_label.custom_minimum_size = Vector2(300, 0)
		_shop_tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shop_tag_label.add_theme_font_size_override("normal_font_size", 15)
		_shop_tag_label.add_theme_font_size_override("bold_font_size", 18)
		shop_tag.add_child(_shop_tag_label)
		canvas.add_child(shop_tag)
	var colour := _rarity_color(String(offer.get("rarity", "uncommon"))).to_html(false)
	var price := int(offer.get("gold", 0))
	var coins := int(run_state.gold)
	var footer := (
		"[color=#9fe08a]Press E to buy[/color]"
		if coins >= price
		else (
			"[color=#e89a7a]You need %d more coin%s[/color]"
			% [price - coins, "" if price - coins == 1 else "s"]
		)
	)
	var rarity := (
		String(offer.get("rarity", "")).replace("_", " ").capitalize()
		if String(offer.get("kind", "item")) == "item"
		else ""
	)
	_shop_tag_label.text = (
		"[b][color=#%s]%s[/color][/b]   [color=#ffe6a3]%d¢[/color]\n%s%s\n%s"
		% [
			colour,
			String(offer.get("name", "Item")),
			price,
			("[color=#a89a80]%s[/color]\n" % rarity) if not rarity.is_empty() else "",
			offer_effect_text(offer),
			footer
		]
	)
	shop_tag.visible = true
	shop_tag.reset_size()
	var screen := get_viewport().canvas_transform * area.global_position
	var view := get_viewport().get_visible_rect().size
	shop_tag.position = Vector2(
		clampf(screen.x - shop_tag.size.x * 0.5, 12.0, view.x - shop_tag.size.x - 12.0),
		clampf(screen.y - shop_tag.size.y - 70.0, 12.0, view.y - shop_tag.size.y - 12.0)
	)


func _hide_shop_tag() -> void:
	if shop_tag != null and is_instance_valid(shop_tag):
		shop_tag.visible = false


func _drop_seed_key() -> String:
	return "room%d" % room_id


## Saves on entering each room and on clearing it, so progress within a floor
## survives a crash or quitting.
func _save_checkpoint() -> void:
	if (
		run_state == null
		or run_state.campaign == null
		or not run_state.campaign.expedition.active
		or not is_instance_valid(player)
	):
		return
	_store_active_slasher_state()
	run_state.current_health = player.health
	run_state.save_room_checkpoint()


## Generates this floor's room graph the first time the floor is entered.
## How this dungeon's rooms look and what things are called. The crypt
## overrides it; see slasher_crypt.gd.
##   walls         "thicket" (trees on the edge) or "stone" (wall tiles drawn by the wall generator)
##   prop_kinds    solid prop kinds swapped when a room is built (the map's T is a tree in the forest)
##   hollow_kind   the breakable that may hide a keyless chest, drawn a shade darker
func _room_theme() -> Dictionary:
	return {
		"walls": "thicket",
		"gate_name": "Root Gate",
		"exit_sprite": "exit",
		"exit_glow": "#83d978",
		"gate_open": "Gate open · descend through the roots.",
		"room_clear": "Room cleared · the brambles pull back.",
		"guardian_falls": "The guardian falls · its pack scatters and the Root Gate opens.",
		"prop_kinds": {},
		"hollow_kind": "tree_large",
		"hollow_found": "Something glints inside the hollow trunk…",
	}


func _ensure_floor_graph() -> bool:
	var floor_key := "%d:%d" % [run_state.get_current_floor_seed(), run_state.current_floor]
	if String(run_state.field_run.get("forest_floor_key", "")) == floor_key:
		return false
	var tuning: Dictionary = Dictionary(
		Dictionary(GameBalance.get_dungeon(run_state.active_dungeon_id).get("slasher", {})).get(
			"room_count", {}
		)
	)
	# TUNING: forest.slasher.room_count in dungeons.json sets how sprawling each floor is.
	var growth := mini(
		int(tuning.get("growth_cap", 4)),
		(run_state.current_floor - 1) * int(tuning.get("growth_per_floor", 1))
	)
	var minimum := int(tuning.get("min", 7)) + growth
	run_state.field_run = FieldDungeonGenerator.generate(
		run_state.get_current_floor_seed(),
		minimum,
		maxi(minimum, int(tuning.get("max", 9)) + growth)
	)
	run_state.field_run["forest_floor_key"] = floor_key
	run_state.field_run["layout_kind"] = "forest_rooms"
	run_state.field_run["arrival_direction"] = ""
	# No campfire by default (dungeons.json room_count.rest_room);
	# from locked_treasure_from_floor the treasure room needs a key.
	if bool(tuning.get("rest_room", true)):
		_assign_rest_room()
	if run_state.current_floor >= int(tuning.get("locked_treasure_from_floor", 99)):
		for record in run_state.field_run.get("rooms", []):
			if String(record.role) == "treasure":
				run_state.update_field_room(int(record.id), {"locked": true})
	if MapPlaytest.active():
		var tested := MapPlaytest.template()
		var role := (
			String(Array(tested.get("roles", ["combat"]))[0])
			if not Array(tested.get("roles", [])).is_empty()
			else "combat"
		)
		run_state.update_field_room(
			0,
			{
				"role": role,
				"cleared": ROOMS.PEACEFUL_ROLES.has(role),
				"template_id": String(tested.get("id", ""))
			}
		)
	return true


## One combat room per floor becomes a campfire clearing: no foes, a place to
## rest. It sits partway along the route, never beside the start or the gate.
func _assign_rest_room() -> void:
	var rooms: Array = run_state.field_run.get("rooms", [])
	var distances := {0: 0}
	var open: Array[int] = [0]
	while not open.is_empty():
		var id: int = open.pop_front()
		for neighbor in Dictionary(Dictionary(rooms[id]).neighbors).values():
			if not distances.has(int(neighbor)):
				distances[int(neighbor)] = int(distances[id]) + 1
				open.append(int(neighbor))
	var gate_distance := 0
	for value in rooms:
		if String(value.role) == "boss":
			gate_distance = int(distances.get(int(value.id), 0))
	var best := -1
	var best_score := 999
	# Prefer a fighting room two or more rooms in; on a cramped floor, settle for one.
	for nearest in [2, 1]:
		for value in rooms:
			if String(value.role) != "combat":
				continue
			var distance := int(distances.get(int(value.id), 0))
			if distance < nearest:
				continue
			var score: int = absi(distance - maxi(2, gate_distance / 2))
			if score < best_score:
				best = int(value.id)
				best_score = score
		if best >= 0:
			break
	if best >= 0:
		run_state.update_field_room(best, {"role": "rest", "cleared": true})


func _room_layout() -> Dictionary:
	var floor_key := String(run_state.field_run.get("forest_floor_key", ""))
	var template := ROOMS.template(String(room.get("template_id", "")))
	if MapPlaytest.active() and room_id == 0:
		template = MapPlaytest.template()
	if template.is_empty():
		var pick_role := String(TEMPLATE_ROLE.get(room_role, "combat"))
		# On guardian floors the gate room is a colossus arena, if any exist.
		if (
			room_role == "boss"
			and run_state.is_slasher_boss_floor()
			and not (
				ROOMS
				. templates()
				. filter(func(t): return Array(t.get("roles", [])).has("guardian"))
				. is_empty()
			)
		):
			pick_role = "guardian"
		template = ROOMS.pick(
			pick_role, hash("%s:%d:room" % [floor_key, room_id]), _neighbor_template_ids()
		)
		run_state.update_field_room(room_id, {"template_id": String(template.get("id", ""))})
		room["template_id"] = String(template.get("id", ""))
	var built := ROOMS.build_layout(
		template,
		Dictionary(room.get("neighbors", {})).keys(),
		hash("%s:%d:decor" % [floor_key, room_id])
	)
	var state: Dictionary = Dictionary(room.get("slasher", {}))
	var destroyed: Array = Array(state.get("destroyed_props", []))
	built.solid_props = Array(built.solid_props).filter(
		func(prop): return not destroyed.has(Vector2i(prop.cell))
	)
	var swaps: Dictionary = Dictionary(_room_theme().get("prop_kinds", {}))
	for prop in built.solid_props:
		if swaps.has(String(prop.kind)):
			prop.kind = String(swaps[String(prop.kind)])
	built["is_boss_floor"] = room_role == "boss" and run_state.is_slasher_boss_floor()
	built["is_elite_floor"] = room_role == "boss" and run_state.is_slasher_elite_floor()
	built["is_guarded"] = room_role == "boss" and floor_gate_guarded()
	built["cycle_floor"] = run_state.get_slasher_cycle_floor()
	var arrival := String(run_state.field_run.get("arrival_direction", ""))
	if (
		int(run_state.field_run.get("previous_room", -1)) >= 0
		and Dictionary(built.doors).has(arrival)
	):
		built.start = ROOMS.arrival_cell(built, arrival)
	elif (
		MapPlaytest.active()
		and room_id == 0
		and room_role != "start"
		and not Dictionary(built.doors).is_empty()
	):
		# Playtesting a fight: walk in through a door rather than appearing among the foes.
		built.start = ROOMS.arrival_cell(built, String(Dictionary(built.doors).keys()[0]))
	built.enemy_spawns = [] if bool(room.get("cleared", false)) else _encounter(built)
	if (
		bool(built.get("exit_under_body", false))
		and bool(room.get("cleared", false))
		and can_press_on()
	):
		for cell in Array(built.passage_cells):
			built.cells[cell] = true
	return built


func _neighbor_template_ids() -> Array:
	var ids: Array = []
	for neighbor in Dictionary(room.get("neighbors", {})).values():
		var other := run_state.get_field_room(int(neighbor))
		if not String(other.get("template_id", "")).is_empty():
			ids.append(String(other.template_id))
	return ids


## The room's walkable area (inside the outer wall) in world space.
func room_arena() -> Rect2:
	return Rect2(
		ORIGIN + Vector2(TILE, TILE),
		Vector2(float((int(layout.width) - 2) * TILE), float((int(layout.height) - 2) * TILE))
	)


func _slasher_config() -> Dictionary:
	return Dictionary(GameBalance.get_dungeon(run_state.active_dungeon_id).get("slasher", {}))


## The one mini boss of the floor, holding the gate room (dungeons.json
## slasher.gate_guardian). With a "pool" it's picked at random per floor (the
## same pick every time you enter that floor).
var forced_gate_guardian := ""  ## Tests and playtests: force a pool entry by visual_id.


func gate_guardian() -> Dictionary:
	var config: Dictionary = Dictionary(_slasher_config().get("gate_guardian", {}))
	var pick: Dictionary = config
	var pool: Array = Array(config.get("pool", []))
	var forced: Array = pool.filter(
		func(entry): return String(entry.get("visual_id", "")) == forced_gate_guardian
	)
	if not forced.is_empty():
		pick = Dictionary(forced[0])
	elif not pool.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(
			"%s:gate_guardian" % String(run_state.field_run.get("forest_floor_key", ""))
		)
		pick = Dictionary(pool[rng.randi_range(0, pool.size() - 1)])
	return {
		"visual_id": String(pick.get("visual_id", "briar_guardian")),
		"behavior_id": String(pick.get("behavior_id", "elite_guardian")),
		"every_floor": bool(config.get("every_floor", false))
	}


## Whether this floor's gate room has a guardian to beat before the way down
## opens: the boss floor, the elite floor, and every floor when gate_guardian.every_floor is set.
func floor_gate_guarded() -> bool:
	return (
		run_state.is_slasher_boss_floor()
		or run_state.is_slasher_elite_floor()
		or bool(gate_guardian().every_floor)
	)


## Which foes hold this room. Plain foes use the forest's normal wolf and beast
## rotation; elite rooms and the gate room add guardians on their cycle floors.
func _encounter(built: Dictionary) -> Array:
	if ROOMS.PEACEFUL_ROLES.has(room_role):
		return []
	var markers: Array = Array(built.enemy_markers).duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(
		"%s:%d:foes" % [String(run_state.field_run.get("forest_floor_key", "")), room_id]
	)
	for index in range(markers.size() - 1, 0, -1):
		var swap := rng.randi_range(0, index)
		var held = markers[index]
		markers[index] = markers[swap]
		markers[swap] = held
	var elite_cell: Vector2i = (
		Array(built.elite_markers)[0]
		if not Array(built.elite_markers).is_empty()
		else (
			markers.pop_back()
			if not markers.is_empty()
			else Vector2i(int(built.width) / 2, int(built.height) / 2)
		)
	)
	# TUNING: plain foes per room grow with depth and stop at the room's markers
	# (dungeons.json slasher.room_count.foes_base / foes_per_floor).
	var room_tuning: Dictionary = Dictionary(_slasher_config().get("room_count", {}))
	var base_foes := int(room_tuning.get("foes_base", 2))
	var count := clampi(
		base_foes + int(run_state.current_floor * float(room_tuning.get("foes_per_floor", 0.5))),
		base_foes,
		maxi(base_foes, markers.size())
	)
	var guardian := gate_guardian()
	var spawns: Array = []
	if (
		room_role == "boss"
		and bool(built.is_boss_floor)
		and Vector2i(built.get("colossus", Vector2i(-100, -100))).x >= 0
	):
		# The colossus is the whole fight: no adds at the start.
		var colossus_id := String(_slasher_config().get("colossus", "heartwood_colossus"))
		return [
			{
				"position": Vector2i(built.colossus),
				"visual_id": colossus_id,
				"behavior_id": colossus_id,
				"is_boss": true,
				"is_mini_boss": false
			}
		]
	if room_role == "boss" and bool(built.is_boss_floor):
		# No colossus arena: the floor's single boss holds the room alone.
		for index in mini(count, markers.size()):
			spawns.append(
				{
					"position": markers[index],
					"visual_id": "",
					"behavior_id": "",
					"is_boss": false,
					"is_mini_boss": false
				}
			)
		spawns.append(
			{
				"position": elite_cell,
				"visual_id": "dark_druid",
				"behavior_id": "",
				"is_boss": true,
				"is_mini_boss": false
			}
		)
		return spawns
	# One boss per floor, at the end: only the gate room has a guardian.
	if room_role == "boss" and bool(built.is_guarded):
		spawns.append(
			{
				"position": elite_cell,
				"visual_id": guardian.visual_id,
				"behavior_id": guardian.behavior_id,
				"is_boss": false,
				"is_mini_boss": true
			}
		)
		count = maxi(1, count - 1)
	else:
		if not Array(built.elite_markers).is_empty():
			markers.push_front(elite_cell)
		# Elite rooms are a tougher fight with more foes, but no mini boss.
		if room_role == "elite":
			count = mini(count + 2, markers.size())
	for index in mini(count, markers.size()):
		spawns.append(
			{
				"position": markers[index],
				"visual_id": "",
				"behavior_id": "",
				"is_boss": false,
				"is_mini_boss": false
			}
		)
	return spawns


# ---------------------------------------------------------------- world


func _build_world() -> void:
	if not rooms_active:
		super._build_world()
		return
	var profile := DungeonRuntimeProfile.get_profile(run_state.active_dungeon_id)
	var underlay := ColorRect.new()
	underlay.name = "DungeonDepth"
	underlay.color = Color("#" + String(profile.get("underlay", "07100d")))
	underlay.position = Vector2.ZERO
	underlay.size = Vector2(float(layout.width * TILE + 128), float(layout.height * TILE + 128))
	underlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	underlay.z_index = -20
	add_child(underlay)
	ground_layer = Node2D.new()
	ground_layer.name = "Ground"
	ground_layer.z_index = -10
	add_child(ground_layer)
	low_decor_layer = Node2D.new()
	low_decor_layer.name = "LowDecor"
	low_decor_layer.z_index = -2
	add_child(low_decor_layer)
	actor_layer = Node2D.new()
	actor_layer.name = "Actors"
	actor_layer.y_sort_enabled = true
	add_child(actor_layer)
	canopy_layer = Node2D.new()
	canopy_layer.name = "Canopy"
	canopy_layer.y_sort_enabled = true
	canopy_layer.z_index = 8
	add_child(canopy_layer)
	_build_room_art()
	# Collision follows the walkable edge; the thicket trees are the visible wall.
	wall_generator = SlasherWallGenerator.new()
	wall_generator.name = "WallGenerator"
	wall_generator.profile_id = String(profile.get("wall_profile", "stone_wall"))
	wall_generator.tile_size = TILE
	wall_generator.render_visuals = false
	wall_generator.render_collisions = true
	add_child(wall_generator)
	wall_topology = wall_generator.generate(layout.cells, [], ORIGIN)
	if String(_room_theme().walls) == "stone":
		_build_stone_walls(profile)
	else:
		_build_thicket()
	_build_decorations()
	_build_solid_props()
	_build_landmarks()
	_build_doors()
	_build_mist()
	_build_vignette()


## The room's painted art (maps/forest/rooms/*.tscn). Rooms without a scene
## fall back to the ground drawn in code from the forest sheet.
func _build_room_art() -> void:
	var template := ROOMS.template(String(layout.get("template_id", "")))
	if template.is_empty() and MapPlaytest.active():
		template = MapPlaytest.template()
	if String(template.get("scene", "")).is_empty():
		FOREST_TERRAIN_ART.build_room_ground(ground_layer, layout, TILE, ORIGIN)
		return
	var art := MapLibrary.art_nodes(template)
	for node in art.ground:
		node.position += ORIGIN
		ground_layer.add_child(node)
	for node in art.canopy:
		node.position += ORIGIN
		node.z_index = 0
		canopy_layer.add_child(node)


## Stone dungeons: the wall generator draws real walls around the room. Pits and
## a colossus's body count as floor here, so they read as holes and bodies, not walls.
func _build_stone_walls(profile: Dictionary) -> void:
	var visual_cells: Dictionary = Dictionary(layout.cells).duplicate()
	for cell in Dictionary(layout.get("water_cells", {})):
		visual_cells[cell] = true
	for cell in Dictionary(layout.get("colossus_cells", {})):
		visual_cells[cell] = true
	var walls := SlasherWallGenerator.new()
	walls.name = "StoneWalls"
	walls.profile_id = String(profile.get("wall_profile", "stone_wall"))
	walls.tile_size = TILE
	walls.render_visuals = true
	walls.render_collisions = false
	add_child(walls)
	walls.generate(visual_cells, [], ORIGIN)


func _build_thicket() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(
		"%s:%d:thicket" % [String(run_state.field_run.get("forest_floor_key", "")), room_id]
	)
	var cells: Dictionary = layout.cells
	var thicket: Dictionary = layout.thicket_cells
	for value in thicket:
		var cell: Vector2i = value
		# Dark undergrowth makes the boundary read as impassable even between trunks.
		var shade_rect := ColorRect.new()
		shade_rect.name = "Undergrowth_%d_%d" % [cell.x, cell.y]
		shade_rect.color = Color(0.03, 0.09, 0.04, 0.62)
		shade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade_rect.position = _world(cell) - Vector2(TILE, TILE) * 0.5
		shade_rect.size = Vector2(TILE, TILE)
		ground_layer.add_child(shade_rect)
		var facing_room := false
		for direction in ROOMS.DIRECTIONS.values():
			if cells.has(cell + Vector2i(direction)):
				facing_room = true
		var count := 1 if facing_room else 2
		for index in count:
			var kind: String = (
				THICKET_KINDS[rng.randi_range(0, THICKET_KINDS.size() - 1)]
				if facing_room and index == 0
				else ("tree_wide" if rng.randf() < 0.6 else "tree_small")
			)
			var tree := SlasherForestArt.make_sprite(kind)
			tree.name = "Thicket_%d_%d_%d" % [cell.x, cell.y, index]
			tree.position = (
				_world(cell) + Vector2(rng.randf_range(-12, 12), rng.randf_range(-8, 12))
			)
			if rng.randf() < 0.5:
				tree.flip_h = true
			var shade := (
				rng.randf_range(0.7, 0.95) if not facing_room else rng.randf_range(0.82, 1.0)
			)
			tree.modulate = Color(shade, shade * 1.03, shade, 1.0)
			canopy_layer.add_child(tree)


func _build_landmarks() -> void:
	if not rooms_active:
		super._build_landmarks()
		return
	var gate := Vector2i(layout.exit)
	exit_position = _world(gate) if gate.x >= 0 else Vector2(-99999, -99999)
	if bool(layout.get("exit_under_body", false)):
		# The way on is hidden in the guardian's body; it opens when it falls.
		exit_position = Vector2(-99999, -99999)
		if bool(room.get("cleared", false)) or not bool(layout.get("is_boss_floor", false)):
			_open_guardian_ways(false)
		gate = Vector2i(-100, -100)
	if gate.x >= 0:
		var theme := _room_theme()
		var exit_root := Node2D.new()
		exit_root.name = "RootGate"
		exit_root.position = exit_position
		exit_root.z_index = 12
		exit_root.add_child(_glow(Color(String(theme.exit_glow)), 34))
		var exit_sprite := SlasherForestArt.make_sprite(String(theme.exit_sprite))
		exit_sprite.position = (
			Vector2(0, -30) if String(theme.exit_sprite) == "exit" else Vector2.ZERO
		)
		exit_root.add_child(exit_sprite)
		actor_layer.add_child(exit_root)
	if (
		Vector2i(layout.get("colossus", Vector2i(-100, -100))).x >= 0
		and (bool(room.get("cleared", false)) or not bool(layout.get("is_boss_floor", false)))
	):
		_build_colossus_remains()
	var merchant_cell := Vector2i(layout.merchant)
	has_dungeon_merchant = room_role == "shop" and merchant_cell.x >= 0
	merchant_position = _world(merchant_cell) if has_dungeon_merchant else Vector2(-99999, -99999)
	if has_dungeon_merchant:
		var merchant_root := Node2D.new()
		merchant_root.name = "CampMerchant"
		merchant_root.position = merchant_position
		merchant_root.add_child(_glow(Color("#e8b94e"), 28))
		var merchant_sprite := SlasherForestArt.make_sprite("merchant")
		merchant_sprite.position = Vector2(0, -28)
		merchant_root.add_child(merchant_sprite)
		actor_layer.add_child(merchant_root)
		_build_shop_floor()
	var fire := Vector2i(layout.get("campfire", Vector2i(-100, -100)))
	campfire_position = _world(fire) if fire.x >= 0 else Vector2(-99999, -99999)
	if fire.x >= 0:
		var camp := Node2D.new()
		camp.name = "Campfire"
		camp.position = campfire_position
		var flames := SlasherForestArt.make_sprite("campfire")
		flames.name = "Flames"
		var height := flames.get_rect().size.y
		if height > 0.0:
			flames.scale = Vector2.ONE * (CAMPFIRE_HEIGHT / height)
		flames.position = Vector2(0, -CAMPFIRE_HEIGHT * 0.3)
		camp.add_child(flames)
		camp.add_child(_glow(Color("#ff9a3d"), 46))
		var blocker := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 18
		shape.shape = circle
		blocker.add_child(shape)
		camp.add_child(blocker)
		actor_layer.add_child(camp)
		if pathfinder != null:
			pathfinder.set_cell_blocked(fire, true)
	var pedestal := Vector2i(layout.treasure)
	active_pedestal = null
	if room_role == "treasure" and pedestal.x >= 0 and not _treasure_active().is_empty():
		_build_active_pedestal(_world(pedestal))
	elif (
		room_role == "treasure"
		and pedestal.x >= 0
		and not bool(room.get("reward_claimed", false))
		and not bool(Dictionary(room.get("slasher", {})).get("active_room", false))
	):
		treasure_area = Area2D.new()
		treasure_area.name = "TreasurePedestal"
		treasure_area.position = _world(pedestal)
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 24
		shape.shape = circle
		treasure_area.add_child(shape)
		treasure_area.add_child(_glow(Color("#d67ee8"), 30))
		var relic := SlasherForestArt.make_sprite("chest_open")
		relic.position = Vector2(0, -10)
		treasure_area.add_child(relic)
		actor_layer.add_child(treasure_area)


## A door is an opening in the thicket on the centre of an edge. While foes remain
## it is barred by brambles; once the room is clear the brambles pull back.
func _build_doors() -> void:
	door_nodes.clear()
	for direction in Dictionary(layout.doors):
		var cell: Vector2i = layout.doors[direction]
		var door := Node2D.new()
		door.name = "Door_%s" % direction
		door.position = _world(cell)
		actor_layer.add_child(door)
		var barrier := StaticBody2D.new()
		barrier.name = "Brambles"
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(TILE, TILE)
		shape.shape = rect
		barrier.add_child(shape)
		_dress_door_barrier(barrier, direction)
		door.add_child(barrier)
		var neighbor := run_state.get_field_room(int(Dictionary(room.neighbors).get(direction, -1)))
		var to_gate := String(neighbor.get("role", "")) == "boss"
		var guarded := to_gate and not bool(neighbor.get("cleared", false)) and floor_gate_guarded()
		var glow := _glow(
			Color("#e0503c") if guarded else (Color("#83d978") if to_gate else Color("#9fe39a")),
			26 if to_gate else 22
		)
		glow.name = "OpenGlow"
		door.add_child(glow)
		if to_gate:
			var mark := GateDoorMark.new()
			mark.name = "GateMark"
			mark.guarded = guarded
			mark.position = Vector2(0, -6)
			mark.scale = Vector2.ONE * 1.5
			mark.z_index = 9
			door.add_child(mark)
		var hint := Label.new()
		hint.name = "Hint"
		hint.text = _door_hint(neighbor)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.size = Vector2(120, 20)
		hint.position = Vector2(-60, -46 if direction != "north" else 24)
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", Color("#f3e3b4"))
		hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		hint.add_theme_constant_override("outline_size", 4)
		door.add_child(hint)
		if to_gate:
			hint.position.y = -78 if direction != "north" else 30
			hint.add_theme_color_override(
				"font_color", Color("#ff8a70") if guarded else Color("#b8f0a8")
			)
			hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			hint.add_theme_constant_override("outline_size", 5)
			hint.z_as_relative = false
			hint.z_index = 30
		door_nodes[direction] = door
	_set_doors_open(exit_open)


## What blocks a door while foes remain: brambles in the forest.
func _dress_door_barrier(barrier: Node2D, _direction: String) -> void:
	for offset in [Vector2(-12, -4), Vector2(12, 2), Vector2(0, 10)]:
		var bush := SlasherForestArt.make_sprite("rounded_bush" if offset.y < 5 else "low_bush_b")
		bush.position = offset
		bush.modulate = Color(0.62, 0.48, 0.42)
		barrier.add_child(bush)


func _door_hint(neighbor: Dictionary) -> String:
	# The way to the gate room is recognisable before you go in.
	if String(neighbor.get("role", "")) == "boss" and not bool(neighbor.get("cleared", false)):
		if run_state.is_slasher_boss_floor():
			return "Guardian"
		if floor_gate_guarded():
			return "Elite Guardian"
	var gate_name := String(_room_theme().gate_name)
	if not bool(neighbor.get("visited", false)):
		return gate_name if String(neighbor.get("role", "")) == "boss" else "?"
	match String(neighbor.get("role", "")):
		"shop":
			return "Camp"
		"treasure":
			return "Treasure" if not bool(neighbor.get("reward_claimed", false)) else ""
		"boss":
			return gate_name
		"rest":
			return "Campfire"
	return ""


func _set_doors_open(open: bool) -> void:
	for direction in door_nodes:
		var door: Node2D = door_nodes[direction]
		if not is_instance_valid(door):
			continue
		var barrier := door.get_node_or_null("Brambles") as StaticBody2D
		if barrier != null:
			barrier.visible = not open
			(barrier.get_child(0) as CollisionShape2D).set_deferred("disabled", open)
		var glow := door.get_node_or_null("OpenGlow") as Node2D
		if glow != null:
			glow.visible = open
		var hint := door.get_node_or_null("Hint") as Label
		# The gate room's door is always labelled, even while the brambles are up.
		if hint != null:
			hint.visible = (
				(open or door.get_node_or_null("GateMark") != null) and not hint.text.is_empty()
			)


# ---------------------------------------------------------------- encounters


func _spawn_enemies() -> void:
	super._spawn_enemies()
	if rooms_active:
		if exit_open and not bool(room.get("cleared", false)):
			_mark_room_cleared(false)
		_set_doors_open(exit_open)


func _reveal_secret_door() -> void:
	if rooms_active:
		return
	super._reveal_secret_door()


func _on_enemy_defeated(enemy: SlasherEnemy, reward: int) -> void:
	super._on_enemy_defeated(enemy, reward)
	if rooms_active and enemy is SlasherColossus:
		_build_colossus_remains()
		_open_guardian_ways(true)
	# The guardian's fall ends the fight: its pack scatters and the gate opens.
	if rooms_active and room_role == "boss" and enemies_remaining > 0 and _is_room_guardian(enemy):
		_scatter_remaining_foes()
	if rooms_active and enemies_remaining == 0:
		_mark_room_cleared(true)
		_set_doors_open(true)
		_spawn_loot()
		_show_message(
			(
				String(_room_theme().gate_open)
				if Vector2i(layout.exit).x >= 0
				else String(_room_theme().room_clear)
			)
		)


# ---------------------------------------------------------------- the fallen guardian


## Whether there's a dungeon beyond this one to press on to. When there isn't,
## the passage through the body stays shut and only the portal home opens.
func can_press_on() -> bool:
	if controller != null and controller.has_method("can_press_on"):
		return bool(controller.call("can_press_on"))
	return true


## After the guardian falls: a passage opens through its body to the way on
## (walk through the remains to continue), and a portal showing the Hearth
## appears beside it (walk in to go home).
func _open_guardian_ways(live: bool) -> void:
	if not bool(layout.get("exit_under_body", false)):
		return
	if can_press_on():
		var cells: Dictionary = layout.cells
		var changed := false
		for cell in Array(layout.passage_cells):
			if not cells.has(cell):
				cells[cell] = true
				changed = true
		exit_position = _world(Vector2i(layout.exit))
		if changed and live:
			wall_topology = wall_generator.generate(cells, [], ORIGIN)
			pathfinder = GRID_PATHFINDER.new().configure(
				cells, Array(layout.get("solid_props", [])), ORIGIN, float(TILE)
			)
		if actor_layer.get_node_or_null("HiddenWay") == null:
			var way := Node2D.new()
			way.name = "HiddenWay"
			way.position = exit_position
			way.add_child(_glow(Color(String(_room_theme().exit_glow)), 30))
			actor_layer.add_child(way)
	var portal_cell := Vector2i(layout.get("portal", Vector2i(-100, -100)))
	if portal_cell.x >= 0 and actor_layer.get_node_or_null("TavernPortal") == null:
		var portal := TavernPortal.new()
		portal.name = "TavernPortal"
		portal.position = _world(portal_cell)
		actor_layer.add_child(portal)
	if live:
		_show_message(
			"The guardian falls · walk through it to go on, or take the portal home.", 4.0
		)


func _take_portal_home() -> void:
	if floor_reward_claimed:
		return
	if controller != null and "guardian_choice" in controller:
		controller.guardian_choice = "home"
	_complete_floor()


func _complete_floor() -> void:
	if (
		bool(layout.get("exit_under_body", false))
		and controller != null
		and "guardian_choice" in controller
		and String(controller.guardian_choice).is_empty()
	):
		controller.guardian_choice = "onward"
	super._complete_floor()


## A shimmering ring with a glimpse of the Hearth in it: the way home.
class TavernPortal:
	extends Node2D
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(t * 2.4)
		draw_set_transform(Vector2(0, -34), 0.0, Vector2(0.62, 1.0))
		draw_circle(Vector2.ZERO, 40, Color(1.0, 0.78, 0.42, 0.18 + pulse * 0.12))
		draw_circle(Vector2.ZERO, 31, Color("#3a2414"))
		draw_rect(Rect2(-16, -2, 32, 18), Color("#a8673a"))
		draw_colored_polygon(
			PackedVector2Array([Vector2(-20, -2), Vector2(0, -18), Vector2(20, -2)]),
			Color("#6b3b22")
		)
		draw_rect(Rect2(-4, 6, 8, 10), Color("#ffd27a"))
		draw_rect(Rect2(-13, 2, 6, 5), Color("#ffd27a"))
		draw_rect(Rect2(7, 2, 6, 5), Color("#ffd27a"))
		draw_arc(Vector2.ZERO, 36, 0, TAU, 40, Color(1.0, 0.86, 0.5, 0.85), 5.0)
		draw_set_transform(Vector2.ZERO)


## The foe whose death decides the gate room: the boss on boss floors, the
## elite guardian on elite floors.
func _is_room_guardian(enemy: SlasherEnemy) -> bool:
	if not is_instance_valid(enemy):
		return false
	if enemy.boss:
		return true
	return (
		bool(layout.get("is_guarded", false))
		and enemy.mini_boss
		and not bool(layout.get("is_boss_floor", false))
	)


func _scatter_remaining_foes() -> void:
	for node in get_tree().get_nodes_in_group("slasher_enemy"):
		var foe := node as SlasherEnemy
		if not is_instance_valid(foe) or foe.dead:
			continue
		foe.dead = true
		foe.remove_from_group("slasher_enemy")
		foe.remove_from_group("slasher_damageable")
		foe.remove_from_group("slasher_wolf")
		foe.set_physics_process(false)
		var fade := foe.create_tween()
		fade.tween_property(foe, "modulate:a", 0.0, 0.45)
		fade.tween_callback(foe.queue_free)
	enemies_remaining = 0
	exit_open = true
	_mark_room_cleared(true)
	_set_doors_open(true)
	_spawn_loot()
	AudioCue.play_from(self, "reward", false)
	_show_message(String(_room_theme().guardian_falls), 3.0)
	_refresh_hud()


func _mark_room_cleared(fought: bool) -> void:
	room["cleared"] = true
	run_state.update_field_room(room_id, {"cleared": true})
	call_deferred("_save_checkpoint")
	if fought:
		# Clearing a fight charges the active item by one pip.
		ActiveItems.add_room_charge(run_state, 1)
		_refresh_active_hud()
		# A chance of one pickup in the middle of the room.
		roll_room_clear_pickup(
			sanitize_player_position(_world(Vector2i(layout.get("center", layout.start))))
		)


## Loot caches appear once a room is safe and stay collected when you come back.
func _spawn_loot() -> void:
	if not rooms_active:
		super._spawn_loot()
		return
	for loot in loot_nodes:
		if is_instance_valid(loot):
			loot.queue_free()
	loot_nodes.clear()
	if not exit_open:
		return
	var taken: Array = Array(Dictionary(room.get("slasher", {})).get("loot_taken", []))
	var kinds := ["gold", "potion", "key"] if RunState.potions_drop() else ["gold", "gold", "key"]
	for index in Array(layout.loot_spawns).size():
		var cell: Vector2i = layout.loot_spawns[index]
		if taken.has(cell):
			continue
		var area := Area2D.new()
		area.name = "ForestCache"
		area.position = _world(cell)
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 14
		shape.shape = circle
		area.add_child(shape)
		var kind := String(kinds[(room_id + index) % kinds.size()])
		var sprite := SlasherForestArt.make_sprite(kind)
		sprite.position = Vector2(0, -8)
		area.add_child(sprite)
		area.add_child(_glow(Color("#f3d366"), 18))
		area.set_meta("kind", kind)
		area.set_meta("room_cell", cell)
		actor_layer.add_child(area)
		loot_nodes.append(area)


func _collect_loot(loot: Area2D) -> void:
	if rooms_active and loot.has_meta("room_cell"):
		_remember("loot_taken", Vector2i(loot.get_meta("room_cell")))
	super._collect_loot(loot)


func _on_prop_broken(prop: SlasherBreakableProp, kind: String, cell: Vector2i) -> void:
	super._on_prop_broken(prop, kind, cell)
	if rooms_active:
		_remember("destroyed_props", cell)
	if rooms_active and kind == String(_room_theme().hollow_kind) and cell == _hollow_cell():
		_spawn_hidden_chest(cell)
		AudioCue.play_from(self, "reward", false)
		_show_message(String(_room_theme().hollow_found), 3.0)


func _on_chest_opened(chest: SlasherBreakableProp, cell: Vector2i) -> void:
	if not rooms_active:
		super._on_chest_opened(chest, cell)
		return
	if pathfinder != null:
		pathfinder.set_cell_blocked(cell, false)
	_remember("destroyed_props", cell)
	relic_choice_source = "chest"
	var cycle: int = (
		maxi(0, run_state.get_slasher_cycle_number() - 1) if run_state.slasher_endless_mode else 0
	)
	relic_modal.open(
		run_state,
		run_state.generate_slasher_chest_choices(
			run_state.current_floor, "room_%d_chest_%d_%d" % [room_id, cell.x, cell.y], cycle
		),
		true
	)


# ---------------------------------------------------------------- hollow trees


## Rooms with breakable trees may hide a chest inside one of them, a shade
## darker than the rest. Decided once per room per floor and remembered.
## TUNING: breakable_props.tree_large.hollow_chance in slasher_balance.json.
func _build_solid_props() -> void:
	super._build_solid_props()
	if not rooms_active:
		return
	var hollow := _hollow_cell()
	if hollow.x < 0:
		return
	var standing := false
	for node in actor_layer.get_children():
		if (
			node is SlasherBreakableProp
			and node.prop_kind == String(_room_theme().hollow_kind)
			and node.cell == hollow
		):
			standing = true
			node.set_meta("hollow", true)
			node.modulate = Color(0.66, 0.6, 0.58)
	if not standing and not bool(Dictionary(room.get("slasher", {})).get("hollow_opened", false)):
		_spawn_hidden_chest(hollow)


func _hollow_cell() -> Vector2i:
	var state: Dictionary = Dictionary(room.get("slasher", {}))
	if not state.has("hollow_tree"):
		var cell := Vector2i(-1, -1)
		var hollow_kind := String(_room_theme().hollow_kind)
		var trees: Array = Array(layout.solid_props).filter(
			func(prop): return String(prop.kind) == hollow_kind
		)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(
			"%s:%d:hollow" % [String(run_state.field_run.get("forest_floor_key", "")), room_id]
		)
		var chance := float(
			Dictionary(GameBalance.get_slasher_balance("breakable_props").get(hollow_kind, {})).get(
				"hollow_chance", 0.4
			)
		)
		if not trees.is_empty() and rng.randf() < chance:
			cell = Vector2i(trees[rng.randi_range(0, trees.size() - 1)].cell)
		state["hollow_tree"] = cell
		room["slasher"] = state
		run_state.update_field_room(room_id, {"slasher": state})
	return Vector2i(state.hollow_tree)


## A chest that needs no key: finding it is the reward.
func _spawn_hidden_chest(cell: Vector2i) -> void:
	var chest: SlasherBreakableProp = BREAKABLE_PROP.new()
	chest.name = "HiddenChest"
	chest.setup("chest", cell)
	chest.position = _world(cell)
	chest.set_meta("no_key", true)
	chest.opened.connect(
		func(_chest, at):
			var state: Dictionary = Dictionary(room.get("slasher", {}))
			state["hollow_opened"] = true
			room["slasher"] = state
			run_state.update_field_room(room_id, {"slasher": state})
	)
	chest.opened.connect(_on_chest_opened)
	actor_layer.add_child(chest)
	chest.add_child(_glow(Color("#f3d366"), 20))
	if pathfinder != null:
		pathfinder.set_cell_blocked(cell, true)


func _remember(key: String, cell: Vector2i) -> void:
	var state: Dictionary = Dictionary(room.get("slasher", {}))
	var list: Array = Array(state.get(key, []))
	if not list.has(cell):
		list.append(cell)
	state[key] = list
	room["slasher"] = state
	run_state.update_field_room(room_id, {"slasher": state})


func _should_have_secret_door() -> bool:
	return false if rooms_active else super._should_have_secret_door()


# ---------------------------------------------------------------- moving between rooms


func _process(delta: float) -> void:
	super._process(delta)
	if not rooms_active or not is_instance_valid(player):
		return
	transition_cooldown = maxf(0.0, transition_cooldown - delta)
	if player.input_locked or (relic_modal != null and relic_modal.visible):
		return
	if (
		treasure_area != null
		and is_instance_valid(treasure_area)
		and player.global_position.distance_to(treasure_area.global_position) < 40
	):
		_open_treasure()
	var portal := (
		actor_layer.get_node_or_null("TavernPortal") if is_instance_valid(actor_layer) else null
	)
	if portal != null and player.global_position.distance_to(portal.global_position) < 42:
		_take_portal_home()
		return
	if room_role == "rest" and player.global_position.distance_to(campfire_position) < 70:
		_offer_rest()
	if is_instance_valid(active_pedestal):
		_check_active_pedestal()
	_check_doors()


func _check_doors() -> void:
	if transition_cooldown > 0.0 or not exit_open:
		return
	for direction in door_nodes:
		var door: Node2D = door_nodes[direction]
		if (
			not is_instance_valid(door)
			or player.global_position.distance_to(door.global_position) > DOOR_TRIGGER_RADIUS
		):
			continue
		var neighbor := int(Dictionary(room.neighbors).get(direction, -1))
		if neighbor < 0:
			continue
		# A locked treasure room: a key opens it for good.
		var target := run_state.get_field_room(neighbor)
		if bool(target.get("locked", false)):
			if run_state.keys <= 0:
				_show_message("Locked · it needs a key.", 0.4)
				return
			run_state.keys -= 1
			run_state.update_field_room(neighbor, {"locked": false})
			AudioCue.play_from(self, "pickup")
			_show_message("Unlocked with a key.", 1.6)
		AudioCue.play_at_from(self, "door_open", player.global_position)
		transition_cooldown = 1.0
		run_state.field_run["arrival_direction"] = ROOMS.OPPOSITE[direction]
		run_state.enter_field_room(neighbor, room_id)
		call_deferred("_build_floor")
		return


func _offer_rest() -> void:
	if bool(room.get("rested", false)):
		_show_message("The fire has burned low. You have already rested here.", 0.15)
		return
	var amount := maxi(1, int(round(player.max_health * REST_HEAL_SHARE)))
	_show_message("Rest by the fire · press E to recover %d health." % amount, 0.15)
	if not Input.is_action_just_pressed("interact"):
		return
	player.basic_mouse_held = false
	rest_at_campfire()


## Rest once per campfire, restoring part of the active hero's health.
func rest_at_campfire() -> bool:
	if room_role != "rest" or bool(room.get("rested", false)):
		return false
	player.heal(maxi(1, int(round(player.max_health * REST_HEAL_SHARE))))
	room["rested"] = true
	run_state.update_field_room(room_id, {"rested": true})
	AudioCue.play_from(self, "reward", false)
	_store_active_slasher_state()
	_refresh_hud()
	_show_message(
		(
			"%s rests by the fire and recovers." % run_state.get_active_character().display_name
			if run_state.get_active_character() != null
			else "You rest by the fire and recover."
		)
	)
	return true


# ---------------------------------------------------------------- active item pedestals


## Which active item this treasure room's pedestal holds ("" for a relic room,
## or once taken). Decided the first time the room is built, then remembered,
## including the item you leave behind when you swap.
## TUNING: treasure_chance in data/active_items.json.
func _treasure_active() -> String:
	if room_role != "treasure" or _is_tutorial_expedition():
		return ""
	var state: Dictionary = Dictionary(room.get("slasher", {}))
	if not state.has("active_pedestal"):
		var id := ""
		var held := ActiveItems.held(run_state)
		var pool: Array[String] = ActiveItems.ids_for_class(run_state.selected_class_id).filter(
			func(item_id): return item_id != held
		)
		var stats := run_state.run_stats()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(
			"%s:%d:active" % [String(run_state.field_run.get("forest_floor_key", "")), room_id]
		)
		var first_offer := held.is_empty() and not bool(stats.get("active_offered", false))
		if (
			not pool.is_empty()
			and (
				first_offer or rng.randf() < float(ActiveItems.data().get("treasure_chance", 0.35))
			)
		):
			id = pool[rng.randi_range(0, pool.size() - 1)]
			stats["active_offered"] = true
		state["active_pedestal"] = id
		state["active_room"] = not id.is_empty()
		room["slasher"] = state
		run_state.update_field_room(room_id, {"slasher": state})
	return String(state.get("active_pedestal", ""))


func _build_active_pedestal(at: Vector2) -> void:
	var pedestal := ActivePedestal.new()
	pedestal.name = "ActivePedestal"
	pedestal.position = at
	pedestal.item_id = _treasure_active()
	pedestal.add_child(_glow(Color("#f3d366"), 30))
	actor_layer.add_child(pedestal)
	active_pedestal = pedestal


func _check_active_pedestal() -> void:
	var distance := player.global_position.distance_to(active_pedestal.global_position)
	if distance > 64.0:
		_pedestal_armed = true
		return
	var id := String(active_pedestal.get("item_id"))
	if id.is_empty() or not _pedestal_armed or distance > 44.0:
		return
	var held := ActiveItems.held(run_state)
	if held.is_empty():
		take_active_item()
		return
	_show_message(
		(
			"Press E to swap %s for %s."
			% [
				String(ActiveItems.item(held).get("name", held)),
				String(ActiveItems.item(id).get("name", id))
			]
		),
		0.15
	)
	if Input.is_action_just_pressed("interact"):
		player.basic_mouse_held = false
		take_active_item()


## Takes the pedestal's item into the active slot; whatever was held is left on the pedestal.
func take_active_item() -> String:
	if not is_instance_valid(active_pedestal):
		return ""
	var id := String(active_pedestal.get("item_id"))
	if id.is_empty():
		return ""
	var old := ActiveItems.give(run_state, id)
	SlasherActiveEffects.ensure_runtime(player, id)
	var state: Dictionary = Dictionary(room.get("slasher", {}))
	state["active_pedestal"] = old
	room["slasher"] = state
	room["reward_claimed"] = true
	run_state.update_field_room(room_id, {"slasher": state, "reward_claimed": true})
	active_pedestal.set("item_id", old)
	active_pedestal.queue_redraw()
	_pedestal_armed = false
	AudioCue.play_from(self, "reward", false)
	var record := ActiveItems.item(id)
	if dungeon_hud != null:
		dungeon_hud.show_pickup(
			String(record.get("name", id)).to_upper(), String(record.get("description", ""))
		)
	_refresh_active_hud()
	return old


func _open_treasure() -> void:
	if relic_modal == null or relic_modal.visible:
		return
	AudioCue.play_at_from(self, "chest_open", treasure_area.global_position)
	treasure_area.queue_free()
	treasure_area = null
	room["reward_claimed"] = true
	run_state.update_field_room(room_id, {"reward_claimed": true})
	relic_choice_source = "chest"
	var cycle: int = (
		maxi(0, run_state.get_slasher_cycle_number() - 1) if run_state.slasher_endless_mode else 0
	)
	relic_modal.open(
		run_state,
		run_state.generate_slasher_chest_choices(
			run_state.current_floor, "room_%d_treasure" % room_id, cycle
		),
		true
	)


## The base scene connects to settings once per player spawn; rooms respawn the
## player on every transition, so drop the previous connection first.
func _spawn_player() -> void:
	var settings := _settings()
	if settings != null and settings.settings_changed.is_connected(_on_game_setting_changed):
		settings.settings_changed.disconnect(_on_game_setting_changed)
	super._spawn_player()
	_apply_arena_zoom()


## Colossus arenas are bigger than the screen, so the camera pulls back there to
## keep the guardian in view (dungeons.json slasher.guardian_camera_zoom).
func _apply_arena_zoom() -> void:
	if not rooms_active or not is_instance_valid(player) or player.camera == null:
		return
	if (
		Vector2i(layout.get("colossus", Vector2i(-100, -100))).x < 0
		or bool(room.get("cleared", false))
	):
		return
	player.camera.zoom *= float(_slasher_config().get("guardian_camera_zoom", 0.75))


func _on_game_setting_changed(key: String, value: Variant) -> void:
	super._on_game_setting_changed(key, value)
	if key in ["slasher_zoom", "reset"]:
		_apply_arena_zoom()


func _snapshot_player() -> Dictionary:
	if not is_instance_valid(player):
		return {}
	return {
		"cooldowns": player.cooldowns.duplicate(),
		"invulnerable": player.invulnerable,
		"defense_window": player.defense_window,
		"defense_kind": player.defense_kind,
		"consumable_speed_time": player.consumable_speed_time,
		"consumable_speed_multiplier": player.consumable_speed_multiplier,
		"fighter_frenzy":
		{
			"left": player.fighter_frenzy_left,
			"damage": player.fighter_frenzy_damage,
			"haste": player.fighter_frenzy_haste,
			"incoming": player.fighter_frenzy_incoming
		}
	}


func _restore_player(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	# Room transitions rebuild the player even outside campaign expeditions.
	# Preserve both sides of the frenzy commitment, not only its offensive half.
	if snapshot.has("fighter_frenzy"):
		var frenzy: Dictionary = snapshot.fighter_frenzy
		player.activate_fighter_frenzy(
			float(frenzy.left), float(frenzy.damage), float(frenzy.haste), float(frenzy.incoming)
		)
	player.cooldowns = Dictionary(snapshot.get("cooldowns", player.cooldowns))
	player.invulnerable = float(snapshot.get("invulnerable", 0))
	player.defense_window = float(snapshot.get("defense_window", 0))
	player.defense_kind = String(snapshot.get("defense_kind", ""))
	player.consumable_speed_time = float(snapshot.get("consumable_speed_time", 0))
	player.consumable_speed_multiplier = float(snapshot.get("consumable_speed_multiplier", 1))


# ---------------------------------------------------------------- HUD


func _build_hud() -> void:
	super._build_hud()
	if not rooms_active:
		return
	var map := ROOM_MINIMAP.new()
	map.name = "ForestRoomMap"
	map.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	map.offset_left = -200
	map.offset_right = -22
	map.offset_top = 20
	map.offset_bottom = 140
	map.setup(run_state)
	get_node("HUD").add_child(map)


func _refresh_hud() -> void:
	super._refresh_hud()
	if not rooms_active or objective_label == null or not is_instance_valid(player):
		return
	var depth_text: String = (
		"ENDLESS · FLOOR %d" % run_state.current_floor
		if run_state.slasher_endless_mode
		else "FLOOR %d" % run_state.current_floor
	)
	var status := (
		"%d FOES" % enemies_remaining
		if not exit_open
		else ("GATE OPEN" if Vector2i(layout.exit).x >= 0 else "CLEAR")
	)
	if bool(layout.get("is_boss_floor", false)) and not exit_open:
		status = "BOSS"
	elif bool(layout.get("is_guarded", false)) and not exit_open:
		status = "ELITE GUARDIAN"
	objective_label.text = (
		"VERDANT FOREST  ·  %s  ·  %s  ·  %s"
		% [depth_text, String(layout.room_name).to_upper(), status]
	)
	var map := get_node_or_null("HUD/ForestRoomMap")
	if map:
		map.queue_redraw()


# ---------------------------------------------------------------- guardian warnings


## A stone pedestal with an active item floating over it.
class ActivePedestal:
	extends Node2D
	var item_id := "":
		set(value):
			item_id = value
			_refresh()
	var icon: Sprite2D
	var label: Label
	var _time := 0.0

	func _ready() -> void:
		icon = Sprite2D.new()
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(icon)
		label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(160, 20)
		label.position = Vector2(-80, 14)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color("#f6d77a"))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("outline_size", 4)
		add_child(label)
		_refresh()

	func _refresh() -> void:
		if icon == null or label == null:
			return
		var record := ActiveItems.item(item_id)
		label.text = String(record.get("name", "")) if not item_id.is_empty() else ""

	func _process(delta: float) -> void:
		_time += delta
		if icon != null:
			icon.position = Vector2(0, -38 + sin(_time * 3.0) * 4.0)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-18, -14, 36, 22), Color("#3d3a44"))
		draw_rect(Rect2(-22, 4, 44, 8), Color("#2a2730"))
		draw_rect(Rect2(-18, -14, 36, 4), Color("#77707f"))
		if not item_id.is_empty():
			var float_at := Vector2(0, -38 + sin(_time * 3.0) * 4.0)
			draw_circle(float_at, 22.0, Color(1.0, 0.9, 0.5, 0.18))
			SlasherActiveEffects.draw_icon(self, item_id, float_at, 34.0)


## The intro when you walk into the guardian's room.
func _show_guardian_banner() -> void:
	var hud := get_node_or_null("HUD")
	if hud == null:
		return
	var boss := bool(layout.get("is_boss_floor", false))
	var boss_id := "dark_druid"
	for node in actor_layer.get_children():
		if node is SlasherEnemy and node.boss:
			boss_id = String(node.visual_id)
	var guardian_name := String(
		GameBalance.get_slasher_journal_entry(String(gate_guardian().visual_id)).get(
			"name", "Elite Guardian"
		)
	)
	var title := (
		String(GameBalance.get_slasher_journal_entry(boss_id).get("name", "The Guardian"))
		if boss
		else guardian_name
	)
	var banner := GuardianBanner.new()
	banner.name = "GuardianBanner"
	banner.setup(
		title.to_upper(),
		(
			(
				"Guardian of the %s"
				% String(GameBalance.get_dungeon(run_state.active_dungeon_id).get("name", "Forest"))
			)
			if boss
			else "The %s is held" % String(_room_theme().gate_name)
		),
		Color("#e0503c") if boss else Color("#ff9e3d")
	)
	hud.add_child(banner)
	AudioCue.play_from(self, "combo", false)


## A horned skull over the door to a guarded gate room; a plain gate glyph otherwise.
class GateDoorMark:
	extends Node2D
	var guarded := false
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.75 + 0.25 * sin(_time * 4.0)
		if not guarded:
			draw_arc(Vector2(0, -8), 9.0, PI, TAU, 12, Color(0.55, 0.9, 0.5, 0.9), 3.0)
			draw_line(Vector2(-9, -8), Vector2(-9, 2), Color(0.55, 0.9, 0.5, 0.9), 3.0)
			draw_line(Vector2(9, -8), Vector2(9, 2), Color(0.55, 0.9, 0.5, 0.9), 3.0)
			return
		var bone := Color(0.95, 0.9, 0.82, pulse)
		var dark := Color(0.12, 0.04, 0.04, 1.0)
		var top := Vector2(0, -6)
		draw_colored_polygon(
			PackedVector2Array(
				[top + Vector2(-10, -4), top + Vector2(-20, -16), top + Vector2(-14, -2)]
			),
			Color(0.7, 0.18, 0.12, pulse)
		)
		draw_colored_polygon(
			PackedVector2Array(
				[top + Vector2(10, -4), top + Vector2(20, -16), top + Vector2(14, -2)]
			),
			Color(0.7, 0.18, 0.12, pulse)
		)
		draw_circle(top, 11.0, dark)
		draw_circle(top, 10.0, bone)
		draw_rect(Rect2(top + Vector2(-6, 6), Vector2(12, 6)), bone)
		draw_circle(top + Vector2(-4, 0), 3.2, dark)
		draw_circle(top + Vector2(4, 0), 3.2, dark)
		draw_line(top + Vector2(-2, 9), top + Vector2(-2, 12), dark, 1.0)
		draw_line(top + Vector2(2, 9), top + Vector2(2, 12), dark, 1.0)


## A band across the screen naming the guardian, sliding in then fading out.
class GuardianBanner:
	extends Control
	var title := ""
	var subtitle := ""
	var tint := Color.RED

	func setup(title_text: String, subtitle_text: String, colour: Color) -> void:
		title = title_text
		subtitle = subtitle_text
		tint = colour

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var band := ColorRect.new()
		band.color = Color(0.03, 0.02, 0.02, 0.82)
		band.anchor_left = 0.0
		band.anchor_right = 1.0
		band.anchor_top = 0.36
		band.anchor_bottom = 0.56
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(band)
		var edge_top := ColorRect.new()
		edge_top.color = tint
		edge_top.anchor_right = 1.0
		edge_top.anchor_top = 0.36
		edge_top.anchor_bottom = 0.36
		edge_top.offset_bottom = 3
		add_child(edge_top)
		var edge_bottom := ColorRect.new()
		edge_bottom.color = tint
		edge_bottom.anchor_right = 1.0
		edge_bottom.anchor_top = 0.56
		edge_bottom.anchor_bottom = 0.56
		edge_bottom.offset_top = -3
		add_child(edge_bottom)
		var name_label := Label.new()
		name_label.text = title
		name_label.anchor_right = 1.0
		name_label.anchor_top = 0.37
		name_label.anchor_bottom = 0.49
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 40)
		name_label.add_theme_color_override("font_color", tint.lightened(0.25))
		name_label.add_theme_color_override("font_outline_color", Color.BLACK)
		name_label.add_theme_constant_override("outline_size", 8)
		add_child(name_label)
		var sub_label := Label.new()
		sub_label.text = subtitle
		sub_label.anchor_right = 1.0
		sub_label.anchor_top = 0.48
		sub_label.anchor_bottom = 0.55
		sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sub_label.add_theme_font_size_override("font_size", 18)
		sub_label.add_theme_color_override("font_color", Color("#ead9b8"))
		add_child(sub_label)
		modulate.a = 0.0
		position.x = -80.0
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 1.0, 0.25)
		(
			tween
			. parallel()
			. tween_property(self, "position:x", 0.0, 0.3)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
		tween.tween_interval(1.8)
		tween.tween_property(self, "modulate:a", 0.0, 0.45)
		tween.tween_callback(queue_free)


## What's left of a fallen colossus: a split stump filling its cells.
func _build_colossus_remains() -> void:
	if actor_layer.get_node_or_null("ColossusRemains") != null:
		return
	var remains := _make_colossus_remains()
	remains.name = "ColossusRemains"
	remains.position = _world(Vector2i(layout.colossus))
	actor_layer.add_child(remains)


## What a fallen colossus leaves behind; the crypt draws a heap of bones instead.
func _make_colossus_remains() -> Node2D:
	return ColossusRemains.new()


class ColossusRemains:
	extends Node2D

	func _draw() -> void:
		var half := Vector2(ForestRoomLibrary.COLOSSUS_SIZE) * 24.0
		var bark := Color("#4a3322")
		for index in 9:
			var angle := PI * 0.08 + PI * 0.84 * index / 8.0
			var start := Vector2(cos(angle) * half.x * 0.7, half.y * 0.55)
			draw_polyline(
				PackedVector2Array([start, start + Vector2(cos(angle) * 60, 40)]),
				Color("#3d2817"),
				7.0,
				true
			)
		draw_set_transform(Vector2(0, half.y * 0.5), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, half.x, Color(0, 0, 0, 0.28))
		draw_set_transform(Vector2.ZERO)
		var stump := PackedVector2Array(
			[
				Vector2(-half.x * 0.62, half.y * 0.8),
				Vector2(-half.x * 0.55, -half.y * 0.1),
				Vector2(-half.x * 0.3, -half.y * 0.45),
				Vector2(-half.x * 0.1, -half.y * 0.15),
				Vector2(half.x * 0.12, -half.y * 0.5),
				Vector2(half.x * 0.32, -half.y * 0.2),
				Vector2(half.x * 0.55, -half.y * 0.35),
				Vector2(half.x * 0.62, half.y * 0.8)
			]
		)
		draw_colored_polygon(stump, bark.darkened(0.3))
		var inner := PackedVector2Array()
		for p in stump:
			inner.append(p * 0.9)
		draw_colored_polygon(inner, bark)
		draw_circle(Vector2(0, half.y * 0.25), 24, Color("#1d120a"))
		draw_circle(Vector2(0, half.y * 0.25), 10, Color(1.0, 0.6, 0.25, 0.35))
		for index in 5:
			draw_circle(
				Vector2(-half.x * 0.5 + index * half.x * 0.25, half.y * 0.75), 12, Color("#3f6b33")
			)
