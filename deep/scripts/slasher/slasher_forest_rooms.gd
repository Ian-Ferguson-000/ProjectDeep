extends "res://scripts/slasher/slasher_forest.gd"

## Verdant Forest as interconnected rooms, Binding of Isaac style.
##
## Each floor is a graph of painted rooms (maps/forest/rooms/*.tscn) laid out
## by FieldDungeonGenerator. Doors sit on the centre of each room edge, stay
## barred by brambles while foes remain, and open once the room is cleared. The
## gate room holds the root gate down to the next floor, so the existing descent,
## elite and boss cadence, and endless depth all carry on unchanged.
##
## The tutorial expedition, merchant interludes and authored template scenes keep
## using the single generated floor from slasher_forest.gd.

const ROOMS := preload("res://scripts/slasher/forest_room_library.gd")
const ROOM_MINIMAP := preload("res://scripts/slasher/forest_room_minimap.gd")
const DOOR_TRIGGER_RADIUS := 30.0
const THICKET_KINDS := ["tree_wide","tree_small","tree_wide","rounded_bush","tree_small","low_bush_a"]
const TEMPLATE_ROLE := {"start":"start","combat":"combat","elite":"elite","treasure":"treasure","shop":"shop","rest":"rest","boss":"boss"}
const CAMPFIRE_HEIGHT := 64.0
# TUNING: share of maximum health restored by resting once at a campfire.
const REST_HEAL_SHARE := 0.35

var room_id := 0
var room: Dictionary = {}
var room_role := "start"
var door_nodes: Dictionary = {}
var transition_cooldown := 0.0
var treasure_area: Area2D
var campfire_position := Vector2(-99999,-99999)
var rooms_active := false

func uses_room_layout() -> bool:
	if run_state == null or use_authored_layout or run_state.slasher_merchant_interlude or _is_tutorial_expedition(): return false
	return String(Dictionary(GameBalance.get_dungeon(run_state.active_dungeon_id).get("slasher",{})).get("layout","")) == "rooms"

func _build_floor() -> void:
	rooms_active = uses_room_layout()
	if not rooms_active:
		super._build_floor()
		return
	get_tree().paused = false
	secret_door_available = false; secret_door_node = null; merchant_offer_nodes.clear(); has_dungeon_merchant = false; treasure_area = null
	var new_floor := _ensure_floor_graph()
	var snapshot := _snapshot_player()
	if is_instance_valid(player): _store_active_slasher_state()
	for child in get_children(): child.free()
	room_id = int(run_state.field_run.get("current_room",0))
	run_state.enter_field_room(room_id,int(run_state.field_run.get("previous_room",-1)))
	room = run_state.get_field_room(room_id)
	room_role = String(room.get("role","combat"))
	layout = _room_layout()
	pathfinder = GRID_PATHFINDER.new().configure(Dictionary(layout.cells),Array(layout.solid_props),ORIGIN,float(TILE))
	active_summons.clear()
	_build_world(); _spawn_player(); _restore_player(snapshot)
	if new_floor: player.reset_combo_progress()
	_spawn_enemies(); _spawn_loot(); _build_hud(); _refresh_hud(); _entry_fade()
	if new_floor and player.item_runtime: player.item_runtime.floor_entered()
	if new_floor: _show_floor_banner()
	if room_role == "boss" and not bool(room.get("cleared",false)) and (bool(layout.get("is_boss_floor",false)) or bool(layout.get("is_elite_floor",false))): _show_guardian_banner()
	if new_floor and run_state.current_floor == 1 and not run_state.starter_reward_claimed: call_deferred("_offer_starter_relic")
	transition_cooldown = 0.5

## Generates this floor's room graph the first time the floor is entered.
func _ensure_floor_graph() -> bool:
	var floor_key := "%d:%d" % [run_state.get_current_floor_seed(),run_state.current_floor]
	if String(run_state.field_run.get("forest_floor_key","")) == floor_key: return false
	var tuning: Dictionary = Dictionary(Dictionary(GameBalance.get_dungeon(run_state.active_dungeon_id).get("slasher",{})).get("room_count",{}))
	# TUNING: forest.slasher.room_count in dungeons.json sets how sprawling each floor is.
	var growth := mini(int(tuning.get("growth_cap",4)),(run_state.current_floor-1)*int(tuning.get("growth_per_floor",1)))
	var minimum := int(tuning.get("min",7)) + growth
	run_state.field_run = FieldDungeonGenerator.generate(run_state.get_current_floor_seed(),minimum,maxi(minimum,int(tuning.get("max",9))+growth))
	run_state.field_run["forest_floor_key"] = floor_key
	run_state.field_run["layout_kind"] = "forest_rooms"
	run_state.field_run["arrival_direction"] = ""
	_assign_rest_room()
	if MapPlaytest.active():
		var tested := MapPlaytest.template()
		var role := String(Array(tested.get("roles",["combat"]))[0]) if not Array(tested.get("roles",[])).is_empty() else "combat"
		run_state.update_field_room(0,{"role":role,"cleared":ROOMS.PEACEFUL_ROLES.has(role),"template_id":String(tested.get("id",""))})
	return true

