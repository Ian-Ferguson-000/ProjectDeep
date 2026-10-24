extends Node2D
class_name TavernExpansions

## The walkable areas beyond the Hearth's main hall.
##
## West: the Lodgings wing, one alcove per room the building has space for. Built
## rooms show a bed in the room's quality, the resident's nameplate and their
## furnishings; unbuilt spaces are empty plots. The wing grows with the Hearth.
## East: the Training Yard, an outdoor yard with dummies and racks. It is boarded
## up until the Hearth's first expansion and gains equipment at later tiers.
##
## Doorways are cut into the hall's side walls. Everything here is rebuilt from the
## campaign whenever the Hearth changes (Tavern._refresh_wings).

const WALL_SECTION := preload("res://scenes/components/TavernWallSection.tscn")
const PROP := preload("res://scenes/components/TavernProp.tscn")
const FLOOR_TEXTURE := preload("res://assets/pixel_art/Tavern Floor Revised.png")
const WALL_STRAIGHT := preload("res://assets/tavern/wall_kit/wall_straight.png")
const WALL_LANTERN := preload("res://assets/tavern/wall_kit/wall_lantern.png")
const SIDE_LEFT := preload("res://assets/tavern/wall_kit/side_wall_left_v2.png")
const SIDE_RIGHT := preload("res://assets/tavern/wall_kit/side_wall_right_v2.png")
const PILLAR := preload("res://assets/tavern/wall_kit/support_pillar.png")
const FOREST_SHEET := preload("res://assets/pixel_art/forest_art/forest tiles.png")
const TREES := preload("res://assets/pixel_art/FreePack.png")
const DECOR := {
	"rug":preload("res://assets/tavern/decor/hearth_rug.png"),
	"barrels":preload("res://assets/tavern/decor/ale_barrels.png"),
	"crates":preload("res://assets/tavern/decor/supply_crates.png"),
	"firewood":preload("res://assets/tavern/decor/firewood.png"),
	"banner":preload("res://assets/tavern/decor/flame_banner.png"),
	"rack":preload("res://assets/tavern/decor/weapon_rack.png"),
	"board":preload("res://assets/tavern/decor/notice_board.png"),
	"sideboard":preload("res://assets/tavern/decor/serving_sideboard.png"),
}

## The main hall, matching TavernWorld's floor and walls.
const HALL_FLOOR := Rect2(256,192,1152,704)
const HALL_BOUNDS := Rect2(0,-48,1664,1008)
const DOOR_TOP := 492.0
const DOOR_BOTTOM := 628.0
const FLOOR_TINT := Color(0.78,0.68,0.58)
const ALCOVE_WIDTH := 184.0
const ALCOVE_DEPTH := 232.0
const YARD_UNLOCK_TIER := 1
const QUALITY_COLORS := {"cot":Color("c9a45c"),"bunk":Color("8a3f32"),"chamber":Color("355f8c"),"suite":Color("6b3f8e")}

var campaign: CampaignState
var world: Node2D
var lodging_floor := Rect2()
var yard_floor := Rect2()
var yard_open := false
var ground: Node2D

func build(target_world: Node2D, source: CampaignState) -> void:
	world = target_world
	campaign = source
	name = "Expansions"
	y_sort_enabled = true
	ground = Node2D.new()
	ground.name = "ExpansionGround"
	ground.z_index = -29
	ground.draw.connect(_draw_ground)
	add_child(ground)
	HearthLodging.ensure_rooms(campaign)
	HearthLodging.sync_occupants(campaign)
	yard_open = int(campaign.establishment_tier) >= YARD_UNLOCK_TIER
	var slots := HearthLodging.room_limit(campaign)
	var width := slots * ALCOVE_WIDTH + 160.0
	lodging_floor = Rect2(160.0 - width, HALL_FLOOR.position.y, width, HALL_FLOOR.size.y)
	var yard_width := 1000.0 + 200.0 * maxi(0,int(campaign.establishment_tier) - YARD_UNLOCK_TIER)
	yard_floor = Rect2(1504.0, 132.0, yard_width, 820.0)
	_cut_side_walls()
	_build_lodgings()
	if yard_open: _build_yard()
	else: _build_locked_yard_door()
	_build_navigation()
	ground.queue_redraw()

# ---------------------------------------------------------------- where people walk

