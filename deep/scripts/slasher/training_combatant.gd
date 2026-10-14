extends SlasherEnemy

signal damage_reported(amount: int, damage_type: String, source_label: String, critical: bool)

var last_damage_type := "physical"

func receive_hit(amount: int, knockback: Vector2 = Vector2.ZERO, attacker: SlasherPlayer = null, stun_duration: float = -1.0, shake_multiplier: float = 1.0, sound_event: String = "impact") -> int:
	var dealt := super(amount,knockback,attacker,stun_duration,shake_multiplier,sound_event)
	if dealt>0:
		last_damage_type=incoming_type
		damage_reported.emit(dealt,incoming_type,incoming_source,incoming_critical)
	return dealt
