class_name SpellRocket
extends Node2D

var caster:Node2D
var rune:Dictionary={}
var target_position:=Vector2.ZERO
var direction:=Vector2.RIGHT
var speed:=920.0
var exploded:=false
var explosion_elapsed:=0.0
var explosion_duration:=0.28
var hit_ids:Dictionary={}

## Configures a rapid cursor-targeted rocket using the rune's range-clamped destination and packet metadata.
func setup(source:Node2D,spell:Dictionary,origin:Vector2,destination:Vector2) -> SpellRocket:
	caster=source;rune=spell;global_position=origin;target_position=destination
	direction=(target_position-origin).normalized() if target_position.distance_squared_to(origin)>1.0 else Vector2.RIGHT
	queue_redraw();return self

## Flies rapidly toward the fixed target point, detonates on arrival, and advances six explosion frames.
func _physics_process(delta:float) -> void:
	if exploded:
		explosion_elapsed+=delta;queue_redraw()
		if explosion_elapsed>=explosion_duration:queue_free()
		return
	var distance:=global_position.distance_to(target_position);var movement:=speed*delta
	if distance<=movement:global_position=target_position;_explode();return
	global_position+=direction*movement;queue_redraw()

## Applies one radial damage packet to each eligible target and starts the local explosion-frame lifecycle.
func _explode() -> void:
	if exploded:return
	exploded=true
	for target in get_tree().get_nodes_in_group("spell_target"):
		if not _valid_target(target) or global_position.distance_to(target.global_position)>float(rune.radius):continue
		var id:=target.get_instance_id()
		if hit_ids.has(id):continue
		hit_ids[id]=true
		var push:Vector2=(target.global_position-global_position).normalized()
		var packet:=DamagePacket.create(caster,int(rune.power),str(rune.damage_type),str(rune.status_effect),int(rune.status_power),float(rune.knockback),push)
		var accepted:=int(target.receive_damage(packet)) if target.has_method("receive_damage") else 0
		if accepted>0:_spawn_target_impact(target.global_position)
	queue_redraw()

## Spawns the standard frame-driven contact effect for each target damaged by the radial detonation.
func _spawn_target_impact(contact_position:Vector2) -> void:
	var parent:=get_parent()
	if not parent:return
	var impact:=SpellImpact.new().setup(str(rune.id),str(rune.damage_type));parent.add_child(impact);impact.global_position=contact_position

## Rejects retained, hidden, freed, or non-damageable encounter nodes from the explosion query.
func _valid_target(target:Node) -> bool:
	if not is_instance_valid(target) or not target is Node2D or not target.has_method("receive_damage"):return false
	if target is CanvasItem and not target.visible:return false
	if target.has_method("is_combat_target_active") and not target.is_combat_target_active():return false
	return true

## Draws a compact high-speed rocket before impact and six expanding elemental explosion frames afterward.
func _draw() -> void:
	var color:=CombatFeedback.damage_color(str(rune.get("damage_type","fire")))
	if not exploded:
		draw_line(-direction*22.0,-direction*5.0,Color(color,0.45),6.0);draw_circle(Vector2.ZERO,7.0,color);draw_circle(direction*2.0,3.0,Color.WHITE)
		return
	var frame:=mini(5,int(explosion_elapsed/explosion_duration*6.0));var progress:=float(frame+1)/6.0;var radius:=float(rune.radius)*progress
	draw_circle(Vector2.ZERO,radius,Color(color,0.26*(1.0-progress)));draw_arc(Vector2.ZERO,radius,0,TAU,32,Color(color,1.0-progress*0.75),6.0)
