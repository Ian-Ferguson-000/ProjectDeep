extends SceneTree

## One-time conversion: turns the old text rooms (legacy_forest_rooms.json) into
## painted MapRoom scenes in maps/forest/rooms/, and writes the blank
## maps/_templates/RoomTemplate.tscn. Run from the deep/ folder:
##   godot --headless --path . --script tools/maps/convert_forest_rooms.gd
## Re-running overwrites rooms with the same id, so don't run it after the
## artist has started repainting them.

const LEGACY := "res://tools/maps/legacy_forest_rooms.json"
const GROUND_SET := "res://maps/forest/tiles/forest_ground.tres"
const PATH_SET := "res://maps/forest/tiles/forest_paths.tres"
const TERRAIN_ART := preload("res://scripts/slasher/slasher_forest_terrain_art.gd")
## Old dirt piece (sheet rectangle corner) -> tile in forest_paths.png.
const PIECES := {
	Vector2(400,16):Vector2i(0,0), Vector2(416,16):Vector2i(1,0), Vector2(544,16):Vector2i(2,0), Vector2(524,76):Vector2i(3,0), Vector2(420,76):Vector2i(4,0),
	Vector2(400,48):Vector2i(0,1), Vector2(472,16):Vector2i(1,1), Vector2(544,48):Vector2i(2,1), Vector2(524,36):Vector2i(3,1), Vector2(420,36):Vector2i(4,1),
	Vector2(400,96):Vector2i(0,2), Vector2(416,96):Vector2i(1,2), Vector2(544,96):Vector2i(2,2),
}
const MARKER_KINDS := {"O":"colossus","e":"enemy","E":"elite","$":"loot","*":"treasure","M":"merchant","X":"gate","P":"player_start","F":"campfire","C":"chest","R":"rock","T":"big_tree","r":"mossy_rock","p":"pebbles","m":"mushrooms","b":"bush"}
const ROLE_BITS := {"start":1,"combat":2,"elite":4,"treasure":8,"shop":16,"rest":32,"boss":64,"guardian":128}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://maps/forest/rooms")
	DirAccess.make_dir_recursive_absolute("res://maps/_templates")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LEGACY))
	var count := 0
	for entry in Array(data.get("rooms",[])):
		_save(build_room(entry),"res://maps/forest/rooms/%s.tscn" % String(entry.id))
		count += 1
	_save(build_room(_template_entry()),"res://maps/_templates/RoomTemplate.tscn")
	print("Converted %d forest rooms and wrote RoomTemplate.tscn" % count)
	quit(0)

func _save(room: MapRoom, path: String) -> void:
	var packed := PackedScene.new()
	packed.pack(room)
	ResourceSaver.save(packed,path)
	room.free()

static func _layer(room: MapRoom, layer_name: String, tile_set_path: String, z: int, cell_pixels: float = 48.0) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = load(tile_set_path)
	# Ground tiles fill a 48px room cell; dirt pieces are half-cells (24px).
	layer.scale = Vector2.ONE * (cell_pixels / float(layer.tile_set.tile_size.x))
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.z_index = z
	room.add_child(layer)
	layer.owner = room
	return layer

static func _hash(cell: Vector2i, salt: int) -> int:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663) ^ salt)

static func build_room(entry: Dictionary) -> MapRoom:
	var room := MapRoom.new()
	room.name = String(entry.get("name","Room")).replace(" ","").replace("'","")
	room.room_name = String(entry.get("name","Room"))
	room.weight = float(entry.get("weight",1.0))
	var bits := 0
	for role in Array(entry.get("roles",["combat"])): bits |= int(ROLE_BITS.get(String(role),0))
	room.roles = bits
	var rows: Array = Array(entry.map)
	room.size_cells = Vector2i(String(rows[0]).length(),rows.size())
	var ground := _layer(room,"Ground",GROUND_SET,0)
	var terrain := _layer(room,"Terrain",GROUND_SET,1)
	var paths := _layer(room,"Paths",PATH_SET,2,24.0)
	_layer(room,"Detail",GROUND_SET,3)
	var thicket := _layer(room,"Thicket",GROUND_SET,4)
	thicket.modulate = Color(1,1,1,0.85)
	_layer(room,"Canopy",GROUND_SET,20)
	var markers := Node2D.new(); markers.name = "Markers"; markers.z_index = 30; room.add_child(markers); markers.owner = room
	var water := {}
	for y in rows.size():
		for x in String(rows[y]).length():
			if String(rows[y])[x] == "~": water[Vector2i(x,y)] = true
	for y in rows.size():
		var row := String(rows[y])
		for x in row.length():
			var cell := Vector2i(x,y)
			var symbol := row[x]
			# Grass everywhere, even under walls, so gaps in the trees never show the void.
			ground.set_cell(cell,0,Vector2i(_hash(cell,11) % 8,0),_hash(cell,23) % 4)
			match symbol:
				"#": thicket.set_cell(cell,0,Vector2i(0,3))
				"~":
					var edge := not water.has(cell + Vector2i.UP)
					terrain.set_cell(cell,0,Vector2i(4 + _hash(cell,5) % 3,1) if edge else Vector2i(_hash(cell,5) % 4,1),_hash(cell,7) % 2)
				"c": terrain.set_cell(cell,0,Vector2i(_hash(cell,5) % 4,2),_hash(cell,7) % 4)
			var door_slot := (y == 0 or y == rows.size() - 1 or x == 0 or x == row.length() - 1)
			if MARKER_KINDS.has(symbol) and not door_slot:
				var marker := MapMarker.new()
				marker.kind = String(MARKER_KINDS[symbol])
				marker.name = "%s_%d_%d" % [String(marker.kind),x,y]
				marker.position = (Vector2(cell) + Vector2.ONE * 0.5) * 48.0
				markers.add_child(marker); marker.owner = room
	# Trails painted as if every door were open; closed doors are covered by trees in game.
	var layout := ForestRoomLibrary.build_layout(entry,ForestRoomLibrary.DIRECTIONS.keys())
	var half_cells := TERRAIN_ART.authored_paths(layout)
	for value in half_cells:
		var half: Vector2i = value
		var piece: Vector2i = PIECES.get(TERRAIN_ART.dirt_region(half,half_cells).position,Vector2i(1,1))
		if piece == Vector2i(1,1) and _hash(half,31) % 9 == 0: piece = Vector2i(3 + _hash(half,37) % 2,2)
		paths.set_cell(half,0,piece)
	return room

## The blank starting room for artists: grass, a thicket border, trails joining
## the four doors, a few enemy spawns and a loot cache.
static func _template_entry() -> Dictionary:
	var width := 27; var height := 15
	var rows: Array = []
	for y in height:
		var row := ""
		for x in width:
			var edge := x == 0 or y == 0 or x == width - 1 or y == height - 1
			var symbol := "#" if edge else "."
			if x == width / 2 or y == height / 2: symbol = "=" if not edge else symbol
			if edge and x == width / 2: symbol = "N" if y == 0 else "S"
			if edge and y == height / 2: symbol = "W" if x == 0 else "E"
			row += symbol
		rows.append(row)
	for spot in [Vector2i(5,4),Vector2i(20,4),Vector2i(6,10),Vector2i(21,10)]: rows[spot.y] = _put(rows[spot.y],spot.x,"e")
	rows[height / 2] = _put(rows[height / 2],width / 2,"$")
	return {"id":"room_template","name":"New Room","roles":["combat"],"weight":1.0,"map":rows}

static func _put(row: String, x: int, symbol: String) -> String:
	return row.substr(0,x) + symbol + row.substr(x + 1)