## Walkable navigation for every open area, joined to the main hall's navigation
## through the doorways, plus activity spots the tavern's adventurers can visit:
## Wander in the corridor and yard, Train at the yard's dummies and targets, and
## Rest by their own bed.
func _build_navigation() -> void:
	var door := Rect2(150.0,DOOR_TOP + 14.0,HALL_FLOOR.position.x - 150.0,DOOR_BOTTOM - DOOR_TOP - 28.0)
	_nav_rect(door)
	var corridor := Rect2(lodging_floor.position.x + 30.0,HALL_FLOOR.position.y + ALCOVE_DEPTH,150.0 - (lodging_floor.position.x + 30.0),860.0 - (HALL_FLOOR.position.y + ALCOVE_DEPTH))
	_nav_rect(corridor)
	var corridor_left := lodging_floor.position.x + 80.0
	for index in HearthLodging.room_limit(campaign):
		var cell := Rect2(corridor_left + index * ALCOVE_WIDTH,HALL_FLOOR.position.y,ALCOVE_WIDTH,ALCOVE_DEPTH)
		var room: Dictionary = campaign.rooms[index] if index < campaign.rooms.size() else {}
		if room.is_empty(): continue
		_nav_rect(Rect2(cell.position.x + 98.0,cell.position.y + 120.0,58.0,ALCOVE_DEPTH - 120.0))
		var occupant := String(room.get("occupant",""))
		if not occupant.is_empty(): _anchor("Rest",Vector2(cell.position.x + 127.0,cell.position.y + 168.0),occupant)
	var x := corridor.position.x + 90.0
	while x < 60.0:
		_anchor("Wander",Vector2(x,700.0 + float(int(x) % 3) * 40.0))
		x += 260.0
	if not yard_open: return
	_nav_rect(Rect2(HALL_FLOOR.end.x,DOOR_TOP + 14.0,yard_floor.position.x + 20.0 - HALL_FLOOR.end.x,DOOR_BOTTOM - DOOR_TOP - 28.0))
	_nav_rect(Rect2(yard_floor.position.x + 20.0,yard_floor.position.y + 40.0,yard_floor.size.x - 60.0,yard_floor.size.y - 80.0))
	var ring_center := Vector2(yard_floor.position.x + 330.0,yard_floor.position.y + 470.0)
	_anchor("Train",ring_center + Vector2(-90,40))
	_anchor("Train",ring_center + Vector2(90,40))
	_anchor("Train",ring_center + Vector2(0,-70))
	_anchor("Wander",Vector2(yard_floor.position.x + 560.0,yard_floor.position.y + 300.0))
	_anchor("Wander",Vector2(yard_floor.position.x + 200.0,yard_floor.end.y - 160.0))
	if int(campaign.establishment_tier) >= 2:
		for index in 3: _anchor("Train",Vector2(yard_floor.end.x - 420.0,yard_floor.position.y + 230.0 + index * 150.0))
	if int(campaign.establishment_tier) >= 3:
		_anchor("Train",Vector2(yard_floor.position.x + 700.0,yard_floor.end.y - 70.0))

func _nav_rect(rect: Rect2) -> void:
	var region := NavigationRegion2D.new()
	var polygon := NavigationPolygon.new()
	polygon.vertices = PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	polygon.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_polygon = polygon
	add_child(region)

func _anchor(kind: String, position_value: Vector2, occupant: String = "") -> Marker2D:
	var marker := Marker2D.new()
	marker.name = "%sSpot" % kind
	marker.position = position_value
	marker.set_meta("activity_kind",kind)
	if not occupant.is_empty(): marker.set_meta("occupant",occupant)
	add_child(marker)
	return marker

## The area the camera may show: the hall plus every open area.
func camera_bounds() -> Rect2:
	var bounds := HALL_BOUNDS
	bounds = bounds.merge(Rect2(lodging_floor.position.x - 150.0,-48.0,lodging_floor.size.x + 150.0,1008.0))
	if yard_open: bounds = bounds.merge(Rect2(yard_floor.position.x,yard_floor.position.y - 90.0,yard_floor.size.x + 140.0,yard_floor.size.y + 150.0))
	return bounds

# ---------------------------------------------------------------- doorways

