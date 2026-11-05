extends CharacterBody2D
class_name CorruptedMiniBeast

var owner_player: SlasherPlayer
var lifetime := 12.0
var attack_cooldown := 0.0
var orbit_offset := Vector2.ZERO
var tint := Color("#a956d8")
var target_reference:WeakRef
var search_left:=0.0
var route:Array[Vector2i]=[]
var route_goal:=Vector2i(2147483647,2147483647)
var route_revision:=-1
var route_pathfinder_id:=0
var age:=0.0
var attack_windup:=0.0
var damage_coefficient:=0.45
var attack_interval:=0.7
var move_speed:=190.0
var search_range:=600.0
var search_interval:=0.2
var attack_range:=48.0
var engage_range:=42.0
var pooled:=false
var active:=true
var emergence_duration:=0.18
var windup_duration:=0.12
var dissolve_duration:=0.4
var facing:=Vector2.RIGHT
var bite_flash:=0.0
var bite_point:=Vector2.ZERO

func setup(player: SlasherPlayer, origin: Vector2, index: int) -> CorruptedMiniBeast:
	owner_player=player;global_position=origin
	active=true;show();set_physics_process(true)
	age=0;attack_windup=0;attack_cooldown=0;search_left=0;target_reference=null;velocity=Vector2.ZERO
	route.clear();route_goal=Vector2i(2147483647,2147483647);route_revision=-1;route_pathfinder_id=0
	facing=Vector2.RIGHT;bite_flash=0;bite_point=origin
	orbit_offset=Vector2.RIGHT.rotated(float(index)*2.399)*float(28+index%3*10)
	z_index=5
	collision_layer=0;collision_mask=1
	if get_node_or_null("BeastBody")==null:
		var shape:=CollisionShape2D.new();shape.name="BeastBody"
		var circle:=CircleShape2D.new();circle.radius=7.0;shape.shape=circle;add_child(shape)
	return self

func retire()->void:
	if not pooled:queue_free();return
	active=false;hide();set_physics_process(false);collision_mask=0
	remove_from_group("corrupted_mini_beast")
	target_reference=null;attack_windup=0;velocity=Vector2.ZERO
	bite_flash=0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_player):queue_free();return
	if not active:return
	if owner_player.health<=0:retire();return
	age+=delta;lifetime-=delta;attack_cooldown=maxf(0.0,attack_cooldown-delta)
	bite_flash=maxf(0,bite_flash-delta)
	if lifetime<=0.0:retire();return
	search_left-=delta
	var target:SlasherEnemy=target_reference.get_ref() as SlasherEnemy if target_reference!=null else null
	if is_instance_valid(target) and target.dead:target=null
	if search_left<=0:
		search_left=maxf(0.01,search_interval);var best:=search_range*search_range
		target=null
		for node in get_tree().get_nodes_in_group("slasher_enemy"):
			if node is SlasherEnemy and not node.dead and owner_player.get_parent().is_ancestor_of(node):
				var distance:=global_position.distance_squared_to(node.global_position)
				if distance<best:best=distance;target=node
		target_reference=weakref(target) if is_instance_valid(target) else null
	if is_instance_valid(target):facing=global_position.direction_to(target.global_position)
	if age<emergence_duration:queue_redraw();return
	if attack_windup>0:
		attack_windup=maxf(0,attack_windup-delta)
		if attack_windup<=0 and is_instance_valid(target) and global_position.distance_to(target.global_position)<=attack_range and _clear_contact(target):
			bite_point=target.global_position;bite_flash=0.14
			var damage:=maxi(1,int(round(owner_player.attack_power*damage_coefficient)))
			target.receive_attack({"damage":damage,"damage_type":"aether","damage_source":"Corrupted Mini-Beast","knockback":18.0,"hit_stun_duration":0.03,"mage_secondary":true},owner_player)
		queue_redraw();return
	if target==null:
		_move_to(owner_player.global_position+orbit_offset,150.0,delta)
	elif global_position.distance_to(target.global_position)>minf(engage_range,attack_range) or not _clear_contact(target):
		_move_to(target.global_position,move_speed,delta)
	elif attack_cooldown<=0.0:
		attack_windup=windup_duration;attack_cooldown=attack_interval
	queue_redraw()

