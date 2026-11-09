extends Node3D
## Deterministic low-poly room kit. One map cell = one metre. Shared static
## primitives are instanced by material; destructible props remain independent.
## theme "forest": grass, hedges and trees. theme "crypt": flagstones, stone
## walls and pillars, bones, candles, iron-barred doors and stairs down.
var world: Node3D
var theme := "forest"
var torches := 0
## Guardians are goliaths built into the north wall: their models are this much
## bigger than the cells they block, and sit this far back into the wall.
const GOLIATH_SCALE := 2.3
const GOLIATH_BACK := 2.2
const TAVERN_ROOM := "res://assets/tavern3d/hearth_room.glb"
var rng := RandomNumberGenerator.new()
var materials: Dictionary = {}
var batches: Dictionary = {}
var dimensions := Vector2.ZERO
## Trees fade see-through when the player walks near or behind them
## (slasher_balance.json → tree_fade). Each entry: {root, meshes, alpha}.
var fading_trees: Array = []
var fade_rules: Dictionary = {}


func mat(color: String, glow: bool = false) -> StandardMaterial3D:
	var key := color + str(glow)
	if materials.has(key):
		return materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = 0.94
	if glow:
		material.emission_enabled = true
		material.emission = Color(color)
		material.emission_energy_multiplier = 1.4
	materials[key] = material
	return material


func primitive(
	kind: String,
	color: String,
	point: Vector3,
	size: Vector3,
	parent: Node3D = null,
	rotation: Vector3 = Vector3.ZERO,
	glow: bool = false
) -> MeshInstance3D:
	var key := kind + color + str(glow)
	var mesh: PrimitiveMesh
	if batches.has(key):
		mesh = batches[key].mesh
	else:
		match kind:
			"orb":
				var sphere := SphereMesh.new()
				sphere.radius = 0.5
				sphere.height = 1.0
				sphere.radial_segments = 7
				sphere.rings = 3
				mesh = sphere
			"trunk":
				var cylinder := CylinderMesh.new()
				cylinder.top_radius = 0.38
				cylinder.bottom_radius = 0.5
				cylinder.height = 1.0
				cylinder.radial_segments = 7
				mesh = cylinder
			_:
				var cube := BoxMesh.new()
				cube.size = Vector3.ONE
				mesh = cube
		mesh.material = mat(color, glow)
		batches[key] = {"mesh": mesh, "transforms": []}
	var transform := Transform3D(Basis.from_euler(rotation).scaled(size), point)
	if parent == null:
		batches[key].transforms.append(transform)
		return null
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.transform = transform
	parent.add_child(instance)
	return instance


