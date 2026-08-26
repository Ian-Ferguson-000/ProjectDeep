extends RefCounted
class_name CombatResolver

const DAMAGE_TYPES := ["physical", "fire", "cold", "lightning", "arcane", "radiant", "necrotic", "poison"]

static func resolve_attack(
	roll: int,
	accuracy: int,
	raw_damage: int,
	penetration: int,
	damage_type: String,
	defenses: Dictionary
) -> Dictionary:
	var total := roll + accuracy
	var armor_class := int(defenses.get("armor_class", 10))
	var evasion := int(defenses.get("evasion", 10))
	var reaction_eligible := total <= armor_class
	var hit := total > evasion
	var result := {
		"roll": roll,
		"accuracy": accuracy,
		"attack_total": total,
		"armor_class": armor_class,
		"evasion": evasion,
		"reaction_eligible": reaction_eligible,
		"hit": hit,
		"raw_damage": maxi(0, raw_damage),
		"damage_type": damage_type,
		"penetration": maxi(0, penetration),
		"threshold": int(defenses.get("threshold", 0)),
		"aegis": aegis_for(defenses, damage_type),
		"damage": 0,
		"blocked_by_threshold": false,
	}
	if not hit:
		return result
	var effective_threshold := maxi(0, int(result["threshold"]) - int(result["penetration"]))
	if int(result["raw_damage"]) <= effective_threshold:
		result["blocked_by_threshold"] = true
		return result
	var effective_aegis := maxi(0, int(result["aegis"]) - int(result["penetration"]))
	result["damage"] = maxi(0, int(result["raw_damage"]) - effective_aegis)
	return result

static func aegis_for(defenses: Dictionary, damage_type: String) -> int:
	var typed_key := "aegis_%s" % damage_type
	return int(defenses.get(typed_key, defenses.get("aegis_all", 0)))

static func defense_snapshot(stats: Dictionary) -> Dictionary:
	var snapshot := {
		"armor_class": int(stats.get("armor_class", 10)),
		"evasion": int(stats.get("evasion", 10)),
		"threshold": int(stats.get("threshold", 0)),
		"aegis_all": int(stats.get("aegis_all", 0)),
	}
	for damage_type in DAMAGE_TYPES:
		snapshot["aegis_%s" % damage_type] = int(snapshot["aegis_all"]) + int(stats.get("aegis_%s" % damage_type, 0))
	return snapshot