## One combat room per floor becomes a campfire clearing: no foes, a place to
## rest. It sits partway along the route, never beside the start or the gate.
func _assign_rest_room() -> void:
	var rooms: Array = run_state.field_run.get("rooms",[])
	var distances := {0:0}
	var open: Array[int] = [0]
	while not open.is_empty():
		var id: int = open.pop_front()
		for neighbor in Dictionary(Dictionary(rooms[id]).neighbors).values():
			if not distances.has(int(neighbor)): distances[int(neighbor)] = int(distances[id]) + 1; open.append(int(neighbor))
	var gate_distance := 0
	for value in rooms:
		if String(value.role) == "boss": gate_distance = int(distances.get(int(value.id),0))
	var best := -1
	var best_score := 999
	for value in rooms:
		if String(value.role) != "combat": continue
		var distance := int(distances.get(int(value.id),0))
		if distance < 2: continue
		var score: int = absi(distance - maxi(2,gate_distance/2))
		if score < best_score: best = int(value.id); best_score = score
	if best >= 0:
		run_state.update_field_room(best,{"role":"rest","cleared":true})

func _room_layout() -> Dictionary:
	var floor_key := String(run_state.field_run.get("forest_floor_key",""))
	var template := ROOMS.template(String(room.get("template_id","")))
	if MapPlaytest.active() and room_id == 0: template = MapPlaytest.template()
	if template.is_empty():
		var pick_role := String(TEMPLATE_ROLE.get(room_role,"combat"))
		# On guardian floors the gate room is a colossus arena, if any exist.
		if room_role == "boss" and run_state.is_slasher_boss_floor() and not ROOMS.templates().filter(func(t): return Array(t.get("roles",[])).has("guardian")).is_empty(): pick_role = "guardian"
		template = ROOMS.pick(pick_role,hash("%s:%d:room" % [floor_key,room_id]),_neighbor_template_ids())
		run_state.update_field_room(room_id,{"template_id":String(template.get("id",""))})
		room["template_id"] = String(template.get("id",""))
	var built := ROOMS.build_layout(template,Dictionary(room.get("neighbors",{})).keys(),hash("%s:%d:decor" % [floor_key,room_id]))
	var state: Dictionary = Dictionary(room.get("slasher",{}))
	var destroyed: Array = Array(state.get("destroyed_props",[]))
	built.solid_props = Array(built.solid_props).filter(func(prop): return not destroyed.has(Vector2i(prop.cell)))
	built["is_boss_floor"] = room_role == "boss" and run_state.is_slasher_boss_floor()
	built["is_elite_floor"] = room_role == "boss" and run_state.is_slasher_elite_floor()
	built["cycle_floor"] = run_state.get_slasher_cycle_floor()
	var arrival := String(run_state.field_run.get("arrival_direction",""))
	if int(run_state.field_run.get("previous_room",-1)) >= 0 and Dictionary(built.doors).has(arrival): built.start = ROOMS.arrival_cell(built,arrival)
	elif MapPlaytest.active() and room_id == 0 and room_role != "start" and not Dictionary(built.doors).is_empty():
		# Playtesting a fight: walk in through a door rather than appearing among the foes.
		built.start = ROOMS.arrival_cell(built,String(Dictionary(built.doors).keys()[0]))
	built.enemy_spawns = [] if bool(room.get("cleared",false)) else _encounter(built)
	return built

func _neighbor_template_ids() -> Array:
	var ids: Array = []
	for neighbor in Dictionary(room.get("neighbors",{})).values():
		var other := run_state.get_field_room(int(neighbor))
		if not String(other.get("template_id","")).is_empty(): ids.append(String(other.template_id))
	return ids

## Which foes hold this room. Plain foes use the forest's normal wolf and beast
## rotation; elite rooms and the gate room add guardians on their cycle floors.
func _encounter(built: Dictionary) -> Array:
	if ROOMS.PEACEFUL_ROLES.has(room_role): return []
	var markers: Array = Array(built.enemy_markers).duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:foes" % [String(run_state.field_run.get("forest_floor_key","")),room_id])
	for index in range(markers.size()-1,0,-1):
		var swap := rng.randi_range(0,index); var held = markers[index]; markers[index] = markers[swap]; markers[swap] = held
	var elite_cell: Vector2i = Array(built.elite_markers)[0] if not Array(built.elite_markers).is_empty() else (markers.pop_back() if not markers.is_empty() else Vector2i(int(built.width)/2,int(built.height)/2))
	# TUNING: plain foes per room grow with depth and stop at the room's markers.
	var count := clampi(2 + int(run_state.current_floor/2.0),2,maxi(2,markers.size()))
	var spawns: Array = []
	if room_role == "boss" and bool(built.is_boss_floor) and Vector2i(built.get("colossus",Vector2i(-100,-100))).x >= 0:
		# The colossus is the whole fight: no adds at the start.
		return [{"position":Vector2i(built.colossus),"visual_id":"heartwood_colossus","behavior_id":"heartwood_colossus","is_boss":true,"is_mini_boss":false}]
	if room_role == "boss" and bool(built.is_boss_floor):
		spawns.append({"position":elite_cell,"visual_id":"dark_druid","behavior_id":"","is_boss":true,"is_mini_boss":false})
		for index in mini(2,markers.size()): spawns.append({"position":markers[index],"visual_id":"briar_guardian","behavior_id":"elite_guardian","is_boss":false,"is_mini_boss":true})
		return spawns
	if room_role == "elite" or (room_role == "boss" and bool(built.is_elite_floor)):
		spawns.append({"position":elite_cell,"visual_id":"briar_guardian","behavior_id":"elite_guardian","is_boss":false,"is_mini_boss":true})
		count = maxi(1,count-1)
	elif not Array(built.elite_markers).is_empty():
		markers.push_front(elite_cell)
	for index in mini(count,markers.size()): spawns.append({"position":markers[index],"visual_id":"","behavior_id":"","is_boss":false,"is_mini_boss":false})
	return spawns