func build(layout: Dictionary) -> void:
	dimensions = Vector2(layout.width, layout.height)
	rng.seed = hash(
		str(world.dungeon.run_state.get_current_floor_seed()) + ":" + str(world.dungeon.room_id)
	)
	var cells: Dictionary = layout.cells
	var paths: Dictionary = layout.get("path_cells", {})
	var cobbles: Dictionary = layout.get("cobble_cells", {})
	var water: Dictionary = layout.get("water_cells", {})
	var thicket: Dictionary = layout.get("thicket_cells", {})
	var body: Dictionary = layout.get("colossus_cells", {})
	var all := cells.duplicate()
	all.merge(thicket)
	all.merge(body)
	if theme == "crypt":
		_build_crypt(layout, cells, paths, cobbles, water, thicket, all)
		return
	for value in all:
		var cell: Vector2i = value
		var point := Vector3(cell.x + 0.5, -0.32, cell.y + 0.5)
		primitive("box", "4a3d2c", point, Vector3(1.005, 0.64, 1.005))
		var color := "536c3c"
		if thicket.has(cell):
			color = "314c32"
		elif paths.has(cell):
			color = "9a8052"
		elif cobbles.has(cell):
			color = "6e7964"
		else:
			color = ["526b3b", "546d3d", "506a3a"][posmod(int(cell.x / 3) + int(cell.y / 3), 3)]
		primitive("box", color, point + Vector3(0, 0.31, 0), Vector3(1.005, 0.035, 1.005))
		if cobbles.has(cell):
			for i in 3:
				primitive(
					"orb",
					"8b927b",
					point + Vector3(rng.randf_range(-.3, .3), .36, rng.randf_range(-.3, .3)),
					Vector3(.40, .12, .28),
					null,
					Vector3(0, rng.randf() * TAU, 0)
				)
		elif cells.has(cell) and not paths.has(cell) and rng.randf() < 0.35:
			grass(point + Vector3(0, .34, 0))
	for value in water:
		var cell: Vector2i = value
		primitive(
			"box", "233d37", Vector3(cell.x + .5, -.44, cell.y + .5), Vector3(1.005, .40, 1.005)
		)
		primitive(
			"box", "487e78", Vector3(cell.x + .5, -.18, cell.y + .5), Vector3(1.005, .04, 1.005)
		)
		if rng.randf() < .45:
			primitive(
				"box",
				"80aaa0",
				Vector3(cell.x + .5, -.151, cell.y + .5),
				Vector3(.42, .008, .018),
				null,
				Vector3(0, .2, 0)
			)
	# Each blocked edge has a visible bank. Higher canopy is kept to the rear;
	# foreground growth is cut down so it never hides combat or door thresholds.
	# Doorways stay clear (slasher_balance.json tree_fade.door_clear_radius): no
	# trees or bushes right at an exit, only low shrubs a little further out.
	var door_points: Array = []
	for direction in Dictionary(layout.get("doors", {})):
		door_points.append(Vector2(Vector2i(layout.doors[direction])))
	var clear_radius := float(
		GameBalance.get_slasher_balance("tree_fade").get("door_clear_radius", 2.6)
	)
	for value in thicket:
		var cell: Vector2i = value
		if body.has(cell):
			continue
		var point := Vector3(cell.x + .5, 0, cell.y + .5)
		var near := cell.y > dimensions.y * .65
		var door_gap := INF
		for door_point in door_points:
			door_gap = minf(door_gap, Vector2(cell).distance_to(door_point))
		if door_gap <= clear_radius * 0.6:
			continue
		if door_gap <= clear_radius:
			primitive("orb", "46543b", point + Vector3(0, .18, 0), Vector3(.9, .45, .85))
			continue
		primitive("orb", "46543b", point + Vector3(0, .22, 0), Vector3(1.05, .65, .95))
		if (cell.x + cell.y) % 2 == 0:
			var height := rng.randf_range(3.5, 4.8) if not near else rng.randf_range(.8, 1.3)
			if cell.x < 2 or cell.x > dimensions.x - 3:
				height = minf(height, 2.3)
			standing_tree(point, height)
		else:
			primitive("orb", "3e6036", point + Vector3(0, .5, 0), Vector3(1.25, .95, 1.15))
	# Non-room tutorial/interlude layouts still receive an honest boundary.
	if thicket.is_empty():
		var boundary := {}
		for value in cells:
			for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var cell: Vector2i = Vector2i(value) + direction
				if not cells.has(cell):
					boundary[cell] = true
		for value in boundary:
			var cell: Vector2i = value
			primitive(
				"orb", "415936", Vector3(cell.x + .5, .35, cell.y + .5), Vector3(1.05, 1.0, 1.05)
			)
	for record in layout.get("decorations", []):
		var point: Vector3 = world.to_world(world.dungeon._world(Vector2i(record.cell)))
		var kind := String(record.kind)
		if kind.contains("mushroom"):
			mushrooms(point)
		elif kind.contains("rock"):
			primitive("orb", "7d856a", point + Vector3(0, .09, 0), Vector3(.35, .2, .27))
		else:
			grass(point)
	build_landmarks(layout)
	flush()


# ---------------------------------------------------------------- crypt

## Room-map decoration names (forest names) -> crypt dressing, as slasher_crypt.gd.
const CRYPT_DECOR := {
	"mossy_rock": "rubble",
	"pebbles": "bone_pile",
	"mushrooms": "candles",
	"low_bush_a": "urn",
	"low_bush_b": "tombstone",
	"rounded_bush": "grave_cross"
}


