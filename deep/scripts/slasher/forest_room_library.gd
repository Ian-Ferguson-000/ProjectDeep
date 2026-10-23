extends RefCounted
class_name ForestRoomLibrary

## Hand-authored Verdant Forest rooms (data/forest_rooms.json) and the rules that
## turn one into a playable layout.
##
## A room map is a grid of single-character cells (see "legend" in the JSON). Each
## edge has one door slot on its centre cell. When a room is placed in the floor's
## room graph, slots facing a neighbour open and the rest are sealed with thicket.
##
## This is deliberately the seam for future procedural generation: anything that
## can produce the same template dictionary (id, roles, map) can feed
## build_layout(), whether it was drawn by hand or assembled by a generator.

const PATH := "res://data/forest_rooms.json"
const DIRECTIONS := {"north":Vector2i.UP,"east":Vector2i.RIGHT,"south":Vector2i.DOWN,"west":Vector2i.LEFT}
const OPPOSITE := {"north":"south","south":"north","east":"west","west":"east"}
const DOOR_SYMBOLS := {"north":"N","east":"E","south":"S","west":"W"}
const BLOCKING := ["#","~"]
const SOLID_KINDS := {"R":"rock","T":"tree_large","C":"chest"}
const DECORATION_KINDS := {"r":"mossy_rock","p":"pebbles","m":"mushrooms","F":"campfire"}
const BUSH_KINDS := ["low_bush_a","low_bush_b","rounded_bush"]
const KNOWN_SYMBOLS := "#.=c~RTCrpmbFeE$*MXPNSW"
const ROLES := ["start","combat","elite","treasure","shop","boss"]

static var _cache: Dictionary = {}

static func data() -> Dictionary:
	if _cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_cache = Dictionary(parsed) if parsed is Dictionary else {}
	return _cache

static func templates() -> Array:
	return Array(data().get("rooms",[]))

static func template(id: String) -> Dictionary:
	for value in templates():
		if value is Dictionary and String(value.get("id","")) == id: return Dictionary(value)
	return {}

static func templates_for(role: String) -> Array:
	var result: Array = templates().filter(func(value): return value is Dictionary and Array(value.get("roles",[])).has(role))
	return result if not result.is_empty() else templates_for("combat") if role != "combat" else templates()

static func size_of(template_data: Dictionary) -> Vector2i:
	var rows: Array = Array(template_data.get("map",[]))
	return Vector2i(String(rows[0]).length() if not rows.is_empty() else 0, rows.size())

static func door_cells(template_data: Dictionary) -> Dictionary:
	var size := size_of(template_data)
	return {"north":Vector2i(size.x/2,0),"south":Vector2i(size.x/2,size.y-1),"west":Vector2i(0,size.y/2),"east":Vector2i(size.x-1,size.y/2)}

## Deterministic weighted pick, so revisiting a room or reloading a floor gives the
## same map. Avoids repeating the previous room's map where possible.
static func pick(role: String, seed_value: int, avoid_ids: Array = []) -> Dictionary:
	var pool := templates_for(role)
	var fresh: Array = pool.filter(func(value): return not avoid_ids.has(String(Dictionary(value).get("id",""))))
	if not fresh.is_empty(): pool = fresh
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var total := 0.0
	for value in pool: total += float(Dictionary(value).get("weight",1.0))
	var roll := rng.randf() * total
	for value in pool:
		roll -= float(Dictionary(value).get("weight",1.0))
		if roll <= 0.0: return Dictionary(value)
	return Dictionary(pool.back())

