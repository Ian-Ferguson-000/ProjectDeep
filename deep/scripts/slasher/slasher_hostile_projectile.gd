extends Node2D
class_name SlasherHostileProjectile

var source:SlasherEnemy
var target:SlasherPlayer
var direction:=Vector2.RIGHT
var speed:=280.0
var max_range:=280.0
var traveled:=0.0
var damage:=1
var hit_radius:=13.0
var tint:=Color("#c9ef72")
var impacted:=false

func setup(owner:SlasherEnemy,player:SlasherPlayer,origin:Vector2,aim:Vector2,projectile_damage:int,config:Dictionary)->SlasherHostileProjectile:
	source=owner;target=player;global_position=origin;direction=aim.normalized() if not aim.is_zero_approx() else Vector2.RIGHT
	damage=maxi(1,projectile_damage);speed=float(config.get("burst_speed",285.0));max_range=float(config.get("burst_range",285.0));hit_radius=float(config.get("burst_hit_radius",13.0));tint=Color(String(config.get("burst_color","#c9ef72")));return self

func _ready()->void:
	z_index=4;queue_redraw()

func _physics_process(delta:float)->void:
	if impacted:return
	var movement:=direction*speed*delta
	var query:=PhysicsRayQueryParameters2D.create(global_position,global_position+movement,1)
	if is_instance_valid(source):query.exclude.append(source.get_rid())
	var collision:=get_world_2d().direct_space_state.intersect_ray(query)
	if not collision.is_empty() and collision.get("collider") is StaticBody2D:_finish();return
	global_position+=movement;traveled+=movement.length()
	if is_instance_valid(target) and global_position.distance_to(target.global_position)<=hit_radius:
		target.receive_damage(damage,direction*95.0,source if is_instance_valid(source) else null);_finish();return
	if traveled>=max_range:_finish()

func _finish()->void:
	if impacted:return
	impacted=true;queue_free()

func _draw()->void:
	var forward:=direction*11.0;var side:=direction.orthogonal()*5.0
	draw_colored_polygon(PackedVector2Array([forward,-forward*0.65+side,-forward,-forward*0.65-side]),tint)
	draw_polyline(PackedVector2Array([forward,-forward*0.65+side,-forward,-forward*0.65-side,forward]),Color("#34562b"),2.0)
