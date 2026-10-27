extends RefCounted
class_name ForestRoomLibrary

## Painted Verdant Forest rooms (maps/forest/rooms/, via MapLibrary) and the rules that
## turn one into a playable layout.
##
## A room map is a grid of single-character cells (see "legend" in the JSON). Each
## edge has one door slot on its centre cell. When a room is placed in the floor's
## room graph, slots facing a neighbour open and the rest are sealed with thicket.
##
## This is deliberately the seam for future procedural generation: anything that
## can produce the same template dictionary (id, roles, map) can feed
## build_layout(), whether it was drawn by hand or assembled by a generator.

const DIRECTIONS := {"north":Vector2i.UP,"east":Vector2i.RIGHT,"south":Vector2i.DOWN,"west":Vector2i.LEFT}
const OPPOSITE := {"north":"south","south":"north","east":"west","west":"east"}
const DOOR_SYMBOLS := {"north":"N","east":"E","south":"S","west":"W"}
const BLOCKING := ["#","~"]
const SOLID_KINDS := {"R":"rock","T":"tree_large","C":"chest"}
const DECORATION_KINDS := {"r":"mossy_rock","p":"pebbles","m":"mushrooms","F":"campfire"}
const BUSH_KINDS := ["low_bush_a","low_bush_b","rounded_bush"]
const KNOWN_SYMBOLS := "#.=c~RTCrpmbFeE$*MXPNSWO"
## Cells a colossus guardian's body blocks, centred on its marker.
const COLOSSUS_SIZE := Vector2i(7,5)
## guardian: the gate room on a guardian floor (holds the colossus).
const ROLES := ["start","combat","elite","treasure","shop","rest","boss","guardian"]
## Rooms where nothing hostile spawns. Campfires and merchants belong only here.
const PEACEFUL_ROLES := ["start","treasure","shop","rest"]
const CAMP_SYMBOLS := {"F":["shop","rest"],"M":["shop"]}

static var _cache: Dictionary = {}

## Rooms come from the painted scenes in maps/forest/rooms/ (see MapLibrary).
static func data() -> Dictionary:
	if _cache.is_empty(): _cache = {"rooms":MapLibrary.rooms("forest")}
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
						"r","p","m": decorations.append({"kind":DECORATION_KINDS[symbol],"cell":cell,"offset":Vector2(rng.randf_range(-6,6),rng.randf_range(-4,6)),"edge":false})
						"F": markers["campfire"] = cell
						"b": decorations.append({"kind":String(BUSH_KINDS[rng.randi_range(0,BUSH_KINDS.size()-1)]),"cell":cell,"offset":Vector2(rng.randf_range(-6,6),rng.randf_range(-4,4)),"edge":false})
						"e": enemy_markers.append(cell)
						"E": elite_markers.append(cell)
						"$": loot_spawns.append(cell)
						"*": markers["treasure"] = cell
						"M": markers["merchant"] = cell
						"X": markers["gate"] = cell
						"O": markers["colossus"] = cell
						"P": markers["start"] = cell
					# Markers dropped onto a trail keep the trail continuous underneath them.
					if "$MPX*eE".contains(symbol) and _touches_count(rows,cell,"=") >= 2: path_cells[cell] = true
	var center := Vector2i(size.x/2,size.y/2)
	# The colossus's body is part of the room: its cells are solid.
	var colossus_cells := {}
	if markers.has("colossus"):
		var middle: Vector2i = markers.colossus
		for y in range(middle.y - COLOSSUS_SIZE.y / 2,middle.y + COLOSSUS_SIZE.y / 2 + 1):
			for x in range(middle.x - COLOSSUS_SIZE.x / 2,middle.x + COLOSSUS_SIZE.x / 2 + 1):
				cells.erase(Vector2i(x,y)); path_cells.erase(Vector2i(x,y)); colossus_cells[Vector2i(x,y)] = true
		solid_props = solid_props.filter(func(prop): return not colossus_cells.has(Vector2i(prop.cell)))
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
		"campfire":Vector2i(markers.get("campfire",Vector2i(-100,-100))),
		"colossus":Vector2i(markers.get("colossus",Vector2i(-100,-100))),"colossus_cells":colossus_cells,
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
		for role in Array(entry.get("roles",[])): role_coverage[String(role)] = true
		errors.append_array(validate_template(entry))
	for role in ROLES:
		if not role_coverage.has(role): errors.append("No forest room can serve as %s." % role)
	return errors

