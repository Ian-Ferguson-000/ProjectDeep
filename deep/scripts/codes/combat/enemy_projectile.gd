class_name EnemyProjectile
extends Area2D

var velocity:=Vector2.ZERO
var packet:DamagePacket
var remaining_range:=320.0
var damage_type:="physical"
var resolved:=false

## Configures travel, packet metadata, collision, and elemental presentation before the projectile is added.
func setup(origin:Vector2,direction:Vector2,ability:EnemyAbility,source:Node) -> EnemyProjectile:
	global_position=origin; velocity=direction.normalized()*ability.projectile_speed; remaining_range=ability.projectile_range
	damage_type=ability.damage_type
	packet=DamagePacket.create(source,ability.damage,ability.damage_type,ability.status_effect,ability.status_power,ability.knockback,direction)
	queue_redraw()
	return self

## Creates the collision shape and connects body contact after setup has supplied packet metadata.
func _ready() -> void:
	collision_layer=0; collision_mask=3
	var shape:=CollisionShape2D.new(); var circle:=CircleShape2D.new(); circle.radius=8; shape.shape=circle; add_child(shape)
	body_entered.connect(_on_body_entered)
	queue_redraw()

## Advances the projectile and removes it after exhausting its configured range.
func _physics_process(delta:float) -> void:
	if resolved:return
	var movement:=velocity*delta; global_position+=movement; remaining_range-=movement.length()
	if remaining_range<=0: queue_free()

## Damages the player once, while terrain contact simply consumes the projectile.
func _on_body_entered(body:Node) -> void:
	if resolved:return
	if body is PlayerCharacter: body.receive_damage(packet)
	resolved=true; queue_free()

## Draws a compact placeholder bolt colored by its data-driven damage type.
func _draw() -> void:
	var colors:={"fire":Color("#ff6b35"),"ice":Color("#73d9ff"),"poison":Color("#83d640"),"aether":Color("#aa7cff")}
	draw_circle(Vector2.ZERO,8,colors.get(damage_type,Color.WHITE)); draw_circle(Vector2.ZERO,3,Color.WHITE)