# ---------------------------------------------------------------- world

func _build_world() -> void:
	if not rooms_active:
		super._build_world()
		return
	var profile := DungeonRuntimeProfile.get_profile(run_state.active_dungeon_id)
	var underlay := ColorRect.new(); underlay.name = "DungeonDepth"; underlay.color = Color("#"+String(profile.get("underlay","07100d"))); underlay.position = Vector2.ZERO; underlay.size = Vector2(float(layout.width*TILE+128),float(layout.height*TILE+128)); underlay.mouse_filter = Control.MOUSE_FILTER_IGNORE; underlay.z_index = -20; add_child(underlay)
	ground_layer = Node2D.new(); ground_layer.name = "Ground"; ground_layer.z_index = -10; add_child(ground_layer)
	low_decor_layer = Node2D.new(); low_decor_layer.name = "LowDecor"; low_decor_layer.z_index = -2; add_child(low_decor_layer)
	actor_layer = Node2D.new(); actor_layer.name = "Actors"; actor_layer.y_sort_enabled = true; add_child(actor_layer)
	canopy_layer = Node2D.new(); canopy_layer.name = "Canopy"; canopy_layer.y_sort_enabled = true; canopy_layer.z_index = 8; add_child(canopy_layer)
	_build_room_art()
	# Collision follows the walkable edge; the thicket trees are the visible wall.
	wall_generator = SlasherWallGenerator.new(); wall_generator.name = "WallGenerator"; wall_generator.profile_id = String(profile.get("wall_profile","stone_wall")); wall_generator.tile_size = TILE; wall_generator.render_visuals = false; wall_generator.render_collisions = true; add_child(wall_generator)
	wall_topology = wall_generator.generate(layout.cells,[],ORIGIN)
	_build_thicket(); _build_decorations(); _build_solid_props(); _build_landmarks(); _build_doors(); _build_mist(); _build_vignette()

## The room's painted art (maps/forest/rooms/*.tscn). Rooms without a scene
## fall back to the ground drawn in code from the forest sheet.
func _build_room_art() -> void:
	var template := ROOMS.template(String(layout.get("template_id","")))
	if template.is_empty() and MapPlaytest.active(): template = MapPlaytest.template()
	if String(template.get("scene","")).is_empty():
		FOREST_TERRAIN_ART.build_room_ground(ground_layer,layout,TILE,ORIGIN)
		return
	var art := MapLibrary.art_nodes(template)
	for node in art.ground:
		node.position += ORIGIN
		ground_layer.add_child(node)
	for node in art.canopy:
		node.position += ORIGIN
		node.z_index = 0
		canopy_layer.add_child(node)

func _build_thicket() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:thicket" % [String(run_state.field_run.get("forest_floor_key","")),room_id])
	var cells: Dictionary = layout.cells
	var thicket: Dictionary = layout.thicket_cells
	for value in thicket:
		var cell: Vector2i = value
		# Dark undergrowth makes the boundary read as impassable even between trunks.
		var shade_rect := ColorRect.new(); shade_rect.name = "Undergrowth_%d_%d" % [cell.x,cell.y]; shade_rect.color = Color(0.03,0.09,0.04,0.62); shade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade_rect.position = _world(cell) - Vector2(TILE,TILE) * 0.5; shade_rect.size = Vector2(TILE,TILE); ground_layer.add_child(shade_rect)
		var facing_room := false
		for direction in ROOMS.DIRECTIONS.values():
			if cells.has(cell + Vector2i(direction)): facing_room = true
		var count := 1 if facing_room else 2
		for index in count:
			var kind: String = THICKET_KINDS[rng.randi_range(0,THICKET_KINDS.size()-1)] if facing_room and index == 0 else ("tree_wide" if rng.randf() < 0.6 else "tree_small")
			var tree := SlasherForestArt.make_sprite(kind)
			tree.name = "Thicket_%d_%d_%d" % [cell.x,cell.y,index]
			tree.position = _world(cell) + Vector2(rng.randf_range(-12,12),rng.randf_range(-8,12))
			if rng.randf() < 0.5: tree.flip_h = true
			var shade := rng.randf_range(0.7,0.95) if not facing_room else rng.randf_range(0.82,1.0)
			tree.modulate = Color(shade,shade*1.03,shade,1.0)
			canopy_layer.add_child(tree)

