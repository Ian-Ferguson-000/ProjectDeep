extends Node3D
## Campaign-driven 3D lodgings and training yard. Dimensions/anchors use the
## existing expansion plan so room ownership and activity reservations stay shared.
var world: Node3D
var materials:Dictionary={}

func _material(color: Color) -> StandardMaterial3D:
	var key:=color.to_html()
	if materials.has(key):return materials[key]
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=color
	mat.roughness=0.85
	materials[key]=mat
	return mat

func box(title: String, center: Vector3, size_value: Vector3, color: Color, solid: bool = true) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new()
	mesh.name=title
	var cube:=BoxMesh.new()
	cube.size=size_value
	cube.material=_material(color)
	mesh.mesh=cube
	mesh.position=center
	add_child(mesh)
	if solid:
		var body:=StaticBody3D.new()
		var shape:=CollisionShape3D.new()
		var volume:=BoxShape3D.new()
		volume.size=size_value
		shape.shape=volume
		body.add_child(shape)
		mesh.add_child(body)
	return mesh

func plan_box(title:String, point:Vector2, size_value:Vector2, height:float, color:Color, base:float=0.05,solid:bool=true) -> MeshInstance3D:
	var location:Vector3=world.to_room(point)
	location.y=base+height*0.5
	return box(title,location,Vector3(size_value.x/64.0,height,size_value.y/64.0),color,solid)

func text(value:String, point:Vector3, font_size:int=30) -> void:
	var label:=Label3D.new()
	label.text=value
	label.position=point
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size=font_size
	label.pixel_size=0.008
	label.modulate=Color("ffe4ad")
	label.outline_size=7
	add_child(label)

