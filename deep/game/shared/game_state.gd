extends Node
enum GameMode { STORY, DEV }
signal inventory_changed
signal runes_changed
signal objective_changed(text: String)
signal corruption_cleansed
signal game_mode_changed(mode: GameMode)
signal journal_changed(enemy_id: String, count: int)
signal soul_grid_changed(size:int,segments:Dictionary,placements:Dictionary)
signal active_grid_runes_changed(rune_ids:Array[String])
var game_mode := GameMode.STORY
var inventory := {"sun_shard": 0, "moon_moss": 0}
var discovered_runes: Array[String] = []
var equipped_runes:Array[String]=["","","",""]
var selected_spell_slot:=0
var equipped_rune:String:
	get:return selected_rune_id()
	set(value):
		if value.is_empty():equipped_runes[selected_spell_slot]="";runes_changed.emit()
		else:equip_rune(value,selected_spell_slot)
var objective_stage := 0
var spawn_id := "south_spawn"
var enemy_defeats: Dictionary = {}
var soul_grid_size:=7
var soul_grid_segments:Dictionary={}
var soul_grid_placements:Dictionary={}
var active_grid_runes:Array[String]=[]

## Fully resets mutable run state. Story gets zero resources/no runes; Dev derives all recipe resource keys,
## fixes them at 999, unlocks every rune, and equips Cleansing Spark. Always use this entry point when
## starting a mode.
func start_new_game(mode: GameMode) -> void:
	game_mode = mode
	inventory.clear()
	var all_runes := StarterRunes.all()
	for rune in all_runes:
		for resource_id in rune.get("costs", {}): inventory[resource_id] = 999 if is_dev_mode() else 0
	discovered_runes.clear()
	soul_grid_segments.clear();soul_grid_placements.clear();active_grid_runes.clear();soul_grid_size=12 if is_dev_mode() else 7
	objective_stage = 0
	if is_dev_mode():
		for rune in all_runes: discovered_runes.append(str(rune.id))
		equipped_runes=["","","",""]
		_seed_dev_soul_grid(["cleansing_spark","fireball","flamethrower","flame_shower"])
		_scan_soul_grid()
		equipped_runes=["cleansing_spark","fireball","flamethrower","flame_shower"]
	else: equipped_runes=["","","",""]
	selected_spell_slot=0
	spawn_id = "south_spawn"
	enemy_defeats.clear()
	game_mode_changed.emit(game_mode)
	inventory_changed.emit(); runes_changed.emit(); objective_changed.emit(objective_text())
	soul_grid_changed.emit(soul_grid_size,soul_grid_segments.duplicate(true),soul_grid_placements.duplicate(true));active_grid_runes_changed.emit(active_grid_runes.duplicate())
	for entry in EnemyJournal.all(): journal_changed.emit(entry.enemy_id,0)

## Returns whether the active enum is Dev without exposing enum-number comparisons to callers.
func is_dev_mode() -> bool:
	return game_mode == GameMode.DEV

## Adds inventory in Story or pins the item to 999 in Dev, advances the material objective when appropriate,
## and emits inventory/objective signals.
func add_item(item_id: String, amount := 1) -> void:
	inventory[item_id] = 999 if is_dev_mode() else inventory.get(item_id, 0) + amount
	if objective_stage < 2 and inventory["sun_shard"] > 0 and inventory["moon_moss"] > 0: objective_stage = 2
	inventory_changed.emit(); objective_changed.emit(objective_text())

## Returns true unconditionally in Dev; otherwise verifies every cost against inventory without mutation.
func can_craft(costs: Dictionary) -> bool:
	if is_dev_mode(): return true
	for item_id in costs:
		if inventory.get(item_id, 0) < int(costs[item_id]): return false
	return true

## Idempotently crafts a rune, consumes costs only in Story, advances progression, and emits
## inventory/rune/objective signals. It does not equip automatically.
func craft_rune(rune: Dictionary) -> bool:
	var id := str(rune.get("id", ""))
	if id in discovered_runes: return true
	var costs: Dictionary = rune.get("costs", {})
	if not can_craft(costs): return false
	if not is_dev_mode():
		for item_id in costs: inventory[item_id] -= int(costs[item_id])
	discovered_runes.append(id); objective_stage = max(objective_stage, 3)
	_scan_soul_grid()
	inventory_changed.emit(); runes_changed.emit(); objective_changed.emit(objective_text())
	return true

