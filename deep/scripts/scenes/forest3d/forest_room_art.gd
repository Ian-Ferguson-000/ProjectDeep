extends Node3D
## Deterministic low-poly forest kit. One map cell = one metre. Shared static
## primitives are instanced by material; destructible props remain independent.
var world: Node3D
var rng := RandomNumberGenerator.new()
var materials: Dictionary = {}
var batches: Dictionary = {}
var dimensions := Vector2.ZERO

func mat(color: String, glow: bool = false) -> StandardMaterial3D:
	var key := color + str(glow)
	if materials.has(key): return materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = 0.94
	if glow:
		material.emission_enabled = true
		material.emission = Color(color)
		material.emission_energy_multiplier = 1.4
	materials[key] = material
	return material

func primitive(kind: String, color: String, point: Vector3, size: Vector3, parent: Node3D = null, rotation: Vector3 = Vector3.ZERO, glow: bool = false) -> MeshInstance3D:
	var key := kind + color + str(glow)
	var mesh: PrimitiveMesh
	if batches.has(key): mesh = batches[key].mesh
	else:
		match kind:
			"orb":
				var sphere := SphereMesh.new()
				sphere.radius = 0.5; sphere.height = 1.0; sphere.radial_segments = 7; sphere.rings = 3
				mesh = sphere
			"trunk":
				var cylinder := CylinderMesh.new()
				cylinder.top_radius = 0.38; cylinder.bottom_radius = 0.5; cylinder.height = 1.0; cylinder.radial_segments = 7
				mesh = cylinder
			_:
				var cube := BoxMesh.new()
				cube.size = Vector3.ONE
				mesh = cube
		mesh.material = mat(color,glow)
		batches[key] = {"mesh":mesh,"transforms":[]}
	var transform := Transform3D(Basis.from_euler(rotation).scaled(size),point)
	if parent == null:
		batches[key].transforms.append(transform)
		return null
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.transform = transform
	parent.add_child(instance)
	return instance

func build(layout: Dictionary) -> void:
	dimensions = Vector2(layout.width,layout.height)
	rng.seed = hash(str(world.dungeon.run_state.get_current_floor_seed())+":"+str(world.dungeon.room_id))
	var cells: Dictionary = layout.cells
	var paths: Dictionary = layout.get("path_cells",{})
	var cobbles: Dictionary = layout.get("cobble_cells",{})
	var water: Dictionary = layout.get("water_cells",{})
	var thicket: Dictionary = layout.get("thicket_cells",{})
	var body: Dictionary = layout.get("colossus_cells",{})
	var all := cells.duplicate()
	all.merge(thicket); all.merge(body)
	for value in all:
		var cell: Vector2i = value
		var point := Vector3(cell.x+0.5,-0.32,cell.y+0.5)
		primitive("box","4a3d2c",point,Vector3(1.005,0.64,1.005))
		var color := "536c3c"
		if thicket.has(cell): color = "314c32"
		elif paths.has(cell): color = "9a8052"
		elif cobbles.has(cell): color = "6e7964"
		else: color = ["526b3b","546d3d","506a3a"][posmod(int(cell.x/3)+int(cell.y/3),3)]
		primitive("box",color,point+Vector3(0,0.31,0),Vector3(1.005,0.035,1.005))
		if cobbles.has(cell):
			for i in 3:
				primitive("orb","8b927b",point+Vector3(rng.randf_range(-.3,.3),.36,rng.randf_range(-.3,.3)),Vector3(.40,.12,.28),null,Vector3(0,rng.randf()*TAU,0))
		elif cells.has(cell) and not paths.has(cell) and rng.randf()<0.35:
			grass(point+Vector3(0,.34,0))
	for value in water:
		var cell: Vector2i = value
		primitive("box","233d37",Vector3(cell.x+.5,-.44,cell.y+.5),Vector3(1.005,.40,1.005))
		primitive("box","487e78",Vector3(cell.x+.5,-.18,cell.y+.5),Vector3(1.005,.04,1.005))
		if rng.randf()<.45:
			primitive("box","80aaa0",Vector3(cell.x+.5,-.151,cell.y+.5),Vector3(.42,.008,.018),null,Vector3(0,.2,0))
	# Each blocked edge has a visible bank. Higher canopy is kept to the rear;
	# foreground growth is cut down so it never hides combat or door thresholds.
	for value in thicket:
		var cell: Vector2i = value
		var point := Vector3(cell.x+.5,0,cell.y+.5)
		var near := cell.y > dimensions.y*.65
		primitive("orb","46543b",point+Vector3(0,.22,0),Vector3(1.05,.65,.95))
		if (cell.x+cell.y)%2 == 0:
			var height := rng.randf_range(3.5,4.8) if not near else rng.randf_range(.8,1.3)
			if cell.x<2 or cell.x>dimensions.x-3: height = minf(height,2.3)
			tree(point,height)
		else:
			primitive("orb","3e6036",point+Vector3(0,.5,0),Vector3(1.25,.95,1.15))
	# Non-room tutorial/interlude layouts still receive an honest boundary.
	if thicket.is_empty():
		var boundary := {}
		for value in cells:
			for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
				var cell: Vector2i = Vector2i(value)+direction
				if not cells.has(cell): boundary[cell] = true
		for value in boundary:
			var cell: Vector2i = value
			primitive("orb","415936",Vector3(cell.x+.5,.35,cell.y+.5),Vector3(1.05,1.0,1.05))
	for record in layout.get("decorations",[]):
		var point: Vector3 = world.to_world(world.dungeon._world(Vector2i(record.cell)))
		var kind := String(record.kind)
		if kind.contains("mushroom"):
			mushrooms(point)
		elif kind.contains("rock"):
			primitive("orb","7d856a",point+Vector3(0,.09,0),Vector3(.35,.2,.27))
		else: grass(point)
	build_landmarks(layout)
	flush()

