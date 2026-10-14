extends RefCounted

## Terrain from the approved forest sheet, shared by gameplay and the art study.
const SHEET := preload("res://assets/pixel_art/forest_art/forest tiles.png")
const GRASS_REGION := Rect2(208, 80, 32, 32)

static func make_ground_sprite(cell_size: int = 48) -> Sprite2D:
	return _region(GRASS_REGION, float(cell_size) / 32.0)

static func make_decoration(kind: String) -> Sprite2D:
	if kind == "mossy_rock": return _region(Rect2(76, 17, 40, 31), 1.0)
	if kind.begins_with("grass_tuft"): return _region(Rect2(337, 79, 32, 36), 0.7)
	return SlasherForestArt.make_sprite(kind)

static func build_ground(parent: Node2D, layout: Dictionary, cell_size: int = 48, origin: Vector2 = Vector2.ZERO) -> void:
	for value: Variant in layout.cells:
		var cell: Vector2i = value
		var ground := make_ground_sprite(cell_size)
		ground.name = "Ground_%d_%d" % [cell.x, cell.y]
		ground.position = origin + (Vector2(cell) + Vector2.ONE * 0.5) * cell_size
		parent.add_child(ground)
	var paths := make_paths(layout)
	for value: Variant in paths:
		var cell: Vector2i = value
		var dirt := _region(dirt_region(cell, paths), float(cell_size) / 32.0)
		dirt.name = "Dirt_%d_%d" % [cell.x, cell.y]
		dirt.position = origin + (Vector2(cell) + Vector2.ONE * 0.5) * (cell_size / 2.0)
		parent.add_child(dirt)

static func make_paths(layout: Dictionary) -> Dictionary:
	var cells: Dictionary = layout.cells
	var points: Array[Vector2i] = []
	for room: Rect2i in layout.get("rooms", []):
		if cells.has(room.get_center()) and not points.has(room.get_center()): points.append(room.get_center())
	for key in ["start", "exit", "merchant"]:
		if layout.has(key) and cells.has(layout[key]) and not points.has(layout[key]): points.append(layout[key])
	var paths: Dictionary = {}
	var navigator := SlasherGridPathfinder.new().configure(cells, [], Vector2.ZERO, 48.0)
	for index in range(1, points.size()):
		# Keep the sample's L-shaped trails when they fit; route around voids otherwise.
		var cursor := points[index - 1]
		var target := points[index]
		var route: Array[Vector2i] = [cursor]
		while cursor != target:
			if cursor.x != target.x: cursor.x += signi(target.x - cursor.x)
			else: cursor.y += signi(target.y - cursor.y)
			route.append(cursor)
		for cell: Vector2i in route:
			if not cells.has(cell):
				route = navigator.find_cell_path(points[index - 1], target)
				break
		for step in range(route.size()):
			var half_cell := route[step] * 2
			_path_slice(paths, cells, half_cell)
			if step > 0: _path_slice(paths, cells, half_cell + route[step - 1] - route[step])
	return paths

static func _path_slice(paths: Dictionary, cells: Dictionary, cell: Vector2i) -> void:
	for y in range(-1, 2):
		for x in range(-1, 2):
			var point := cell + Vector2i(x, y)
			var coarse := Vector2i(floori(point.x / 2.0), floori(point.y / 2.0))
			if cells.has(coarse): paths[point] = true

static func dirt_region(cell: Vector2i, paths: Dictionary) -> Rect2:
	var left := not paths.has(cell + Vector2i.LEFT)
	var right := not paths.has(cell + Vector2i.RIGHT)
	var top := not paths.has(cell + Vector2i.UP)
	var bottom := not paths.has(cell + Vector2i.DOWN)
	var x := 400 if left else (544 if right else 416)
	var y := 16 if top else (96 if bottom else 48)
	if not (left or right or top or bottom):
		# Only the grass tip belongs in a missing diagonal, not the grass island.
		if not paths.has(cell + Vector2i(-1, -1)): return Rect2(524, 76, 16, 16)
		if not paths.has(cell + Vector2i(1, -1)): return Rect2(420, 76, 16, 16)
		if not paths.has(cell + Vector2i(-1, 1)): return Rect2(524, 36, 16, 16)
		if not paths.has(cell + Vector2i(1, 1)): return Rect2(420, 36, 16, 16)
		return Rect2(472, 16, 16, 16)
	return Rect2(x, y, 16, 16)

static func _region(rect: Rect2, scale_value: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = SHEET
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.region_enabled = true
	sprite.region_rect = rect
	sprite.scale = Vector2.ONE * scale_value
	return sprite