## Equips a discovered rune into an explicit or currently selected hotbar slot and reports success.
func equip_rune(id: String, slot: int=-1) -> bool:
	if id not in discovered_runes or id not in active_grid_runes:return false
	var target_slot:=selected_spell_slot if slot<0 else clampi(slot,0,3)
	equipped_runes[target_slot]=id
	runes_changed.emit()
	return true

## Selects one of the four combat hotbar slots and broadcasts the equipment presentation change.
func select_spell_slot(slot:int) -> void:
	selected_spell_slot=clampi(slot,0,3);runes_changed.emit()

## Returns the stable ID in the selected hotbar slot or an empty string when that slot is vacant.
func selected_rune_id() -> String:return equipped_runes[selected_spell_slot]

## Returns the selected rune record defensively for combat and HUD consumers.
func selected_rune() -> Dictionary:return RuneLibrary.get_rune(selected_rune_id())

## Adds one canonical undirected neighboring segment, rescans every embedded rune, and reports mutation success.
func add_soul_segment(a:Vector2i,b:Vector2i) -> bool:
	if not _valid_soul_node(a) or not _valid_soul_node(b) or RuneLibrary.direction(a,b)<0:return false
	var key:=soul_segment_key(a,b)
	if soul_grid_segments.has(key):return false
	soul_grid_segments[key]=[a,b];_scan_soul_grid();return true

## Removes one existing canonical segment, rescans patterns, and reports whether anything changed.
func remove_soul_segment(a:Vector2i,b:Vector2i) -> bool:
	var key:=soul_segment_key(a,b)
	if not soul_grid_segments.has(key):return false
	soul_grid_segments.erase(key);_scan_soul_grid();return true

## Clears the complete persistent network and immediately invalidates grid-dependent hotbar entries.
func clear_soul_grid() -> void:soul_grid_segments.clear();_scan_soul_grid()

## Returns whether Story progression may append another row and column before the 12×12 cap.
func can_expand_soul_grid() -> bool:return soul_grid_size<12

## Expands the grid by one while preserving all existing coordinates and segments.
func expand_soul_grid() -> bool:
	if not can_expand_soul_grid():return false
	soul_grid_size+=1;_scan_soul_grid();return true

## Sets a clamped initialization/debug size and removes only segments that no longer fit the requested bounds.
func set_soul_grid_size(value:int) -> void:
	soul_grid_size=clampi(value,7,12)
	for key in soul_grid_segments.keys():
		var edge:Array=soul_grid_segments[key]
		if not _valid_soul_node(edge[0]) or not _valid_soul_node(edge[1]):soul_grid_segments.erase(key)
	_scan_soul_grid()

## Returns every detected placement for one stable rune ID as arrays of lattice coordinates.
func soul_placements_for(rune_id:String) -> Array:return soul_grid_placements.get(rune_id,[]).duplicate(true)

## Reports whether a crafted rune currently has at least one complete pattern embedded in the network.
func is_rune_active_in_grid(rune_id:String) -> bool:return rune_id in active_grid_runes

## Produces a stable order-independent key for one undirected segment endpoint pair.
func soul_segment_key(a:Vector2i,b:Vector2i) -> String:
	var first:=a;var second:=b
	if b.y<a.y or (b.y==a.y and b.x<a.x):first=b;second=a
	return "%d,%d|%d,%d"%[first.x,first.y,second.x,second.y]

## Checks one coordinate against the currently unlocked square lattice bounds.
func _valid_soul_node(point:Vector2i) -> bool:return point.x>=0 and point.y>=0 and point.x<soul_grid_size and point.y<soul_grid_size

