extends "res://scripts/slasher/slasher_mage_kit_base.gd"

const GEAR_ID := "winterglass_codex"
const ACTIONS := {"basic":"Rime Needle","special":"Fracture","defensive":"Icebook Wall","movement":"Skating Retreat"}
const TUNING := {
	"basic":{"cooldown":0.18,"resource_cost":0,"power_stat":"spell_power","damage_coefficient":5.0,"projectile_range":400.0,"projectile_speed":900.0,"hit_radius":24.0,"visual":"aether","visual_scale":1.25,"tint":"#99e8ff","animation_lock":0.12},
	"special":{"cooldown":0.9,"resource_cost":1,"power_stat":"spell_power","damage_coefficient":20.0,"animation_lock":0.12},
	"defensive":{"cooldown":0.65,"resource_cost":0,"mitigation":0.0,"animation_lock":0.12},
	"movement":{"cooldown":0.65,"resource_cost":0,"animation_lock":0.1}
}
var chills: Dictionary = {}
var fractures: Array[Dictionary] = []
var wall: Dictionary = {}
var wall_body: StaticBody2D
var wall_masks: Dictionary = {}
var blocked_cells: Array[Vector2i] = []
var wall_pathfinder: SlasherGridPathfinder
var frozen_fields: Array[Dictionary] = []
const TERRAIN_DURATION := 5.0
const SKATING_SPEED := 1.4

static func gear() -> GearData:
	return GearData.create(GEAR_ID,"Winterglass Codex",3,false,0,"fracture","Cold kills shatter into radial needles. Fracture and Skating Retreat freeze five-second terrain that speeds your movement. Raise an enemy-only ice wall.","mage","icebook_wall")
func kit_id() -> String:return GEAR_ID
func element() -> String:return "ice"
func action_name(slot: String) -> String:return String(ACTIONS.get(slot,slot))
func raw_tuning(slot: String) -> Dictionary:return TUNING.get(slot,{})

func perform(slot: String, result: Dictionary) -> Dictionary:
	match slot:
		"basic":actor._spawn_projectile(attack_for(slot,"Needle",true),false)
		"special":fractures.append({"origin":actor.global_position,"direction":actor.aim_direction,"left":0.16,"attack":attack_for(slot,"Fracture")})
		"defensive":
			if not place_wall():result.started=false;result.failure="The wall needs a clear space in front of you."
		"movement":
			var start := actor.global_position
			result=safe_move(start-actor.aim_direction*300,result)
			if result.started:frozen_fields.append({"kind":"strip","a":start,"b":actor.global_position,"left":TERRAIN_DURATION})
	return result

func on_frozen_field(point: Vector2, field: Dictionary) -> bool:
	if field.kind=="strip":return Geometry2D.get_closest_point_to_segment(point,field.a,field.b).distance_to(point)<=24
	var offset := point-Vector2(field.a)
	return offset.length()<=270 and (offset.is_zero_approx() or offset.normalized().dot(field.direction)>=cos(deg_to_rad(50))) and clear_line(field.a,point)

func movement_speed_multiplier() -> float:
	for field in frozen_fields:
		if float(field.left)>0 and on_frozen_field(actor.global_position,field):return SKATING_SPEED
	return 1.0

func on_cold_kill(origin: Vector2) -> void:
	flash(origin,90,"burst",0.5)
	var shards := secondary_copy(attack_for("basic","Shatter"))
	shards.damage=maxi(1,int(round(actor._scaled_damage(tuning("basic"))*2.4)))
	shards.range=220.0;shards.visual_scale=0.8;shards.hit_radius=20.0
	for index in 8:
		actor._spawn_projectile(shards,false,Vector2.RIGHT.rotated(TAU*index/8.0),origin)