func _build_crypt(
	layout: Dictionary,
	cells: Dictionary,
	paths: Dictionary,
	cobbles: Dictionary,
	water: Dictionary,
	thicket: Dictionary,
	all: Dictionary
) -> void:
	for value in all:
		var cell: Vector2i = value
		var point := Vector3(cell.x + 0.5, -0.32, cell.y + 0.5)
		primitive("box", "2a2830", point, Vector3(1.005, 0.64, 1.005))
		if water.has(cell) or thicket.has(cell):
			continue
		# Flagstones with dark grout; worn paths are darker and smoother.
		var color: String = ["66646c", "625f68", "6a6770", "5f5c66"][posmod(
			cell.x * 7 + cell.y * 13, 4
		)]
		if paths.has(cell) or cobbles.has(cell):
			color = ["55525c", "59565f"][posmod(cell.x + cell.y, 2)]
		primitive("box", color, point + Vector3(0, .31, 0), Vector3(.95, .04, .95))
		if cells.has(cell) and rng.randf() < 0.05:
			primitive(
				"orb",
				"6b6574",
				point + Vector3(rng.randf_range(-.3, .3), .36, rng.randf_range(-.3, .3)),
				Vector3(.22, .1, .16),
				null,
				Vector3(0, rng.randf() * TAU, 0)
			)
	for value in water:
		var cell: Vector2i = value
		primitive(
			"box", "120f18", Vector3(cell.x + .5, -.44, cell.y + .5), Vector3(1.005, .40, 1.005)
		)
		primitive(
			"box", "2a3340", Vector3(cell.x + .5, -.18, cell.y + .5), Vector3(1.005, .04, 1.005)
		)
	# Walls: tall at the back, cut down in front so they never hide a fight.
	var body: Dictionary = layout.get("colossus_cells", {})
	for value in thicket:
		var cell: Vector2i = value
		if body.has(cell):
			continue
		var point := Vector3(cell.x + .5, 0, cell.y + .5)
		var near := cell.y > dimensions.y * .65
		var height := 0.55 if near else 2.3
		if not near and (cell.x < 2 or cell.x > dimensions.x - 3):
			height = 1.6
		primitive(
			"box",
			["4f4d56", "4a4851", "53515a"][posmod(cell.x + cell.y * 3, 3)],
			point + Vector3(0, height * .5, 0),
			Vector3(1.005, height, 1.005)
		)
		primitive("box", "66636e", point + Vector3(0, height + .04, 0), Vector3(1.03, .08, 1.03))
		if not near and posmod(cell.x, 5) == 0 and posmod(cell.y, 2) == 0:
			primitive(
				"trunk",
				"3d3946",
				point + Vector3(0, height * .5 + .15, 0),
				Vector3(.62, height + .3, .62)
			)
		if (
			not near
			and torches < 6
			and posmod(cell.x * 3 + cell.y, 11) == 0
			and cells.has(cell + Vector2i.DOWN)
		):
			torches += 1
			primitive("box", "2b2630", point + Vector3(0, 1.5, .55), Vector3(.10, .32, .10))
			primitive(
				"orb",
				"b9a2ff",
				point + Vector3(0, 1.75, .58),
				Vector3(.18, .26, .18),
				null,
				Vector3.ZERO,
				true
			)
			light(point + Vector3(0, 1.9, .9), Color("a58cff"), 5.0)
	if thicket.is_empty():
		var boundary := {}
		for value in cells:
			for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var cell: Vector2i = Vector2i(value) + direction
				if not cells.has(cell):
					boundary[cell] = true
		for value in boundary:
			var cell: Vector2i = value
			primitive(
				"box", "4a4553", Vector3(cell.x + .5, .4, cell.y + .5), Vector3(1.005, .8, 1.005)
			)
	for record in layout.get("decorations", []):
		var point: Vector3 = world.to_world(world.dungeon._world(Vector2i(record.cell)))
		crypt_decor(String(CRYPT_DECOR.get(String(record.kind), String(record.kind))), point)
	build_landmarks(layout)
	flush()


func crypt_decor(kind: String, point: Vector3, parent: Node3D = null) -> void:
	match kind:
		"candles":
			for i in 3:
				var offset := Vector3(rng.randf_range(-.22, .22), 0, rng.randf_range(-.22, .22))
				var tall := rng.randf_range(.14, .30)
				primitive(
					"trunk",
					"d8d0b8",
					point + offset + Vector3(0, tall * .5, 0),
					Vector3(.07, tall, .07),
					parent
				)
				primitive(
					"orb",
					"ffcf7a",
					point + offset + Vector3(0, tall + .04, 0),
					Vector3(.05, .08, .05),
					parent,
					Vector3.ZERO,
					true
				)
		"bone_pile":
			for i in 4:
				primitive(
					"box",
					"c9c1ae",
					point + Vector3(rng.randf_range(-.25, .25), .05, rng.randf_range(-.25, .25)),
					Vector3(.34, .06, .07),
					parent,
					Vector3(0, rng.randf() * TAU, 0)
				)
			if rng.randf() < .5:
				primitive(
					"orb", "d6cfbd", point + Vector3(.08, .1, 0), Vector3(.17, .15, .17), parent
				)
		"urn":
			primitive("trunk", "6d5546", point + Vector3(0, .22, 0), Vector3(.32, .44, .32), parent)
			primitive("orb", "7c6352", point + Vector3(0, .30, 0), Vector3(.42, .34, .42), parent)
		"tombstone":
			primitive(
				"box",
				"767180",
				point + Vector3(0, .36, 0),
				Vector3(.55, .72, .16),
				parent,
				Vector3(0, 0, rng.randf_range(-.08, .08))
			)
			primitive("orb", "767180", point + Vector3(0, .72, 0), Vector3(.55, .24, .16), parent)
		"grave_cross":
			primitive("box", "6b6676", point + Vector3(0, .45, 0), Vector3(.12, .9, .12), parent)
			primitive("box", "6b6676", point + Vector3(0, .66, 0), Vector3(.5, .12, .12), parent)
		_:
			primitive(
				"orb",
				"5d5868",
				point + Vector3(0, .1, 0),
				Vector3(.38, .22, .3),
				parent,
				Vector3(0, rng.randf() * TAU, 0)
			)