func _cut_side_walls() -> void:
	var walls := world.get_node_or_null("Walls/SideWalls")
	if walls == null: return
	for record in [["WestRun",SIDE_LEFT,64.25],["EastRun",SIDE_RIGHT,-64.25]]:
		var section := walls.get_node_or_null(String(record[0])) as TavernWallSection
		if section == null: continue
		section.section_enabled = false
		var texture: Texture2D = record[1]
		var scale_value: Vector2 = section.visual_scale
		var height := texture.get_height() * scale_value.y
		var top := section.position.y - height * 0.5
		var left := section.position.x - texture.get_width() * scale_value.x * 0.5
		for span in [[top,DOOR_TOP],[DOOR_BOTTOM,top + height]]:
			var from_y: float = span[0]; var to_y: float = span[1]
			var piece := Sprite2D.new()
			piece.texture = texture
			piece.centered = false
			piece.region_enabled = true
			piece.region_rect = Rect2(0,(from_y - top) / scale_value.y,texture.get_width(),(to_y - from_y) / scale_value.y)
			piece.scale = scale_value
			piece.position = Vector2(left,from_y)
			var holder := Node2D.new()
			holder.position = Vector2(0,to_y)
			piece.position -= holder.position
			holder.add_child(piece)
			add_child(holder)
			_wall_body(Vector2(section.position.x + float(record[2]),(from_y + to_y) * 0.5),Vector2(38,to_y - from_y))
		# Lanterns either side of the opening.
		for y in [DOOR_TOP - 14.0,DOOR_BOTTOM + 6.0]:
			var lamp := ColorRect.new()
			lamp.color = Color(1.0,0.72,0.32,0.85)
			lamp.size = Vector2(8,8)
			lamp.position = Vector2(section.position.x + float(record[2]) - 4.0,y)
			lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(lamp)

