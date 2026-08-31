class_name HealthComponent
extends Node

signal health_changed(current: int, maximum: int)
signal damage_received(amount: int, packet: DamagePacket)
signal died(packet: DamagePacket)
signal combat_reset

@export var max_health := 100
@export var defense := 0
@export var vulnerabilities: Dictionary = {}
var current_health := 100
var invulnerable := false

## Initializes current health from the exported maximum. Owners that configure dynamically should still call
## configure().
func _ready() -> void:
	current_health=max_health

## Replaces health configuration, fully heals, duplicates the multiplier map, and emits health_changed.
## Multipliers use damage-type strings; missing types default to 1.0.
func configure(maximum: int, armor: int, multipliers: Dictionary) -> void:
	max_health=maximum; defense=armor; vulnerabilities=multipliers.duplicate(true); current_health=max_health
	health_changed.emit(current_health,max_health)

## Applies max(0, round(base × multiplier) − defense), emits damage/health/death signals, and returns resolved
## damage. Invulnerable or dead components reject hits; zero multiplier provides immunity.
func receive_damage(packet: DamagePacket) -> int:
	if invulnerable or current_health<=0: return 0
	var multiplier:=float(vulnerabilities.get(packet.damage_type,1.0))
	var owner:=get_parent();var status:StatusComponent=owner.get_node_or_null("StatusComponent") if owner else null
	if status:multiplier*=status.vulnerability_multiplier()
	var armor:=defense+(status.defense_bonus() if status else 0)
	var amount: int=max(0,int(round(packet.base_damage*multiplier))-armor)
	if amount<=0: return 0
	current_health=max(0,current_health-amount)
	damage_received.emit(amount,packet); health_changed.emit(current_health,max_health)
	if current_health==0: died.emit(packet)
	return amount

## Clears invulnerability, fully heals, and emits health and reset signals. It does not clear statuses; the
## owner must also call StatusComponent.clear().
func reset_health() -> void:
	invulnerable=false; current_health=max_health
	health_changed.emit(current_health,max_health); combat_reset.emit()

## Returns current/max as a safe float, protecting against a zero maximum.
func health_ratio() -> float:
	return float(current_health)/float(max(1,max_health))