## The Charnel King: a giant crowned skeleton sunk to the chest in the floor.
func charnel_king(point: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "CharnelKing"
	root.position = point + Vector3(0, 0, -GOLIATH_BACK * .6)
	root.scale = Vector3.ONE * GOLIATH_SCALE
	add_child(root)
	primitive("trunk", "0d0a11", Vector3(0, .02, .6), Vector3(6.8, .04, 3.2), root)
	for i in 10:
		var angle := PI * .05 + PI * .9 * i / 9.0
		primitive(
			"box",
			"3a3640",
			Vector3(cos(angle) * 3.2, .12, .6 + sin(angle) * 1.5),
			Vector3(.5, .24, .36),
			root,
			Vector3(0, angle, 0)
		)
	for rib in 4:
		var width := 2.4 - rib * .3
		for side in [-1.0, 1.0]:
			primitive(
				"box",
				"c9c1ae",
				Vector3(side * width * .5, .75 - rib * .08, .2 + rib * .45),
				Vector3(width, .22, .22),
				root,
				Vector3(0, 0, side * -.55)
			)
	primitive("box", "9b9483", Vector3(0, .7, .9), Vector3(.3, .5, 2.2), root)
	var skull := Node3D.new()
	skull.name = "Skull"
	skull.position = Vector3(0, 2.2, -1.0)
	root.add_child(skull)
	primitive("orb", "d0c8b4", Vector3.ZERO, Vector3(2.9, 2.6, 2.6), skull)
	for side in [-1.0, 1.0]:
		primitive("orb", "120d16", Vector3(side * .55, .05, 1.12), Vector3(.7, .75, .4), skull)
		var eye := primitive(
			"orb",
			"9fd8ff",
			Vector3(side * .55, .05, 1.3),
			Vector3(.24, .24, .18),
			skull,
			Vector3.ZERO,
			true
		)
		eye.name = "Eye" if side < 0 else "Eye2"
	primitive("box", "120d16", Vector3(0, -.45, 1.25), Vector3(.25, .3, .2), skull)
	var jaw := primitive("box", "bdb5a1", Vector3(0, -1.15, .75), Vector3(1.8, .45, 1.1), skull)
	jaw.name = "Jaw"
	for spike in 5:
		var x := -1.0 + spike * .5
		primitive(
			"box",
			"a8873e",
			Vector3(x, 1.4 + (.22 if spike == 2 else 0.0), 0),
			Vector3(.2, .55 + (.3 if spike == 2 else 0.0), .2),
			skull,
			Vector3(0, PI * .25, 0)
		)
	primitive("trunk", "a8873e", Vector3(0, 1.2, 0), Vector3(2.5, .22, 2.3), skull)
	primitive(
		"orb", "c2453c", Vector3(0, 1.25, 1.12), Vector3(.18, .18, .12), skull, Vector3.ZERO, true
	)
	var glow := OmniLight3D.new()
	glow.name = "EyeGlow"
	glow.position = Vector3(0, 2.3, .6)
	glow.light_color = Color("7fe0ff")
	glow.omni_range = 6.0
	glow.light_energy = 1.2
	root.add_child(glow)
	return root


func bone_heap(point: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "FallenCharnelKing"
	root.position = point + Vector3(0, 0, -GOLIATH_BACK * .6)
	root.scale = Vector3.ONE * GOLIATH_SCALE
	add_child(root)
	var heap := RandomNumberGenerator.new()
	heap.seed = 777
	for i in 30:
		primitive(
			"box",
			"c9c1ae",
			Vector3(
				heap.randf_range(-2.6, 2.6), heap.randf_range(.05, .35), heap.randf_range(-1.4, 1.6)
			),
			Vector3(heap.randf_range(.5, 1.0), .12, .14),
			root,
			Vector3(heap.randf_range(-.3, .3), heap.randf() * TAU, 0)
		)
	primitive("orb", "b5ad99", Vector3(-.2, .6, 0), Vector3(2.2, 1.4, 2.0), root, Vector3(0, 0, .5))
	for side in [-1.0, 1.0]:
		primitive("orb", "120d16", Vector3(side * .45 - .2, .75, .85), Vector3(.5, .5, .3), root)
	primitive(
		"trunk", "8a7038", Vector3(1.6, .2, .9), Vector3(1.8, .18, 1.6), root, Vector3(.5, 0, .3)
	)
	return root


func grass(point: Vector3) -> void:
	for i in 3:
		var offset := Vector3(rng.randf_range(-.35, .35), .12, rng.randf_range(-.35, .35))
		primitive(
			"box",
			"819259",
			point + offset,
			Vector3(.045, rng.randf_range(.16, .28), .10),
			null,
			Vector3(0, rng.randf() * PI, .18)
		)


func mushrooms(point: Vector3) -> void:
	for i in 3:
		var offset := Vector3(rng.randf_range(-.23, .23), 0, rng.randf_range(-.23, .23))
		primitive("trunk", "c6ba8a", point + offset + Vector3(0, .12, 0), Vector3(.07, .24, .07))
		primitive("orb", "c18e52", point + offset + Vector3(0, .24, 0), Vector3(.24, .12, .24))


func tree(point: Vector3, height: float, parent: Node3D = null) -> void:
	primitive(
		"trunk",
		"60452f",
		point + Vector3(0, height * .38, 0),
		Vector3(.36, height * .76, .36),
		parent
	)
	for i in 3:
		var angle := i * TAU / 3.0
		primitive(
			"trunk",
			"60452f",
			point + Vector3(cos(angle) * .17, .09, sin(angle) * .17),
			Vector3(.18, .50, .18),
			parent,
			Vector3(.65, angle, 0)
		)
	if height < 1.5:
		primitive(
			"orb", "4f713e", point + Vector3(0, height * .70, 0), Vector3(1.3, .8, 1.2), parent
		)
	else:
		for i in 3:
			var angle := i * TAU / 3.0 + .4
			primitive(
				"orb",
				["3d6035", "52753d", "638348"][i],
				point + Vector3(cos(angle) * .45, height * .72 + i * .14, sin(angle) * .4),
				Vector3(1.7, 1.65, 1.65),
				parent
			)
		primitive(
			"orb", "66874a", point + Vector3(.08, height - .35, 0), Vector3(1.25, 1.1, 1.2), parent
		)


## A tree with its own nodes (not batched) so it can fade on its own.
func standing_tree(point: Vector3, height: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Tree"
	root.position = point
	add_child(root)
	tree(Vector3.ZERO, height, root)
	_track_fading(root)
	return root


func _track_fading(root: Node3D) -> void:
	var meshes: Array = []
	for child in root.get_children():
		if child is GeometryInstance3D:
			meshes.append(child)
	fading_trees.append({"root": root, "meshes": meshes, "alpha": 0.0})


## Fades every tree that is close to the player, or stands between the player
## and the camera, so the player is never hidden behind a canopy.
func fade_trees(player: Vector3, toward_camera: Vector3, delta: float) -> void:
	if fade_rules.is_empty():
		fade_rules = GameBalance.get_slasher_balance("tree_fade")
	var rules := fade_rules
	var near := float(rules.get("near_radius", 2.2))
	var behind_width := float(rules.get("behind_width", 1.7))
	var behind_depth := float(rules.get("behind_depth", 6.0))
	var faded := float(rules.get("faded_transparency", 0.72))
	var speed := float(rules.get("fade_speed", 8.0))
	var look := Vector2(toward_camera.x, toward_camera.z).normalized()
	var keep: Array = []
	for record in fading_trees:
		var root: Node3D = record.root
		if not is_instance_valid(root):
			continue
		keep.append(record)
		var offset := Vector2(root.global_position.x - player.x, root.global_position.z - player.z)
		var along := offset.dot(look)
		var across := absf(offset.cross(look))
		var hiding := (
			offset.length() < near
			or (along > -0.5 and along < behind_depth and across < behind_width)
		)
		var target := faded if hiding else 0.0
		var alpha: float = move_toward(float(record.alpha), target, delta * speed * faded)
		if is_equal_approx(alpha, float(record.alpha)) and alpha == target and record.has("set"):
			continue
		record.alpha = alpha
		record["set"] = true
		for mesh in record.meshes:
			if is_instance_valid(mesh):
				_set_see_through(mesh, alpha)
	fading_trees = keep


## A see-through copy of the mesh's own material (works on every renderer);
## fully solid again uses the shared opaque material, shadows included.
func _set_see_through(mesh: MeshInstance3D, alpha: float) -> void:
	if alpha <= 0.001:
		mesh.material_override = null
		return
	var faded: StandardMaterial3D = mesh.material_override
	if faded == null:
		var base: StandardMaterial3D = mesh.mesh.material
		faded = base.duplicate()
		faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material_override = faded
	faded.albedo_color.a = 1.0 - alpha


func make_prop(kind: String, point: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = kind.to_pascal_case()
	root.position = point
	add_child(root)
	if theme == "crypt" and kind != "chest":
		match kind:
			"coffin", "tree_large", "tree_small", "tree":
				primitive("box", "4a3528", Vector3(0, .22, 0), Vector3(.62, .44, 1.25), root)
				primitive("box", "5c4332", Vector3(0, .47, 0), Vector3(.66, .08, 1.3), root)
				primitive("box", "8a7a5a", Vector3(0, .52, -.1), Vector3(.06, .02, .6), root)
				primitive("box", "8a7a5a", Vector3(0, .52, -.2), Vector3(.32, .02, .06), root)
			_:
				primitive(
					"orb",
					"5d5868",
					Vector3(0, .28, 0),
					Vector3(.85, .6, .7),
					root,
					Vector3(.1, .5, .1)
				)
				primitive("orb", "6b6574", Vector3(-.19, .45, .1), Vector3(.45, .24, .36), root)
		return root
	match kind:
		"tree_large", "tree_small", "tree":
			tree(Vector3.ZERO, 2.7, root)
			_track_fading(root)
		"chest":
			primitive("box", "755034", Vector3(0, .25, 0), Vector3(.74, .5, .52), root)
			var lid := primitive("box", "9a7042", Vector3(0, .53, 0), Vector3(.78, .13, .56), root)
			lid.name = "Lid"
			for x in [-.24, .24]:
				primitive("box", "c4a765", Vector3(x, .32, .275), Vector3(.065, .48, .025), root)
			primitive("box", "e4c97a", Vector3(0, .41, .285), Vector3(.10, .14, .035), root)
		_:
			primitive(
				"orb", "7b8270", Vector3(0, .30, 0), Vector3(.85, .7, .7), root, Vector3(.1, .5, .1)
			)
			primitive("orb", "617452", Vector3(-.19, .48, .1), Vector3(.47, .24, .37), root)
	return root


func open_chest(root: Node3D) -> void:
	var lid := root.get_node_or_null("Lid") as Node3D
	if lid != null:
		lid.position = Vector3(0, .74, -.22)
		lid.rotation.x = -1.1


func door(point: Vector3, direction: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Passage_" + direction
	root.position = point
	if direction in ["east", "west"]:
		root.rotation.y = PI * .5
	add_child(root)
	if theme == "crypt":
		for x in [-.72, .72]:
			primitive("box", "5f5a69", Vector3(x, .75, 0), Vector3(.34, 1.5, .4), root)
			primitive(
				"orb",
				"b9a2ff",
				Vector3(x, 1.6, 0),
				Vector3(.15, .15, .15),
				root,
				Vector3.ZERO,
				true
			)
		primitive("box", "5f5a69", Vector3(0, 1.55, 0), Vector3(1.8, .24, .42), root)
		var bars := Node3D.new()
		bars.name = "Brambles"
		root.add_child(bars)
		for i in 5:
			primitive(
				"trunk", "3a3640", Vector3(-.48 + i * .24, .72, 0), Vector3(.06, 1.44, .06), bars
			)
		for y in [.4, 1.1]:
			primitive("box", "3a3640", Vector3(0, y, 0), Vector3(1.15, .07, .07), bars)
		return root
	for x in [-.68, .68]:
		primitive("trunk", "6b654a", Vector3(x, .62, 0), Vector3(.27, 1.24, .31), root)
		primitive(
			"orb", "a5bd75", Vector3(x, 1.31, 0), Vector3(.16, .16, .16), root, Vector3.ZERO, true
		)
	var barrier := Node3D.new()
	barrier.name = "Brambles"
	root.add_child(barrier)
	for i in 4:
		primitive(
			"trunk",
			"624433",
			Vector3(-.42 + i * .28, .44, 0),
			Vector3(.10, 1.08, .10),
			barrier,
			Vector3(0, 0, .38 if i % 2 == 0 else -.38)
		)
		primitive("orb", "725e3a", Vector3(-.42 + i * .28, .32, 0), Vector3(.42, .4, .38), barrier)
	return root


func build_landmarks(layout: Dictionary) -> void:
	for key in ["campfire", "merchant", "exit", "treasure"]:
		if key == "exit" and bool(layout.get("exit_under_body", false)):
			continue
		var cell: Vector2i = layout.get(key, Vector2i(-100, -100))
		if cell.x < 0:
			continue
		var point := Vector3(cell.x + .5, 0, cell.y + .5)
		if theme == "crypt" and key in ["campfire", "exit", "treasure"]:
			match key:
				"campfire":
					primitive("trunk", "4a4553", point + Vector3(0, .3, 0), Vector3(.5, .6, .5))
					primitive("trunk", "5f5a69", point + Vector3(0, .66, 0), Vector3(.9, .14, .9))
					primitive(
						"orb",
						"8fd7ff",
						point + Vector3(0, .88, 0),
						Vector3(.42, .6, .42),
						null,
						Vector3.ZERO,
						true
					)
					primitive(
						"orb",
						"e6f7ff",
						point + Vector3(0, .8, .05),
						Vector3(.2, .32, .2),
						null,
						Vector3.ZERO,
						true
					)
					light(point + Vector3(0, 1.3, 0), Color("8fd7ff"), 4.0)
				"exit":
					primitive("box", "07050a", point + Vector3(0, .29, 0), Vector3(1.9, .04, 1.6))
					for i in 4:
						primitive(
							"box",
							"3d3946",
							point + Vector3(0, .24 - i * .16, -.6 + i * .32),
							Vector3(1.6, .12, .3)
						)
					for x in [-1.05, 1.05]:
						primitive(
							"box", "5f5a69", point + Vector3(x, .35, 0), Vector3(.22, .7, 1.7)
						)
					primitive(
						"orb",
						"a58cff",
						point + Vector3(0, .2, 0),
						Vector3(.8, .12, .6),
						null,
						Vector3.ZERO,
						true
					)
					light(point + Vector3(0, .8, 0), Color("a58cff"), 3.5)
				"treasure":
					primitive("box", "5f5a69", point + Vector3(0, .2, 0), Vector3(.95, .4, .95))
					primitive("box", "767180", point + Vector3(0, .42, 0), Vector3(.75, .06, .75))
					light(point + Vector3(0, 1, 0), Color("d9bb71"), 2.0)
			continue
		match key:
			"campfire":
				for i in 8:
					var angle := i * TAU / 8
					primitive(
						"orb",
						"7c7c65",
						point + Vector3(cos(angle) * .45, .12, sin(angle) * .45),
						Vector3(.26, .23, .22)
					)
				for i in 3:
					primitive(
						"trunk",
						"503821",
						point + Vector3(0, .13, 0),
						Vector3(.15, .74, .15),
						null,
						Vector3(PI * .5, i * PI / 3, 0)
					)
				primitive(
					"orb",
					"ffb94e",
					point + Vector3(0, .4, 0),
					Vector3(.37, .74, .34),
					null,
					Vector3.ZERO,
					true
				)
				primitive(
					"orb",
					"ffe2a0",
					point + Vector3(0, .32, .08),
					Vector3(.18, .4, .2),
					null,
					Vector3.ZERO,
					true
				)
				light(point + Vector3(0, .8, 0), Color("ffb65e"), 3.0)
			"exit":
				for x in [-.7, .7]:
					primitive("trunk", "737861", point + Vector3(x, 1, 0), Vector3(.45, 2, .45))
				primitive("box", "8b8e6c", point + Vector3(0, 1.95, 0), Vector3(1.9, .35, .55))
				for i in 3:
					primitive(
						"box",
						"4b5d46",
						point + Vector3(0, .04 + i * .07, .55 - i * .23),
						Vector3(1.15, .10, .28)
					)
				primitive(
					"orb",
					"91ca81",
					point + Vector3(0, 1.5, 0),
					Vector3(.25, .30, .18),
					null,
					Vector3.ZERO,
					true
				)
			"merchant":
				for x in [-.75, .75]:
					primitive(
						"trunk", "765233", point + Vector3(x, .9, -.35), Vector3(.10, 1.8, .10)
					)
				primitive(
					"box",
					"ad945b",
					point + Vector3(0, 1.8, -.35),
					Vector3(1.7, .12, 1.1),
					null,
					Vector3(.12, 0, 0)
				)
				primitive("box", "785335", point + Vector3(0, .4, .45), Vector3(1.5, .8, .45))
			"treasure":
				primitive("trunk", "85846a", point + Vector3(0, .18, 0), Vector3(.85, .36, .85))
				light(point + Vector3(0, 1, 0), Color("d9bb71"), 2.0)
	# Remove old static landmark images while leaving their triggers/glows intact.
	for child in world.dungeon.actor_layer.get_children():
		if child.name in ["Campfire", "RootGate"]:
			for visual in child.get_children():
				if visual is Sprite2D:
					visual.visibility_layer = world.HIDDEN_LAYER


## A shop ware: a low plinth (a crypt slab in the crypt) with the item floating
## and turning above it. The bobbing runs in ware_bob().
func ware_stand(point: Vector3, texture: Texture2D, glow: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Ware"
	root.position = point
	add_child(root, true)
	if theme == "crypt":
		primitive("box", "5f5a69", Vector3(0, .12, 0), Vector3(.62, .24, .62), root)
		primitive("box", "767180", Vector3(0, .26, 0), Vector3(.5, .05, .5), root)
	else:
		primitive("trunk", "6b4a2e", Vector3(0, .12, 0), Vector3(.62, .24, .62), root)
		primitive("trunk", "9a7448", Vector3(0, .25, 0), Vector3(.56, .03, .56), root)
	var icon := Sprite3D.new()
	icon.name = "Icon"
	icon.texture = texture
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	icon.shaded = false
	icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if texture != null:
		icon.pixel_size = 0.95 / maxf(1.0, float(maxi(texture.get_width(), texture.get_height())))
	icon.position = Vector3(0, .95, 0)
	root.add_child(icon)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, .9, 0)
	lamp.light_color = glow
	lamp.omni_range = 1.6
	lamp.light_energy = 0.9
	root.add_child(lamp)
	return root


func ware_bob(stand: Node3D, time: float) -> void:
	var icon := stand.get_node_or_null("Icon") as Node3D
	if icon != null:
		icon.position.y = .95 + sin(time * 2.4 + stand.position.x) * .07


func light(point: Vector3, color: Color, radius: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = point
	lamp.light_color = color
	lamp.omni_range = radius
	lamp.light_energy = 1.4
	add_child(lamp)


func colossus(point: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "HeartwoodColossus"
	root.position = point + Vector3(0, 0, -GOLIATH_BACK)
	root.scale = Vector3.ONE * GOLIATH_SCALE
	add_child(root)
	primitive("trunk", "57432f", Vector3(0, 2.1, 0), Vector3(4.5, 4.2, 3.3), root)
	for side in [-1.0, 1.0]:
		primitive(
			"trunk",
			"655036",
			Vector3(side * 2.5, 2.7, .3),
			Vector3(.8, 3.1, .8),
			root,
			Vector3(0, 0, side * -.9)
		)
		primitive(
			"orb",
			"a7d96e",
			Vector3(side * .7, 2.8, 1.5),
			Vector3(.34, .21, .14),
			root,
			Vector3.ZERO,
			true
		)
	for i in 5:
		primitive(
			"orb",
			["3b5a32", "51713c", "608042"][i % 3],
			Vector3((i - 2) * .9, 4.1 + sin(i) * .4, -.5),
			Vector3(2.7, 2.4, 2.7),
			root
		)
	for i in 7:
		var angle := PI * i / 6
		primitive(
			"trunk",
			"655036",
			Vector3(cos(angle) * 2.2, .25, sin(angle) * 1.9),
			Vector3(.5, 2.3, .5),
			root,
			Vector3(.9, angle, 0)
		)
	return root


## The glow of the way on, deep in the fallen guardian's body.
func hidden_way(point: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "HiddenWay"
	root.position = point
	add_child(root)
	var colour := Color("a58cff") if theme == "crypt" else Color("91ca81")
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 1.2, .8)
	lamp.light_color = colour
	lamp.omni_range = 5.0
	lamp.light_energy = 2.2
	root.add_child(lamp)
	primitive(
		"orb",
		colour.to_html(false),
		Vector3(0, .12, 1.0),
		Vector3(2.2, .08, 1.6),
		root,
		Vector3.ZERO,
		true
	)
	return root


## A standing ring of light with a mirage of the Hearth inside it: walk in to
## go home. The mirage is the real tavern room, seen through a small camera.
func tavern_portal(point: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "TavernPortal"
	root.position = point
	add_child(root)
	# Face the camera (it looks from the south-east).
	root.rotation.y = atan2(10.0, 18.0)
	# Big enough to walk into, leaning back a little towards the high camera.
	var frame := Node3D.new()
	frame.name = "Frame"
	frame.scale = Vector3.ONE * 1.45
	frame.rotation.x = -0.45
	root.add_child(frame)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.0
	torus.outer_radius = 1.22
	torus.rings = 28
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = mat("ffd27a", true)
	ring.rotation.x = PI * .5
	ring.position.y = 1.35
	ring.name = "Ring"
	frame.add_child(ring)
	for x in [-1.0, 1.0]:
		primitive("box", "8a7a5a", Vector3(x * .9, .1, 0), Vector3(.5, .2, .5), root)
	var view := SubViewport.new()
	view.name = "Mirage"
	view.size = Vector2i(220, 220)
	view.own_world_3d = true
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(view)
	var room_scene: PackedScene = load(TAVERN_ROOM) if ResourceLoader.exists(TAVERN_ROOM) else null
	if room_scene != null:
		view.add_child(room_scene.instantiate())
	var sky := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("2a1a10")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("ffcf94")
	environment.ambient_light_energy = 0.9
	sky.environment = environment
	view.add_child(sky)
	var hearth := OmniLight3D.new()
	hearth.position = Vector3(0, 2.6, 0)
	hearth.light_color = Color("ffb65e")
	hearth.omni_range = 14.0
	hearth.light_energy = 2.0
	view.add_child(hearth)
	var eye := Camera3D.new()
	eye.fov = 62.0
	view.add_child(eye)
	eye.position = Vector3(0, 2.7, 5.2)
	eye.look_at_from_position(eye.position, Vector3(0, 1.0, -2.5))
	eye.current = true
	var disc := MeshInstance3D.new()
	disc.name = "Glimpse"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	disc.mesh = quad
	disc.position.y = 1.35
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, cull_disabled; uniform sampler2D view_tex : source_color; void fragment(){ vec2 uv = UV; uv.x += sin(uv.y*18.0+TIME*2.2)*0.012; uv.y += sin(uv.x*14.0+TIME*1.7)*0.010; float d = distance(UV,vec2(0.5)); vec3 c = texture(view_tex,uv).rgb; c = mix(c, vec3(1.0,0.85,0.55), 0.18+0.08*sin(TIME*2.0)); ALBEDO = c; ALPHA = smoothstep(0.5,0.40,d)*0.92; }"
	var glimpse := ShaderMaterial.new()
	glimpse.shader = shader
	glimpse.set_shader_parameter("view_tex", view.get_texture())
	disc.material_override = glimpse
	frame.add_child(disc)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 1.4, .6)
	glow.light_color = Color("ffcf7a")
	glow.omni_range = 4.0
	glow.light_energy = 1.6
	root.add_child(glow)
	# Render the room a couple of times once it has loaded, then leave it still.
	var view_ref: WeakRef = weakref(view)
	get_tree().create_timer(0.4).timeout.connect(
		func():
			var later: SubViewport = view_ref.get_ref()
			if later != null:
				later.render_target_update_mode = SubViewport.UPDATE_ONCE
	)
	return root


func flush() -> void:
	for key in batches:
		var record: Dictionary = batches[key]
		var transforms: Array = record.transforms
		if transforms.is_empty():
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = record.mesh
		multi.instance_count = transforms.size()
		for i in transforms.size():
			multi.set_instance_transform(i, transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.name = "ForestBatch_" + key
		instance.multimesh = multi
		add_child(instance)
		record.transforms = []


func stump(point: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "FallenHeartwood"
	root.position = point + Vector3(0, 0, -GOLIATH_BACK)
	root.scale = Vector3.ONE * GOLIATH_SCALE
	add_child(root)
	primitive("trunk", "57432f", Vector3(0, .55, 0), Vector3(4.2, 1.1, 3.2), root)
	primitive("trunk", "9b8554", Vector3(0, 1.10, 0), Vector3(3.8, .04, 2.8), root)
	primitive("orb", "302c20", Vector3(0, 1.13, 0), Vector3(1.7, .035, 1.3), root)
	for x in [-1.7, 1.7]:
		primitive("orb", "557543", Vector3(x, .4, .9), Vector3(1.0, .65, .9), root)
	return root