func build(expansion:TavernExpansions,campaign:CampaignState) -> void:
	var timber:=Color("63422b")
	var oak:=Color("a57648")
	var plaster:=Color("c6ab7b")
	var stone:=Color("79776b")
	var r:=expansion.lodging_floor
	plan_box("LodgingsFloor",r.get_center(),r.size,0.22,oak,-0.17)
	planks(r)
	plan_box("WestPassage",Vector2(208,560),Vector2(120,144),0.22,oak,-0.17)
	for y in [192.0,896.0]:plan_box("LodgingBoundary",Vector2(r.get_center().x,y),Vector2(r.size.x,18),3.2 if y==192 else 0.75,plaster)
	plan_box("WestBoundary",Vector2(r.position.x,544),Vector2(18,704),3.2,plaster)
	# Seal both sides of the short connector to the hall.
	for y in [484.0,636.0]:plan_box("PassageRail",Vector2(208,y),Vector2(120,12),1.1,timber)
	for span in [[192.0,484.0],[636.0,896.0]]:
		plan_box("LodgingEastBoundary",Vector2(160,(span[0]+span[1])/2),Vector2(16,span[1]-span[0]),1.3,plaster)
	var left:=r.position.x+80.0
	for index in expansion.accessible_room_count:
		var cell:=Rect2(left+index*184,192,184,232)
		plan_box("RoomPartition",Vector2(cell.position.x,308),Vector2(10,232),2.5,timber)
		var occupied:bool=index<campaign.rooms.size()
		if not occupied:
			plan_box("UnbuiltRoomPlot",cell.get_center(),Vector2(158,206),0.012,Color("665542"),0.06,false)
			text("ROOM %d\nSpace to build"%(index+1),world.to_room(Vector2(cell.get_center().x,402))+Vector3.UP*0.6,22)
			continue
		var room:Dictionary=campaign.rooms[index]
		var quality:=String(room.get("quality","cot"))
		var rank:=HearthLodging.quality_index(quality)
		var bed_point:=cell.position+Vector2(52,92)
		var bed_size:=Vector2(68 if rank<2 else 84,124)
		plan_box("BedFrame",bed_point,bed_size,0.38,timber)
		plan_box("Mattress",bed_point,bed_size-Vector2(6,6),0.15,Color("e3d3aa"),0.43)
		var colors:Dictionary=TavernExpansions.QUALITY_COLORS
		plan_box("Blanket",bed_point+Vector2(0,14),bed_size-Vector2(8,38),0.04,colors.get(quality,Color("8a3f32")),0.59,false)
		plan_box("Pillow",bed_point-Vector2(0,42),Vector2(48,22),0.09,Color("f0e5c5"),0.59,false)
		plan_box("Headboard",bed_point-Vector2(0,64),Vector2(bed_size.x,8),0.95,timber)
		if rank==1:
			plan_box("UpperBunk",bed_point,bed_size,0.16,timber,1.45)
			plan_box("UpperBunkBlanket",bed_point,bed_size-Vector2(6,8),0.08,colors[quality],1.61,false)
		var items:Array=room.get("furnishings",[])
		for slot in items.size():
			var pos:=cell.position+Vector2(120+(slot%2)*38,60+int(slot/2)*54)
			furnishing(String(items[slot]),pos)
		var occupant:CharacterRecord=campaign.character(String(room.get("occupant","")))
		var title:=occupant.display_name if occupant!=null else "Vacant"
		text("%s · %s"%[title,quality.capitalize()],world.to_room(Vector2(cell.get_center().x,407))+Vector3.UP*0.55,22)
	plan_box("FinalRoomPartition",Vector2(left+expansion.accessible_room_count*184,308),Vector2(10,232),2.5,timber)
	text("LODGINGS",world.to_room(Vector2(r.get_center().x,540))+Vector3.UP*2.8)
	plan_box("LodgingsLedgerStand",Vector2(110,735),Vector2(42,32),0.95,timber)
	plan_box("LedgerBook",Vector2(110,735),Vector2(36,24),0.06,Color("b39d66"),1.0,false)
	# Entrance porch supports the shared arrival/departure endpoints beyond the door.
	box("EntrancePorch",Vector3(0,-0.06,6.25),Vector3(3.2,0.22,1.65),stone)
	box("PorchSouthRail",Vector3(0,0.55,7.08),Vector3(3.3,1.1,0.12),timber)
	for x in [-1.65,1.65]:box("PorchSideRail",Vector3(x,0.55,6.25),Vector3(0.12,1.1,1.7),timber)
	# Visible hall fixtures for shared Armory/Merchant management interactions.
	box("ArmoryRack",Vector3(8.35,0.75,3.0),Vector3(.30,1.5,1.5),timber)
	for z in [2.5,3.0,3.5]:
		box("PracticeSword",Vector3(8.08,1.10,z),Vector3(.07,1.1,.08),Color("a5adb1"),false)
		box("SwordGuard",Vector3(8.08,.77,z),Vector3(.10,.08,.34),Color("baa35e"),false)
	box("MerchantSupplies",Vector3(8.3,.42,1.8),Vector3(.72,.84,.75),oak)
	if not expansion.yard_open:
		box("LockedYardGate",Vector3(9,1.25,0),Vector3(.30,2.5,2.0),timber)
		text("TRAINING YARD\nExpand the Hearth to open",Vector3(8.7,2.6,0),22)
		return
	r=expansion.yard_floor
	plan_box("YardGround",r.get_center(),r.size,0.22,Color("68764b"),-0.17)
	plan_box("EastPassage",Vector2(1456,560),Vector2(128,144),0.22,oak,-0.17)
	for y in [484.0,636.0]:plan_box("EastPassageRail",Vector2(1456,y),Vector2(128,12),1.1,timber)
	for y in [r.position.y,r.end.y]:
		for x in range(int(r.position.x),int(r.end.x),96):
			plan_box("FencePost",Vector2(x,y),Vector2(10,10),1.25,timber)
		plan_box("FenceRail",Vector2(r.get_center().x,y),Vector2(r.size.x,8),0.85,timber)
	plan_box("YardEastFence",Vector2(r.end.x,r.get_center().y),Vector2(10,r.size.y),1.25,timber)
	for span in [[r.position.y,484.0],[636.0,r.end.y]]:
		plan_box("YardWestFence",Vector2(r.position.x,(span[0]+span[1])/2),Vector2(10,span[1]-span[0]),1.25,timber)
	var ring:=Vector2(r.position.x+330,r.position.y+470)
	plan_box("SparringSand",ring,Vector2(390,230),0.012,Color("b39b70"),0.06,false)
	for offset in [Vector2(-90,-20),Vector2(90,-20)]:
		var pos:Vector2=ring+offset
		plan_box("TrainingDummyPost",pos,Vector2(12,12),1.75,timber)
		plan_box("DummyTorso",pos,Vector2(34,24),0.60,Color("b8a179"),0.8)
		plan_box("DummyArms",pos,Vector2(90,10),0.12,timber,1.25)
		plan_box("DummyHead",pos,Vector2(22,22),0.30,Color("b8a179"),1.45)
	text("TRAINING YARD",world.to_room(ring+Vector2(0,160))+Vector3.UP*2.0)
	if expansion.accessible_tier>=2:
		for i in 3:
			var pos:=Vector2(r.end.x-300,r.position.y+220+i*150)
			plan_box("TargetStand",pos,Vector2(12,12),1.6,timber)
			plan_box("ArcheryTarget",pos,Vector2(12,68),0.85,Color("d5c7a0"),.8)
			plan_box("TargetBullseye",pos-Vector2(7,0),Vector2(3,22),0.28,Color("a63b2f"),1.08,false)
	if expansion.accessible_tier>=3:
		for i in 3:plan_box("TrainingWeights",Vector2(r.position.x+640+i*60,r.end.y-120),Vector2(45,18),0.24,Color("4d5356"))
	# Equipment at the northern fence, clear of training activity anchors.
	for x in [140.0,330.0]:plan_box("YardEquipmentRack",Vector2(r.position.x+x,r.position.y+150),Vector2(100,24),1.25,timber)