func grass(point: Vector3) -> void:
	for i in 3:
		var offset := Vector3(rng.randf_range(-.35,.35),.12,rng.randf_range(-.35,.35))
		primitive("box","819259",point+offset,Vector3(.045,rng.randf_range(.16,.28),.10),null,Vector3(0,rng.randf()*PI,.18))

func mushrooms(point: Vector3) -> void:
	for i in 3:
		var offset := Vector3(rng.randf_range(-.23,.23),0,rng.randf_range(-.23,.23))
		primitive("trunk","c6ba8a",point+offset+Vector3(0,.12,0),Vector3(.07,.24,.07))
		primitive("orb","c18e52",point+offset+Vector3(0,.24,0),Vector3(.24,.12,.24))

func tree(point: Vector3, height: float, parent: Node3D = null) -> void:
	primitive("trunk","60452f",point+Vector3(0,height*.38,0),Vector3(.36,height*.76,.36),parent)
	for i in 3:
		var angle := i*TAU/3.0
		primitive("trunk","60452f",point+Vector3(cos(angle)*.17,.09,sin(angle)*.17),Vector3(.18,.50,.18),parent,Vector3(.65,angle,0))
	if height<1.5:
		primitive("orb","4f713e",point+Vector3(0,height*.70,0),Vector3(1.3,.8,1.2),parent)
	else:
		for i in 3:
			var angle := i*TAU/3.0+.4
			primitive("orb",["3d6035","52753d","638348"][i],point+Vector3(cos(angle)*.45,height*.72+i*.14,sin(angle)*.4),Vector3(1.7,1.65,1.65),parent)
		primitive("orb","66874a",point+Vector3(.08,height-.35,0),Vector3(1.25,1.1,1.2),parent)

