class_name DamagePacket
extends RefCounted

var source: Node
var base_damage := 0
var damage_type := "neutral"
var status_effect := ""
var status_power := 0
var knockback := 0.0
var direction := Vector2.ZERO

## Constructs and returns a normalized packet. damage is pre-mitigation, type must match vulnerability keys,
## and push_direction is normalized automatically. source may be null for environmental or test damage.
static func create(p_source: Node, damage: int, type: String, status := "", power := 0, force := 0.0, push_direction := Vector2.ZERO) -> DamagePacket:
	var packet:=DamagePacket.new(); packet.source=p_source; packet.base_damage=damage; packet.damage_type=type
	packet.status_effect=status; packet.status_power=power; packet.knockback=force; packet.direction=push_direction.normalized()
	return packet