func _build_landmarks() -> void:
	if not rooms_active:
		super._build_landmarks()
		return
	var gate := Vector2i(layout.exit)
	exit_position = _world(gate) if gate.x >= 0 else Vector2(-99999,-99999)
	if gate.x >= 0:
		var exit_root := Node2D.new(); exit_root.name = "RootGate"; exit_root.position = exit_position; exit_root.z_index = 12; exit_root.add_child(_glow(Color("#83d978"),34))
		var exit_sprite := SlasherForestArt.make_sprite("exit"); exit_sprite.position = Vector2(0,-30); exit_root.add_child(exit_sprite); actor_layer.add_child(exit_root)
	if Vector2i(layout.get("colossus",Vector2i(-100,-100))).x >= 0 and (bool(room.get("cleared",false)) or not bool(layout.get("is_boss_floor",false))): _build_colossus_remains()
	var merchant_cell := Vector2i(layout.merchant)
	has_dungeon_merchant = room_role == "shop" and merchant_cell.x >= 0
	merchant_position = _world(merchant_cell) if has_dungeon_merchant else Vector2(-99999,-99999)
	if has_dungeon_merchant:
		var merchant_root := Node2D.new(); merchant_root.name = "CampMerchant"; merchant_root.position = merchant_position; merchant_root.add_child(_glow(Color("#e8b94e"),28))
		var merchant_sprite := SlasherForestArt.make_sprite("merchant"); merchant_sprite.position = Vector2(0,-28); merchant_root.add_child(merchant_sprite); actor_layer.add_child(merchant_root)
	var fire := Vector2i(layout.get("campfire",Vector2i(-100,-100)))
	campfire_position = _world(fire) if fire.x >= 0 else Vector2(-99999,-99999)
	if fire.x >= 0:
		var camp := Node2D.new(); camp.name = "Campfire"; camp.position = campfire_position
		var flames := SlasherForestArt.make_sprite("campfire"); flames.name = "Flames"
		var height := flames.get_rect().size.y
		if height > 0.0: flames.scale = Vector2.ONE * (CAMPFIRE_HEIGHT / height)
		flames.position = Vector2(0,-CAMPFIRE_HEIGHT*0.3); camp.add_child(flames); camp.add_child(_glow(Color("#ff9a3d"),46))
		var blocker := StaticBody2D.new(); var shape := CollisionShape2D.new(); var circle := CircleShape2D.new(); circle.radius = 18; shape.shape = circle; blocker.add_child(shape); camp.add_child(blocker)
		actor_layer.add_child(camp)
		if pathfinder != null: pathfinder.set_cell_blocked(fire,true)
	var pedestal := Vector2i(layout.treasure)
	if room_role == "treasure" and pedestal.x >= 0 and not bool(room.get("reward_claimed",false)):
		treasure_area = Area2D.new(); treasure_area.name = "TreasurePedestal"; treasure_area.position = _world(pedestal)
		var shape := CollisionShape2D.new(); var circle := CircleShape2D.new(); circle.radius = 24; shape.shape = circle; treasure_area.add_child(shape)
		treasure_area.add_child(_glow(Color("#d67ee8"),30))
		var relic := SlasherForestArt.make_sprite("chest_open"); relic.position = Vector2(0,-10); treasure_area.add_child(relic)
		actor_layer.add_child(treasure_area)

## A door is an opening in the thicket on the centre of an edge. While foes remain
## it is barred by brambles; once the room is clear the brambles pull back.
func _build_doors() -> void:
	door_nodes.clear()
	for direction in Dictionary(layout.doors):
		var cell: Vector2i = layout.doors[direction]
		var door := Node2D.new(); door.name = "Door_%s" % direction; door.position = _world(cell); actor_layer.add_child(door)
		var barrier := StaticBody2D.new(); barrier.name = "Brambles"
		var shape := CollisionShape2D.new(); var rect := RectangleShape2D.new(); rect.size = Vector2(TILE,TILE); shape.shape = rect; barrier.add_child(shape)
		for offset in [Vector2(-12,-4),Vector2(12,2),Vector2(0,10)]:
			var bush := SlasherForestArt.make_sprite("rounded_bush" if offset.y < 5 else "low_bush_b"); bush.position = offset; bush.modulate = Color(0.62,0.48,0.42); barrier.add_child(bush)
		door.add_child(barrier)
		var neighbor := run_state.get_field_room(int(Dictionary(room.neighbors).get(direction,-1)))
		var to_gate := String(neighbor.get("role","")) == "boss"
		var guarded := to_gate and not bool(neighbor.get("cleared",false)) and (run_state.is_slasher_boss_floor() or run_state.is_slasher_elite_floor())
		var glow := _glow(Color("#e0503c") if guarded else (Color("#83d978") if to_gate else Color("#9fe39a")),26 if to_gate else 22); glow.name = "OpenGlow"; door.add_child(glow)
		if to_gate:
			var mark := GateDoorMark.new(); mark.name = "GateMark"; mark.guarded = guarded; mark.position = Vector2(0,-6); mark.scale = Vector2.ONE * 1.5; mark.z_index = 9; door.add_child(mark)
		var hint := Label.new(); hint.name = "Hint"; hint.text = _door_hint(neighbor); hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hint.size = Vector2(120,20); hint.position = Vector2(-60,-46 if direction != "north" else 24); hint.add_theme_font_size_override("font_size",12); hint.add_theme_color_override("font_color",Color("#f3e3b4")); hint.add_theme_color_override("font_outline_color",Color(0,0,0,0.85)); hint.add_theme_constant_override("outline_size",4); door.add_child(hint)
		if to_gate:
			hint.position.y = -78 if direction != "north" else 30
			hint.add_theme_color_override("font_color",Color("#ff8a70") if guarded else Color("#b8f0a8"))
			hint.add_theme_color_override("font_outline_color",Color(0,0,0,0.9)); hint.add_theme_constant_override("outline_size",5)
			hint.z_as_relative = false; hint.z_index = 30
		door_nodes[direction] = door
	_set_doors_open(exit_open)

func _door_hint(neighbor: Dictionary) -> String:
	# Like Isaac's boss door, the way to the gate room is recognisable before you go in.
	if String(neighbor.get("role","")) == "boss" and not bool(neighbor.get("cleared",false)):
		if run_state.is_slasher_boss_floor(): return "Guardian"
		if run_state.is_slasher_elite_floor(): return "Elite Guardian"
	if not bool(neighbor.get("visited",false)): return "Root Gate" if String(neighbor.get("role","")) == "boss" else "?"
	match String(neighbor.get("role","")):
		"shop": return "Camp"
		"treasure": return "Treasure" if not bool(neighbor.get("reward_claimed",false)) else ""
		"boss": return "Root Gate"
		"rest": return "Campfire"
	return ""

