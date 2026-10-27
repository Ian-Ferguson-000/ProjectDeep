extends SceneTree

## Creates the TileSet resources under maps/<dungeon>/tiles/ from the tileset
## images. Run from the deep/ folder:
##   godot --headless --path . --script tools/maps/build_tilesets.gd
##
## Every tile gets a "kind" (custom data) that tells the game what it is:
## grass, water, cobble, dirt, thicket or floor. Once the TileSets exist the
## artist edits them in Godot's TileSet panel; re-running this rebuilds them
## from scratch.

func _initialize() -> void:
	_forest_ground()
	_forest_paths()
	_slab_set("res://maps/crypt/tiles/crypt_ground.png","res://maps/crypt/tiles/crypt_ground.tres",2,1)
	_slab_set("res://maps/hell/tiles/hell_ground.png","res://maps/hell/tiles/hell_ground.tres",6,2)
	print("TileSets written under res://maps/")
	quit(0)

func _new_set(tile_size: int) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(tile_size,tile_size)
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(0,"kind")
	tile_set.set_custom_data_layer_type(0,TYPE_STRING)
	return tile_set

func _atlas(tile_set: TileSet, texture_path: String, tile_size: int) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = load(texture_path)
	source.texture_region_size = Vector2i(tile_size,tile_size)
	tile_set.add_source(source,0)
	return source

func _tile(source: TileSetAtlasSource, coords: Vector2i, kind: String, flips: Array = []) -> void:
	source.create_tile(coords)
	source.get_tile_data(coords,0).set_custom_data("kind",kind)
	# Mirrored copies as alternative tiles: more variety from the same art.
	for flip in flips:
		var alternative := source.create_alternative_tile(coords)
		var data := source.get_tile_data(coords,alternative)
		data.set_custom_data("kind",kind)
		data.flip_h = bool(flip[0])
		data.flip_v = bool(flip[1])

func _forest_ground() -> void:
	var tile_set := _new_set(32)
	var source := _atlas(tile_set,"res://maps/forest/tiles/forest_ground.png",32)
	var all_flips := [[true,false],[false,true],[true,true]]
	for x in 8: _tile(source,Vector2i(x,0),"grass",all_flips)
	for x in 4: _tile(source,Vector2i(x,1),"water",[[true,false]])
	for x in range(4,7): _tile(source,Vector2i(x,1),"water",[[true,false]])
	for x in 4: _tile(source,Vector2i(x,2),"cobble",all_flips)
	_tile(source,Vector2i(0,3),"thicket")
	ResourceSaver.save(tile_set,"res://maps/forest/tiles/forest_ground.tres")

## Dirt pieces with corner terrain bits, so paths can be drawn with the
## TileMap panel's Terrains tab and Godot picks the right edge pieces.
func _forest_paths() -> void:
	var tile_set := _new_set(16)
	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(0,TileSet.TERRAIN_MODE_MATCH_CORNERS)
	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0,0,"Dirt")
	tile_set.set_terrain_color(0,0,Color("#e8b14f"))
	var source := _atlas(tile_set,"res://maps/forest/tiles/forest_paths.png",16)
	# Which corners of each piece are dirt: top-left, top-right, bottom-left, bottom-right.
	var corners := {
		Vector2i(0,0):[0,0,0,1], Vector2i(1,0):[0,0,1,1], Vector2i(2,0):[0,0,1,0],
		Vector2i(0,1):[0,1,0,1], Vector2i(1,1):[1,1,1,1], Vector2i(2,1):[1,0,1,0],
		Vector2i(0,2):[0,1,0,0], Vector2i(1,2):[1,1,0,0], Vector2i(2,2):[1,0,0,0],
		Vector2i(3,0):[0,1,1,1], Vector2i(4,0):[1,0,1,1],
		Vector2i(3,1):[1,1,0,1], Vector2i(4,1):[1,1,1,0],
		Vector2i(3,2):[1,1,1,1], Vector2i(4,2):[1,1,1,1],
	}
	var neighbours := [TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER]
	for coords: Vector2i in corners:
		source.create_tile(coords)
		var data := source.get_tile_data(coords,0)
		data.set_custom_data("kind","dirt")
		data.terrain_set = 0
		data.terrain = 0
		var bits: Array = corners[coords]
		for index in 4:
			if int(bits[index]) == 1: data.set_terrain_peering_bit(neighbours[index],0)
		# The two spare dirt-centre pieces are rarer variety.
		if coords in [Vector2i(3,2),Vector2i(4,2)]: data.probability = 0.25
	ResourceSaver.save(tile_set,"res://maps/forest/tiles/forest_paths.tres")

func _slab_set(texture_path: String, save_path: String, columns: int, rows: int) -> void:
	var tile_set := _new_set(48)
	var source := _atlas(tile_set,texture_path,48)
	for y in rows:
		for x in columns: _tile(source,Vector2i(x,y),"floor",[[true,false],[false,true],[true,true]])
	ResourceSaver.save(tile_set,save_path)