func _wall_body(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = center
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	add_child(body)

func _wall_run(texture: Texture2D, x_from: float, x_to: float, y: float, base_scale: Vector2, collision_offset_y: float, tags: String) -> void:
	var span := x_to - x_from
	var piece_width := texture.get_width() * base_scale.x
	var count := maxi(1,int(ceil(span / piece_width)))
	var fitted := Vector2(base_scale.x * span / (count * piece_width),base_scale.y)
	for index in count:
		var section := WALL_SECTION.instantiate() as TavernWallSection
		section.section_id = "%s_%d" % [tags,index]
		section.section_texture = texture if index % 3 != 1 or texture != WALL_STRAIGHT else WALL_LANTERN
		section.visual_scale = fitted if section.section_texture == texture else Vector2(fitted.x * texture.get_width() / WALL_LANTERN.get_width(),fitted.y)
		section.collision_size = Vector2(span / count,34)
		section.collision_offset = Vector2(0,collision_offset_y)
		section.position = Vector2(x_from + (index + 0.5) * span / count,y)
		add_child(section)

# ---------------------------------------------------------------- lodgings

func _build_lodgings() -> void:
	var left := lodging_floor.position.x
	_wall_run(WALL_STRAIGHT,left,160.0,73.0,Vector2.ONE,119.0,"lodging_back")
	_wall_run(WALL_STRAIGHT,left,160.0,800.0,Vector2(0.72,0.8),95.2,"lodging_front")
	var end_wall := WALL_SECTION.instantiate() as TavernWallSection
	end_wall.section_id = "lodging_west_end"
	end_wall.section_texture = SIDE_LEFT
	end_wall.visual_scale = Vector2(0.5,0.51841)
	end_wall.collision_size = Vector2(38,704)
	end_wall.collision_offset = Vector2(64.25,0)
	end_wall.position = Vector2(left - 64.25,544)
	add_child(end_wall)
	var slots := HearthLodging.room_limit(campaign)
	var corridor_left := left + 80.0
	for index in slots:
		var cell := Rect2(corridor_left + index * ALCOVE_WIDTH,HALL_FLOOR.position.y,ALCOVE_WIDTH,ALCOVE_DEPTH)
		var room: Dictionary = campaign.rooms[index] if index < campaign.rooms.size() else {}
		_build_alcove(cell,room,index)
	# Partition posts between alcoves.
	for index in slots + 1:
		var post := Sprite2D.new()
		post.texture = PILLAR
		post.scale = Vector2(0.32,0.62)
		var x := corridor_left + index * ALCOVE_WIDTH
		post.position = Vector2(x,HALL_FLOOR.position.y + ALCOVE_DEPTH - 80.0)
		var holder := Node2D.new(); holder.position = Vector2(x,HALL_FLOOR.position.y + ALCOVE_DEPTH); post.position -= holder.position; holder.add_child(post); add_child(holder)
		_wall_body(Vector2(x,HALL_FLOOR.position.y + ALCOVE_DEPTH * 0.5),Vector2(16,ALCOVE_DEPTH))
	# The corridor: a long runner, lanterns, and the lodgings board.
	var rug_x := corridor_left + ALCOVE_WIDTH
	while rug_x < 120.0:
		var rug := Sprite2D.new(); rug.texture = DECOR.rug; rug.scale = Vector2(0.24,0.2); rug.position = Vector2(rug_x,590); rug.modulate = Color(0.92,0.86,0.82); ground.add_child(rug)
		rug_x += ALCOVE_WIDTH * 2.0
	var decor_x := corridor_left + ALCOVE_WIDTH * 1.5
	var decor_ids := ["barrels","crates","firewood","sideboard"]
	var decor_index := 0
	while decor_x < 60.0:
		_decor(String(decor_ids[decor_index % decor_ids.size()]),Vector2(decor_x,860),0.13,true)
		decor_x += ALCOVE_WIDTH * 2.0; decor_index += 1
	var board := _prop("lodgings_board","Lodgings ledger","Rooms, upgrades and furnishings for the company.",DECOR.board,Vector2(150.0 - 40.0,735),Vector2(0.16,0.16))
	board.name = "LodgingsBoard"
	_decor("barrels",Vector2(left + 60.0,470),0.15)
	var title := _label("LODGINGS",Vector2(lodging_floor.get_center().x - 120.0,440),22,Color("e0b870"),240)
	title.name = "LodgingsTitle"

func _build_alcove(cell: Rect2, room: Dictionary, index: int) -> void:
	var center := cell.get_center()
	if room.is_empty():
		var plot := _prop("lodgings_plot","Empty plot · room %d" % (index + 1),"There is space here for another room. Build one from the Lodgings ledger.",null,Vector2(center.x,cell.end.y - 20.0),Vector2.ONE)
		plot.name = "Plot_%d" % (index + 1)
		var marker := _label("Space for a room",Vector2(cell.position.x,center.y - 10.0),13,Color(0.75,0.66,0.52,0.75),cell.size.x)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return
	var quality := String(room.get("quality","cot"))
	var occupant := campaign.character(String(room.get("occupant","")))
	var bed := AlcoveBed.new()
	bed.quality = quality
	bed.blanket = QUALITY_COLORS.get(quality,Color("8a3f32"))
	bed.position = Vector2(cell.position.x + 52.0,cell.position.y + 92.0)
	add_child(bed)
	var furnishings: Array = Array(room.get("furnishings",[]))
	for slot in furnishings.size():
		var item := FurnishingVisual.new()
		item.furnishing_id = String(furnishings[slot])
		item.position = Vector2(cell.position.x + 112.0 + (slot % 2) * 40.0,cell.position.y + 70.0 + int(slot / 2) * 58.0)
		add_child(item)
	if HearthLodging.quality_index(quality) >= 2:
		var rug := Sprite2D.new(); rug.texture = DECOR.rug; rug.scale = Vector2(0.16,0.12); rug.position = Vector2(center.x,cell.end.y - 36.0); ground.add_child(rug)
	var name_text := occupant.display_name if occupant != null else "Vacant"
	var plate := _label("%s\n%s" % [name_text,String(HearthLodging.quality(quality).get("name",""))],Vector2(cell.position.x,cell.end.y - 58.0),14,Color("f3e3b4") if occupant != null else Color(0.8,0.72,0.58,0.8),cell.size.x)
	plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var prompt := "Room %d · %s" % [index + 1,name_text]
	var prop := _prop("lodgings_room",prompt,"%s's room." % name_text if occupant != null else "An empty room, ready for a new recruit.",null,Vector2(center.x,cell.end.y - 10.0),Vector2.ONE)
	prop.name = "Room_%d" % (index + 1)

# ---------------------------------------------------------------- training yard

func _build_locked_yard_door() -> void:
	var boards := LockedDoor.new()
	boards.position = Vector2(1472.0,(DOOR_TOP + DOOR_BOTTOM) * 0.5)
	add_child(boards)
	_wall_body(Vector2(1408.0,(DOOR_TOP + DOOR_BOTTOM) * 0.5),Vector2(38,DOOR_BOTTOM - DOOR_TOP))
	var gate := _prop("training_yard_locked","Boarded door","The training yard lies beyond these boards. Expand the Hearth to the %s to open it." % String(HearthCatalog.tier(YARD_UNLOCK_TIER).name),null,Vector2(1380.0,(DOOR_TOP + DOOR_BOTTOM) * 0.5 + 40.0),Vector2.ONE)
	gate.name = "LockedYardDoor"

func _build_yard() -> void:
	var tier := int(campaign.establishment_tier)
	var r := yard_floor
	var fence := YardFence.new()
	fence.rect = r
	fence.gate_top = DOOR_TOP
	fence.gate_bottom = DOOR_BOTTOM
	add_child(fence)
	# Boundary: fence on three sides, the tavern wall on the fourth.
	_wall_body(Vector2(r.get_center().x,r.position.y),Vector2(r.size.x,30))
	_wall_body(Vector2(r.get_center().x,r.end.y),Vector2(r.size.x,30))
	_wall_body(Vector2(r.end.x,r.get_center().y),Vector2(30,r.size.y))
	_wall_body(Vector2(1508.0,(r.position.y + DOOR_TOP) * 0.5),Vector2(30,DOOR_TOP - r.position.y))
	_wall_body(Vector2(1508.0,(DOOR_BOTTOM + r.end.y) * 0.5),Vector2(30,r.end.y - DOOR_BOTTOM))
	# Trees beyond the fence.
	var rng := RandomNumberGenerator.new(); rng.seed = 4401
	var tree_regions := [Rect2(0,135,100,130),Rect2(100,270,60,114),Rect2(196,270,60,114)]
	var x := r.position.x + 30.0
	while x < r.end.x + 60.0:
		_tree(Vector2(x,r.position.y - 30.0 + rng.randf_range(-10,10)),tree_regions[rng.randi_range(0,2)],rng.randf_range(0.8,1.05))
		x += rng.randf_range(80,120)
	var y := r.position.y + 40.0
	while y < r.end.y + 40.0:
		_tree(Vector2(r.end.x + 60.0 + rng.randf_range(-8,8),y),tree_regions[rng.randi_range(0,2)],rng.randf_range(0.8,1.05))
		y += rng.randf_range(90,130)
	# Sparring ring and dummies.
	var ring := SandPatch.new()
	ring.radius = Vector2(190,110)
	ring.position = Vector2(r.position.x + 330.0,r.position.y + 470.0)
	ground.add_child(ring)
	for offset in [Vector2(-90,-20),Vector2(90,-20)]:
		var dummy := YardDummy.new(); dummy.scale = Vector2.ONE * 1.6; dummy.position = ring.position + offset; add_child(dummy)
		_wall_body(dummy.position + Vector2(0,8),Vector2(26,16))
	var post := _prop("training_post","Training Yard","Drill your adventurers. Each can train once a day.",null,ring.position + Vector2(0,60),Vector2.ONE)
	post.name = "TrainingPost"
	_decor("rack",Vector2(r.position.x + 140.0,r.position.y + 150.0),0.24,true)
	_decor("rack",Vector2(r.position.x + 330.0,r.position.y + 150.0),0.24,true)
	_decor("barrels",Vector2(r.position.x + 560.0,r.position.y + 140.0),0.16,true)
	_decor("crates",Vector2(r.position.x + 120.0,r.end.y - 80.0),0.15,true)
	_decor("firewood",Vector2(r.position.x + 250.0,r.end.y - 70.0),0.14,true)
	_label("TRAINING YARD",Vector2(r.position.x + 220.0,r.position.y + 250.0),22,Color("f3e3b4"),260)
	if tier >= 2:
		# Archery range along the far side.
		var lane := SandPatch.new(); lane.radius = Vector2(70,230); lane.color = Color(0.68,0.6,0.42,0.55); lane.position = Vector2(r.end.x - 300.0,r.get_center().y); ground.add_child(lane)
		for index in 3:
			var target := YardTarget.new(); target.scale = Vector2.ONE * 1.4; target.position = Vector2(r.end.x - 300.0,r.position.y + 220.0 + index * 150.0); add_child(target)
			_wall_body(target.position + Vector2(0,10),Vector2(30,14))
		_label("ARCHERY",Vector2(r.end.x - 360.0,r.position.y + 120.0),16,Color("e8d49a"),120)
	if tier >= 3:
		# A weights corner and a banner for the Hearth's finest.
		for index in 3:
			var weights := FurnishingVisual.new(); weights.furnishing_id = "iron_dumbbells"; weights.scale = Vector2.ONE * 1.4; weights.position = Vector2(r.position.x + 640.0 + index * 60.0,r.end.y - 120.0); add_child(weights)
		_decor("banner",Vector2(r.position.x + 700.0,r.position.y + 150.0),0.2,true)
		_decor("sideboard",Vector2(r.position.x + 820.0,r.end.y - 110.0),0.15,true)

func _tree(position_value: Vector2, region: Rect2, scale_value: float) -> void:
	var tree := Sprite2D.new()
	tree.texture = TREES
	tree.region_enabled = true
	tree.region_rect = region
	tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tree.scale = Vector2.ONE * scale_value * 1.4
	tree.offset = Vector2(0,-region.size.y * 0.5)
	tree.position = position_value
	add_child(tree)

# ---------------------------------------------------------------- shared helpers

func _decor(id: String, position_value: Vector2, scale_value: float, solid: bool = false) -> Sprite2D:
	var texture: Texture2D = DECOR[id]
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2.ONE * scale_value
	sprite.offset = Vector2(0,-texture.get_height() * 0.5)
	sprite.position = position_value
	add_child(sprite)
	if solid: _wall_body(position_value + Vector2(0,-10),Vector2(texture.get_width() * scale_value * 0.8,20))
	return sprite

func _prop(prop_id: String, display: String, text_value: String, texture: Texture2D, position_value: Vector2, scale_value: Vector2) -> TavernProp:
	var prop := PROP.instantiate() as TavernProp
	prop.prop_id = prop_id
	prop.display_name = display
	prop.interaction_text = text_value
	prop.position = position_value
	if texture != null:
		prop.prop_texture = texture
		prop.visual_scale = scale_value
		prop.visual_offset = Vector2(0,-texture.get_height() * scale_value.y * 0.5)
	add_child(prop)
	return prop

func _label(text_value: String, position_value: Vector2, size: int, color: Color, width: float) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = position_value
	label.size = Vector2(width,size * 2.6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_outline_color",Color(0,0,0,0.8))
	label.add_theme_constant_override("outline_size",4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 5
	add_child(label)
	return label

func _draw_ground() -> void:
	# Lodgings floor, and floor under both doorway openings.
	_tile_floor(Rect2(lodging_floor.position.x,lodging_floor.position.y,lodging_floor.size.x + 96.0,lodging_floor.size.y))
	_tile_floor(Rect2(128.0,DOOR_TOP - 12.0,128.0,DOOR_BOTTOM - DOOR_TOP + 24.0))
	_tile_floor(Rect2(1408.0,DOOR_TOP - 12.0,128.0 if yard_open else 64.0,DOOR_BOTTOM - DOOR_TOP + 24.0))
	# Alcove floors are a shade warmer than the corridor.
	var corridor_left := lodging_floor.position.x + 80.0
	for index in HearthLodging.room_limit(campaign):
		var built := index < campaign.rooms.size()
		ground.draw_rect(Rect2(corridor_left + index * ALCOVE_WIDTH + 8.0,lodging_floor.position.y,ALCOVE_WIDTH - 16.0,ALCOVE_DEPTH - 8.0),Color(0.35,0.2,0.1,0.18) if built else Color(0.0,0.0,0.0,0.32))
	if not yard_open: return
	var grass_scale := 1.5
	var step := 32.0 * grass_scale
	var y := yard_floor.position.y - 60.0
	while y < yard_floor.end.y + 120.0:
		var x := yard_floor.position.x
		while x < yard_floor.end.x + 160.0:
			ground.draw_texture_rect_region(FOREST_SHEET,Rect2(x,y,step,step),SlasherForestTerrainArtRegion.GRASS,Color(0.78,0.82,0.62))
			x += step
		y += step
	# A trodden path from the doorway into the yard.
	ground.draw_rect(Rect2(1500.0,DOOR_TOP + 18.0,220.0,DOOR_BOTTOM - DOOR_TOP - 36.0),Color(0.74,0.6,0.36,0.75))

func _tile_floor(rect: Rect2) -> void:
	var y := rect.position.y
	while y < rect.end.y:
		var x := rect.position.x
		while x < rect.end.x:
			var w := minf(32.0,rect.end.x - x); var h := minf(32.0,rect.end.y - y)
			ground.draw_texture_rect_region(FLOOR_TEXTURE,Rect2(x,y,w,h),Rect2(128,0,w,h),FLOOR_TINT)
			x += 32.0
		y += 32.0

# ---------------------------------------------------------------- small drawn pieces

## Grass region on the forest sheet (shared with the forest terrain art).
class SlasherForestTerrainArtRegion:
	const GRASS := Rect2(208,80,32,32)

class AlcoveBed extends Node2D:
	var quality := "cot"
	var blanket := Color("8a3f32")
	func _draw() -> void:
		var frame := Color("4a2c18")
		match quality:
			"cot":
				draw_rect(Rect2(-30,-40,60,92),Color("b8954e"))
				draw_rect(Rect2(-30,-40,60,92),Color("7a5a2c"),false,2.0)
				draw_rect(Rect2(-22,-34,44,16),Color("e7dcc2"))
			_:
				draw_rect(Rect2(-36,-48,72,108),frame)
				draw_rect(Rect2(-32,-42,64,98),Color("e9dfca"))
				draw_rect(Rect2(-24,-38,48,18),Color("f7f1e2"))
				draw_rect(Rect2(-32,-14,64,70),blanket)
				draw_rect(Rect2(-32,-14,64,6),blanket.lightened(0.25))
				if quality == "suite":
					draw_rect(Rect2(-40,-58,80,8),Color("c9a24a"))
					draw_rect(Rect2(-40,-58,4,118),Color("c9a24a"))
					draw_rect(Rect2(36,-58,4,118),Color("c9a24a"))
				if quality in ["chamber","suite"]:
					draw_rect(Rect2(-32,40,64,4),Color("d8b25a"))

class FurnishingVisual extends Node2D:
	var furnishing_id := ""
	func _draw() -> void:
		draw_circle(Vector2(0,12),15.0,Color(0,0,0,0.25))
		match furnishing_id:
			"training_dummy":
				draw_rect(Rect2(-3,-20,6,34),Color("6b4426")); draw_line(Vector2(-14,-6),Vector2(14,-6),Color("c9a86a"),5.0); draw_circle(Vector2(0,-22),8.0,Color("d8bd84")); draw_circle(Vector2(0,-4),8.0,Color("b28a52"))
			"iron_dumbbells":
				draw_line(Vector2(-10,4),Vector2(10,4),Color("8c8c8c"),3.0); draw_circle(Vector2(-11,4),6.0,Color("3c3c40")); draw_circle(Vector2(11,4),6.0,Color("3c3c40"))
			"weapon_rack","armor_stand":
				draw_rect(Rect2(-14,-18,28,30),Color("6b4426"),false,3.0); draw_line(Vector2(-6,-22),Vector2(-6,10),Color("c8ccd4"),3.0); draw_line(Vector2(6,-22),Vector2(6,10),Color("c8ccd4"),3.0)
			"archery_target":
				draw_circle(Vector2(0,-6),14.0,Color("f1e6cc")); draw_circle(Vector2(0,-6),10.0,Color("c0392b")); draw_circle(Vector2(0,-6),5.0,Color("f1e6cc")); draw_circle(Vector2(0,-6),2.0,Color("c0392b"))
			"lockpick_board":
				draw_rect(Rect2(-14,-16,28,24),Color("7a5230")); for i in 6: draw_circle(Vector2(-9 + (i % 3) * 9,-10 + int(i / 3) * 10),2.5,Color("b9b9c2"))
			"crystal_ball":
				draw_rect(Rect2(-8,2,16,8),Color("5a3a22")); draw_circle(Vector2(0,-6),10.0,Color("7fb6e8")); draw_circle(Vector2(-3,-9),3.0,Color("e6f4ff"))
			"spellbook_stack":
				draw_rect(Rect2(-12,0,24,7),Color("7d2f2f")); draw_rect(Rect2(-10,-7,22,7),Color("2f4f7d")); draw_rect(Rect2(-11,-14,20,7),Color("3d6b3a"))
			"prayer_altar":
				draw_rect(Rect2(-12,-8,24,18),Color("8d8a86")); draw_rect(Rect2(-2,-18,4,10),Color("efe6c8")); draw_circle(Vector2(0,-20),3.0,Color("ffb347"))
			"herb_garden":
				draw_rect(Rect2(-14,0,28,10),Color("8b5a33")); for i in 4: draw_circle(Vector2(-10 + i * 7,-3),5.0,Color("5d9c4a"))
			"bonded_perch":
				draw_line(Vector2(0,10),Vector2(0,-18),Color("6b4426"),3.0); draw_line(Vector2(-10,-18),Vector2(10,-18),Color("6b4426"),3.0); draw_circle(Vector2(4,-24),5.0,Color("b07a3c"))
			"tall_mirror":
				draw_rect(Rect2(-9,-24,18,34),Color("c9a24a")); draw_rect(Rect2(-6,-21,12,28),Color("bfe0ef"))
			"lute":
				draw_circle(Vector2(-3,2),8.0,Color("b0743a")); draw_line(Vector2(2,-2),Vector2(12,-18),Color("6b4426"),3.0); draw_circle(Vector2(-3,2),2.0,Color("3c2412"))
			"war_table":
				draw_rect(Rect2(-16,-8,32,18),Color("6b4426")); draw_rect(Rect2(-12,-5,24,12),Color("e5d3a1")); draw_circle(Vector2(4,0),2.0,Color("c0392b"))
			"hearthstone_brazier":
				draw_rect(Rect2(-10,0,20,10),Color("3c3c40")); draw_circle(Vector2(0,-2),7.0,Color("ff8c2a")); draw_circle(Vector2(0,-6),4.0,Color("ffd27a"))
			"starglass_orrery":
				draw_arc(Vector2(0,-6),11.0,0,TAU,24,Color("d8b25a"),2.0); draw_arc(Vector2(0,-6),7.0,0.6,TAU + 0.6,24,Color("d8b25a"),2.0); draw_circle(Vector2(0,-6),3.0,Color("ffd27a")); draw_rect(Rect2(-6,6,12,5),Color("5a3a22"))
			_:
				draw_rect(Rect2(-10,-10,20,20),Color("7a5230"))

class YardDummy extends Node2D:
	func _draw() -> void:
		draw_circle(Vector2(0,10),18.0,Color(0,0,0,0.28))
		draw_rect(Rect2(-4,-34,8,44),Color("6b4426"))
		draw_line(Vector2(-22,-18),Vector2(22,-18),Color("c9a86a"),7.0)
		draw_circle(Vector2(0,-40),11.0,Color("d8bd84"))
		draw_circle(Vector2(0,-14),13.0,Color("b28a52"))
		draw_arc(Vector2(0,-14),10.0,0,TAU,20,Color("8a6a3a"),2.0)

class YardTarget extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-3,-6,6,20),Color("6b4426"))
		draw_circle(Vector2(0,-22),20.0,Color("d9c69a"))
		draw_circle(Vector2(0,-22),15.0,Color("f1e6cc"))
		draw_circle(Vector2(0,-22),10.0,Color("c0392b"))
		draw_circle(Vector2(0,-22),5.0,Color("f1e6cc"))
		draw_circle(Vector2(0,-22),2.0,Color("c0392b"))

class SandPatch extends Node2D:
	var radius := Vector2(160,90)
	var color := Color(0.76,0.62,0.38,0.8)
	func _draw() -> void:
		var points := PackedVector2Array()
		for i in 48: points.append(Vector2(cos(TAU * i / 48.0) * radius.x,sin(TAU * i / 48.0) * radius.y))
		draw_colored_polygon(points,color)
		var rim := points.duplicate(); rim.append(points[0])
		draw_polyline(rim,color.darkened(0.25),3.0)

class YardFence extends Node2D:
	var rect := Rect2()
	var gate_top := 0.0
	var gate_bottom := 0.0
	func _draw() -> void:
		var wood := Color("7a4f2a"); var dark := Color("4e3018")
		var top := rect.position.y; var bottom := rect.end.y; var left := rect.position.x; var right := rect.end.x
		for y_line in [top,bottom]:
			draw_line(Vector2(left,y_line - 10),Vector2(right,y_line - 10),wood,5.0)
			draw_line(Vector2(left,y_line + 4),Vector2(right,y_line + 4),wood,5.0)
			var x := left
			while x <= right:
				draw_rect(Rect2(x - 4,y_line - 22,8,32),dark); x += 60.0
		draw_line(Vector2(right,top),Vector2(right,bottom),wood,5.0)
		var y := top
		while y <= bottom:
			draw_rect(Rect2(right - 4,y - 16,8,26),dark); y += 60.0
		for span in [[top,gate_top],[gate_bottom,bottom]]:
			draw_line(Vector2(left + 4,span[0]),Vector2(left + 4,span[1]),wood,5.0)

class LockedDoor extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-64,-70,128,140),Color("2a1a10"))
		for i in 5: draw_rect(Rect2(-60,-62 + i * 27,120,20),Color("6e4626").darkened(0.08 * (i % 2)))
		draw_line(Vector2(-58,-50),Vector2(58,50),Color("4a2c18"),8.0)
		draw_line(Vector2(-58,50),Vector2(58,-50),Color("4a2c18"),8.0)