func _set_doors_open(open: bool) -> void:
	for direction in door_nodes:
		var door: Node2D = door_nodes[direction]
		if not is_instance_valid(door): continue
		var barrier := door.get_node_or_null("Brambles") as StaticBody2D
		if barrier != null:
			barrier.visible = not open
			(barrier.get_child(0) as CollisionShape2D).set_deferred("disabled",open)
		var glow := door.get_node_or_null("OpenGlow") as Node2D
		if glow != null: glow.visible = open
		var hint := door.get_node_or_null("Hint") as Label
		# The gate room's door is always labelled, even while the brambles are up.
		if hint != null: hint.visible = (open or door.get_node_or_null("GateMark") != null) and not hint.text.is_empty()

# ---------------------------------------------------------------- encounters

func _spawn_enemies() -> void:
	super._spawn_enemies()
	if rooms_active:
		if exit_open and not bool(room.get("cleared",false)): _mark_room_cleared(false)
		_set_doors_open(exit_open)

func _reveal_secret_door() -> void:
	if rooms_active: return
	super._reveal_secret_door()

func _on_enemy_defeated(enemy: SlasherEnemy, reward: int) -> void:
	super._on_enemy_defeated(enemy,reward)
	if rooms_active and enemy is SlasherColossus: _build_colossus_remains()
	# The guardian's fall ends the fight, Isaac style: its pack scatters and the gate opens.
	if rooms_active and room_role == "boss" and enemies_remaining > 0 and _is_room_guardian(enemy): _scatter_remaining_foes()
	if rooms_active and enemies_remaining == 0:
		_mark_room_cleared(true)
		_set_doors_open(true)
		_spawn_loot()
		_show_message("Gate open · descend through the roots." if Vector2i(layout.exit).x >= 0 else "Room cleared · the brambles pull back.")

## The foe whose death decides the gate room: the boss on boss floors, the
## elite guardian on elite floors.
func _is_room_guardian(enemy: SlasherEnemy) -> bool:
	if not is_instance_valid(enemy): return false
	if enemy.boss: return true
	return bool(layout.get("is_elite_floor",false)) and enemy.mini_boss and not bool(layout.get("is_boss_floor",false))

func _scatter_remaining_foes() -> void:
	for node in get_tree().get_nodes_in_group("slasher_enemy"):
		var foe := node as SlasherEnemy
		if not is_instance_valid(foe) or foe.dead: continue
		foe.dead = true
		foe.remove_from_group("slasher_enemy"); foe.remove_from_group("slasher_damageable"); foe.remove_from_group("slasher_wolf")
		foe.set_physics_process(false)
		var fade := foe.create_tween(); fade.tween_property(foe,"modulate:a",0.0,0.45); fade.tween_callback(foe.queue_free)
	enemies_remaining = 0
	exit_open = true
	_mark_room_cleared(true)
	_set_doors_open(true)
	_spawn_loot()
	AudioCue.play_from(self,"reward",false)
	_show_message("The guardian falls · its pack scatters and the Root Gate opens.",3.0)
	_refresh_hud()

func _mark_room_cleared(fought: bool) -> void:
	room["cleared"] = true
	run_state.update_field_room(room_id,{"cleared":true})
	if fought:
		# TUNING: a small purse for every room fought through, on top of enemy rewards.
		var amount := run_state.apply_reward_bonus(int(Dictionary(Dictionary(GameBalance.get_dungeon(run_state.active_dungeon_id).get("slasher",{})).get("room_count",{})).get("room_clear_gold",3)),"gold")
		run_state.gold += amount

## Loot caches appear once a room is safe and stay collected when you come back.
func _spawn_loot() -> void:
	if not rooms_active:
		super._spawn_loot()
		return
	for loot in loot_nodes:
		if is_instance_valid(loot): loot.queue_free()
	loot_nodes.clear()
	if not exit_open: return
	var taken: Array = Array(Dictionary(room.get("slasher",{})).get("loot_taken",[]))
	var kinds := ["gold","potion","key"] if RunState.potions_drop() else ["gold","gold","key"]
	for index in Array(layout.loot_spawns).size():
		var cell: Vector2i = layout.loot_spawns[index]
		if taken.has(cell): continue
		var area := Area2D.new(); area.name = "ForestCache"; area.position = _world(cell)
		var shape := CollisionShape2D.new(); var circle := CircleShape2D.new(); circle.radius = 14; shape.shape = circle; area.add_child(shape)
		var kind := String(kinds[(room_id + index) % kinds.size()])
		var sprite := SlasherForestArt.make_sprite(kind); sprite.position = Vector2(0,-8); area.add_child(sprite); area.add_child(_glow(Color("#f3d366"),18))
		area.set_meta("kind",kind); area.set_meta("room_cell",cell)
		actor_layer.add_child(area); loot_nodes.append(area)

func _collect_loot(loot: Area2D) -> void:
	if rooms_active and loot.has_meta("room_cell"): _remember("loot_taken",Vector2i(loot.get_meta("room_cell")))
	super._collect_loot(loot)

