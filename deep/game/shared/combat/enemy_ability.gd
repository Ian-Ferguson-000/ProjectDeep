class_name EnemyAbility
extends Resource

enum Kind { MELEE, PROJECTILE, AREA, LUNGE }

@export var ability_id:="attack"
@export var kind:=Kind.MELEE
@export var damage:=10
@export var damage_type:="physical"
@export var status_effect:=""
@export var status_power:=0
@export var range:=48.0
@export var preferred_min_range:=0.0
@export var preferred_max_range:=48.0
@export var cooldown:=1.25
@export var windup:=0.35
@export var knockback:=100.0
@export var projectile_speed:=360.0
@export var projectile_range:=320.0
@export var area_radius:=48.0
@export var lunge_speed:=420.0
@export var lunge_duration:=0.22