func on_primary_hit(target: SlasherEnemy, attack: Dictionary) -> void:
	if String(attack.get("damage_source",""))!="Needle":return
	var id := target.get_instance_id()
	var previous: Dictionary=chills.get(id,{})
	var stacks := mini(3,int(previous.get("stacks",0))+1)
	chills[id]={"enemy":weakref(target),"stacks":stacks,"left":3.0,"base_slow":previous.get("base_slow",target.movement_slow),"base_left":previous.get("base_left",target.status_time)}
	if not target.boss and not target.mini_boss:
		target.movement_slow=minf(target.movement_slow,1-stacks*0.1);target.status_time=maxf(target.status_time,3.0)

func release_chill(id: int) -> void:
	if not chills.has(id):return
	var mark: Dictionary=chills[id]
	var enemy := (mark.enemy as WeakRef).get_ref() as SlasherEnemy
	if is_instance_valid(enemy) and not enemy.boss and not enemy.mini_boss and is_equal_approx(enemy.movement_slow,1-int(mark.stacks)*0.1):
		enemy.movement_slow=float(mark.base_slow) if float(mark.base_left)>0 else 1.0
		enemy.status_time=maxf(0,float(mark.base_left))
	chills.erase(id)

func place_wall() -> bool:
	var center := actor._safe_destination(actor.global_position+actor.aim_direction*90)
	var side := actor.aim_direction.orthogonal()
	var a := center-side*65
	var b := center+side*65
	if not clear_line(actor.global_position,center) or not clear_line(a,b):return false
	if actor.global_position.distance_to(center)<55:return false
	for enemy in enemies():
		if Geometry2D.get_closest_point_to_segment(enemy.global_position,a,b).distance_to(enemy.global_position)<35:return false
	clear_wall()
	wall={"a":a,"b":b,"center":center,"left":2.0,"rewarded":false}
	wall_body=StaticBody2D.new();wall_body.collision_layer=8;wall_body.collision_mask=0
	var shape := CollisionShape2D.new();var rectangle := RectangleShape2D.new();rectangle.size=Vector2(130,14);shape.shape=rectangle
	wall_body.add_child(shape);add_child(wall_body);wall_body.global_position=center;wall_body.global_rotation=side.angle()
	for enemy in enemies():
		wall_masks[enemy.get_instance_id()]={"enemy":weakref(enemy),"mask":enemy.collision_mask}
		enemy.collision_mask|=8
		if wall_pathfinder==null and enemy.pathfinder!=null:wall_pathfinder=enemy.pathfinder
	if wall_pathfinder!=null:
		for index in 8:
			var cell := wall_pathfinder.world_to_cell(a.lerp(b,index/7.0))
			if wall_pathfinder.cells.has(cell) and not wall_pathfinder.blocked.has(cell):
				blocked_cells.append(cell);wall_pathfinder.set_cell_blocked(cell,true)
	return true

func clear_wall() -> void:
	if is_instance_valid(wall_body):remove_child(wall_body);wall_body.queue_free()
	wall_body=null;wall.clear()
	for entry in wall_masks.values():
		var enemy := (entry.enemy as WeakRef).get_ref() as SlasherEnemy
		if is_instance_valid(enemy):enemy.collision_mask=int(entry.mask)
	wall_masks.clear()
	if wall_pathfinder!=null:
		for cell in blocked_cells:wall_pathfinder.set_cell_blocked(cell,false)
	blocked_cells.clear();wall_pathfinder=null

func _exit_tree() -> void:
	clear_wall()
	for id in chills.keys():release_chill(id)