func _on_prop_broken(prop: SlasherBreakableProp, kind: String, cell: Vector2i) -> void:
	super._on_prop_broken(prop,kind,cell)
	if rooms_active: _remember("destroyed_props",cell)
	if rooms_active and kind == "tree_large" and cell == _hollow_cell():
		_spawn_hidden_chest(cell)
		AudioCue.play_from(self,"reward",false)
		_show_message("Something glints inside the hollow trunk…",3.0)

func _on_chest_opened(chest: SlasherBreakableProp, cell: Vector2i) -> void:
	if not rooms_active:
		super._on_chest_opened(chest,cell)
		return
	if pathfinder != null: pathfinder.set_cell_blocked(cell,false)
	_remember("destroyed_props",cell)
	relic_choice_source = "chest"
	var cycle: int = maxi(0,run_state.get_slasher_cycle_number()-1) if run_state.slasher_endless_mode else 0
	relic_modal.open(run_state,run_state.generate_slasher_chest_choices(run_state.current_floor,"room_%d_chest_%d_%d" % [room_id,cell.x,cell.y],cycle),true)

# ---------------------------------------------------------------- hollow trees

## Rooms with breakable trees may hide a chest inside one of them, a shade
## darker than the rest. Decided once per room per floor and remembered.
## TUNING: breakable_props.tree_large.hollow_chance in slasher_balance.json.
func _build_solid_props() -> void:
	super._build_solid_props()
	if not rooms_active: return
	var hollow := _hollow_cell()
	if hollow.x < 0: return
	var standing := false
	for node in actor_layer.get_children():
		if node is SlasherBreakableProp and node.prop_kind == "tree_large" and node.cell == hollow:
			standing = true
			node.set_meta("hollow",true)
			node.modulate = Color(0.66,0.6,0.58)
	if not standing and not bool(Dictionary(room.get("slasher",{})).get("hollow_opened",false)): _spawn_hidden_chest(hollow)

func _hollow_cell() -> Vector2i:
	var state: Dictionary = Dictionary(room.get("slasher",{}))
	if not state.has("hollow_tree"):
		var cell := Vector2i(-1,-1)
		var trees: Array = Array(layout.solid_props).filter(func(prop): return String(prop.kind) == "tree_large")
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s:%d:hollow" % [String(run_state.field_run.get("forest_floor_key","")),room_id])
		var chance := float(Dictionary(GameBalance.get_slasher_balance("breakable_props").get("tree_large",{})).get("hollow_chance",0.4))
		if not trees.is_empty() and rng.randf() < chance: cell = Vector2i(trees[rng.randi_range(0,trees.size() - 1)].cell)
		state["hollow_tree"] = cell
		room["slasher"] = state
		run_state.update_field_room(room_id,{"slasher":state})
	return Vector2i(state.hollow_tree)

## A chest that needs no key: finding it is the reward.
func _spawn_hidden_chest(cell: Vector2i) -> void:
	var chest: SlasherBreakableProp = BREAKABLE_PROP.new(); chest.name = "HiddenChest"
	chest.setup("chest",cell); chest.position = _world(cell)
	chest.set_meta("no_key",true)
	chest.opened.connect(func(_chest, at):
		var state: Dictionary = Dictionary(room.get("slasher",{})); state["hollow_opened"] = true; room["slasher"] = state
		run_state.update_field_room(room_id,{"slasher":state}))
	chest.opened.connect(_on_chest_opened)
	actor_layer.add_child(chest)
	chest.add_child(_glow(Color("#f3d366"),20))
	if pathfinder != null: pathfinder.set_cell_blocked(cell,true)

func _remember(key: String, cell: Vector2i) -> void:
	var state: Dictionary = Dictionary(room.get("slasher",{}))
	var list: Array = Array(state.get(key,[]))
	if not list.has(cell): list.append(cell)
	state[key] = list; room["slasher"] = state
	run_state.update_field_room(room_id,{"slasher":state})

func _should_have_secret_door() -> bool:
	return false if rooms_active else super._should_have_secret_door()

# ---------------------------------------------------------------- moving between rooms

func _process(delta: float) -> void:
	super._process(delta)
	if not rooms_active or not is_instance_valid(player): return
	transition_cooldown = maxf(0.0,transition_cooldown-delta)
	if player.input_locked or (relic_modal != null and relic_modal.visible): return
	if treasure_area != null and is_instance_valid(treasure_area) and player.global_position.distance_to(treasure_area.global_position) < 40: _open_treasure()
	if room_role == "rest" and player.global_position.distance_to(campfire_position) < 70: _offer_rest()
	_check_doors()

func _check_doors() -> void:
	if transition_cooldown > 0.0 or not exit_open: return
	for direction in door_nodes:
		var door: Node2D = door_nodes[direction]
		if not is_instance_valid(door) or player.global_position.distance_to(door.global_position) > DOOR_TRIGGER_RADIUS: continue
		var neighbor := int(Dictionary(room.neighbors).get(direction,-1))
		if neighbor < 0: continue
		AudioCue.play_at_from(self,"door_open",player.global_position)
		transition_cooldown = 1.0
		run_state.field_run["arrival_direction"] = ROOMS.OPPOSITE[direction]
		run_state.enter_field_room(neighbor,room_id)
		call_deferred("_build_floor")
		return

func _offer_rest() -> void:
	if bool(room.get("rested",false)):
		_show_message("The fire has burned low. You have already rested here.",0.15)
		return
	var amount := maxi(1,int(round(player.max_health * REST_HEAL_SHARE)))
	_show_message("Rest by the fire · press E to recover %d health." % amount,0.15)
	if not Input.is_action_just_pressed("interact"): return
	player.basic_mouse_held = false
	rest_at_campfire()