## Converts a template into the layout dictionary the forest renderer and slasher
## runtime already understand, plus room-specific keys (doors, markers, terrain).
static func build_layout(template_data: Dictionary, open_doors: Array, seed_value: int = 0) -> Dictionary:
	var rows: Array = Array(template_data.get("map",[]))
	var size := size_of(template_data)
	var slots := door_cells(template_data)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cells := {}; var path_cells := {}; var cobble_cells := {}; var water_cells := {}; var thicket_cells := {}
	var solid_props: Array[Dictionary] = []; var decorations: Array[Dictionary] = []
	var enemy_markers: Array[Vector2i] = []; var elite_markers: Array[Vector2i] = []; var loot_spawns: Array[Vector2i] = []
	var markers := {}
	var doors := {}
	for direction in slots:
		if open_doors.has(direction): doors[direction] = slots[direction]
	for y in size.y:
		var row := String(rows[y])
		for x in size.x:
			var cell := Vector2i(x,y)
			var symbol := row[x]
			var slot_direction := _slot_direction(slots,cell)
			if not slot_direction.is_empty():
				if doors.has(slot_direction):
					cells[cell] = true
					path_cells[cell] = true
				else:
					thicket_cells[cell] = true
				continue
			match symbol:
				"#": thicket_cells[cell] = true
				"~": water_cells[cell] = true
				_:
					cells[cell] = true
					match symbol:
						"=": path_cells[cell] = true
						"c": cobble_cells[cell] = true
						"R","T","C": solid_props.append({"kind":SOLID_KINDS[symbol],"cell":cell})
						"r","p","m","F": decorations.append({"kind":DECORATION_KINDS[symbol],"cell":cell,"offset":Vector2(rng.randf_range(-6,6),rng.randf_range(-4,6)),"edge":false})
						"b": decorations.append({"kind":String(BUSH_KINDS[rng.randi_range(0,BUSH_KINDS.size()-1)]),"cell":cell,"offset":Vector2(rng.randf_range(-6,6),rng.randf_range(-4,4)),"edge":false})
						"e": enemy_markers.append(cell)
						"E": elite_markers.append(cell)
						"$": loot_spawns.append(cell)
						"*": markers["treasure"] = cell
						"M": markers["merchant"] = cell
						"X": markers["gate"] = cell
						"P": markers["start"] = cell
					# Markers dropped onto a trail keep the trail continuous underneath them.
					if "$MPX*eE".contains(symbol) and _touches_count(rows,cell,"=") >= 2: path_cells[cell] = true
	var center := Vector2i(size.x/2,size.y/2)
	return {
		"template_id":String(template_data.get("id","")),
		"room_name":String(template_data.get("name","Forest")),
		"width":size.x,"height":size.y,
		"cells":cells,"rooms":[Rect2i(1,1,size.x-2,size.y-2)],
		"path_cells":path_cells,"cobble_cells":cobble_cells,"water_cells":water_cells,"thicket_cells":thicket_cells,
		"solid_props":solid_props,"decorations":decorations,
		"enemy_markers":enemy_markers,"elite_markers":elite_markers,"loot_spawns":loot_spawns,
		"enemy_spawns":[],
		"doors":doors,"door_slots":slots,
		"start":Vector2i(markers.get("start",center)),
		"exit":Vector2i(markers.get("gate",Vector2i(-100,-100))),
		"merchant":Vector2i(markers.get("merchant",Vector2i(-100,-100))),
		"treasure":Vector2i(markers.get("treasure",Vector2i(-100,-100))),
		"edges":SlasherForestGenerator.classify_edges(cells),
	}

## The cell just inside a door, where a party arriving through it appears.
static func arrival_cell(layout: Dictionary, direction: String) -> Vector2i:
	var slot: Vector2i = Dictionary(layout.get("door_slots",{})).get(direction,Vector2i(int(layout.width)/2,int(layout.height)/2))
	var inward: Vector2i = -Vector2i(DIRECTIONS[direction])
	var cell := slot + inward
	var cells: Dictionary = layout.cells
	var blocked := {}
	for prop in layout.solid_props: blocked[Vector2i(prop.cell)] = true
	for step in range(1,4):
		var candidate := slot + inward * step
		if cells.has(candidate) and not blocked.has(candidate): return candidate
	return cell

static func _touches_count(rows: Array, cell: Vector2i, symbol: String) -> int:
	var count := 0
	for direction in DIRECTIONS.values():
		var other: Vector2i = cell + Vector2i(direction)
		if other.y < 0 or other.y >= rows.size(): continue
		var row := String(rows[other.y])
		if other.x >= 0 and other.x < row.length() and (row[other.x] == symbol or "NSEW".contains(row[other.x])): count += 1
	return count

