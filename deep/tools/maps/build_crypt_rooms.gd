extends SceneTree

## One-time build of the Stone Crypt's rooms: writes the crypt TileSet
## (maps/crypt/tiles/crypt_ground.tres, from crypt_ground.png) and turns the
## designs in tools/maps/crypt_rooms.json into painted MapRoom scenes in
## maps/crypt/rooms/. Run from the deep/ folder:
##   python3 tools/maps/make_crypt_sheet.py        (tile art)
##   python3 tools/maps/crypt_room_designs.py      (room designs)
##   godot --headless --path . --script tools/maps/build_crypt_rooms.gd
## Re-running overwrites rooms with the same id: don't, once the artist has
## started repainting them.

const DESIGNS := "res://tools/maps/crypt_rooms.json"
const TILESET := "res://maps/crypt/tiles/crypt_ground.tres"
const SHEET := "res://maps/crypt/tiles/crypt_ground.png"
const MARKER_KINDS := {"O":"colossus","e":"enemy","E":"elite","$":"loot","*":"treasure","M":"merchant","X":"gate","P":"player_start","F":"campfire","C":"chest","R":"rock","T":"big_tree","r":"mossy_rock","p":"pebbles","m":"mushrooms","b":"bush"}
const ROLE_BITS := {"start":1,"combat":2,"elite":4,"treasure":8,"shop":16,"rest":32,"boss":64,"guardian":128}
const FLOOR_VARIANTS := 8

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://maps/crypt/rooms")
	_build_tileset()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DESIGNS))
	var count := 0
	for entry in Array(data.get("rooms",[])):
		var room := build_room(entry)
		var packed := PackedScene.new()
		packed.pack(room)
		ResourceSaver.save(packed,"res://maps/crypt/rooms/%s.tscn" % String(entry.id))
		room.free()
		count += 1
	print("Built crypt_ground.tres and %d crypt rooms" % count)
	quit(0)

## Floor (8 slabs), pit (open, and with a stone lip on top), carpet (plain,
## trimmed) and the wall marker, each tagged with its "kind".
func _build_tileset() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(48,48)
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(0,"kind")
	tile_set.set_custom_data_layer_type(0,TYPE_STRING)
	var source := TileSetAtlasSource.new()
	source.texture = load(SHEET)
	source.texture_region_size = Vector2i(48,48)
	tile_set.add_source(source,0)
	var flips := [[true,false],[false,true],[true,true]]
	for x in FLOOR_VARIANTS: _tile(source,Vector2i(x,0),"floor",flips)
	_tile(source,Vector2i(0,1),"pit",flips)
	_tile(source,Vector2i(1,1),"pit",[[true,false]])
	_tile(source,Vector2i(0,2),"carpet",[[false,true]])
	_tile(source,Vector2i(1,2),"carpet",[[false,true]])
	_tile(source,Vector2i(0,3),"wall")
	ResourceSaver.save(tile_set,TILESET)

func _tile(source: TileSetAtlasSource, coords: Vector2i, kind: String, flips: Array = []) -> void:
	source.create_tile(coords)
	source.get_tile_data(coords,0).set_custom_data("kind",kind)
	for flip in flips:
		var alternative := source.create_alternative_tile(coords)
		var tile := source.get_tile_data(coords,alternative)
		tile.set_custom_data("kind",kind)
		tile.flip_h = bool(flip[0]); tile.flip_v = bool(flip[1])

static func _layer(room: MapRoom, layer_name: String, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = load(TILESET)
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
	var ground := _layer(room,"Ground",0)
	var terrain := _layer(room,"Terrain",1)
	_layer(room,"Detail",3)
	var walls := _layer(room,"Thicket",4)
	walls.modulate = Color(1,1,1,0.85)
	_layer(room,"Canopy",20)
	var markers := Node2D.new(); markers.name = "Markers"; markers.z_index = 30; room.add_child(markers); markers.owner = room
	for y in rows.size():
		var row := String(rows[y])
		for x in row.length():
			var cell := Vector2i(x,y)
			var symbol := row[x]
			# Mostly plain and studded slabs; cracked and bone-strewn ones now and then.
			var roll := _hash(cell,11) % 20
			var variant := (_hash(cell,5) % 4) if roll < 17 else 4 + (_hash(cell,7) % 4)
			ground.set_cell(cell,0,Vector2i(variant,0),_hash(cell,23) % 4)
			match symbol:
				"#": walls.set_cell(cell,0,Vector2i(0,3))
				"~":
					var lip := y > 0 and String(rows[y - 1])[x] != "~"
					terrain.set_cell(cell,0,Vector2i(1 if lip else 0,1),0 if lip else _hash(cell,9) % 4)
				"c": terrain.set_cell(cell,0,Vector2i(0,2),0)
			var door_slot := y == 0 or y == rows.size() - 1 or x == 0 or x == row.length() - 1
			if MARKER_KINDS.has(symbol) and not door_slot:
				var marker := MapMarker.new()
				marker.kind = String(MARKER_KINDS[symbol])
				marker.name = "%s_%d_%d" % [String(marker.kind),x,y]
				marker.position = (Vector2(cell) + Vector2.ONE * 0.5) * 48.0
				markers.add_child(marker); marker.owner = room
	return room
