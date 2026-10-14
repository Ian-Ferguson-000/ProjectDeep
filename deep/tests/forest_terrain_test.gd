extends SceneTree

const ART := preload("res://scripts/slasher/slasher_forest_terrain_art.gd")
const FOREST := preload("res://scenes/slasher/SlasherForest.tscn")
const MINE := preload("res://scenes/slasher/SlasherMine.tscn")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# Trails must remain on the actual floor, including bent/narrow corridors.
	for seed in range(100, 120):
		var floor_layout := SlasherForestGenerator.generate(seed, 1 + seed % 8)
		var original_cells: Dictionary = floor_layout.cells.duplicate()
		var paths := ART.make_paths(floor_layout)
		assert(floor_layout.cells == original_cells, "Terrain changed walkability")
		assert(paths.has(floor_layout.start * 2) and paths.has(floor_layout.exit * 2), "Trail misses floor endpoints")
		for cell: Vector2i in paths:
			assert(original_cells.has(Vector2i(floori(cell.x / 2.0), floori(cell.y / 2.0))), "Trail crosses the void")
		assert(_connected(paths, floor_layout.start * 2, floor_layout.exit * 2), "Trail disconnects at a corridor bend")
	# Check the source pixels as well as the corner orientation: no grass squares.
	var source := ART.SHEET.get_image()
	var diagonals := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	for index in range(diagonals.size()):
		var junction: Dictionary = {}
		for y in range(-1, 2):
			for x in range(-1, 2):
				if Vector2i(x, y) != diagonals[index]: junction[Vector2i(x, y)] = true
		var region := ART.dirt_region(Vector2i.ZERO, junction)
		var grass_quadrants := [0, 0, 0, 0]
		for y in 16:
			for x in 16:
				var pixel := source.get_pixel(int(region.position.x) + x, int(region.position.y) + y)
				if pixel.g > pixel.r: grass_quadrants[(2 if y >= 8 else 0) + (1 if x >= 8 else 0)] += 1
		assert(grass_quadrants[index] > 0 and grass_quadrants[index] < 32, "Internal corner contains a grass square")
		for quadrant in 4:
			if quadrant != index: assert(grass_quadrants[quadrant] <= 1, "Corner grass points into the trail")
	var scene = FOREST.instantiate()
	scene._ensure_designer_controls()
	var state := RunState.new()
	state.start_new_run(GearData.create("terrain_test", "Terrain Test", 3, false, 0, "", "", "warrior"), "forest")
	state.current_floor = 2
	state.floor_seed = 83492791 - state.current_floor * 997
	scene.run_state = state
	root.add_child(scene)
	assert(scene.ground_layer.get_child(0).texture == ART.SHEET, "Forest runtime still uses old grass")
	assert(scene.ground_layer.get_child_count() > scene.layout.cells.size(), "Forest runtime is missing dirt paths")
	assert(scene.wall_generator.render_collisions, "Terrain disabled gameplay walls")
	if "--capture" in OS.get_cmdline_user_args():
		scene.process_mode = Node.PROCESS_MODE_DISABLED
		await create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/forest_dungeon_new_tiles.png")
	scene.queue_free()
	await process_frame
	var mine = MINE.instantiate()
	var mine_state := RunState.new()
	mine_state.start_new_run(GearData.create("terrain_test", "Terrain Test", 3, false, 0, "", "", "warrior"), "sunken_mine")
	mine_state.current_floor = 2
	mine.run_state = mine_state
	root.add_child(mine)
	assert(mine.ground_layer.get_child(0).texture == SlasherForestArt.TX_GRASS, "Forest art leaked into the mine")
	mine.queue_free()
	await process_frame
	print("Forest terrain: 20 layouts, four corner orientations, live forest and mine runtime passed.")
	quit()

func _connected(cells: Dictionary, start: Vector2i, target: Vector2i) -> bool:
	var frontier: Array[Vector2i] = [start]
	var seen: Dictionary = {start: true}
	var head := 0
	while head < frontier.size():
		var cell := frontier[head]
		head += 1
		if cell == target: return true
		for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var neighbor := cell + direction
			if cells.has(neighbor) and not seen.has(neighbor):
				seen[neighbor] = true
				frontier.append(neighbor)
	return false