static func _slot_direction(slots: Dictionary, cell: Vector2i) -> String:
	for direction in slots:
		if slots[direction] == cell: return String(direction)
	return ""

static func _touches(rows: Array, cell: Vector2i, symbol: String) -> bool:
	for direction in DIRECTIONS.values():
		var other: Vector2i = cell + Vector2i(direction)
		if other.y < 0 or other.y >= rows.size(): continue
		var row := String(rows[other.y])
		if other.x >= 0 and other.x < row.length() and row[other.x] == symbol: return true
	return false

## Authoring checks. Every room must be well formed, and every door slot must
## reach every other door and every marker without crossing water, thicket, or
## solid props, so any combination of open doors is traversable.
static func validate() -> Array[String]:
	var errors: Array[String] = []
	var ids := {}
	var role_coverage := {}
	for value in templates():
		if not value is Dictionary: errors.append("Forest room entry is not an object."); continue
		var entry: Dictionary = value
		var id := String(entry.get("id",""))
		if id.is_empty() or ids.has(id): errors.append("Missing or duplicate forest room id: %s" % id)
		ids[id] = true
		for role in Array(entry.get("roles",[])):
			if not ROLES.has(String(role)): errors.append("%s has unknown role %s." % [id,role])
			role_coverage[String(role)] = true
		var rows: Array = Array(entry.get("map",[]))
		var size := size_of(entry)
		if size.x < 7 or size.y < 7 or size.x % 2 == 0 or size.y % 2 == 0: errors.append("%s must be at least 7x7 with odd dimensions." % id); continue
		var ragged := false
		for row in rows:
			if String(row).length() != size.x: ragged = true
		if ragged: errors.append("%s has rows of different lengths." % id); continue
		var slots := door_cells(entry)
		for direction in slots:
			var slot: Vector2i = slots[direction]
			if String(rows[slot.y])[slot.x] != DOOR_SYMBOLS[direction]: errors.append("%s is missing its %s door slot." % [id,direction])
		var markers: Array[Vector2i] = []
		for y in size.y:
			for x in size.x:
				var symbol := String(rows[y])[x]
				var cell := Vector2i(x,y)
				if not KNOWN_SYMBOLS.contains(symbol): errors.append("%s uses unknown symbol '%s' at %d,%d." % [id,symbol,x,y])
				var on_edge := x == 0 or y == 0 or x == size.x-1 or y == size.y-1
				if on_edge and not slots.values().has(cell) and symbol != "#": errors.append("%s border cell %d,%d must be thicket." % [id,x,y])
				if not on_edge and "eE$*MXP".contains(symbol): markers.append(cell)
		var layout := build_layout(entry,DIRECTIONS.keys())
		var blocked := {}
		for prop in layout.solid_props: blocked[Vector2i(prop.cell)] = true
		var reach := _reachable(layout.cells,blocked,slots.north)
		for direction in slots:
			if not reach.has(slots[direction]): errors.append("%s: the %s door cannot be reached from the north door." % [id,direction])
		for marker in markers:
			if not reach.has(marker): errors.append("%s: marker at %d,%d cannot be reached." % [id,marker.x,marker.y])
		var roles: Array = Array(entry.get("roles",[]))
		if roles.has("boss") and Vector2i(layout.exit).x < 0: errors.append("%s is a boss room without an X gate." % id)
		if roles.has("treasure") and Vector2i(layout.treasure).x < 0: errors.append("%s is a treasure room without a * pedestal." % id)
		if roles.has("shop") and Vector2i(layout.merchant).x < 0: errors.append("%s is a shop room without an M merchant." % id)
	for role in ROLES:
		if not role_coverage.has(role): errors.append("No forest room can serve as %s." % role)
	return errors

static func _reachable(cells: Dictionary, blocked: Dictionary, start: Vector2i) -> Dictionary:
	var seen := {start:true}
	var open: Array[Vector2i] = [start]
	while not open.is_empty():
		var cell: Vector2i = open.pop_front()
		for direction in DIRECTIONS.values():
			var next: Vector2i = cell + Vector2i(direction)
			if cells.has(next) and not blocked.has(next) and not seen.has(next):
				seen[next] = true
				open.append(next)
	return seen