func _physics_process(delta: float) -> void:
	super(delta)
	for id in chills.keys():
		var mark: Dictionary=chills[id]
		mark.left-=delta;mark.base_left-=delta
		var enemy := (mark.enemy as WeakRef).get_ref() as SlasherEnemy
		if float(mark.left)<=0 or not is_instance_valid(enemy) or enemy.dead:release_chill(id)
	if not wall.is_empty():
		wall.left-=delta
		if float(wall.left)<=0:clear_wall()
		else:
			for shot in hostile_shots():
				var next := shot.global_position+shot.direction*shot.speed*delta
				if Geometry2D.segment_intersects_segment(shot.global_position,next,wall.a,wall.b)!=null:
					shot._finish();flash(shot.global_position,35)
					if not bool(wall.rewarded):wall.rewarded=true;actor._award_resource(1);actor.resource_changed.emit(actor.run_state.class_resource,actor.run_state.get_class_resource_max())
	for index in range(frozen_fields.size()-1,-1,-1):
		var field: Dictionary=frozen_fields[index];field.left-=delta
		if float(field.left)<=0:frozen_fields.remove_at(index);continue
		for enemy in enemies():
			if not enemy.boss and not enemy.mini_boss and on_frozen_field(enemy.global_position,field):
				enemy.movement_slow=minf(enemy.movement_slow,0.65);enemy.status_time=maxf(enemy.status_time,0.4)
	for index in range(fractures.size()-1,-1,-1):
		var cast: Dictionary=fractures[index];cast.left-=delta
		if float(cast.left)>0:continue
		frozen_fields.append({"kind":"cone","a":cast.origin,"direction":cast.direction,"left":TERRAIN_DURATION})
		for enemy in enemies():
			var offset := enemy.global_position-Vector2(cast.origin)
			if offset.length()>270 or (not offset.is_zero_approx() and offset.normalized().dot(cast.direction)<cos(deg_to_rad(50))) or not clear_line(cast.origin,enemy.global_position):continue
			var id := enemy.get_instance_id();var stacks := int(Dictionary(chills.get(id,{})).get("stacks",0))
			var attack: Dictionary=Dictionary(cast.attack).duplicate(true);attack.damage=maxi(1,int(round(int(attack.damage)*(1+stacks*0.2))))
			attack["hit_stun_duration"]=0.15 if stacks==3 and not enemy.boss and not enemy.mini_boss else 0.0
			release_chill(id);hit(enemy,attack,true);flash(enemy.global_position,55)
		flash(cast.origin+Vector2(cast.direction)*130,125);fractures.remove_at(index)

func _draw() -> void:
	super()
	var tint := VISUALS.color_for("ice")
	if not wall.is_empty():
		var a := to_local(wall.a);var b := to_local(wall.b)
		draw_line(a,b,Color(0.4,0.8,1,0.25),24);draw_line(a,b,tint,5)
		for index in 7:VISUALS.crystal(self,a.lerp(b,index/6.0),12+sin(clock*4+index)*2,tint)
	for field in frozen_fields:
		var opacity := minf(1,float(field.left))*0.3
		var a := to_local(field.a)
		if field.kind=="strip":
			var b := to_local(field.b)
			draw_line(a,b,Color(0.5,0.85,1,opacity),48)
			draw_line(a,b,Color(0.7,0.95,1,opacity+0.1),3)
			for index in 12:VISUALS.crystal(self,a.lerp(b,index/11.0),5,tint)
		else:
			var polygon := PackedVector2Array([a])
			for index in 17:polygon.append(a+Vector2(field.direction).rotated(deg_to_rad(-50+index*100.0/16))*270)
			draw_colored_polygon(polygon,Color(0.5,0.85,1,opacity));draw_polyline(polygon,tint,2)
			for index in 9:
				var point := a+Vector2(field.direction).rotated(deg_to_rad(-40+index*10))*170
				VISUALS.crystal(self,point,7,tint)
	for cast in fractures:
		var origin := to_local(cast.origin);var direction := Vector2(cast.direction)
		var polygon := PackedVector2Array([origin])
		for index in 17:polygon.append(origin+direction.rotated(deg_to_rad(-50+index*100.0/16))*270)
		draw_colored_polygon(polygon,Color(0.45,0.85,1,0.18));draw_polyline(polygon,tint,2)

func draw_foreground(canvas: Node2D) -> void:
	super(canvas)
	for mark in chills.values():
		var enemy := (mark.enemy as WeakRef).get_ref() as SlasherEnemy
		if is_instance_valid(enemy):
			for index in int(mark.stacks):VISUALS.crystal(canvas,to_local(enemy.global_position)+Vector2((index-1)*13,-42),5,VISUALS.color_for("ice"))