func make_prop(kind: String, point: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = kind.to_pascal_case()
	root.position = point
	add_child(root)
	match kind:
		"tree_large","tree_small","tree": tree(Vector3.ZERO,2.7,root)
		"chest":
			primitive("box","755034",Vector3(0,.25,0),Vector3(.74,.5,.52),root)
			var lid := primitive("box","9a7042",Vector3(0,.53,0),Vector3(.78,.13,.56),root)
			lid.name = "Lid"
			for x in [-.24,.24]: primitive("box","c4a765",Vector3(x,.32,.275),Vector3(.065,.48,.025),root)
			primitive("box","e4c97a",Vector3(0,.41,.285),Vector3(.10,.14,.035),root)
		_:
			primitive("orb","7b8270",Vector3(0,.30,0),Vector3(.85,.7,.7),root,Vector3(.1,.5,.1))
			primitive("orb","617452",Vector3(-.19,.48,.1),Vector3(.47,.24,.37),root)
	return root

func open_chest(root: Node3D) -> void:
	var lid := root.get_node_or_null("Lid") as Node3D
	if lid != null:
		lid.position = Vector3(0,.74,-.22)
		lid.rotation.x = -1.1

func door(point: Vector3, direction: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Passage_"+direction
	root.position = point
	if direction in ["east","west"]: root.rotation.y = PI*.5
	add_child(root)
	for x in [-.68,.68]:
		primitive("trunk","6b654a",Vector3(x,.62,0),Vector3(.27,1.24,.31),root)
		primitive("orb","a5bd75",Vector3(x,1.31,0),Vector3(.16,.16,.16),root,Vector3.ZERO,true)
	var barrier := Node3D.new()
	barrier.name = "Brambles"
	root.add_child(barrier)
	for i in 4:
		primitive("trunk","624433",Vector3(-.42+i*.28,.44,0),Vector3(.10,1.08,.10),barrier,Vector3(0,0,.38 if i%2==0 else -.38))
		primitive("orb","725e3a",Vector3(-.42+i*.28,.32,0),Vector3(.42,.4,.38),barrier)
	return root

func build_landmarks(layout: Dictionary) -> void:
	for key in ["campfire","merchant","exit","treasure"]:
		var cell: Vector2i = layout.get(key,Vector2i(-100,-100))
		if cell.x<0: continue
		var point := Vector3(cell.x+.5,0,cell.y+.5)
		match key:
			"campfire":
				for i in 8:
					var angle := i*TAU/8
					primitive("orb","7c7c65",point+Vector3(cos(angle)*.45,.12,sin(angle)*.45),Vector3(.26,.23,.22))
				for i in 3: primitive("trunk","503821",point+Vector3(0,.13,0),Vector3(.15,.74,.15),null,Vector3(PI*.5,i*PI/3,0))
				primitive("orb","ffb94e",point+Vector3(0,.4,0),Vector3(.37,.74,.34),null,Vector3.ZERO,true)
				primitive("orb","ffe2a0",point+Vector3(0,.32,.08),Vector3(.18,.4,.2),null,Vector3.ZERO,true)
				light(point+Vector3(0,.8,0),Color("ffb65e"),3.0)
			"exit":
				for x in [-.7,.7]: primitive("trunk","737861",point+Vector3(x,1,0),Vector3(.45,2,.45))
				primitive("box","8b8e6c",point+Vector3(0,1.95,0),Vector3(1.9,.35,.55))
				for i in 3: primitive("box","4b5d46",point+Vector3(0,.04+i*.07,.55-i*.23),Vector3(1.15,.10,.28))
				primitive("orb","91ca81",point+Vector3(0,1.5,0),Vector3(.25,.30,.18),null,Vector3.ZERO,true)
			"merchant":
				for x in [-.75,.75]: primitive("trunk","765233",point+Vector3(x,.9,-.35),Vector3(.10,1.8,.10))
				primitive("box","ad945b",point+Vector3(0,1.8,-.35),Vector3(1.7,.12,1.1),null,Vector3(.12,0,0))
				primitive("box","785335",point+Vector3(0,.4,.45),Vector3(1.5,.8,.45))
			"treasure":
				primitive("trunk","85846a",point+Vector3(0,.18,0),Vector3(.85,.36,.85))
				light(point+Vector3(0,1,0),Color("d9bb71"),2.0)
	# Remove old static landmark images while leaving their triggers/glows intact.
	for child in world.dungeon.actor_layer.get_children():
		if child.name in ["Campfire","RootGate"]:
			for visual in child.get_children():
				if visual is Sprite2D: visual.visibility_layer = world.HIDDEN_LAYER

func light(point: Vector3, color: Color, radius: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = point; lamp.light_color = color; lamp.omni_range = radius; lamp.light_energy = 1.4
	add_child(lamp)

func colossus(point: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "HeartwoodColossus"
	root.position = point
	add_child(root)
	primitive("trunk","57432f",Vector3(0,2.1,0),Vector3(4.5,4.2,3.3),root)
	for side in [-1.0,1.0]:
		primitive("trunk","655036",Vector3(side*2.5,2.7,.3),Vector3(.8,3.1,.8),root,Vector3(0,0,side*-.9))
		primitive("orb","a7d96e",Vector3(side*.7,2.8,1.5),Vector3(.34,.21,.14),root,Vector3.ZERO,true)
	for i in 5:
		primitive("orb",["3b5a32","51713c","608042"][i%3],Vector3((i-2)*.9,4.1+sin(i)*.4,-.5),Vector3(2.7,2.4,2.7),root)
	for i in 7:
		var angle := PI*i/6
		primitive("trunk","655036",Vector3(cos(angle)*2.2,.25,sin(angle)*1.9),Vector3(.5,2.3,.5),root,Vector3(.9,angle,0))
	return root

func flush() -> void:
	for key in batches:
		var record: Dictionary = batches[key]
		var transforms: Array = record.transforms
		if transforms.is_empty(): continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = record.mesh
		multi.instance_count = transforms.size()
		for i in transforms.size(): multi.set_instance_transform(i,transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.name = "ForestBatch_"+key
		instance.multimesh = multi
		add_child(instance)
		record.transforms = []

func stump(point: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "FallenHeartwood"
	root.position = point
	add_child(root)
	primitive("trunk","57432f",Vector3(0,.55,0),Vector3(4.2,1.1,3.2),root)
	primitive("trunk","9b8554",Vector3(0,1.10,0),Vector3(3.8,.04,2.8),root)
	primitive("orb","302c20",Vector3(0,1.13,0),Vector3(1.7,.035,1.3),root)
	for x in [-1.7,1.7]: primitive("orb","557543",Vector3(x,.4,.9),Vector3(1.0,.65,.9),root)
	return root