## Rebuilds all forward/reverse placements, crafted activation, objectives, and equipment validity after edits.
func _scan_soul_grid() -> void:
	var previous_active:=active_grid_runes.duplicate();soul_grid_placements.clear()
	for rune in StarterRunes.all():
		var placements:Array=[];var variants:Array=[Array(rune.path),StarterRunes.reverse_path(Array(rune.path))]
		for y in soul_grid_size:
			for x in soul_grid_size:
				for directions in variants:
					var placement:=_walk_soul_pattern(Vector2i(x,y),directions)
					if not placement.is_empty() and placement not in placements:placements.append(placement)
		if not placements.is_empty():soul_grid_placements[str(rune.id)]=placements
	active_grid_runes.clear()
	for rune_id in soul_grid_placements:
		if rune_id in discovered_runes:active_grid_runes.append(rune_id)
	active_grid_runes.sort();var loadout_changed:=_reconcile_grid_loadout()
	if objective_stage==3 and "cleansing_spark" in active_grid_runes:objective_stage=4;objective_changed.emit(objective_text())
	soul_grid_changed.emit(soul_grid_size,soul_grid_segments.duplicate(true),soul_grid_placements.duplicate(true))
	if previous_active!=active_grid_runes:active_grid_runes_changed.emit(active_grid_runes.duplicate())
	if previous_active!=active_grid_runes or loadout_changed:runes_changed.emit()

## Walks one authored direction sequence from a start node and returns its coordinates only when every edge exists.
func _walk_soul_pattern(start:Vector2i,directions:Array) -> Array:
	var nodes:Array=[start];var point:=start
	for direction in directions:
		var next:=StarterRunes._step(point,int(direction))
		if not _valid_soul_node(next) or not soul_grid_segments.has(soul_segment_key(point,next)):return []
		nodes.append(next);point=next
	return nodes

## Clears every equipped slot whose crafted pattern is absent and reports one consolidated loadout mutation.
func _reconcile_grid_loadout() -> bool:
	var changed:=false
	for slot in equipped_runes.size():
		if not equipped_runes[slot].is_empty() and equipped_runes[slot] not in active_grid_runes:equipped_runes[slot]="";changed=true
	return changed

## Packs requested Dev starter patterns into distinct valid node regions without rotations or overlaps.
func _seed_dev_soul_grid(rune_ids:Array) -> void:
	var occupied:Dictionary={}
	for rune_id in rune_ids:
		var rune:=StarterRunes.get_rune(str(rune_id));var placed:=false
		for y in soul_grid_size:
			for x in soul_grid_size:
				var nodes:=_trace_seed_path(Vector2i(x,y),Array(rune.path))
				if nodes.is_empty() or nodes.any(func(node):return occupied.has(node)):continue
				for index in range(nodes.size()-1):soul_grid_segments[soul_segment_key(nodes[index],nodes[index+1])]=[nodes[index],nodes[index+1]]
				for node in nodes:occupied[node]=true
				placed=true;break
			if placed:break

## Traces a candidate seed placement inside current bounds without requiring its segments to exist yet.
func _trace_seed_path(start:Vector2i,directions:Array) -> Array:
	if not _valid_soul_node(start):return []
	var nodes:Array=[start];var point:=start
	for direction in directions:
		point=StarterRunes._step(point,int(direction))
		if not _valid_soul_node(point) or point in nodes:return []
		nodes.append(point)
	return nodes

## Advances objective 0→1 once and emits updated text.
func mark_tutorial_seen() -> void:
	if objective_stage == 0: objective_stage = 1; objective_changed.emit(objective_text())
## Advances to completion once, emits corruption and objective signals, and never regresses state.
func mark_cleansed() -> void:
	if objective_stage < 5: objective_stage = 5; corruption_cleansed.emit(); objective_changed.emit(objective_text())
## Maps the current stage to user-facing objective copy.
func objective_text() -> String:
	match objective_stage:
		0: return "Speak with Mira in the village clearing."
		1: return "Find Sun Shard (west) and Moon Moss (east)."
		2: return "Open Soul Space [R], draw the rune, then craft it."
		3:return "Arrange Cleansing Spark within the persistent Soul Grid."
		4:return "Cleanse the corruption in the northern glade."
		_: return "The path north is open. Vertical slice complete!"

## Records one legitimate alive-to-dead transition and broadcasts the updated run-local count.
func record_enemy_defeat(enemy_id: String) -> void:
	if enemy_id.is_empty(): return
	enemy_defeats[enemy_id]=int(enemy_defeats.get(enemy_id,0))+1
	journal_changed.emit(enemy_id,enemy_defeats[enemy_id])

## Returns the current run's defeat count for an enemy, defaulting to zero.
func enemy_defeat_count(enemy_id: String) -> int:
	return int(enemy_defeats.get(enemy_id,0))

## Reports journal visibility: Dev reveals all entries, while Story requires at least one defeat.
func is_enemy_discovered(enemy_id: String) -> bool:
	return is_dev_mode() or enemy_defeat_count(enemy_id)>0
