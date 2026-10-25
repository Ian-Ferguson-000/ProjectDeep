extends RefCounted
class_name MapLibrary

## Finds and reads the room scenes in maps/<dungeon>/rooms/.
##
## Each MapRoom scene is read into the same room template the game has always
## used ({id, name, roles, weight, map}) plus "scene" (its path), so the floor
## graph, doors, spawns and validation work the same for painted rooms. The
## scene's painted layers become the room's art in game (see art_nodes()).

const ROOT := "res://maps/"
const CELL := 48.0
const ART_LAYERS := ["Ground","Terrain","Paths","Detail"]
const CANOPY_LAYERS := ["Canopy"]
const KIND_SYMBOLS := {"water":"~","cobble":"c"}
## Dungeon id -> folder under maps/. Folders use short names artists can find.
const FOLDERS := {"forest":"forest","crypt":"crypt","balors_hell":"hell","ashen_farmstead":"farmstead","sunken_mine":"mine","ember_foundry":"foundry","moonlit_grove":"grove","abyssal_archive":"archive"}

static func folder_for(dungeon_id: String) -> String:
	return ROOT + String(FOLDERS.get(dungeon_id,dungeon_id)) + "/"

static var _cache: Dictionary = {}
static var _scenes: Dictionary = {}

## Every room scene in a dungeon's folder, read into room templates. Cached.
static func rooms(dungeon_id: String) -> Array:
	if _cache.has(dungeon_id): return _cache[dungeon_id]
	var result: Array = []
	for path in room_paths(dungeon_id):
		var scene := _scene(path)
		if scene == null: continue
		var node := scene.instantiate()
		if node is MapRoom: result.append(to_template(node,path))
		else: push_warning("%s is not a MapRoom scene; skipped." % path)
		node.free()
	_cache[dungeon_id] = result
	return result

static func clear_cache() -> void:
	_cache.clear(); _scenes.clear()

## Scene files in maps/<dungeon>/rooms/, sorted. Works in exported builds too.
static func room_paths(dungeon_id: String) -> Array[String]:
	var folder := folder_for(dungeon_id) + "rooms/"
	var paths: Array[String] = []
	if not DirAccess.dir_exists_absolute(folder): return paths
	for file in DirAccess.get_files_at(folder):
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tscn") and not paths.has(folder + name): paths.append(folder + name)
	paths.sort()
	return paths

static func dungeons() -> Array[String]:
	var result: Array[String] = []
	for folder in DirAccess.get_directories_at(ROOT):
		if not folder.begins_with("_"): result.append(folder)
	return result

static func _scene(path: String) -> PackedScene:
	if not _scenes.has(path): _scenes[path] = load(path) as PackedScene
	return _scenes[path]

## Reads a room scene's painting and markers into a text map.
static func to_template(room: MapRoom, path: String) -> Dictionary:
	var size := room.size_cells
	var grid: Array = []
	for y in size.y:
		var row: Array[String] = []
		row.resize(size.x)
		row.fill(".")
		grid.append(row)
	var thicket := room.get_node_or_null("Thicket") as TileMapLayer
	var terrain := room.get_node_or_null("Terrain") as TileMapLayer
	var paths := room.get_node_or_null("Paths") as TileMapLayer
	for y in size.y:
		for x in size.x:
			var center := (Vector2(x,y) + Vector2.ONE * 0.5) * CELL
			var symbol := "."
			if _dirt_corners(paths,center) == 4: symbol = "="
			var ground_kind := _kind_at(terrain,center)
			if KIND_SYMBOLS.has(ground_kind): symbol = KIND_SYMBOLS[ground_kind]
			if not _kind_at(thicket,center).is_empty(): symbol = "#"
			grid[y][x] = symbol
	var markers := room.get_node_or_null("Markers")
	if markers != null:
		for child in markers.get_children():
			if child is MapMarker:
				var cell: Vector2i = child.cell()
				if cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y: grid[cell.y][cell.x] = child.symbol()
	var doors := room.door_cells()
	for direction in doors:
		var cell: Vector2i = doors[direction]
		grid[cell.y][cell.x] = String(ForestRoomLibrary.DOOR_SYMBOLS[direction])
	var rows: Array[String] = []
	for row in grid: rows.append("".join(row))
	return {"id":path.get_file().get_basename(),"name":room.room_name,"roles":room.role_list(),"weight":room.weight,"map":rows,"scene":path}

static func _kind_at(layer: TileMapLayer, point: Vector2, offset: Vector2 = Vector2.ZERO) -> String:
	if layer == null or layer.tile_set == null: return ""
	var local := (point + offset - layer.position) / layer.scale
	var data := layer.get_cell_tile_data(layer.local_to_map(local))
	if data == null: return ""
	var kind: Variant = data.get_custom_data("kind") if layer.tile_set.get_custom_data_layer_by_name("kind") >= 0 else ""
	return String(kind) if kind != null and String(kind) != "" else "painted"

static func _dirt_corners(layer: TileMapLayer, center: Vector2) -> int:
	var count := 0
	for offset in [Vector2(-12,-12),Vector2(12,-12),Vector2(-12,12),Vector2(12,12)]:
		if not _kind_at(layer,center,offset).is_empty(): count += 1
	return count

## Plain-language problems with a room scene, for the editor warning triangle.
static func problems(room: MapRoom) -> Array[String]:
	var result: Array[String] = []
	if room.size_cells.x < 7 or room.size_cells.y < 7 or room.size_cells.x % 2 == 0 or room.size_cells.y % 2 == 0:
		return ["Size must be odd and at least 7x7 (standard 27x15, large 35x19)."]
	if room.role_list().is_empty(): result.append("Tick at least one role in the Inspector (combat, shop, ...).")
	for layer in ["Ground","Thicket","Markers"]:
		if room.get_node_or_null(layer) == null: result.append("Missing the %s node. Start from maps/_templates/RoomTemplate.tscn." % layer)
	var seen := {}
	var markers := room.get_node_or_null("Markers")
	if markers != null:
		for child in markers.get_children():
			if not child is MapMarker: continue
			var cell: Vector2i = child.cell()
			if cell.x < 0 or cell.y < 0 or cell.x >= room.size_cells.x or cell.y >= room.size_cells.y: result.append("%s marker is outside the room." % child.name)
			elif seen.has(cell): result.append("%s and %s share a cell; only one counts." % [seen[cell],child.name])
			seen[cell] = child.name
	var template := to_template(room,room.scene_file_path if not room.scene_file_path.is_empty() else "res://unsaved.tscn")
	for error in ForestRoomLibrary.validate_template(template): result.append(error.trim_prefix(String(template.id) + ": ").trim_prefix(String(template.id) + " "))
	return result

## The room's painted art, ready to add to the game world (positioned from the
## room's top-left). Thicket and Markers are left out: the game draws trees and
## spawns things from them. Returns {"ground":[nodes], "canopy":[nodes]}.
static func art_nodes(template: Dictionary) -> Dictionary:
	var result := {"ground":[],"canopy":[]}
	var scene := _scene(String(template.get("scene","")))
	if scene == null: return result
	var room := scene.instantiate()
	for child in room.get_children():
		var bucket := ""
		if ART_LAYERS.has(String(child.name)) or (child is TileMapLayer and not ["Thicket","Canopy"].has(String(child.name))) or String(child.name) == "Art": bucket = "ground"
		if CANOPY_LAYERS.has(String(child.name)): bucket = "canopy"
		if bucket.is_empty(): continue
		room.remove_child(child)
		result[bucket].append(child)
	room.free()
	return result
