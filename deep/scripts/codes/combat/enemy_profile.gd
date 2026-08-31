class_name EnemyProfile
extends Resource

@export_category("Identity")
@export var enemy_id := "enemy"
@export var journal_id := ""
@export var display_name := "Enemy"
@export var faction := "hostile"
@export var drops: Dictionary = {}
@export_category("Survivability")
@export var max_health := 40
@export var defense := 1
@export var vulnerabilities: Dictionary = {"fire":1.25,"lightning":1.5,"aether":0.75}
@export var knockback_resistance := 0.15
@export_category("Lifecycle")
@export_range(0.0,300.0,0.1,"or_greater") var respawn_time:=0.0
@export_category("Movement and Awareness")
@export var move_speed := 105.0
@export var aggro_range := 250.0
@export var leash_range := 390.0
@export var attack_range := 48.0
@export var retreat_range := 190.0
@export var retreat_health_ratio := 0.25
@export_category("Attack")
@export var attack_damage := 12
@export var attack_damage_type := "physical"
@export var attack_cooldown := 1.25
@export var attack_windup := 0.38
@export var attack_knockback := 100.0
@export_flags("Patrol","Chase","Melee","Retreat") var enabled_behaviors := 15