## Rest once per campfire, restoring part of the active hero's health.
func rest_at_campfire() -> bool:
	if room_role != "rest" or bool(room.get("rested",false)): return false
	player.heal(maxi(1,int(round(player.max_health * REST_HEAL_SHARE))))
	room["rested"] = true
	run_state.update_field_room(room_id,{"rested":true})
	AudioCue.play_from(self,"reward",false)
	_store_active_slasher_state(); _refresh_hud()
	_show_message("%s rests by the fire and recovers." % run_state.get_active_character().display_name if run_state.get_active_character() != null else "You rest by the fire and recover.")
	return true

func _open_treasure() -> void:
	if relic_modal == null or relic_modal.visible: return
	AudioCue.play_at_from(self,"chest_open",treasure_area.global_position)
	treasure_area.queue_free(); treasure_area = null
	room["reward_claimed"] = true
	run_state.update_field_room(room_id,{"reward_claimed":true})
	relic_choice_source = "chest"
	var cycle: int = maxi(0,run_state.get_slasher_cycle_number()-1) if run_state.slasher_endless_mode else 0
	relic_modal.open(run_state,run_state.generate_slasher_chest_choices(run_state.current_floor,"room_%d_treasure" % room_id,cycle),true)

## The base scene connects to settings once per player spawn; rooms respawn the
## player on every transition, so drop the previous connection first.
func _spawn_player() -> void:
	var settings := _settings()
	if settings != null and settings.settings_changed.is_connected(_on_game_setting_changed): settings.settings_changed.disconnect(_on_game_setting_changed)
	super._spawn_player()

func _snapshot_player() -> Dictionary:
	if not is_instance_valid(player): return {}
	return {"cooldowns":player.cooldowns.duplicate(),"invulnerable":player.invulnerable,"defense_window":player.defense_window,"defense_kind":player.defense_kind,"consumable_speed_time":player.consumable_speed_time,"consumable_speed_multiplier":player.consumable_speed_multiplier}

func _restore_player(snapshot: Dictionary) -> void:
	if snapshot.is_empty(): return
	player.cooldowns = Dictionary(snapshot.get("cooldowns",player.cooldowns)); player.invulnerable = float(snapshot.get("invulnerable",0)); player.defense_window = float(snapshot.get("defense_window",0)); player.defense_kind = String(snapshot.get("defense_kind","")); player.consumable_speed_time = float(snapshot.get("consumable_speed_time",0)); player.consumable_speed_multiplier = float(snapshot.get("consumable_speed_multiplier",1))

# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	super._build_hud()
	if not rooms_active: return
	var map := ROOM_MINIMAP.new(); map.name = "ForestRoomMap"
	map.set_anchors_preset(Control.PRESET_TOP_RIGHT); map.offset_left = -200; map.offset_right = -22; map.offset_top = 20; map.offset_bottom = 140
	map.setup(run_state); get_node("HUD").add_child(map)

func _refresh_hud() -> void:
	super._refresh_hud()
	if not rooms_active or objective_label == null or not is_instance_valid(player): return
	var depth_text: String = "ENDLESS · FLOOR %d" % run_state.current_floor if run_state.slasher_endless_mode else "FLOOR %d" % run_state.current_floor
	var status := "%d FOES" % enemies_remaining if not exit_open else ("GATE OPEN" if Vector2i(layout.exit).x >= 0 else "CLEAR")
	if bool(layout.get("is_boss_floor",false)) and not exit_open: status = "BOSS"
	elif bool(layout.get("is_elite_floor",false)) and not exit_open: status = "ELITE GUARDIAN"
	objective_label.text = "VERDANT FOREST  ·  %s  ·  %s  ·  %s" % [depth_text,String(layout.room_name).to_upper(),status]
	var map := get_node_or_null("HUD/ForestRoomMap")
	if map: map.queue_redraw()


# ---------------------------------------------------------------- guardian warnings

## Isaac-style intro when you walk into the guardian's room.
func _show_guardian_banner() -> void:
	var hud := get_node_or_null("HUD")
	if hud == null: return
	var boss := bool(layout.get("is_boss_floor",false))
	var boss_id := "dark_druid"
	for node in actor_layer.get_children():
		if node is SlasherEnemy and node.boss: boss_id = String(node.visual_id)
	var title := String(GameBalance.get_slasher_journal_entry(boss_id).get("name","The Guardian")) if boss else "Elite Guardian"
	var banner := GuardianBanner.new(); banner.name = "GuardianBanner"
	banner.setup(title.to_upper(),"Guardian of the %s" % String(GameBalance.get_dungeon(run_state.active_dungeon_id).get("name","Forest")) if boss else "The Root Gate is held",Color("#e0503c") if boss else Color("#ff9e3d"))
	hud.add_child(banner)
	AudioCue.play_from(self,"combo",false)

