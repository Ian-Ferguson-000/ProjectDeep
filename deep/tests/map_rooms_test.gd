extends SceneTree

## Painted room scenes in maps/: they load, read back exactly like the old text
## rooms, report problems in plain language, and hand their art to the game.

var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	MapLibrary.clear_cache()
	# Every forest scene loads and matches the room it was converted from.
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/maps/legacy_forest_rooms.json"))
	var old := {}
	for entry in legacy.rooms: old[String(entry.id)] = entry
	var rooms := MapLibrary.rooms("forest")
	_expect(rooms.size() >= old.size(),"Expected at least the %d converted forest rooms, found %d" % [old.size(),rooms.size()])
	var converted := 0
	for room in rooms:
		var before: Dictionary = old.get(String(room.id),{})
		if before.is_empty(): continue
		converted += 1
		_expect(Array(room.map) == Array(before.map),"%s reads back differently from its text map" % room.id)
		_expect(Array(room.roles) == Array(before.roles) and String(room.name) == String(before.name),"%s lost its name or roles" % room.id)
		_expect(String(room.scene).begins_with("res://maps/forest/rooms/"),"%s has no scene path" % room.id)
	_expect(converted == old.size(),"Some converted rooms are missing (%d of %d)" % [converted,old.size()])
	_expect(ForestRoomLibrary.validate().is_empty(),"Forest rooms fail validation: %s" % "; ".join(ForestRoomLibrary.validate()))

	# Each scene has the artist's layers, and no warnings.
	for path in MapLibrary.room_paths("forest"):
		var node: MapRoom = load(path).instantiate()
		for layer in ["Ground","Terrain","Paths","Detail","Thicket","Canopy","Markers"]: _expect(node.get_node_or_null(layer) != null,"%s is missing its %s layer" % [path.get_file(),layer])
		_expect(MapLibrary.problems(node).is_empty(),"%s shows warnings: %s" % [path.get_file(),"; ".join(MapLibrary.problems(node))])
		for marker in node.get_node("Markers").get_children():
			var cell: Vector2i = marker.cell()
			_expect(cell.x > 0 and cell.y > 0 and cell.x < node.size_cells.x - 1 and cell.y < node.size_cells.y - 1,"%s has a marker on its edge" % path.get_file())
		node.free()

	# The template is a valid room to start from.
	var template: MapRoom = load("res://maps/_templates/RoomTemplate.tscn").instantiate()
	_expect(MapLibrary.problems(template).is_empty(),"RoomTemplate shows warnings: %s" % "; ".join(MapLibrary.problems(template)))
	var sample: Node = load("res://maps/_templates/Marker.tscn").instantiate()
	_expect(sample is MapMarker,"Marker.tscn is not a marker")
	sample.free()

	# Problems an artist could make are explained.
	var thicket: TileMapLayer = template.get_node("Thicket")
	var doors := template.door_cells()
	thicket.set_cell(Vector2i(doors.east) + Vector2i.LEFT,0,Vector2i(0,3))
	thicket.set_cell(Vector2i(doors.east) + Vector2i(-1,-1),0,Vector2i(0,3))
	thicket.set_cell(Vector2i(doors.east) + Vector2i(-1,1),0,Vector2i(0,3))
	thicket.set_cell(Vector2i(doors.east) + Vector2i(-2,0),0,Vector2i(0,3))
	thicket.set_cell(Vector2i(doors.east) + Vector2i(-2,-1),0,Vector2i(0,3))
	thicket.set_cell(Vector2i(doors.east) + Vector2i(-2,1),0,Vector2i(0,3))
	thicket.set_cell(Vector2i(doors.east) + Vector2i(0,-1),-1)
	var issues := "; ".join(MapLibrary.problems(template))
	_expect(issues.contains("east door cannot be reached"),"Blocked door not reported: %s" % issues)
	_expect(issues.contains("outer edge must be thicket"),"Gap in the wall not reported: %s" % issues)
	template.roles = 16
	var merchantless := "; ".join(MapLibrary.problems(template))
	_expect(merchantless.contains("Merchant marker") and merchantless.contains("cannot hold enemy spawns"),"Shop rules not reported: %s" % merchantless)
	var stray := MapMarker.new(); stray.kind = "loot"; stray.position = Vector2(-100,-100); template.get_node("Markers").add_child(stray)
	_expect("; ".join(MapLibrary.problems(template)).contains("outside the room"),"Marker outside the room not reported")
	template.free()

	# Painted art goes to the game; the thicket and markers do not.
	var art := MapLibrary.art_nodes(rooms[0])
	var names: Array = art.ground.map(func(node): return String(node.name))
	_expect(names.has("Ground") and names.has("Paths") and not names.has("Thicket") and not names.has("Markers"),"Wrong art layers: %s" % str(names))
	_expect(art.canopy.size() == 1,"Canopy layer not handed over")
	for node in art.ground + art.canopy: node.free()

	# Folders: every dungeon has one, hell maps to balors_hell.
	for id in ["forest","crypt","balors_hell","ashen_farmstead","sunken_mine","ember_foundry","moonlit_grove","abyssal_archive"]:
		_expect(DirAccess.dir_exists_absolute(MapLibrary.folder_for(id) + "rooms"),"No rooms folder for %s" % id)
	_expect(MapLibrary.folder_for("balors_hell") == "res://maps/hell/","Hell folder mapping wrong")
	_expect(MapLibrary.rooms("crypt").size() >= 18,"The crypt is missing its painted rooms")
	_expect(MapLibrary.rooms("balors_hell").is_empty(),"Hell should have no rooms yet")
	for path in ["res://maps/forest/tiles/forest_ground.tres","res://maps/forest/tiles/forest_paths.tres","res://maps/crypt/tiles/crypt_ground.tres","res://maps/hell/tiles/hell_ground.tres"]:
		_expect(load(path) is TileSet,"%s is not a TileSet" % path)
	var paths_set: TileSet = load("res://maps/forest/tiles/forest_paths.tres")
	_expect(paths_set.get_terrain_sets_count() == 1 and paths_set.get_terrain_name(0,0) == "Dirt","Dirt terrain missing for autotiling")

	if failures.is_empty(): print("MAP_ROOMS_TESTS_PASSED"); quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(value: bool, message: String) -> void:
	if not value and not failures.has(message): failures.append(message)