func _move_to(destination:Vector2,speed:float,delta:float)->void:
	var waypoint:=destination
	var pathfinder:SlasherGridPathfinder=owner_player.pathfinder
	if pathfinder!=null and not pathfinder.cells.is_empty():
		var goal:=pathfinder.nearest_walkable_cell(pathfinder.world_to_cell(destination))
		if goal!=route_goal or pathfinder.revision!=route_revision or pathfinder.get_instance_id()!=route_pathfinder_id:
			route_goal=goal;route_revision=pathfinder.revision;route_pathfinder_id=pathfinder.get_instance_id()
			route=pathfinder.find_cell_path(pathfinder.world_to_cell(global_position),goal)
		# Do not skip a waypoint merely because the body entered its cell.
		# Center-to-center traversal preserves footprint clearance at corners.
		while not route.is_empty() and global_position.distance_to(pathfinder.cell_to_world(route[0]))<=2.0:route.pop_front()
		if not route.is_empty():waypoint=pathfinder.cell_to_world(route[0])
		elif pathfinder.world_to_cell(global_position)!=goal:return
	move_and_collide((waypoint-global_position).limit_length(speed*delta))

func _clear_contact(target:SlasherEnemy)->bool:
	var query:=PhysicsRayQueryParameters2D.create(global_position,target.global_position,1)
	query.exclude=[get_rid(),owner_player.get_rid(),target.get_rid()]
	# Another dynamic body must not hide solid cover behind it.
	for i in 128:
		var result:=get_world_2d().direct_space_state.intersect_ray(query)
		if result.is_empty():return true
		if result.collider is StaticBody2D:return false
		var exclusions:=query.exclude;exclusions.append(result.rid);query.exclude=exclusions
	return false

func _draw() -> void:
	var emerge:=clampf(age/maxf(0.01,emergence_duration),0,1)
	var dissolve:=clampf(lifetime/maxf(0.01,dissolve_duration),0,1)
	var settings:=get_node_or_null("/root/GameSettings")
	var reduced:bool=settings!=null and settings.get_bool("reduced_effects",false)
	var windup:=attack_windup/maxf(0.01,windup_duration)
	var lunge:=maxf(0,bite_flash/0.14)*8-windup*4
	# Only the silhouette lunges. The body and bite remain collision/LOS checked.
	draw_set_transform(facing*lunge,facing.angle(),Vector2(emerge,emerge*dissolve))
	draw_circle(Vector2.ZERO,10,Color("#24132e",0.8*dissolve))
	for side in [-1,1]:
		for leg in 2:
			var root:=Vector2(-5+leg*9,side*3)
			var knee:=Vector2(-9+leg*14,side*(5+emerge*5))
			var foot:=Vector2(-12+leg*18,side*(6+emerge*8))
			draw_polyline(PackedVector2Array([root,knee,foot]),Color(tint,dissolve),2,true)
	draw_colored_polygon(PackedVector2Array([Vector2(-10,0),Vector2(-5,-7),Vector2(7,-6),Vector2(12,0),Vector2(7,6),Vector2(-5,7)]),Color(tint,0.85*dissolve))
	for side in [-1,1]:
		draw_circle(Vector2(6,side*3),1.6,Color("#b6ffbf",dissolve))
		draw_line(Vector2(10,side*3),Vector2(14,side),Color("#e5dfbd",dissolve),2,true)
	draw_set_transform(Vector2.ZERO)
	if attack_windup>0:draw_arc(Vector2.ZERO,16,-0.7+facing.angle(),0.7+facing.angle(),12,Color("#70edbd"),2)
	if bite_flash>0:
		var contact:=to_local(bite_point)
		for side in [-1,1]:draw_line(contact+Vector2(-5,side*6),contact+Vector2(5,0),Color("#b6ffbf",bite_flash/0.14),2,true)
	if not reduced and (emerge<1 or dissolve<1):
		for i in 5:
			var offset:=Vector2.from_angle(i*TAU/5+age)*lerpf(15,5,emerge*dissolve)
			draw_circle(offset+Vector2(0,-(1-dissolve)*15),2,Color(tint,0.55*dissolve))