func planks(rect:Rect2) -> void:
	var x_count:=ceili(rect.size.x/180.0)
	var z_count:=ceili(rect.size.y/24.0)
	var shared:=BoxMesh.new()
	shared.size=Vector3.ONE
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color("a57648")
	material.vertex_color_use_as_albedo=true
	material.roughness=.85
	shared.material=material
	var multimesh:=MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_3D
	multimesh.use_colors=true
	multimesh.mesh=shared
	multimesh.instance_count=x_count*z_count
	for z in z_count:
		for x in x_count:
			var width:=minf(180,rect.size.x-x*180)
			var depth:=minf(24,rect.size.y-z*24)
			var point:Vector3=world.to_room(rect.position+Vector2(x*180+width*.5,z*24+depth*.5))
			point.y=.066
			var transform:=Transform3D(Basis.from_scale(Vector3((width-1)/64,.025,(depth-.8)/64)),point)
			multimesh.set_instance_transform(z*x_count+x,transform)
			var shade:=.82+float((x*7+z*3)%6)*.035
			multimesh.set_instance_color(z*x_count+x,Color(shade,shade,shade))
	var instance:=MultiMeshInstance3D.new()
	instance.name="LodgingsPlankFloor"
	instance.multimesh=multimesh
	add_child(instance)

func furnishing(id:String,point:Vector2) -> void:
	var first_child:=get_child_count()
	var origin:Vector3=world.to_room(point)
	var root:=Node3D.new()
	root.name="Furnishing_"+id
	root.position=origin
	add_child(root)
	# Named, recognisable low-poly shapes share the room palette.
	var wood:=Color("795235")
	var iron:=Color("586168")
	var brass:=Color("b69b50")
	match id:
		"training_dummy","armor_stand","bonded_perch":
			box("Stand",origin+Vector3(0,.6,0),Vector3(.10,1.2,.10),wood)
			box("Crossbar",origin+Vector3(0,1.0,0),Vector3(.55,.10,.10),wood,false)
			if id!="bonded_perch":box("Torso",origin+Vector3(0,.95,0),Vector3(.30,.5,.2),iron if id=="armor_stand" else Color("b6a178"),false)
		"weapon_rack","lockpick_board","tall_mirror":
			box("Frame",origin+Vector3(0,.65,0),Vector3(.52,1.3,.16),wood)
			box("Face",origin+Vector3(0,.68,.09),Vector3(.43,1.1,.03),Color("acc6cb") if id=="tall_mirror" else iron,false)
		"iron_dumbbells":
			box("WeightGrip",origin+Vector3(0,.16,0),Vector3(.58,.07,.07),iron)
			for x in [-.23,.23]:box("WeightPlate",origin+Vector3(x,.16,0),Vector3(.1,.27,.27),iron,false)
		"spellbook_stack":
			for i in 4:box("Book",origin+Vector3(.02*(i%2),.06+i*.1,0),Vector3(.40,.08,.28),[Color("714331"),Color("375867"),Color("5d6640"),Color("884d43")][i],false)
		"herb_garden":
			box("Planter",origin+Vector3(0,.24,0),Vector3(.52,.4,.32),wood)
			for x in [-.17,0,.17]:orb("Herbs",origin+Vector3(x,.55,0),.16,Color("627d42"))
		"lute":
			orb("LuteBody",origin+Vector3(0,.30,0),.22,Color("b78a51"))
			box("LuteNeck",origin+Vector3(0,.66,0),Vector3(.09,.55,.06),wood,false)
		"archery_target":
			box("TargetLeg",origin+Vector3(0,.55,0),Vector3(.1,1.1,.1),wood)
			orb("Target",origin+Vector3(0,1,0),.30,Color("c7ae7b"))
			orb("Bullseye",origin+Vector3(0,1,.25),.10,Color("9e4230"))
		_:
			box("FurnitureBase",origin+Vector3(0,.35,0),Vector3(.48,.70,.38),wood)
			match id:
				"crystal_ball":orb("Crystal",origin+Vector3(0,.93,0),.23,Color("81c8d5"))
				"hearthstone_brazier":orb("BrazierGlow",origin+Vector3(0,.95,0),.22,Color("ffac47"))
				"starglass_orrery":
					orb("OrrerySun",origin+Vector3(0,1.02,0),.14,brass)
					for x in [-.22,.22]:orb("OrreryPlanet",origin+Vector3(x,.9,.1),.07,Color("729aae"))
				"prayer_altar":box("AltarCloth",origin+Vector3(0,.72,0),Vector3(.5,.04,.4),Color("e2d6b3"),false)
				"war_table":box("CampaignMap",origin+Vector3(0,.72,0),Vector3(.46,.025,.32),Color("c6be89"),false)

	for child in get_children().slice(first_child+1):child.reparent(root,true)

func orb(title:String,point:Vector3,radius:float,color:Color) -> void:
	var mesh:=MeshInstance3D.new()
	mesh.name=title
	var sphere:=SphereMesh.new()
	sphere.radius=radius
	sphere.height=radius*2
	sphere.radial_segments=10
	sphere.rings=5
	sphere.material=_material(color)
	mesh.mesh=sphere
	mesh.position=point
	add_child(mesh)