## A horned skull over the door to a guarded gate room; a plain gate glyph otherwise.
class GateDoorMark extends Node2D:
	var guarded := false
	var _time := 0.0
	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()
	func _draw() -> void:
		var pulse := 0.75 + 0.25 * sin(_time * 4.0)
		if not guarded:
			draw_arc(Vector2(0,-8),9.0,PI,TAU,12,Color(0.55,0.9,0.5,0.9),3.0)
			draw_line(Vector2(-9,-8),Vector2(-9,2),Color(0.55,0.9,0.5,0.9),3.0); draw_line(Vector2(9,-8),Vector2(9,2),Color(0.55,0.9,0.5,0.9),3.0)
			return
		var bone := Color(0.95,0.9,0.82,pulse)
		var dark := Color(0.12,0.04,0.04,1.0)
		var top := Vector2(0,-6)
		draw_colored_polygon(PackedVector2Array([top + Vector2(-10,-4),top + Vector2(-20,-16),top + Vector2(-14,-2)]),Color(0.7,0.18,0.12,pulse))
		draw_colored_polygon(PackedVector2Array([top + Vector2(10,-4),top + Vector2(20,-16),top + Vector2(14,-2)]),Color(0.7,0.18,0.12,pulse))
		draw_circle(top,11.0,dark); draw_circle(top,10.0,bone)
		draw_rect(Rect2(top + Vector2(-6,6),Vector2(12,6)),bone)
		draw_circle(top + Vector2(-4,0),3.2,dark); draw_circle(top + Vector2(4,0),3.2,dark)
		draw_line(top + Vector2(-2,9),top + Vector2(-2,12),dark,1.0); draw_line(top + Vector2(2,9),top + Vector2(2,12),dark,1.0)

## A band across the screen naming the guardian, sliding in then fading out.
class GuardianBanner extends Control:
	var title := ""
	var subtitle := ""
	var tint := Color.RED
	func setup(title_text: String, subtitle_text: String, colour: Color) -> void:
		title = title_text; subtitle = subtitle_text; tint = colour
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var band := ColorRect.new(); band.color = Color(0.03,0.02,0.02,0.82); band.anchor_left = 0.0; band.anchor_right = 1.0; band.anchor_top = 0.36; band.anchor_bottom = 0.56; band.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(band)
		var edge_top := ColorRect.new(); edge_top.color = tint; edge_top.anchor_right = 1.0; edge_top.anchor_top = 0.36; edge_top.anchor_bottom = 0.36; edge_top.offset_bottom = 3; add_child(edge_top)
		var edge_bottom := ColorRect.new(); edge_bottom.color = tint; edge_bottom.anchor_right = 1.0; edge_bottom.anchor_top = 0.56; edge_bottom.anchor_bottom = 0.56; edge_bottom.offset_top = -3; add_child(edge_bottom)
		var name_label := Label.new(); name_label.text = title; name_label.anchor_right = 1.0; name_label.anchor_top = 0.37; name_label.anchor_bottom = 0.49; name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size",40); name_label.add_theme_color_override("font_color",tint.lightened(0.25)); name_label.add_theme_color_override("font_outline_color",Color.BLACK); name_label.add_theme_constant_override("outline_size",8); add_child(name_label)
		var sub_label := Label.new(); sub_label.text = subtitle; sub_label.anchor_right = 1.0; sub_label.anchor_top = 0.48; sub_label.anchor_bottom = 0.55; sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; sub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sub_label.add_theme_font_size_override("font_size",18); sub_label.add_theme_color_override("font_color",Color("#ead9b8")); add_child(sub_label)
		modulate.a = 0.0; position.x = -80.0
		var tween := create_tween()
		tween.tween_property(self,"modulate:a",1.0,0.25); tween.parallel().tween_property(self,"position:x",0.0,0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_interval(1.8)
		tween.tween_property(self,"modulate:a",0.0,0.45)
		tween.tween_callback(queue_free)


## What's left of a fallen colossus: a split stump filling its cells.
func _build_colossus_remains() -> void:
	if actor_layer.get_node_or_null("ColossusRemains") != null: return
	var remains := ColossusRemains.new(); remains.name = "ColossusRemains"
	remains.position = _world(Vector2i(layout.colossus))
	actor_layer.add_child(remains)

class ColossusRemains extends Node2D:
	func _draw() -> void:
		var half := Vector2(ForestRoomLibrary.COLOSSUS_SIZE) * 24.0
		var bark := Color("#4a3322")
		for index in 9:
			var angle := PI * 0.08 + PI * 0.84 * index / 8.0
			var start := Vector2(cos(angle) * half.x * 0.7,half.y * 0.55)
			draw_polyline(PackedVector2Array([start,start + Vector2(cos(angle) * 60,40)]),Color("#3d2817"),7.0,true)
		draw_set_transform(Vector2(0,half.y * 0.5),0.0,Vector2(1.0,0.4)); draw_circle(Vector2.ZERO,half.x,Color(0,0,0,0.28)); draw_set_transform(Vector2.ZERO)
		var stump := PackedVector2Array([Vector2(-half.x * 0.62,half.y * 0.8),Vector2(-half.x * 0.55,-half.y * 0.1),Vector2(-half.x * 0.3,-half.y * 0.45),Vector2(-half.x * 0.1,-half.y * 0.15),Vector2(half.x * 0.12,-half.y * 0.5),Vector2(half.x * 0.32,-half.y * 0.2),Vector2(half.x * 0.55,-half.y * 0.35),Vector2(half.x * 0.62,half.y * 0.8)])
		draw_colored_polygon(stump,bark.darkened(0.3))
		var inner := PackedVector2Array()
		for p in stump: inner.append(p * 0.9)
		draw_colored_polygon(inner,bark)
		draw_circle(Vector2(0,half.y * 0.25),24,Color("#1d120a"))
		draw_circle(Vector2(0,half.y * 0.25),10,Color(1.0,0.6,0.25,0.35))
		for index in 5:
			draw_circle(Vector2(-half.x * 0.5 + index * half.x * 0.25,half.y * 0.75),12,Color("#3f6b33"))