## Problems with one room. Marker names match the MapMarker kinds artists see.
static func validate_template(entry: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var id := String(entry.get("id",""))
	for role in Array(entry.get("roles",[])):
		if not ROLES.has(String(role)): errors.append("%s: unknown role %s." % [id,role])
	var rows: Array = Array(entry.get("map",[]))
	var size := size_of(entry)
	if size.x < 7 or size.y < 7 or size.x % 2 == 0 or size.y % 2 == 0: return ["%s: must be at least 7x7 with odd dimensions." % id]
	for row in rows:
		if String(row).length() != size.x: return ["%s: has rows of different lengths." % id]
	var slots := door_cells(entry)
	for direction in slots:
		var slot: Vector2i = slots[direction]
		if String(rows[slot.y])[slot.x] != DOOR_SYMBOLS[direction]: errors.append("%s: is missing its %s door." % [id,direction])
	var markers: Array[Vector2i] = []
	var wall_gap := false
	for y in size.y:
		for x in size.x:
			var symbol := String(rows[y])[x]
			var cell := Vector2i(x,y)
			if not KNOWN_SYMBOLS.contains(symbol): errors.append("%s: unknown symbol '%s' at %d,%d." % [id,symbol,x,y])
			var on_edge := x == 0 or y == 0 or x == size.x-1 or y == size.y-1
			if on_edge and not slots.values().has(cell) and symbol != "#": wall_gap = true
			if not on_edge and "eE$*MXP".contains(symbol): markers.append(cell)
			if CAMP_SYMBOLS.has(symbol):
				for role in Array(entry.get("roles",[])):
					if not Array(CAMP_SYMBOLS[symbol]).has(String(role)): errors.append("%s: a %s only belongs in %s rooms, not %s." % [id,_marker_name(symbol)," or ".join(CAMP_SYMBOLS[symbol]),role])
			if "eE".contains(symbol) and not on_edge:
				for role in Array(entry.get("roles",[])):
					if PEACEFUL_ROLES.has(String(role)): errors.append("%s: a %s room cannot hold enemy spawns." % [id,role])
	if wall_gap: errors.append("%s: the outer edge must be thicket all the way round, except the four door cells." % id)
	var layout := build_layout(entry,DIRECTIONS.keys())
	var blocked := {}
	for prop in layout.solid_props: blocked[Vector2i(prop.cell)] = true
	if Vector2i(layout.campfire).x >= 0: blocked[Vector2i(layout.campfire)] = true
	var reach := _reachable(layout.cells,blocked,slots.north)
	for direction in slots:
		if not reach.has(slots[direction]): errors.append("%s: the %s door cannot be reached from the north door." % [id,direction])
	for marker in markers:
		if not reach.has(marker): errors.append("%s: the %s at %d,%d cannot be reached." % [id,_marker_name(String(rows[marker.y])[marker.x]),marker.x,marker.y])
	var roles: Array = Array(entry.get("roles",[]))
	if roles.has("boss") and Vector2i(layout.exit).x < 0: errors.append("%s: a boss room needs a Gate down marker." % id)
	if roles.has("treasure") and Vector2i(layout.treasure).x < 0: errors.append("%s: a treasure room needs a Treasure marker." % id)
	if roles.has("shop") and Vector2i(layout.merchant).x < 0: errors.append("%s: a shop room needs a Merchant marker." % id)
	if roles.has("rest") and Vector2i(layout.campfire).x < 0: errors.append("%s: a rest room needs a Campfire marker." % id)
	if roles.has("guardian") and Vector2i(layout.colossus).x < 0: errors.append("%s: a guardian room needs a Colossus marker." % id)
	if roles.has("guardian") and Vector2i(layout.exit).x < 0: errors.append("%s: a guardian room needs a Gate down marker for after the fight." % id)
	if Vector2i(layout.colossus).x >= 0 and not roles.has("guardian"): errors.append("%s: a Colossus marker only belongs in guardian rooms." % id)
	return errors

static func _marker_name(symbol: String) -> String:
	for kind in MapMarker.KINDS:
		if String(MapMarker.KINDS[kind][0]) == symbol: return String(MapMarker.KINDS[kind][1])
	return "'%s'" % symbol

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
